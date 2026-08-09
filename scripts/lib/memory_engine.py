#!/usr/bin/env python3
"""memory_engine.py — Memoria curada persistente (brecha 2 vs Hermes).

Réplica fiel del `memory_tool.py` de Hermes (Nous Research), sin dependencias
externas: dos stores limitados, entradas separadas por `§`, snapshot congelado
para el system prompt, y la triada add/replace/remove con substring matching.

Datos (en BUFFY_MEM_DIR, default ~/.buffy/memories — perfil-local):
    MEMORY.md — 2200 chars — notas personales del agente (entorno, hechos,
                convenciones, lecciones, workarounds). Se inyecta al prompt.
    USER.md   — 1375 chars — perfil del usuario (preferencias, estilo de
                comunicación, pet peeves, hábitos de trabajo).

Garantías (idénticas a Hermes):
- Límites duros por store; add/replace que exceda el límite se rechaza.
- Dedupe (preserva orden, primera ocurrencia).
- replace/remove por substring único (old_text); ambigüedad -> error
  "be more specific" con previews.
- File lock exclusivo (fcntl) para read-modify-write entre sesiones.
- Guard de drift externo: contenido en disco que no hace round-trip con el
  parser/serializer (edición manual, append de shell, otra sesión) ABORTA la
  mutación y guarda .bak — nunca sobrescribir lo que no entendemos.
- Guard de lectura fallida: archivo que existe pero no se puede leer (UTF-8
  inválido, permiso, block) NO se trata como store vacío — se rechaza.
- Escritura atómica (tmp + rename 0600): los lectores nunca ven medio archivo.
- Escaneo de inyección ligero sobre el contenido antes de escribir (la
  memoria entra al system prompt como snapshot congelado).

Uso:
    memory_engine.py [--dir DIR] [--json] list|render|stats|add|replace|remove|batch
    list                       → entradas de un store
    render -t memory|user      → bloque de system prompt (snapshot)
    stats                      → uso de ambos stores
    add    --content '...'                     (target via --target)
    replace --old 'substring' --content '...'
    remove --old 'substring'
    batch  --ops 'JSON list'    (secuencia atómica add/replace/remove)

Exit: 0 ok · 1 error operacional · 2 uso inválido. --json ⇒ stdout JSON puro.
"""
import fcntl
import json
import os
import sys
import tempfile
import time

ENTRY_DELIMITER = "\n§\n"
MEMORY_LIMIT = 2200
USER_LIMIT = 1375
BOX_LINE = "═" * 46
HEADERS = {"memory": "MEMORY (notas personales del agente)",
           "user": "USER PROFILE (quién es el usuario)"}

# Patrones típicos de prompt injection/exfiltración (versión mínima del
# threat_scan de Hermes). La memoria se congela en el system prompt, así que
# una entrada envenenada persistiría la sesión entera — se rechaza al escribir.
_THREAT_PATTERNS = (
    "ignore all previous", "ignore previous", " disregar", "disregard ",
    "overwrite your", "system prompt", "reveal your", "forget your",
    "you are not allowed", "act as if", "immediately print", "send this text",
    "copy this text", "exfiltr", "bypass your", "pretend you are",
)


def memory_dir():
    return os.environ.get("BUFFY_MEM_DIR") or os.path.join(
        os.environ.get("HOME", "."), ".buffy", "memories")


def path_for(target):
    return os.path.join(memory_dir(), "USER.md" if target == "user" else "MEMORY.md")


def char_limit(target):
    return USER_LIMIT if target == "user" else MEMORY_LIMIT


def scan_content(content):
    low = (content or "").lower()
    hits = [p for p in _THREAT_PATTERNS if p in low]
    return ", ".join(hits)


class MemoryStore:
    def __init__(self):
        self.entries = {"memory": [], "user": []}

    # ── Lectura / parsing ───────────────────────────────────────────────
    @staticmethod
    def _read_raw_checked(path):
        """(raw, read_ok). read_ok=False SOLO si existe pero no se pudo leer
        (incl. UTF-8 inválido) — nunca tratar eso como store vacío."""
        if not os.path.exists(path):
            return "", True
        try:
            with open(path, "r", encoding="utf-8-sig") as fh:
                return fh.read(), True
        except (OSError, IOError, UnicodeDecodeError):
            return "", False

    @staticmethod
    def _parse_entries(raw):
        if not raw.strip():
            return []
        return [e.strip() for e in raw.split(ENTRY_DELIMITER) if e.strip()]

    @staticmethod
    def _write_file(path, entries):
        content = ENTRY_DELIMITER.join(entries) if entries else ""
        d = os.path.dirname(path)
        os.makedirs(d, exist_ok=True)
        fd, tmp = tempfile.mkstemp(prefix=".mem_", dir=d)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                fh.write(content)
            os.chmod(tmp, 0o600)
            os.replace(tmp, path)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise

    @staticmethod
    def _lock(path):
        """Lock exclusivo en <archivo>.lock (el archivo mismo solo via replace)."""
        class _Ctx:
            def __enter__(self):
                os.makedirs(os.path.dirname(path), exist_ok=True)
                self.fd = open(path + ".lock", "a+", encoding="utf-8")
                fcntl.flock(self.fd.fileno(), fcntl.LOCK_EX)
                return self

            def __exit__(self, *exc):
                fcntl.flock(self.fd.fileno(), fcntl.LOCK_UN)
                self.fd.close()

        return _Ctx()

    # ── Estado ──────────────────────────────────────────────────────────
    def _load_target(self, target):
        raw, ok = self._read_raw_checked(path_for(target))
        self.entries[target] = list(dict.fromkeys(self._parse_entries(raw))) if ok else []
        return ok

    def _char_count(self, target):
        entries = self.entries[target]
        return len(ENTRY_DELIMITER.join(entries)) if entries else 0

    def _usage(self, target):
        cur, lim = self._char_count(target), char_limit(target)
        return {"target": target, "chars": cur, "limit": lim,
                "pct": min(100, int(cur * 100 / lim)) if lim else 0,
                "entries": len(self.entries[target])}

    # ── Reload + drift (bajo lock, antes de mutar) ──────────────────────
    def _reload_target(self, target, skip_drift=False):
        """Devuelve ruta .bak si hay drift (CON la mutación), None si limpio.
        Lanza RuntimeError si el archivo existe y no es legible (abortar)."""
        path = path_for(target)
        raw, read_ok = self._read_raw_checked(path)
        if not read_ok:
            raise RuntimeError(f"archivo existe pero no se puede leer: {path}")
        bak = None if skip_drift else self._detect_external_drift(target, raw)
        self.entries[target] = list(dict.fromkeys(self._parse_entries(raw)))
        return bak

    def _detect_external_drift(self, target, raw):
        if not raw.strip():
            return None
        parsed = [e.strip() for e in raw.split(ENTRY_DELIMITER) if e.strip()]
        roundtrip = ENTRY_DELIMITER.join(parsed)
        if raw.strip() == roundtrip and parsed and max(len(e) for e in parsed) <= char_limit(target):
            return None
        bak = path_for(target) + f".bak.{int(time.time())}"
        try:
            with open(bak, "w", encoding="utf-8") as fh:
                fh.write(raw)
            return bak
        except OSError:
            return bak + " (BACKUP FALLIDO)"

    # ── Resultados ──────────────────────────────────────────────────────
    def _fail(self, error, target, entries=None):
        return {"success": False, "error": error,
                "current_entries": self.entries.get(target, []),
                "usage": f"{self._char_count(target):,}/{char_limit(target):,} chars"}

    def _success(self, target, message, extra=None):
        u = self._usage(target)
        d = {"success": True, "target": target, "message": message,
             "usage": f"{u['pct']}% — {u['chars']:,}/{u['limit']:,} chars",
             "entry_count": u["entries"]}
        if extra:
            d.update(extra)
        return d

    # ── Acciones ────────────────────────────────────────────────────────
    def add(self, target, content):
        content = (content or "").strip()
        if not content:
            return self._fail("content vacío", target)
        threat = scan_content(content)
        if threat:
            return self._fail(f"Contenido bloqueado (inyección): {threat}", target)
        with self._lock(path_for(target)):
            try:
                self._reload_target(target, skip_drift=True)
            except RuntimeError as exc:
                return self._fail(f"Archivo ilegible — nada se borró: {exc}", target)
            if content in self.entries[target]:
                return self._success(target, "Entrada ya existe (no se duplicó).", {"duplicate": True})
            current = self._char_count(target)
            new_total = current + len(content) + (len(ENTRY_DELIMITER) if self.entries[target] else 0)
            if new_total > char_limit(target):
                return self._fail(
                    f"Límite: {current:,}/{char_limit(target):,} chars. "
                    f"Consolida con replace/remove y reintenta.", target)
            self.entries[target].append(content)
            self._write_file(path_for(target), self.entries[target])
        return self._success(target, "Entrada agregada.")

    def replace(self, target, old_text, content):
        old_text, content = (old_text or "").strip(), (content or "").strip()
        if not old_text:
            return self._fail("old_text vacío — substring único de la entrada a reemplazar", target)
        if not content:
            return self._fail("contenido nuevo vacío — usa remove para borrar", target)
        threat = scan_content(content)
        if threat:
            return self._fail(f"Contenido bloqueado (inyección): {threat}", target)
        with self._lock(path_for(target)):
            try:
                bak = self._reload_target(target)
            except RuntimeError as exc:
                return self._fail(f"error: {exc}", target)
            if bak:
                return self._fail(
                    f"DRIFT externo en {os.path.basename(path_for(target))}: contenido "
                    f"en disco sin round-trip (edición manual u otro proceso). Snapshot en "
                    f"{bak} — arregla el archivo y reintenta. Nunca sobrescribimos "
                    f"lo que no entendemos.", target)
            matches = [i for i, e in enumerate(self.entries[target]) if old_text in e]
            if not matches:
                return self._fail(f"Ninguna entrada contiene '{old_text}'.", target)
            if len(matches) > 1 and len({self.entries[target][i] for i in matches}) > 1:
                previews = [self.entries[target][i][:80] for i in matches]
                return self._fail(f"'{old_text}' matchea varias entradas distintas — sé más específico.\n{previews}", target)
            idx = matches[0]
            test = list(self.entries[target])
            test[idx] = content
            if len(ENTRY_DELIMITER.join(test)) > char_limit(target):
                return self._fail(f"El reemplazo excedería el límite de {char_limit(target)} chars.", target)
            self.entries[target][idx] = content
            self._write_file(path_for(target), self.entries[target])
        return self._success(target, "Entrada reemplazada.")

    def remove(self, target, old_text):
        old_text = (old_text or "").strip()
        if not old_text:
            return self._fail("old_text vacío — substring único de la entrada a borrar", target)
        with self._lock(path_for(target)):
            try:
                bak = self._reload_target(target)
            except RuntimeError as exc:
                return self._fail(f"error: {exc}", target)
            if bak:
                return self._fail(f"DRIFT detectado — snapshot {bak}, arregla y reintenta.", target)
            matches = [i for i, e in enumerate(self.entries[target]) if old_text in e]
            if not matches:
                return self._fail(f"Ninguna entrada contiene '{old_text}'.", target)
            if len(matches) > 1 and len({self.entries[target][i] for i in matches}) > 1:
                return self._fail(f"'{old_text}' matchea varias entradas distintas — sé más específico.", target)
            self.entries[target].pop(matches[0])
            self._write_file(path_for(target), self.entries[target])
        return self._success(target, "Entrada removida.")

    def batch(self, target, ops):
        """add/replace/remove atómicos contra el presupuesto FINAL: si alguna
        op falla o el neto excede, NO se escribe nada (all-or-nothing)."""
        if not isinstance(ops, list) or not ops:
            return self._fail("operations debe ser lista no vacía", target)
        for i, op in enumerate(ops):
            if op.get("action") in ("add", "replace"):
                threat = scan_content(op.get("content", ""))
                if threat:
                    return self._fail(f"Op {i+1}: contenido bloqueado (inyección): {threat}", target)
        with self._lock(path_for(target)):
            try:
                bak = self._reload_target(target)
            except RuntimeError as exc:
                return self._fail(f"error: {exc}", target)
            if bak:
                return self._fail(f"DRIFT detectado — snapshot {bak}, batch sin aplicar.", target)
            working = list(self.entries[target])
            for i, op in enumerate(ops):
                act, content, old = (op.get("action") or ""), (op.get("content") or "").strip(), (op.get("old_text") or "").strip()
                pos = f"Op {i+1} ({act})"
                if act == "add":
                    if not content:
                        return self._fail(f"{pos}: content requerido. Nada se aplicó.", target)
                    if content not in working:
                        working.append(content)
                elif act == "replace":
                    if not old or not content:
                        return self._fail(f"{pos}: old_text y content requeridos. Nada se aplicó.", target)
                    ms = [j for j, e in enumerate(working) if old in e]
                    if not ms or (len(ms) > 1 and len({working[j] for j in ms}) > 1):
                        return self._fail(f"{pos}: '{old}' sin coincidencia única. Nada se aplicó.", target)
                    working[ms[0]] = content
                elif act == "remove":
                    if not old:
                        return self._fail(f"{pos}: old_text requerido. Nada se aplicó.", target)
                    ms = [j for j, e in enumerate(working) if old in e]
                    if not ms or (len(ms) > 1 and len({working[j] for j in ms}) > 1):
                        return self._fail(f"{pos}: '{old}' sin coincidencia única. Nada se aplicó.", target)
                    working.pop(ms[0])
                else:
                    return self._fail(f"{pos}: acción desconocida (add|replace|remove). Nada se aplicó.", target)
            if len(ENTRY_DELIMITER.join(working)) > char_limit(target):
                return self._fail(f"Batch excedería el límite ({len(ENTRY_DELIMITER.join(working))} > {char_limit(target)}). Nada se aplicó.", target)
            self.entries[target] = working
            self._write_file(path_for(target), working)
        return self._success(target, f"Batch de {len(ops)} operación(es) aplicado.")

    # ── Lecturas / snapshot ─────────────────────────────────────────────
    def render_block(self, target):
        """Bloque para el system prompt. Se captura UNA vez al inicio de la
        sesión (snapshot congelado: mid-session NO cambia — prefix cache)."""
        entries = self.entries[target]
        if not entries:
            return ""
        u = self._usage(target)
        content = ENTRY_DELIMITER.join(entries)
        return (f"{BOX_LINE}\n{HEADERS[target]} [{u['pct']}% — "
                f"{u['chars']:,}/{u['limit']:,} chars]\n{BOX_LINE}\n{content}")


# ── CLI ─────────────────────────────────────────────────────────────────
def parse_common(argv):
    """Separa flags globales; devuelve (cmd, target, kwargs, as_json, dir_opt)."""
    as_json = "--json" in argv
    argv = [a for a in argv if a != "--json"]
    dir_opt = None
    for i, a in enumerate(argv):
        if a in ("--dir", "-d") and i + 1 < len(argv):
            dir_opt, argv = argv[i + 1], argv[:i] + argv[i + 2:]
            break
    if dir_opt:
        os.environ["BUFFY_MEM_DIR"] = dir_opt
    if not argv:
        return None, "memory", {}, as_json, None
    cmd, rest = argv[0], argv[1:]
    target = "memory"
    kwargs = {}
    i = 0
    while i < len(rest):
        a = rest[i]
        if a in ("--target", "-t"):
            target = rest[i + 1] if i + 1 < len(rest) else target
        elif a in ("--content", "-c"):
            kwargs["content"] = rest[i + 1] if i + 1 < len(rest) else ""
        elif a in ("--old", "-o"):
            kwargs["old"] = rest[i + 1] if i + 1 < len(rest) else ""
        elif a in ("--ops", "-p"):
            kwargs["ops"] = rest[i + 1] if i + 1 < len(rest) else ""
        else:
            break
        i += 2
    return cmd, target, kwargs, as_json, dir_opt


def main():
    parsed = parse_common(sys.argv[1:])
    if parsed is None:
        return 2
    cmd, target, kwargs, as_json, dir_opt = parsed
    store = MemoryStore()

    def emit(result, fix="memoria"):
        if as_json:
            print(json.dumps(result, ensure_ascii=False))
        elif result.get("success"):
            print(f"✅ {result.get('message', 'ok')}  →  {result.get('usage', '')}  ({result.get('entry_count', '?')} entradas, {result.get('target', '?')})")
        else:
            print(f"❌ {result.get('error', 'error')}", file=sys.stderr)
            for i, e in enumerate(result.get("current_entries", []) or []):
                print(f"   {i:02d}: {e[:80]}{'…' if len(e) > 80 else ''}", file=sys.stderr)
        return 0 if result.get("success") else 1

    if cmd == "list":
        store._load_target(target)
        entries = store.entries[target]
        u = store._usage(target)
        if as_json:
            print(json.dumps({"success": True, "target": target, "entries": entries, "usage": u}, ensure_ascii=False))
            return 0
        print(f"📚 {HEADERS[target]} — {u['pct']}% ({u['chars']:,}/{u['limit']:,} chars, {u['entries']} entradas)")
        for i, e in enumerate(entries):
            print(f"  [{i:02d}] {e}")
        return 0

    if cmd == "render":
        store._load_target(target)
        print(store.render_block(target))
        return 0

    if cmd == "stats":
        if as_json:
            print(json.dumps({"success": True, "stores": {t: (store._load_target(t), store._usage(t))[1] for t in ("memory", "user")}}, ensure_ascii=False))
        else:
            for t in ("memory", "user"):
                store._load_target(t)
                u = store._usage(t)
                print(f"  {t:6s} {u['pct']:3d}%   {u['chars']:>5,}/{u['limit']:,} chars   {u['entries']} entradas")
            print(f"  → {memory_dir()}")
        return 0

    if cmd == "add":
        if not kwargs.get("content"):
            print("uso: add --content 'texto' [--target memory|user]", file=sys.stderr)
            return 2
        return emit(store.add(target, kwargs["content"]))

    if cmd == "replace":
        if not kwargs.get("old") or "content" not in kwargs:
            print("uso: replace --old 'substring' --content 'nuevo' [--target ...]", file=sys.stderr)
            return 2
        return emit(store.replace(target, kwargs["old"], kwargs.get("content", "")))

    if cmd == "remove":
        if not kwargs.get("old"):
            print("uso: remove --old 'substring' [--target ...]", file=sys.stderr)
            return 2
        return emit(store.remove(target, kwargs["old"]))

    if cmd == "batch":
        raw = kwargs.get("ops")
        if not raw:
            print("uso: batch --ops '[{\"action\":\"add\",...}]' [--target ...]", file=sys.stderr)
            return 2
        try:
            ops = json.loads(raw)
        except Exception as exc:
            print(f"ops no es JSON válido: {exc}", file=sys.stderr)
            return 2
        return emit(store.batch(target, ops))

    print(f"comando desconocido: {cmd}", file=sys.stderr)
    print("comandos: list | render | stats | add | replace | remove | batch", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
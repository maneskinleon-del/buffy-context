#!/usr/bin/env python3
"""project_state_engine.py — motor de verificación de project-state.yaml (Paso 5).

Ejecuta los `check` de las aserciones tipo A, clasifica cada una en
verified | stale | unknown | expired y emite TSV (default) o JSON (--json).
Las aserciones tipo B NUNCA se ejecutan (D3) — se reportan como conteo de
juicio humano. Motor READ-ONLY por defecto: no escribe project-state.yaml,
no modifica facts.yaml, no toca Git (Q-02) y no integra con buffy-verify
(Q-03: canal paralelo con su propio JSON).

Diseño normativo: ai-context/project-state-engine-design.md (Paso 3)
  - Pipeline: carga → clasificación → ejecución → TTL → reporte (§ARQUITECTURA)
  - Q-04: fallo de infraestructura → unknown, NUNCA stale
  - Q-07/S-04: hereda normalize_command + SHELL_METACHARS de facts_engine.py
    (una sola fuente de verdad) y exige lista estricta sin retrocompat
  - Etapa TTL: condición SOLO sobre la fecha almacenada (hoy − verified) >
    ttl_days → expired, aplicada a A cuyo resultado fue verified (H-3: expired
    es estado derivado del TTL, no un resultado de ejecución)
  - S-05: trust_project = round(100*V/max(1,V+S+E),1) — solo A, excluye unknown

Uso:
    python3 project_state_engine.py [repo_dir] [--json]
Exit: 0 reporte emitido · 1 project-state.yaml ausente/corrupto · 2 CLI inválido
"""
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import date, datetime

import yaml

# facts_engine vive en esta misma lib/ — una sola fuente de verdad para
# SHELL_METACHARS/normalize_command (Q-07: se hereda, no se reimplementa).
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import facts_engine  # noqa: E402

TIMEOUT = 10                 # heredado de facts_engine.run_cmd (M-05)
RELATIVE_YAML = os.path.join("ai-context", "project-state.yaml")
PROGRAM = "project-state-engine"
TARGET = "project-state.yaml"
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
A_STATUS = ("verified", "stale", "unknown", "expired")
B_STATUS = ("judged", "pending", "disputed")
INFO = "verificación de aserciones A de project-state.yaml — canal paralelo a buffy-verify (Q-03)"

USAGE = """project-state-engine — verificación de aserciones tipo A de project-state.yaml
Uso: python3 project_state_engine.py [repo_dir] [--json]
  repo_dir default: . (lee <repo_dir>/ai-context/project-state.yaml)
  --json: contrato de §SALIDA (trust_project + human_assertions + schema_violations)
Exit: 0 reporte emitido · 1 archivo ausente/corrupto · 2 CLI inválido
Nota: el modo --update es diseño futuro (Paso 3 §MODO --update), no implementado."""


def trunc(text, limit=200):
    """Salida segura para TSV/JSON: sin tabuladores ni saltos, acotada."""
    text = text.replace("\t", " ").replace("\n", " ").replace("\r", " ")
    return text if len(text) <= limit else text[:limit] + "…"


def parse_args(argv):
    as_json = False
    positional = []
    for arg in argv:
        if arg == "--json":
            as_json = True
        elif arg in ("--help", "-h"):
            print(USAGE)
            sys.exit(0)
        elif arg.startswith("-"):
            sys.stderr.write(
                f"{PROGRAM}: opción no soportada: {arg} "
                "(el modo --update es diseño futuro, no implementado)\n")
            sys.exit(2)
        else:
            positional.append(arg)
    if len(positional) > 1:
        sys.stderr.write(f"{PROGRAM}: máximo un repo_dir positional (recibí {len(positional)})\n")
        sys.exit(2)
    return (positional[0] if positional else "."), as_json


def load(repo_dir):
    """Etapa 1 CARGA — ausente/corrupto → error a stderr y exit 1."""
    path = os.path.join(repo_dir, RELATIVE_YAML)
    if not os.path.isfile(path):
        sys.stderr.write(f"{PROGRAM}: no existe o no es archivo: {path}\n")
        return None
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except (OSError, UnicodeDecodeError) as exc:
        sys.stderr.write(f"{PROGRAM}: no se pudo leer {path}: {exc}\n")
        return None
    try:
        data = yaml.safe_load(raw)
    except Exception as exc:  # parseo/constructores (p.ej. timestamp imposible)
        sys.stderr.write(f"{PROGRAM}: YAML corrupto en {path}: {exc}\n")
        return None
    if not isinstance(data, dict):
        sys.stderr.write(f"{PROGRAM}: la raíz no es un mapping YAML: {path}\n")
        return None
    if not isinstance(data.get("assertions"), list):
        sys.stderr.write(f"{PROGRAM}: 'assertions' ausente o no es una lista: {path}\n")
        return None
    return data


def compare(check, argv, proc, repo_dir):
    """Etapa 3 (continuación) — comparar salida según check.comparison."""
    comparison = check.get("comparison", "exact")
    # Formas autocontenidas: el resultado está en el exit code, sin expected
    if comparison == "exit_code":
        if proc.returncode == 0:
            return "verified", "exit 0 ✓", "", "exit 0"
        return "stale", f"exit {proc.returncode} ≠ 0", "", f"exit {proc.returncode}"
    if comparison == "exists":
        ruta = argv[-1]
        full = ruta if os.path.isabs(ruta) else os.path.join(repo_dir, ruta)
        if os.path.exists(full):
            return "verified", f"ruta existe ✓ ({ruta})", "", ruta
        return "stale", f"ruta no existe: {ruta}", "", ruta
    # exact | contains | regex — exigen expected (sin esperado = verified universal
    # = falso-success → unknown "no evaluable", H-2/Paso 3 §check)
    if comparison in ("exact", "contains", "regex"):
        if "expected" not in check or check["expected"] is None:
            return "unknown", "check sin expected — no evaluable", "EXPECTED_MISSING", ""
        out = (proc.stdout or "").strip() or (proc.stderr or "").strip()
        if not out:
            return "unknown", "el comando no produjo salida evaluable", "NO_OUTPUT", ""
        expected = str(check["expected"])
        if comparison == "exact":
            hit, como = out == expected, "salida == expected"
        elif comparison == "contains":
            hit, como = expected in out, "expected ∈ salida"
        else:
            try:
                hit = re.search(expected, out) is not None
            except re.error as exc:
                return "unknown", f"regex inválida en expected: {exc}", "REGEX_INVALID", ""
            como = "regex match"
        if hit:
            return "verified", f"{como} ✓", "", trunc(out)
        return "stale", f"{como} falla — la salida difiere de expected", "", trunc(out)
    return "unknown", f"comparison desconocido: {comparison!r}", "COMPARISON_UNKNOWN", ""


def run_check(item, repo_dir):
    """Etapa 3 EJECUCIÓN (paso a paso de §EJECUCIÓN) → (level, msg, id, real)."""
    check = item.get("check")
    if not isinstance(check, dict):
        return "unknown", "check ausente o no es objeto (LINT-06 lo detecta)", "CHECK_MISSING", ""
    cmd = check.get("command")
    if not isinstance(cmd, list):
        # S-04: lista estricta — string se rechaza (sin retrocompat)
        return "unknown", f"check.command no es lista estricta de args (S-04): {cmd!r}", "COMMAND_NOT_LIST", ""
    if not cmd:
        return "unknown", "check.command vacío (S-04)", "COMMAND_EMPTY", ""
    argv, err = facts_engine.normalize_command(cmd)
    if err:
        # Q-07: metacaracteres rechazados ANTES de ejecutar (nunca llega a subprocess)
        return "unknown", f"comando rechazado antes de ejecutar: {err}", "METACHARS_REJECTED", ""
    if shutil.which(argv[0]) is None:
        return "unknown", f"binario no disponible en PATH: {argv[0]}", "BINARY_MISSING", ""
    try:
        proc = subprocess.run(argv, capture_output=True, text=True,
                              timeout=TIMEOUT, cwd=repo_dir)
    except subprocess.TimeoutExpired:
        return "unknown", f"timeout ({TIMEOUT}s)", "TIMEOUT", ""
    except Exception as exc:
        return "unknown", f"error de ejecución: {exc}", "EXEC_ERROR", ""
    return compare(check, argv, proc, repo_dir)


def apply_ttl(item, level, msg):
    """Etapa 4 TTL (post-ejecución) — la condición usa SOLO la fecha almacenada:
    (hoy − verified).days > ttl_days → expired (0.2). Aplica a A cuyo resultado
    de ejecución fue verified; stale/unknown ya describen el intento (H-3)."""
    if level != "verified":
        return level, msg
    ttl = item.get("ttl_days", 30)  # herencia: siempre 30 (S-02); ausente → 30
    if not (isinstance(ttl, int) and not isinstance(ttl, bool) and ttl > 0):
        ttl = 30
    stored = item.get("verified")
    if isinstance(stored, datetime):  # datetime ≠ YYYY-MM-DD (S-07)
        return level, msg
    if isinstance(stored, date):
        day = stored
    elif isinstance(stored, str) and DATE_RE.match(stored):
        try:
            day = date.fromisoformat(stored)
        except ValueError:
            return level, msg
    else:
        return level, msg  # sin fecha evaluable — LINT-15/LINT-16 la flaggean
    age = (date.today() - day).days
    if age > ttl:
        return ("expired",
                f"TTL vencido: verified {day.isoformat()} tiene {age} días "
                f"(> ttl {ttl}) — requiere reverificación (estado derivado del TTL)")
    return level, msg


def evaluate(assertions, repo_dir):
    """Etapas 2-4: clasificar A/B, ejecutar A, aplicar TTL. Solo lectura."""
    rows = []  # (level, key, msg, id, target, real)
    counts = {s: 0 for s in A_STATUS}
    human = {s: 0 for s in B_STATUS}
    violations = []

    def violation(code, key, detail):
        violations.append({"code": code, "key": key, "detail": detail})
        sys.stderr.write(f"{PROGRAM}: {code} key={key} — {detail}\n")

    for idx, item in enumerate(assertions):
        if not isinstance(item, dict):
            violation("SCHEMA_VIOLATION_ITEM_NOT_MAPPING", f"assertions[{idx}]",
                      "el item no es un mapping (no clasificable)")
            continue
        raw_key = item.get("key")
        key = raw_key if isinstance(raw_key, str) and raw_key else f"assertions[{idx}]"
        atype = item.get("type")
        if atype == "B":
            # B nunca se ejecuta (D3) — y nunca verified
            status = item.get("status")
            if status == "verified":
                violation("SCHEMA_VIOLATION_B_VERIFIED", key,
                          "type: B con status: verified (D3 — B nunca es verified)")
                continue
            if status not in B_STATUS:
                violation("SCHEMA_VIOLATION_B_STATUS", key,
                          f"status B fuera de conjunto: {status!r}")
                continue
            value = trunc(str(item.get("value", "")), 120)
            rows.append((status, key, f"juicio humano: {value}", "", TARGET, ""))
            human[status] += 1
            continue
        if atype != "A":
            violation("SCHEMA_VIOLATION_TYPE_UNKNOWN", key, f"type desconocido: {atype!r}")
            continue
        level, msg, vid, real = run_check(item, repo_dir)
        level, msg = apply_ttl(item, level, msg)
        counts[level] += 1
        rows.append((level, key, msg, vid, TARGET, real))
    return rows, counts, human, violations


def main():
    repo_dir, as_json = parse_args(sys.argv[1:])
    data = load(repo_dir)  # etapa 1
    if data is None:
        return 1
    rows, counts, human, violations = evaluate(data["assertions"], repo_dir)

    if as_json:
        items = []
        for level, key, msg, vid, target, real in rows:
            entry = {"level": level, "key": key, "message": msg, "target": target}
            if vid:
                entry["id"] = vid
            if real:
                entry["real"] = real
            items.append(entry)
        # S-05: misma fórmula que trust_score (buffy-verify L343) — solo A,
        # excluye unknown; B nunca entra.
        denom = max(1, counts["verified"] + counts["stale"] + counts["expired"])
        doc = {
            "repo": repo_dir,
            "verified": counts["verified"],
            "stale": counts["stale"],
            "unknown": counts["unknown"],
            "expired": counts["expired"],
            "trust_project": round(100 * counts["verified"] / denom, 1),
            "human_assertions": {
                "judged": human["judged"],
                "pending": human["pending"],
                "disputed": human["disputed"],
                "total": sum(human.values()),
            },
            "schema_violations": violations,
            "items": items,
            "_info": INFO,
        }
        print(json.dumps(doc, ensure_ascii=False, indent=1))
    else:
        # TSV (patrón facts_engine L7): level<TAB>key<TAB>msg<TAB>id<TAB>target<TAB>real
        for row in rows:
            print("\t".join(row))
    return 0


if __name__ == "__main__":
    sys.exit(main())

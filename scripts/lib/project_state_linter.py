#!/usr/bin/env python3
"""project_state_linter.py — linter estático de project-state.yaml (Paso 5).

Validación PRE-ejecución, barata y sin subprocess (decisión Q-08: el linter es
el gate del pipeline ANTES del motor). NO ejecuta `check.command` — ejecutar es
dominio de project_state_engine.py — y NO escribe nada sobre el archivo
evaluado ni sobre el repo (M-01/M-02: sin modificación).

Diseño normativo: ai-context/project-state-linter-design.md (Paso 4)
  - Guards G-1..G-6, fase de procesabilidad, en orden → exit 2 (§3.7)
  - Reglas LINT-01..LINT-19 → error (exit 1) / advertencia (exit 0) (§3.1-§3.2)
  - LINT-03 se materializa como G-6 (§3.3); LINT-18 es propuesta, NO obligatoria (§3.4)
  - LINT-19 valida SOLO forma: lista no vacía, sin ejecutar ni inspectar
    metacarácteres (§6 — la defensa de ejecución es del motor).

Uso:
    python3 project_state_linter.py [ruta] [--json]
    (ruta default: ai-context/project-state.yaml — convención S-01)

Exit: 0 procesado sin ERR · 1 procesado con ≥1 ERR · 2 no procesado (guard/CLI)
"""
import json
import os
import re
import sys
from datetime import date, datetime

import yaml

DEFAULT_PATH = os.path.join("ai-context", "project-state.yaml")
PROGRAM = "project-state-linter"

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TYPES = ("A", "B")
SOURCES = ("system", "user", "inferred")
A_STATUS = ("verified", "stale", "unknown", "expired")
B_STATUS = ("judged", "pending", "disputed")
# Columna "Requerido ✅" de la tabla de campos (Paso 2 §ESTRUCTURA)
REQUIRED_FIELDS = ("key", "type", "value", "source", "confidence", "status",
                   "verified", "scope", "evidence")

USAGE = """project-state-linter — validación estática de project-state.yaml
Uso: python3 project_state_linter.py [ruta] [--json]
  ruta default: ai-context/project-state.yaml (convención S-01)
  --json: contrato de §4 (healthy/errors/warnings/items)
Exit: 0 procesado sin errores · 1 procesado con ≥1 error · 2 no procesado"""


def valid_date(value):
    """YYYY-MM-DD. PyYAML resuelve el escalar `2026-10-11` como datetime.date
    (no string) — un date puro es exactamente ese formato; un datetime lleva
    hora (≠ YYYY-MM-DD) y un string inválido no parsea (S-07)."""
    if isinstance(value, datetime):  # datetime es subclase de date: verificar antes
        return False
    if isinstance(value, date):
        return True
    if isinstance(value, str) and DATE_RE.match(value) is not None:
        try:
            date.fromisoformat(value)
            return True
        except ValueError:
            return False
    return False


def is_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def guard(msg):
    """Fase de procesabilidad (G-1..G-6 o CLI inválido) → exit 2, NO procesado.

    El motivo va a stderr y NO se emite nada por stdout: un YAML rojo jamás
    reporta `healthy: true` (I-3/F-01)."""
    sys.stderr.write(f"{PROGRAM}: {msg}\n")
    sys.exit(2)


def parse_args(argv):
    path = DEFAULT_PATH
    as_json = False
    positional = []
    for arg in argv:
        if arg == "--json":
            as_json = True
        elif arg in ("--help", "-h"):
            print(USAGE)
            sys.exit(0)
        elif arg.startswith("-"):
            guard(f"opción desconocida: {arg} (usa --help)")
        else:
            positional.append(arg)
    if len(positional) > 1:
        guard(f"máximo una ruta positional (recibí {len(positional)})")
    if positional:
        path = positional[0]
    return path, as_json


def load(path):
    """Guards G-1..G-6, en orden; el PRIMERO fallido detiene (exit 2)."""
    # G-1: existe y es legible
    if not os.path.exists(path):
        guard(f"no existe: {path}")
    if os.path.isdir(path):
        guard(f"no es un archivo: {path}")
    try:
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
    except PermissionError:
        guard(f"sin permiso de lectura: {path}")
    except UnicodeDecodeError:
        guard(f"no es texto UTF-8 válido: {path}")
    except OSError as exc:
        guard(f"no se pudo leer {path}: {exc}")
    # G-2: no vacío
    if len(raw) == 0:
        guard(f"archivo vacío (0 bytes): {path}")
    # G-3: parsea como YAML válido (incluye errores de constructor — p.ej.
    # PyYAML levanta ValueError crudo con un timestamp imposible: todo fallo
    # de parseo/constructores = no procesable, nunca healthy:true (I-3))
    try:
        data = yaml.safe_load(raw)
    except Exception as exc:
        guard(f"error de parseo YAML en {path}: {exc}")
    # G-4: raíz mapping
    if not isinstance(data, dict):
        guard(f"la raíz del documento no es un mapping YAML: {path}")
    # G-5: bloque project presente y mapping
    if not isinstance(data.get("project"), dict):
        guard("bloque 'project' ausente o no es un mapping")
    # G-6: materializa LINT-03 — assertions presente, lista, items mapping
    if "assertions" not in data:
        guard("LINT-03/G-6: 'assertions' ausente (no procesable)")
    assertions = data["assertions"]
    if not isinstance(assertions, list):
        guard(f"LINT-03/G-6: 'assertions' no es una lista (es {type(assertions).__name__})")
    for i, item in enumerate(assertions):
        if not isinstance(item, dict):
            guard(f"LINT-03/G-6: assertions[{i}] no es un mapping")
    return data


def evaluate(data):
    findings = []  # {rule, key, detail, sev}

    def err(rule, key, detail):
        findings.append({"rule": rule, "key": key, "detail": detail, "sev": "error"})

    def warn(rule, key, detail):
        findings.append({"rule": rule, "key": key, "detail": detail, "sev": "advertencia"})

    project = data["project"]

    # LINT-01 / LINT-02 — bloque project
    name = project.get("name")
    if not isinstance(name, str) or not name:
        err("LINT-01", "project.name", "project.name debe ser string no vacío")
    if not valid_date(project.get("version")):
        err("LINT-02", "project.version",
            f"project.version debe ser fecha ISO YYYY-MM-DD (recibí {project.get('version')!r})")

    seen_keys = set()
    for idx, item in enumerate(data["assertions"]):
        label = item.get("key") if isinstance(item.get("key"), str) and item.get("key") else f"assertions[{idx}]"
        atype = item.get("type")
        source = item.get("source")
        status = item.get("status")
        conf = item.get("confidence")
        has = lambda f: f in item  # noqa: E731

        # LINT-15 — campos requeridos (una línea por aserción, todos los faltantes)
        missing = [f for f in REQUIRED_FIELDS if f not in item]
        if missing:
            err("LINT-15", label, f"falta campo requerido: {', '.join(missing)}")

        # LINT-04 — key única
        key = item.get("key")
        if has("key"):
            if key in seen_keys:
                err("LINT-04", label, f"key duplicada: {key!r} (única dentro del repo)")
            else:
                seen_keys.add(key)

        # LINT-05 — type ∈ {A, B}
        type_ok = atype in TYPES
        if has("type") and not type_ok:
            err("LINT-05", label, f"type inválido: {atype!r} (∉ {{'A', 'B'}})")

        # LINT-12 — source ∈ {system, user, inferred}
        source_ok = source in SOURCES
        if has("source") and not source_ok:
            err("LINT-12", label, f"source inválido: {source!r} (∉ {{'system', 'user', 'inferred'}})")

        # LINT-17 — confidence numérica en [0.0, 1.0]
        conf_ok = False
        if has("confidence"):
            if not is_number(conf) or not (0.0 <= conf <= 1.0):
                err("LINT-17", label, f"confidence fuera de [0.0, 1.0] o no numérica: {conf!r}")
            else:
                conf_ok = True

        # LINT-16 — verified fecha válida
        if has("verified") and not valid_date(item["verified"]):
            err("LINT-16", label, f"verified no es fecha YYYY-MM-DD válida: {item['verified']!r}")

        # LINT-11 — ttl_days, si presente, = 30
        if has("ttl_days") and item["ttl_days"] != 30:
            err("LINT-11", label, f"ttl_days debe ser 30 (herencia facts.yaml): {item['ttl_days']!r}")

        # ── Reglas por tipo ──
        if atype == "A":
            # LINT-06 — check presente y objeto
            check = item.get("check")
            if not isinstance(check, dict):
                err("LINT-06", label, "type: A requiere 'check' presente y es objeto")
            else:
                # LINT-19 — forma estricta (S-04): solo forma, sin ejecutar
                cmd = check.get("command")
                if "command" not in check:
                    err("LINT-19", label, "check.command ausente (lista estricta, S-04)")
                elif not isinstance(cmd, list) or not cmd:
                    err("LINT-19", label,
                        f"check.command debe ser lista no vacía de args (S-04): {cmd!r}")
            # LINT-08b — status ∈ conjunto A
            if has("status") and status not in A_STATUS:
                err("LINT-08b", label, f"status A fuera de conjunto: {status!r}")
            # LINT-10 — A verified exige confidence 1.0
            if status == "verified" and conf_ok and conf != 1.0:
                err("LINT-10", label,
                    f"type: A + status: verified exige confidence: 1.0 (recibí {conf!r})")
        elif atype == "B":
            # LINT-07 — check prohibido (D3)
            if has("check"):
                err("LINT-07", label, "type: B con check presente (B no es machine-verificable)")
            # LINT-08a — B nunca verified (regla explícita Paso 2)
            if status == "verified":
                err("LINT-08a", label, "type: B con status: verified (D3: B nunca es verified)")
            # LINT-08b — status ∈ conjunto B (verified queda para 08a)
            elif has("status") and status not in B_STATUS:
                err("LINT-08b", label, f"status B fuera de conjunto: {status!r}")

        # LINT-09 — confidence 1.0 ⇒ source system Y type A
        if conf_ok and conf == 1.0:
            fails = []
            if not source_ok or source != "system":
                fails.append("source: system")
            if not type_ok or atype != "A":
                fails.append("type: A")
            if fails:
                err("LINT-09", label, "confidence: 1.0 requiere " + " y ".join(fails))

        # LINT-13 — source system ⇒ type A
        if source_ok and source == "system" and has("type") and atype != "A":
            err("LINT-13", label, f"source: system exige type: A (recibí type: {atype!r})")

        # LINT-14 — source user ⇒ type B (ADVERTENCIA)
        if source_ok and source == "user" and has("type") and atype != "B":
            warn("LINT-14", label, f"source: user con type: {atype!r} — lo que dice el operador es juicio (type: B)")

    return findings


def main():
    path, as_json = parse_args(sys.argv[1:])
    data = load(path)
    findings = evaluate(data)
    errors = sum(1 for f in findings if f["sev"] == "error")
    warnings = sum(1 for f in findings if f["sev"] == "advertencia")

    if as_json:
        print(json.dumps(
            {
                "healthy": errors == 0,
                "errors": errors,
                "warnings": warnings,
                "items": [{"rule": f["rule"], "key": f["key"], "detail": f["detail"]}
                          for f in findings],
            },
            ensure_ascii=False, indent=1))
    else:
        for f in findings:
            print(f'{f["rule"]} {f["key"]} {f["detail"]}')
        if errors:
            print(f"{PROGRAM}: FALLO — {errors} error(es), {warnings} advertencia(s)")
        else:
            print(f"{PROGRAM}: OK — 0 errores, {warnings} advertencia(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""facts_engine.py — Motor declarativo de buffy-verify.

Lee `ai-context/facts_rules.yaml` (catálogo de hechos) y emite una línea TSV por
hecho con el formato del resto de buffy-verify.sh:

    level<TAB>fact<TAB>msg<TAB>id<TAB>target<TAB>real

El bash solo recorre el TSV y lo integra con fact()/contadores — AGREGAR un
hecho nuevo = editar facts_rules.yaml, sin tocar el motor.

Uso:
    python3 facts_engine.py <repo_dir>            # emite TSV por stdout
    python3 facts_engine.py <repo_dir> --json     # emite JSON (debug/tests)
"""
import json
import os
import re
import shutil
import subprocess
import sys

VERSION_RE = re.compile(r"[vV]?(\d+(?:\.\d+){1,3})")
DOC_VERSION_RE = r"(?:^|[\s·|]){name}[^\d]*?[vV]?(\d+(?:\.\d+){{1,3}})"  # .format(name=...) antes de usar

def sh_quote(s):
    """Minimal POSIX quoting (shlex.quote no siempre está disponible)."""
    return "'" + s.replace("'", "'\\''") + "'"

def run_cmd(cmd):
    try:
        out = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return (out.stdout + out.stderr).strip()
    except Exception:
        return ""

def extract_version(text):
    m = VERSION_RE.search(text or "")
    return m.group(1) if m else ""

def doc_version(info_core, name):
    """Versión que INFO-core.md declara para `name` (o '' si no declara)."""
    if not info_core:
        return ""
    m = re.search(DOC_VERSION_RE.format(name=re.escape(name)), info_core, re.IGNORECASE)
    return m.group(1) if m else ""

def is_documented(info_core, name):
    return bool(info_core) and re.search(r"\b" + re.escape(name) + r"\b", info_core, re.IGNORECASE) is not None

def parse_rules(repo_dir):
    rules_file = os.path.join(repo_dir, "ai-context", "facts_rules.yaml")
    try:
        import yaml
        with open(rules_file, encoding="utf-8") as fh:
            data = yaml.safe_load(fh) or {}
    except Exception as exc:
        sys.stderr.write(f"facts_engine: no pude leer {rules_file}: {exc}\n")
        data = {}
    return data.get("version_checks", []), data.get("tool_checks", [])

def main():
    repo_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    as_json = "--json" in sys.argv
    info_core_path = os.path.join(repo_dir, "ai-context", "INFO-core.md")
    try:
        with open(info_core_path, encoding="utf-8") as fh:
            info_core = fh.read()
    except Exception:
        info_core = ""

    version_checks, tool_checks = parse_rules(repo_dir)
    rows = []

    def emit(level, fact, msg, fid="", target="INFO-core.md", real=""):
        rows.append((level, fact, msg, fid, target, real))

    for kind, rules in (("version", version_checks), ("tool", tool_checks)):
        for rule in rules:
            name = rule.get("name", "")
            cmd = rule.get("command", "")
            if not name or not cmd:
                continue

            # Presencia del binario (primer token del comando)
            binary = cmd.split()[0]
            if shutil.which(binary) is None:
                if is_documented(info_core, name):
                    emit("stale", name, f"{name} documentado en INFO-core pero NO instalado",
                         "TOOL_NOT_INSTALLED", "INFO-core.md", "no instalado")
                continue

            out = run_cmd(cmd)
            real_ver = extract_version(out)

            if kind == "version":
                if not real_ver:
                    if is_documented(info_core, name):
                        emit("unknown", name, f"{name} presente pero no pude extraer su versión",
                             "", "INFO-core.md", "")
                    continue
                if is_documented(info_core, name):
                    dv = doc_version(info_core, name)
                    if dv and real_ver != dv:
                        emit("stale", name, f"{name}: doc dice {dv}, sistema tiene {real_ver}",
                             "VERSION_STALE", "INFO-core.md", real_ver)
                    else:
                        emit("verified", name, f"{name} {real_ver} ✓", "", "INFO-core.md", real_ver)
            else:  # tool: solo presencia
                if is_documented(info_core, name):
                    emit("verified", name, f"{name} instalado ✓", "", "INFO-core.md", "instalado")

    if as_json:
        print(json.dumps(
            [{"level": l, "fact": f, "message": m, **({"id": i} if i else {}),
              **({"target": t} if t else {}), **({"real": r} if r else {})}
             for (l, f, m, i, t, r) in rows], ensure_ascii=False, indent=1))
    else:
        for (l, f, m, i, t, r) in rows:
            print("\t".join([l, f, m, i, t, r]))

if __name__ == "__main__":
    main()

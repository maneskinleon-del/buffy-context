#!/usr/bin/env bash
# build-fixture.sh — Fase D1: construye un fixture/corpus experimental congelado.
#
# El benchmark NO debe depender del árbol vivo del repo (evidencia 17D: el corpus
# driftó entre 17C y 17D y rompió la reproducibilidad). Este script congela el
# corpus en scripts/tests/evals/fixtures/<fixture_id>/corpus/ con un manifest.json
# de identidad completa. El corpus_hash es POR CONTENIDO (no mtime), determinista
# entre máquinas. El runner consumirá el fixture vía --fixture (Fase D3, pendiente).
#
# Diseño: FIXTURE-EXPERIMENTAL-DESIGN.md (§3, §5) — Fase D1.
#
# Uso:
#   build-fixture.sh --out <fixture_id> [--include <relpath> …] [--repo <dir>]
#     --out       fixture_id (obligatorio) — se crea scripts/tests/evals/fixtures/<id>/
#     --include   re-incluir un archivo excluido por defecto (p. ej. un distractor:
#                 ai-context/CONTINUE.md, ai-context/memories/MEMORY.md). Repetible.
#     --repo      árbol vivo del que se congela (default: ${REPO_DIR:-$HOME/buffy-context})
#     -h|--help   esta ayuda
#
# Exit: 0 fixture construido · 2 uso inválido o ya existe.
# No toca el runner ni ejecuta ningún EVAL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
REPO="${REPO_DIR:-$HOME/buffy-context}"
OUT=""
INCLUDES=()

usage() { sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out) OUT="${2:?falta fixture_id}"; shift 2 ;;
    --include) INCLUDES+=("${2:?falta relpath}"); shift 2 ;;
    --repo) REPO="${2:?falta dir}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "❌ opción desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$OUT" ]] || { echo "❌ falta --out <fixture_id>" >&2; usage >&2; exit 2; }
[[ -d "$REPO/.git" ]] || [[ -d "$REPO" ]] || { echo "❌ --repo no es un directorio: $REPO" >&2; exit 2; }

FIXTURE_DIR="$FIXTURES_DIR/$OUT"
if [[ -e "$FIXTURE_DIR" ]]; then
  echo "❌ el fixture ya existe: $FIXTURE_DIR (usá otro --out o borrálo a mano)" >&2
  exit 2
fi

# ── params del runner (para config del manifest) — leídos del runner 17C si existe,
#    con defaults que coinciden con el heredoc (verificado 2026-08-15) ──
RUNNER="$SCRIPT_DIR/run-leak-17C.sh"
if [[ -f "$RUNNER" ]]; then
  MODEL=$(grep -oP '^MODEL = "\K[^"]+' "$RUNNER" | head -1) || MODEL="bge-m3"
  N_L=$(grep -oP '^N_L = \K[0-9]+' "$RUNNER" | head -1) || N_L=50
  N_X=$(grep -oP '^N_X = \K[0-9]+' "$RUNNER" | head -1) || N_X=50
  N_S=$(grep -oP '^N_S = \K[0-9]+' "$RUNNER" | head -1) || N_S=50
  P_TOP=$(grep -oP '^P_EXPAND_TOP_K = \K[0-9]+' "$RUNNER" | head -1) || P_TOP=10
  MAXP=$(grep -oP '^MAX_PASSAGES = \K[0-9]+' "$RUNNER" | head -1) || MAXP=400
  BUDGET=$(grep -oP '^BUDGET_TOKENS = \K[0-9]+' "$RUNNER" | head -1) || BUDGET=10400
  RESCUE=$(grep -oP '^RESCUE_LOW = \K[0-9.]+' "$RUNNER" | head -1) || RESCUE=0.545
  EVAL_REF="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
  EVAL_ID=$(python3 -c "import json,sys; print(json.load(open('$EVAL_REF')).get('eval_id',''))" 2>/dev/null || echo "eval-ctx-PC-2026-08-11")
  EVAL_HASH=$(grep -oP '^EVAL_HASH="\K[0-9a-f]+' "$RUNNER" | head -1) || EVAL_HASH=""
  RUNNER_SHA=$(sha256sum "$RUNNER" | awk '{print $1}')
else
  MODEL="bge-m3"; N_L=50; N_X=50; N_S=50; P_TOP=10; MAXP=400; BUDGET=10400
  RESCUE=0.545; EVAL_ID=""; EVAL_HASH=""; RUNNER_SHA=""
fi

mkdir -p "$FIXTURE_DIR"

# ── python: discover corpus (mismo alcance que el runner) + filtro + copia + hash por contenido + manifest ──
REPO="$REPO" OUT="$OUT" FIXTURE_DIR="$FIXTURE_DIR" \
MODEL="$MODEL" N_L="$N_L" N_X="$N_X" N_S="$N_S" P_TOP="$P_TOP" MAXP="$MAXP" BUDGET="$BUDGET" RESCUE="$RESCUE" \
EVAL_ID="$EVAL_ID" EVAL_HASH="$EVAL_HASH" RUNNER_SHA="$RUNNER_SHA" \
python3 - "$REPO" "${INCLUDES[@]}" <<'PY'
import hashlib, json, os, subprocess, sys, time

repo = sys.argv[1]
includes = set(sys.argv[2:])
out = os.environ["OUT"]
fixture_dir = os.environ["FIXTURE_DIR"]
corpus_dir = os.path.join(fixture_dir, "corpus")

# ── exclusión por defecto (diseño §3.2, aprobado 2026-08-15) ──
# exclusions: estado de instancia — NUNCA en un fixture normal
EXCLUSIONS = {
    "ai-context/SESION.md", "ai-context/SESION-archive.md", "ai-context/CONTINUE.md",
    "ai-context/SNAPSHOT.md", "ai-context/facts.yaml", "ai-context/.sync-state",
}
# include_by_default_off: memoria — no entra normalmente, solo con --include explícito
MEMORY_DIRS = ("ai-context/memories/",)

# ── discover_corpus: MISMO alcance que run-leak-17C.sh ──
def discover_corpus(root):
    files = []
    for name in sorted(os.listdir(root)):
        if name.startswith('.'):
            continue
        p = os.path.join(root, name)
        if os.path.isfile(p) and (name.endswith('.md') or name.endswith('.yaml')):
            files.append(name)
    for sub in ('ai-context', 'Knowledge'):
        base = os.path.join(root, sub)
        if not os.path.isdir(base):
            continue
        for dirpath, dirs, fnames in os.walk(base):
            dirs[:] = [d for d in dirs if d != 'deprecated']
            for fn in sorted(fnames):
                if fn.endswith('.md') or fn.endswith('.yaml'):
                    files.append(os.path.relpath(os.path.join(dirpath, fn), root))
    return sorted(set(files))

# ── corpus_hash POR CONTENIDO (diseño §3.4 — determinista, no mtime) ──
def corpus_hash(root, files):
    h = hashlib.sha1()
    for f in sorted(files):
        with open(os.path.join(root, f), 'rb') as fh:
            h.update(b"%s:" % f.encode())
            h.update(fh.read())
            h.update(b"\x00")
    return h.hexdigest()[:16]

def is_excluded(rel):
    if rel in EXCLUSIONS:
        return "exclusion"
    if rel.startswith(MEMORY_DIRS):
        return "memory"
    return None

# 1. descubre el corpus
all_files = discover_corpus(repo)

# 2. filtra exclusiones (salvo --include explícito)
kept, excluded_by_default = [], []
for rel in all_files:
    kind = is_excluded(rel)
    if kind and rel not in includes:
        excluded_by_default.append(rel)
    else:
        kept.append(rel)

# 3. copia preservando relpath
os.makedirs(corpus_dir, exist_ok=True)
n_entries = 0
size_bytes = 0
files_meta = []
for rel in kept:
    src = os.path.join(repo, rel)
    dst = os.path.join(corpus_dir, rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    data = open(src, 'rb').read()
    with open(dst, 'wb') as fh:
        fh.write(data)
    size_bytes += len(data)
    n_entries += sum(1 for ln in data.decode('utf-8', 'replace').splitlines() if ln.strip())
    files_meta.append({"path": rel, "sha256": hashlib.sha256(data).hexdigest()})

# 4. hash por contenido del corpus congelado
corpus_h = corpus_hash(corpus_dir, kept)

# 5. fuente (commit_sha del árbol vivo)
try:
    commit_sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"],
                                capture_output=True, text=True, timeout=10).stdout.strip()
except Exception:
    commit_sha = "?"

# config_hash = sha256 del bloque config canónico (diseño §3.5)
config_block = {
    "model": os.environ["MODEL"],
    "params": {"N_L": int(os.environ["N_L"]), "N_X": int(os.environ["N_X"]), "N_S": int(os.environ["N_S"]),
               "P_EXPAND_TOP_K": int(os.environ["P_TOP"]), "MAX_PASSAGES": int(os.environ["MAXP"]),
               "BUDGET_TOKENS": int(os.environ["BUDGET"]), "RESCUE_LOW": float(os.environ["RESCUE"]),
               "PADS": [4], "LIMIT": 10},
    "variant": "A",
    "dict": {"path": None, "h1_dict_hash": None},
    "eval": {"eval_id": os.environ["EVAL_ID"], "eval_hash": os.environ["EVAL_HASH"]},
    "runner": {"name": "run-leak-17C.sh", "version": os.environ["RUNNER_SHA"]},
}
config_hash = hashlib.sha256(json.dumps(config_block, sort_keys=True, ensure_ascii=False).encode()).hexdigest()

manifest = {
    "fixture_id": out,
    "fixture_version": 1,
    "created_at": time.strftime('%Y-%m-%dT%H:%M:%S'),
    "source": {"repo": os.path.basename(repo), "commit_sha": commit_sha},
    "corpus": {
        "n_files": len(kept),
        "n_entries": n_entries,
        "size_bytes": size_bytes,
        "corpus_hash": corpus_h,
        "files": files_meta,
    },
    "exclusions": sorted(EXCLUSIONS),
    "include_by_default_off": ["ai-context/memories/MEMORY.md", "ai-context/memories/USER.md"],
    "eval": {"eval_id": os.environ["EVAL_ID"], "eval_hash": os.environ["EVAL_HASH"]},
    "config": config_block,
    "config_hash": config_hash,
    "runner": {"name": "run-leak-17C.sh", "version": os.environ["RUNNER_SHA"]},
}

with open(os.path.join(fixture_dir, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, ensure_ascii=False, indent=2)

print("fixture_id      : %s" % out)
print("fuente          : %s @ %s" % (manifest["source"]["repo"], commit_sha[:12]))
print("corpus          : %d archivos / %d bytes / %d líneas" % (len(kept), size_bytes, n_entries))
print("corpus_hash     : %s  (por contenido)" % corpus_h)
print("config_hash     : %s" % config_hash)
print("excluidos (def) : %d (%d por instancia/memoria)" % (len(excluded_by_default),
      sum(1 for r in excluded_by_default if is_excluded(r))))
print("manifest        : %s" % os.path.join(fixture_dir, "manifest.json"))
PY

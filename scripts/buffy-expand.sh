#!/usr/bin/env bash
# buffy-expand.sh — Expansión de candidatos de pasajes (rama P, Paso 13 F2).
# Componente generador del pipeline: cierra el candidate gap que el FTS5 deja
# (Q08/Q06: System.md/CHANGELOG.md entran al pool vía los archivos del router +
# top-K del pool, NO por búsqueda léxica).
#
#   query → buffy-router.sh (kno) → buffy-search.sh (top-K pool)
#         → buffy-expand.sh (rama P F2) → pool expandido de pasajes
#         → buffy-selector.sh (M3) → top-K del contexto
#
# Uso:
#   buffy-expand.sh --kno '["a.md","b.md"]' --pool <file> [--repo DIR] [--top-k 10]
#   buffy-expand.sh --kno '["a.md"]' < pool.json            # pool por stdin
#   buffy-search.sh -l 30 "query" | buffy-expand.sh --kno "$(buffy-router.sh --json "query" | jq .knowledge)"
#
# Opciones:
#   --kno '["path",...]'   archivos del router_knowledge (JSON array)
#   --pool <file>          candidatos del search [{path,lineno,rank}] (default: stdin)
#   --top-k N              top-K archivos del pool fuera de kno (default: 10)
#   --max-passages N       tope operativo de pasajes P (default: 400) — los
#                          archivos kno entran completos; los del pool se
#                          recortan. Guard de coste (tile de archivos enormes
#                          como SESION-archive = 220+ pasajes por archivo).
#   --repo DIR             repo con el corpus (default: $BUFFY_REPO o ~/buffy-context)
#   --json                 salida JSON completa (default: lista de pasajes, una por línea)
#   --help                 esta ayuda
#
# Exit codes:
#   0 → OK · 1 → uso · 2 → entrada inválida
#
# Creado: 2026-08-13 (cierre del candidate gap — integración F2 + M3)
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
ENGINE="$SCRIPT_DIR/lib/expand_passages.py"

KNO=""
POOL_FILE=""
TOP_K=10
MAX_PASSAGES=400
JSON_OUT=false

usage() { sed -n '2,28p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kno) KNO="${2:?falta json}"; shift 2 ;;
    --pool) POOL_FILE="${2:?falta archivo}"; shift 2 ;;
    --top-k) TOP_K="${2:?falta número}"; shift 2 ;;
    --max-passages) MAX_PASSAGES="${2:?falta número}"; shift 2 ;;
    --repo) REPO_DIR="${2:?falta dir}"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "opción desconocida: $1" >&2; exit 1 ;;
  esac
done

[ -f "$ENGINE" ] || { echo "❌ No encuentro el motor: $ENGINE" >&2; exit 2; }

if [ -n "$POOL_FILE" ]; then
  [ -f "$POOL_FILE" ] || { echo "❌ No encuentro --pool: $POOL_FILE" >&2; exit 2; }
  OUT="$(python3 "$ENGINE" --repo "$REPO_DIR" --kno "${KNO:-[]}" --top-k "$TOP_K" \
         --max-passages "$MAX_PASSAGES" --pool "$(cat "$POOL_FILE")" 2>/tmp/buffy-expand.err)" \
    || { RC=$?; cat /tmp/buffy-expand.err >&2; exit "$RC"; }
else
  if [ -t 0 ]; then
    echo "❌ Sin --pool, falta stdin (JSON de candidatos del search)" >&2
    exit 1
  fi
  OUT="$(python3 "$ENGINE" --repo "$REPO_DIR" --kno "${KNO:-[]}" --top-k "$TOP_K" \
         --max-passages "$MAX_PASSAGES" 2>/tmp/buffy-expand.err)" \
    || { RC=$?; cat /tmp/buffy-expand.err >&2; exit "$RC"; }
fi

if [ "$JSON_OUT" = true ]; then
  printf '%s\n' "$OUT"
  exit 0
fi

# Salida humana: una pasaje por línea (path:s-e)
python3 - "$OUT" <<'PY'
import json, sys
D = json.loads(sys.argv[1])
print("📦 Expansión F2 (rama P): %d archivos (%d kno + %d pool) → %d pasajes ventana ±%d"
      % (len(D["expanded_files"]), len(D["kno"]),
         max(0, len(D["expanded_files"]) - len(D["kno"])),
         len(D["passages"]), D["pas_pad"]))
for p in D["passages"]:
    first = p["text"].splitlines()[0][:60] if p["text"].splitlines() else ""
    print("  %s:%d-%d  %s" % (p["path"], p["s"], p["e"], first))
PY
exit 0

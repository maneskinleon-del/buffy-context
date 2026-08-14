#!/usr/bin/env bash
# buffy-selector.sh — Selección M3 (quality-aware) sobre candidatos de búsqueda.
# Componente de selección del pipeline (Rama B adoptada 2026-08-13):
#
#   query → buffy-router.sh (dominio/archivos) → buffy-search.sh (candidatos)
#         → [buffy-expand.sh (rama P/F2)] → buffy-selector.sh (M3) → top-K
#
# Toma una query + pasajes candidatos y devuelve el top-K puntuado con el
# selector M3 (el módulo reutilizable scripts/lib/selector_m3.py, extraído del
# runner 15A bit-a-bit). NO modifica el motor de búsqueda ni el router.
# Con --kno (archivos del router) se encadena la expansión F2 del Paso 13:
# los archivos del router + top-K del pool generan pasajes ventana ±4 que
# cierran el candidate gap (Q08/Q06: System.md/CHANGELOG.md entran al pool).
#
# Uso:
#   buffy-selector.sh --query "..." --candidates <file> [--top-k 10]
#   buffy-selector.sh --query "..." --kno '["a.md"]' [--repo DIR]
#   echo '[{"path": "...", "lineno": 57}, ...]' | buffy-selector.sh --query "..."
#
# Opciones:
#   --query "texto"       consulta del usuario (obligatoria)
#   --candidates <file>   JSON: [{"path","s","e","text"} | {"path","lineno"}]
#                         Si no se pasa, lee JSON de stdin.
#   --kno '["a.md",...]'  archivos del router_knowledge → expansión F2 (rama P)
#                         ANTES del scoring M3. Cierra el candidate gap.
#   --terms '["push",...]' términos de expansión (rama X, Paso 10 H1): se suman
#                         a la query para S1 (bge-m3 puntúa query+términos).
#                         Seteado por buffy-search.sh --expand-query.
#   -l, --limit N         top-k a devolver (default: 10)
#   --theta F             gate S1 de referencia (default: 0.55)
#   --rescue-low F        piso de relevancia ventana de rescate (default: 0.545)
#   --repo DIR            repo con el corpus (default: $BUFFY_REPO o ~/buffy-context)
#   --json                salida JSON cruda del motor (default: humano)
#   --help                esta ayuda
#
# Exit codes:
#   0 → selección OK
#   1 → error de uso
#   2 → entrada inválida
#   3 → Ollama no disponible (bge-m3) — el selector no puede computar S1
#
# Creado: 2026-08-13 (integración M3 al pipeline real)
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
ENGINE="$SCRIPT_DIR/lib/selector_m3.py"

QUERY=""
CANDIDATES=""
KNO=""
TERMS=""
TOP_K=10
MAX_PASSAGES=400
THETA=0.55
RESCUE_LOW=0.545
JSON_OUT=false
EXPAND_BIN="$SCRIPT_DIR/buffy-expand.sh"

usage() { sed -n '2,36p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query) QUERY="${2:?falta query}"; shift 2 ;;
    --candidates) CANDIDATES="${2:?falta archivo}"; shift 2 ;;
    --kno) KNO="${2:?falta json}"; shift 2 ;;
    --terms) TERMS="${2:?falta json}"; shift 2 ;;
    --max-passages) MAX_PASSAGES="${2:?falta número}"; shift 2 ;;
    -l|--limit) TOP_K="${2:?falta número}"; shift 2 ;;
    --theta) THETA="${2:?falta valor}"; shift 2 ;;
    --rescue-low) RESCUE_LOW="${2:?falta valor}"; shift 2 ;;
    --repo) REPO_DIR="${2:?falta dir}"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "opción desconocida: $1" >&2; exit 1 ;;
    *) echo "argumento posicional no soportado: $1" >&2; exit 1 ;;
  esac
done

[ -n "$QUERY" ] || { echo "❌ Falta --query. Uso: buffy-selector.sh --query \"...\" [--candidates file]" >&2; exit 1; }
[ -f "$ENGINE" ] || { echo "❌ No encuentro el motor: $ENGINE" >&2; exit 1; }

# Entrada: --candidates <file> | stdin (JSON)
if [ -n "$CANDIDATES" ]; then
  if [ ! -f "$CANDIDATES" ]; then
    echo "❌ No encuentro --candidates: $CANDIDATES" >&2
    exit 2
  fi
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d,list), "esperaba lista"; print(json.dumps(d))' "$CANDIDATES" >/dev/null 2>&1 \
    || { echo "❌ --candidates no es un JSON de lista válido" >&2; exit 2; }
  INPUT="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1], "passages": json.load(open(sys.argv[2]))}, ensure_ascii=False))' "$QUERY" "$CANDIDATES")"
else
  # stdin: JSON crudo (dict con query+passages, o solo lista de passages)
  if [ -t 0 ]; then
    echo "❌ Sin --candidates, falta stdin (JSON). Uso: ... | buffy-selector.sh --query \"...\"" >&2
    exit 1
  fi
  RAW="$(cat)"
  if echo "$RAW" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert isinstance(d,list)' 2>/dev/null; then
    INPUT="$(python3 -c 'import json,sys; print(json.dumps({"query": sys.argv[1], "passages": json.loads(sys.stdin.read())}, ensure_ascii=False))' "$QUERY" <<<"$RAW")"
  else
    INPUT="$RAW"  # ya es dict con query+passages (se respeta la query del dict si es consistente)
  fi
fi

# ── Expansión F2 (rama P) — si --kno: genera pasajes de los archivos del
# router + top-K del pool (cierra el candidate gap Q08/Q06), los mezcla con
# los candidatos originales y delega el scoring al motor.
if [ -n "$KNO" ]; then
  # (la expansión F2 reconstruye INPUT al final de este bloque)
  # candidatos base: el pool del search (si --candidates, se usa ese; si no,
  # el stdin ya cargado en INPUT[passages])
  BASE_PASSAGES="$(printf '%s' "$INPUT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get("passages", d if isinstance(d,list) else []), ensure_ascii=False))' 2>/dev/null || printf '[]')"
  EXP_OUT="$(printf '%s' "$BASE_PASSAGES" | bash "$EXPAND_BIN" --kno "$KNO" --repo "$REPO_DIR" --top-k "$TOP_K" --max-passages "${MAX_PASSAGES:-400}" --json 2>/tmp/buffy-expand.err)" \
    || { RC=$?; echo "⚠️  expansión falló: $(cat /tmp/buffy-expand.err)" >&2; RC="$RC"; }
  if [ "${EXP_OUT:-}" != "" ] && printf '%s' "$EXP_OUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    INPUT="$(printf '%s' "$EXP_OUT" | python3 -c '
import json, sys
exp = json.load(sys.stdin)
out = {"query": sys.argv[1], "passages": exp["passages"]}
print(json.dumps(out, ensure_ascii=False))
' "$QUERY")"
  fi
fi

# ── Rama X (query expansion H1) — si --terms: se suman a la query para S1
# (el motor concatena query + términos antes de embeddear). Sin efecto en el
# default (sin --terms = comportamiento idéntico).
if [ -n "$TERMS" ]; then
  if printf '%s' "$TERMS" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    INPUT="$(printf '%s' "$INPUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
d["terms"] = json.loads(sys.argv[1])
print(json.dumps(d, ensure_ascii=False))
' "$TERMS")"
  else
    echo "⚠️  --terms no es JSON válido — se ignora" >&2
  fi
fi

OUT="$(printf '%s' "$INPUT" | python3 "$ENGINE" --top-k "$TOP_K" --theta "$THETA" \
      --rescue-low "$RESCUE_LOW" --repo "$REPO_DIR" 2>/tmp/buffy-selector.err)" \
  || { RC=$?; cat /tmp/buffy-selector.err >&2; exit "$RC"; }

if [ "$JSON_OUT" = true ]; then
  # compacto en una línea (robusto para encadenar: search --select --json → router)
  printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), separators=(",",":"), ensure_ascii=False))' 2>/dev/null \
    || printf '%s\n' "$OUT"
  exit 0
fi

# Salida humana: top-K con score + ruta + snippet
echo "🎯 Selector M3 (S1+S2+S3+S4 · gate rescue $RESCUE_LOW · top-$TOP_K)"
python3 - "$OUT" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
sel = d["selected"]
print("   pool: %d pasajes · debajo del piso S1: %d · %s" % (
    d["pool_size"], d["dropped_below_floor"], "%.1fs" % d["elapsed_seconds"]))
for i, p in enumerate(sel, 1):
    first = p["text"].splitlines()[0][:80] if p["text"].splitlines() else ""
    print("  %2d. %s:%d-%d  [score %.3f | s1 %.3f s2 %.3f s3 %.1f s4 %.1f]  %s"
          % (i, p["path"], p["s"], p["e"], p["score"], p["s1"], p["s2"],
             p["s3"], p["s4"], first))
PY
exit 0

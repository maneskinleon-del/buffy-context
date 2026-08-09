#!/usr/bin/env bash
# buffy-memory.sh — Memoria curada persistente estilo Hermes (brecha 2).
# Envuelve scripts/lib/memory_engine.py — DOS stores limitados que persisten
# entre sesiones y se inyectan al inicio como snapshot congelado:
#
#   MEMORY.md (2200 chars) — notas del agente: entorno, convenciones, lecciones
#   USER.md   (1375 chars) — perfil del usuario: preferencias, estilo, hábitos
#
# Uso:
#   buffy-memory.sh list [memory|user]              → entradas numeradas
#   buffy-memory.sh render [memory|user]            → bloque de system prompt
#   buffy-memory.sh stats                           → uso de ambos stores
#   buffy-memory.sh add    [memory|user] "texto"
#   buffy-memory.sh replace [memory|user] "old_text" "nuevo texto"
#   buffy-memory.sh remove  [memory|user] "old_text"
#   buffy-memory.sh batch  [memory|user] 'JSON'
#   buffy-memory.sh --json ...    → stdout JSON puro (máquina)
#   BUFFY_MEM_DIR=/ruta buffy-memory.sh ...   → store alterno (tests/portable)
#
# El agente que la use NUNCA re-lee render mid-sesión: el snapshot se captura
# una vez al inicio (caché de prefijo). Las mutaciones persisten al instante
# y se ven en la próxima sesión.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$SCRIPT_DIR/lib/memory_engine.py"

USAGE="uso: buffy-memory.sh [--json] list|render|stats|add|replace|remove|batch [args...]"

if [[ $# -eq 0 ]]; then
  echo "$USAGE"
  echo "ayuda: buffy-memory.sh --help"
  exit 1
fi

JSON=false
if [[ "$1" == "--json" ]]; then
  JSON=true
  shift
fi

CMD="${1:-}"
shift || true

case "$CMD" in
  -h|--help)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

# ── Target opcional y resto de argumentos ────────────────────────────────
TARGET="memory"
ARGS=("$@")
if [[ ${#ARGS[@]} -ge 1 && ( "${ARGS[0]}" == "memory" || "${ARGS[0]}" == "user" ) ]]; then
  TARGET="${ARGS[0]}"
  ARGS=("${ARGS[@]:1}")
fi

PY_ARGS=()
if [[ "$JSON" == true ]]; then
  PY_ARGS+=(--json)
fi

case "$CMD" in
  list|render|stats)
    PY_ARGS+=("$CMD" --target "$TARGET")
    ;;
  add)
    [[ ${#ARGS[@]} -ge 1 ]] || { echo "uso: buffy-memory.sh add [memory|user] \"texto\"" >&2; exit 2; }
    PY_ARGS+=(add --target "$TARGET" --content "${ARGS[*]}")
    ;;
  replace)
    [[ ${#ARGS[@]} -ge 2 ]] || { echo "uso: buffy-memory.sh replace [memory|user] \"old_text\" \"nuevo texto\"" >&2; exit 2; }
    PY_ARGS+=(replace --target "$TARGET" --old "${ARGS[0]}" --content "${ARGS[*]:1}")

    ;;
  remove)
    [[ ${#ARGS[@]} -ge 1 ]] || { echo "uso: buffy-memory.sh remove [memory|user] \"old_text\"" >&2; exit 2; }
    PY_ARGS+=(remove --target "$TARGET" --old "${ARGS[0]}")
    ;;
  batch)
    [[ ${#ARGS[@]} -ge 1 ]] || { echo "uso: buffy-memory.sh batch [memory|user] 'JSON'" >&2; exit 2; }
    PY_ARGS+=(batch --target "$TARGET" --ops "${ARGS[0]}")
    ;;
  *)
    echo "$USAGE" >&2
    echo "comandos: list | render | stats | add | replace | remove | batch" >&2
    exit 2
    ;;
esac

exec python3 "$ENGINE" "${PY_ARGS[@]}"
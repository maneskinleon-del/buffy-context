#!/usr/bin/env bash
# buffy-continuity.sh — Emite el contenido íntegro de CONTINUE.md como JSON.
#
# Lee ÚNICAMENTE $REPO_DIR/ai-context/CONTINUE.md (fuente canónica — Rama C).
# NO parsea, NO extrae secciones, NO sincroniza, NO toca $HOME. Solo lectura.
#
# Uso:
#   buffy-continuity.sh [--json] [--repo RUTA] [--help]
#
#   --json       (default) Emite JSON a stdout.
#   --repo RUTA  Override de REPO_DIR (para tests).
#   --help       Muestra esta ayuda y exit 0.
#
# Exit codes (HANDOFF contract v4):
#   0  OK (JSON con content emitido)
#   1  not_found      — CONTINUE.md no existe en $REPO_DIR/ai-context/
#   2  unreadable     — existe pero no se puede leer
#   3  empty          — existe, legible, pero está vacío (0 bytes)
#   4  is_directory   — la ruta resuelta es un directorio, no archivo
#   5  internal_error — falló la generación de JSON (ni python3 ni jq)
#
# Creado: 2026-10-17 (MVP buffy_continuity MCP — delegate desde Next)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"

# ─── Argument parsing ────────────────────────────────────────────
while [ $# -gt 0 ]; do
  case "$1" in
    --json|-j)  shift ;;
    --help|-h)
      cat <<'HELP'
buffy-continuity.sh — continuidad operativa: emite el contenido íntegro de CONTINUE.md como JSON

Lee EXCLUSIVAMENTE $REPO_DIR/ai-context/CONTINUE.md (fuente canónica en repo).
No parsea: emite el contenido raw preservando markdown, headers, orden.

Uso:
  buffy-continuity.sh [--json] [--repo RUTA] [--help]

  --json       (default) Emite JSON a stdout.
  --repo RUTA  Override de REPO_DIR (para tests).
  --help       Muestra esta ayuda y exit 0.

Exit codes:
  0  OK
  1  not_found      — CONTINUE.md no existe
  2  unreadable     — no se puede leer
  3  empty          — archivo vacío
  4  is_directory   — la ruta es un directorio
  5  internal_error — no hay python3 ni jq para generar JSON

NOTA: solo lectura. No modifica, no sincroniza, no toca $HOME.
HELP
      exit 0 ;;
    --repo)     REPO_DIR="$2"; shift 2 ;;
    *) echo "Uso: buffy-continuity.sh [--json] [--repo RUTA] [--help]" >&2; exit 1 ;;
  esac
done

CONTINUE_FILE="$REPO_DIR/ai-context/CONTINUE.md"
export CONTINUE_FILE REPO_DIR

# ─── Detect JSON generator ────────────────────────────────────────
HAS_PYTHON3=false
HAS_JQ=false
command -v python3 >/dev/null 2>&1 && HAS_PYTHON3=true
command -v jq >/dev/null 2>&1 && HAS_JQ=true

if [ "$HAS_PYTHON3" = false ] && [ "$HAS_JQ" = false ]; then
  echo '{"error":"internal_error","reason":"necesario python3 o jq","source":"repo"}'
  exit 5
fi

# ─── Helper: emit error JSON ─────────────────────────────────────
emit_error() {
  local err="$1"
  local cf="$CONTINUE_FILE"
  if [ "$HAS_PYTHON3" = true ]; then
    python3 - "$cf" "$err" <<'PYEOF'
import json, os, sys
cf, err = sys.argv[1], sys.argv[2]
d = {"error": err, "path": cf, "source": "repo"}
if err == "empty":
    d["size_bytes"] = 0
print(json.dumps(d, ensure_ascii=False))
PYEOF
  else
    if [ "$err" = "empty" ]; then
      jq -cn --arg path "$cf" --arg err "$err" '{error:$err, path:$path, size_bytes:0, source:"repo"}'
    else
      jq -cn --arg path "$cf" --arg err "$err" '{error:$err, path:$path, source:"repo"}'
    fi
  fi
}

# ─── Verify file — ordered checks (HANDOFF contract v4) ───────────
# 1. is_directory → exit 4
if [ -d "$CONTINUE_FILE" ]; then
  emit_error "is_directory"
  exit 4
fi

# 2. not_found → exit 1
if [ ! -e "$CONTINUE_FILE" ]; then
  emit_error "not_found"
  exit 1
fi

# 3. unreadable → exit 2
if [ ! -r "$CONTINUE_FILE" ]; then
  emit_error "unreadable"
  exit 2
fi

# 4. empty → exit 3
if [ ! -s "$CONTINUE_FILE" ]; then
  emit_error "empty"
  exit 3
fi

# ─── Success: emit raw content (no parsing) ──────────────────────
if [ "$HAS_PYTHON3" = true ]; then
  python3 <<'PYEOF'
import json, os
cf = os.environ['CONTINUE_FILE']
repo = os.environ.get('REPO_DIR', '')
with open(cf, encoding='utf-8') as f:
    content = f.read()
size = os.path.getsize(cf)
lines = content.count('\n')
if content and not content.endswith('\n'):
    lines += 1
data = {
    "source": "repo",
    "path": cf,
    "exists": True,
    "readable": True,
    "size_bytes": size,
    "line_count": lines,
    "content": content,
}
print(json.dumps(data, ensure_ascii=False, indent=2))
PYEOF
else
  size=$(wc -c < "$CONTINUE_FILE")
  lines=$(wc -l < "$CONTINUE_FILE")
  jq -n \
    --arg source "repo" \
    --arg path "$CONTINUE_FILE" \
    --argjson size "$size" \
    --argjson lines "$lines" \
    --rawfile content "$CONTINUE_FILE" \
    '{
      source: $source,
      path: $path,
      exists: true,
      readable: true,
      size_bytes: $size,
      line_count: $lines,
      content: $content,
    }'
fi

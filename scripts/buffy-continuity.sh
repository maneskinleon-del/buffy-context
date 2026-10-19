#!/usr/bin/env bash
# buffy-continuity.sh — Emite la continuidad operativa de Buffy Context como JSON.
#
# Lee ÚNICAMENTE $REPO_DIR/ai-context/CONTINUE.md (fuente canónica).
# NO toca $HOME, no sincroniza, no modifica nada. Solo lectura.
#
# Uso:
#   buffy-continuity.sh [--json] [--repo RUTA] [--help]
#
#   --json       (default) Emite JSON estructurado a stdout.
#   --repo RUTA  Override de REPO_DIR (para tests: apunta a un fixture).
#   --help       Muestra esta ayuda y exit 0.
#
# Exit codes:
#   0  OK (JSON válido emitido)
#   1  argumento inválido
#   2  CONTINUE.md no encontrado en $REPO_DIR/ai-context/
#   3  dependencia de parseo falló (ni python3 ni jq disponible)
#
# Creado: 2026-10-17 (MVP buffy_continuity MCP — delegate desde Next)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"

# ─── Argument parsing ────────────────────────────────────────────
JSON_MODE=true
HELP_MODE=false
REPO_OVERRIDE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --json|-j)  JSON_MODE=true; shift ;;
    --help|-h)  HELP_MODE=true; shift ;;
    --repo)     REPO_OVERRIDE="$2"; REPO_DIR="$2"; shift 2 ;;
    *) echo "Uso: buffy-continuity.sh [--json] [--repo RUTA] [--help]" >&2; exit 1 ;;
  esac
done

if [ "$HELP_MODE" = true ]; then
  cat <<'HELP'
buffy-continuity.sh — continuidad operativa de Buffy Context

Lee ai-context/CONTINUE.md (fuente canónica en repo) y emite JSON estructurado
con: last_checkpoint, resumen, pendientes, stack, inline_checkpoint, etc.

Uso:
  buffy-continuity.sh [--json] [--repo RUTA] [--help]

  --json       (default) Emite JSON a stdout.
  --repo RUTA  Override de REPO_DIR (para tests).
  --help       Muestra esta ayuda y exit 0.

Exit codes:
  0  OK
  1  argumento inválido
  2  CONTINUE.md no encontrado
  3  ni python3 ni jq disponibles

NOTA: solo lectura. No modifica, no sincroniza, no toca $HOME.
HELP
  exit 0
fi

# ─── Locate CONTINUE.md ──────────────────────────────────────────
CONTINUE_FILE="$REPO_DIR/ai-context/CONTINUE.md"

if [ ! -f "$CONTINUE_FILE" ]; then
  echo "Error: CONTINUE.md no encontrado en: $CONTINUE_FILE" >&2
  echo "¿Está clonado buffy-context en la ruta esperada? Diagnóstico: buffy env" >&2
  exit 2
fi

# ─── Detect JSON generator ──────────────────────────────────────
HAS_PYTHON3=false
HAS_JQ=false

if command -v python3 >/dev/null 2>&1; then
  HAS_PYTHON3=true
fi
if command -v jq >/dev/null 2>&1; then
  HAS_JQ=true
fi

if [ "$HAS_PYTHON3" = false ] && [ "$HAS_JQ" = false ]; then
  echo "Error: ni python3 ni jq disponibles — no se puede generar JSON" >&2
  exit 3
fi

# ─── Emit JSON ────────────────────────────────────────────────────
export CONTINUE_FILE
export REPO_DIR

if [ "$HAS_PYTHON3" = true ]; then
  python3 <<'PYEOF'
import json, os

continue_file = os.environ['CONTINUE_FILE']
repo = os.environ.get('REPO_DIR', '')

with open(continue_file, encoding='utf-8') as f:
    content = f.read()

lines = content.split('\n')

def extract_section(section_name):
    in_section = False
    result = []
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('## '):
            header_text = stripped[3:].strip()
            if header_text.lower() == section_name.lower():
                in_section = True
                continue
            if in_section:
                break
        if in_section:
            result.append(line)
    while result and result[-1].strip() == '':
        result.pop()
    return '\n'.join(result)

def extract_list_items(section_name):
    text = extract_section(section_name)
    items = []
    for line in text.split('\n'):
        line = line.strip()
        if line.startswith('- '):
            items.append(line[2:])
    return items

def find_last_structured_checkpoint():
    for line in lines:
        if line.startswith('## CHECKPOINT'):
            return line.strip()
    return None

def find_last_inline_checkpoint():
    last = None
    for line in lines:
        if line.startswith('[CHECKPOINT'):
            last = line.strip()
    return last

last_checkpoint = find_last_structured_checkpoint()
last_inline = find_last_inline_checkpoint()
summary = extract_section('Resumen de la sesión')
pending = extract_list_items('Pendientes para próxima sesión')
stack = extract_section('Stack del usuario')

data = {
    "repo": repo,
    "source_file": "ai-context/CONTINUE.md",
    "last_checkpoint": last_checkpoint,
    "last_inline_checkpoint": last_inline,
    "summary": summary,
    "pending": pending,
    "stack": stack,
    "_info": "continuidad operativa — handoff entre sesiones (instancia local)"
}

print(json.dumps(data, ensure_ascii=False, indent=2))
PYEOF
elif [ "$HAS_JQ" = true ]; then
  last_checkpoint="$(grep '^## CHECKPOINT' "$CONTINUE_FILE" | head -1)"
  last_inline="$(grep '^\[CHECKPOINT' "$CONTINUE_FILE" | tail -1)"
  summary="$(awk '/^## Resumen de la sesión$/{f=1;next}/^## /{f=0}f' "$CONTINUE_FILE" | sed -e :a -e '/^\n*$/{N;ba}' -e 's/\n*$//')"
  pending="$(awk '/^## Pendientes para próxima sesi[oó]n$/{f=1;next}/^## /{f=0}f' "$CONTINUE_FILE" | grep '^- ' | sed 's/^- //' | jq -R . | jq -s .)"
  stack="$(awk '/^## Stack del usuario$/{f=1;next}/^## /{f=0}f' "$CONTINUE_FILE" | sed -e :a -e '/^\n*$/{N;ba}' -e 's/\n*$//')"
  jq -n \
    --arg repo "$REPO_DIR" \
    --arg source_file "ai-context/CONTINUE.md" \
    --arg last_checkpoint "$last_checkpoint" \
    --arg last_inline_checkpoint "$last_inline" \
    --arg summary "$summary" \
    --argjson pending "$pending" \
    --arg stack "$stack" \
    '{
      repo: $repo,
      source_file: $source_file,
      last_checkpoint: $last_checkpoint,
      last_inline_checkpoint: $last_inline_checkpoint,
      summary: $summary,
      pending: $pending,
      stack: $stack,
      _info: "continuidad operativa — handoff entre sesiones (instancia local)"
    }'
fi
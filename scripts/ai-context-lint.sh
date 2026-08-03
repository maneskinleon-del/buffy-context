#!/usr/bin/env bash
# ai-context-lint.sh — valida la estructura de los archivos críticos de ai-context (schema-lite B1).
#
# Los consumidores de ai-context son LLMs que leen markdown: este validador garantiza
# que los archivos SIEMPRE tengan las secciones que el protocolo (LOAD_CONTEXT.md) promete.
# Complementa al doctor (que valida existencia) con validación ESTRUCTURAL.
#
# Archivos y secciones obligatorias:
#   INFO-core.md    → ## Sistema, ## Hardware, ## Reglas personales, ## Estructura de proyectos
#   CONTINUE.md     → ## Resumen de la sesión, ## Pendientes para próxima sesión, ## Stack del usuario
#   LOAD_CONTEXT.md → ## Protocolo obligatorio al iniciar sesión, ## Carga condicional, ## Arquitectura de memoria
#   Front-matter    → si existe (--- ... ---), version semver-lite X.Y (convención de ai-context) o
#                     X.Y.Z, y updated fecha ISO (YYYY-MM-DD)
#
# Uso:
#   bash scripts/ai-context-lint.sh                → valida el repo actual
#   bash scripts/ai-context-lint.sh --repo <dir>   → valida otro checkout (tests/sandbox/CI)
#   bash scripts/ai-context-lint.sh --json         → resumen JSON a stdout (stderr limpio)
#   bash scripts/ai-context-lint.sh --quick        → solo errores, sin detalle por archivo
#   bash scripts/ai-context-lint.sh --help
#
# Exit: 0 sano · 1 errores estructurales · 2 uso.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
JSON=false
QUICK=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO_DIR="$(cd "$2" && pwd)" || exit 2; shift 2 ;;
    --json) JSON=true; shift ;;
    --quick) QUICK=true; shift ;;
    --help)
      sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ai-context-lint: opción desconocida: $1 (usa --help)" >&2
      exit 2
      ;;
  esac
done

AI_CONTEXT="$REPO_DIR/ai-context"
if [ ! -d "$AI_CONTEXT" ]; then
  echo "ai-context-lint: no existe $AI_CONTEXT" >&2
  exit 2
fi

ERRORS=0

# --- helpers ----------------------------------------------------------------
err() {  # <msg>
  ERRORS=$((ERRORS+1))
  if [ "$JSON" = false ] && [ "$QUICK" = false ]; then
    echo "  ERR  $1"
  fi
}

has_section() {  # <archivo> <sección> — true si el archivo contiene la sección (heading 2/3)
  grep -qE "^#{2,3} .*${2}" "$1"
}

check_section() {  # <archivo> <rel> <sección>
  local f="$1" rel="$2" sec="$3"
  if has_section "$f" "$sec"; then
    if [ "$JSON" = false ] && [ "$QUICK" = false ]; then
      echo "  OK   $rel: sección '$sec'"
    fi
  else
    err "$rel: falta sección '$sec' (obligatoria según LOAD_CONTEXT.md)"
  fi
}

# --- validar un archivo con sus secciones obligatorias ----------------------
check_file() {  # <rel> <sección1> <sección2> ...
  local rel="$1"
  shift
  local f="$AI_CONTEXT/$rel"
  local sec
  if [ ! -f "$f" ]; then
    err "$rel: archivo no existe"
    return
  fi
  for sec in "$@"; do
    check_section "$f" "$rel" "$sec"
  done
}

# --- front-matter YAML (si existe) ------------------------------------------
check_frontmatter() {  # <rel>
  local rel="$1"
  local f="$AI_CONTEXT/$rel"
  local first version updated
  first=$(head -1 "$f" 2>/dev/null)
  [ "$first" = "---" ] || return 0   # sin front-matter → no aplica
  if [ "$JSON" = false ] && [ "$QUICK" = false ]; then
    echo "  OK   $rel: front-matter presente"
  fi
  version=$(awk '/^---$/{n++} n==1 && /^version:/{gsub(/^version:[ \t]*/,""); print; exit}' "$f")
  updated=$(awk '/^---$/{n++} n==1 && /^updated:/{gsub(/^updated:[ \t]*/,""); print; exit}' "$f")
  if [ -n "$version" ] && ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
    err "$rel: front-matter version '$version' no es semver-lite (X.Y o X.Y.Z)"
  fi
  if [ -n "$updated" ] && ! printf '%s' "$updated" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}'; then
    err "$rel: front-matter updated '$updated' no es fecha ISO (YYYY-MM-DD)"
  fi
}

# --- ejecutar ---------------------------------------------------------------
if [ "$QUICK" = false ] && [ "$JSON" = false ]; then
  echo "ai-context-lint: validando estructura de ai-context/ ($REPO_DIR)"
fi

# Archivos críticos del protocolo (LOAD_CONTEXT.md los marca SIEMPRE)
check_file "INFO-core.md" "Sistema" "Hardware" "Reglas personales" "Estructura de proyectos"
check_file "CONTINUE.md" "Resumen de la sesión" "Pendientes para próxima sesión" "Stack del usuario"
check_file "LOAD_CONTEXT.md" "Protocolo obligatorio al iniciar sesión" "Carga condicional" "Arquitectura de memoria"

# Front-matter de los archivos que lo usan (perfil + protocolo)
check_frontmatter "INFO-core.md"
check_frontmatter "INFO-full.md"
check_frontmatter "AGENTS.md"
check_frontmatter "README.md"
check_frontmatter "PROJECTS.md"

# --- resumen ----------------------------------------------------------------
if [ "$JSON" = true ]; then
  python3 -c 'import json, sys
repo, errors = sys.argv[1], int(sys.argv[2])
print(json.dumps({"repo": repo, "errors": errors, "healthy": errors == 0}))' "$REPO_DIR" "$ERRORS"
else
  echo
  if [ "$ERRORS" -eq 0 ]; then
    echo "ai-context-lint: OK estructura válida (0 errores)"
  else
    echo "ai-context-lint: FALLO $ERRORS error(es) estructural(es)"
  fi
fi

[ "$ERRORS" -gt 0 ] && exit 1
exit 0

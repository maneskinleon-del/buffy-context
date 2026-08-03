#!/usr/bin/env bash
# changelog-entry.sh — Genera e inserta la entrada de release en el CHANGELOG.
#
# Uso:
#   bash scripts/changelog-entry.sh v1.1.0           → inserta la entrada
#   bash scripts/changelog-entry.sh --dry-run v1.1.0 → imprime sin escribir
#
# La entrada se construye desde git log (commits desde el último tag + archivos
# modificados/creados). Se sanitizan las referencias skills/<nombre> para que el
# doctor no las tome como skills documentadas (drift falso).
#
# Exit: 0 éxito · 1 error de uso o git.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CHANGELOG="ai-context/CHANGELOG.md"
DRY_RUN=false
VERSION=""

for a in "$@"; do
  case "$a" in
    --dry-run) DRY_RUN=true ;;
    *) VERSION="$a" ;;
  esac
done

if [ -z "$VERSION" ] || ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Falta la versión (vX.Y.Z)." >&2
  echo "Uso: $0 [--dry-run] vX.Y.Z" >&2
  exit 1
fi

if [ ! -d .git ]; then
  echo "❌ No es un repo git — no se puede generar la entrada." >&2
  exit 1
fi

TODAY="$(date +%F)"

# Último tag ANCESTRO de HEAD (el rango del log se calcula contra él).
# git describe encuentra el tag reachable más cercano; un sort por versión
# podría elegir un tag de otra rama que no es ancestro → rango roto.
PREV_TAG="$(git describe --tags --abbrev=0 2>/dev/null || true)"

# ── Cambios incluidos (commits desde el último tag) ───────────
ENTRY="### $TODAY — Release $VERSION"
if [ -n "$PREV_TAG" ]; then
  ENTRY+=$'\n\n'"**Cambios incluidos** (commits desde \`$PREV_TAG\`):"
else
  ENTRY+=$'\n\n'"**Cambios incluidos** (historial completo — primer release):"
fi

if [ -n "$PREV_TAG" ]; then
  COMMITS="$(git log --pretty=format:'%s' "$PREV_TAG..HEAD" 2>/dev/null || true)"
else
  COMMITS="$(git log --pretty=format:'%s' -20 HEAD 2>/dev/null || true)"
fi

if [ -z "${COMMITS:-}" ]; then
  ENTRY+=$'\n'"- Sin commits nuevos."
else
  while IFS= read -r c; do
    [ -z "$c" ] && continue
    c="$(printf '%s' "$c" | sed 's|skills/[a-z0-9_-]\+|skills/…|g')"
    ENTRY+=$'\n'"- $c"
  done <<< "$COMMITS"
fi

# ── Archivos modificados/creados ───────────────────────────────
ENTRY+=$'\n\n'"**Archivos modificados/creados:**"
if [ -n "$PREV_TAG" ]; then
  FILES="$(git diff --name-status "$PREV_TAG" HEAD 2>/dev/null || true)"
else
  FILES="$(git ls-files 2>/dev/null | sed 's/^/A\t/' || true)"
fi

if [ -z "${FILES:-}" ]; then
  ENTRY+=$'\n'"- (sin cambios de archivos)"
else
  while IFS=$'\t' read -r st path newpath; do
    [ -z "$path" ] && continue
    case "$st" in
      A)  lbl="creado" ;;
      D)  lbl="eliminado" ;;
      R*) lbl="renombrado"; [ -n "$newpath" ] && path="$newpath" ;;
      *)  lbl="modificado" ;;
    esac
    path="$(printf '%s' "$path" | sed 's|skills/[a-z0-9_-]\+|skills/…|g')"
    ENTRY+=$'\n'"- \`$path\` — $lbl"
  done <<< "$FILES"
fi

ENTRY+=$'\n\n---'

if [ "$DRY_RUN" = true ]; then
  printf '%s\n' "$ENTRY"
  exit 0
fi

# ── Insertar en el CHANGELOG ───────────────────────────────────
if [ ! -f "$CHANGELOG" ]; then
  echo "⚠️  No existe $CHANGELOG — creándolo con cabecera mínima." >&2
  printf '# CHANGELOG.md — Historial de cambios del sistema\n\n' > "$CHANGELOG"
fi

# Insertar tras la línea '# CHANGELOG.md' (primera coincidencia) y actualizar
# el front matter 'updated:' (primera ocurrencia) con la fecha de hoy.
awk -v entry="$ENTRY" -v today="$TODAY" '
  /^updated:/ && !updated_done { print "updated: " today; updated_done=1; next }
  /^# CHANGELOG\.md/ && !inserted { print; print ""; print entry; inserted=1; next }
  { print }
' "$CHANGELOG" > "$CHANGELOG.tmp" && mv "$CHANGELOG.tmp" "$CHANGELOG"

echo "✅ Entrada de release $VERSION insertada en $CHANGELOG."

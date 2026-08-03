#!/usr/bin/env bash
# set-version.sh — Establece la versión del proyecto y crea tag en Git.
#
# Uso:
#   bash scripts/set-version.sh v1.0.0
#
# Valida el formato semver, verifica que la suite pase, genera la entrada de
# release en ai-context/CHANGELOG.md (scripts/changelog-entry.sh), commitea
# VERSION + CHANGELOG, crea un tag anotado y lo pushea (rama main + tag).
#
# Exit: 0 éxito · 1 error (uso, formato, tests, git).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CHANGELOG_FILE="ai-context/CHANGELOG.md"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Uso: $0 <version>"
  echo "Ejemplo: $0 v1.1.0"
  exit 1
fi

# Validar formato semver
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ Versión inválida. Usa formato vX.Y.Z (ej. v1.1.0)"
  exit 1
fi

# No repetir la versión actual
if [ -f VERSION ] && [ "$(cat VERSION)" = "$VERSION" ]; then
  echo "⚠️  VERSION ya contiene $VERSION. Si es un release nuevo, incrementa la versión."
  exit 1
fi

echo "📝 Estableciendo versión $VERSION..."
PREV_VERSION=""
[ -f VERSION ] && PREV_VERSION="$(cat VERSION)"
echo "$VERSION" > VERSION

# Verificar que los tests pasen antes de taggear. Para un release se corre la
# suite COMPLETA (no --quick): los ciclos de sandbox son las regresiones reales.
# (El chequeo de versión duplicada ya ocurrió antes de escribir VERSION.)
echo "🔍 Ejecutando suite completa de tests..."
if ! bash scripts/tests/run-tests.sh; then
  echo "❌ Tests fallaron. No se creará el tag."
  if [ -n "$PREV_VERSION" ]; then
    echo "$PREV_VERSION" > VERSION
    echo "   VERSION restaurado a $PREV_VERSION"
  else
    rm -f VERSION
  fi
  exit 1
fi

# Generar la entrada de release en el CHANGELOG (git log desde el último tag).
echo "📝 Generando entrada de CHANGELOG..."
CHANGELOG_UPDATED=false
if bash scripts/changelog-entry.sh "$VERSION"; then
  CHANGELOG_UPDATED=true
else
  echo "⚠️  No se pudo generar la entrada de CHANGELOG — el release continúa sin ella."
fi

# Commit + tag + push (VERSION + CHANGELOG en el mismo commit)
git add VERSION
[ "$CHANGELOG_UPDATED" = true ] && git add "$CHANGELOG_FILE"
if ! git commit -m "chore: release $VERSION"; then
  echo "❌ Commit falló. Restaurando..."
  if [ -n "$PREV_VERSION" ]; then
    echo "$PREV_VERSION" > VERSION
    echo "   VERSION restaurado a $PREV_VERSION"
  else
    rm -f VERSION
  fi
  [ "$CHANGELOG_UPDATED" = true ] && git checkout -- "$CHANGELOG_FILE"
  exit 1
fi
git tag -a "$VERSION" -m "Release $VERSION"
git push origin main "$VERSION"

echo "✅ Versión $VERSION creada y pusheada."

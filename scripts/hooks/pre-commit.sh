#!/usr/bin/env bash
set -u
# pre-commit.sh — ejecuta la suite de tests antes de cada commit.
#
# Versionado en el repo (NO perder en clones). Instalar con el installer
# (escribe este archivo en .git/hooks/pre-commit con el shebang REAL del sistema):
#   bash scripts/hooks/install.sh
#
# Por defecto corre la suite en modo --quick (sin ciclos de sandbox, rápido).
# Para un commit puntual con la suite completa:
#   BUFFY_HOOK_FULL=1 git commit
# Saltar los tests puntualmente: git commit --no-verify (no recomendado).
#
# Exit: 0 si todos los tests pasan · 1 si hay fallos (aborta el commit).

# Resolver el repo raíz aunque el hook se invoque desde .git/hooks (symlink)
HOOK_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  HOOK_SRC="$(readlink -f "$HOOK_SRC" 2>/dev/null || echo "$HOOK_SRC")"
fi
REPO_DIR="$(cd "$(dirname "$HOOK_SRC")/../.." && pwd)"
RUNNER="$REPO_DIR/scripts/tests/run-tests.sh"

if [ ! -f "$RUNNER" ]; then
  echo "❌ No encuentro la suite de tests en $RUNNER" >&2
  echo "   (¿checkout de buffy-context incompleto?) — commit abortado." >&2
  exit 1
fi

if [ "${BUFFY_HOOK_FULL:-}" = "1" ]; then
  echo "🔍 Ejecutando suite COMPLETA (BUFFY_HOOK_FULL=1)..."
  OUT=$(bash "$RUNNER" 2>&1)
else
  echo "🔍 Ejecutando suite (--quick)..."
  OUT=$(bash "$RUNNER" --quick 2>&1)
fi
RC=$?
echo "$OUT" | tail -40

if [ "$RC" -ne 0 ]; then
  echo ""
  echo "❌ Tests fallaron — commit ABORTADO."
  echo "   Usa 'git commit --no-verify' para saltar (no recomendado)."
  exit 1
fi

echo ""
echo "✅ Todos los tests pasaron."

#!/usr/bin/env bash
# install.sh — instala el pre-commit hook con el shebang CORRECTO para este sistema.
#
# Por qué: git ejecuta los hooks con exec directo, resolviendo el shebang del
# archivo. En Termux `/usr/bin/env` no existe (bash real: $PREFIX/bin/bash), así
# que un shebang `#!/usr/bin/env bash` falla con "cannot exec ... No such file".
# Este installer resuelve la ruta real de bash y genera .git/hooks/pre-commit
# con ese shebang, funcionando en Termux y en Linux (Arch, etc.).
#
# Uso: bash scripts/hooks/install.sh  (NO ejecutar ./install.sh directo en Termux:
# este script conserva #!/usr/bin/env bash y depende de la invocación explícita con bash)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../scripts/hooks
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"                   # repo raíz
HOOK_SRC="$SCRIPT_DIR/pre-commit.sh"
BASH_PATH="$(command -v bash 2>/dev/null || echo /bin/bash)"

if [ ! -f "$HOOK_SRC" ]; then
  echo "❌ No encuentro $HOOK_SRC" >&2
  exit 1
fi

mkdir -p "$REPO_DIR/.git/hooks"
{
  echo "#!$BASH_PATH"
  tail -n +2 "$HOOK_SRC"
} > "$REPO_DIR/.git/hooks/pre-commit"
chmod +x "$REPO_DIR/.git/hooks/pre-commit"

echo "✅ Hook instalado: $REPO_DIR/.git/hooks/pre-commit"
echo "   shebang: #!$BASH_PATH"
echo "   (corre scripts/tests/run-tests.sh en cada commit; saltar con --no-verify)"

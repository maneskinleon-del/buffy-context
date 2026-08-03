#!/usr/bin/env bash
# install.sh — instala/desinstala/verifica el pre-commit hook.
#
# Por qué escribe el archivo (y no un symlink): git ejecuta los hooks con exec
# directo, resolviendo el shebang del archivo. En Termux `/usr/bin/env` no existe
# (bash real: $PREFIX/bin/bash), así que un shebang `#!/usr/bin/env bash` falla
# con "cannot exec ... No such file". Este installer resuelve la ruta real de
# bash (command -v bash) y genera .git/hooks/pre-commit con ese shebang,
# funcionando en Termux y en Linux (Arch, etc.).
#
# Uso: bash scripts/hooks/install.sh [OPCIÓN]
#   --install    Instala el hook (predeterminado)
#   --uninstall  Elimina el hook
#   --check      Verifica que el hook esté instalado y con el shebang correcto
#   --force      Sobrescribe sin preguntar (o sin terminal interactiva)
#   --no-test    Instala sin ejecutar la verificación (corre la suite --quick)
#   --help       Muestra esta ayuda
#
# NOTA: invocar SIEMPRE con `bash scripts/hooks/install.sh` (este script
# conserva #!/usr/bin/env bash y depende de la invocación explícita con bash).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../scripts/hooks
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"                   # repo raíz
HOOK_SRC="$SCRIPT_DIR/pre-commit.sh"
BASH_PATH="$(command -v bash 2>/dev/null || echo /bin/bash)"
HOOK_TARGET="$REPO_DIR/.git/hooks/pre-commit"

show_help() {
  # Solo líneas de comentario del header (hasta la primera línea no-comentario)
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print } NR>1 && !/^#/ { exit }' "${BASH_SOURCE[0]}"
}

ACTION=install
FORCE=false
RUN_TEST=true

while [ $# -gt 0 ]; do
  case "$1" in
    --install)   ACTION=install ;;
    --uninstall) ACTION=uninstall ;;
    --check)     ACTION=check ;;
    --force)     FORCE=true ;;
    --no-test)   RUN_TEST=false ;;
    --help)      show_help; exit 0 ;;
    *)
      echo "❌ Opción desconocida: $1" >&2
      show_help
      exit 1 ;;
  esac
  shift
done

if [ ! -f "$HOOK_SRC" ]; then
  echo "❌ No encuentro $HOOK_SRC" >&2
  exit 1
fi

case "$ACTION" in
  install)
    if [ -f "$HOOK_TARGET" ]; then
      if [ "$FORCE" = true ]; then
        : # sobrescribir sin preguntar
      elif [ -t 0 ]; then
        read -r -p "⚠️  El hook ya existe. ¿Sobrescribir? (y/N) " ans
        case "$ans" in
          y|Y) : ;;
          *) echo "❌ Instalación cancelada."; exit 0 ;;
        esac
      else
        echo "❌ El hook ya existe en $HOOK_TARGET" >&2
        echo "   Usa --force para sobrescribir (o --check para verificar)." >&2
        exit 1
      fi
    fi

    mkdir -p "$REPO_DIR/.git/hooks"
    {
      echo "#!$BASH_PATH"
      tail -n +2 "$HOOK_SRC"
    } > "$HOOK_TARGET"
    chmod +x "$HOOK_TARGET"

    echo "✅ Hook instalado: $HOOK_TARGET"
    echo "   shebang: #!$BASH_PATH"
    echo "   (corre scripts/tests/run-tests.sh --quick en cada commit; saltar con --no-verify)"

    if [ "$RUN_TEST" = true ]; then
      echo "🔍 Verificando hook (corre la suite --quick)..."
      if bash "$HOOK_TARGET" >/dev/null 2>&1; then
        echo "✅ Hook funciona correctamente."
      else
        echo "⚠️  El hook falló. Revisa la configuración." >&2
      fi
    fi
    ;;

  uninstall)
    if [ -f "$HOOK_TARGET" ]; then
      rm -f "$HOOK_TARGET"
      echo "✅ Hook desinstalado."
    else
      echo "ℹ️  No hay hook instalado."
    fi
    ;;

  check)
    if [ -f "$HOOK_TARGET" ] && [ -x "$HOOK_TARGET" ]; then
      FIRST=$(head -1 "$HOOK_TARGET")
      if [ "$FIRST" = "#!$BASH_PATH" ]; then
        echo "✅ Hook instalado y con el shebang correcto: $FIRST"
        exit 0
      else
        echo "⚠️  Hook existe pero su shebang ($FIRST) no coincide con bash actual ($BASH_PATH)." >&2
        echo "   Reinstala: bash scripts/hooks/install.sh --force" >&2
        exit 1
      fi
    else
      echo "❌ Hook no instalado. Corre: bash scripts/hooks/install.sh" >&2
      exit 1
    fi
    ;;
esac

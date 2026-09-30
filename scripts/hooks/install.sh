#!/usr/bin/env bash
# install.sh — instala/desinstala/verifica los hooks pre-commit y pre-push.
#
# Por qué escribe el archivo (y no un symlink): git ejecuta los hooks con exec
# directo, resolviendo el shebang del archivo. En Termux `/usr/bin/env` no existe
# (bash real: $PREFIX/bin/bash), así que un shebang `#!/usr/bin/env bash` falla
# con "cannot exec ... No such file". Este installer resuelve la ruta real de
# bash (command -v bash) y genera .git/hooks/<hook> con ese shebang,
# funcionando en Termux y en Linux (Arch, etc.).
#
# Hooks gestionados:
#   pre-commit  (pre-commit.sh) — suite --quick en cada commit
#   pre-push    (pre-push.sh)   — ci-sim --quick: simula CI en clone fresco
#                                 antes de pushear (instancia 4b de
#                                 SIGNAL-STATE-COUPLING-FAILURES.md: quick
#                                 verde no implica CI verde). Salteable con
#                                 git push --no-verify.
#
# Uso: bash scripts/hooks/install.sh [OPCIÓN]
#   --install    Instala ambos hooks (predeterminado)
#   --uninstall  Elimina ambos hooks
#   --check      Verifica que estén instalados y con el shebang correcto
#   --force      Sobrescribe sin preguntar (o sin terminal interactiva)
#   --no-test    Instala sin ejecutar la verificación (corre suite --quick)
#   --help       Muestra esta ayuda
#
# NOTA: invocar SIEMPRE con `bash scripts/hooks/install.sh` (este script
# conserva #!/usr/bin/env bash y depende de la invocación explícita con bash).

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../scripts/hooks
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"                   # repo raíz
BASH_PATH="$(command -v bash 2>/dev/null || echo /bin/bash)"
# Cada entrada: "nombre-hook|fuente-versionada"
HOOKS=("pre-commit|pre-commit.sh" "pre-push|pre-push.sh")
hook_target() { printf '%s/.git/hooks/%s' "$REPO_DIR" "${1%%|*}"; }
hook_src()    { printf '%s/%s' "$SCRIPT_DIR" "${1##*|}"; }

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

for entry in "${HOOKS[@]}"; do
  if [ ! -f "$(hook_src "$entry")" ]; then
    echo "❌ No encuentro $(hook_src "$entry")" >&2
    exit 1
  fi
done

case "$ACTION" in
  install)
    mkdir -p "$REPO_DIR/.git/hooks"
    for entry in "${HOOKS[@]}"; do
      hname="${entry%%|*}"
      target="$(hook_target "$entry")"
      src="$(hook_src "$entry")"
      if [ -f "$target" ]; then
        if [ "$FORCE" = true ]; then
          : # sobrescribir sin preguntar
        elif [ -t 0 ]; then
          read -r -p "⚠️  $hname ya existe. ¿Sobrescribir? (y/N) " ans
          case "$ans" in
            y|Y) : ;;
            *) echo "❌ Instalación cancelada."; exit 0 ;;
          esac
        else
          echo "❌ El hook $hname ya existe en $target" >&2
          echo "   Usa --force para sobrescribir (o --check para verificar)." >&2
          exit 1
        fi
      fi

      {
        echo "#!$BASH_PATH"
        tail -n +2 "$src"
      } > "$target"
      chmod +x "$target"
      echo "✅ Hook instalado: $target (shebang: #!$BASH_PATH)"
    done

    echo "   pre-commit: corre scripts/tests/run-tests.sh --quick en cada commit"
    echo "   pre-push:   corre scripts/tests/ci-sim.sh --quick antes de pushear"
    echo "   (ambos saltables con --no-verify)"

    if [ "$RUN_TEST" = true ]; then
      echo "🔍 Verificando hook pre-commit (corre la suite --quick)..."
      if bash "$(hook_target "pre-commit|x")" >/dev/null 2>&1; then
        echo "✅ Hook pre-commit funciona correctamente."
      else
        echo "⚠️  El hook pre-commit falló. Revisa la configuración." >&2
      fi
    fi
    ;;

  uninstall)
    for entry in "${HOOKS[@]}"; do
      target="$(hook_target "$entry")"
      if [ -f "$target" ]; then
        rm -f "$target"
        echo "✅ ${entry%%|*} desinstalado."
      else
        echo "ℹ️  ${entry%%|*} no estaba instalado."
      fi
    done
    ;;

  check)
    rc=0
    for entry in "${HOOKS[@]}"; do
      hname="${entry%%|*}"
      target="$(hook_target "$entry")"
      if [ -f "$target" ] && [ -x "$target" ]; then
        FIRST=$(head -1 "$target")
        if [ "$FIRST" = "#!$BASH_PATH" ]; then
          echo "✅ $hname instalado y con el shebang correcto: $FIRST"
        else
          echo "⚠️  $hname existe pero su shebang ($FIRST) no coincide con bash actual ($BASH_PATH)." >&2
          echo "   Reinstala: bash scripts/hooks/install.sh --force" >&2
          rc=1
        fi
      else
        echo "❌ $hname no instalado. Corre: bash scripts/hooks/install.sh" >&2
        rc=1
      fi
    done
    exit $rc
    ;;
esac

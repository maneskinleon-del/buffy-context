#!/usr/bin/env bash
# ci-sim.sh — simula las condiciones exactas de CI en local (2026-09-30).
#
# Lección (instancia 4b de SIGNAL-STATE-COUPLING-FAILURES.md): `--quick`
# corre contra el working tree (ve CONTINUE.md, memorias, overrides .local)
# y CI corre contra un clone fresco (no ve nada de eso) → `--quick` verde es
# condición necesaria pero NO suficiente para CI verde. La única forma de
# saberlo sin pushear es simular el clone. Este script hace exactamente eso:
#
#   1. Clone file:// del repo con historial completo (ci.yml usa
#      fetch-depth: 0; en paths locales git ignora --depth → file://).
#   2. Overlay de los cambios SIN commitear del working tree — la simulación
#      ve exactamente lo que vería CI tras un commit + push ahora (en CI no
#      hay overlay porque todo está commiteado: la sim es estrictamente más
#      estricta). Los untracked se omiten: CI tampoco los ve.
#   3. Suite (full por defecto, --quick opcional) con HOME aislado — el
#      runner de Actions no tiene el $HOME del operador — y SIN Ollama:
#      OLLAMA_URL apuntada a un puerto muerto. En CI no existe Ollama, así
#      que ollama_up() siempre falla allá y los tests Ollama-dependientes
#      skippean con su contrato honesto. Sin esto, la sim ve el Ollama
#      LOCAL del operador — servicio de estado variable minuto a minuto
#      (semi-wedged, instancia 1) — y el gate deja pasar/cortar según el
#      pico de turno: el hook pre-push abortó su propio push inaugural por
#      exactamente eso. Los tests con Ollama corren como bonus en corridas
#      locales directas (bash scripts/tests/run-tests.sh), fuera de ci-sim.
#
# Uso:
#   bash scripts/tests/ci-sim.sh            → suite full en clone fresco
#   bash scripts/tests/ci-sim.sh --quick    → rápido, para hook pre-push
# Exit: el de la suite simulada (0 = lo que corra en CI va a pasar).

set -eu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
QUICK=false
[ "${1:-}" = "--quick" ] && QUICK=true

command -v git >/dev/null 2>&1 || { echo "ci-sim: git no disponible" >&2; exit 2; }

SIM="$(mktemp -d "${TMPDIR:-/tmp}/buffy-ci-sim.XXXXXX")"
trap 'rm -rf "$SIM"' EXIT

# 1. Clone fresco con historial completo
git clone -q file://"$REPO_DIR" "$SIM/repo"
mkdir -p "$SIM/home"

# 2. Overlay: cambios tracked sin commitear (M/A/D/R — como los pushearía
#    el próximo commit). Untracked (??) se omite: CI tampoco los vería.
cd "$REPO_DIR"
git status --porcelain | grep -v '^??' | while IFS= read -r line; do
  status="${line:0:2}"
  path="${line:3}"
  if [[ "$path" == *" -> "* ]]; then
    # rename: formato porcelain "R  NUEVA -> VIEJA"; el clone ya tiene VIEJA
    new="${path%% -> *}"
    mkdir -p "$SIM/repo/$(dirname "$new")"
    cp "$REPO_DIR/$new" "$SIM/repo/$new"
  elif [[ "$status" == *D* ]]; then
    rm -f "$SIM/repo/$path"
  else
    mkdir -p "$SIM/repo/$(dirname "$path")"
    cp "$REPO_DIR/$path" "$SIM/repo/$path"
  fi
done

# 3. Suite simulada: HOME aislado + OLLAMA_URL muerta (reproducir el runner)
#    + stdin cerrado: CI corre sin stdin, pero el hook pre-push hereda de git
#    las ref-lines del push — si la suite las hereda, el router sin --message
#    las LEE como mensaje (exit 0 en vez de 1). Segundo fallo del hook
#    inaugural, misma raíz: la sim debe reproducir el entorno COMPLETO del
#    runner, no solo el filesystem.
cd "$SIM/repo"
export HOME="$SIM/home"
export OLLAMA_URL="http://127.0.0.1:1"
set +e
if [ "$QUICK" = true ]; then
  bash scripts/tests/run-tests.sh --quick </dev/null
else
  bash scripts/tests/run-tests.sh </dev/null
fi
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "ci-sim: ✅ clone fresco + working tree → verde (CI debería pasar)"
else
  echo "ci-sim: ❌ fallaría en CI (rc=$rc) — ver arriba" >&2
fi
exit "$rc"

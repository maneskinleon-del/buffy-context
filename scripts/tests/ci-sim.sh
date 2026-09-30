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
#      runner de Actions no tiene el $HOME del operador.
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

# 3. Suite simulada con HOME aislado
cd "$SIM/repo"
if [ "$QUICK" = true ]; then
  set +e
  HOME="$SIM/home" bash scripts/tests/run-tests.sh --quick
else
  set +e
  HOME="$SIM/home" bash scripts/tests/run-tests.sh
fi
rc=$?
if [ "$rc" -eq 0 ]; then
  echo "ci-sim: ✅ clone fresco + working tree → verde (CI debería pasar)"
else
  echo "ci-sim: ❌ fallaría en CI (rc=$rc) — ver arriba" >&2
fi
exit "$rc"

#!/usr/bin/env bash
# pre-push — simula CI en clone fresco antes de pushear (2026-09-30).
#
# Por qué existe (instancia 4b de SIGNAL-STATE-COUPLING-FAILURES.md):
# `--quick` corre contra el working tree y CI corre contra un clone fresco;
# quick verde no implica CI verde. El costo de descubrirlo en Actions es
# ~1 min de espera + run rojo; aquí son ~5-20s en local.
#
# Salteable conscientemente: git push --no-verify
# Versionado en scripts/hooks/ (instalado con: bash scripts/hooks/install.sh).

echo "🔍 pre-push: simulando CI en clone fresco (ci-sim --quick)..."
bash "$(git rev-parse --show-toplevel)/scripts/tests/ci-sim.sh" --quick
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "" >&2
  echo "❌ pre-push: la suite fallaría en CI. Push abortado." >&2
  echo "   (salteo conscientemente con: git push --no-verify)" >&2
  exit 1
fi
exit 0

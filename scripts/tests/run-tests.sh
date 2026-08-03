#!/usr/bin/env bash
# run-tests.sh — runner único de la suite de tests de buffy-context.
# Bash puro (bats opcional, no requerido). Recupera los checks doctor/repair/agent
# validados en desarrollo (18/18) como tests versionados.
#
# Uso:
#   bash scripts/tests/run-tests.sh            → suite completa
#   bash scripts/tests/run-tests.sh --json     → resumen en JSON (CI/protocolo)
#   bash scripts/tests/run-tests.sh --quick    → salta los ciclos de sandbox (rápido, para hooks/CI)
#   bash scripts/tests/run-tests.sh NOMBRE     → solo tests cuyo nombre contiene NOMBRE
#
# Exit: 0 si todos pasan · 1 si hay fallos.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../scripts/tests
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"                        # .../scripts
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"                          # repo raíz
JSON_SUMMARY=false
QUICK_MODE=false
FILTER=""
for a in "$@"; do
  case "$a" in
    --json) JSON_SUMMARY=true ;;
    --quick) QUICK_MODE=true ;;
    *) FILTER="$a" ;;
  esac
done

# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"
# shellcheck source=test-doctor.sh
source "$SCRIPT_DIR/test-doctor.sh"
# shellcheck source=test-repair.sh
source "$SCRIPT_DIR/test-repair.sh"
# shellcheck source=test-agent.sh
source "$SCRIPT_DIR/test-agent.sh"
# shellcheck source=test-runner.sh
source "$SCRIPT_DIR/test-runner.sh"
# shellcheck source=test-changelog.sh
source "$SCRIPT_DIR/test-changelog.sh"
# shellcheck source=test-skill-lint.sh
source "$SCRIPT_DIR/test-skill-lint.sh"
# shellcheck source=test-ai-context-lint.sh
source "$SCRIPT_DIR/test-ai-context-lint.sh"
# shellcheck source=test-common.sh
source "$SCRIPT_DIR/test-common.sh"
# shellcheck source=test-router.sh
source "$SCRIPT_DIR/test-router.sh"

trap teardown_sandbox EXIT

echo "🔍 Suite de tests buffy-context — $(basename "$REPO_DIR")"
echo "   bash puro (bats no requerido) · python3 para asserts JSON"
[ -n "$FILTER" ] && echo "   filtro: '$FILTER'"
[ "$QUICK_MODE" = true ] && echo "   modo --quick: sin ciclos de sandbox"
[ "$QUICK_MODE" = true ] && [ -n "$FILTER" ] && echo "   (el filtro se aplica igual en --quick)"

# ── 0. Sintaxis previa (todos los scripts) ─────────────────
suite "Sintaxis (bash -n)"
for s in buffy-doctor.sh buffy-repair.sh buffy-agent.sh buffy-router.sh buffy-context.sh set-version.sh migrate-system.sh changelog-entry.sh skill-lint.sh ai-context-lint.sh; do
  if bash -n "$SCRIPTS_DIR/$s" 2>/dev/null; then
    ok "bash -n $s"
  else
    bad "bash -n $s"
  fi
done
for h in install.sh pre-commit.sh; do
  if bash -n "$SCRIPTS_DIR/hooks/$h" 2>/dev/null; then
    ok "bash -n hooks/$h"
  else
    bad "bash -n hooks/$h"
  fi
done

# ── 1. Descubrir y ejecutar los tests ──────────────────────
TESTS=$(declare -F | awk '{print $3}' | grep '^test_' | sort)
for t in $TESTS; do
  if [ -n "$FILTER" ] && ! echo "$t" | grep -Fq "$FILTER"; then
    continue
  fi
  # --quick: salta cualquier test que use el sandbox (copia del repo = lo lento).
  # Heurística automática: solo llamadas REALES (setup_sandbox al inicio de línea),
  # no meras menciones del string en comentarios/asserts. OJO: declare -f añade
  # un ';' final a cada comando, así que el patrón tolera [;] opcional.
  if [ "$QUICK_MODE" = true ] && declare -f "$t" | grep -qE '^[[:space:]]*setup_sandbox[[:space:];]*$'; then
    [ -z "$FILTER" ] && echo "  SKIP $t (sandbox — modo --quick)"
    continue
  fi
  "$t"
done

# ── 2. Resumen ─────────────────────────────────────────────
echo
echo "═══════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  if [ "$QUICK_MODE" = true ]; then
    echo "RESULTADO: $PASS OK / 0 FAIL — ✅ SUITE COMPLETA (--quick)"
  else
    echo "RESULTADO: $PASS OK / 0 FAIL — ✅ SUITE COMPLETA"
  fi
  echo "═══════════════════════════════════"
  if [ "$JSON_SUMMARY" = true ]; then
    printf '{"suite":"buffy-context","passed":%s,"failed":0,"quick":%s,"healthy":true}\n' "$PASS" "$QUICK_MODE"
  fi
  exit 0
else
  if [ "$QUICK_MODE" = true ]; then
    echo "RESULTADO: $PASS OK / $FAIL FAIL — ❌ HAY FALLOS (--quick)"
  else
    echo "RESULTADO: $PASS OK / $FAIL FAIL — ❌ HAY FALLOS"
  fi
  echo "═══════════════════════════════════"
  if [ "$JSON_SUMMARY" = true ]; then
    printf '{"suite":"buffy-context","passed":%s,"failed":%s,"quick":%s,"healthy":false}\n' "$PASS" "$FAIL" "$QUICK_MODE"
  fi
  exit 1
fi

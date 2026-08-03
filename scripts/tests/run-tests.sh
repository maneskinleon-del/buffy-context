#!/usr/bin/env bash
# run-tests.sh — runner único de la suite de tests de buffy-context.
# Bash puro (bats opcional, no requerido). Recupera los checks doctor/repair/agent
# validados en desarrollo (18/18) como tests versionados.
#
# Uso:
#   bash scripts/tests/run-tests.sh            → suite completa
#   bash scripts/tests/run-tests.sh --json     → resumen en JSON (CI/protocolo)
#   bash scripts/tests/run-tests.sh NOMBRE     → solo tests cuyo nombre contiene NOMBRE
#
# Exit: 0 si todos pasan · 1 si hay fallos.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # .../scripts/tests
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"                        # .../scripts
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"                          # repo raíz
JSON_SUMMARY=false
FILTER=""
for a in "$@"; do
  case "$a" in
    --json) JSON_SUMMARY=true ;;
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

trap teardown_sandbox EXIT

echo "🔍 Suite de tests buffy-context — $(basename "$REPO_DIR")"
echo "   bash puro (bats no requerido) · python3 para asserts JSON"
[ -n "$FILTER" ] && echo "   filtro: '$FILTER'"

# ── 0. Sintaxis previa (todos los scripts) ─────────────────
suite "Sintaxis (bash -n)"
for s in buffy-doctor.sh buffy-repair.sh buffy-agent.sh buffy-router.sh buffy-context.sh; do
  if bash -n "$SCRIPTS_DIR/$s" 2>/dev/null; then
    ok "bash -n $s"
  else
    bad "bash -n $s"
  fi
done

# ── 1. Descubrir y ejecutar los tests ──────────────────────
TESTS=$(declare -F | awk '{print $3}' | grep '^test_' | sort)
for t in $TESTS; do
  if [ -z "$FILTER" ] || echo "$t" | grep -Fq "$FILTER"; then
    "$t"
  fi
done

# ── 2. Resumen ─────────────────────────────────────────────
echo
echo "═══════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "RESULTADO: $PASS OK / 0 FAIL — ✅ SUITE COMPLETA"
  echo "═══════════════════════════════════"
  if [ "$JSON_SUMMARY" = true ]; then
    printf '{"suite":"buffy-context","passed":%s,"failed":0,"healthy":true}\n' "$PASS"
  fi
  exit 0
else
  echo "RESULTADO: $PASS OK / $FAIL FAIL — ❌ HAY FALLOS"
  echo "═══════════════════════════════════"
  if [ "$JSON_SUMMARY" = true ]; then
    printf '{"suite":"buffy-context","passed":%s,"failed":%s,"healthy":false}\n' "$PASS" "$FAIL"
  fi
  exit 1
fi

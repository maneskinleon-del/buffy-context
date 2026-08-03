#!/usr/bin/env bash
# test-runner.sh — tests del propio runner (run-tests.sh), sourced por run-tests.sh.
# Se autolimitan a invocaciones FILTRADAS (p.ej. 'help') para evitar recursión:
# un run interno con filtro nunca descubre ni ejecuta estos mismos test_runner_*.

test_runner_quick_flag() {
  suite "runner: --quick (invocación filtrada, sin recursión)"
  # Filtro 'help' → solo test_*_help (rápido, read-only) + sintaxis + resumen.
  expect_exit 0 "--quick con filtro help → exit 0" bash "$SCRIPT_DIR/run-tests.sh" --quick help
}

test_runner_quick_skip_logic() {
  suite "runner: --quick salta tests de sandbox"
  local n
  n=$(declare -f test_repair_sandbox_auto_cycle test_agent_sandbox_cycle 2>/dev/null | grep -c 'setup_sandbox')
  if [ "$n" -ge 2 ]; then
    ok "heuristic: los tests de sandbox contienen setup_sandbox ($n refs)"
  else
    bad "heuristic: refs a setup_sandbox=$n (esperado ≥2)"
  fi
  if grep -q 'QUICK_MODE' "$SCRIPT_DIR/run-tests.sh"; then
    ok "runner: soporta QUICK_MODE"
  else
    bad "runner: no soporta QUICK_MODE"
  fi
}

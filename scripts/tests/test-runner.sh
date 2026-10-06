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

test_runner_expect_exit_diagnostics() {
  # C-1: expect_exit descartaba stdout+stderr con >/dev/null 2>&1 → un FAIL no
  # daba pista de por qué. Ahora captura la salida y la muestra en FAIL (y con
  # BUFFY_TEST_VERBOSE=1 / `--verbose` también en verde). Se prueba en subshell
  # para no contaminar los contadores PASS/FAIL del runner real.
  suite "runner: diagnóstico de checks (expect_exit, C-1)"
  local out
  out=$(BUFFY_TEST_VERBOSE=0 bash -c "source \"$SCRIPT_DIR/helpers.sh\"; expect_exit 0 'x' bash -c 'echo DIAGNOSTICO_C1; exit 1'" 2>&1)
  if echo "$out" | grep -q 'DIAGNOSTICO_C1'; then
    ok "FAIL muestra la salida del comando"
  else
    bad "FAIL no muestra la salida del comando: $out"
  fi
  out=$(BUFFY_TEST_VERBOSE=0 bash -c "source \"$SCRIPT_DIR/helpers.sh\"; expect_exit 0 'y' bash -c 'echo RUIDO_VERDE; exit 0'" 2>&1)
  if echo "$out" | grep -q 'RUIDO_VERDE'; then
    bad "check verde sin --verbose no debería imprimir salida"
  else
    ok "check verde sin --verbose descarta salida"
  fi
  out=$(BUFFY_TEST_VERBOSE=1 bash -c "source \"$SCRIPT_DIR/helpers.sh\"; expect_exit 0 'z' bash -c 'echo VERBOSE_C1; exit 0'" 2>&1)
  if echo "$out" | grep -q 'VERBOSE_C1'; then
    ok "BUFFY_TEST_VERBOSE=1 muestra salida en verde"
  else
    bad "BUFFY_TEST_VERBOSE=1 no mostró salida en verde: $out"
  fi
}

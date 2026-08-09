#!/usr/bin/env bash
# test-scale.sh — benchmark P0 en la suite: selección correcta a escala + contaminación negativa.
# Reutiliza bench-scale.sh (script standalone) con --quick para no alargar el runner.
# sourced por run-tests.sh.

# OJO: NO usar `|| true` al capturar OUT — mataría el exit code del benchmark
# (RC siempre 0). El runner no tiene `set -e` aquí, así que la asignación captura
# el RC real del comando.
test_scale() {
  suite "scale: selección correcta a escala (recall + contaminación)"
  local OUT RC
  OUT=$(bash "$SCRIPT_DIR/bench-scale.sh" --quick --json 2>/dev/null)
  RC=$?
  # exit del benchmark (0 = recall==K y leaked==0)
  if [ "$RC" -eq 0 ]; then
    ok "benchmark escala: recall completo + 0 irrelevantes filtrados"
  else
    bad "benchmark escala falló (exit $RC): $OUT"
  fi
  # JSON bien formado y saludable
  jassert "benchmark escala: JSON saludable" "$OUT" \
    'import json,sys; d=json.load(sys.stdin); assert d["healthy"] is True, d'
}

test_scale_adversarial() {
  suite "scale: adversarial léxico (irrelevantes comparten vocabulario)"
  local OUT RC
  OUT=$(bash "$SCRIPT_DIR/bench-scale.sh" --quick --adversarial --json 2>/dev/null)
  RC=$?
  # El adversarial es medición: exit 0 = corrió bien (JSON válido). El recall
  # real queda en healthy del JSON y se reporta como dato, no como gate.
  if [ "$RC" -eq 0 ]; then
    ok "benchmark adversarial corrió (medición válida)"
  else
    bad "benchmark adversarial no corrió (exit $RC): $OUT"
  fi
  jassert "benchmark adversarial: JSON con métricas (recall/leaked/healthy)" "$OUT" \
    'import json,sys; d=json.load(sys.stdin); assert "recall" in d and "irrelevant_leaked" in d and "healthy" in d and "mode" in d, d'
}

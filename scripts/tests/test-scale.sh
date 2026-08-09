#!/usr/bin/env bash
# test-scale.sh — benchmark P0 en la suite: selección correcta a escala + contaminación negativa.
# Reutiliza bench-scale.sh (script standalone) con --quick para no alargar el runner.
# sourced por run-tests.sh.

test_scale() {
  suite "scale: selección correcta a escala (recall + contaminación)"
  local OUT RC
  OUT=$(bash "$SCRIPT_DIR/bench-scale.sh" --quick --json 2>/dev/null) || true
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

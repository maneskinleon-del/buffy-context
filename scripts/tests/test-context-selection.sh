#!/usr/bin/env bash
# test-context-selection.sh — benchmark P0 en la suite: selección de contexto CON router.
# Reutiliza bench-context-selection.sh (script standalone) con --quick.
# Mide el pipeline completo USER REQUEST → router → categoría → search → ranking,
# y verifica la tesis del CONTINUE: FTS5 puro no basta con vocabulario compartido,
# el ROUTER lo resuelve cargando el archivo del dominio correcto.
# sourced por run-tests.sh.

# OJO: NO usar `|| true` al capturar OUT — mataría el exit code del benchmark.
test_context_selection() {
  suite "context-selection: pipeline router→search (selección de contexto)"
  local OUT RC
  OUT=$(bash "$SCRIPT_DIR/bench-context-selection.sh" --quick --json 2>/dev/null)
  RC=$?
  # exit del benchmark (0 = pipeline sano: domain_recall==1, precision==1.00, sin spurious)
  if [ "$RC" -eq 0 ]; then
    ok "benchmark context-selection: pipeline sano (router eligió dominio correcto)"
  else
    bad "benchmark context-selection falló (exit $RC): $OUT"
  fi
  # JSON bien formado y pipeline saludable en modo easy
  jassert "benchmark context-selection: JSON saludable (easy)" "$OUT" \
    'import json,sys; d=json.load(sys.stdin); assert d["pipeline_healthy"] is True, d; assert d["domain_precision"] == 1.0, d; assert d["spurious_categories"] == 0, d; assert "context_chars" in d and "estimated_tokens" in d and "window_utilization" in d, d'
}

test_context_selection_adversarial() {
  suite "context-selection: adversarial léxico (router resuelve lo que FTS5 no puede)"
  local OUT RC
  OUT=$(bash "$SCRIPT_DIR/bench-context-selection.sh" --quick --adversarial --json 2>/dev/null)
  RC=$?
  # El adversarial es medición: exit 0 = corrió bien (JSON válido). La tesis medida:
  # FTS5 puro puede fallar (search_recall bajo / search_leaked alto) PERO el router
  # carga el archivo del dominio correcto → pipeline_healthy se mantiene.
  if [ "$RC" -eq 0 ]; then
    ok "benchmark adversarial corrió (medición válida)"
  else
    bad "benchmark adversarial no corrió (exit $RC): $OUT"
  fi
  jassert "benchmark adversarial: pipeline_healthy true (router cubre el dominio)" "$OUT" \
    'import json,sys; d=json.load(sys.stdin); assert "mode" in d and "search_recall" in d and "search_leaked" in d and "domain_recall" in d, d; assert d["pipeline_healthy"] is True, d'
}

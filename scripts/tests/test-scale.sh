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

# ── Fase 1 del benchmark realista (espec: bench-realistic-FASE1-Search.md) ──
# Estrategia OR (BUFFY_SEARCH_STRATEGY=or): la query natural recupera lo que el
# AND absoluto no puede; el default (sin env) sigue siendo AND byte a byte;
# los tokens técnicos de 3 chars (ADB, API, ...) nunca se descartan por longitud.
# Sandbox chico propio (sin setup_sandbox → corre también en --quick).
search_run() {
  local strat="$1" query="$2" sb="$3"
  if [ -n "$strat" ]; then
    BUFFY_REPO="$sb" XDG_CACHE_HOME="$sb/.cache" BUFFY_SEARCH_STRATEGY="$strat" \
      bash "$SCRIPTS_DIR/buffy-search.sh" -l 10 "$query" 2>/dev/null
  else
    BUFFY_REPO="$sb" XDG_CACHE_HOME="$sb/.cache" \
      bash "$SCRIPTS_DIR/buffy-search.sh" -l 10 "$query" 2>/dev/null
  fi
}

search_st_fixture() {
  local sb="$1"
  mkdir -p "$sb/Knowledge/Android"
  printf '%s\n' \
    "SOLUCION_ADB: móvil ADB conectado USB." \
    "SOLUCION_ADB2: ZTE reinicia sola." \
    "SOLUCION_ADB3: soporte ADB pendrive." > "$sb/Knowledge/Android/ADB.md"
  # pre-índice: la primera llamada reindexa (mensaje) — se hace aparte para que
  # las llamadas de comparación emitan solo resultados.
  BUFFY_REPO="$sb" XDG_CACHE_HOME="$sb/.cache" \
    bash "$SCRIPTS_DIR/buffy-search.sh" -l 5 "precalentamiento" >/dev/null 2>&1 || true
}

test_search_strategy_or() {
  suite "search: estrategia OR (Fase 1 — query natural recupera lo que AND no puede)"
  local SB="${TMPDIR:-/tmp}/buffy-search-or-$$"
  rm -rf "$SB"
  search_st_fixture "$SB"
  local Q="el teléfono ADB no detecta el móvil conectado por USB"
  local OR1 AND1 OR3 DEF
  OR1=$(search_run or "$Q" "$SB")
  AND1=$(search_run and "$Q" "$SB")
  OR3=$(search_run or "el ADB de la casa" "$SB")
  DEF=$(search_run "" "$Q" "$SB")
  if printf '%s' "$OR1" | grep -q "ADB.md:1:"; then
    ok "or recupera la línea del hecho (query natural completa, solo q['text'])"
  else
    bad "or no recuperó el hecho: $OR1"
  fi
  if printf '%s' "$AND1" | grep -q "Sin resultados"; then
    ok "and (baseline) sigue sin resultados para la misma query"
  else
    bad "and devolvió algo (esperado Sin resultados): $AND1"
  fi
  if printf '%s' "$OR3" | grep -q "ADB.md:3:"; then
    ok "token técnico de 3 chars (adb) se conserva y recupera (regla ≥3)"
  else
    bad "adb descartado por longitud (regresión de la regla ≥3): $OR3"
  fi
  if [ "$DEF" = "$AND1" ]; then
    ok "default (sin env) == AND explícito → baseline reproducible byte a byte"
  else
    bad "default ≠ and: la env var cambió el comportamiento por defecto"
  fi
  rm -rf "$SB"
}

test_search_strategy_determinism() {
  suite "search: determinismo de la estrategia OR"
  local SB="${TMPDIR:-/tmp}/buffy-search-or-$$"
  rm -rf "$SB"
  search_st_fixture "$SB"
  local A B
  A=$(search_run or "el móvil conectado por USB" "$SB")
  B=$(search_run or "el móvil conectado por USB" "$SB")
  if [ "$A" = "$B" ]; then
    ok "or: dos corridas con el mismo resultado (mismo seed → mismo top-K)"
  else
    bad "or no es determinista entre corridas"
  fi
  rm -rf "$SB"
}

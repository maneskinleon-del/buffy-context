#!/usr/bin/env bash
# test-common.sh — tests de scripts/lib/common.sh (prioridad C2: BUFFY_HOME opt-in).
# Verifica que el estado generado (ai-context/ + SNAPSHOT) respete BUFFY_HOME cuando
# está definido, y que sin él el comportamiento sea idéntico al actual ($HOME).
# No toca el sandbox → corre también en modo --quick. Fixtures temporales en /tmp.

test_common_helpers_default() {
  suite "common: helpers sin BUFFY_HOME → $HOME"
  local OUT
  OUT=$(bash -c '
    source "$1/lib/common.sh"
    printf "home=%s\nai=%s\nsnap=%s\n" "$(buffy_home)" "$(buffy_ai_context)" "$(buffy_snapshot)"
  ' _ "$SCRIPTS_DIR")
  if echo "$OUT" | grep -q "^home=$HOME$"; then ok "buffy_home = \$HOME (default)"; else bad "buffy_home = \$HOME (got: $OUT)"; fi
  if echo "$OUT" | grep -q "^ai=$HOME/ai-context$"; then ok "buffy_ai_context = \$HOME/ai-context"; else bad "buffy_ai_context = \$HOME/ai-context"; fi
  if echo "$OUT" | grep -q "^snap=$HOME/ai-context/SNAPSHOT.md$"; then ok "buffy_snapshot = \$HOME/ai-context/SNAPSHOT.md"; else bad "buffy_snapshot = \$HOME/ai-context/SNAPSHOT.md"; fi
}

test_common_helpers_custom() {
  suite "common: helpers con BUFFY_HOME alternativo"
  local BH="/tmp/buffy-common-custom-$$"
  local OUT
  OUT=$(BUFFY_HOME="$BH" bash -c '
    source "$1/lib/common.sh"
    printf "home=%s\nai=%s\nsnap=%s\n" "$(buffy_home)" "$(buffy_ai_context)" "$(buffy_snapshot)"
  ' _ "$SCRIPTS_DIR")
  if echo "$OUT" | grep -q "^home=$BH$"; then ok "buffy_home respeta BUFFY_HOME"; else bad "buffy_home respeta BUFFY_HOME (got: $OUT)"; fi
  if echo "$OUT" | grep -q "^ai=$BH/ai-context$"; then ok "buffy_ai_context bajo BUFFY_HOME"; else bad "buffy_ai_context bajo BUFFY_HOME"; fi
  if echo "$OUT" | grep -q "^snap=$BH/ai-context/SNAPSHOT.md$"; then ok "buffy_snapshot bajo BUFFY_HOME"; else bad "buffy_snapshot bajo BUFFY_HOME"; fi
}

test_common_context_genera_en_buffy_home() {
  suite "common: buffy-context.sh escribe SNAPSHOT en BUFFY_HOME"
  local BH="${TMPDIR:-/tmp}/buffy-common-gen-$$"
  rm -rf "$BH"
  trap 'rm -rf "$BH"' RETURN
  local OUT RC
  OUT=$(BUFFY_HOME="$BH" bash "$SCRIPTS_DIR/buffy-context.sh" 2>&1); RC=$?
  if [ "$RC" = "0" ] && echo "$OUT" | grep -q "$BH/ai-context/SNAPSHOT.md"; then
    ok "SNAPSHOT generado en BUFFY_HOME/ai-context"
  else
    bad "SNAPSHOT generado en BUFFY_HOME (rc=$RC: $OUT)"
  fi
  if [ -s "$BH/ai-context/SNAPSHOT.md" ]; then ok "archivo no vacío"; else bad "archivo no vacío"; fi
}

test_common_context_sin_buffy_home() {
  # Sin BUFFY_HOME → usa HOME. Se ejecuta con HOME TEMPORAL (no toca el real:
  # contrato de la suite — el repo/entorno real solo se lee).
  suite "common: sin BUFFY_HOME → escribe en \$HOME (no rompe)"
  local BH="${TMPDIR:-/tmp}/buffy-common-nobh-$$/home"
  rm -rf "$(dirname "$BH")"; mkdir -p "$BH"
  trap 'rm -rf "$(dirname "$BH")"' RETURN
  local OUT RC
  OUT=$(HOME="$BH" env -u BUFFY_HOME bash "$SCRIPTS_DIR/buffy-context.sh" 2>&1); RC=$?
  if [ "$RC" = "0" ] && echo "$OUT" | grep -q "$BH/ai-context/SNAPSHOT.md"; then
    ok "sin BUFFY_HOME → \$HOME/ai-context (en HOME temporal, sin tocar el real)"
  else
    bad "sin BUFFY_HOME → \$HOME/ai-context (rc=$RC)"
  fi
}

test_common_doctor_respeta_buffy_home() {
  suite "common: buffy-doctor detecta el estado bajo BUFFY_HOME"
  local BH="${TMPDIR:-/tmp}/buffy-common-doc-$$"
  rm -rf "$BH"
  mkdir -p "$BH/ai-context"
  trap 'rm -rf "$BH"' RETURN
  local OUT
  OUT=$(BUFFY_HOME="$BH" bash "$SCRIPTS_DIR/buffy-doctor.sh" --quick 2>&1)
  if echo "$OUT" | grep -q "CONSISTENTE\|OK:"; then
    ok "doctor ve el ai-context bajo BUFFY_HOME (sin NO_AI_CONTEXT_DIR)"
  else
    bad "doctor ve el ai-context bajo BUFFY_HOME (got: $OUT)"
  fi
}

test_common_router_respeta_buffy_home() {
  suite "common: buffy-router carga SNAPSHOT desde BUFFY_HOME"
  local BH="${TMPDIR:-/tmp}/buffy-common-route-$$"
  rm -rf "$BH"
  mkdir -p "$BH/ai-context"
  printf '%s\n' '# SNAPSHOT de prueba' '> Generated: 2026-08-03 00:00:00' > "$BH/ai-context/SNAPSHOT.md"
  trap 'rm -rf "$BH"' RETURN
  local OUT
  OUT=$(BUFFY_HOME="$BH" bash "$SCRIPTS_DIR/buffy-router.sh" --json "hola" 2>/dev/null)
  if echo "$OUT" | grep -q "$BH/ai-context/SNAPSHOT.md"; then
    ok "router incluye SNAPSHOT desde BUFFY_HOME"
  else
    bad "router incluye SNAPSHOT desde BUFFY_HOME (got: $OUT)"
  fi
}

#!/usr/bin/env bash
# test-agent.sh — tests de buffy-agent.sh (sourced por run-tests.sh)
# En el repo real solo --no-repair (no escribe). El ciclo completo
# (con repair) se ejecuta SIEMPRE dentro del sandbox.

test_agent_help() {
  suite "agent: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/buffy-agent.sh" --help
}

test_agent_no_repair_real() {
  suite "agent: --no-repair en repo real (no escribe)"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-agent.sh" --no-repair --json 2>/dev/null)
  jassert "--no-repair --json parseable + claves" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","preflight","repair","verify","load","ready"}, d.keys()'
  jassert "repair.ran=false sin repair" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["repair"]["ran"] is False'
  jassert "load=null sin mensaje" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["load"] is None'
  jassert "preflight.errors==verify.errors sin repair" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["preflight"]["errors"]==d["verify"]["errors"]'
  jassert "ready==verify.healthy" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["ready"]==d["verify"]["healthy"]'
  # Exit honesto CONDICIONAL al estado real del repo (evita fragilidad si un día
  # el repo está consistente — mismo patrón que los tests del doctor).
  local J RC
  J=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  bash "$SCRIPTS_DIR/buffy-agent.sh" --no-repair >/dev/null 2>&1; RC=$?
  if { [ "$RC" = "1" ] && [ "$J" != "0" ]; } || { [ "$RC" = "0" ] && [ "$J" = "0" ]; }; then
    ok "exit $RC coherente con drift errors=$J"
  else
    bad "exit $RC incoherente con errors=$J"
  fi

  local OUT2
  OUT2=$(bash "$SCRIPTS_DIR/buffy-agent.sh" --no-repair --json "arreglar el build" 2>/dev/null)
  jassert "load es objeto con mensaje y files" "$OUT2" 'import json,sys; d=json.load(sys.stdin); assert isinstance(d["load"], dict); assert d["load"]["message"]=="arreglar el build"; assert isinstance(d["load"]["files"], list)'

  local HUM
  HUM=$(bash "$SCRIPTS_DIR/buffy-agent.sh" --no-repair "hola" 2>&1)
  if echo "$HUM" | grep -q '1/4'; then ok "humano: muestra preflight [1/4]"; else bad "humano: muestra preflight [1/4]"; fi
  if echo "$HUM" | grep -q '4/4'; then ok "humano: muestra carga [4/4]"; else bad "humano: muestra carga [4/4]"; fi
}

test_agent_usage_errors() {
  suite "agent: errores de uso"
  expect_exit 2 "repo inválido → exit 2" bash "$SCRIPTS_DIR/buffy-agent.sh" --repo /no/existe
}

test_agent_sandbox_cycle() {
  suite "agent: ciclo completo en sandbox (drift → repair → verify → load)"
  setup_sandbox
  local PRE_ERR
  PRE_ERR=$(sb_doctor_json | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  if [ "$PRE_ERR" = "0" ]; then
    bad "sandbox sin drift (no se puede probar el ciclo)"
    return
  fi
  local OUT
  OUT=$(sb_agent --json "arreglar error de Vite en el build" 2>/dev/null)
  jassert "ciclo: JSON parseable + claves" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","preflight","repair","verify","load","ready"}, d.keys()'
  jassert "ciclo: repair corrió y aplicó" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["repair"]["ran"] is True; assert len(d["repair"]["applied"])>0'
  jassert "ciclo: drift→0 (verify.errors=0, ready=true)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["verify"]["errors"]==0, d["verify"]; assert d["ready"] is True; assert d["verify"]["errors"] < d["preflight"]["errors"]'
  jassert "ciclo: load con mensaje y files" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert isinstance(d["load"], dict); assert isinstance(d["load"]["files"], list)'
  expect_exit 0 "ciclo: exit 0 tras verificar consistente" sb_agent --json "x"
}

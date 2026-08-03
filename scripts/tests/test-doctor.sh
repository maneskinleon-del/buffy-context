#!/usr/bin/env bash
# test-doctor.sh — tests de buffy-doctor.sh (sourced por run-tests.sh)
# Todos corren sobre el repo real en modo LECTURA (el doctor nunca escribe).

test_doctor_help() {
  suite "doctor: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/buffy-doctor.sh" --help
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --help 2>&1)
  if echo "$OUT" | grep -q 'buffy-doctor'; then
    ok "--help muestra uso"
  else
    bad "--help muestra uso"
  fi
}

test_doctor_json_schema() {
  suite "doctor: --json válido"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>/dev/null)
  if [ -n "$OUT" ]; then ok "--json produce salida"; else bad "--json produce salida"; fi
  jassert "--json parseable + claves exactas" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","ok","warnings","errors","healthy","items"}, d.keys()'
  jassert "conteos coherentes (errors/warnings/ok == items por level)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert isinstance(d["errors"],int) and isinstance(d["warnings"],int) and isinstance(d["ok"],int); assert d["errors"]==sum(1 for i in d["items"] if i["level"]=="err"), (d["errors"], d["items"]); assert d["warnings"]==sum(1 for i in d["items"] if i["level"]=="warn"); assert d["ok"]==sum(1 for i in d["items"] if i["level"]=="ok")'
  jassert "healthy = (errors==0)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["healthy"]==(d["errors"]==0)'
  jassert "levels válidos" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert all(i["level"] in ("ok","warn","err","info","section") for i in d["items"])'
  jassert "mensajes sin códigos ANSI" "$OUT" 'import json,sys,re; d=json.load(sys.stdin); assert all(re.search(r"\x1b\[[0-9;]*m", i["message"]) is None for i in d["items"])'
}

test_doctor_catalog() {
  suite "doctor: catálogo fix_id"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>/dev/null)
  jassert "items accionables tienen identidad (id/fix/safe/target)" "$OUT" 'import json,sys; d=json.load(sys.stdin); a=[i for i in d["items"] if i.get("fix")]; assert len(a)>0, "sin items accionables"; assert all(("id" in i) and ("safe" in i) and ("target" in i) for i in a), [i for i in a if not ("id" in i and "safe" in i and "target" in i)]'
  jassert "safe coherente con FIX_SAFE (AUTO_SAFE)" "$OUT" 'import json,sys; d=json.load(sys.stdin); SAFE={"regenerate_snapshot","create_ai_context_dir","create_skill_dir","chmod_plus_x"}; assert all(i["safe"]==(i["fix"] in SAFE) for i in d["items"] if i.get("fix")), [(i["fix"], i["safe"]) for i in d["items"] if i.get("fix") and i["safe"]!=(i["fix"] in SAFE)]'
  jassert "safe es booleano" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert all(isinstance(i["safe"], bool) for i in d["items"] if "safe" in i)'
}

test_doctor_error_json() {
  suite "doctor: errores con identidad"
  expect_exit 1 "repo inválido → exit 1" bash "$SCRIPTS_DIR/buffy-doctor.sh" --json --repo /no/existe
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json --repo /no/existe 2>/dev/null)
  jassert "INVALID_REPO en JSON a stdout" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert any(i.get("id")=="INVALID_REPO" for i in d["items"]); assert d["errors"]==1'
  expect_exit 1 "opción desconocida (--json) → exit 1" bash "$SCRIPTS_DIR/buffy-doctor.sh" --json --bogus
  local OUT2
  OUT2=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json --bogus 2>/dev/null)
  jassert "UNKNOWN_OPTION en JSON a stdout" "$OUT2" 'import json,sys; d=json.load(sys.stdin); assert any(i.get("id")=="UNKNOWN_OPTION" for i in d["items"]); assert d["errors"]==1'
  local ERR
  ERR=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json --bogus 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then ok "stderr vacío en error --json"; else bad "stderr vacío en error --json (len=${#ERR})"; fi
  expect_exit 1 "opción desconocida (humano) → exit 1" bash "$SCRIPTS_DIR/buffy-doctor.sh" --bogus
}

test_doctor_stderr_clean() {
  suite "doctor: stderr limpio en --json"
  local ERR
  ERR=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then
    ok "stderr vacío (0 chars)"
  else
    bad "stderr vacío (len=${#ERR}: $(echo "$ERR" | head -1))"
  fi
}

test_doctor_quick() {
  suite "doctor: --quick vs --json"
  local Q J RC
  J=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  # El doctor imprime 'error(es)' con paréntesis literales — el patrón debe
  # matchear 'N error' sin interpretar los paréntesis como grupo ERE.
  Q=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --quick 2>&1 | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' | head -1)
  if [ -n "$Q" ] && [ "$Q" = "$J" ]; then
    ok "--quick reporta los mismos errores que --json ($Q)"
  else
    bad "--quick ($Q) != --json ($J)"
  fi
  bash "$SCRIPTS_DIR/buffy-doctor.sh" --quick >/dev/null 2>&1; RC=$?
  if { [ "$RC" = "1" ] && [ "$J" != "0" ]; } || { [ "$RC" = "0" ] && [ "$J" = "0" ]; }; then
    ok "--quick exit $RC coherente con drift errors=$J"
  else
    bad "--quick exit $RC incoherente con errors=$J"
  fi
}

test_doctor_exit_honest() {
  suite "doctor: exit code = hay drift"
  local RC J
  J=$(bash "$SCRIPTS_DIR/buffy-doctor.sh" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  bash "$SCRIPTS_DIR/buffy-doctor.sh" >/dev/null 2>&1; RC=$?
  if { [ "$RC" = "1" ] && [ "$J" != "0" ]; } || { [ "$RC" = "0" ] && [ "$J" = "0" ]; }; then
    ok "exit $RC coherente con errors=$J"
  else
    bad "exit $RC incoherente con errors=$J"
  fi
}

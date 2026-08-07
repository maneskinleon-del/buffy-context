#!/usr/bin/env bash
# test-verify.sh — tests de buffy-verify.sh (sourced por run-tests.sh)
# La verificación es contra el sistema REAL del runner (doc vs realidad),
# por lo que no usa sandbox: los asserts validan el CONTRATO de salida
# (schema JSON, presencia de hechos, ids, trust_score) — no valores concretos,
# que dependen de la máquina donde corra.

test_verify_help() {
  suite "verify: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/buffy-verify.sh" --help
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --help 2>&1)
  if echo "$OUT" | grep -q 'buffy-verify'; then
    ok "--help muestra uso"
  else
    bad "--help muestra uso"
  fi
}

test_verify_json_schema() {
  suite "verify: --json válido"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json 2>/dev/null)
  if [ -n "$OUT" ]; then ok "--json produce salida"; else bad "--json produce salida"; fi
  jassert "--json parseable + claves exactas" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","verified","stale","unknown","trust_score","items","_info"}, d.keys()'
  jassert "conteos coherentes con items por level" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["verified"]==sum(1 for i in d["items"] if i["level"]=="verified"); assert d["stale"]==sum(1 for i in d["items"] if i["level"]=="stale"); assert d["unknown"]==sum(1 for i in d["items"] if i["level"]=="unknown")'
  jassert "trust_score coherente (0..100)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert 0 <= d["trust_score"] <= 100'
  jassert "hechos verificados presentes" "$OUT" 'import json,sys; d=json.load(sys.stdin); v=[i for i in d["items"] if i["level"]=="verified"]; assert any(i["fact"]=="os" for i in v); assert any(i["fact"]=="kernel" for i in v); assert any(i["fact"] in ("git","node","npm","python3","codegraph") for i in v), "faltan hechos de herramientas"'
  jassert "mensajes sin códigos ANSI" "$OUT" 'import json,sys,re; d=json.load(sys.stdin); assert all(re.search(r"\x1b\[[0-9;]*m", i["message"]) is None for i in d["items"])'
}

test_verify_stale_identity() {
  suite "verify: hechos obsoletos con identidad"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json 2>/dev/null)
  # Si hay stale: cada uno debe tener id + target (para reparación manual).
  # El assert se salta (no falla) si no hay stale: es un entorno sano.
  jassert "stale con identidad (id+target) cuando existe" "$OUT" 'import json,sys; d=json.load(sys.stdin); s=[i for i in d["items"] if i["level"]=="stale"]; assert all(("id" in i) and ("target" in i) for i in s), [i for i in s if not ("id" in i and "target" in i)]'
}

test_verify_error_json() {
  suite "verify: errores con identidad"
  expect_exit 1 "repo inválido → exit 1" bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo /no/existe
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo /no/existe 2>/dev/null)
  jassert "INVALID_REPO en JSON a stdout" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert any(i.get("id")=="INVALID_REPO" for i in d["items"])'
  local ERR
  ERR=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo /no/existe 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then ok "stderr vacío en error --json"; else bad "stderr vacío en error --json (len=${#ERR})"; fi
  expect_exit 1 "opción desconocida (humano) → exit 1" bash "$SCRIPTS_DIR/buffy-verify.sh" --bogus
}

test_verify_quick() {
  suite "verify: --quick"
  local Q J
  J=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json 2>/dev/null)
  Q=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --quick 2>&1)
  if echo "$Q" | grep -q 'Verificados:'; then
    ok "--quick imprime resumen con conteos"
  else
    bad "--quick imprime resumen con conteos"
  fi
  jassert "--json: todos los hechos son verified/stale/unknown (sections marcadas aparte)" "$J" 'import json,sys; d=json.load(sys.stdin); assert all(i["level"] in ("verified","stale","unknown","section") for i in d["items"]); assert all(i["level"] in ("verified","stale","unknown") for i in d["items"] if i["fact"] != "--")'
}

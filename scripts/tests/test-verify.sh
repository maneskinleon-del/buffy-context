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
  jassert "--json parseable + claves exactas" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","verified","stale","unknown","expired","trust_score","items","_info"}, d.keys()'
  jassert "conteos coherentes con items por level" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["verified"]==sum(1 for i in d["items"] if i["level"]=="verified"); assert d["stale"]==sum(1 for i in d["items"] if i["level"]=="stale"); assert d["unknown"]==sum(1 for i in d["items"] if i["level"]=="unknown"); assert d["expired"]==sum(1 for i in d["items"] if i["level"]=="expired")'
  jassert "trust_score coherente (0..100)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert 0 <= d["trust_score"] <= 100'
  jassert "hechos del catalogo presentes (cualquier level)" "$OUT" 'import json,sys; d=json.load(sys.stdin); fs={i["fact"] for i in d["items"]}; assert {"os","kernel"} <= fs, "faltan os/kernel: "+str(fs); assert any(f in fs for f in ("git","node","npm","python3","codegraph")), "faltan hechos de herramientas: "+str(fs)'
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
  jassert "--json: todos los hechos son verified/stale/unknown/expired (sections marcadas aparte)" "$J" 'import json,sys; d=json.load(sys.stdin); assert all(i["level"] in ("verified","stale","unknown","expired","section") for i in d["items"]); assert all(i["level"] in ("verified","stale","unknown","expired") for i in d["items"] if i["fact"] != "--")'
}

test_verify_fixture_stale() {
  # Fixtures controlados (P1 auditoría 2): detección de stale DETERMINÍSTICA,
  # sin depender de la máquina del runner. Se copia el repo a un sandbox, se
  # inyecta una afirmación FALSA conocida en INFO-core.md y se verifica que
  # verify la reporta como stale con su identidad — el hueco que los tests de
  # contrato dejaban abierto.
  suite "verify: fixtures controlados (stale determinístico)"
  # Path con sufijo propio: evita colisionar con otros tests.
  local BH="${TMPDIR:-/tmp}/buffy-verify-fix-$$-fixture"
  rm -rf "$BH"; mkdir -p "$BH"
  cp -r "$REPO_DIR" "$BH/repo"
  rm -rf "$BH/repo/.git"

  # Fixture 1: kernel falso (5.0.0-fake) → KERNEL_STALE
  if ! sed -i 's/kernel [0-9][0-9.]*[-a-z0-9]*/kernel 5.0.0-fake/' "$BH/repo/ai-context/INFO-core.md" || ! grep -q 'kernel 5.0.0-fake' "$BH/repo/ai-context/INFO-core.md"; then
    bad "fixture kernel inyectado"
    return
  fi
  ok "fixture kernel inyectado (5.0.0-fake)"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo "$BH/repo" 2>/dev/null)
  jassert "kernel falso detectado como stale (KERNEL_STALE)" "$OUT" 'import json,sys; d=json.load(sys.stdin); k=[i for i in d["items"] if i["fact"]=="kernel"]; assert k and k[0]["level"]=="stale" and k[0].get("id")=="KERNEL_STALE", k'
  jassert "trust_score refleja el stale" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["trust_score"] < 100, d["trust_score"]'

  # Fixture 2: node falso (0.1.0) → VERSION_STALE
  # OJO: cp -r source dest con dest EXISTENTE anida (repo/buffy-context/...).
  # Sin mkdir previo: cp crea dest nuevo y copia el CONTENIDO dentro.
  rm -rf "$BH/repo"
  cp -r "$REPO_DIR" "$BH/repo"
  rm -rf "$BH/repo/.git"
  if ! sed -i 's/node v[0-9.]*/node v0.1.0/' "$BH/repo/ai-context/INFO-core.md" || ! grep -q 'node v0.1.0' "$BH/repo/ai-context/INFO-core.md"; then
    bad "fixture node inyectado"
    return
  fi
  ok "fixture node inyectado (v0.1.0)"
  local OUT2
  OUT2=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo "$BH/repo" 2>/dev/null)
  jassert "versión de node falsa detectada como stale (VERSION_STALE)" "$OUT2" 'import json,sys; d=json.load(sys.stdin); n=[i for i in d["items"] if i["fact"]=="node"]; assert n and n[0]["level"]=="stale" and n[0].get("id")=="VERSION_STALE", n'
  rm -rf "$BH"
}

test_verify_ttl_expired() {
  # Test adversarial (hallazgo en prueba E2E): el TTL de facts.yaml DEBE
  # enforzarse. Si un hecho dice verified=2025 con ttl=30, verify lo reporta
  # como EXPIRED (no verified) y el trust baja — antes daba trust 100%.
  # Self-contained: genera facts.yaml en el sandbox (es gitignored — no existe
  # en un checkout fresco de CI) y luego envejece sus fechas.
  suite "verify: TTL vencido (facts.yaml previo)"
  local BH="${TMPDIR:-/tmp}/buffy-verify-ttl-$$-fixture"
  rm -rf "$BH"; mkdir -p "$BH"
  cp -r "$REPO_DIR" "$BH/repo"
  rm -rf "$BH/repo/.git"
  HOME="$BH/home" bash "$SCRIPTS_DIR/buffy-verify.sh" --update-facts --repo "$BH/repo" >/dev/null 2>&1
  if [ ! -f "$BH/repo/ai-context/facts.yaml" ]; then
    bad "fixture: no pude generar facts.yaml"
    return
  fi
  python3 -c "
import yaml
p = '$BH/repo/ai-context/facts.yaml'
d = yaml.safe_load(open(p))
for v in d['facts'].values():
    v['verified'] = '2025-01-01'
    v['ttl_days'] = 30
open(p, 'w').write(yaml.dump(d, sort_keys=False, allow_unicode=True))
"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json --repo "$BH/repo" 2>/dev/null)
  jassert "hechos vencidos reportados como expired (TTL_EXPIRED)" "$OUT" 'import json,sys; d=json.load(sys.stdin); e=[i for i in d["items"] if i["level"]=="expired"]; assert len(e) > 0, "sin expired"; assert all(i.get("id")=="TTL_EXPIRED" for i in e), e[:2]'
  jassert "trust baja con TTL vencido" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["trust_score"] < 100, d["trust_score"]'
  jassert "expired NO cuenta como verified" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["verified"] == sum(1 for i in d["items"] if i["level"]=="verified")'
  rm -rf "$BH"
}

test_source_hierarchy() {
  # Jerarquía de autoridad de fuentes (caso 3 adversarial): cuando las fuentes
  # se contradicen, gana la de MAYOR autoridad y el conflicto se reporta.
  # Para aislar la jerarquía del sistema real del runner, se usa el hecho
  # 'codegraph' (no hay live si se fuerza, pero facts.yaml SÍ tiene valor
  # verified): facts.yaml dice 1.5.0 y INFO-core dice otra versión → el
  # resolver DEBE elegir facts.yaml y marcar info-core como conflicto.
  # (kernel no sirve: el sistema real siempre gana como real-time.)
  suite "source: jerarquía de autoridad"
  local BH="${TMPDIR:-/tmp}/buffy-source-$$-fixture"
  rm -rf "$BH"; mkdir -p "$BH"
  cp -r "$REPO_DIR" "$BH/repo"
  rm -rf "$BH/repo/.git"
  # facts.yaml: gitignored → lo genero en el sandbox (no existe en CI fresco)
  HOME="$BH/home" bash "$SCRIPTS_DIR/buffy-verify.sh" --update-facts --repo "$BH/repo" >/dev/null 2>&1
  # codegraph VERIFICADO (confianza 1.0, TTL vigente)
  python3 -c "
import yaml
p = '$BH/repo/ai-context/facts.yaml'
d = yaml.safe_load(open(p))
d['facts']['codegraph'] = {'value': '1.5.0', 'source': 'system', 'confidence': 1.0, 'status': 'verified', 'verified': '2026-08-07', 'scope': 'test', 'ttl_days': 30}
open(p, 'w').write(yaml.dump(d, sort_keys=False, allow_unicode=True))
"
  # INFO-core: codegraph con versión DISTINTA (contradice a facts.yaml)
  sed -i 's/codegraph v[0-9.]*/codegraph v0.0.1/' "$BH/repo/ai-context/INFO-core.md"
  # --no-live: aísla la jerarquía del sistema real del runner (en CI no hay
  # código instalado, y en local el real-time siempre ganaría).
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-source.sh" --resolve codegraph --json --no-live --repo "$BH/repo" 2>/dev/null)
  jassert "gana facts.yaml sobre info-core (codegraph)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["value"]=="1.5.0", d; assert d["source"]=="facts", d'
  jassert "conflicto con info-core reportado" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert any(c.startswith("info-core") for c in d.get("conflicts", [])), d'
  # Sin facts.yaml → inferred (uv nunca tiene live ni doc)
  rm -f "$BH/repo/ai-context/facts.yaml"
  local OUT2
  OUT2=$(bash "$SCRIPTS_DIR/buffy-source.sh" --resolve uv --json --repo "$BH/repo" 2>/dev/null)
  jassert "sin fuentes → inferred" "$OUT2" 'import json,sys; d=json.load(sys.stdin); assert d["source"]=="inferred" and d["value"] is None, d'
  rm -rf "$BH"
}

test_verify_provenance() {
  suite "verify: provenance (--update-facts)"
  # Sandbox ligero: genera facts.yaml en un repo temporal para no tocar el real.
  # Self-contained: genera el archivo (gitignored → no existe en CI fresco).
  local BH="${TMPDIR:-/tmp}/buffy-verify-facts-$$-provenance"
  rm -rf "$BH"; mkdir -p "$BH"
  cp -r "$REPO_DIR" "$BH/repo"
  rm -rf "$BH/repo/.git"
  rm -f "$BH/repo/ai-context/facts.yaml"
  HOME="$BH/home" bash "$SCRIPTS_DIR/buffy-verify.sh" --update-facts --repo "$BH/repo" >/dev/null 2>&1
  if [ -f "$BH/repo/ai-context/facts.yaml" ]; then
    ok "--update-facts genera ai-context/facts.yaml"
  else
    bad "--update-facts genera ai-context/facts.yaml"; rm -rf "$BH"; return
  fi
  local FY="$BH/repo/ai-context/facts.yaml"
  if grep -q '^facts:' "$FY"; then
    ok "YAML con raíz 'facts:'"
  else
    bad "YAML con raíz 'facts:'"
  fi
  jassert "schema de cada hecho (value/source/confidence/status/verified/scope/ttl_days)" "$(cat "$FY")" 'import yaml,sys; d=yaml.safe_load(sys.stdin); f=d["facts"]; assert len(f)>0, "sin hechos"; assert all(set(v.keys())=={"value","source","confidence","status","verified","scope","ttl_days"} for v in f.values()), [v for v in f.values() if set(v.keys())!={"value","source","confidence","status","verified","scope","ttl_days"}]'
  jassert "scope presente y ttl_days entero positivo" "$(cat "$FY")" 'import yaml,sys; d=yaml.safe_load(sys.stdin); assert all(isinstance(v["scope"], str) and v["scope"] for v in d["facts"].values()); assert all(isinstance(v["ttl_days"], int) and v["ttl_days"] > 0 for v in d["facts"].values())'
  jassert "confidence 1.0 para verified, <1.0 para stale/unknown" "$(cat "$FY")" 'import yaml,sys; d=yaml.safe_load(sys.stdin); assert all(v["confidence"]==1.0 if v["status"]=="verified" else v["confidence"]<1.0 for v in d["facts"].values())'
  jassert "fecha de verificación válida (YYYY-MM-DD)" "$(cat "$FY")" 'import yaml,sys,datetime; d=yaml.safe_load(sys.stdin); assert all(datetime.date.fromisoformat(v["verified"]) for v in d["facts"].values())'
  rm -rf "$BH"
}

test_verify_engine_hardening() {
  # Hardening auditoría 3: el motor NUNCA ejecuta con shell. Una regla con
  # metacaracteres de shell (p.ej. "node --version; rm -rf /tmp/x") debe ser
  # RECHAZADA (emitida a stderr), jamás ejecutada.
  suite "verify: hardening del motor (sin shell)"
  local OUT ERR
  OUT=$(python3 -c "
import sys; sys.path.insert(0, '$SCRIPTS_DIR/lib')
from facts_engine import normalize_command
ok = True
try:
    argv, err = normalize_command(['node', '--version'])
    assert argv == ['node', '--version'] and not err, (argv, err)
except AssertionError:
    ok = False
argv2, err2 = normalize_command('node --version; rm -rf /tmp/x')
if argv2:
    ok = False
argv3, err3 = normalize_command(['git', '--version'])
assert argv3 == ['git', '--version'] and not err3
print('OK' if ok else 'FAIL')
" 2>&1)
  if echo "$OUT" | grep -q '^OK$'; then
    ok "lista de args aceptada y string con metacaracteres rechazado"
  else
    bad "hardening del motor: $OUT"
  fi

  # Integración: verify con reglas YAML en forma de lista funciona igual
  local J
  J=$(bash "$SCRIPTS_DIR/buffy-verify.sh" --json 2>/dev/null)
  jassert "verify con reglas lista sigue reportando git/node/npm" "$J" 'import json,sys; d=json.load(sys.stdin); f={i["fact"] for i in d["items"]}; assert {"git","node","npm"}.issubset(f), f'
}

#!/usr/bin/env bash
# test-project-state-engine.sh — pruebas del motor (Paso 5): estados +
# trust_project, comparaciones, taxonomía unknown (Q-04), errores de entrada,
# fallos de enumeración (schema_violations), I-1 (metacaracteres) e I-4
# (compatibilidad linter↔motor con fixture compartido).
#
# Fuentes: ai-context/project-state-engine-design.md (Paso 3), plan Paso 5 §2.
# Sin setup_sandbox → corre en --quick: fixtures locales en tmp, sin red.
# Excepción: TIMEOUT cuesta los 10s que fija el diseño (sin override) y se
# salta en --quick — misma heurística de skip que los tests de sandbox.

PS_ENG="$SCRIPTS_DIR/lib/project_state_engine.py"
PS_LINT="$SCRIPTS_DIR/lib/project_state_linter.py"
PS_FIX="$SCRIPT_DIR/fixtures/project-state"

# ps_eng_fx <dir> — crea <dir>/ai-context/project-state.yaml; assertions stdin
ps_eng_fx() {
  mkdir -p "$1/ai-context"
  cat > "$1/ai-context/project-state.yaml" <<'HDR'
project:
  name: fx-engine
  version: 2026-10-13
assertions:
HDR
  cat >> "$1/ai-context/project-state.yaml"
}

# ps_eng_1 <dir> <command> <comparison> [expected] — doc con UNA aserción A
ps_eng_1() {
  local dir="$1" cmd="$2" comp="$3" exp="${4:-}"
  mkdir -p "$dir/ai-context"
  touch "$dir/README.md"
  {
    printf '%s\n' \
      "project:" "  name: fx-engine" "  version: 2026-10-13" "assertions:" \
      "  - key: a1" "    type: A" "    value: v" "    source: system" \
      "    confidence: 1.0" "    status: verified" "    verified: $(date +%F)" \
      "    scope: fx-engine" "    ttl_days: 30" "    evidence: e" \
      "    check:" "      command: $cmd" "      comparison: $comp"
    [ -n "$exp" ] && printf '      expected: %s\n' "$exp"
  } > "$dir/ai-context/project-state.yaml"
}

# ── Estados, trust_project, TSV y read-only ─────────────────────────────────
test_engine_estados_y_trust() {
  suite "project-state-engine · estados, trust_project y read-only"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  touch "$d/README.md"
  local hoy; hoy=$(date +%F)
  ps_eng_fx "$d" <<EOF
  - key: exact-ok
    type: A
    value: hola
    source: system
    confidence: 1.0
    status: verified
    verified: $hoy
    scope: fx-engine
    ttl_days: 30
    evidence: e
    check:
      command: [echo, hola]
      comparison: exact
      expected: hola
  - key: exact-difiere
    type: A
    value: otro
    source: system
    confidence: 0.4
    status: stale
    verified: $hoy
    scope: fx-engine
    ttl_days: 30
    evidence: e
    check:
      command: [echo, hola]
      comparison: exact
      expected: distinto
  - key: ttl-vencido
    type: A
    value: hola
    source: system
    confidence: 0.2
    status: expired
    verified: 2020-01-01
    scope: fx-engine
    ttl_days: 30
    evidence: e
    check:
      command: [echo, hola]
      comparison: exact
      expected: hola
  - key: binario-ausente
    type: A
    value: v
    source: system
    confidence: 0.2
    status: unknown
    verified: $hoy
    scope: fx-engine
    ttl_days: 30
    evidence: e
    check:
      command: [no-existe-xyz-bin, arg]
      comparison: exact
      expected: v
  - key: juicio-b
    type: B
    value: decision tomada
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-engine
    ttl_days: 30
    evidence: e
EOF

  # TSV default: 5 filas de 6 campos (patrón facts_engine L7)
  local tsv rc lines badf
  tsv=$(python3 "$PS_ENG" "$d" 2>/dev/null); rc=$?
  lines=$(printf '%s\n' "$tsv" | grep -c '')
  badf=$(printf '%s\n' "$tsv" | awk -F'\t' 'NF != 6' | grep -c '')
  if [ "$rc" -eq 0 ] && [ "$lines" -eq 5 ] && [ "$badf" -eq 0 ]; then
    ok "TSV: 5 filas, 6 campos cada una (level key msg id target real)"
  else
    bad "TSV roto (exit $rc, líneas=$lines, filas≠6 campos=$badf)"
    dump_out "$tsv"
  fi

  local json; json=$(python3 "$PS_ENG" "$d" --json 2>/dev/null)
  jassert "JSON: claves raíz exactas (Q-03: trust_project, NO trust_score)" "$json" \
    'import json,sys; d=json.load(sys.stdin); exp={"repo","verified","stale","unknown","expired","trust_project","human_assertions","schema_violations","items","_info"}; assert set(d)==exp, set(d)'
  jassert "JSON: conteos A = 1 verified / 1 stale / 1 unknown / 1 expired" "$json" \
    'import json,sys; d=json.load(sys.stdin); assert (d["verified"],d["stale"],d["unknown"],d["expired"])==(1,1,1,1), d'
  jassert "trust_project = 33.3 (1/(1+1+1), unknown excluido — S-05)" "$json" \
    'import json,sys; d=json.load(sys.stdin); assert d["trust_project"]==33.3, d["trust_project"]'
  jassert "human_assertions = judged 1, total 1 (B fuera del trust)" "$json" \
    'import json,sys; d=json.load(sys.stdin); assert d["human_assertions"]=={"judged":1,"pending":0,"disputed":0,"total":1}, d["human_assertions"]'
  jassert "B reportada en items sin ejecutar (mensaje juicio humano)" "$json" \
    'import json,sys; d=json.load(sys.stdin); assert any(i["level"]=="judged" and i["message"].startswith("juicio humano") for i in d["items"])'

  # read-only: el motor no escribe el YAML (default sin --update)
  local before after
  before=$(sha256sum "$d/ai-context/project-state.yaml" | cut -d' ' -f1)
  python3 "$PS_ENG" "$d" --json >/dev/null 2>&1
  after=$(sha256sum "$d/ai-context/project-state.yaml" | cut -d' ' -f1)
  if [ "$before" = "$after" ]; then
    ok "read-only: SHA-256 del YAML idéntico tras la corrida"
  else
    bad "read-only: el motor modificó el YAML evaluado"
  fi

  rm -rf "$d"
}

# ── Comparaciones: exact | contains | regex | exists | exit_code (M-03) ─────
test_engine_comparaciones() {
  suite "project-state-engine · las 5 comparaciones (M-03)"
  local d

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, hola]' exact hola
  ps_expect 0 '"level": "verified"' "exact: salida == expected → verified" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, hola]' exact distinto
  ps_expect 0 '"level": "stale"' "exact: salida difiere → stale (0.4, no unknown)" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, conclusion=success]' contains 'conclusion=success'
  ps_expect 0 '"level": "verified"' "contains: expected ∈ salida → verified" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, abc123]' regex 'a.c.23'
  ps_expect 0 '"level": "verified"' "regex: re.search matchea → verified" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, abc123]' regex 'x.y'
  ps_expect 0 '"level": "stale"' "regex: sin match → stale" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[test, -f, README.md]' exit_code
  ps_expect 0 '"level": "verified"' "exit_code: 0 → verified" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  # "false"/"true" COTADOS: sin comillas YAML los convierte en booleanos y el
  # arg sería "False" (nombre de binario inexistente) — queremos el binario.
  ps_eng_1 "$d" '["false"]' exit_code
  ps_expect 0 '"level": "stale"' "exit_code: ≠0 → stale" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[test, -f, README.md]' exists
  ps_expect 0 '"level": "verified"' "exists: ruta presente → verified" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[test, -f, nada-aqui.txt]' exists
  ps_expect 0 '"level": "stale"' "exists: ruta ausente → stale" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"
}

# ── Taxonomía unknown de Q-04 (nunca stale por infraestructura) ─────────────
test_engine_taxonomy_unknown() {
  suite "project-state-engine · taxonomía unknown (Q-04)"
  local d

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[no-existe-xyz-bin, a]' exact v
  ps_expect 0 '"id": "BINARY_MISSING"' "binario ausente → unknown BINARY_MISSING" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX"); touch "$d/README.md"
  ps_eng_fx "$d" <<'EOF'
  - key: sin-check
    type: A
    value: v
    source: system
    confidence: 0.2
    status: unknown
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: e
EOF
  ps_expect 0 '"id": "CHECK_MISSING"' "A sin check → unknown CHECK_MISSING (degrada, no rompe)" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, hola]' exact
  ps_expect 0 '"id": "EXPECTED_MISSING"' "exact sin expected → unknown no evaluable (H-2)" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '["true"]' exact v   # cotado: sin comillas YAML daría booleano
  ps_expect 0 '"id": "NO_OUTPUT"' "sin salida evaluable → unknown NO_OUTPUT" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  printf '#!/nonexistent-interp-subprocess\n' > "$d/badexec.sh"; chmod +x "$d/badexec.sh"
  ps_eng_1 "$d" "[$d/badexec.sh]" exact v
  ps_expect 0 '"id": "EXEC_ERROR"' "ejecución imposible (shebang inválido) → unknown EXEC_ERROR" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, hola]' banana hola
  ps_expect 0 '"id": "COMPARISON_UNKNOWN"' "comparison desconocido → unknown COMPARISON_UNKNOWN" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_1 "$d" '[echo, hola]' regex '('
  ps_expect 0 '"id": "REGEX_INVALID"' "regex inválida en expected → unknown REGEX_INVALID" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  # TIMEOUT: el diseño fija timeout=10 sin override — cuesta 10s reales, se
  # salta en --quick (misma economía que los tests de sandbox).
  if [ "$QUICK_MODE" != true ]; then
    d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
    ps_eng_1 "$d" '[sleep, "15"]' exact v
    ps_expect 0 '"id": "TIMEOUT"' "timeout 10s → unknown TIMEOUT (Q-04)" \
      python3 "$PS_ENG" "$d" --json
    rm -rf "$d"
  fi
}

# ── Errores de entrada (carga → exit 1, CLI → exit 2) ───────────────────────
test_engine_errores_entrada() {
  suite "project-state-engine · errores de entrada"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  mkdir -p "$d/ai-context"

  ps_expect 1 "no existe" "archivo ausente → exit 1" \
    python3 "$PS_ENG" "$d"

  printf 'project:\n  name: [unclosed\n' > "$d/ai-context/project-state.yaml"
  ps_expect 1 "YAML corrupto" "YAML corrupto → exit 1" \
    python3 "$PS_ENG" "$d"

  printf -- '- a\n- b\n' > "$d/ai-context/project-state.yaml"
  ps_expect 1 "raíz" "raíz no mapping → exit 1" \
    python3 "$PS_ENG" "$d"

  printf 'project:\n  name: x\nassertions: "no lista"\n' > "$d/ai-context/project-state.yaml"
  ps_expect 1 "no es una lista" "assertions no lista → exit 1" \
    python3 "$PS_ENG" "$d"

  ps_expect 2 "opción no soportada" "flag desconocida → exit 2 (CLI)" \
    python3 "$PS_ENG" "$d" --foo
  ps_expect 2 "futuro" "--update no implementado (diseño futuro) → exit 2" \
    python3 "$PS_ENG" "$d" --update
  ps_expect 0 "Uso" "--help → exit 0 con usage" \
    python3 "$PS_ENG" --help

  rm -rf "$d"
}

# ── Fallos de enumeración → schema_violations (safety net, Q-08) ────────────
test_engine_fallos_enumeracion() {
  suite "project-state-engine · fallos de enumeración (schema_violations)"
  local d

  # item de assertions que no es mapping: no rompe la enumeración
  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX"); touch "$d/README.md"
  ps_eng_fx "$d" <<'EOF'
  - "no-mapping"
  - key: ok1
    type: A
    value: v
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: e
    check:
      command: [echo, v]
      comparison: exact
      expected: v
EOF
  ps_expect 0 '"code": "SCHEMA_VIOLATION_ITEM_NOT_MAPPING"' \
    "item no mapping → violación, sin crash, exit 0" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  # type desconocido
  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_fx "$d" <<'EOF'
  - key: t
    type: C
    value: v
    source: inferred
    confidence: 0.5
    status: verified
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: e
EOF
  ps_expect 0 '"code": "SCHEMA_VIOLATION_TYPE_UNKNOWN"' \
    "type desconocido → violación, no clasifica" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  # B verified (D3): rechazo en stderr + JSON, fuera de human_assertions
  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_fx "$d" <<'EOF'
  - key: bv
    type: B
    value: v
    source: user
    confidence: 0.9
    status: verified
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: e
EOF
  ps_expect 0 '"code": "SCHEMA_VIOLATION_B_VERIFIED"' \
    "B verified → SCHEMA_VIOLATION_B_VERIFIED (D3, safety net)" \
    python3 "$PS_ENG" "$d" --json
  ps_expect 0 '"total": 0' \
    "B verified FUERA de human_assertions (total 0) y del trust" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"

  # B con status fuera de conjunto
  d=$(mktemp -d "${TMPDIR:-/tmp}/ps-eng-XXXXXX")
  ps_eng_fx "$d" <<'EOF'
  - key: bfoo
    type: B
    value: v
    source: user
    confidence: 0.9
    status: foo
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: e
EOF
  ps_expect 0 '"code": "SCHEMA_VIOLATION_B_STATUS"' \
    "B status inválido → violación, no clasifica" \
    python3 "$PS_ENG" "$d" --json
  rm -rf "$d"
}

# ── I-1: SHELL_METACHARS rechazado ANTES de ejecutar (plan §2) ──────────────
test_project_state_i1_metachars() {
  suite "project-state · I-1 motor rechaza SHELL_METACHARS antes de ejecutar"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-i1-XXXXXX")
  ps_eng_fx "$d" <<'EOF'
  - key: pwned
    type: A
    value: x
    source: system
    confidence: 0.2
    status: unknown
    verified: 2026-10-13
    scope: fx-engine
    ttl_days: 30
    evidence: "I-1: arg con ; y espacio — jamás debe ejecutarse"
    check:
      command: [git, "rev-parse; touch /tmp/PWNED"]
      comparison: exact
      expected: x
EOF
  rm -f /tmp/PWNED

  # (c) falsificación (patrón B-1/B-3): SIN el fix (shell=True) el hijo corre
  # y el sentinel SÍ se crea → el assert de (b) fallaría sin la defensa.
  python3 -c "import subprocess; subprocess.run('git rev-parse; touch /tmp/PWNED', shell=True)" \
    >/dev/null 2>&1
  if [ -e /tmp/PWNED ]; then
    ok "I-1(c) control de sensibilidad: sin shell=False el hijo se lanza (el test fallaría sin el fix)"
  else
    bad "I-1(c) el control no creó /tmp/PWNED — el sentinel no detectaría ejecución"
  fi
  rm -f /tmp/PWNED

  # (a) salida JSON: status unknown + código METACHARS_REJECTED
  ps_expect 0 '"id": "METACHARS_REJECTED"' \
    "I-1(a) motor → unknown + METACHARS_REJECTED en JSON" \
    python3 "$PS_ENG" "$d" --json

  # (b) test ! -e /tmp/PWNED: el proceso hijo jamás se lanzó
  if [ ! -e /tmp/PWNED ]; then
    ok "I-1(b) test ! -e /tmp/PWNED — el proceso hijo jamás se lanzó"
  else
    bad "I-1(b) /tmp/PWNED existe: el comando rechazado se ejecutó"
    rm -f /tmp/PWNED
  fi

  rm -rf "$d"
}

# ── I-4: mismo fixture, ambos lo rechazan (compatibilidad LINT-19 ↔ motor) ──
test_project_state_i4_linter_engine_compat() {
  suite "project-state · I-4 compatibilidad linter↔motor (fixture compartido)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-i4-XXXXXX")
  mkdir -p "$d/ai-context"
  # fixture ÚNICO del directorio de fixtures — sin copias divergentes
  cp "$PS_FIX/cmd-string.yaml" "$d/ai-context/project-state.yaml"
  local fx="$d/ai-context/project-state.yaml"

  ps_expect 1 "LINT-19" "I-4 linter: exit 1 + LINT-19 (forma S-04)" \
    python3 "$PS_LINT" "$fx"
  ps_expect 1 '"healthy": false' "I-4 linter --json: unhealthy" \
    python3 "$PS_LINT" "$fx" --json
  ps_expect 0 '"id": "COMMAND_NOT_LIST"' "I-4 motor: unknown + COMMAND_NOT_LIST (S-04)" \
    python3 "$PS_ENG" "$d" --json

  # grep de aceptación: ninguno de los dos lo da por verificado
  if python3 "$PS_ENG" "$d" --json 2>/dev/null | grep -q '"level": "verified"'; then
    bad "I-4 el motor aceptó el string como verified"
  else
    ok "I-4 grep de aceptación vacío: el motor no lo da por verified"
  fi

  rm -rf "$d"
}

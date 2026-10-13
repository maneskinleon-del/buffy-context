#!/usr/bin/env bash
# test-project-state-linter.sh — matriz §5 del Paso 4 (45 filas, IDs idénticos
# al diseño) + contrato JSON I-2. Una fila = UN check (ps_expect): exit code
# documentado + hallazgo esperado (ID de regla / guard).
#
# Fuentes: ai-context/project-state-linter-design.md §3-§5 (Paso 4 APROBADO
# 2026-10-13 — bitácora §9), plan Paso 5 §2-§3.
# Sin setup_sandbox → corre también en --quick: todo es local y read-only
# (M-01/M-02 asientan que ni el archivo ni el repo cambian).

PS_LINT="$SCRIPTS_DIR/lib/project_state_linter.py"
PS_LINT_SCHEMA="$SCRIPTS_DIR/lib/project_state_linter.schema.json"
PS_VALIDATE="$SCRIPT_DIR/fixtures/validate_json_schema.py"
PS_REAL="$REPO_DIR/ai-context/project-state.yaml"

# ps_doc <ruta> — encabezado de documento VÁLIDO; el bloque assertions va por
# stdin de la llamada (el header usa su propio heredoc, no consume el ajeno).
ps_doc() {
  cat > "$1" <<'HDR'
project:
  name: fx-linter
  version: 2026-10-11
assertions:
HDR
  cat >> "$1"
}

# ps_val <desc> <instancia> — la instancia VALIDA contra el esquema (I-2)
ps_val() {
  local desc="$1" inst="$2" out
  out=$(python3 "$PS_VALIDATE" "$PS_LINT_SCHEMA" "$inst" 2>&1)
  if [ $? -eq 0 ]; then
    ok "$desc"
  else
    bad "$desc"
    dump_out "$out"
  fi
}

# ps_val_reject <desc> <instancia> — la instancia NO valida (mutación rota, I-2)
ps_val_reject() {
  local desc="$1" inst="$2" out rc
  out=$(python3 "$PS_VALIDATE" "$PS_LINT_SCHEMA" "$inst" 2>&1); rc=$?
  if [ "$rc" -eq 1 ]; then
    ok "$desc"
  else
    bad "$desc (esperado rechazo exit 1, obtuve $rc)"
    dump_out "$out"
  fi
}

# ── §5.2 Positivas — exit 0 (9) ─────────────────────────────────────────────
test_project_state_linter_matriz_p01_p09() {
  suite "project-state-linter · matriz positivas exit 0 (P-01..P-09)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-lint-XXXXXX")

  ps_doc "$d/p01.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e1"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "0 errores" "P-01 documento mínimo válido (A completa con check)" \
    python3 "$PS_LINT" "$d/p01.yaml"

  ps_doc "$d/p02.yaml" <<'EOF'
  - key: a1
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e1"
    check:
      command: [test, -f, README.md]
      comparison: exists
  - key: b1
    type: B
    value: "MVC aprobado"
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "[orig] SESION.md 2026-10-03"
EOF
  ps_expect 0 "0 errores" "P-02 documento mixto A+B completo" \
    python3 "$PS_LINT" "$d/p02.yaml"

  ps_doc "$d/p03.yaml" <<'EOF'
  - key: b1
    type: B
    value: "decisión registrada"
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "[orig] SESION.md 2026-10-03"
EOF
  ps_expect 0 "0 errores" "P-03 B judged 0.9 sin check (LINT-07/08a/09 conformes)" \
    python3 "$PS_LINT" "$d/p03.yaml"

  ps_doc "$d/p04.yaml" <<'EOF'
  - key: b2
    type: B
    value: "hipótesis pendiente"
    source: user
    confidence: 0.5
    status: pending
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "[orig] discusión abierta"
EOF
  ps_expect 0 "0 errores" "P-04 B pending 0.5 (LINT-08b conforme, LINT-14 no aplica)" \
    python3 "$PS_LINT" "$d/p04.yaml"

  ps_doc "$d/p05.yaml" <<'EOF'
  - key: a2
    type: A
    value: true
    source: system
    confidence: 0.4
    status: stale
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "0 errores" "P-05 A stale 0.4 (LINT-10 no aplica: solo verified exige 1.0)" \
    python3 "$PS_LINT" "$d/p05.yaml"

  ps_doc "$d/p06.yaml" <<'EOF'
  - key: a3
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "0 errores" "P-06 A sin ttl_days (campo opcional, LINT-11 no aplica)" \
    python3 "$PS_LINT" "$d/p06.yaml"

  ps_doc "$d/p07.yaml" <<'EOF'
  - key: a4
    type: A
    value: false
    source: inferred
    confidence: 0.2
    status: unknown
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "0 errores" "P-07 A inferred/unknown/0.2 (LINT-09/12/13 conformes)" \
    python3 "$PS_LINT" "$d/p07.yaml"

  ps_doc "$d/p08.yaml" <<'EOF'
  - key: a5
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "0 errores" "P-08 A verified + confidence 1.0 (LINT-10 conforme)" \
    python3 "$PS_LINT" "$d/p08.yaml"

  ps_doc "$d/p09.yaml" <<'EOF'
  - key: a6
    type: A
    value: ok
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [echo, ok]
      comparison: exact
      expected: ok
EOF
  ps_expect 0 "0 errores" "P-09 check.command lista no vacía (LINT-19 conforme)" \
    python3 "$PS_LINT" "$d/p09.yaml"

  rm -rf "$d"
}

# ── §5.3 Lectura/procesamiento — exit 2 (9) ─────────────────────────────────
test_project_state_linter_matriz_n01_n09() {
  suite "project-state-linter · matriz guards exit 2 (N-01..N-09)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-lint-XXXXXX")

  ps_expect 2 "no existe" "N-01 archivo inexistente (G-1)" \
    python3 "$PS_LINT" "$d/no-existe.yaml"

  # N-02 sin permisos (G-1). Como root chmod 000 no restringe la lectura:
  # skip honesto con MISMO conteo de checks (doc_truth no se desvía).
  if [ "$(id -u)" -eq 0 ]; then
    ok "N-02 archivo sin permisos de lectura (skip: root — chmod 000 no restringe)"
  else
    : > "$d/n02.yaml"; chmod 000 "$d/n02.yaml"
    ps_expect 2 "sin permiso" "N-02 archivo sin permisos de lectura (G-1)" \
      python3 "$PS_LINT" "$d/n02.yaml"
    chmod 644 "$d/n02.yaml"
  fi

  : > "$d/n03.yaml"
  ps_expect 2 "vacío" "N-03 archivo vacío 0 bytes (G-2)" \
    python3 "$PS_LINT" "$d/n03.yaml"

  printf '%s\n' '- foo' '- bar' > "$d/n04.yaml"
  ps_expect 2 "raíz" "N-04 raíz es lista (G-4)" \
    python3 "$PS_LINT" "$d/n04.yaml"

  ps_doc "$d/n05.yaml" <<'EOF'
  - "string-item"
EOF
  ps_expect 2 "no es un mapping" "N-05 item de assertions no es mapping (G-6)" \
    python3 "$PS_LINT" "$d/n05.yaml"

  cat > "$d/n06.yaml" <<'EOF'
project:
  name: fx-linter
  version: 2026-10-11
EOF
  ps_expect 2 "ausente" "N-06 assertions ausente (G-6 / LINT-03)" \
    python3 "$PS_LINT" "$d/n06.yaml"

  cat > "$d/n07.yaml" <<'EOF'
project:
  name: fx-linter
  version: 2026-10-11
assertions: "no soy una lista"
EOF
  ps_expect 2 "no es una lista" "N-07 assertions no es lista (G-6 / LINT-03)" \
    python3 "$PS_LINT" "$d/n07.yaml"

  printf 'project:\n  name: [unclosed\n' > "$d/n08.yaml"
  ps_expect 2 "error de parseo" "N-08 YAML inválido (G-3)" \
    python3 "$PS_LINT" "$d/n08.yaml"

  printf 'assertions:\n  - key: k\n' > "$d/n09.yaml"
  ps_expect 2 "project" "N-09 bloque project ausente (G-5)" \
    python3 "$PS_LINT" "$d/n09.yaml"

  rm -rf "$d"
}

# ── §5.4 Violaciones ERR — exit 1 (21: V-01..V-15, V-17..V-21, F-03) ────────
test_project_state_linter_matriz_v01_v21() {
  suite "project-state-linter · matriz violaciones exit 1 (V-01..V-15, V-17..V-21, F-03)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-lint-XXXXXX")

  # V-01: project.name vacío
  cat > "$d/v01.yaml" <<'EOF'
project:
  name: ""
  version: 2026-10-11
assertions:
  - key: k1
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-01" "V-01 project.name vacío" python3 "$PS_LINT" "$d/v01.yaml"

  # V-02: version no ISO
  sed 's|version: 2026-10-11|version: 12/10/2026|' "$d/v01.yaml" > "$d/v02.yaml"
  ps_expect 1 "LINT-02" "V-02 project.version no ISO" python3 "$PS_LINT" "$d/v02.yaml"

  # V-03: key duplicada
  ps_doc "$d/v03.yaml" <<'EOF'
  - key: dup
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
  - key: dup
    type: B
    value: v
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-04" "V-03 key duplicada" python3 "$PS_LINT" "$d/v03.yaml"

  # V-04: type C (aislado: source inferred + conf 0.5 → solo LINT-05)
  ps_doc "$d/v04.yaml" <<'EOF'
  - key: k1
    type: C
    value: v
    source: inferred
    confidence: 0.5
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-05" "V-04 type: C" python3 "$PS_LINT" "$d/v04.yaml"

  # V-05: A sin check
  ps_doc "$d/v05.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-06" "V-05 type: A sin check" python3 "$PS_LINT" "$d/v05.yaml"

  # V-06: B con check
  ps_doc "$d/v06.yaml" <<'EOF'
  - key: k1
    type: B
    value: v
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-07" "V-06 type: B con check" python3 "$PS_LINT" "$d/v06.yaml"

  # V-07: B verified (LINT-08a)
  ps_doc "$d/v07.yaml" <<'EOF'
  - key: k1
    type: B
    value: v
    source: user
    confidence: 0.9
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-08a" "V-07 type: B + status: verified (LINT-08a)" \
    python3 "$PS_LINT" "$d/v07.yaml"

  # V-08: B expired (∉ conjunto B → LINT-08b)
  sed 's/status: verified/status: expired/' "$d/v07.yaml" > "$d/v08.yaml"
  ps_expect 1 "LINT-08b" "V-08 type: B + status: expired (LINT-08b)" \
    python3 "$PS_LINT" "$d/v08.yaml"

  # V-09: A judged (∉ conjunto A → LINT-08b)
  ps_doc "$d/v09.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: system
    confidence: 0.4
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-08b" "V-09 type: A + status: judged (LINT-08b)" \
    python3 "$PS_LINT" "$d/v09.yaml"

  # V-10: confidence 1.0 con source user (LINT-09; LINT-14 advierte aparte)
  ps_doc "$d/v10.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: user
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-09" "V-10 confidence 1.0 + source user" python3 "$PS_LINT" "$d/v10.yaml"

  # V-11: confidence 1.0 con type B (LINT-09)
  ps_doc "$d/v11.yaml" <<'EOF'
  - key: k1
    type: B
    value: v
    source: user
    confidence: 1.0
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-09" "V-11 confidence 1.0 + type B" python3 "$PS_LINT" "$d/v11.yaml"

  # V-12: A verified con confidence 0.4 (LINT-10)
  sed 's/confidence: 1.0/confidence: 0.4/' "$d/v01.yaml" > "$d/v12.yaml"
  ps_expect 1 "LINT-10" "V-12 A verified + confidence 0.4" python3 "$PS_LINT" "$d/v12.yaml"

  # V-13: ttl_days 60
  sed 's/ttl_days: 30/ttl_days: 60/' "$d/v01.yaml" > "$d/v13.yaml"
  ps_expect 1 "LINT-11" "V-13 ttl_days: 60" python3 "$PS_LINT" "$d/v13.yaml"

  # V-14: source guessed (base stale/0.4 → aislado de LINT-09)
  ps_doc "$d/v14.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: guessed
    confidence: 0.4
    status: stale
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-12" "V-14 source: guessed" python3 "$PS_LINT" "$d/v14.yaml"

  # V-15: source system con type B (LINT-13)
  ps_doc "$d/v15.yaml" <<'EOF'
  - key: k1
    type: B
    value: v
    source: system
    confidence: 0.9
    status: judged
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  ps_expect 1 "LINT-13" "V-15 source: system + type B" python3 "$PS_LINT" "$d/v15.yaml"

  # V-17: falta status (LINT-15)
  grep -v '^    status: ' "$d/v01.yaml" > "$d/v17.yaml"
  ps_expect 1 "LINT-15" "V-17 falta status" python3 "$PS_LINT" "$d/v17.yaml"

  # V-18: falta evidence (LINT-15)
  grep -v '^    evidence: ' "$d/v01.yaml" > "$d/v18.yaml"
  ps_expect 1 "LINT-15" "V-18 falta evidence" python3 "$PS_LINT" "$d/v18.yaml"

  # V-19: verified no válida (string cotado — sin comillas PyYAML lanza
  # ValueError de constructor → G-3, guard de parseo, no LINT-16)
  sed 's|verified: 2026-10-11|verified: "2026-99-99"|' "$d/v01.yaml" > "$d/v19.yaml"
  ps_expect 1 "LINT-16" "V-19 fecha verified no válida" python3 "$PS_LINT" "$d/v19.yaml"

  # V-20: confidence 1.5 (base stale → aislado de LINT-10)
  ps_doc "$d/v20.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: system
    confidence: 1.5
    status: stale
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 1 "LINT-17" "V-20 confidence: 1.5" python3 "$PS_LINT" "$d/v20.yaml"

  # V-21: confidence -0.1
  sed 's/confidence: 1.5/confidence: -0.1/' "$d/v20.yaml" > "$d/v21.yaml"
  ps_expect 1 "LINT-17" "V-21 confidence: -0.1" python3 "$PS_LINT" "$d/v21.yaml"

  # F-03: check.command como string (LINT-19, contrato S-04)
  ps_doc "$d/f03.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: "git rev-parse HEAD"
      comparison: exact
      expected: "x"
EOF
  ps_expect 1 "LINT-19" "F-03 check.command string (LINT-19)" python3 "$PS_LINT" "$d/f03.yaml"

  rm -rf "$d"
}

# ── §5.5 WARN — exit 0 (1) ──────────────────────────────────────────────────
test_project_state_linter_matriz_v16_warn() {
  suite "project-state-linter · matriz advertencia exit 0 (V-16)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-lint-XXXXXX")

  ps_doc "$d/v16.yaml" <<'EOF'
  - key: k1
    type: A
    value: true
    source: user
    confidence: 0.4
    status: stale
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
    check:
      command: [test, -f, README.md]
      comparison: exists
EOF
  ps_expect 0 "LINT-14" "V-16 source user + type A → WARN, exit 0" \
    python3 "$PS_LINT" "$d/v16.yaml"

  rm -rf "$d"
}

# ── §5.6 Falsificación/regresión (3: F-01, F-02, F-04) ─────────────────────
test_project_state_linter_matriz_f01_f04() {
  suite "project-state-linter · falsificación/regresión (F-01, F-02, F-04)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-lint-XXXXXX")

  # F-01 (≡N-08) — I-3: el guard NO absorbe el parseo. Tres condiciones en un
  # check: exit 2 exacto, stdout VACÍO (jamás healthy:true con archivo rojo) y
  # stderr con el motivo de parseo. Falla si alguien "arregla" el guard 0.
  printf 'project:\n  name: [unclosed\n' > "$d/f01.yaml"
  local so se rc1 rc2
  so=$(python3 "$PS_LINT" "$d/f01.yaml" 2>/dev/null); rc1=$?
  se=$(python3 "$PS_LINT" "$d/f01.yaml" 2>&1 >/dev/null); rc2=$?
  if [ "$rc1" -eq 2 ] && [ "$rc2" -eq 2 ] && [ -z "$so" ] \
     && printf '%s' "$se" | grep -q "error de parseo"; then
    ok "F-01/I-3 guard no absorbe parseo: exit 2, stderr con motivo, stdout vacío"
  else
    bad "F-01/I-3 guard no absorbe parseo (rc1=$rc1 rc2=$rc2 stdout='${so:0:40}')"
    dump_out "$se"
  fi

  # F-02: TRES type C en el mismo documento → las tres violaciones, no solo la
  # primera (el linter agrega, no corta en la primera regla).
  ps_doc "$d/f02.yaml" <<'EOF'
  - key: c1
    type: C
    value: v
    source: inferred
    confidence: 0.5
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
  - key: c2
    type: C
    value: v
    source: inferred
    confidence: 0.5
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
  - key: c3
    type: C
    value: v
    source: inferred
    confidence: 0.5
    status: verified
    verified: 2026-10-11
    scope: fx-linter
    ttl_days: 30
    evidence: "e"
EOF
  local out rc n
  out=$(python3 "$PS_LINT" "$d/f02.yaml" 2>&1); rc=$?
  n=$(printf '%s\n' "$out" | grep -c '^LINT-05 ')
  if [ "$rc" -eq 1 ] && [ "$n" -ge 3 ]; then
    ok "F-02 multi-violación: 3 type C reportados (LINT-05 x$n, exit 1)"
  else
    bad "F-02 multi-violación — esperado exit 1 con ≥3 LINT-05, obtuve exit $rc con $n"
    dump_out "$out"
  fi

  # F-04 (≡N-07): regresión G-6 — assertions como string en un documento que
  # además tiene reglas violables (project.name vacío): el GUARD corta primero
  # (exit 2, sin findings — no procesado ≠ procesado-con-errores).
  cat > "$d/f04.yaml" <<'EOF'
project:
  name: ""
  version: 2026-10-11
assertions: "no soy lista"
EOF
  so=$(python3 "$PS_LINT" "$d/f04.yaml" 2>/dev/null); rc1=$?
  if [ "$rc1" -eq 2 ] && [ -z "$so" ]; then
    ok "F-04 G-6 corta antes que las reglas: exit 2, sin findings"
  else
    bad "F-04 G-6 no cortó primero (exit $rc1, stdout='${so:0:60}')"
  fi

  rm -rf "$d"
}

# ── §5.7 No-modificación (2) — repo real ────────────────────────────────────
test_project_state_linter_matriz_no_modificacion() {
  suite "project-state-linter · no-modificación sobre el repo real (M-01, M-02)"
  local before after rc
  local s1 s2

  # M-01: SHA-256 del archivo evaluado idéntico antes/después
  before=$(sha256sum "$PS_REAL" | cut -d' ' -f1)
  python3 "$PS_LINT" "$PS_REAL" --json >/dev/null 2>&1; rc=$?
  after=$(sha256sum "$PS_REAL" | cut -d' ' -f1)
  if [ "$rc" -eq 0 ] && [ "$before" = "$after" ]; then
    ok "M-01 SHA-256 del YAML idéntico antes/después (exit $rc)"
  else
    bad "M-01 el linter modificó el archivo evaluado (exit $rc, sha antes=$before después=$after)"
  fi

  # M-02: git status + HEAD del repo sin cambios tras la corrida (ruta default)
  s1="$(git -C "$REPO_DIR" status --porcelain; git -C "$REPO_DIR" rev-parse HEAD)"
  (cd "$REPO_DIR" && python3 scripts/lib/project_state_linter.py >/dev/null 2>&1); rc=$?
  s2="$(git -C "$REPO_DIR" status --porcelain; git -C "$REPO_DIR" rev-parse HEAD)"
  if [ "$rc" -eq 0 ] && [ "$s1" = "$s2" ]; then
    ok "M-02 git status/HEAD sin cambios tras la corrida (exit $rc)"
  else
    bad "M-02 el repo cambió tras la corrida del linter (exit $rc)"
  fi
}

# ── I-2: contrato JSON contra su esquema (plan Paso 5 §2) ───────────────────
test_project_state_linter_json_contract() {
  suite "project-state-linter · I-2 contrato JSON vs esquema (ambas direcciones)"
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/ps-json-XXXXXX")

  # (a) esquema versionado y parseable
  check "I-2 esquema existe y parsea como JSON" \
    python3 -c "import json; json.load(open('$PS_LINT_SCHEMA'))"

  # (b) salida REAL del linter valida contra el esquema
  python3 "$PS_LINT" "$PS_REAL" --json > "$d/live.json" 2>/dev/null
  ps_val "I-2 salida real --json del fixture valida contra el esquema" "$d/live.json"

  # 3 instancias conformes
  cat > "$d/ok01.json" <<'EOF'
{"healthy": true, "errors": 0, "warnings": 0, "items": []}
EOF
  ps_val "I-2 conforme A (healthy true, 0/0, items vacío)" "$d/ok01.json"

  cat > "$d/ok02.json" <<'EOF'
{"healthy": true, "errors": 0, "warnings": 1,
 "items": [{"rule": "LINT-14", "key": "k1", "detail": "source user con type A"}]}
EOF
  ps_val "I-2 conforme B (warnings=1 sano)" "$d/ok02.json"

  cat > "$d/ok03.json" <<'EOF'
{"healthy": false, "errors": 2, "warnings": 1,
 "items": [{"rule": "LINT-07", "key": "k1", "detail": "B con check"},
           {"rule": "LINT-19", "key": "k2", "detail": "command string"}]}
EOF
  ps_val "I-2 conforme C (errors>0 → healthy false)" "$d/ok03.json"

  # 4 mutaciones rotas (ambas direcciones de healthy incluidas)
  cat > "$d/mut01.json" <<'EOF'
{"healthy": true, "errors": 0, "items": []}
EOF
  ps_val_reject "I-2 mutación: clave 'warnings' faltante" "$d/mut01.json"

  cat > "$d/mut02.json" <<'EOF'
{"healthy": true, "errors": "0", "warnings": 0, "items": []}
EOF
  ps_val_reject "I-2 mutación: errors con tipo wrong (string)" "$d/mut02.json"

  cat > "$d/mut03.json" <<'EOF'
{"healthy": false, "errors": 0, "warnings": 0, "items": []}
EOF
  ps_val_reject "I-2 mutación: healthy false con errors 0" "$d/mut03.json"

  cat > "$d/mut04.json" <<'EOF'
{"healthy": true, "errors": 1, "warnings": 0, "items": []}
EOF
  ps_val_reject "I-2 mutación: healthy true con errors 1" "$d/mut04.json"

  rm -rf "$d"
}

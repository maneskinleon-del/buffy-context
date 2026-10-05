#!/usr/bin/env bash
# test-skill-lint.sh — tests de scripts/skill-lint.sh (prioridad B2: manifests machine-readable).
# El linter es standalone (--repo) y no toca el sandbox → corre también en modo --quick.
# Fixtures temporales en ${TMPDIR:-/tmp}; limpieza con trap RETURN (se dispara al salir del test).

test_skill_lint_help() {
  suite "skill-lint: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --help
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/skill-lint.sh" --help 2>&1)
  if echo "$OUT" | grep -q 'skill.yaml'; then
    ok "--help documenta el manifest skill.yaml"
  else
    bad "--help documenta el manifest skill.yaml"
  fi
}

test_skill_lint_repo_sano() {
  suite "skill-lint: repo actual sano"
  local OUT RC ERR
  OUT=$(bash "$SCRIPTS_DIR/skill-lint.sh" --json 2>/dev/null); RC=$?
  if [ "$RC" = "0" ]; then
    ok "exit 0 (manifiestos válidos)"
  else
    bad "exit $RC (esperado 0)"
  fi
  jassert "--json: claves y coherencia" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","skills","manifests","errors","warnings","healthy","yaml_validated"}, d.keys(); assert d["manifests"]>=1, "android-agent debe tener manifest"; assert d["errors"]==0, d; assert d["healthy"] is True'
  jassert "--json: warnings = skills sin manifest" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["warnings"]==d["skills"]-d["manifests"], (d["warnings"], d["skills"], d["manifests"]); assert d["manifests"]<=d["skills"]'
  jassert "--json: yaml_validated=true (PyYAML presente)" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["yaml_validated"] is True, "sin PyYAML el linter no debe declarar sano el repo"'
  ERR=$(bash "$SCRIPTS_DIR/skill-lint.sh" --json 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then
    ok "stderr vacío en --json"
  else
    bad "stderr vacío en --json (${#ERR} chars)"
  fi
}

# ── Fix: el linter debe PARSEAR el YAML, no solo mirarle la forma ──────────
# Los 6 manifests con comillas dobles anidadas (roast, weekly-review, ...) pasaban
# el linter (que sólo usa sed/awk) y rompían a todo consumidor que parsea YAML real.
test_skill_lint_yaml_real() {
  suite "skill-lint: sintaxis YAML real (PyYAML)"

  if ! python3 -c 'import yaml' >/dev/null 2>&1; then
    bad "PyYAML disponible (requisito de este test)"
    return
  fi
  ok "PyYAML disponible"

  # (a) Los 44 manifiestos del repo parsean.
  local BAD
  BAD=$(python3 - "$REPO_DIR" <<'PY'
import glob, os, sys, yaml
repo = sys.argv[1]
for f in sorted(glob.glob(os.path.join(repo, ".agents/skills/*/skill.yaml"))):
    try:
        with open(f, encoding="utf-8") as fh:
            yaml.safe_load(fh)
    except Exception as e:
        print("%s: %s" % (os.path.relpath(f, repo), str(e).split("\n")[0]))
PY
)
  if [ -z "$BAD" ]; then
    ok "los 44 manifiestos son YAML válido (PyYAML)"
  else
    bad "manifiestos con YAML inválido"
    printf '%s\n' "$BAD" | sed 's/^/       → /'
  fi

  # (b) El linter DETECTA un YAML inválido (regresión real: sin la capa 2
  #     el fixture de abajo pasaba con exit 0).
  local FIX="${TMPDIR:-/tmp}/buffy-skilllint-yaml-$$"
  rm -rf "$FIX"
  mkdir -p "$FIX/.agents/skills/rota"
  printf '%s\n' '---' 'name: rota' '---' > "$FIX/.agents/skills/rota/SKILL.md"
  # description con comillas dobles anidadas sin escapar = el bug original
  printf '%s\n' \
    'id: rota' \
    'name: "rota"' \
    'version: 1.0.0' \
    'description: "rota con "comillas" anidadas"' \
    'entry: SKILL.md' \
    'origin: local' \
    'safe: true' \
    'triggers:' \
    '  - rota' > "$FIX/.agents/skills/rota/skill.yaml"
  trap 'rm -rf "$FIX"' RETURN
  expect_exit 1 "YAML inválido (comillas anidadas) → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX"
  local MSG
  MSG=$(bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX" 2>&1 || true)
  if echo "$MSG" | grep -q 'YAML inválido'; then
    ok "el error nombra la causa (YAML inválido), no solo la forma"
  else
    bad "el error nombra la causa (YAML inválido)"
    printf '%s\n' "$MSG" | sed 's/^/       → /'
  fi

  # (c) Un manifiesto con block scalar (la forma que adoptamos en los 6) es válido.
  local FIX2="${TMPDIR:-/tmp}/buffy-skilllint-blk-$$"
  rm -rf "$FIX2"
  trap 'rm -rf "$FIX" "$FIX2"' RETURN
  mkdir -p "$FIX2/.agents/skills/bloque"
  printf '%s\n' '---' 'name: bloque' '---' > "$FIX2/.agents/skills/bloque/SKILL.md"
  printf '%s\n' \
    'id: bloque' \
    'name: "bloque"' \
    'version: 1.0.0' \
    'description: >-' \
    '  texto con "comillas" sin escapar' \
    'entry: SKILL.md' \
    'origin: local' \
    'safe: true' \
    'triggers:' \
    '  - bloque' > "$FIX2/.agents/skills/bloque/skill.yaml"
  expect_exit 0 "block scalar (>- ) con comillas → exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX2"
}

test_skill_lint_require_all_gate() {
  # Gate real de CI: TODAS las skills del repo deben tener skill.yaml.
  # Si alguien añade una skill sin manifest, este test falla → hook y CI en rojo.
  suite "skill-lint: gate --require-all en repo real"
  expect_exit 0 "TODAS las skills con manifest (--require-all) → exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --require-all
}

test_skill_lint_android_example() {
  suite "skill-lint: ejemplo android-agent"
  local MF="$REPO_DIR/.agents/skills/android-agent/skill.yaml"
  if [ ! -f "$MF" ]; then
    bad "existe .agents/skills/android-agent/skill.yaml"
    return
  fi
  ok "existe .agents/skills/android-agent/skill.yaml"
  if grep -q '^id:[[:space:]]*android-agent' "$MF"; then ok "id = android-agent"; else bad "id = android-agent"; fi
  if grep -q '^entry:[[:space:]]*SKILL.md' "$MF"; then ok "entry = SKILL.md"; else bad "entry = SKILL.md"; fi
  if [ -f "$REPO_DIR/.agents/skills/android-agent/SKILL.md" ]; then ok "SKILL.md referenciado existe"; else bad "SKILL.md referenciado existe"; fi
  if grep -qE '^safe:[[:space:]]*(true|false)' "$MF"; then ok "safe es booleano"; else bad "safe es booleano"; fi
  if grep -qE '^version:[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+' "$MF"; then ok "version semver"; else bad "version semver"; fi
}

test_skill_lint_manifest_invalido() {
  suite "skill-lint: manifiesto inválido"
  local FIX="${TMPDIR:-/tmp}/buffy-skilllint-inv-$$"
  local FIXE="${TMPDIR:-/tmp}/buffy-skilllint-empty-$$"
  rm -rf "$FIX" "$FIXE"
  mkdir -p "$FIX/.agents/skills/broken-skill" "$FIXE/.agents/skills"
  printf '%s\n' \
    'id: otro-nombre' \
    'version: nope' \
    'safe: quizas' \
    'entry: no-existe.md' \
    'triggers: []' > "$FIX/.agents/skills/broken-skill/skill.yaml"
  trap 'rm -rf "$FIX" "$FIXE"' RETURN
  expect_exit 1 "manifest inválido → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX" --json 2>/dev/null)
  jassert "--json: errores ≥ 4, manifests=1, healthy=false" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["errors"]>=4 and d["manifests"]==1 and d["healthy"] is False, d'
  expect_exit 0 "sin skills no es error (exit 0)" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIXE"
}

# D2.3: `origin` es obligatorio. Sin este test el gate es como el de PyYAML antes
# del fix1 — el linter valida, nadie verifica que valga. Tres ramas: ausente,
# inválido, y presente (para que el test no pase por el motivo equivocado).
test_skill_lint_origin_obligatorio() {
  suite "skill-lint: origin obligatorio (procedencia, D2.3)"
  local BASE="${TMPDIR:-/tmp}/buffy-skilllint-origin-$$"
  rm -rf "$BASE"
  trap 'rm -rf "$BASE"' RETURN
  local caso
  for caso in ausente invalido valido; do
    local FIX="$BASE/$caso"
    mkdir -p "$FIX/.agents/skills/una-skill"
    {
      printf '%s\n' \
        'id: una-skill' \
        'name: Una Skill' \
        'version: 1.0.0' \
        'entry: SKILL.md'
      case "$caso" in
        invalido) printf '%s\n' 'origin: copiado-de-copiar' ;;
        valido)   printf '%s\n' 'origin: local' ;;
      esac
      printf '%s\n' \
        'safe: true' \
        'triggers:' \
        '  - test'
    } > "$FIX/.agents/skills/una-skill/skill.yaml"
    touch "$FIX/.agents/skills/una-skill/SKILL.md"
  done
  expect_exit 1 "origin ausente → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$BASE/ausente"
  expect_exit 1 "origin inválido → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$BASE/invalido"
  expect_exit 0 "origin: local → exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$BASE/valido"
}

test_skill_lint_require_all() {
  suite "skill-lint: --require-all"
  local FIX1="${TMPDIR:-/tmp}/buffy-skilllint-req1-$$"
  local FIX2="${TMPDIR:-/tmp}/buffy-skilllint-req2-$$"
  rm -rf "$FIX1" "$FIX2"
  mkdir -p "$FIX1/.agents/skills/una-skill" "$FIX2/.agents/skills/sin-manifest"
  printf '%s\n' \
    'id: una-skill' \
    'name: Una Skill' \
    'version: 1.0.0' \
    'entry: SKILL.md' \
    'origin: local' \
    'safe: true' \
    'triggers:' \
    '  - test' > "$FIX1/.agents/skills/una-skill/skill.yaml"
  touch "$FIX1/.agents/skills/una-skill/SKILL.md"
  touch "$FIX2/.agents/skills/sin-manifest/SKILL.md"
  trap 'rm -rf "$FIX1" "$FIX2"' RETURN
  expect_exit 0 "--require-all, todo con manifest → exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX1" --require-all
  expect_exit 1 "--require-all, skill sin manifest → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX2" --require-all
  expect_exit 0 "sin --require-all tolera falta de manifest → exit 0" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX2"
}

test_skill_lint_crosscheck_frontmatter() {
  suite "skill-lint: cross-check front-matter SKILL.md"
  local FIX="${TMPDIR:-/tmp}/buffy-skilllint-fm-$$"
  rm -rf "$FIX"
  mkdir -p "$FIX/.agents/skills/mi-skill"
  printf '%s\n' \
    'id: mi-skill' \
    'name: Mi Skill' \
    'version: 1.0.0' \
    'entry: SKILL.md' \
    'origin: local' \
    'safe: true' \
    'triggers:' \
    '  - test' > "$FIX/.agents/skills/mi-skill/skill.yaml"
  printf '%s\n' '---' 'name: otro-nombre' '---' > "$FIX/.agents/skills/mi-skill/SKILL.md"
  trap 'rm -rf "$FIX"' RETURN
  expect_exit 1 "front-matter name ≠ id → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX"
}

# ── Regresión: el linter NUNCA puede reportar sano un escaneo que no ocurrió ──
# Si la enumeración de skills falla (p. ej. process substitution no disponible
# porque falta /dev/fd), el `while read` recorría cero líneas y el linter
# reportaba skills=0 / errors=0 / healthy=true / exit 0. Eso es un FALSE-GREEN
# en un gate de salud de CI: un chequeo que no pudo correr se hacía pasar.
# El guard de skill-lint.sh convierte ese caso en error explícito.
# El hook BUFFY_SKILL_LINT_FORCE_ENUM_FAIL=1 reproduce el fallo de forma
# determinista, sin depender de que el host tenga /dev/fd.
test_skill_lint_enum_fail_not_green() {
  suite "skill-lint: fallo de enumeración no puede ser healthy (anti false-green)"

  local OUT RC MSG
  OUT=$(BUFFY_SKILL_LINT_FORCE_ENUM_FAIL=1 bash "$SCRIPTS_DIR/skill-lint.sh" --json 2>/dev/null); RC=$?
  if [ "$RC" -ne 0 ]; then
    ok "enum-fail → exit $RC (esperado != 0)"
  else
    bad "enum-fail → exit 0 (un escaneo fallido no puede salir limpio)"
  fi
  jassert "--json: enum-fail → healthy=false y errors>0" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["healthy"] is False, d; assert d["errors"]>0, d; assert d["skills"]==0, d'

  MSG=$(BUFFY_SKILL_LINT_FORCE_ENUM_FAIL=1 bash "$SCRIPTS_DIR/skill-lint.sh" 2>&1 || true)
  if echo "$MSG" | grep -q 'fallo de enumeración'; then
    ok "el error dice explícitamente que la enumeración falló"
  else
    bad "el error dice explícitamente que la enumeración falló"
  fi

  # El camino normal no debe estar afectado por el guard: el repo tiene skills,
  # así que N_SKILLS>0 y el guard ni siquiera se activa.
  OUT=$(bash "$SCRIPTS_DIR/skill-lint.sh" --json 2>/dev/null); RC=$?
  if [ "$RC" -eq 0 ]; then
    ok "sin el hook → exit 0 (el guard no ensucia el camino sano)"
  else
    bad "sin el hook → exit 0 (obtuve $RC)"
  fi
  jassert "--json: sin el hook → skills>0 y healthy=true" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["skills"]>0, d; assert d["healthy"] is True, d'
}

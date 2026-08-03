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
  jassert "--json: claves y coherencia" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","skills","manifests","errors","warnings","healthy"}, d.keys(); assert d["manifests"]>=1, "android-agent debe tener manifest"; assert d["errors"]==0, d; assert d["healthy"] is True'
  jassert "--json: warnings = skills sin manifest" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["warnings"]==d["skills"]-d["manifests"], (d["warnings"], d["skills"], d["manifests"]); assert d["manifests"]<=d["skills"]'
  ERR=$(bash "$SCRIPTS_DIR/skill-lint.sh" --json 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then
    ok "stderr vacío en --json"
  else
    bad "stderr vacío en --json (${#ERR} chars)"
  fi
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
    'safe: true' \
    'triggers:' \
    '  - test' > "$FIX/.agents/skills/mi-skill/skill.yaml"
  printf '%s\n' '---' 'name: otro-nombre' '---' > "$FIX/.agents/skills/mi-skill/SKILL.md"
  trap 'rm -rf "$FIX"' RETURN
  expect_exit 1 "front-matter name ≠ id → exit 1" bash "$SCRIPTS_DIR/skill-lint.sh" --repo "$FIX"
}

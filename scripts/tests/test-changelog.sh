#!/usr/bin/env bash
# test-changelog.sh — tests de scripts/changelog-entry.sh (entrada de release
# automática en el CHANGELOG). Todos usan sandbox → saltados en modo --quick.

# Prepara el repo del sandbox para git: quita el hook instalado (no debe correr
# en el sandbox) y fija identidad local.
sb_prep_git() {
  rm -f "$SANDBOX/repo/.git/hooks/pre-commit"
  git -C "$SANDBOX/repo" config user.email "t@test" 2>/dev/null || true
  git -C "$SANDBOX/repo" config user.name "test" 2>/dev/null || true
}

test_changelog_dryrun_structure() {
  suite "changelog: --dry-run genera la entrada (estructura)"
  setup_sandbox
  sb_prep_git
  echo "cambio de prueba" >> "$SANDBOX/repo/README.md"
  git -C "$SANDBOX/repo" add README.md
  git -C "$SANDBOX/repo" commit -qm "feat: cambio de prueba"
  local out rc
  out="$(cd "$SANDBOX/repo" && bash scripts/changelog-entry.sh --dry-run v9.9.9 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] \
     && echo "$out" | grep -q "^### .*— Release v9.9.9" \
     && echo "$out" | grep -q "Cambios incluidos" \
     && echo "$out" | grep -q "feat: cambio de prueba" \
     && echo "$out" | grep -q "Archivos modificados/creados" \
     && echo "$out" | grep -q '`README.md`'; then
    ok "dry-run: cabecera + commits + archivos (exit $rc)"
  else
    bad "dry-run: estructura incompleta (exit $rc)"
    echo "$out" | head -10 | sed 's/^/       → /'
  fi
}

test_changelog_sanitiza_skills() {
  suite "changelog: sanitiza referencias skills/ (sin drift en doctor)"
  setup_sandbox
  sb_prep_git
  mkdir -p "$SANDBOX/repo/.agents/skills/ghost-skill"
  echo "# ghost" > "$SANDBOX/repo/.agents/skills/ghost-skill/SKILL.md"
  git -C "$SANDBOX/repo" add .agents/skills/ghost-skill
  git -C "$SANDBOX/repo" commit -qm "feat: skills/ghost-skill referenciada"
  local out rc
  out="$(cd "$SANDBOX/repo" && bash scripts/changelog-entry.sh --dry-run v9.9.9 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && ! echo "$out" | grep -q 'skills/ghost-skill'; then
    ok "sanitización: no aparece skills/ghost-skill en la entrada (exit $rc)"
  else
    bad "sanitización falló (exit $rc) — la entrada expone skills/ghost-skill"
    echo "$out" | grep 'skills/' | sed 's/^/       → /'
  fi
}

test_changelog_insert_real() {
  suite "changelog: inserción real en copia (cabecera intacta, entrada al inicio)"
  setup_sandbox
  sb_prep_git
  echo "cambio de prueba" >> "$SANDBOX/repo/README.md"
  git -C "$SANDBOX/repo" add README.md
  git -C "$SANDBOX/repo" commit -qm "feat: cambio de prueba"
  local before after rc n_new n_old old_first
  before="$(grep -c '^### ' "$SANDBOX/repo/ai-context/CHANGELOG.md")"
  old_first="$(grep '^### ' "$SANDBOX/repo/ai-context/CHANGELOG.md" | head -1)"
  (cd "$SANDBOX/repo" && bash scripts/changelog-entry.sh v9.9.9 >/dev/null 2>&1)
  rc=$?
  after="$(grep -c '^### ' "$SANDBOX/repo/ai-context/CHANGELOG.md")"
  n_new="$(grep -n 'Release v9.9.9' "$SANDBOX/repo/ai-context/CHANGELOG.md" | head -1 | cut -d: -f1)"
  n_old="$(grep -nF "$old_first" "$SANDBOX/repo/ai-context/CHANGELOG.md" | head -1 | cut -d: -f1)"
  if [ "$rc" -eq 0 ] \
     && [ "$after" -eq $((before+1)) ] \
     && grep -q '# CHANGELOG.md — Historial' "$SANDBOX/repo/ai-context/CHANGELOG.md" \
     && [ -n "$n_new" ] && [ -n "$n_old" ] && [ "$n_new" -lt "$n_old" ]; then
    ok "inserción: +1 entrada, cabecera intacta, nueva antes que la anterior (exit $rc)"
  else
    bad "inserción falló (exit $rc, entradas $before→$after, n_new=$n_new n_old=$n_old)"
  fi
}

#!/usr/bin/env bash
# test-repair.sh — tests de buffy-repair.sh (sourced por run-tests.sh)
# En el repo real solo se prueba dry-run (no escribe). Cualquier --auto
# se ejecuta SIEMPRE dentro del sandbox.

test_repair_help() {
  suite "repair: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/buffy-repair.sh" --help
}

test_repair_dryrun_real() {
  suite "repair: dry-run en repo real (no escribe)"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-repair.sh" 2>&1)
  if echo "$OUT" | grep -q 'Plan de reparación'; then ok "dry-run muestra el plan"; else bad "dry-run muestra el plan"; fi
  if echo "$OUT" | grep -q 'AUTO_SAFE'; then ok "dry-run clasifica AUTO_SAFE"; else bad "dry-run clasifica AUTO_SAFE"; fi
  if echo "$OUT" | grep -q 'REVIEW_REQUIRED'; then ok "dry-run clasifica REVIEW_REQUIRED"; else bad "dry-run clasifica REVIEW_REQUIRED"; fi
  local BEFORE AFTER
  BEFORE=$(git -C "$REPO_DIR" status --porcelain | wc -l)
  bash "$SCRIPTS_DIR/buffy-repair.sh" >/dev/null 2>&1
  AFTER=$(git -C "$REPO_DIR" status --porcelain | wc -l)
  if [ "$BEFORE" = "$AFTER" ]; then
    ok "dry-run no modifica el repo ($BEFORE archivos iguales)"
  else
    bad "dry-run modificó el repo ($BEFORE → $AFTER)"
  fi
}

test_repair_json_dryrun() {
  suite "repair: --json dry-run"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-repair.sh" --json 2>/dev/null)
  jassert "--json dry-run parseable + claves" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","healthy","errors","warnings","applied","plan","review_required"}, d.keys(); assert d["applied"]==[]'
}

test_repair_usage_errors() {
  suite "repair: errores de uso"
  expect_exit 2 "repo inválido → exit 2" bash "$SCRIPTS_DIR/buffy-repair.sh" --repo /no/existe
  expect_exit 2 "--fix inexistente → exit 2" bash "$SCRIPTS_DIR/buffy-repair.sh" --fix no_such_fix
  expect_exit 2 "opción desconocida → exit 2" bash "$SCRIPTS_DIR/buffy-repair.sh" --bogus
}

test_repair_sandbox_dryrun_nochange() {
  suite "repair: dry-run no crea archivos (sandbox)"
  setup_sandbox
  local FIRST
  FIRST=$(sb_doctor_json | python3 -c 'import json,sys; d=json.load(sys.stdin); ms=[i["target"] for i in d["items"] if i.get("id")=="MISSING_SKILL"]; print(ms[0] if ms else "")')
  if [ -z "$FIRST" ]; then
    bad "sandbox sin MISSING_SKILL (no se puede probar)"
    return
  fi
  sb_repair >/dev/null 2>&1
  if [ ! -d "$SANDBOX/repo/.agents/skills/$FIRST" ]; then
    ok "dry-run no crea $FIRST/ (plan-only)"
  else
    bad "dry-run creó $FIRST/ (debería ser solo plan)"
  fi
}

test_repair_sandbox_fix_one() {
  suite "repair: --fix NOMBRE aplica un solo fix (sandbox)"
  setup_sandbox
  local FIRST
  FIRST=$(sb_doctor_json | python3 -c 'import json,sys; d=json.load(sys.stdin); ms=[i["target"] for i in d["items"] if i.get("id")=="MISSING_SKILL"]; print(ms[0] if ms else "")')
  if [ -z "$FIRST" ]; then
    bad "sandbox sin MISSING_SKILL (no se puede probar)"
    return
  fi
  sb_repair --fix create_skill_dir >/dev/null 2>&1
  if [ -f "$SANDBOX/repo/.agents/skills/$FIRST/SKILL.md" ]; then
    ok "--fix create_skill_dir crea $FIRST/SKILL.md"
  else
    bad "--fix create_skill_dir no creó $FIRST/SKILL.md"
  fi
  local NDIR
  NDIR=$(ls -d "$SANDBOX/repo/.agents/skills"/*/ 2>/dev/null | wc -l)
  if [ "$NDIR" = "1" ]; then
    ok "--fix aplica exactamente 1 fix ($NDIR dir)"
  else
    bad "--fix aplicó $NDIR fixes (esperado 1)"
  fi
}

test_repair_sandbox_auto_cycle() {
  suite "repair: --auto en sandbox (drift → reparado)"
  setup_sandbox
  local PRE PRE_ERR PRE_MSK ROUT POST POST_ERR POST_MSK
  PRE=$(sb_doctor_json)
  PRE_ERR=$(printf '%s' "$PRE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  PRE_MSK=$(printf '%s' "$PRE" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(1 for i in d["items"] if i.get("id")=="MISSING_SKILL"))')
  if [ "$PRE_ERR" -gt 0 ] && [ "$PRE_MSK" -gt 0 ]; then
    ok "drift artificial presente (errors=$PRE_ERR, MISSING_SKILL=$PRE_MSK)"
  else
    bad "drift artificial presente (errors=$PRE_ERR, MISSING_SKILL=$PRE_MSK)"
  fi

  ROUT=$(sb_repair --auto --json 2>/dev/null)
  jassert "--auto --json parseable" "$ROUT" 'import json,sys; d=json.load(sys.stdin); assert "applied" in d and "review_required" in d'
  jassert "--auto aplica fixes (applied>0, todos ok)" "$ROUT" 'import json,sys; d=json.load(sys.stdin); assert len(d["applied"])>0; assert all(a["status"]=="ok" for a in d["applied"])'

  POST=$(sb_doctor_json)
  POST_ERR=$(printf '%s' "$POST" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])')
  POST_MSK=$(printf '%s' "$POST" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(1 for i in d["items"] if i.get("id")=="MISSING_SKILL"))')
  if [ "$POST_ERR" = "0" ] && [ "$POST_MSK" = "0" ]; then
    ok "verify: drift→0 (errors $PRE_ERR→$POST_ERR, MISSING_SKILL $PRE_MSK→$POST_MSK)"
  else
    bad "verify: drift residual (errors $PRE_ERR→$POST_ERR, MISSING_SKILL $PRE_MSK→$POST_MSK)"
  fi

  # Regresión del bug `local skill dir` (creaba SKILL.md sueltos): cada skill
  # debe quedar en su propio dir con SKILL.md.
  local NDIR NSKILL
  NDIR=$(ls -d "$SANDBOX/repo/.agents/skills"/*/ 2>/dev/null | wc -l)
  NSKILL=$(ls "$SANDBOX/repo/.agents/skills"/*/SKILL.md 2>/dev/null | wc -l)
  if [ "$NDIR" -ge 1 ] && [ "$NDIR" = "$NSKILL" ]; then
    ok "on-disk: $NDIR skill dirs, cada una con SKILL.md (bug local cubierto)"
  else
    bad "on-disk: dirs=$NDIR skills=$NSKILL (deberían ser iguales y ≥1)"
  fi
}

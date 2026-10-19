#!/usr/bin/env bash
# test-buffy-continuity.sh — tests del nuevo script buffy-continuity.sh.
# sourced por run-tests.sh. Valida: help, JSON output, error codes, estructura.
# Fixture: repo temporal con ai-context/CONTINUE.md (no el repo real).

test_continuity_help() {
  suite "buffy-continuity: --help"
  local out rc
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --help 2>&1); rc=$?
  expect_exit 0 "help → exit 0" bash "$SCRIPTS_DIR/buffy-continuity.sh" --help >/dev/null 2>&1
  if echo "$out" | grep -q "continuidad operativa"; then
    ok "--help documenta el propósito del script"
  else
    bad "--help debería mencionar 'continuidad operativa'"
  fi
  if echo "$out" | grep -q -- "--help"; then
    ok "--help documenta el flag --help"
  else
    bad "--help debería documentar --help"
  fi
  if echo "$out" | grep -q "solo lectura"; then
    ok "--help menciona 'solo lectura'"
  else
    bad "--help debería mencionar 'solo lectura'"
  fi
}

test_continuity_invalid_arg() {
  suite "buffy-continuity: argumento inválido → exit 1"
  expect_exit 1 "arg inválido → exit 1" bash "$SCRIPTS_DIR/buffy-continuity.sh" --bogus
}

test_continuity_missing_file() {
  suite "buffy-continuity: CONTINUE.md inexistente → exit 2"
  local empty_repo
  empty_repo=$(mktemp -d)
  trap 'rm -rf "$empty_repo"' RETURN
  # Repo sin ai-context/CONTINUE.md
  expect_exit 2 "CONTINUE.md inexistente → exit 2" \
    bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$empty_repo"
}

test_continuity_json_structure() {
  suite "buffy-continuity: --json contra fixture → 8 keys + paridad"
  local fixture out rc
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context"
  cat > "$fixture/ai-context/CONTINUE.md" <<'CONT'
# CONTINUE — handoff entre sesiones (instancia local)

> Sesión más reciente: 2026-10-17

## Resumen de la sesión

Trabajo de hoy: implementación de buffy_continuity.

## Pendientes para próxima sesión
- Revisar compatibilidad con Cursor E2E
- Documentar caveat de AGY
- Test de paridad OUTPUT

## Stack del usuario

Buffy Next (MVP buffy_verify) → buffy_context (observaciones) → buffy_continuity (handoff)
CONT

  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1) || {
    bad "script falló con exit $rc"
    return
  }
  rc=$?

  # JSON parseable
  if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    ok "JSON parseable"
  else
    bad "JSON parseable"
    return
  fi

  # 8 keys requeridas
  jassert "8 keys requeridas" "$out" '
import json,sys
d=json.load(sys.stdin)
required={"repo","source_file","last_checkpoint","last_inline_checkpoint","summary","pending","stack","_info"}
missing=required-set(d.keys())
if missing:
    sys.exit(1)
'

  # repo = fixture path (exported for Python access via os.environ)
  export CTX_FIXTURE="$fixture"
  jassert "repo apunta al fixture (REPO_OVERRIDE)" "$out" '
import json,sys,os
d=json.load(sys.stdin)
assert d["repo"] == os.environ["CTX_FIXTURE"]
'

  # source_file correct
  jassert "source_file = ai-context/CONTINUE.md" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["source_file"]=="ai-context/CONTINUE.md"
'

  # _info contiene el texto canónico
  jassert "_info contiene texto canónico" "$out" '
import json,sys
d=json.load(sys.stdin)
assert "continuidad operativa" in d["_info"]
'

  # pending es array con 3 items
  jassert "pending tiene 3 items" "$out" '
import json,sys
d=json.load(sys.stdin)
assert isinstance(d["pending"], list)
assert len(d["pending"]) == 3
'

  # summary contiene el texto esperado
  jassert "summary contiene texto" "$out" '
import json,sys
d=json.load(sys.stdin)
assert "buffy_continuity" in d["summary"]
'

  # stack contiene el texto esperado
  jassert "stack contiene texto" "$out" '
import json,sys
d=json.load(sys.stdin)
assert "buffy_context" in d["stack"]
'
}

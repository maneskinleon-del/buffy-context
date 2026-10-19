#!/usr/bin/env bash
# test-buffy-continuity.sh — tests del script buffy-continuity.sh (contrato v4).
# sourced por run-tests.sh. Valida: help, raw content JSON, error codes diferenciados.
#
# Contrato: el script emite el contenido íntegro de CONTINUE.md como JSON
# (raw content, no parsing). NO extrae secciones ni toca $HOME.

test_continuity_help() {
  suite "buffy-continuity: --help"
  expect_exit 0 "help → exit 0" bash "$SCRIPTS_DIR/buffy-continuity.sh" --help >/dev/null 2>&1
  local out
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --help 2>&1)
  if echo "$out" | grep -q "continuidad operativa"; then
    ok "--help documenta el propósito del script"
  else
    bad "--help debería mencionar 'continuidad operativa'"
  fi
  if echo "$out" | grep -q -- "Exit codes"; then
    ok "--help documenta los exit codes"
  else
    bad "--help debería documentar exit codes"
  fi
  if echo "$out" | grep -q "solo lectura"; then
    ok "--help menciona 'solo lectura'"
  else
    bad "--help debería mencionar 'solo lectura'"
  fi
  if echo "$out" | grep -q "raw"; then
    ok "--help menciona 'raw' (no parseo)"
  else
    bad "--help debería mencionar 'raw' (no parseo)"
  fi
}

test_continuity_invalid_arg() {
  suite "buffy-continuity: argumento inválido → exit 1"
  expect_exit 1 "arg inválido → exit 1" bash "$SCRIPTS_DIR/buffy-continuity.sh" --bogus
}

test_continuity_present_raw_content() {
  suite "buffy-continuity: present → JSON con content crudo (byte a byte)"

  local fixture out rc
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context"

  local fixture_content
  fixture_content='# CONTINUE.md — handoff entre sesiones

## Resumen de la sesión

Trabajo: buffy_continuity MVP + continuity-fusion-guard.

## Pendientes para próxima sesión

- Revisar Cursor E2E
- Documentar caveat AGY
- Test de paridad OUTPUT

## Stack del usuario

Buffy Next (MVP buffy_verify) → buffy_context → buffy_continuity
'
  printf '%s' "$fixture_content" > "$fixture/ai-context/CONTINUE.md"

  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1)
  rc=$?

  if [ "$rc" -ne 0 ]; then
    bad "script falló (exit $rc)"
    dump_out "$out"
    return
  fi

  # JSON parseable
  if echo "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
    ok "JSON parseable"
  else
    bad "JSON no parseable"
    dump_out "$out"
    return
  fi

  # 7 keys: source, path, exists, readable, size_bytes, line_count, content
  jassert "7 keys requeridas (source, path, exists, readable, size_bytes, line_count, content)" "$out" '
import json,sys
d=json.load(sys.stdin)
required={"source","path","exists","readable","size_bytes","line_count","content"}
missing=required-set(d.keys())
if missing:
    print(f"missing: {missing}", file=sys.stderr); sys.exit(1)
'

  # source = "repo"
  jassert "source = repo" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["source"] == "repo", f"got {d[chr(115)+chr(111)+chr(117)+chr(114)+chr(99)+chr(101)]}"
'

  # path contiene ai-context/CONTINUE.md
  jassert "path contiene ai-context/CONTINUE.md" "$out" '
import json,sys
d=json.load(sys.stdin)
assert "/ai-context/CONTINUE.md" in d["path"]
'

  # content matches file content byte-for-byte
  export CF="$fixture"
  jassert "content == byte-for-byte file content" "$out" '
import json,sys,os
fixture = os.environ["CF"]
cf_path = fixture + "/ai-context/CONTINUE.md"
with open(cf_path, encoding="utf-8") as f:
    expected = f.read()
d = json.load(sys.stdin)
assert d["content"] == expected, "content mismatch"
'

  # exists y readable son True
  jassert "exists=true, readable=true" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["exists"] is True
assert d["readable"] is True
'

  # size_bytes > 0
  jassert "size_bytes > 0" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["size_bytes"] > 0
'

  # line_count > 0
  jassert "line_count > 0" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["line_count"] > 0
'
}

test_continuity_not_found() {
  suite "buffy-continuity: CONTINUE.md inexistente → exit 1, error=not_found"
  local empty_repo
  empty_repo=$(mktemp -d)
  trap 'rm -rf "$empty_repo"' RETURN
  # Repo sin ai-context/CONTINUE.md (ni siquiera el directorio ai-context)
  expect_exit 1 "not_found → exit 1" bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$empty_repo"

  # Verifica que el JSON contiene error=not_found
  local out
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$empty_repo" 2>&1) || true
  jassert "JSON contiene error=not_found" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d.get("error") == "not_found"
'
}

test_continuity_empty() {
  suite "buffy-continuity: archivo vacío → exit 3, error=empty"
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context"
  touch "$fixture/ai-context/CONTINUE.md"

  expect_exit 3 "empty → exit 3" bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture"

  # Verifica error=empty en el JSON
  local out
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1) || true
  jassert "JSON contiene error=empty" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d.get("error") == "empty"
'
  jassert "empty incluye size_bytes=0" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d.get("size_bytes") == 0
'
}

test_continuity_unreadable() {
  suite "buffy-continuity: archivo no legible → exit 2, error=unreadable"
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context"
  printf '# test\n' > "$fixture/ai-context/CONTINUE.md"
  chmod 000 "$fixture/ai-context/CONTINUE.md"

  expect_exit 2 "unreadable → exit 2" bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture"

  # Verifica error=unreadable en el JSON
  local out
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1) || true
  jassert "JSON contiene error=unreadable" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d.get("error") == "unreadable"
'

  # Restore perms for cleanup
  chmod 644 "$fixture/ai-context/CONTINUE.md"
}

test_continuity_is_directory() {
  suite "buffy-continuity: ruta es directorio → exit 4, error=is_directory"
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context/CONTINUE.md"

  expect_exit 4 "is_directory → exit 4" bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture"

  # Verifica error=is_directory en el JSON
  local out
  out=$(bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1) || true
  jassert "JSON contiene error=is_directory" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d.get("error") == "is_directory"
'
}

test_continuity_read_only() {
  suite "buffy-continuity: no modifica el archivo (sha256 antes/después)"
  local fixture
  fixture=$(mktemp -d)
  trap 'rm -rf "$fixture"' RETURN
  mkdir -p "$fixture/ai-context"
  printf '# test content\n- item 1\n- item 2\n' > "$fixture/ai-context/CONTINUE.md"

  local sha_before sha_after
  sha_before=$(sha256sum "$fixture/ai-context/CONTINUE.md" | awk '{print $1}')
  bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" >/dev/null 2>&1
  sha_after=$(sha256sum "$fixture/ai-context/CONTINUE.md" | awk '{print $1}')

  if [ "$sha_before" = "$sha_after" ]; then
    ok "sha256 unchanged (read-only)"
  else
    bad "sha256 cambiado — el script modificó el archivo"
  fi
}

test_continuity_no_home() {
  suite "buffy-continuity: no toca $HOME (fuente canónica = repo)"
  local fixture fake_home
  fixture=$(mktemp -d)
  fake_home=$(mktemp -d)
  trap 'rm -rf "$fixture" "$fake_home"' RETURN

  # Crear el archivo correcto en el repo fixture
  mkdir -p "$fixture/ai-context"
  local repo_content="# repo content — CANONICAL"
  printf '%s' "$repo_content" > "$fixture/ai-context/CONTINUE.md"

  # Crear un ~/ai-context/CONTINUE.md con contenido DISTINTO en fake_home
  mkdir -p "$fake_home/ai-context"
  printf '# HOME content — DECOY (no deberia leerse)\npending: [fake items]\n' > "$fake_home/ai-context/CONTINUE.md"

  # Ejecutar con HOME distinto al real
  local out
  out=$(HOME="$fake_home" bash "$SCRIPTS_DIR/buffy-continuity.sh" --json --repo "$fixture" 2>&1)
  local rc=$?

  if [ "$rc" -ne 0 ]; then
    bad "script falló (exit $rc)"
    dump_out "$out"
    return
  fi

  # El content debe ser el del REPO, no el de $HOME
  export CF="$fixture"
  jassert "content proviene del repo (no de HOME)" "$out" '
import json,sys,os
fixture = os.environ["CF"]
cf_path = fixture + "/ai-context/CONTINUE.md"
with open(cf_path) as f:
    repo_content = f.read()
d = json.load(sys.stdin)
assert d["content"] == repo_content, "content matches repo"
assert "DECOY" not in d["content"], "decoy content found — HOME was read!"
'

  # path no apunta a $HOME
  jassert "path no apunta a HOME" "$out" '
import json,sys,os
fixture = os.environ["CF"]
d = json.load(sys.stdin)
assert d["path"].startswith(fixture), "path starts with fixture"
assert "fake_home" not in d["path"]
'
}

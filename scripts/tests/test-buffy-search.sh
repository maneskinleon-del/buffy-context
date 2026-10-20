#!/usr/bin/env bash
# test-buffy-search.sh — tests del contrato --json de buffy-search.sh.
# sourced por run-tests.sh. Valida: contrato JSON con total/len(results),
# error codes diferenciados (empty/invalid/sqlite_unavailable), limit/has_more,
# regresión modo texto, regresión --select --json, DB no FTS5, readonly,
# y indisponibilidad de sqlite3.
#
# Contrato JSON: ["query","repo","results[]","total","limit","has_more","_info"]
#   total = len(results)  ·  has_more = (total == limit)
# Exit codes: 0 ok · 1 empty_query · 2 invalid_query · 3 sqlite_unavailable · 4 db_unreadable · 5 internal_error

SEARCH_SCRIPT="$SCRIPTS_DIR/buffy-search.sh"
# En CI (clone fresco) buffy-search.sh defaulting BUFFY_REPO a $HOME/buffy-context
# no existe → usar REPO_DIR (el working tree real o el clone de la simulación).

# S-01 — query válida: JSON con matches, total == len(results), has_more coherente
test_search_json_matches() {
  suite "buffy-search: --json query con matches"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" 2>/dev/null)
  expect_exit 0 "exit 0 — query válida con matches" env BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" >/dev/null 2>&1
  jassert "JSON parseable" "$out" '
import json,sys
json.load(sys.stdin)
'
  jassert "total == len(results)" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["total"] == len(d["results"])
'
  jassert "results no vacio (hay matches)" "$out" '
import json,sys
d=json.load(sys.stdin)
assert len(d["results"]) > 0
'
}

# S-02 — query sin matches: results [], total=0, has_more=false
test_search_json_no_matches() {
  suite "buffy-search: --json query sin matches"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "xyzz_nonexistent_term_42zz" 2>/dev/null)
  expect_exit 0 "exit 0 — query sin matches" env BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "xyzz_nonexistent_term_42zz" >/dev/null 2>&1
  jassert "results == []" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["results"] == []
'
  jassert "total == 0" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["total"] == 0
'
  jassert "has_more == false" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["has_more"] is False
'
}

# S-03 — query vacia: error empty_query, exit 1
test_search_json_empty() {
  suite "buffy-search: --json query vacia"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "" 2>/dev/null)
  expect_exit 1 "exit 1 — empty_query" env BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "" 2>&1
  jassert "error == empty_query" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["error"] == "empty_query"
'
}

# S-04 — DB no FTS5: error invalid_query, exit 2
#      Se instala un .db vacio (no tiene tabla FTS5) y se apunta XDG_CACHE_HOME.
test_search_json_invalid_query() {
  suite "buffy-search: --json DB no FTS5 → invalid_query"
  local fake_cache fake_db out
  fake_cache=$(mktemp -d)
  fake_db="$fake_cache/buffy-search/search.db"
  mkdir -p "$(dirname "$fake_db")"
  # DB con tabla docs regular (no FTS5) → search_query falla (snippet() no existe) → invalid_query
  sqlite3 "$fake_db" "CREATE TABLE docs(path TEXT, lineno INTEGER, line TEXT);" 2>/dev/null || true
  export XDG_CACHE_HOME="$fake_cache"
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" 2>/dev/null)
  expect_exit 2 "exit 2 — invalid_query (DB no FTS5)" env BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" 2>&1
  jassert "error == invalid_query" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["error"] == "invalid_query"
'
  rm -rf "$fake_cache"
  unset XDG_CACHE_HOME
}

# S-05 — --limit N: total <= limit
test_search_json_limit() {
  suite "buffy-search: --json --limit 5"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json --limit 5 "ADB" 2>/dev/null)
  expect_exit 0 "exit 0 — --limit 5" env BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json --limit 5 "ADB" >/dev/null 2>&1
  jassert "limit == 5 en JSON" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["limit"] == 5
'
  jassert "total <= limit (5)" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["total"] <= 5
'
}

# S-06 — sqlite3 no disponible: error sqlite_unavailable, exit 3
test_search_json_sqlite_unavailable() {
  suite "buffy-search: --json sqlite3 no disponible"
  local fake_cache fake_bin out
  fake_cache=$(mktemp -d)
  fake_bin=$(mktemp -d)
  # PATH con todos los binarios necesarios MENOS sqlite3:
  # command -v sqlite3 debe fallar para trigger sqlite_unavailable (exit 3)
  for cmd in bash sed awk find mkdir python3 grep head cat rm mktemp dirname readlink sha256sum sort; do
    ln -sf "/usr/bin/$cmd" "$fake_bin/$cmd" 2>/dev/null
  done
  export XDG_CACHE_HOME="$fake_cache"
  out=$(BUFFY_REPO="$REPO_DIR" PATH="$fake_bin" bash "$SEARCH_SCRIPT" --json "ADB" 2>/dev/null)
  expect_exit 3 "exit 3 — sqlite_unavailable" env BUFFY_REPO="$REPO_DIR" PATH="$fake_bin" XDG_CACHE_HOME="$fake_cache" bash "$SEARCH_SCRIPT" --json "ADB" 2>&1
  jassert "error == sqlite_unavailable" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["error"] == "sqlite_unavailable"
'
  rm -rf "$fake_cache" "$fake_bin"
  unset XDG_CACHE_HOME
}

# S-07 — regresion: modo texto NO cambio (formato path:lineno: snippet)
test_search_text_regression() {
  suite "buffy-search: modo texto (regresion)"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" "ADB" 2>&1)
  if echo "$out" | grep -qE '[a-zA-Z0-9_/]+\.[a-z]+:[0-9]+:'; then
    ok "text output contiene formato path:lineno: snippet"
  else
    bad "text output deberia contener path:lineno: snippet"
  fi
  if echo "$out" | grep -q '{'; then
    bad "text output NO deberia contener JSON braces"
  else
    ok "text output NO contiene JSON braces"
  fi
}

# S-08 — regresion: --select --json produce selector JSON (no el de search)
test_search_json_select_regression() {
  suite "buffy-search: --select --json (regresion selector)"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --select --json "ADB" 2>/dev/null)
  jassert "JSON parseable (selector)" "$out" '
import json,sys
json.load(sys.stdin)
'
  jassert "selector JSON tiene keys {model,selected,error,degraded}" "$out" '
import json,sys
d=json.load(sys.stdin)
for k in ("model","selected","error","degraded"):
    assert k in d
'
}

# S-09 — contrato: total == len(results) con query amplio
test_search_json_total_equals_len() {
  suite "buffy-search: --json total == len(results) (contrato)"
  local out
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "context" 2>/dev/null)
  jassert "total == len(results)" "$out" '
import json,sys
d=json.load(sys.stdin)
assert d["total"] == len(d["results"])
'
}

# S-10 — readonly: search() no muta la BD (SHA256 estable)
test_search_readonly() {
  suite "buffy-search: search() no muta la BD (readonly)"
  local cache_dir db_path sha1 sha2
  cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-search"
  db_path="$cache_dir/search.db"
  BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" >/dev/null 2>&1
  sha1=$(sha256sum "$db_path" 2>/dev/null | awk '{print $1}')
  BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" >/dev/null 2>&1
  sha2=$(sha256sum "$db_path" 2>/dev/null | awk '{print $1}')
  check "SHA256 de la BD estable tras 2 searches" test "$sha1" = "$sha2"
}

# S-11 — DB corrupta (no es SQLite): error db_unreadable, exit 4
#      Ya implementado en el check case-statement (sqlite3 "SELECT 1;" falla).
test_search_json_corrupt_db() {
  suite "buffy-search: --json DB corrupta → db_unreadable"
  local fake_cache fake_db out
  fake_cache=$(mktemp -d)
  fake_db="$fake_cache/buffy-search/search.db"
  mkdir -p "$(dirname "$fake_db")"
  # Archivo existe (pasa [[ -f "$DB" ]] pero no es SQLite válido)
  echo "not a database file" > "$fake_db"
  export XDG_CACHE_HOME="$fake_cache"
  out=$(BUFFY_REPO="$REPO_DIR" bash "$SEARCH_SCRIPT" --json "ADB" 2>/dev/null)
  expect_exit 4 "exit 4 — db_unreadable (DB corrupta)" env BUFFY_REPO="$REPO_DIR" XDG_CACHE_HOME="$fake_cache" bash "$SEARCH_SCRIPT" --json "ADB" 2>&1
  jassert "error == db_unreadable" "$out" '
  import json,sys
  d=json.load(sys.stdin)
  assert d["error"] == "db_unreadable"
  '
  rm -rf "$fake_cache"
  unset XDG_CACHE_HOME
}

# S-12 — sqlite3 timeout (mock): error internal_error, exit 5
#      El mock sqlite3 delega al real para todo excepto queries con MATCH,
#      que fallan con "database is locked (timeout)".
test_search_json_internal_error() {
  suite "buffy-search: --json timeout interno → internal_error"
  local fake_cache fake_bin real_cache DB out
  fake_cache=$(mktemp -d)
  fake_bin=$(mktemp -d)
  # DB real para pasar el check [[ -f "$DB" ]] y db_unreadable (SELECT 1)
  real_cache="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-search"
  if [ -d "$real_cache" ]; then
    cp -r "$real_cache" "$fake_cache/buffy-search"
  else
    # Si no hay DB real, crear una mínima con FTS5
    mkdir -p "$fake_cache/buffy-search"
    DB="$fake_cache/buffy-search/search.db"
    sqlite3 "$DB" "CREATE VIRTUAL TABLE docs USING fts5(path, lineno, line, tokenize='unicode61');"
    sqlite3 "$DB" "INSERT INTO docs(path, lineno, line) VALUES('test.md', 1, 'ADB');"
  fi
  DB="$fake_cache/buffy-search/search.db"
  # Mock sqlite3: delega al real, excepto queries con MATCH → timeout
  cat > "$fake_bin/sqlite3" << MOCK
#!/usr/bin/env bash
REAL=/usr/bin/sqlite3
if [[ "\$*" == *"MATCH"* ]]; then
  echo "Error: database is locked (timeout)" >&2
  exit 1
fi
exec "\$REAL" "\$@"
MOCK
  chmod +x "$fake_bin/sqlite3"
  export XDG_CACHE_HOME="$fake_cache"
  out=$(BUFFY_REPO="$REPO_DIR" PATH="$fake_bin:$PATH" bash "$SEARCH_SCRIPT" --json "ADB" 2>/dev/null)
  expect_exit 5 "exit 5 — internal_error (timeout simulado)" env BUFFY_REPO="$REPO_DIR" XDG_CACHE_HOME="$fake_cache" PATH="$fake_bin:$PATH" bash "$SEARCH_SCRIPT" --json "ADB" 2>&1
  jassert "error == internal_error" "$out" '
  import json,sys
  d=json.load(sys.stdin)
  assert d["error"] == "internal_error"
  '
  jassert "message contiene 'unexpected search failure'" "$out" '
  import json,sys
  d=json.load(sys.stdin)
  assert "unexpected" in d.get("message","")
  '
  rm -rf "$fake_cache" "$fake_bin"
  unset XDG_CACHE_HOME
}

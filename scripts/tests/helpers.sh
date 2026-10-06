#!/usr/bin/env bash
# helpers.sh — funciones compartidas de la suite de tests (sourced por run-tests.sh)
# Bash puro, sin bats: portable en Termux y cualquier Linux con python3.

# ── Estado global ──────────────────────────────────────────
PASS=0
FAIL=0
SANDBOX=""

ok()   { PASS=$((PASS+1)); echo "  OK   $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL $1"; }

suite() { echo; echo "── $1 ──"; }

# check <desc> <cmd...> — pasa si el comando devuelve 0
check() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$desc"
  else
    bad "$desc"
  fi
}

# BUFFY_TEST_VERBOSE=1 (o `run-tests.sh --verbose`) → muestra stdout+stderr de
# los checks aunque PASEN — diagnóstico de flaky. Por defecto se descarta para
# no ensuciar. En FAIL el diagnóstico SIEMPRE se muestra (C-1: antes expect_exit
# descartaba toda salida con >/dev/null 2>&1 → "falló" sin pista de por qué).
TEST_VERBOSE="${BUFFY_TEST_VERBOSE:-0}"
# dump_out <texto> — imprime salida capturada, acotada y prefijada.
dump_out() {
  [ -n "$1" ] || return 0
  printf '%s\n' "$1" | head -20 | sed 's/^/       │ /'
}

# expect_exit <esperado> <desc> <cmd...> — pasa si el exit code coincide
# Captura la salida del comando (rc igual) para poder mostrarla si falla.
expect_exit() {
  local expected="$1" desc="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" -eq "$expected" ]; then
    ok "$desc (exit $rc)"
    [ "$TEST_VERBOSE" = "1" ] && dump_out "$out"
  else
    bad "$desc (esperado $expected, obtuve $rc)"
    dump_out "$out"
  fi
}

# jassert <desc> <json> <python> — pasa si el python (lee JSON por stdin) no lanza excepción
# El python va entre comillas simples en el caller; usar comillas dobles DENTRO del código.
jassert() {
  local desc="$1" json="$2" code="$3"
  local out rc
  out=$(printf '%s' "$json" | python3 -c "$code" 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "$desc"
    [ "$TEST_VERBOSE" = "1" ] && dump_out "$out"
  else
    bad "$desc"
    printf '%s\n' "$out" | head -1 | sed 's/^/       → /'
  fi
}

# ── Sandbox (HOME aislado + repo copiado) ──────────────────
# Crea drift artificial: sin ~/ai-context y sin skills → el doctor reporta
# errores reparables (MISSING_SNAPSHOT, MISSING_SKILL, NO_AI_CONTEXT_DIR).
setup_sandbox() {
  SANDBOX="${TMPDIR:-/tmp}/buffy-tests-$$"
  rm -rf "$SANDBOX"
  mkdir -p "$SANDBOX/home"
  cp -r "$REPO_DIR" "$SANDBOX/repo"
  rm -rf "$SANDBOX/home/ai-context"
  rm -rf "$SANDBOX/repo/.agents/skills"/*
}

teardown_sandbox() {
  [ -n "$SANDBOX" ] && rm -rf "$SANDBOX"
  SANDBOX=""
}

# Ejecutar los scripts del sandbox con HOME aislado
sb_doctor()       { HOME="$SANDBOX/home" bash "$SANDBOX/repo/scripts/buffy-doctor.sh" "$@"; }
sb_doctor_json()  { HOME="$SANDBOX/home" bash "$SANDBOX/repo/scripts/buffy-doctor.sh" --json "$@" 2>/dev/null; }
sb_repair()       { HOME="$SANDBOX/home" bash "$SANDBOX/repo/scripts/buffy-repair.sh" "$@"; }
sb_agent()        { HOME="$SANDBOX/home" bash "$SANDBOX/repo/scripts/buffy-agent.sh" "$@"; }

# corpus_frozen_ok — ¿el corpus indexado por FTS5 coincide con el del commit
# congelado 40dd565 (base del fixture selector-pool-frozen-2026-08-13)?
# find_scope (buffy-search.sh) indexa: *.md|*.yaml de raíz (depth 1),
# ai-context/ y Knowledge/ (recursivo, sin deprecated). El gate compara el
# ls-tree (paths + blob SHAs) de HEAD vs 40dd565 sobre ese mismo scope:
# archivos nuevos, borrados o editados cambian la expansión/pool → la
# fidelidad vs el fixture degrada SIN que haya bug → SKIP honesto (el
# veredicto viejo necesita re-gen del fixture, no un fix del motor).
# Sin git o sin el ancestro (CI shallow/tarball) → OK: no se puede medir
# drift y el test corre (comportamiento pre-gate).
corpus_frozen_ok() {
  local repo="${1:-${REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null)}}"
  [ -n "$repo" ] || return 0
  command -v git >/dev/null 2>&1 || return 0
  git -C "$repo" cat-file -e 40dd565 2>/dev/null || return 0
  local a b
  a=$(git -C "$repo" ls-tree -r 40dd565 -- ai-context Knowledge | grep -v 'deprecated/' ; \
      git -C "$repo" ls-tree 40dd565 | grep -E '\.(md|yaml)$') 
  b=$(git -C "$repo" ls-tree -r HEAD -- ai-context Knowledge | grep -v 'deprecated/' ; \
      git -C "$repo" ls-tree HEAD | grep -E '\.(md|yaml)$')
  [ -n "$a" ] && [ "$a" = "$b" ]
}

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

# expect_exit <esperado> <desc> <cmd...> — pasa si el exit code coincide
expect_exit() {
  local expected="$1" desc="$2"; shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" -eq "$expected" ]; then
    ok "$desc (exit $rc)"
  else
    bad "$desc (esperado $expected, obtuve $rc)"
  fi
}

# jassert <desc> <json> <python> — pasa si el python (lee JSON por stdin) no lanza excepción
# El python va entre comillas simples en el caller; usar comillas dobles DENTRO del código.
jassert() {
  local desc="$1" json="$2" code="$3"
  if printf '%s' "$json" | python3 -c "$code" >/dev/null 2>&1; then
    ok "$desc"
  else
    bad "$desc"
    printf '%s' "$json" | python3 -c "$code" 2>&1 | head -1 | sed 's/^/       → /'
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

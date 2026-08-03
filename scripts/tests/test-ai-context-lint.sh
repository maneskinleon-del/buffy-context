#!/usr/bin/env bash
# test-ai-context-lint.sh — tests de scripts/ai-context-lint.sh (prioridad B1: schema-lite
# de los archivos críticos de ai-context). El linter es standalone (--repo) y no toca el
# sandbox → corre también en modo --quick. Fixtures temporales en ${TMPDIR:-/tmp};
# limpieza con trap RETURN (se dispara al salir del test).

test_ai_context_lint_help() {
  suite "ai-context-lint: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/ai-context-lint.sh" --help
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" --help 2>&1)
  if echo "$OUT" | grep -q 'INFO-core.md'; then
    ok "--help documenta los archivos validados"
  else
    bad "--help documenta los archivos validados"
  fi
}

test_ai_context_lint_repo_sano() {
  suite "ai-context-lint: repo actual sano"
  local OUT RC ERR
  OUT=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" --json 2>/dev/null); RC=$?
  if [ "$RC" = "0" ]; then
    ok "exit 0 (estructura válida)"
  else
    bad "exit $RC (esperado 0)"
  fi
  jassert "--json: claves y healthy" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"repo","errors","healthy"}, d.keys(); assert d["errors"]==0, d; assert d["healthy"] is True'
  ERR=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" --json 2>&1 1>/dev/null)
  if [ -z "$ERR" ]; then
    ok "stderr vacío en --json"
  else
    bad "stderr vacío en --json (${#ERR} chars)"
  fi
}

test_ai_context_lint_secciones_obligatorias() {
  suite "ai-context-lint: secciones obligatorias"
  # INFO-core.md y CONTINUE.md existen en el repo y tienen las secciones del protocolo.
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" 2>/dev/null)
  if echo "$OUT" | grep -q "sección 'Reglas personales'"; then ok "INFO-core tiene 'Reglas personales'"; else bad "INFO-core tiene 'Reglas personales'"; fi
  if echo "$OUT" | grep -q "sección 'Pendientes para próxima sesión'"; then ok "CONTINUE tiene 'Pendientes para próxima sesión'"; else bad "CONTINUE tiene 'Pendientes para próxima sesión'"; fi
  if echo "$OUT" | grep -q "sección 'Protocolo obligatorio al iniciar sesión'"; then ok "LOAD_CONTEXT tiene 'Protocolo obligatorio al iniciar sesión'"; else bad "LOAD_CONTEXT tiene 'Protocolo obligatorio al iniciar sesión'"; fi
}

test_ai_context_lint_repo_roto() {
  suite "ai-context-lint: repo con secciones faltantes → exit 1"
  local FIX="${TMPDIR:-/tmp}/buffy-aictx-roto-$$"
  rm -rf "$FIX"
  mkdir -p "$FIX/ai-context"
  printf '%s\n' '# hola' > "$FIX/ai-context/INFO-core.md"
  printf '%s\n' '# chau' > "$FIX/ai-context/CONTINUE.md"
  printf '%s\n' '# protocolo' > "$FIX/ai-context/LOAD_CONTEXT.md"
  trap 'rm -rf "$FIX"' RETURN
  expect_exit 1 "secciones faltantes → exit 1" bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX" --json 2>/dev/null)
  jassert "--json: errors >= 4 y healthy=false" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["errors"]>=4, d; assert d["healthy"] is False, d'
}

test_ai_context_lint_frontmatter() {
  suite "ai-context-lint: front-matter semver-lite"
  local FIX1="${TMPDIR:-/tmp}/buffy-aictx-fm1-$$"
  local FIX2="${TMPDIR:-/tmp}/buffy-aictx-fm2-$$"
  rm -rf "$FIX1" "$FIX2"
  mkdir -p "$FIX1/ai-context" "$FIX2/ai-context"
  # X.Y (convención de ai-context) y X.Y.Z (semver completo) son válidos.
  # OJO: además del front-matter, los archivos deben tener sus secciones obligatorias.
  printf '%s\n' '---' 'version: 1.2' 'updated: 2026-08-03' '---' '' '## Sistema' '' '## Hardware' '' '## Reglas personales' '' '## Estructura de proyectos' > "$FIX1/ai-context/INFO-core.md"
  printf '%s\n' '---' 'version: 1.2.4' 'updated: 2026-08-03' '---' '' '## Resumen de la sesión' '' '## Pendientes para próxima sesión' '' '## Stack del usuario' > "$FIX1/ai-context/CONTINUE.md"
  printf '%s\n' '---' 'version: 1.2' 'updated: 2026-08-03' '---' '' '## Protocolo obligatorio al iniciar sesión' '' '## Carga condicional' '' '## Arquitectura de memoria' > "$FIX1/ai-context/LOAD_CONTEXT.md"
  # version rota y fecha rota → error. Todos los archivos con secciones válidas
  # para aislar el fallo al front-matter (solo INFO-core lo tiene roto).
  printf '%s\n' '---' 'version: nope' 'updated: ayer' '---' '' '## Sistema' '' '## Hardware' '' '## Reglas personales' '' '## Estructura de proyectos' > "$FIX2/ai-context/INFO-core.md"
  printf '%s\n' '---' 'version: 1.2' 'updated: 2026-08-03' '---' '' '## Resumen de la sesión' '' '## Pendientes para próxima sesión' '' '## Stack del usuario' > "$FIX2/ai-context/CONTINUE.md"
  printf '%s\n' '---' 'version: 1.2' 'updated: 2026-08-03' '---' '' '## Protocolo obligatorio al iniciar sesión' '' '## Carga condicional' '' '## Arquitectura de memoria' > "$FIX2/ai-context/LOAD_CONTEXT.md"
  trap 'rm -rf "$FIX1" "$FIX2"' RETURN
  expect_exit 0 "version X.Y y X.Y.Z válidos → exit 0" bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX1"
  expect_exit 1 "version/fecha rotos → exit 1" bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX2"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX2" --json 2>/dev/null)
  jassert "--json: 2 errores de front-matter (version + fecha), secciones OK" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert d["errors"]==2, d'
}

test_ai_context_lint_opcion_desconocida() {
  suite "ai-context-lint: opción desconocida → exit 2"
  expect_exit 2 "opción inválida → exit 2" bash "$SCRIPTS_DIR/ai-context-lint.sh" --frobnicate
}

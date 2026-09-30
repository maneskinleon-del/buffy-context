#!/usr/bin/env bash
# test-local-override.sh — regresión del Patrón B (C4-B): resolución de
# INFO-core/AGENTS/PROJECTS vía override .local con fuente única
# (scripts/lib/resolve-path.sh — bash y Python consumen la MISMA regla).
#
# Contrato probado (decisión del operador 2026-09-30):
#   1. La regla vive SOLO en el helper — nadie la reimplementa. Python la
#      consume vía subprocess (una fuente de verdad, sin divergencia).
#   2. Existencia de .local = AUTORIDAD TOTAL (incluso vacío/corrupto —
#      fallback silencioso ocultaría el error).
#   3. Sin .local: el base tracked (genérico, instancia válida).
#   4. Punto de inserción: ANTES de la última extensión (INFO-core.local.md).
#   5. El helper resuelve; el consumidor decide qué significa ausencia.
#
# Corre en --quick (sin sandbox: fixtures en ${TMPDIR:-/tmp} + helper + los
# scripts son standalone con --repo, y selector_m3 se importa por path).

test_resolve_path_regla() {
  suite "local-override: helper resolve-path (fuente única de la regla)"
  local FIX="${TMPDIR:-/tmp}/buffy-lor-$$"
  mkdir -p "$FIX/scripts/lib" "$FIX/ai-context"
  cp "$REPO_DIR/scripts/lib/resolve-path.sh" "$FIX/scripts/lib/"
  printf 'BASE' > "$FIX/ai-context/INFO-core.md"
  trap 'rm -rf "$FIX"' RETURN

  # 1. sin override → base
  expect_exit 0 "sin .local → base" bash "$FIX/scripts/lib/resolve-path.sh" --repo "$FIX" ai-context/INFO-core.md
  check "sin .local → base (ruta exacta)" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX ai-context/INFO-core.md)\" = 'ai-context/INFO-core.md'"

  # 2. override → autoridad (ruta .local)
  printf 'LOCAL' > "$FIX/ai-context/INFO-core.local.md"
  check "con .local → override" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX ai-context/INFO-core.md)\" = 'ai-context/INFO-core.local.md'"

  # 3. override VACÍO → autoridad igual (no hay fallback silencioso)
  : > "$FIX/ai-context/INFO-core.local.md"
  check "override vacío → sigue siendo autoridad" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX ai-context/INFO-core.md)\" = 'ai-context/INFO-core.local.md'"

  # 4. override borrado → vuelve al base (determinismo)
  rm "$FIX/ai-context/INFO-core.local.md"
  check "override borrado → base" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX ai-context/INFO-core.md)\" = 'ai-context/INFO-core.md'"

  # 5. ausente → imprime ruta + exit 1 (el consumidor decide qué significa)
  expect_exit 1 "missing → exit 1" bash "$FIX/scripts/lib/resolve-path.sh" --repo "$FIX" ai-context/NOEXISTE.md
  check "missing → imprime ruta igual" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX ai-context/NOEXISTE.md)\" = 'ai-context/NOEXISTE.md'"

  # 6. sin extensión → sufijo .local directo
  printf 'B' > "$FIX/LICENSE"; printf 'L' > "$FIX/LICENSE.local"
  check "sin extensión → .local directo" bash -c "test \"\$(bash $FIX/scripts/lib/resolve-path.sh --repo $FIX LICENSE)\" = './LICENSE.local'"
}

test_python_consulta_helper() {
  suite "local-override: Python consume el MISMO helper (subprocess)"
  # facts_engine.py resuelve INFO-core llamando al helper — la regla no se
  # duplica en Python (decisión (2) del operador: una sola fuente de verdad).
  if grep -q "resolve-path.sh" "$SCRIPTS_DIR/lib/facts_engine.py"; then
    ok "facts_engine delega en resolve-path.sh (regla única)"
  else
    bad "facts_engine reimplementa la regla (debe delegar en resolve-path.sh)"
  fi
  # Y la resolución real vía subprocess devuelve base cuando no hay override:
  local FIX="${TMPDIR:-/tmp}/buffy-lorpy-$$"
  mkdir -p "$FIX/scripts/lib" "$FIX/ai-context"
  cp "$REPO_DIR/scripts/lib/resolve-path.sh" "$FIX/scripts/lib/"
  printf 'BASE' > "$FIX/ai-context/INFO-core.md"
  trap 'rm -rf "$FIX"' RETURN
  local out
  out=$(python3 - "$FIX" <<'PY' 2>/dev/null
import subprocess, sys
fix = sys.argv[1]
r = subprocess.run(["bash", fix + "/scripts/lib/resolve-path.sh", "--repo", fix, "ai-context/INFO-core.md"], capture_output=True, text=True)
print(r.stdout.strip())
PY
)
  check "subprocess Python → base" bash -c "test \"$out\" = 'ai-context/INFO-core.md'"
}

test_selectornoise_variantes() {
  suite "local-override: selector trata .local igual que su base (paridad)"
  # El ruido de ai-context/* es ESTRUCTURAL (todo ai-context/* salvo
  # CHANGELOG.md): las variantes .local ya quedan cubiertas. El contrato que
  # importa es la PARIDAD con el base (mismo tratamiento, se excluya o no) —
  # y Knowledge/ sigue siendo canónico.
  local out
  out=$(python3 - "$SCRIPTS_DIR/lib/selector_m3.py" <<'PY' 2>/dev/null
import importlib.util, sys
spec = importlib.util.spec_from_file_location("m3", sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
n = m.is_session_noise
ok = (n("ai-context/INFO-core.local.md") == n("ai-context/INFO-core.md")
      and n("ai-context/AGENTS.local.md") == n("ai-context/AGENTS.md")
      and n("ai-context/PROJECTS.local.md") == n("ai-context/PROJECTS.md")
      and n("ai-context/AGENTS.local.md")
      and not n("Knowledge/Android/ADB.md"))
print("OK" if ok else "FAIL")
PY
)
  if [ "$out" = "OK" ]; then
    ok "paridad .local vs base (mismo tratamiento de ruido)"
  else
    bad "selector no trata .local igual que el base ($out)"
  fi
}

test_lint_respeta_override() {
  suite "local-override: lint valida el EFECTIVO (ambas direcciones del contrato)"
  # El lint (standalone, --repo) debe leer el archivo RESUELTO:
  #   a) base mínimo + override con secciones → sano (usa el override)
  #   b) override con secciones MALAS → falla SOBRE el override (autoridad
  #      total: ni fallback silencioso ni validación del base)
  local FIX="${TMPDIR:-/tmp}/buffy-lorlint-$$"
  mkdir -p "$FIX/ai-context"
  trap 'rm -rf "$FIX"' RETURN
  # base genérico: INFO-core SIN secciones (el discriminante de la prueba);
  # el resto de obligatorios válidos para no ensuciar la señal
  printf '%s\n' '# INFO-core (base genérico)' > "$FIX/ai-context/INFO-core.md"
  printf '%s\n' '# AGENTS (base genérico)' > "$FIX/ai-context/AGENTS.md"
  printf '%s\n' '## Resumen de la sesión' '## Pendientes para próxima sesión' '## Stack del usuario' > "$FIX/ai-context/CONTINUE.md"
  printf '%s\n' '## Protocolo obligatorio al iniciar sesión' '## Carga condicional' '## Arquitectura de memoria' > "$FIX/ai-context/LOAD_CONTEXT.md"
  # (a) override con las secciones obligatorias → lint sano (leyó el override)
  printf '%s\n' '## Sistema' '## Hardware' '## Reglas personales' '## Estructura de proyectos' > "$FIX/ai-context/INFO-core.local.md"
  expect_exit 0 "override con secciones → lint sano (lee el efectivo)" \
    bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX"
  # (b) override con secciones MALAS → falla por el override (autoridad total)
  printf '%s\n' '## Seccion-Que-No-Existe-En-Protocolo' > "$FIX/ai-context/INFO-core.local.md"
  expect_exit 1 "override con secciones malas → lint falla (autoridad total)" \
    bash "$SCRIPTS_DIR/ai-context-lint.sh" --repo "$FIX"
}

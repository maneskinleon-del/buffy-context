#!/usr/bin/env bash
# test-documentation.sh — verdad documental: la documentación debe representar
# el estado real. El número canónico de checks NO se hardcodea: se deriva del
# $PASS real del runner. El README debe declarar el MISMO número — si la suite
# crece y alguien olvida actualizar la doc, el CI rompe.
#
# Modelo de contador (Opción A — functional vs meta):
#
#   Functional checks   — los que prueban Buffy directamente (198 full / 182 quick)
#   Meta checks         — los que validan la representación documental (5 full / 5 quick)
#   Total               — functional + meta (203 full / 187 quick)
#
# Cómo se resuelve la paradoja del contador:
#   doc_truth_check recibe el PASS *functional* (antes de esta fase) y valida
#   contra el número *functional* declarado en el README — números estables.
#   El check de TOTAL se hace AL FINAL, contra $PASS ya completo (functional +
#   meta emitidos): si alguien agrega un meta-check sin actualizar el README,
#   el total real crece y el check lo detecta. Auto-derivado, sin constantes.
#
# NO es un test_* descubierto: es una FASE FINAL del runner. Se invoca:
#   doc_truth_check "$PASS_FUNCTIONAL" "$QUICK_MODE"
# sourced por run-tests.sh (después de los test_*).

# ── Estado de verdad documental ────────────────────────────────────────────
DOC_TRUTH_FILES=(README.md ai-context/LOAD_CONTEXT.md)

# doc_truth_check <pass_functional> <quick_true|false>
# 1. El README declara el conteo FUNCTIONAL real (derivado, no hardcodeado).
# 2. La regla de poda de SESION.md (5 entradas o 30KB) coherente en todos lados.
# 3. Anti-regresión: nadie puede volver a escribir "3 sesiones".
# 4. El README declara el TOTAL == functional + meta emitidos (al final).
doc_truth_check() {
  local pass_functional="$1"
  local quick_mode="$2"
  suite "documental-truth: functional + meta representan el estado real"

  local readme="$REPO_DIR/README.md"
  local load_ctx="$REPO_DIR/ai-context/LOAD_CONTEXT.md"
  [ -f "$readme" ] || { bad "README.md existe"; return; }
  [ -f "$load_ctx" ] || { bad "ai-context/LOAD_CONTEXT.md existe"; return; }

  # 1. Conteo FUNCTIONAL — el README declara el mismo número real.
  #    Formato README: "Suite N checks totales (F functional + M meta · Q --quick con QF functional)"
  local decl_total decl_func decl_quick_total decl_quick_func
  decl_total=$(sed -n 's/.*Suite \([0-9][0-9]*\) checks totales.*/\1/p' "$readme" | head -1)
  decl_func=$(sed -n 's/.*(\([0-9][0-9]*\) functional.*/\1/p' "$readme" | head -1)
  decl_quick_total=$(sed -n 's/.*· \([0-9][0-9]*\) `--quick`.*/\1/p' "$readme" | head -1)
  decl_quick_func=$(sed -n 's/.*`--quick` con \([0-9][0-9]*\) functional.*/\1/p' "$readme" | head -1)

  if [ "$quick_mode" = true ]; then
    if [ -n "$decl_quick_func" ] && [ "$decl_quick_func" = "$pass_functional" ]; then
      ok "README: $decl_quick_func functional --quick == suite real ($pass_functional)"
    else
      bad "README declara '$decl_quick_func' functional --quick pero la suite real tiene $pass_functional (¿olvidaste actualizar README?)"
    fi
  else
    if [ -n "$decl_func" ] && [ "$decl_func" = "$pass_functional" ]; then
      ok "README: $decl_func functional == suite real ($pass_functional)"
    else
      bad "README declara '$decl_func' functional pero la suite real tiene $pass_functional (¿olvidaste actualizar README?)"
    fi
  fi

  # 2. La regla de poda de SESION.md unificada (5 entradas O 30KB) coherente.
  if grep -q "máximo 5 entradas" "$readme" && grep -q "Últimas 5 sesiones" "$readme"; then
    ok "README: regla de poda = 5 entradas (tabla + árbol)"
  else
    bad "README: regla de poda debe decir 5 entradas en tabla Y 'Últimas 5 sesiones' en el árbol (quedó '3 sesiones'?)"
  fi
  if grep -q "máximo 5 entradas O ~30KB" "$load_ctx"; then
    ok "LOAD_CONTEXT: regla unificada 'máximo 5 entradas O ~30KB'"
  else
    bad "LOAD_CONTEXT: falta la regla unificada 'máximo 5 entradas O ~30KB'"
  fi

  # 3. Anti-regresión: nadie puede volver a escribir "3 sesiones".
  if grep -q "3 sesiones" "$readme" || grep -q "Últimas 3" "$readme"; then
    bad "README: vuelve a decir '3 sesiones' — regresión del drift documental"
  else
    ok "README: sin residuos de '3 sesiones'"
  fi

  # 4. TOTAL — debe ser el ÚLTIMO check de esta función. Se calcula como
  #    PASS + 1 (lo que PASS será tras emitir este check): así el check se
  #    cuenta a sí mismo y el README declara el total FINAL de la suite.
  #    Si la fase meta crece ANTES de este check, total_real crece y el README
  #    (declarado con el total viejo) deja de matchear → CI rojo.
  local total_real=$((PASS + 1))
  if [ "$quick_mode" = true ]; then
    if [ -n "$decl_quick_total" ] && [ "$decl_quick_total" = "$total_real" ]; then
      ok "README: total --quick $decl_quick_total == suite real ($total_real)"
    else
      bad "README declara total --quick '$decl_quick_total' pero la suite real suma $total_real (¿creció la fase meta sin actualizar README?)"
    fi
  else
    if [ -n "$decl_total" ] && [ "$decl_total" = "$total_real" ]; then
      ok "README: total $decl_total == suite real ($total_real)"
    else
      bad "README declara total '$decl_total' pero la suite real suma $total_real (¿creció la fase meta sin actualizar README?)"
    fi
  fi
}

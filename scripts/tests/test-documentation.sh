#!/usr/bin/env bash
# test-documentation.sh — verdad documental: la documentación debe representar
# el estado real. El número canónico de checks NO se hardcodea: se deriva del
# $PASS real del runner. El README debe declarar el MISMO número — si la suite
# crece y alguien olvida actualizar la doc, el CI rompe.
#
# Modelo de contador (Opción A — functional vs meta):
#
#   Functional checks   — los que prueban Buffy directamente (derivados dinámicamente)
#   Meta checks         — los que validan la representación documental (derivados dinámicamente)
#   Total               — functional + meta (derivados dinámicamente)
#
# NOTA: estos números NO se escriben a mano — el runner los deriva de $PASS en
# cada corrida y el README debe declararlos. No poner cifras en estos comentarios:
# cada vez que la suite crece, quedarían desactualizados (drift documental).
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
  # Instancia #8 (2026-09-30): comparar contra PASSED contamina la señal —
  # cuando otro test falla, passed baja y el README (correcto) "miente".
  # Comparar contra TOTALES (passed+failed): son invariantes ante fallos
  # ajenos, así doc_truth solo muerde cuando la doc realmente miente.
  local pre_fail="$FAIL"   # FAILs funcionales previos a esta fase (la fase meta aún no emitió)
  local functional_total=$((pass_functional + pre_fail))

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
    if [ -n "$decl_quick_func" ] && [ "$decl_quick_func" = "$functional_total" ]; then
      ok "README: $decl_quick_func functional --quick == suite real ($functional_total)"
    else
      bad "README declara '$decl_quick_func' functional --quick pero la suite total tiene $functional_total (¿olvidaste actualizar README?)"
    fi
  else
    if [ -n "$decl_func" ] && [ "$decl_func" = "$functional_total" ]; then
      ok "README: $decl_func functional == suite real ($functional_total)"
    else
      bad "README declara '$decl_func' functional pero la suite total tiene $functional_total (¿olvidaste actualizar README?)"
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

  # 4. Anti-cascada (instancia #8): doc_truth compara contra TOTALES
  #    (passed+failed), nunca contra passed — los passed incorporan FAILs
  #    ajenos: un FAIL en cualquier parte de la suite los baja y este check
  #    diría "README miente" cuando en realidad falló OTRO test (la señal se
  #    contamina). Guard de introspección: nadie puede reintroducir la
  #    comparación contra passed en esta fase. (El test no puede assertionar
  #    su propia no-cascada; la introspección sí — la no-cascada ya quedó
  #    demostrada empíricamente en CI con la suite en 344+1.)
  local src
  src=$(declare -f doc_truth_check)
  if echo "$src" | grep -qE '\$\{?PASS\}?\b|PASS \+ 1|PASS\+1'; then
    bad "doc_truth vuelve a comparar contra passed (cascada, instancia #8 — comparar contra passed+failed)"
  else
    ok "doc_truth compara contra totales (anti-cascada #8)"
  fi

  # 5. TOTAL — debe ser el ÚLTIMO check de esta función. Se calcula como
  #    PASS+FAIL+1 (todo lo emitido + este check): los TOTALES son invariantes
  #    ante fallos ajenos (instancia #8) — si otro test falla, passed baja
  #    pero passed+failed no cambia, y este check no se contagia.
  local total_real=$((PASS + FAIL + 1))
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

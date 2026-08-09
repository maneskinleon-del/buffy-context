#!/usr/bin/env bash
# test-documentation.sh — verdad documental: la documentación debe representar
# el estado real. El número canónico de checks NO se hardcodea: se deriva del
# $PASS real del runner (run-tests.sh lo pasa como argumento). El README debe
# declarar ese mismo número — si la suite crece (196 → 203) y alguien olvida
# actualizar la doc, el CI rompe. Ese es el objetivo: eliminar el drift
# documental como categoría, no corregirlo a mano cada vez.
#
# NO es un test_* descubierto: es una FASE FINAL del runner (debe correr con
# el conteo total ya calculado). Se invoca desde run-tests.sh como:
#   doc_truth_check "$PASS" "$QUICK_MODE"
#
# sourced por run-tests.sh (después de los test_*).

# ── Estado de verdad documental ────────────────────────────────────────────
# Archivos que la verdad documental controla (rutas relativas al repo).
DOC_TRUTH_FILES=(README.md ai-context/LOAD_CONTEXT.md)

# doc_truth_check <pass_total> <quick_true|false>
# Compara el conteo real de la suite contra lo que declara el README y que
# la regla de poda de SESION.md (5 entradas o 30KB) sea coherente en todos lados.
doc_truth_check() {
  local pass_total="$1"
  local quick_mode="$2"
  suite "documental-truth: la doc representa el estado real"

  local readme="$REPO_DIR/README.md"
  local load_ctx="$REPO_DIR/ai-context/LOAD_CONTEXT.md"
  [ -f "$readme" ] || { bad "README.md existe"; return; }
  [ -f "$load_ctx" ] || { bad "ai-context/LOAD_CONTEXT.md existe"; return; }

  # 1. El README declara el conteo REAL de checks (derivado, no hardcodeado).
  #    En modo --quick el conteo real es el de quick; en full, el completo.
  local declared_full declared_quick
  declared_full=$(sed -n 's/.*Suite \([0-9][0-9]*\) checks.*/\1/p' "$readme" | head -1)
  declared_quick=$(sed -n 's/.*(\([0-9][0-9]*\) `--quick`).*/\1/p' "$readme" | head -1)
  if [ "$quick_mode" = true ]; then
    if [ -n "$declared_quick" ] && [ "$declared_quick" = "$pass_total" ]; then
      ok "README declara $declared_quick checks --quick == suite real ($pass_total)"
    else
      bad "README declara '$declared_quick' --quick pero la suite real tiene $pass_total (¿olvidaste actualizar README?)"
    fi
  else
    if [ -n "$declared_full" ] && [ "$declared_full" = "$pass_total" ]; then
      ok "README declara $declared_full checks == suite real ($pass_total)"
    else
      bad "README declara '$declared_full' checks pero la suite real tiene $pass_total (¿olvidaste actualizar README?)"
    fi
  fi

  # 2. La regla de poda de SESION.md unificada (5 entradas O 30KB) coherente.
  #    README tiene DOS menciones: tabla (línea 29) y árbol (línea 47).
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
}

#!/usr/bin/env bash
# test-granularity-16B.sh — Paso 16B (granularidad del pasaje, pool regenerado).
# Cubre:
#   - sintaxis del runner y de las libs que usa (expand_query, selector_m3)
#   - sin Ollama: verifica que el runner usa H1 real (NUNCA H2/oráculo), que
#     PAS_PAD=4 está incluido en el barrido, que --repeat habilita G2, que el
#     pool NO se construye con gold (no inyección) y que los params declarados
#     (max-passages=400, rescue 0.545, top-K) están presentes.
# sourced por run-tests.sh.

test_gran16b_sintaxis() {
  suite "granularity-16B: sintaxis"
  if bash -n "$SCRIPTS_DIR/tests/evals/run-granularity-PC.sh" 2>/dev/null; then
    ok "bash -n run-granularity-PC.sh"
  else
    bad "bash -n run-granularity-PC.sh"
  fi
  if python3 -m py_compile "$SCRIPTS_DIR/lib/expand_query.py" 2>/dev/null; then
    ok "py_compile expand_query.py (H1 real)"
  else
    bad "py_compile expand_query.py"
  fi
  if python3 -m py_compile "$SCRIPTS_DIR/lib/selector_m3.py" 2>/dev/null; then
    ok "py_compile selector_m3.py (M3 V6)"
  else
    bad "py_compile selector_m3.py"
  fi
  # el heredoc python del runner debe compilar
  if python3 - "$SCRIPTS_DIR/tests/evals/run-granularity-PC.sh" <<'PY' 2>/dev/null
import sys
src = open(sys.argv[1], encoding="utf-8").read()
start = src.index("<<'PY'") + len("<<'PY'")
lines = src[start:].splitlines(True)
py = []
for ln in lines:
    if ln.rstrip("\n") == "PY":
        break
    py.append(ln)
compile("".join(py), "run-granularity.py", "exec")
PY
  then
    ok "heredoc python del runner compila"
  else
    bad "heredoc python del runner NO compila"
  fi
}

test_gran16b_params_no_ollama() {
  suite "granularity-16B: H1 real / no-H2 / PAD=4 / --repeat (sin Ollama)"
  local runner="$SCRIPTS_DIR/tests/evals/run-granularity-PC.sh"

  # 1) H1 real, NUNCA H2: el runner importa expand_query y usa expansion_terms;
  #    NUNCA referencia DICT_H2_EXTRA ni los terms del fixture (oráculo).
  local src
  src=$(cat "$runner")
  if printf '%s' "$src" | grep -q "import expand_query" \
     && printf '%s' "$src" | grep -q "H1_TERMS_FN = expand_query.expansion_terms" \
     && ! printf '%s' "$src" | grep -q "DICT_H2"; then
    ok "usa H1 real (expand_query.expansion_terms), sin H2/oráculo"
  else
    bad "runner no usa H1 real y/o referencia H2"
  fi
  # los terms del fixture NO deben usarse como query (solo query + H1)
  if ! printf '%s' "$src" | grep -qE "q\[\"terms\"\]|q\.get\(\"terms\"|gold_facts.*terms"; then
    ok "no usa los terms del fixture (oráculo H2) como query"
  else
    bad "runner podría usar terms del fixture (revisar)"
  fi

  # 2) PAS_PAD=4 está incluido en el barrido default
  if printf '%s' "$src" | grep -qE 'PADS="0 1 2 4"'; then
    ok "barrido default incluye PAS_PAD=4 (PADS='0 1 2 4')"
  else
    bad "barrido default no incluye PAD=4"
  fi
  if printf '%s' "$src" | grep -Fq -- '--pads'; then
    ok "flag --pads presente"
  else
    bad "falta flag --pads"
  fi

  # 3) --repeat para determinismo G2
  if printf '%s' "$src" | grep -Fq -- '--repeat'; then
    ok "flag --repeat presente (G2)"
  else
    bad "falta flag --repeat (G2)"
  fi
  if printf '%s' "$src" | grep -q 'determinism_hash'; then
    ok "determinism_hash en la salida JSON"
  else
    bad "falta determinism_hash"
  fi

  # 4) params declarados a priori: max-passages=400, rescue 0.545, top-K=10,
  #    M3 V6 (selector_m3), sin inyección de gold al pool
  if printf '%s' "$src" | grep -q 'MAX_PASSAGES = 400'; then
    ok "guard F2 max-passages=400 declarado"
  else
    bad "falta MAX_PASSAGES=400"
  fi
  if printf '%s' "$src" | grep -q 'RESCUE_LOW = 0.545'; then
    ok "piso rescue 0.545 (no se toca)"
  else
    bad "falta RESCUE_LOW=0.545"
  fi
  if printf '%s' "$src" | grep -q 'import selector_m3' \
     && printf '%s' "$src" | grep -q 'selector_m3.W'; then
    ok "M3 V6 real (selector_m3.py) puntúa el pool"
  else
    bad "no usa selector_m3 (M3 V6 real)"
  fi
  if printf '%s' "$src" | grep -q "NO se inyecta gold al pool"; then
    ok "sin inyección de gold al pool (declarado)"
  else
    bad "falta declaración de no-inyección de gold"
  fi
  # Inyección = gold_files/gold_facts usados para AÑADIR pasajes al pool.
  # El pool se construye SOLO con L/X/S/P (variables cands_*/p_items); gold
  # aparece únicamente en la sección de métricas. Verificamos que la
  # construcción del pool no referencia gold_files/gold_facts en su cuerpo.
  local build_block
  build_block=$(printf '%s' "$src" | sed -n '/── pool dedup/,/── M3 V6/p')
  if ! printf '%s' "$build_block" | grep -q "gold_files\|gold_facts"; then
    ok "pool construido sin gold (solo L/X/S/P)"
  else
    bad "pool referencia gold_files/gold_facts en su construcción"
  fi

  # 5) el runner exige el fixture del EVAL
  if printf '%s' "$src" | grep -q 'eval-ctx-PC-2026-08-11.json'; then
    ok "fixture EVAL congelado referenciado"
  else
    bad "no referencia el fixture EVAL"
  fi
}

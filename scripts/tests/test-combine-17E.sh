#!/usr/bin/env bash
# test-combine-17E.sh — Paso 17E (combinación V1 + DICT_H1_B sobre fixture fx-2026-08-15-001).
# Cubre (sin Ollama):
#   - sintaxis del orquestador run-combine-17E.sh y del analizador analiza-17E.py
#   - heredoc python del orquestador compila (anti-regresión del sanity/gate)
#   - params congelados: fixture fx-2026-08-15-001, corpus_hash 0af49cc666d872a6,
#     4 configs ×2 G2 (A/B-solo/V1-solo/T), gate §4 presente con dominancia combinada
#   - anti-oráculo: términos de DICT_H1_B ∩ gold_facts del EVAL = ∅ (el dict NO
#     contiene la respuesta — el dict ya pasó esto en 17B; se re-verifica aquí)
#   - cobertura de gold_files ⊆ fixture/corpus (spec §3.1 check 3)
#   - orden estricto: sanity ANTES de T; STOP (exit 3) si el sanity falla
# sourced por run-tests.sh.
# shellcheck disable=SC2312

FIXTURE_DIR="$SCRIPTS_DIR/tests/evals/fixtures/fx-2026-08-15-001"
ORCH="$SCRIPTS_DIR/tests/evals/run-combine-17E.sh"
ANAL="$SCRIPTS_DIR/tests/evals/analiza-17E.py"
DICT="$SCRIPTS_DIR/tests/evals/dict_h1_b.json"
EVAL_F="$SCRIPTS_DIR/tests/evals/eval-ctx-PC-2026-08-11.json"
FIX_HASH="0af49cc666d872a6"

test_combine17e_sintaxis() {
  suite "combine-17E: sintaxis"
  if bash -n "$ORCH" 2>/dev/null; then
    ok "bash -n run-combine-17E.sh"
  else
    bad "bash -n run-combine-17E.sh"
  fi
  if python3 -m py_compile "$ANAL" 2>/dev/null; then
    ok "py_compile analiza-17E.py"
  else
    bad "py_compile analiza-17E.py"
  fi
  # el heredoc python del orquestador debe compilar (sanity + gate)
  if python3 - "$ORCH" <<'PY' 2>/dev/null
import sys
src = open(sys.argv[1], encoding="utf-8").read()
import re
# extraer todos los heredocs <<'PY' ... PY del orquestador
starts = [m.end() for m in re.finditer(r"<<'PY'\n", src)]
if not starts:
    sys.exit(1)
for s in starts:
    end = src.index("\nPY", s)
    compile(src[s:end], "run-combine-17E.py", "exec")
PY
  then
    ok "heredoc(s) python del orquestador compilan"
  else
    bad "heredoc(s) python del orquestador compilan"
  fi
}

test_combine17e_params_no_ollama() {
  suite "combine-17E: fixture congelado / configs ×2 G2 / gate §4 / orden sanity→T"
  local src
  src=$(cat "$ORCH")

  # 1) fixture congelado + hash esperado por contenido
  if printf '%s' "$src" | grep -q "fx-2026-08-15-001" \
     && printf '%s' "$src" | grep -q "$FIX_HASH"; then
    ok "fixture fx-2026-08-15-001 + corpus_hash $FIX_HASH (identidad por contenido)"
  else
    bad "fixture fx-2026-08-15-001 + corpus_hash $FIX_HASH (identidad por contenido)"
  fi

  # 2) 4 configs ×2 G2: A, B-solo, V1-solo (sanity) + T
  if printf '%s' "$src" | grep -q 'CFG\[A\]=' \
     && printf '%s' "$src" | grep -q 'CFG\[B\]=' \
     && printf '%s' "$src" | grep -q 'CFG\[V1\]=' \
     && printf '%s' "$src" | grep -q -- '--variant V1 --dict' ; then
    ok "configs A/B-solo/V1-solo + T (V1 + DICT_H1_B), repetidas ×2 (G2)"
  else
    bad "configs A/B-solo/V1-solo + T (V1 + DICT_H1_B), repetidas ×2 (G2)"
  fi

  # 3) gate §4: dominancia combinada (leak ≤ min, attr ≥ max, pRel ≥ min, contain ≥ 0.80)
  if printf '%s' "$src" | grep -q "1 leak ≤ min" \
     && printf '%s' "$src" | grep -q "2 attr ≥ max" \
     && printf '%s' "$src" | grep -q "3 Q05 ≥ 1" \
     && printf '%s' "$src" | grep -q "4 sin regresión por gold" \
     && printf '%s' "$src" | grep -q "5 pRel ≥ min" \
     && printf '%s' "$src" | grep -q "6 contain ≥ 0.80" \
     && printf '%s' "$src" | grep -q "7 G2"; then
    ok "gate §4 completo: 7 criterios (dominancia combinada + no-regresión + G2)"
  else
    bad "gate §4 completo: 7 criterios (dominancia combinada + no-regresión + G2)"
  fi

  # 4) orden estricto: sanity de controles ANTES de T; STOP si falla
  if printf '%s' "$src" | grep -q "4/6 · verificación de sanity de controles" \
     && printf '%s' "$src" | grep -q "SANITY FALLÓ — STOP antes de T" \
     && printf '%s' "$src" | grep -q "5/6 · T = V1 + DICT_H1_B"; then
    ok "orden estricto: sanity (4/6) → solo si OK → T (5/6) → gate (6/6)"
  else
    bad "orden estricto: sanity (4/6) → solo si OK → T (5/6) → gate (6/6)"
  fi

  # 5) cobertura de golds: el orquestador valida gold_files ⊆ fixture (spec §3.1)
  if printf '%s' "$src" | grep -q "cobertura de golds ⊆ fixture"; then
    ok "check de cobertura golds ⊆ fixture presente en el orquestador"
  else
    bad "check de cobertura golds ⊆ fixture presente en el orquestador"
  fi
}

test_combine17e_anti_oracle_y_cobertura() {
  suite "combine-17E: anti-oráculo (dict ∩ golds = ∅) + cobertura golds ⊆ fixture"
  # 1) anti-oráculo: los términos de DICT_H1_B no deben contener gold_facts del EVAL
  if python3 - "$DICT" "$EVAL_F" "$SCRIPTS_DIR/lib" <<'PY' 2>/dev/null
import json, sys
dict_path, eval_path, libdir = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, libdir)
import expand_query

A = dict(expand_query.DICT_H1)
B = json.load(open(dict_path))["h1"]

ev = json.load(open(eval_path))
golds = set()
for q in ev["queries"]:
    for f in q.get("gold_facts", []):
        if f.get("text", "").strip():
            golds.add(f["text"].lower())

terms_A = {t for vals in A.values() for t in vals}
terms_B = {t for vals in B.values() for t in vals}
nuevos = terms_B - terms_A
inter = golds & nuevos
assert not inter, "ORACULO: %s" % sorted(inter)
print("  términos B nuevos vs A:", len(nuevos))
PY
  then
    ok "anti-oráculo: términos DICT_H1_B ∩ gold_facts = ∅ (dict sin respuesta)"
  else
    bad "anti-oráculo: términos DICT_H1_B ∩ gold_facts = ∅ (dict sin respuesta)"
  fi

  # 2) cobertura: todos los gold_files del EVAL están dentro del fixture/corpus
  if python3 - "$EVAL_F" "$FIXTURE_DIR" <<'PY' 2>/dev/null
import json, os, sys
eval_path, fix = sys.argv[1], sys.argv[2]
corpus_files = set()
for root, dirs, fnames in os.walk(os.path.join(fix, "corpus")):
    for fn in fnames:
        rel = os.path.relpath(os.path.join(root, fn), os.path.join(fix, "corpus"))
        corpus_files.add(rel)
missing = []
for q in json.load(open(eval_path))["queries"]:
    for gf in q.get("gold_files", []):
        if gf not in corpus_files:
            missing.append((q["id"], gf))
assert not missing, "golds fuera del fixture: %s" % missing
print("  golds ⊆ fixture/corpus ✓")
PY
  then
    ok "cobertura: gold_files del EVAL ⊆ fixture/corpus (check 3, spec §3.1)"
  else
    bad "cobertura: gold_files del EVAL ⊆ fixture/corpus (check 3, spec §3.1)"
  fi
}

test_combine17e_sanity_logic() {
  suite "combine-17E: lógica de sanity (direcciones de efecto + fixture hash en JSON)"
  # la lógica de sanity del orquestador (sección 4) debe referenciar los campos
  # reales del JSON del runner 17C en modo fixture
  local src
  src=$(cat "$ORCH")
  if printf '%s' "$src" | grep -q "fixture_corpus_hash" \
     && printf '%s' "$src" | grep -q "attributed_total" \
     && printf '%s' "$src" | grep -q "cross_domain_leakage_avg" \
     && printf '%s' "$src" | grep -q "B-solo no rescata Q05" \
     && printf '%s' "$src" | grep -q "V1 no reduce"; then
    ok "sanity usa campos reales del runner (fixture_corpus_hash, attributed_total, leak) + direcciones de efecto"
  else
    bad "sanity usa campos reales del runner (fixture_corpus_hash, attributed_total, leak) + direcciones de efecto"
  fi
  # el analizador también debe usar los campos reales y el veredicto del gate
  local an
  an=$(cat "$ANAL")
  if printf '%s' "$an" | grep -q "fixture_corpus_hash" \
     && printf '%s' "$an" | grep -q "GATE 17E" \
     && printf '%s' "$an" | grep -q "NO ADOPTADA"; then
    ok "analizador: campos reales + veredicto gate (adoptada / NO ADOPTADA)"
  else
    bad "analizador: campos reales + veredicto gate (adoptada / NO ADOPTADA)"
  fi
}

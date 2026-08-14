#!/usr/bin/env bash
# test-bridge-17B.sh — Paso 17B (puente semántico DICT_H1, A/B).
# Cubre (sin Ollama):
#   - sintaxis del runner 17B y de las libs que usa (expand_query, selector_m3)
#   - PADS default = 4 (la granularidad NO es variable de este paso)
#   - flags --dict y --repeat presentes; determinism_hash en el JSON
#   - H1 real (importa expand_query) sin H2/terms del fixture (oráculo)
#   - anti-oráculo: términos NUEVOS de DICT_H1_B ∩ gold_facts del EVAL = ∅,
#     y hash de la variante B = f534283f (congelada)
#   - parámetros congelados: RESCUE_LOW=0.545, LIMIT=10, MAX_PASSAGES=400,
#     selector_m3 importado (M3 V6 real), sin inyección de gold en el pool
# sourced por run-tests.sh.

test_bridge17b_sintaxis() {
  suite "bridge-17B: sintaxis"
  if bash -n "$SCRIPTS_DIR/tests/evals/run-bridge-17B.sh" 2>/dev/null; then
    ok "bash -n run-bridge-17B.sh"
  else
    bad "bash -n run-bridge-17B.sh"
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
  # el heredoc python del runner 17B debe compilar
  if python3 - "$SCRIPTS_DIR/tests/evals/run-bridge-17B.sh" <<'PY' 2>/dev/null
import sys
src = open(sys.argv[1], encoding="utf-8").read()
start = src.index("<<'PY'") + len("<<'PY'")
lines = src[start:].splitlines(True)
py = []
for ln in lines:
    if ln.rstrip("\n") == "PY":
        break
    py.append(ln)
compile("".join(py), "run-bridge-17B.py", "exec")
PY
  then
    ok "heredoc python del runner 17B compila"
  else
    bad "heredoc python del runner 17B NO compila"
  fi
}

test_bridge17b_params_no_ollama() {
  suite "bridge-17B: PADS=4 / --dict / H1 sin oráculo / anti-oráculo / params"
  local runner="$SCRIPTS_DIR/tests/evals/run-bridge-17B.sh"
  local dict="$SCRIPTS_DIR/tests/evals/dict_h1_b.json"
  local eval_f="$SCRIPTS_DIR/tests/evals/eval-ctx-PC-2026-08-11.json"
  local src
  src=$(cat "$runner")

  # 1) H1 real, NUNCA H2: importa expand_query; NO referencia DICT_H2/oráculo
  if printf '%s' "$src" | grep -q "import expand_query" \
     && printf '%s' "$src" | grep -q "H1_TERMS_FN = expand_query.expansion_terms" \
     && ! printf '%s' "$src" | grep -q "DICT_H2"; then
    ok "usa H1 real (expand_query.expansion_terms), sin H2/oráculo"
  else
    bad "usa H1 real (expand_query.expansion_terms), sin H2/oráculo"
  fi

  # 2) PADS default = 4 (granularidad NO es variable del Paso 17)
  if printf '%s' "$src" | grep -q 'PADS="4"' \
     && ! printf '%s' "$src" | grep -q 'PADS="0 1 2 4"'; then
    ok "PADS default = 4 (16B barria 0/1/2/4; 17B congela 4)"
  else
    bad "PADS default = 4 (16B barria 0/1/2/4; 17B congela 4)"
  fi

  # 3) flags --dict y --repeat presentes; determinism_hash en el JSON
  if printf '%s' "$src" | grep -q -- '--dict)' \
     && printf '%s' "$src" | grep -q -- '--repeat)' \
     && printf '%s' "$src" | grep -q "determinism_hash"; then
    ok "flags --dict/--repeat + determinism_hash (G2) presentes"
  else
    bad "flags --dict/--repeat + determinism_hash (G2) presentes"
  fi

  # 4) la variante B carga desde JSON y expand_query.DICT_H1 se reemplaza
  if printf '%s' "$src" | grep -q 'expand_query.DICT_H1 = _v.get("h1", _v)'; then
    ok "runner carga variante B desde --dict (reemplaza DICT_H1)"
  else
    bad "runner carga variante B desde --dict (reemplaza DICT_H1)"
  fi

  # 5) parámetros congelados: piso 0.545, max-passages 400, M3 V6 importado
  if printf '%s' "$src" | grep -q "RESCUE_LOW = 0.545" \
     && printf '%s' "$src" | grep -q "MAX_PASSAGES = 400" \
     && printf '%s' "$src" | grep -q "import selector_m3"; then
    ok "params congelados: RESCUE_LOW=0.545, MAX_PASSAGES=400, M3 V6"
  else
    bad "params congelados: RESCUE_LOW=0.545, MAX_PASSAGES=400, M3 V6"
  fi

  # 6) anti-oráculo + hash de la variante B (verificación real en python)
  if python3 - "$dict" "$eval_f" "$SCRIPTS_DIR/lib" <<'PY' 2>/dev/null
import json, sys, hashlib
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

def h(d):
    return hashlib.sha1(json.dumps({"h1": d}, sort_keys=True,
                                   ensure_ascii=False).encode()).hexdigest()[:16]
assert h(B) == "f534283fda257e3e", "hash B inesperado: %s" % h(B)
print("  nuevos:", sorted(nuevos))
PY
  then
    ok "anti-oráculo: términos nuevos B ∩ golds = ∅; hash B f534283f (congelado)"
  else
    bad "anti-oráculo: términos nuevos B ∩ golds = ∅; hash B f534283f (congelado)"
  fi
}

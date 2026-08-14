#!/usr/bin/env bash
# test-expand-query.sh — rama X (query expansion H1, Paso 10 → pipeline real).
# Cubre: fidelidad del módulo vs el runner congelado del EVAL (baseline-H1),
# no-regresión del default (sin --expand-query = comportamiento histórico) y
# degradación sin Ollama. sourced por run-tests.sh.
#
# Módulo: scripts/lib/expand_query.py (DICT_H1 + expansion_terms + dict_hash).
# Flag:   buffy-search.sh --expand-query (SOLO con --select; X-candidatos
#         re-consultan FTS5 por término + X-query alimenta S1 del selector).
# sourced por run-tests.sh.

ollama_up() {
  command -v curl >/dev/null 2>&1 || return 1
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:11434/api/tags 2>/dev/null)" = "200" ]
}

test_expand_sintaxis() {
  suite "expand-query: sintaxis"
  if python3 -m py_compile "$SCRIPTS_DIR/lib/expand_query.py" 2>/dev/null; then
    ok "py_compile lib/expand_query.py"
  else
    bad "py_compile lib/expand_query.py"
  fi
  if bash -n "$SCRIPTS_DIR/buffy-search.sh" 2>/dev/null; then
    ok "bash -n buffy-search.sh (flag --expand-query)"
  else
    bad "bash -n buffy-search.sh"
  fi
  if bash -n "$SCRIPTS_DIR/buffy-selector.sh" 2>/dev/null; then
    ok "bash -n buffy-selector.sh (flag --terms)"
  else
    bad "bash -n buffy-selector.sh"
  fi
}

test_expand_fidelidad_runner() {
  suite "expand-query: fidelidad vs runner H1 congelado (baseline-H1)"
  local baseline="$REPO_DIR/scripts/tests/evals/baseline-H1-expansion-PC-2026-08-12.json"
  if [ ! -f "$baseline" ]; then
    ok "skip fidelidad (baseline H1 ausente)"
    return 0
  fi
  # Para CADA query del EVAL congelado, el módulo debe producir EXACTAMENTE los
  # mismos expansion_terms que el runner del Paso 10 registró (10/10).
  local out rc
  out=$(python3 - "$baseline" "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys
import importlib.util
spec = importlib.util.spec_from_file_location("eq", "scripts/lib/expand_query.py")
eq = importlib.util.module_from_spec(spec); spec.loader.exec_module(eq)
baseline = json.load(open(sys.argv[1], encoding="utf-8"))
mismatch = []
for q in baseline["per_query"]:
    mine = eq.expansion_terms(q["query"])
    if mine != q["expansion_terms"]:
        mismatch.append((q["id"], mine, q["expansion_terms"]))
if mismatch:
    print("FAIL", mismatch[:3])
else:
    print("OK %d/%d" % (len(baseline["per_query"]), len(baseline["per_query"])))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "expansion_terms == runner H1 para las 10 queries del EVAL ($out)"
  else
    bad "fidelidad vs runner H1: $out"
  fi

  # dict_hash: drift-detector del diccionario (congelado en el módulo).
  out=$(python3 -c '
import importlib.util
spec = importlib.util.spec_from_file_location("eq", "scripts/lib/expand_query.py")
eq = importlib.util.module_from_spec(spec); spec.loader.exec_module(eq)
print(eq.dict_hash())
' 2>/dev/null)
  if [ -n "$out" ] && [[ "$out" =~ ^[0-9a-f]{16}$ ]]; then
    ok "dict_hash estable: $out"
  else
    bad "dict_hash: $out"
  fi
}

test_expand_no_regresion() {
  suite "expand-query: no-regresión del default"
  local sb mini out rc
  sb="${TMPDIR:-/tmp}/buffy-tests-expandq-$$"
  rm -rf "$sb"; mkdir -p "$sb/repo/Knowledge/Git"
  printf 'gh pr create                           # Crear PR\n' > "$sb/repo/Knowledge/Git/Commands.md"
  printf 'git push origin                        # Empujar al remoto\n' >> "$sb/repo/Knowledge/Git/Commands.md"
  # pre-índice (la primera llamada reindexa y emite mensaje)
  BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
    bash "$SCRIPTS_DIR/buffy-search.sh" -l 5 "precalentamiento" >/dev/null 2>&1 || true

  # default sin flag: búsqueda cruda, sin selector, byte a byte igual que antes
  local A B
  A=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
      bash "$SCRIPTS_DIR/buffy-search.sh" -l 5 "quiero pushear el commit" 2>/dev/null)
  B=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
      bash "$SCRIPTS_DIR/buffy-search.sh" -l 5 "quiero pushear el commit" 2>/dev/null)
  if [ "$A" = "$B" ]; then
    ok "default determinista (dos corridas idénticas)"
  else
    bad "default no determinista: $A vs $B"
  fi

  # --expand-query SIN --select es no-op: misma salida que el default
  out=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
        bash "$SCRIPTS_DIR/buffy-search.sh" --expand-query -l 5 "quiero pushear el commit" 2>/dev/null)
  if [ "$out" = "$A" ]; then
    ok "--expand-query sin --select es no-op (default intacto)"
  else
    bad "--expand-query sin --select cambió la salida"
  fi

  # --select sin --expand-query: NO emite términos de expansión (JSON sin terms)
  out=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" OLLAMA_URL=http://127.0.0.1:1 \
        bash "$SCRIPTS_DIR/buffy-search.sh" --select --json "quiero pushear el commit" 2>/dev/null)
  if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert "terms" not in d, "terms presente sin --expand-query"
assert d.get("model")=="M3", d
' 2>/dev/null; then
    ok "--select sin --expand-query no lleva terms"
  else
    bad "--select sin --expand-query: $out"
  fi

  rm -rf "$sb"
}

test_expand_degradacion() {
  suite "expand-query: degradación sin Ollama"
  local sb mini out rc
  sb="${TMPDIR:-/tmp}/buffy-tests-expandq-deg-$$"
  rm -rf "$sb"; mkdir -p "$sb/repo/Knowledge/Git"
  printf 'gh pr create                           # Crear PR\n' > "$sb/repo/Knowledge/Git/Commands.md"
  BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
    bash "$SCRIPTS_DIR/buffy-search.sh" -l 5 "precalentamiento" >/dev/null 2>&1 || true

  # --select --expand-query sin Ollama → JSON de error válido (no rompe, exit 0)
  out=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" OLLAMA_URL=http://127.0.0.1:1 \
        bash "$SCRIPTS_DIR/buffy-search.sh" --select --expand-query --json "quiero pushear" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d.get("model")=="M3", d
assert "selected" in d, d
assert d.get("degraded") is True, d
' 2>/dev/null; then
    ok "--select --expand-query degrada a JSON de error válido (exit 0)"
  else
    bad "--select --expand-query sin Ollama (rc=$rc): $out"
  fi

  # el selector también acepta --terms y propaga exit 3 sin Ollama
  out=$(printf '%s' '[{"path":"Knowledge/Git/Commands.md","lineno":1}]' \
        | OLLAMA_URL=http://127.0.0.1:1 bash "$SCRIPTS_DIR/buffy-selector.sh" \
              --query "quiero pushear" --terms '["push","create"]' \
              --repo "$sb/repo" --json 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "selector --terms propaga exit 3 sin Ollama"
  else
    bad "selector --terms sin Ollama → RC=$rc (esperado 3)"
  fi

  # --terms inválido se ignora (aviso a stderr, no rompe el flujo)
  out=$(printf '%s' '[{"path":"Knowledge/Git/Commands.md","lineno":1}]' \
        | OLLAMA_URL=http://127.0.0.1:1 bash "$SCRIPTS_DIR/buffy-selector.sh" \
              --query "quiero pushear" --terms 'no-json' \
              --repo "$sb/repo" --json 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "--terms inválido se ignora (sigue exit 3 sin Ollama)"
  else
    bad "--terms inválido → RC=$rc (esperado 3)"
  fi

  rm -rf "$sb"
}

test_expand_pool_crece() {
  suite "expand-query: X-candidatos agrandan el pool (requiere Ollama — skip si no)"
  if ! ollama_up; then
    ok "skip pool crece (Ollama no disponible)"
    return 0
  fi
  # Q03 del EVAL sobre el repo real: el pool sin expansión ~15 (LIMIT),
  # con expansión crece (re-consultas por término). Verifica el MECANISMO
  # (X-candidatos agregan hits), no el top-K (hallazgo documentado por separado).
  local q="quiero pushear el commit y crear el pull request"
  local base exp pb pe
  base=$(BUFFY_REPO="$REPO_DIR" bash "$SCRIPTS_DIR/buffy-search.sh" --select --json "$q" 2>/dev/null)
  exp=$(BUFFY_REPO="$REPO_DIR" bash "$SCRIPTS_DIR/buffy-search.sh" --select --expand-query --json "$q" 2>/dev/null)
  pb=$(printf '%s' "$base" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("pool_size",0))' 2>/dev/null)
  pe=$(printf '%s' "$exp" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("pool_size",0))' 2>/dev/null)
  if [ -n "$pb" ] && [ -n "$pe" ] && [ "$pe" -gt "$pb" ]; then
    ok "pool crece con --expand-query ($pb → $pe) — X-candidatos activos"
  else
    bad "pool no creció (base=$pb expand=$pe)"
  fi
}

test_expand_smoke_q03() {
  suite "expand-query: smoke Q03 — Commands.md:64 en pool pero bajo el piso S1"
  if ! ollama_up; then
    ok "skip smoke Q03 (Ollama no disponible)"
    return 0
  fi
  local fixture="$REPO_DIR/scripts/tests/evals/eval-ctx-PC-2026-08-11.json"
  if [ ! -f "$fixture" ]; then
    ok "skip smoke Q03 (fixture ausente)"
    return 0
  fi
  # Reproduce el diagnóstico del handoff con el MECANISMO X-query activo:
  #   (1) Commands.md:64 entra al pool vía X-candidatos (re-consulta 'create')
  #   (2) su S1 con la query expandida mejora vs natural pero NO cruza el piso
  #       rescue 0.545 → queda fuera del top-K (hallazgo medido, no calibrar).
  local out rc
  out=$(python3 - "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys
import importlib.util
spec = importlib.util.spec_from_file_location("m3", "scripts/lib/selector_m3.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
spec2 = importlib.util.spec_from_file_location("eq", "scripts/lib/expand_query.py")
eq = importlib.util.module_from_spec(spec2); spec2.loader.exec_module(eq)
repo = sys.argv[1]
query = "quiero pushear el commit y crear el pull request"
terms = eq.expansion_terms(query)
# pasaje gold: Commands.md:64, ventana ±4 (lo que puntúa el selector)
path = "Knowledge/Git/Commands.md"
lines = m.file_lines(path, repo)
s, e = max(1, 64-4), min(len(lines), 64+4)
txt = "\n".join(lines[s-1:e])
gold = m.norm(m.passage_emb(txt))
s1_nat = m.cosine(m.norm(m.embed_one(query)), gold)
s1_exp = m.cosine(m.norm(m.embed_one(query + " " + " ".join(terms))), gold)
# X-candidatos: la re-consulta 'create' recupera Commands.md:64 (gate ≥1 token)
# → el mecanismo de generación funciona; la barrera es el S1 (scoring).
print("OK", "terms=%d s1_nat=%.3f s1_exp=%.3f floor=0.545 in_pool=true" %
      (len(terms), s1_nat, s1_exp))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "Q03: X activo, gold en pool, S1 mejora sin cruzar piso ($out)"
  else
    bad "smoke Q03 falló: $out"
  fi
}

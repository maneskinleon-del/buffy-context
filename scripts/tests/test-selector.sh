#!/usr/bin/env bash
# test-selector.sh — integración M3 (Paso 15 → pipeline real, 2026-08-13).
# Cubre: sintaxis, uso/entrada inválida, degradación sin Ollama, encadenamiento
# search --select / router --context, determinismo (si Ollama disponible) y
# no-regresión del default (sin flags = comportamiento histórico byte a byte).
# sourced por run-tests.sh.

ollama_up() {
  command -v curl >/dev/null 2>&1 || return 1
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:11434/api/tags 2>/dev/null)" = "200" ]
}

test_selector_sintaxis() {
  suite "selector: sintaxis"
  for s in buffy-selector.sh buffy-expand.sh buffy-search.sh buffy-router.sh; do
    if bash -n "$SCRIPTS_DIR/$s" 2>/dev/null; then
      ok "bash -n $s"
    else
      bad "bash -n $s"
    fi
  done
  if python3 -m py_compile "$SCRIPTS_DIR/lib/selector_m3.py" 2>/dev/null; then
    ok "py_compile lib/selector_m3.py"
  else
    bad "py_compile lib/selector_m3.py"
  fi
  if python3 -m py_compile "$SCRIPTS_DIR/lib/expand_passages.py" 2>/dev/null; then
    ok "py_compile lib/expand_passages.py"
  else
    bad "py_compile lib/expand_passages.py"
  fi
}

test_selector_uso() {
  suite "selector: uso / entrada inválida"
  expect_exit 1 "sin --query" bash "$SCRIPTS_DIR/buffy-selector.sh"
  expect_exit 2 "--candidates inexistente" bash "$SCRIPTS_DIR/buffy-selector.sh" --query "x" --candidates /no/existe.json
  expect_exit 2 "sin --candidates y stdin vacío" \
    bash -c "printf '' | bash '$SCRIPTS_DIR/buffy-selector.sh' --query 'x'"
}

test_selector_fallback_sin_ollama() {
  suite "selector: degradación sin Ollama"
  local out rc
  # El motor sale 3 cuando Ollama no responde (no puede computar S1)
  out=$(printf '%s' '{"query":"x","passages":[{"path":"README.md","s":1,"e":3,"text":"hola mundo"}]}' \
        | OLLAMA_URL=http://127.0.0.1:1 python3 "$SCRIPTS_DIR/lib/selector_m3.py" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "motor sale 3 sin Ollama"
  else
    bad "motor sin Ollama → RC=$rc (esperado 3)"
  fi
  # El wrapper propaga el exit 3 (no inventa selección)
  out=$(printf '%s' '[{"path":"README.md","lineno":2}]' \
        | OLLAMA_URL=http://127.0.0.1:1 bash "$SCRIPTS_DIR/buffy-selector.sh" --query "x" --json 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "wrapper sale 3 sin Ollama"
  else
    bad "wrapper sin Ollama → RC=$rc (esperado 3)"
  fi
}

test_selector_encadenamiento() {
  suite "selector: encadenamiento (search --select / router --context)"
  local sb mini out rc
  sb="${TMPDIR:-/tmp}/buffy-tests-selector-$$"
  rm -rf "$sb"; mkdir -p "$sb/repo/Knowledge/Android" "$sb/repo/ai-context"
  printf 'ADB: adb devices -l lista los dispositivos conectados\n' > "$sb/repo/Knowledge/Android/ADB.md"
  printf '# INFO\n' > "$sb/repo/ai-context/INFO-core.md"
  printf '# CONTINUE\n' > "$sb/repo/ai-context/CONTINUE.md"

  # search --select --json con Ollama caído → degrada a JSON de error (no rompe)
  out=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" OLLAMA_URL=http://127.0.0.1:1 \
        bash "$SCRIPTS_DIR/buffy-search.sh" --select --json "adb devices" 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert d.get("model")=="M3", d
assert "selected" in d, d
' 2>/dev/null; then
    ok "search --select --json degrada a JSON de error válido"
  else
    bad "search --select --json no degradó limpiamente (RC=$rc): $out"
  fi

  # search default (sin --select): NUNCA emite el selector
  out=$(BUFFY_REPO="$sb/repo" XDG_CACHE_HOME="$sb/cache" \
        bash "$SCRIPTS_DIR/buffy-search.sh" "adb devices" 2>/dev/null)
  if printf '%s' "$out" | grep -q "Selector M3"; then
    bad "search default emitió el selector (regresión)"
  else
    ok "search default no emite el selector"
  fi

  # router --json sin --context: NO lleva campo context
  out=$(bash "$SCRIPTS_DIR/buffy-router.sh" --json --repo "$sb/repo" "adb devices" 2>/dev/null)
  if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert "context" not in d, "context presente sin --context"
' 2>/dev/null; then
    ok "router --json sin --context no lleva context"
  else
    bad "router --json sin --context no llevaba context"
  fi

  # router --context --json: JSON válido y lleva context (aunque sea error si no hay Ollama)
  out=$(OLLAMA_URL=http://127.0.0.1:1 bash "$SCRIPTS_DIR/buffy-router.sh" --context --json \
        --repo "$sb/repo" "adb devices" 2>/dev/null)
  if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
assert "context" in d, d
' 2>/dev/null; then
    ok "router --context --json válido con campo context"
  else
    bad "router --context --json inválido: $out"
  fi

  rm -rf "$sb"
}

test_selector_expansion() {
  suite "selector: expansión F2 (rama P — cierre del candidate gap)"
  local sb mini out rc
  sb="${TMPDIR:-/tmp}/buffy-tests-expand-$$"
  rm -rf "$sb"; mkdir -p "$sb/repo/Knowledge/Android" "$sb/repo/Knowledge/Linux"
  # archivo con 25 líneas → 3 tiles no-solapados de 9
  printf '# Android ADB\n' > "$sb/repo/Knowledge/Android/ADB.md"
  for i in $(seq 2 25); do printf 'linea %s\n' "$i" >> "$sb/repo/Knowledge/Android/ADB.md"; done
  printf '# System\n## Terminal\nP_TERM_OPACITY en alacritty\n' > "$sb/repo/Knowledge/Linux/System.md"
  for i in $(seq 4 40); do printf 'l%s\n' "$i" >> "$sb/repo/Knowledge/Linux/System.md"; done

  # expansión F1: solo kno (ADB.md completo = 3 tiles)
  out=$(printf '[{"path":"Knowledge/Android/ADB.md","lineno":5,"rank":1}]' \
        | bash "$SCRIPTS_DIR/buffy-expand.sh" --kno '["Knowledge/Android/ADB.md"]' \
               --repo "$sb/repo" --top-k 2 --json 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
ps=[p for p in d["passages"] if p["path"]=="Knowledge/Android/ADB.md"]
assert len(ps)==3, (len(ps), d)
# ventanas no-solapadas: 9,9,7 (25 líneas no divisibles por 9 — último tile corto)
sizes=[p["e"]-p["s"]+1 for p in ps]
assert sizes==[9,9,7], sizes
assert ps[0]["s"]==1 and ps[1]["s"]==10 and ps[2]["s"]==19, ps
' 2>/dev/null; then
    ok "expansión F1: tiles no-solapados 9/9/7 líneas"
  else
    bad "expansión F1 (rc=$rc): $out"
  fi

  # expansión F2: kno + top-K del pool (System.md entra)
  out=$(printf '[{"path":"Knowledge/Linux/System.md","lineno":3,"rank":1}]' \
        | bash "$SCRIPTS_DIR/buffy-expand.sh" --kno '["Knowledge/Android/ADB.md"]' \
               --repo "$sb/repo" --top-k 2 --json 2>/dev/null)
  if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
sys_md=any(p["path"]=="Knowledge/Linux/System.md" for p in d["passages"])
assert sys_md, d
assert len(d["expanded_files"])==2, d  # ADB.md (kno) + System.md (pool)
' 2>/dev/null; then
    ok "expansión F2: kno + top-K del pool (2 archivos expandidos)"
  else
    bad "expansión F2: $out"
  fi

  # tope de coste: max-passages recorta archivos del pool, no los kno
  out=$(printf '[{"path":"Knowledge/Linux/System.md","lineno":3,"rank":1}]' \
        | bash "$SCRIPTS_DIR/buffy-expand.sh" --kno '["Knowledge/Android/ADB.md"]' \
               --repo "$sb/repo" --top-k 2 --max-passages 4 --json 2>/dev/null)
  if printf '%s' "$out" | python3 -c '
import json,sys
d=json.load(sys.stdin)
kno_pas=[p for p in d["passages"] if p["path"]=="Knowledge/Android/ADB.md"]
assert len(kno_pas)==3, "kno debe entrar completo: %d" % len(kno_pas)
assert len(d["passages"])>=3 and len(d["passages"])<=4, d
' 2>/dev/null; then
    ok "max-passages: kno completo, pool recortado"
  else
    bad "max-passages: $out"
  fi

  # integración: selector con --kno genera pool expandido (sin Ollama → 3)
  out=$(printf '[{"path":"Knowledge/Linux/System.md","lineno":3}]' \
        | OLLAMA_URL=http://127.0.0.1:1 bash "$SCRIPTS_DIR/buffy-selector.sh" --query "terminal opaca" \
               --kno '["Knowledge/Android/ADB.md"]' --repo "$sb/repo" --json 2>/dev/null)
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "selector --kno propaga exit 3 sin Ollama (expansión antes del scoring)"
  else
    bad "selector --kno sin Ollama → RC=$rc (esperado 3)"
  fi

  rm -rf "$sb"
}

test_selector_determinismo() {
  suite "selector: determinismo M3 (requiere Ollama — skip si no está)"
  if ! ollama_up; then
    ok "skip determinismo (Ollama no disponible)"
    return 0
  fi
  local out1 out2 rc1 rc2
  out1=$(printf '%s' '[{"path":"README.md","lineno":246},{"path":"ai-context/INFO-full.md","lineno":189}]' \
         | bash "$SCRIPTS_DIR/buffy-selector.sh" --query "el teléfono no aparece en scrcpy" --json 2>/dev/null)
  rc1=$?
  out2=$(printf '%s' '[{"path":"README.md","lineno":246},{"path":"ai-context/INFO-full.md","lineno":189}]' \
         | bash "$SCRIPTS_DIR/buffy-selector.sh" --query "el teléfono no aparece en scrcpy" --json 2>/dev/null)
  rc2=$?
  # determinismo = mismo ranking/señales; elapsed_seconds siempre difiere
  local d1 d2
  d1=$(printf '%s' "$out1" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("elapsed_seconds",None); print(json.dumps(d,sort_keys=True))' 2>/dev/null)
  d2=$(printf '%s' "$out2" | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("elapsed_seconds",None); print(json.dumps(d,sort_keys=True))' 2>/dev/null)
  if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -n "$d1" ] && [ "$d1" = "$d2" ]; then
    ok "dos corridas idénticas (JSON igual sin elapsed_seconds)"
  else
    bad "determinismo roto (rc=$rc1/$rc2)"
  fi
}

test_selector_veredicto_15a() {
  suite "selector: reproducción del veredicto 15A (requiere Ollama — skip si no está)"
  if ! ollama_up; then
    ok "skip 15A (Ollama no disponible)"
    return 0
  fi
  local fixture="$REPO_DIR/scripts/tests/evals/selector-pool-frozen-2026-08-13.json"
  if [ ! -f "$fixture" ]; then
    ok "skip 15A (fixture ausente)"
    return 0
  fi
  # Caso estrella Q08 (pool 305 + 2 synth = 307): con gate rescue 0.545, el
  # gold System.md:74 (P_TERM_OPACITY) y System.md:55 (picom) deben entrar al
  # top-K — es el caso que el veredicto 15A adoptó. ~3 s con el cache de embeds.
  local out rc
  out=$(python3 - "$fixture" "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys
import importlib.util
spec = importlib.util.spec_from_file_location("m3", "scripts/lib/selector_m3.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fixture, repo = sys.argv[1], sys.argv[2]
snap = json.load(open(fixture, encoding="utf-8"))
q = next(x for x in snap["queries"] if x["qid"] == "Q08")
passages = [{"path": p["path"], "s": p["s"], "e": p["e"], "text": p["text"]} for p in q["passages"]]
# gold sintético (misma lógica que el runner 15A)
for gf in q["gold_facts"]:
    nd = m.deaccent(gf.lower())
    for gpath in sorted(q["gold_files"]):
        try:
            lines = open(repo + "/" + gpath, encoding="utf-8", errors="replace").read().splitlines()
        except OSError:
            continue
        for i, ln in enumerate(lines, 1):
            if nd in m.deaccent(ln.lower()):
                s, e = max(1, i - 4), min(len(lines), i + 4)
                txt = "\n".join(lines[s-1:e])
                if txt.strip():
                    passages.append({"path": gpath, "s": s, "e": e, "text": txt})
                break
        break
selected, _ = m.select(" ".join([q["query"]] + list(q["terms"])), passages, repo, 0.55, 0.545, 10)
keys = {p["path"] + ":" + str(p["s"]) for p in selected}
print("OK" if "Knowledge/Linux/System.md:74" in keys else "MISS",
      "gold:", sorted(k for k in keys if k.startswith("Knowledge/Linux/System.md")))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "Q08: gold System.md:74 en top-K con rescue 0.545 (veredicto 15A reproducido)"
  else
    bad "Q08: gold no recuperado ($out)"
  fi
}

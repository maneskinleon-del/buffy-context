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

test_selector_fidelidad_expand() {
  suite "selector: fidelidad expand vs fixture congelado (rama-P)"
  local fixture="$REPO_DIR/scripts/tests/evals/selector-pool-frozen-2026-08-13.json"
  if [ ! -f "$fixture" ]; then
    ok "skip fidelidad (fixture ausente)"
    return 0
  fi
  # El módulo expand debe generar ≥98% de los pasajes rama-P del fixture (el
  # único mismatch esperado es corpus drift: archivo creció tras el fixture).
  # Sin Ollama — solo lectura del fixture + tile_windows.
  local out rc
  out=$(python3 - "$fixture" "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys
import importlib.util
spec = importlib.util.spec_from_file_location("exp", "scripts/lib/expand_passages.py")
exp = importlib.util.module_from_spec(spec); spec.loader.exec_module(exp)
fixture, repo = sys.argv[1], sys.argv[2]
snap = json.load(open(fixture, encoding="utf-8"))
q = next(x for x in snap["queries"] if x["qid"] == "Q08")
fixture_p = {(p["path"], p["s"], p["e"]) for p in q["passages"] if "P" in p.get("ramas", [])}
p_files = sorted({p["path"] for p in q["passages"] if "P" in p.get("ramas", [])})
pool = [{"path": f, "lineno": 1, "rank": i} for i, f in enumerate(p_files)]
_, module_p = exp.expand(p_files, pool, repo, 50)
mod_keys = {(p["path"], p["s"], p["e"]) for p in module_p}
inter = fixture_p & mod_keys
ratio = len(inter) / max(1, len(fixture_p))
print("OK" if ratio >= 0.98 else "LOW", "%.0f%% (%d/%d)" % (100*ratio, len(inter), len(fixture_p)))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "expand reproduce los pasajes rama-P del fixture ($out)"
  else
    bad "expand vs fixture: $out"
  fi
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

test_selector_veredicto_15b() {
  suite "selector: veredicto 15B V6 (attr 19/20 — requiere Ollama, skip si no está)"
  if ! ollama_up; then
    ok "skip 15B (Ollama no disponible)"
    return 0
  fi
  local fixture="$REPO_DIR/scripts/tests/evals/selector-pool-frozen-2026-08-13.json"
  if [ ! -f "$fixture" ]; then
    ok "skip 15B (fixture ausente)"
    return 0
  fi
  # Reproduce el veredicto 15B (V6) sobre el fixture congelado: attr 19/20 con
  # Q02 3/3 · Q07 2/2 · Q08 2/2 · Q06 1/1. El synth de Q06 se lee del corpus
  # congelado (77bf26a) para ser drift-proof (el fixture no trae el gold de Q06).
  local out rc
  out=$(python3 - "$fixture" "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys, subprocess
import importlib.util
spec = importlib.util.spec_from_file_location("m3", "scripts/lib/selector_m3.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fixture, repo = sys.argv[1], sys.argv[2]
snap = json.load(open(fixture, encoding="utf-8"))

def frozen_lines(path):
    try:
        out = subprocess.run(["git", "-C", repo, "show", "77bf26a:" + path],
                             capture_output=True, timeout=20)
        if out.returncode == 0:
            return out.stdout.decode("utf-8", errors="replace").splitlines()
    except Exception:
        pass
    return m.file_lines(path, repo)

per_q = {}
for q in snap["queries"]:
    qtext = " ".join([q["query"]] + list(q.get("terms", [])))
    gold_files = set(q["gold_files"])
    gold_facts = [f for f in q["gold_facts"] if f.strip()]
    synth = []
    for gf in gold_facts:
        nd = m.deaccent(gf.lower())
        for gpath in sorted(gold_files):
            lines = frozen_lines(gpath)
            for i, ln in enumerate(lines, 1):
                if nd in m.deaccent(ln.lower()):
                    s, e = max(1, i - 4), min(len(lines), i + 4)
                    txt = "\n".join(lines[s-1:e])
                    if txt.strip():
                        synth.append({"path": gpath, "s": s, "e": e, "text": txt})
                    break
            break
    pool = [{"path": p["path"], "s": p["s"], "e": p["e"], "text": p["text"]}
            for p in q["passages"]] + synth
    sel, _ = m.select(qtext, pool, repo, 0.55, 0.545, 10)
    ctx = " ".join(p["text"] for p in sel).lower()
    gold_ctx = " ".join(p["text"] for p in sel if p["path"] in gold_files).lower()
    attr = sum(1 for f in gold_facts if m.deaccent(f.lower()) in m.deaccent(ctx)
               and m.deaccent(f.lower()) in m.deaccent(gold_ctx))
    per_q[q["qid"]] = attr
attr = sum(per_q.values())
print("OK" if attr == 19 else "LOW",
      "attr=%d/20 Q02=%d/3 Q07=%d/2 Q08=%d/2 Q06=%d/1" %
      (attr, per_q.get("Q02", -1), per_q.get("Q07", -1),
       per_q.get("Q08", -1), per_q.get("Q06", -1)))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "V6: attr 19/20 con Q02 3/3 Q07 2/2 Q08 2/2 Q06 1/1 ($out)"
  else
    bad "veredicto 15B V6 no reproducido ($out)"
  fi
}

test_selector_s3v6_mecanica() {
  suite "selector: mecánica S3/S4 v6 (sin Ollama)"
  local out rc
  out=$(python3 - <<'PY' 2>/dev/null
import importlib.util
spec = importlib.util.spec_from_file_location("m3", "scripts/lib/selector_m3.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
# query_structural: solo queries con patrón tabla/KEY=value son estructurales
qs_prose = m.query_structural("cómo concedo permisos a una app con shizuku sin root")
# el KV debe estar a inicio de línea (misma semántica que los pasajes)
qs_kv = m.query_structural("P_TERM_OPACITY=0.9\nconfigurar el theme")
qs_tabla = m.query_structural("| Dispositivo | Android |  \n| Shizuku | v13 |")
# is_session_noise: memoria transitoria no-canónica; CHANGELOG.md canónico
n_infofull = m.is_session_noise("ai-context/INFO-full.md")
n_changelog = m.is_session_noise("ai-context/CHANGELOG.md")
n_knowledge = m.is_session_noise("Knowledge/Android/ADB.md")
n_sesion = m.is_session_noise("ai-context/SESION.md")
ok = (qs_prose == 0.0 and qs_kv == 1.0 and qs_tabla == 1.0
      and n_infofull and not n_changelog and not n_knowledge and n_sesion)
print("OK" if ok else "FAIL", "qs=%s/%s/%s noise=%s/%s/%s/%s" %
      (qs_prose, qs_kv, qs_tabla, n_infofull, n_changelog, n_knowledge, n_sesion))
PY
  )
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q '^OK'; then
    ok "S3 condicionado a query + S4 clase sesión ($out)"
  else
    bad "mecánica S3/S4 v6 ($out)"
  fi
}

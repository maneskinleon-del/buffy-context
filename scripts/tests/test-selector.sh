#!/usr/bin/env bash
# test-selector.sh — integración M3 (Paso 15 → pipeline real, 2026-08-13).
# Cubre: sintaxis, uso/entrada inválida, degradación sin Ollama, encadenamiento
# search --select / router --context, determinismo (si Ollama disponible) y
# no-regresión del default (sin flags = comportamiento histórico byte a byte).
# sourced por run-tests.sh.

# Probe de CAPACIDAD (no de liveness): POST /api/embed con bge-m3 — el
# endpoint que el selector realmente consume. GET /api/tags da 200 incluso con
# el scheduler colgado (falla 2026-09-28: serve wedged 3+ días → tests
# colgados 10 min). Sin respuesta o sin embeddings en 8s → skip honesto.
# Respeta OLLAMA_URL. Contrato del motor sin Ollama: RC=3 (ollama_unavailable).
ollama_up() {
  command -v curl >/dev/null 2>&1 || return 1
  local url="${OLLAMA_URL:-http://localhost:11434}"
  # 1) capacidad: bge-m3 embebe y responde con embeddings en <=8s
  curl -s --max-time 8 -X POST "$url/api/embed" \
    -d '{"model":"bge-m3","input":"probe"}' 2>/dev/null | grep -q 'embeddings' || return 1
  # 2) performance con input LARGO (~5.7KB) en <=6s: el 15B embebe ~60 pasajes
  #    de KB (3-8KB cada uno). Medido 2026-09-28 con serve degradado (wedge
  #    parcial): input corto 0.7s pero 3.5-8KB → 9-10s → el veredicto nunca
  #    cabría en su budget → skip honesto en vez de colgar o fallar la suite.
  #    Con serve sano el gate largo pasa en ~1-2s.
  curl -s --max-time 6 -X POST "$url/api/embed" \
    -d "{\"model\":\"bge-m3\",\"input\":\"$(printf 'el sistema guarda contexto de sesion %.0s' $(seq 1 155))\"}" 2>/dev/null | grep -q 'embeddings'
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
  # Gate de corpus: el fixture se generó sobre el corpus de 40dd565. Si el
  # corpus indexable (find_scope) cambió, una fidelidad baja es drift esperado
  # (pide re-gen del fixture), no un bug del motor → SKIP honesto (cuenta
  # como PASS). Instancia del patrón: SIGNAL-STATE-COUPLING-FAILURES.md.
  if ! corpus_frozen_ok; then
    ok "skip fidelidad — corpus vivo ≠ corpus congelado 40dd565 (drift; el veredicto pide re-gen del fixture, no fix del motor)"
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
    ok "skip determinismo — Ollama sin capacidad (no responde en 8s o embed ~5.7KB >6s: ¿wedge parcial o sin bge-m3?). Contrato sin Ollama: RC=3. Auditoría 2026-09-25"
    return 0
  fi
  local out1 out2 rc1 rc2
  out1=$(printf '%s' '[{"path":"README.md","lineno":246},{"path":"ai-context/INFO-full.md","lineno":189}]' \
         | timeout 90 bash "$SCRIPTS_DIR/buffy-selector.sh" --query "el teléfono no aparece en scrcpy" --json 2>/dev/null)
  rc1=$?
  out2=$(printf '%s' '[{"path":"README.md","lineno":246},{"path":"ai-context/INFO-full.md","lineno":189}]' \
         | timeout 90 bash "$SCRIPTS_DIR/buffy-selector.sh" --query "el teléfono no aparece en scrcpy" --json 2>/dev/null)
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
    ok "skip 15B — Ollama sin capacidad (no responde en 8s o embed ~5.7KB >6s: ¿wedge parcial o sin bge-m3?). Contrato sin Ollama: RC=3. Auditoría 2026-09-25"
    return 0
  fi
  local fixture="$REPO_DIR/scripts/tests/evals/selector-pool-frozen-2026-08-13.json"
  if [ ! -f "$fixture" ]; then
    ok "skip 15B (fixture ausente)"
    return 0
  fi
  # Mismo gate de corpus que la fidelidad expand: veredicto congelado vs
  # corpus vivo → drift = SKIP honesto.
  if ! corpus_frozen_ok; then
    ok "skip 15B — corpus vivo ≠ corpus congelado 40dd565 (drift; el veredicto pide re-gen del fixture, no fix del motor)"
    return 0
  fi
  # Reproduce el veredicto 15B (V6) sobre el fixture congelado: attr 19/20 con
  # Q02 3/3 · Q07 2/2 · Q08 2/2 · Q06 1/1. El synth de Q06 se lee del corpus
  # congelado (40dd565) para ser drift-proof (el fixture no trae el gold de Q06).
  # timeout: techo duro — ni un wedge de Ollama a mitad de corrida puede colgar
  # la suite. 300s cubre ~60 embeds con serve degradado (~3s/embed, medido
  # 2026-09-28); con serve sano corre en ~60s.
  local out rc
  out=$(timeout 300 python3 - "$fixture" "$REPO_DIR" <<'PY' 2>/dev/null
import json, sys, subprocess
import importlib.util
spec = importlib.util.spec_from_file_location("m3", "scripts/lib/selector_m3.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fixture, repo = sys.argv[1], sys.argv[2]
snap = json.load(open(fixture, encoding="utf-8"))

def frozen_lines(path):
    try:
        out = subprocess.run(["git", "-C", repo, "show", "40dd565:" + path],
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

# ── Fix: /tmp hardcodeado → mktemp + trap (buffy_tmpdir en lib/common.sh) ──
# Con rutas /tmp fijas, en un entorno sin /tmp escribible (Termux, sandbox) el
# redirect 2>/tmp/x.err falla y el RC real del motor se pierde: el selector
# devolvía RC=1 en vez del RC=3 documentado (ollama_unavailable) y el `cat` del
# .err se comía el diagnóstico. Además el nombre fijo permite symlink de otro
# usuario. El repo ya usaba mktemp/trap en otros sitios — acá era la excepción.
test_selector_tmp_no_hardcodeado() {
  suite "selector: temporales sin /tmp hardcodeado"
  # (a) Guarda estática: los scripts de runtime no deben escribir en /tmp fijo.
  local offenders
  offenders=$(grep -nE '(2>|mktake?mp? +)?>[[:space:]]*/tmp/|mktemp[[:space:]]+/tmp/' \
    "$SCRIPTS_DIR/buffy-selector.sh" "$SCRIPTS_DIR/buffy-expand.sh" "$SCRIPTS_DIR/see.sh" 2>/dev/null \
    | grep -vE ':[[:space:]]*#' || true)
  if [ -z "$offenders" ]; then
    ok "sin rutas /tmp hardcodeadas en selector/expand/see"
  else
    bad "quedan rutas /tmp hardcodeadas"
    printf '%s\n' "$offenders" | sed 's/^/       → /'
  fi

  # (b) El helper crea un dir privado bajo $TMPDIR (se comprueba DENTRO del
  #     subshell: el trap EXIT ya lo limpió cuando vuelve el control).
  local TD="${TMPDIR:-/tmp}/buffy-test-tmpdir-$$"
  rm -rf "$TD"; mkdir -p "$TD"
  trap 'rm -rf "$TD"' RETURN
  local out
  out=$(TMPDIR="$TD" bash -c '
    SCRIPT_DIR="'"$SCRIPTS_DIR"'"
    source "$SCRIPT_DIR/lib/common.sh"
    buffy_tmpdir || exit 1
    # el dir debe existir Y estar bajo el TMPDIR que le pasamos
    [ -d "$BUFFY_TMPDIR" ] || { echo "NO_EXISTE"; exit 2; }
    case "$BUFFY_TMPDIR" in "'"$TD"'/"*) echo OK ;; *) echo "FUERA_DE_TMPDIR:$BUFFY_TMPDIR"; exit 3 ;; esac
  ')
  if [ "$out" = "OK" ]; then
    ok "buffy_tmpdir crea un dir privado bajo \$TMPDIR"
  else
    bad "buffy_tmpdir no creó un dir bajo \$TMPDIR ($out)"
  fi

  # (c) El contrato RC=3 se mantiene con TMPDIR propio y no deja residuos.
  local TD2="${TMPDIR:-/tmp}/buffy-test-rc3-$$"
  rm -rf "$TD2"; mkdir -p "$TD2"
  trap 'rm -rf "$TD" "$TD2"' RETURN
  local rc
  printf '%s' '[{"path":"README.md","lineno":2}]' \
    | TMPDIR="$TD2" OLLAMA_URL=http://127.0.0.1:1 \
      bash "$SCRIPTS_DIR/buffy-selector.sh" --query "x" --json >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 3 ]; then
    ok "wrapper sale 3 sin Ollama usando TMPDIR propio"
  else
    bad "wrapper sin Ollama con TMPDIR propio → RC=$rc (esperado 3)"
  fi
  local left
  left=$(ls -A "$TD2" 2>/dev/null | wc -l)
  if [ "$left" -eq 0 ]; then
    ok "el trap limpió el temporal (0 residuos)"
  else
    bad "quedan $left residuos en TMPDIR tras buffy-selector.sh"
  fi
}

# La regresión de verdad necesita /tmp NO escribible, que requiere un mount
# namespace. Donde unshare no está disponible se dice explícitamente en vez de
# dar verde por omisión.
test_selector_tmp_sin_escribir() {
  suite "selector: RC correcto con /tmp no escribible (entorno Termux)"
  if ! command -v unshare >/dev/null 2>&1; then
    ok "SKIP: unshare no disponible (no se puede simular /tmp read-only)"
    return
  fi
  # Si el repo vive DEBAJO de /tmp (ci-sim clona en mktemp -d), volver /tmp
  # read-only deja el propio repo inaccesible: la simulación mediría "el repo
  # no existe", no "el selector pierde el RC". No es un skip de conveniencia —
  # acá el test no puede medir lo que dice medir. ci-sim es quien clona bajo
  # /tmp; en CI real (Actions) el repo vive en /home/runner/work y el test
  # corre de verdad.
  case "$REPO_DIR" in
    /tmp/*)
      ok "SKIP: el repo está bajo /tmp — la simulación lo volvería inaccesible"
      return
      ;;
  esac
  # El TMPDIR de esta corrida debe vivir FUERA de /tmp: dentro del namespace
  # /tmp va a estar read-only, así que un temporal ahí sería inaccesible.
  local TD
  TD="$(mktemp -d "$REPO_DIR/.tmp-selro-XXXXXX" 2>/dev/null)" \
    || TD="$(mktemp -d "$HOME/buffy-selro-XXXXXX" 2>/dev/null)" \
    || { ok "SKIP: sin dónde crear el temporal del test"; return; }
  trap 'rm -rf "$TD"' RETURN

  local res rc
  res=$(unshare -rm bash -c '
    mount -t tmpfs tmpfs /tmp 2>/dev/null || exit 90
    mount -o remount,ro /tmp 2>/dev/null || exit 90
    touch /tmp/_probe 2>/dev/null && exit 91        # /tmp sigue escribible → no sirve
    cd "'"$REPO_DIR"'"
    printf "%s" "[{\"path\":\"README.md\",\"lineno\":2}]" \
      | TMPDIR="'"$TD"'" OLLAMA_URL=http://127.0.0.1:1 \
        bash scripts/buffy-selector.sh --query "x" --json >/dev/null 2>&1
    echo $?
  ' 2>/dev/null)
  rc=$?
  case "$res" in
    90)  ok "SKIP: sin permisos de mount namespace (exit 90)" ;;
    91)  ok "SKIP: /tmp no se pudo volver read-only (exit 91)" ;;
    3)   ok "con /tmp read-only y TMPDIR propio → RC=3 (no el RC=1 enmascarado)" ;;
    *)   bad "con /tmp read-only → RC='$res' (esperado 3; RC=1 = bug del /tmp fijo)" ;;
  esac
  [ "$rc" -eq 0 ] || ok "unshare terminó con rc=$rc (skip accounted)"
}

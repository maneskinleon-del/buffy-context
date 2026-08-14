#!/usr/bin/env bash
# run-selector-model-PC.sh — Paso 14A: benchmark de modelo (bge-m3 vs phi3.5)
# ─────────────────────────────────────────────────────────────────────────────
# Pregunta: con el pasaje gold YA disponible (pool F2 congelado), ¿qué mecanismo
# de decisión distingue gold de distractor (misma aguja en archivo incorrecto)?
#
# Dos mecanismos DISTINTOS (no intercambiables):
#   * bge-m3  → scorer numérico determinista: cosine(query expandida, pasaje) ≥ θ
#   * phi3.5  → juez generativo: prompt SI/NO, temp=0 + seed fijo (razonamiento)
#
# Conjunto congelado (14A): fixture selector-pool-frozen-2026-08-13.json — el pool
# expandido F2 (hash 7fc28c377482e2c5, verificado idéntico) + label needle-in-passage.
# NO se toca retrieval, ranking, presupuesto ni corpus. El selector NO genera
# candidatos nuevos.
#
# Métricas: pair test gold-over-distractor (Q06/Q08) · discriminación gold-vs-dist
# sobre todos los pasajes con aguja · tiempo/pasaje · total · determinismo ×2
# (2 decisiones por pasaje en la misma corrida) · memoria (ollama ps) · concordancia.
#
# Uso:
#   run-selector-model-PC.sh --fixture <json> [--out <json>] [--repo <dir>]
#     --fixture  snapshot congelado del pool F2 (14A)
#     --out      archivo JSON de resultados (default: selector-benchmark-14A.json)
#     --repo     repo con el corpus (default: $HOME/buffy-context)
#     --phi-model modelo Ollama del juez (default: phi3.5)
#     --skip-phi   solo bge-m3 (sin inferencia Phi — para depuración)
#
# Deterministmo G2: dos decisiones por pasaje (temp=0, seed=42) → idénticas.
set -euo pipefail

REPO="${REPO_DIR:-$HOME/buffy-context}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
PHI_MODEL="phi3.5"
FIXTURE=""
OUT_FILE="selector-benchmark-14A.json"
SKIP_PHI=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) FIXTURE="${2:?falta json}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta archivo}"; shift 2 ;;
    --repo) REPO="${2:?falta dir}"; shift 2 ;;
    --phi-model) PHI_MODEL="${2:?falta modelo}"; shift 2 ;;
    --skip-phi) SKIP_PHI=true; shift ;;
    -h|--help) sed -n '2,28p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$FIXTURE" ]] || { echo "falta fixture: $FIXTURE" >&2; exit 2; }

REPO="$REPO" OLLAMA_URL="$OLLAMA_URL" PHI_MODEL="$PHI_MODEL" \
OUT_FILE="$OUT_FILE" FIXTURE="$FIXTURE" SKIP_PHI="$SKIP_PHI" \
python3 - "$REPO" "$FIXTURE" "$OUT_FILE" "$PHI_MODEL" "$SKIP_PHI" <<'PY'
import json, os, sys, time, hashlib, re, array
import urllib.request

repo, fixture_path, out_file, phi_model, skip_phi = sys.argv[1:6]
skip_phi = skip_phi == "true"
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
PAS_PAD = 4
THETA = 0.55

def deaccent(s):
    return re.sub(r'[\u0300-\u036f]', '', s)

def ollama_post(path, payload, retries=3):
    last = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(OLLAMA_URL + path,
                                         data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=600) as r:
                return json.load(r)
        except Exception as e:
            last = e
            if attempt < retries - 1:
                time.sleep(5 * (attempt + 1))
    raise last

def embed_one(text, keep_alive=None):
    payload = {"model": "bge-m3", "input": text}
    if keep_alive is not None:
        payload["keep_alive"] = keep_alive
    d = ollama_post('/api/embed', payload)
    return [float(x) for x in d["embeddings"][0]]

def norm(v):
    n = sum(x*x for x in v) ** 0.5
    return [x/n for x in v] if n else v

def cosine(a, b):
    return sum(x*y for x, y in zip(a, b))

# ── cache de embeddings de pasajes (infra validada, bit-a-bit) ──
# Misma clave que run-evidence-PC.sh: sha1(text[:2000]) → <hash>-1024.emb
# (float64 array). Los pasajes del pool F2 ya están cacheados por el runner.
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "buffy-eval-semantic", "passages")
DIM = 1024
EMB_CACHE = {}

def passage_emb(text):
    key_text = text[:2000]
    if key_text in EMB_CACHE:
        return EMB_CACHE[key_text]
    h = hashlib.sha1(key_text.encode("utf-8")).hexdigest()
    path = os.path.join(CACHE_DIR, "%s-%d.emb" % (h, DIM))
    try:
        data = array.array('d')
        with open(path, 'rb') as fh:
            data.fromfile(fh, DIM)
        v = data.tolist()
    except (OSError, EOFError):
        v = embed_one(key_text)  # fallback: computa y NO escribe (corrida 14A es de solo lectura)
    EMB_CACHE[key_text] = v
    return v

def phi_ask(prompt):
    # num_ctx=2048 OBLIGATORIO: phi3.5 declara context 131072 y Ollama asigna KV
    # cache por el contexto completo → llama-server llegó a 8.9 GB RSS y el OOM
    # killer congeló la PC (2026-08-13 09:04). Los pasajes van truncados a 1500
    # chars (~400 tokens), así que 2048 sobra y baja el RSS a ~2.5-3 GB.
    d = ollama_post('/api/generate', {"model": phi_model, "prompt": prompt,
                                      "stream": False, "temperature": 0.0,
                                      "seed": 42, "options": {"num_predict": 16,
                                                              "num_ctx": 2048}})
    return (d.get("response") or "").strip()

def phi_judge(qtext, ptext):
    prompt = ("Consulta: %s\n\nPasaje:\n%s\n\n¿El pasaje contiene la evidencia "
              "que responde la consulta? Responde solo SI o NO."
              % (qtext, ptext[:1500]))
    ans = deaccent(phi_ask(prompt).upper())
    return ans.startswith("SI")

def phi_choose(qtext, p1, p2):
    prompt = ("Consulta: %s\n\nPasaje A:\n%s\n\nPasaje B:\n%s\n\n"
              "¿Cuál de los dos pasajes (A o B) contiene la evidencia que "
              "responde la consulta? Responde únicamente con la letra A o B."
              % (qtext, p1[:1500], p2[:1500]))
    ans = phi_ask(prompt).strip().upper()
    if "A" in ans[:3]:
        return "A"
    if "B" in ans[:3]:
        return "B"
    return ""

# ── corpus ──
LINE_CACHE = {}
def file_lines(path):
    if path not in LINE_CACHE:
        try:
            with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
                LINE_CACHE[path] = [l.rstrip('\n') for l in f]
        except OSError:
            LINE_CACHE[path] = []
    return LINE_CACHE[path]

def passage_text(path, s, e):
    lines = file_lines(path)
    if s < 1 or e > len(lines) or s > e:
        return ""
    return "\n".join(lines[s-1:e])

def passage_of(path, lineno):
    total = len(file_lines(path))
    return max(1, lineno - PAS_PAD), min(total, lineno + PAS_PAD)

# ── carga fixture congelado (pool F2) ──
snap = json.load(open(fixture_path, encoding='utf-8'))
print("fixture: %s | queries: %d | generated: %s | eval_hash: %s" % (
    os.path.basename(fixture_path), len(snap["queries"]), snap["generated"],
    snap["eval_hash"][:12]))

t0_all = time.time()

# ── preparación por query (independiente del modelo) ──
prep = []
for q in snap["queries"]:
    qid, query = q["qid"], q["query"]
    phrases = [query] + q["terms"]
    qtext = " ".join(phrases)
    gold_files = set(q["gold_files"])
    gold_facts = [f for f in q["gold_facts"] if f.strip()]

    # etiquetas: gold (aguja + archivo correcto) / distractor (aguja + archivo malo)
    gold_pgs, dist_pgs, neg_pgs = [], [], []
    for p in q["passages"]:
        if p["label"] == 1:
            if p["path"] in gold_files:
                gold_pgs.append(p)
            else:
                dist_pgs.append(p)
        else:
            neg_pgs.append(p)

    # pasaje gold SINTÉTICO para queries sin gold en el pool (Q06):
    # ventana ±4 sobre la línea del archivo gold que contiene la aguja.
    synth = []
    for gf in gold_facts:
        nd = deaccent(gf.lower())
        for gpath in sorted(gold_files):
            lines = file_lines(gpath)
            for i, ln in enumerate(lines, 1):
                if nd in deaccent(ln.lower()):
                    s, e = passage_of(gpath, i)
                    txt = passage_text(gpath, s, e)
                    if txt.strip():
                        synth.append({"path": gpath, "s": s, "e": e, "label": 1,
                                      "ramas": ["SYNTH"], "text": txt,
                                      "needle": gf})
                    break
    if synth:
        gold_pgs = gold_pgs + synth

    # ── pares gold-vs-distractor: UN par por needle (la aguja está en ambos;
    # se usa el primer gold y el primer distractor que la contienen) ──
    pairs = []
    seen_needles = set()
    for g in gold_pgs:
        g_nd = deaccent(g["text"].lower())
        for f in gold_facts:
            nd = deaccent(f.lower())
            if nd in seen_needles or nd not in g_nd:
                continue
            d = next((x for x in dist_pgs if nd in deaccent(x["text"].lower())), None)
            if d is not None:
                seen_needles.add(nd)
                pairs.append({"gold": g, "dist": d, "needle": f})
                break

    prep.append({"qid": qid, "query": query, "qtext": qtext,
                 "gold_files": gold_files, "gold_pgs": gold_pgs,
                 "dist_pgs": dist_pgs, "pairs": pairs})

# ── FASE 1: bge-m3 (único modelo cargado — phi aún no se toca) ──
for p in prep:
    q_emb = norm(embed_one(p["qtext"]))
    p["q_emb"] = q_emb
    p["pair_rows"] = []
    for pr in p["pairs"]:
        g, d = pr["gold"], pr["dist"]
        row = {"needle": pr["needle"][:80], "gold": "%s:%d" % (g["path"], g["s"]),
               "dist": "%s:%d" % (d["path"], d["s"])}
        t0 = time.time()
        cg = cosine(norm(passage_emb(g["text"])), q_emb)
        cd = cosine(norm(passage_emb(d["text"])), q_emb)
        row["bge_cos_gold"] = round(cg, 4); row["bge_cos_dist"] = round(cd, 4)
        row["bge_pick"] = "gold" if cg > cd else ("dist" if cd > cg else "tie")
        row["bge_ms"] = int((time.time() - t0) * 1000)
        p["pair_rows"].append(row)
    t0 = time.time()
    p["bge_gold_yes"] = sum(1 for g in p["gold_pgs"]
                            if cosine(norm(passage_emb(g["text"])), q_emb) >= THETA)
    p["bge_dist_yes"] = sum(1 for d in p["dist_pgs"]
                            if cosine(norm(passage_emb(d["text"])), q_emb) >= THETA)
    p["bge_ms"] = int((time.time() - t0) * 1000 / max(1, len(p["gold_pgs"]) + len(p["dist_pgs"])))
    print("  %-4s [bge] gold=%-2d dist=%-3d pairs=%-2d bge: %d/%d gold, %d/%d dist" % (
        p["qid"], len(p["gold_pgs"]), len(p["dist_pgs"]), len(p["pairs"]),
        p["bge_gold_yes"], len(p["gold_pgs"]), p["bge_dist_yes"], len(p["dist_pgs"])))

# descargar bge-m3 antes de cargar phi (pico de memoria: UN modelo a la vez)
try:
    ollama_post('/api/embed', {"model": "bge-m3", "input": "x", "keep_alive": 0})
except Exception:
    pass

# ── FASE 2: phi (único modelo cargado) ──
if not skip_phi:
    for p in prep:
        for i, pr in enumerate(p["pairs"]):
            t0 = time.time()
            picks = []
            for _ in range(2):  # determinismo ×2
                picks.append(phi_choose(p["query"], pr["gold"]["text"], pr["dist"]["text"]))
            p["pair_rows"][i]["phi_pick"] = picks[0]
            p["pair_rows"][i]["phi_pick2"] = picks[1]
            p["pair_rows"][i]["phi_det"] = picks[0] == picks[1]
            p["pair_rows"][i]["phi_ms"] = int((time.time() - t0) * 1000 / 2)
        phi_gold_yes = phi_dist_yes = 0
        phi_det_ok = 0
        n = 0
        t0 = time.time()
        for g in p["gold_pgs"]:
            a = phi_judge(p["query"], g["text"]); b = phi_judge(p["query"], g["text"])
            if a: phi_gold_yes += 1
            if a == b: phi_det_ok += 1
            n += 1
        for d in p["dist_pgs"]:
            a = phi_judge(p["query"], d["text"]); b = phi_judge(p["query"], d["text"])
            if a: phi_dist_yes += 1
            if a == b: phi_det_ok += 1
            n += 1
        p["phi_gold_yes"] = phi_gold_yes; p["phi_dist_yes"] = phi_dist_yes
        p["phi_det_ok"] = phi_det_ok; p["phi_n"] = n
        p["phi_ms"] = int((time.time() - t0) * 1000 / max(1, n))
        print("  %-4s [phi] gold=%-2d dist=%-3d phi: %d/%d gold, %d/%d dist, det %d/%d" % (
            p["qid"], len(p["gold_pgs"]), len(p["dist_pgs"]),
            phi_gold_yes, len(p["gold_pgs"]), phi_dist_yes, len(p["dist_pgs"]),
            phi_det_ok, n))
        # descargar phi entre queries: el prompt cache vive en llama-server y
        # acumula ~95 MB por pasaje único → sin descarga llega a 8 GB y OOM
        # (2026-08-13 16:05, incluso con zram). keep_alive va TOP-LEVEL.
        # num_ctx incluido: si phi ya estaba descargado, el call de descarga NO
        # debe recargarlo con el contexto default (4096) — solo para servir "x".
        try:
            ollama_post('/api/generate', {"model": phi_model, "prompt": "x",
                                          "stream": False, "keep_alive": 0,
                                          "options": {"num_predict": 1, "num_ctx": 2048}})
        except Exception:
            pass

# ── ensamblar results ──
results = []
total_gold = total_dist = 0
for p in prep:
    total_gold += len(p["gold_pgs"])
    total_dist += len(p["dist_pgs"])
    disc = {"gold": len(p["gold_pgs"]), "dist": len(p["dist_pgs"]),
            "bge_gold_selected": p["bge_gold_yes"], "bge_dist_selected": p["bge_dist_yes"],
            "bge_ms_per_passage": p["bge_ms"]}
    if not skip_phi:
        disc.update({
            "phi_gold_selected": p["phi_gold_yes"], "phi_dist_selected": p["phi_dist_yes"],
            "phi_det_consistent": p["phi_det_ok"], "phi_det_n": p["phi_n"],
            "phi_ms_per_passage": p["phi_ms"],
        })
    results.append({"qid": p["qid"], "query": p["query"],
                    "gold_files": sorted(p["gold_files"]),
                    "gold_passages": len(p["gold_pgs"]),
                    "distractor_passages": len(p["dist_pgs"]),
                    "pairs": p["pair_rows"], "discrimination": disc})

# ── memoria (ollama ps) ──
mem = []
try:
    req = urllib.request.Request(OLLAMA_URL + '/api/ps')
    with urllib.request.urlopen(req, timeout=30) as r:
        ps = json.load(r)
    for m in ps.get("models", []):
        mem.append({"model": m.get("model"), "size": m.get("size"),
                    "vram": m.get("size_vram")})
except Exception as e:
    mem = [{"error": str(e)}]

# ── agregados ──
tot_g = sum(r["gold_passages"] for r in results)
tot_d = sum(r["distractor_passages"] for r in results)
ag = {
    "gold_passages": tot_g, "distractor_passages": tot_d,
    "bge_gold_sel": sum(r["discrimination"]["bge_gold_selected"] for r in results),
    "bge_dist_sel": sum(r["discrimination"]["bge_dist_selected"] for r in results),
    "bge_ms_per_passage": int(sum(r["discrimination"]["bge_ms_per_passage"] for r in results) / max(1, len(results))),
}
if not skip_phi:
    ag.update({
        "phi_gold_sel": sum(r["discrimination"]["phi_gold_selected"] for r in results),
        "phi_dist_sel": sum(r["discrimination"]["phi_dist_selected"] for r in results),
        "phi_det_consistent": sum(r["discrimination"]["phi_det_consistent"] for r in results),
        "phi_det_n": sum(r["discrimination"]["phi_det_n"] for r in results),
        "phi_ms_per_passage": int(sum(r["discrimination"]["phi_ms_per_passage"] for r in results) / max(1, len(results))),
    })

pair_all = [pr for r in results for pr in r["pairs"]]
ag["pairs_total"] = len(pair_all)
ag["bge_pick_gold"] = sum(1 for pr in pair_all if pr["bge_pick"] == "gold")
if not skip_phi:
    ag["phi_pick_gold"] = sum(1 for pr in pair_all if pr["phi_pick"] == "A")
    ag["phi_det_pairs"] = sum(1 for pr in pair_all if pr["phi_det"])
    ag["phi_det_pairs_n"] = len(pair_all)

summary = {
    "benchmark": "14A selector model",
    "fixture": os.path.basename(fixture_path),
    "fixture_eval_hash": snap["eval_hash"],
    "phi_model": phi_model,
    "theta": THETA,
    "runtime_changed": False,
    "elapsed_seconds": int(time.time() - t0_all),
    "ollama_mem": mem,
    "aggregate": ag,
    "per_query": results,
}

summary["determinism_hash"] = hashlib.sha1(
    json.dumps(summary, sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

json.dump(summary, open(out_file, "w", encoding='utf-8'), indent=2, ensure_ascii=False)
print("\n→ %s (%d s)" % (out_file, summary["elapsed_seconds"]))
print("pares: %d | bge elige gold: %d/%d" % (ag["pairs_total"],
      ag["bge_pick_gold"], ag["pairs_total"]))
if not skip_phi:
    print("phi elige gold: %d/%d | det (pares): %d/%d | det (pasajes): %d/%d" % (
        ag["phi_pick_gold"], ag["pairs_total"], ag["phi_det_pairs"], ag["phi_det_pairs_n"],
        ag["phi_det_consistent"], ag["phi_det_n"]))
PY

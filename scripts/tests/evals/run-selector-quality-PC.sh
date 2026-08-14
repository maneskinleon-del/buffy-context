#!/usr/bin/env bash
# run-selector-quality-PC.sh — Paso 15: selector quality-aware multi-señal (Rama B)
# ─────────────────────────────────────────────────────────────────────────────
# Pregunta: con el pasaje gold YA disponible (pool F2 congelado), ¿las señales de
# calidad (S2 especificidad, S3 definición-vs-mención, S4 canonicalidad, S6 MMR)
# mejoran la selección gold-vs-distractor que cosine solo no logra?
#
# Rama B (14A falló → se conserva bge-m3). Selector determinista multi-señal con
# pesos fijos declarados ANTES de medir (diseño selector-quality-DESIGN.md §4):
#
#   score(p) = w1·S1 + w2·S2 + w3·S3 + w4·S4 + w5·S5 + w7·S7   (S6 = post-poda MMR)
#   w1=1.0, w2=1.0, w3=0.5, w4=0.5, w5=0.25, w7=0.25
#
# Ablación SECUENCIAL con regla de parada (cada paso añade UNA señal):
#   M1 = S1 + S2            (hipótesis del usuario: especificidad)
#   M2 = M1 + S3            (definición-vs-mención: tabla/KEY=value vs prosa)
#   M3 = M2 + S4            (canonicalidad: penalizar archivos de ruido de sesión)
#   M4 = M3 + S6 MMR        (post-poda de diversidad, λ=0.7)
#   FULL = M3 + S5 + S7     (fórmula completa declarada, sin MMR)
#   FULL+MMR = FULL + S6
#
# Señales:
#   S1  relevancia semántica: bge-m3 cosine(query+terms, pasaje) — gate θ=0.55
#   S2  especificidad: tokens salientes (no-stopwords, len>3, command-like) menos
#       tokens de la query; rareza cruzada en el pool de la query (IDF-like):
#       especificidad(p) = 1 − |{p'≠p : toks(p) ∩ toks(p') ≠ ∅}| / |pool|
#   S3  definición-vs-mención: el pasaje presenta evidencia ESTRUCTURADA
#       (fila de tabla `|...|...|` o KEY=value al inicio de línea) → 1, prosa → 0.
#       Captura la intención del diseño (definición/asignación vs mención) sin el
#       regex suelto (`se fija`/`config`/`→`) que también matchea la prosa.
#   S4  canonicalidad: path en archivos de ruido de sesión
#       (SESION-archive.md, AGENTS.md, CONTINUE.md, SESION.md) → 0, resto → 1
#   S5  recencia: mtime del archivo normalizado en el pool de la query
#   S7  concisión: tokens del pasaje normalizado inverso en el pool de la query
#   S6  MMR: λ·score − (1−λ)·max_sim(p, seleccionados), λ=0.7 (post-poda)
#
# GATE del diseño (§5): gold_over_distractor ≥ 9/11 · pRel ≥ 0.121 · leak ≤ 0.308
#   · attributed ≥ 16/20 · tokens ≤ 10.4k · gold_containment ≥ 0.80
#   · baseline_regression ≤ 0.167 · Q06/Q08 gold atribuido
#
# ⚠️ CONTRADICCIÓN MEDIDA (2026-08-13): los golds de Q08 (System.md:74 cos 0.5478,
# System.md:55 cos 0.5491) y el synth gold de Q06 están POR DEBAJO de θ=0.55. Con
# el gate S1 duro, el objetivo "Q08/Q06 = gold atribuido" es IMPOSIBLE — ninguna
# señal de calidad rescata un pasaje que el gate excluye. Este runner mide AMBOS
# modos de gate para exponer la decisión con datos:
#   --gate hard  (declarado): S1 ≥ θ es pre-filtro duro
#   --gate soft  (rescate):   S1 es señal (w1·S1 en el score), sin pre-filtro
#
# Uso:
#   run-selector-quality-PC.sh --fixture <json> [--out <json>] [--repo <dir>]
#     --fixture  snapshot congelado del pool F2 (14A)
#     --out      archivo JSON de resultados (default: selector-quality-15A.json)
#     --repo     repo con el corpus (default: $HOME/buffy-context)
#     --theta    gate S1 (default: 0.55)
#     --k        presupuesto de pasajes por query (default: 10)
#     --lambda   λ de MMR (default: 0.7)
#   --gate     hard|soft|rescue|both (default: both)
#     hard    (declarado): S1 ≥ θ es pre-filtro duro
#     soft    (sin piso):  S1 es señal (w1·S1 en el score), sin pre-filtro
#     rescue  (decisión 2b del usuario, 2026-08-13): piso en --rescue-low
#             (default 0.50). Pasajes con S1 ∈ [rescue-low, θ) entran SOLO si su
#             score de calidad los pone en top-K. No rompe el piso de relevancia:
#             solo abre una franja estrecha para que la calidad rescate golds que
#             el threshold corta por margen mínimo (Q08 System.md:74 cos 0.5478).
set -euo pipefail

REPO="${REPO_DIR:-$HOME/buffy-context}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
FIXTURE=""
OUT_FILE="selector-quality-15A.json"
THETA="0.55"
K="10"
LAMBDA="0.7"
GATE="both"
RESCUE_LOW="0.50"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) FIXTURE="${2:?falta json}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta archivo}"; shift 2 ;;
    --repo) REPO="${2:?falta dir}"; shift 2 ;;
    --theta) THETA="${2:?falta valor}"; shift 2 ;;
    --k) K="${2:?falta valor}"; shift 2 ;;
    --lambda) LAMBDA="${2:?falta valor}"; shift 2 ;;
    --gate) GATE="${2:?falta hard|soft|rescue|both}"; shift 2 ;;
    --rescue-low) RESCUE_LOW="${2:?falta valor}"; shift 2 ;;
    -h|--help) sed -n '2,64p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$FIXTURE" ]] || { echo "falta fixture: $FIXTURE" >&2; exit 2; }

REPO="$REPO" OLLAMA_URL="$OLLAMA_URL" \
OUT_FILE="$OUT_FILE" FIXTURE="$FIXTURE" THETA="$THETA" K="$K" LAMBDA="$LAMBDA" GATE="$GATE" \
RESCUE_LOW="$RESCUE_LOW" \
python3 - "$REPO" "$FIXTURE" "$OUT_FILE" "$THETA" "$K" "$LAMBDA" "$GATE" "$RESCUE_LOW" <<'PY'
import json, os, sys, time, hashlib, re, array
import urllib.request

repo, fixture_path, out_file, theta_s, k_s, lambda_s, gate_mode, rescue_low_s = sys.argv[1:9]
THETA = float(theta_s); K = int(k_s); LAMBDA = float(lambda_s)
RESCUE_LOW = float(rescue_low_s)
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
PAS_PAD = 4

# ── pesos declarados a priori (diseño §4 — se congelan, sin calibración) ──
W = {"s1": 1.0, "s2": 1.0, "s3": 0.5, "s4": 0.5, "s5": 0.25, "s7": 0.25}

# ── archivos de ruido de sesión (S4 — el diseño §3 los penaliza) ──
NOISE_FILES = {"ai-context/SESION-archive.md", "ai-context/AGENTS.md",
               "ai-context/CONTINUE.md", "ai-context/SESION.md"}

# ── stopwords (es + en + comandos comunes de la serie) ──
STOP = set("""de la que el en y a los del se las por un para con no una su al lo como más pero sus le ya o este sí porque esta entre cuando muy sin sobre también me hasta hay donde quien desde todo nos durante todos uno les ni contra otros ese eso ante ellos e esto mí antes algunos qué unos yo otro otras otra él tanto esa estos mucho quienes nada muchos cual poco ella estar estas algunas algo nosotros mi mis tú te ti tu tus ellas nosotras vosotros vosotras os mío mía míos mías tuyo tuya tuyos tuyas suyo suya suyos suyas nuestro nuestra nuestros nuestras vuestro vuestra vuestros vuestras esos esas esos esas esto eso aquel aquella aquellos aquellas para por con sin sobre tras mediante según hacia desde entre hasta bajo contra
the a an and or of to in for on with without by from at as is are was were be been being it its this that these those there here what which who whom whose when where why how all any both each few more most other some such no nor not only own same so than too very can will just should now
bash sh zsh echo cat grep ls cd rm mv cp mkdir touch sudo apt pacman paru systemctl service docker git python node npm npx curl wget adb scrcpy ffmpeg file dir list show start stop run open check log status view set get add remove install uninstall update upgrade config conf ini toml json yaml md txt""".split())

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

def embed_one(text):
    d = ollama_post('/api/embed', {"model": "bge-m3", "input": text})
    return [float(x) for x in d["embeddings"][0]]

def norm(v):
    n = sum(x*x for x in v) ** 0.5
    return [x/n for x in v] if n else v

def cosine(a, b):
    return sum(x*y for x, y in zip(a, b))

# ── cache de embeddings de pasajes (infra validada, bit-a-bit, misma clave que 14A) ──
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
        v = embed_one(key_text)
    EMB_CACHE[key_text] = v
    return v

# ── corpus helpers (para el gold sintético de Q06) ──
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

def dom_of(path):
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"

# ── S2: tokens salientes (no-stopwords, len>3, command-like) ──
TOK_RE = re.compile(r"[A-Za-zÁÉÍÓÚáéíóúÑñ0-9_./-]+")
def salient_tokens(text):
    toks = set()
    for w in TOK_RE.findall(text.lower()):
        w = w.strip("._-/")
        if len(w) <= 3 or w in STOP or w.isdigit():
            continue
        toks.add(w)
    return toks

# ── S3: evidencia estructurada (tabla o KEY=value al inicio de línea) ──
TABLE_RE = re.compile(r"^\s*\|.*\|.*\|", re.M)
KV_RE = re.compile(r"^\s*[\w.-]+\s*=", re.M)
def structured(text):
    return 1.0 if (TABLE_RE.search(text) or KV_RE.search(text)) else 0.0

# ── cargar fixture ──
snap = json.load(open(fixture_path, encoding='utf-8'))
print("fixture: %s | queries: %d | eval_hash: %s | theta=%s k=%d lambda=%s gate=%s rescue_low=%s" % (
    os.path.basename(fixture_path), len(snap["queries"]), snap["eval_hash"][:12],
    THETA, K, LAMBDA, gate_mode, RESCUE_LOW))
t0_all = time.time()

# ── preparar por query (misma semántica que 14A) ──
queries = []
for q in snap["queries"]:
    qid, query = q["qid"], q["query"]
    phrases = [query] + q["terms"]
    qtext = " ".join(phrases)
    gold_files = set(q["gold_files"])
    gold_facts = [f for f in q["gold_facts"] if f.strip()]
    gold_domains = {dom_of(p) for p in gold_files}

    gold_pgs, dist_pgs, neg_pgs = [], [], []
    for p in q["passages"]:
        if p["label"] == 1:
            if p["path"] in gold_files:
                gold_pgs.append(p)
            else:
                dist_pgs.append(p)
        else:
            neg_pgs.append(p)

    # gold sintético para queries sin gold en el pool (Q06): ventana ±4 sobre la
    # línea del archivo gold que contiene la aguja. Se AGREGA al pool de selección
    # (si no, Q06 no tiene gold que atribuir — el pool no lo contiene).
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
                                      "ramas": ["SYNTH"], "text": txt, "needle": gf})
                    break
    if synth:
        gold_pgs = gold_pgs + synth

    # pares gold-vs-distractor: UN par por needle (la aguja está en ambos)
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

    pool = list(q["passages"])
    if synth:
        pool = pool + synth

    queries.append({"qid": qid, "query": query, "qtext": qtext,
                    "gold_files": gold_files, "gold_facts": gold_facts,
                    "gold_domains": gold_domains,
                    "gold_pgs": gold_pgs, "dist_pgs": dist_pgs, "neg_pgs": neg_pgs,
                    "pairs": pairs, "pool": pool})

# ── señales por pasaje ──
for qd in queries:
    pool = qd["pool"]
    q_emb = norm(embed_one(qd["qtext"]))
    q_toks = salient_tokens(qd["qtext"])

    # S1 + S7 raw
    for p in pool:
        p["_s1"] = cosine(norm(passage_emb(p["text"])), q_emb)
        p["_s7_raw"] = len(p["text"].split())

    # S2: especificidad (rareza cruzada en el pool de la query)
    pool_toks = [salient_tokens(p["text"]) - q_toks for p in pool]
    n = len(pool)
    for i, p in enumerate(pool):
        shared = sum(1 for j in range(n) if j != i and (pool_toks[i] & pool_toks[j]))
        p["_s2"] = 1.0 - shared / max(1, n - 1)

    # S3: estructura
    for p in pool:
        p["_s3"] = structured(p["text"])

    # S4: canonicalidad
    for p in pool:
        p["_s4"] = 0.0 if p["path"] in NOISE_FILES else 1.0

    # S5: recencia (mtime normalizado en el pool)
    mt = []
    for p in pool:
        try:
            mt.append(os.path.getmtime(os.path.join(repo, p["path"])))
        except OSError:
            mt.append(0.0)
    mn, mx = min(mt), max(mt)
    for p, m in zip(pool, mt):
        p["_s5"] = (m - mn) / (mx - mn) if mx > mn else 0.5

    # S7: concisión (normalizado inverso en el pool)
    toks = [p["_s7_raw"] for p in pool]
    tn, tx = min(toks), max(toks)
    for p in pool:
        p["_s7"] = 1.0 - (p["_s7_raw"] - tn) / (tx - tn) if tx > tn else 0.5

# ── modelos ──
def model_score(p, model):
    if model == "S1":
        return W["s1"] * p["_s1"]
    if model == "M1":
        return W["s1"]*p["_s1"] + W["s2"]*p["_s2"]
    if model == "M2":
        return W["s1"]*p["_s1"] + W["s2"]*p["_s2"] + W["s3"]*p["_s3"]
    if model == "M3":
        return W["s1"]*p["_s1"] + W["s2"]*p["_s2"] + W["s3"]*p["_s3"] + W["s4"]*p["_s4"]
    if model == "FULL":
        return (W["s1"]*p["_s1"] + W["s2"]*p["_s2"] + W["s3"]*p["_s3"] +
                W["s4"]*p["_s4"] + W["s5"]*p["_s5"] + W["s7"]*p["_s7"])
    # M4 / FULL+MMR: el score base es M3 / FULL (MMR es post-poda de selección)
    if model == "M4":
        return model_score(p, "M3")
    if model == "FULL+MMR":
        return model_score(p, "FULL")
    raise ValueError(model)

def mmr_select(scored, k, lam):
    selected = []
    remaining = scored[:]
    while len(selected) < k and remaining:
        best = None
        best_val = -1e18
        for p, s in remaining:
            if selected:
                sim = max(cosine(norm(passage_emb(p["text"])),
                                 norm(passage_emb(sl["text"]))) for sl, _ in selected)
            else:
                sim = 0.0
            val = lam * s - (1 - lam) * sim
            if val > best_val:
                best_val = val
                best = (p, s)
        selected.append(best)
        remaining.remove(best)
    return selected

MODELS = ["S1", "M1", "M2", "M3", "M4", "FULL", "FULL+MMR"]
GATES = ["hard", "soft", "rescue"] if gate_mode == "both" else [gate_mode]
def gate_pool(pool, gate):
    """Pre-filtro por relevancia S1 (el piso del diseño).
    hard:   floor θ — solo pasajes con S1 ≥ θ.
    rescue: floor rescue_low (default 0.50) — franja [rescue_low, θ) habilitada
            para que la calidad rescate golds que θ corta por margen mínimo
            (decisión 2b del usuario, 2026-08-13). Soft (sin piso) se descartó:
            15A soft colapsó (attr 1/20).
    soft:   sin piso (medido solo como contrafactual).
    """
    if gate == "hard":
        return [p for p in pool if p["_s1"] >= THETA], {}
    if gate == "rescue":
        return [p for p in pool if p["_s1"] >= RESCUE_LOW], {"rescue_low": RESCUE_LOW}
    return list(pool), {}

def measure(model, gate):
    per_query = []
    for qd in queries:
        pool = qd["pool"]
        gated, gate_info = gate_pool(pool, gate)
        # franja rescatada: pasajes con S1 ∈ [rescue_low, θ) que entraron al ctx
        rescue_low = gate_info.get("rescue_low")
        scored = [(p, model_score(p, model)) for p in gated]
        scored.sort(key=lambda x: -x[1])
        if model in ("M4", "FULL+MMR"):
            ctx = mmr_select(scored, K, LAMBDA)
        else:
            ctx = scored[:K]
        ctx_passages = [p for p, _ in ctx]
        ctx_paths = {p["path"] for p in ctx_passages}
        rescue_entered = (sum(1 for p in ctx_passages
                              if rescue_low is not None and rescue_low <= p["_s1"] < THETA)
                          if rescue_low is not None else 0)

        # pRel: pasajes de gold_files en ctx / ctx
        prel = (sum(1 for p in ctx_passages if p["path"] in qd["gold_files"]) /
                len(ctx_passages)) if ctx_passages else 0.0
        # leak: archivos en ctx fuera de gold_files y de gold_domains / archivos en ctx
        leak = (len({f for f in ctx_paths if f not in qd["gold_files"]
                     and dom_of(f) not in qd["gold_domains"]}) / len(ctx_paths)) if ctx_paths else 0.0
        # attributed: agujas cuyo needle aparece en ctx Y en un pasaje de gold_files
        ctx_text = " ".join(p["text"] for p in ctx_passages).lower()
        gold_ctx_text = " ".join(p["text"] for p in ctx_passages
                                 if p["path"] in qd["gold_files"]).lower()
        attributed = sum(1 for f in qd["gold_facts"]
                         if deaccent(f.lower()) in deaccent(ctx_text)
                         and deaccent(f.lower()) in deaccent(gold_ctx_text))
        # gold_containment: agujas en pool cuyo pasaje gold cabe en el presupuesto
        in_pool_facts = 0
        contained = 0
        for f in qd["gold_facts"]:
            nd = deaccent(f.lower())
            hit = next((p for p in qd["gold_pgs"] if nd in deaccent(p["text"].lower())), None)
            if hit is None:
                continue
            in_pool_facts += 1
            if hit["_s7_raw"] <= 10400 // max(1, len(queries)):
                contained += 1
        gcq = (contained / in_pool_facts) if in_pool_facts else 0.0
        # tokens del ctx
        tokens = sum(p["_s7_raw"] for p in ctx_passages)
        # gold_over_distractor (pares): score(gold) > score(dist)
        pair_wins = 0
        pair_rows = []
        for pr in qd["pairs"]:
            gs = model_score(pr["gold"], model)
            ds = model_score(pr["dist"], model)
            win = gs > ds
            pair_wins += int(win)
            pair_rows.append({"needle": pr["needle"][:60],
                              "gold": "%s:%d" % (pr["gold"]["path"], pr["gold"]["s"]),
                              "dist": "%s:%d" % (pr["dist"]["path"], pr["dist"]["s"]),
                              "gold_score": round(gs, 4), "dist_score": round(ds, 4),
                              "gold_wins": win})
        # baseline_regression vs S1-only: fracción del top-K de S1 que se mantiene
        s1_scored = [(p, model_score(p, "S1")) for p in gated]
        s1_scored.sort(key=lambda x: -x[1])
        s1_top = {id(p) for p, _ in s1_scored[:K]}
        stayed = sum(1 for p in ctx_passages if id(p) in s1_top)
        reg = 1.0 - (stayed / len(ctx_passages)) if ctx_passages else 0.0

        per_query.append({
            "qid": qd["qid"], "query": qd["query"],
            "pool_size": len(pool), "gated": len(gated),
            "rescue_entered": rescue_entered,
            "ctx_size": len(ctx_passages),
            "gold_in_ctx": sum(1 for p in ctx_passages if p["path"] in qd["gold_files"]),
            "dist_in_ctx": sum(1 for p in ctx_passages if p["path"] not in qd["gold_files"]
                               and p["label"] == 1),
            "neg_in_ctx": sum(1 for p in ctx_passages if p["label"] != 1),
            "passage_relevance": round(prel, 3),
            "cross_domain_leakage": round(leak, 3),
            "attributed": attributed, "gold_facts_n": len(qd["gold_facts"]),
            "gold_containment": round(gcq, 3),
            "tokens": tokens,
            "baseline_regression": round(reg, 3),
            "pair_wins": pair_wins, "pair_n": len(qd["pairs"]),
            "pairs": pair_rows,
            "ctx_passages": ["%s:%d" % (p["path"], p["s"]) for p in ctx_passages],
        })

    n = len(per_query)
    ag = {
        "passage_relevance_avg": round(sum(x["passage_relevance"] for x in per_query) / n, 3),
        "cross_domain_leakage_avg": round(sum(x["cross_domain_leakage"] for x in per_query) / n, 3),
        "attributed_total": sum(x["attributed"] for x in per_query),
        "attributed_n": sum(x["gold_facts_n"] for x in per_query),
        "gold_containment_avg": round(sum(x["gold_containment"] for x in per_query) / n, 3),
        "tokens_avg": round(sum(x["tokens"] for x in per_query) / n, 1),
        "tokens_total": sum(x["tokens"] for x in per_query),
        "baseline_regression_avg": round(sum(x["baseline_regression"] for x in per_query) / n, 3),
        "pair_wins_total": sum(x["pair_wins"] for x in per_query),
        "pair_n_total": sum(x["pair_n"] for x in per_query),
        "gold_over_distractor": round(sum(x["pair_wins"] for x in per_query) /
                                      max(1, sum(x["pair_n"] for x in per_query)), 3),
        "queries_attributed": sum(1 for x in per_query if x["attributed"] > 0),
        "queries_n": n,
        "q06_attributed": next((x["attributed"] for x in per_query if x["qid"] == "Q06"), None),
        "q08_attributed": next((x["attributed"] for x in per_query if x["qid"] == "Q08"), None),
    }
    return {"aggregate": ag, "per_query": per_query}

# ── medir ──
results = {}
for gate in GATES:
    results[gate] = {}
    for model in MODELS:
        results[gate][model] = measure(model, gate)
        a = results[gate][model]["aggregate"]
        print("  [%s] %-8s pRel=%.3f leak=%.3f attr=%d/%d gold_over_dist=%d/%d tokens=%d reg=%.3f" % (
            gate, model, a["passage_relevance_avg"], a["cross_domain_leakage_avg"],
            a["attributed_total"], a["attributed_n"], a["pair_wins_total"], a["pair_n_total"],
            a["tokens_total"], a["baseline_regression_avg"]))

summary = {
    "benchmark": "15A selector quality (Rama B)",
    "fixture": os.path.basename(fixture_path),
    "fixture_eval_hash": snap["eval_hash"],
    "theta": THETA, "k": K, "lambda": LAMBDA,
    "rescue_low": RESCUE_LOW,
    "weights": W,
    "gate_mode": gate_mode,
    "noise_files": sorted(NOISE_FILES),
    "elapsed_seconds": int(time.time() - t0_all),
    "models": results,
}
summary["determinism_hash"] = hashlib.sha1(
    json.dumps({k: v for k, v in summary.items() if k not in ("determinism_hash", "elapsed_seconds")},
               sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

json.dump(summary, open(out_file, "w", encoding='utf-8'), indent=2, ensure_ascii=False)
print("\n→ %s (%d s)" % (out_file, summary["elapsed_seconds"]))
PY
#!/usr/bin/env bash
# run-hybrid-PC.sh — Paso 8: experimento DIAGNÓSTICO de fusión acotada (variantes E=RRF, F=POOL)
# sobre el EVAL PC. Candidate generation ≠ final retrieval.
#
# Responde: ¿una fusión acotada (léxico + semántico) recupera la capacidad semántica
# que D demostró (Q06) SIN heredar el comportamiento de OR/D (leakage/relevance/tokens)?
#
# MISMO EVAL / MISMO gold definitivo / MISMO LIMIT / MISMAS métricas (instrumento
# v3.1) que los runners A/B/C/D. Cambia la capa de retrieval de UNA rama a DOS ramas
# + fusión con presupuesto:
#
#   rama L (léxica)  → buffy-search.sh OR top-50 (BUFFY_SEARCH_STRATEGY=or) + gate de
#                      co-ocurrencia ≥2 tokens significativos en la línea (mismo
#                      mecanismo and-norm del Paso 4 — no es estrategia de buffy-search.sh)
#   rama S (semántica) → índice bge-m3 cacheado de D (coseno, top-N_S)
#   pool = dedup(L ∪ S) por (path, lineno) → fusión (V1-RRF k=60 | V1-POOL rank⁻¹)
#   → presupuesto de contexto (token_budget ~2×A ≈ 10.4k, chars/4) → top-10 final
#   → métricas v3.1 + G-H0 (candidate availability por aguja)
#
# NO toca el runtime: buffy-search.sh, buffy-router.sh y el cap-selector quedan
# congelados (se invocan SOLO como generadores de candidatos / control).
#
# G-H0 (pre-gate diagnóstico, NO compuerta): por query y aguja gold:
#   in_pool_top10 / in_pool_ranked_out / in_pool_budget_cut / out_of_pool / not_in_corpus
# Atribuye correctamente: candidate gap vs fallo de presupuesto vs fallo de rerank.
#
# Uso:
#   run-hybrid-PC.sh [--variant rrf|pool] [--model bge-m3] [--ollama URL]
#                    [--out FILE] [--limit N] [--reindex] [--json] [--quiet]
#   --variant rrf|pool  fórmula de fusión V1 (default: rrf). CADA variante es un
#                       resultado experimental independiente (mismo gate para ambas).
#   --out     archivo de salida (default: baseline-<E|F>-hybrid-<variant>-PC-2026-08-11.json)
#   --limit   top-K final (default: 10, igual que A/B/C/D)
#   --reindex fuerza reconstrucción del índice semántico (ignora cache; ~38 min en CPU)
#   --json    además volcar el JSON a stdout
#   --quiet   no imprimir tabla
#
# Exit: 0 si la medición corre (es medición, no gate) · 2 error de uso/precondición.
# Precondiciones: `ollama serve` corriendo, `ollama pull bge-m3`, e índice semántico
# de D cacheado (~/.cache/buffy-eval-semantic/) — se usa tal cual (MISMO índice).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"

MODEL="bge-m3"
OLLAMA_URL="http://localhost:11434"
VARIANT="rrf"
OUT_FILE=""
JSON=false
QUIET=false
REINDEX=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant) VARIANT="${2:?falta rrf|pool}"; shift 2 ;;
    --model) MODEL="${2:?falta modelo}"; shift 2 ;;
    --ollama) OLLAMA_URL="${2:?falta URL}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta ruta}"; shift 2 ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --reindex) REINDEX=true; shift ;;
    --json) JSON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

case "$VARIANT" in
  rrf|pool) ;;
  *) echo "variante inválida: $VARIANT (rrf|pool)" >&2; exit 2 ;;
esac

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router (control)" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-search.sh" ]] || { echo "falta search (rama L)" >&2; exit 2; }

if [ -z "$OUT_FILE" ]; then
  LABEL="E"; [ "$VARIANT" = "pool" ] && LABEL="F"
  OUT_FILE="$SCRIPT_DIR/baseline-$LABEL-hybrid-$VARIANT-PC-2026-08-11.json"
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-eval-semantic"
mkdir -p "$CACHE_DIR"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/hybrid.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(VARIANT="$VARIANT" MODEL="$MODEL" OLLAMA_URL="$OLLAMA_URL" LIMIT="$LIMIT" REPO_DIR="$REPO_DIR" EVAL="$EVAL" TMP="$TMP" EVAL_HASH="$EVAL_HASH" CACHE_DIR="$CACHE_DIR" REINDEX="$REINDEX" QUIET="$QUIET" python3 - "$REPO_DIR" "$EVAL" "$TMP" "$VARIANT" "$MODEL" "$OLLAMA_URL" "$LIMIT" "$EVAL_HASH" "$CACHE_DIR" "$REINDEX" <<'PY'
import json, os, re, subprocess, sys, time, urllib.request, urllib.error, hashlib, math, unicodedata, array

repo, eval_path, tmpdir, variant, model, ollama_url, limit, eval_hash, cache_dir, reindex = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6],
    int(sys.argv[7]), sys.argv[8], sys.argv[9], sys.argv[10] == "true",
)
router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

# ── parámetros V1 (fijados ANTES de medir, sin calibrar con el EVAL) ──
N_L = 50          # candidatos léxicos (OR top-50 + gate)
N_S = 50          # candidatos semánticos (coseno top-50)
K_RRF = 60        # constante de Reciprocal Rank Fusion
BUDGET_TOKENS = 10400  # ~2× A (5 197) ≈ 10.4k, gate del usuario
BUDGET_CHARS = BUDGET_TOKENS * 4  # mismo estimador chars/4 del instrumento

try:
    import numpy as np
    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False

STOPWORDS_ES = set("""a al algo aunque asi aun cada casi como con cual cuando cuanta cuantas cuanto
cuantos de del demasiado donde el ella ellas ellos en entre esa esas ese esos esta estas
este estos fue haber hasta haya hay he hizo la las le les lo los mas me mi mis mucho muchos
mucha muchas muy nada nadie ni no nosotros nosotras nuestra nuestras nuestro nuestros o otra
otras otro otros para pero poca pocas poco pocos por porque que quien quienes quiero quiere
se sea ser si sin solo sino sobre su sus tal tambien tampoco tan tanto tanta te tiene tienes
todo todos toda todas tu tus un una uno unas usted y ya""".split())

def deaccent(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def tokenize_significant(raw):
    """Mismo pipeline que la rama OR de build_query (buffy-search.sh):
    deaccent → lowercase → alnum → ≥3 chars → stopwords → máx 8 tokens."""
    norm = deaccent(raw).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    norm = re.sub(r'\s+', ' ', norm).strip()
    toks = []
    for tok in norm.split():
        if len(tok) < 3 or tok in STOPWORDS_ES:
            continue
        toks.append(tok)
        if len(toks) >= 8:
            break
    return toks

def line_token_set(line):
    """Normaliza una línea con el MISMO pipeline y devuelve su set de tokens."""
    norm = deaccent(line).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    return set(norm.split())

def dom_of(path):
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"

def hit_parts(hit):
    """path:lineno: text → (path, lineno, text)."""
    path, rest = hit.split(':', 1)
    lineno, _, snip = rest.partition(': ')
    return path, lineno, snip

# ── corpus: MISMO alcance que find_scope de buffy-search.sh ──
def discover_corpus(repo):
    files = []
    try:
        for name in sorted(os.listdir(repo)):
            if name.startswith('.'):
                continue
            p = os.path.join(repo, name)
            if os.path.isfile(p) and (name.endswith('.md') or name.endswith('.yaml')):
                files.append(name)
    except OSError:
        pass
    for sub in ('ai-context', 'Knowledge'):
        base = os.path.join(repo, sub)
        if not os.path.isdir(base):
            continue
        for root, dirs, fnames in os.walk(base):
            dirs[:] = [d for d in dirs if d != 'deprecated']
            for fn in sorted(fnames):
                if fn.endswith('.md') or fn.endswith('.yaml'):
                    rel = os.path.relpath(os.path.join(root, fn), repo)
                    files.append(rel)
    return sorted(set(files))

def corpus_hash(repo, files):
    h = hashlib.sha1()
    for f in files:
        try:
            st = os.stat(os.path.join(repo, f))
            h.update(f"{f}:{st.st_mtime_ns}:{st.st_size}".encode())
        except OSError:
            pass
    return h.hexdigest()[:16]

def read_entries(repo, files):
    """(path, lineno, text) por línea no vacía — misma granularidad que FTS5."""
    entries = []
    for f in files:
        try:
            with open(os.path.join(repo, f), encoding='utf-8', errors='replace') as fh:
                for i, line in enumerate(fh, 1):
                    text = line.rstrip('\n')
                    if text.strip() == '':
                        continue
                    entries.append((f, i, text))
        except OSError:
            pass
    return entries

def read_line(path, lineno):
    try:
        with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
            for i, line in enumerate(f, 1):
                if i == lineno:
                    return line.rstrip('\n')
    except Exception:
        pass
    return ""

# ── Ollama ──
def ollama_post(path, payload, timeout=900):
    req = urllib.request.Request(
        ollama_url.rstrip('/') + path, data=json.dumps(payload).encode(),
        headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())

def ollama_embed_batch(texts):
    try:
        data = ollama_post('/api/embed', {'model': model, 'input': texts})
        embs = data.get('embeddings')
        if embs:
            return embs
    except urllib.error.HTTPError as e:
        if e.code == 404:
            sys.stderr.write("✗ modelo '%s' no disponible en Ollama — ejecuta: ollama pull %s\n" % (model, model))
            sys.exit(2)
        if e.code != 405:
            raise
    out = []
    for t in texts:
        d = ollama_post('/api/embeddings', {'model': model, 'prompt': t})
        out.append(d['embedding'])
    return out

def norm(v):
    s = math.sqrt(sum(x * x for x in v))
    if s == 0:
        return v
    return [x / s for x in v]

def check_ollama():
    try:
        req = urllib.request.Request(ollama_url.rstrip('/') + '/api/tags')
        with urllib.request.urlopen(req, timeout=5) as resp:
            resp.read()
    except Exception:
        sys.stderr.write("✗ Ollama no responde en %s — ¿corre `ollama serve`?\n" % ollama_url)
        sys.exit(2)

# ── índice semántico: REUTILIZA el cache de D (MISMO índice; rebuild opcional) ──
def load_or_build_index(files, entries):
    h = corpus_hash(repo, files)
    meta_path = os.path.join(cache_dir, "%s-%s.meta.json" % (model, h))
    emb_path = os.path.join(cache_dir, "%s-%s.emb" % (model, h))
    if not reindex and os.path.exists(meta_path) and os.path.exists(emb_path):
        try:
            meta = json.load(open(meta_path, encoding='utf-8'))
            dim, n = meta['dim'], meta['n']
            data = array.array('f')
            with open(emb_path, 'rb') as fh:
                data.fromfile(fh, n * dim)
            embs = [data[i*dim:(i+1)*dim] for i in range(n)]
            return meta, embs, True
        except Exception:
            pass  # cache corrupto → reconstruir

    sys.stderr.write("✗ índice semántico de D no encontrado en %s\n" % cache_dir)
    sys.stderr.write("  El Paso 8 exige el MISMO índice que D. Ejecuta primero el Paso 7\n")
    sys.stderr.write("  (run-semantic-PC.sh) o fuerza el rebuild con --reindex (~38 min en CPU).\n")
    sys.exit(2)

# ── router (control, Δ=0 esperado) ──
def run_router(q):
    t0 = time.monotonic()
    try:
        out = subprocess.run(["bash", router, "--json", q], capture_output=True, text=True, timeout=30)
        return json.loads(out.stdout), (time.monotonic() - t0) * 1000
    except Exception as e:
        return {"error": str(e)}, 0.0

# ── rama L: lexical (OR top-50 + gate co-ocurrencia ≥2 tokens) ──
def lexical_candidates(q, n_l):
    """Mismo mecanismo and-norm del Paso 4: buffy-search.sh OR top-N_L + gate ≥2
    tokens significativos en la línea completa. Devuelve [(path, lineno, text)]
    en orden bm25, y el número de hits antes del gate."""
    t0 = time.monotonic()
    q_tokens = set(tokenize_significant(q))
    env = dict(os.environ, BUFFY_SEARCH_STRATEGY="or")
    try:
        out = subprocess.run(["bash", search, "-l", str(n_l), q],
                             capture_output=True, text=True, timeout=60, env=env)
        lines = [l for l in out.stdout.splitlines() if ':' in l]
    except Exception as e:
        return [], 0.0, q_tokens, 0, 0
    kept = []
    before = 0
    for hit in lines:
        if ':' not in hit:
            continue
        path, rest = hit.split(':', 1)
        if not path or not rest[:1].isdigit():
            continue
        if not os.path.exists(os.path.join(repo, path)):
            continue
        before += 1
        lineno = int(rest.split(':', 1)[0])
        full = read_line(path, lineno)
        if len(q_tokens & line_token_set(full)) >= 2:
            kept.append((path, lineno, full))
    return kept, (time.monotonic() - t0) * 1000, q_tokens, before, len(kept)

# ── rama S: semantic (coseno sobre el índice de D, top-N_S) ──
NUMPY_MATRIX = None
if HAVE_NUMPY:
    flat = array.array('f')
    for row in embs:
        flat.extend(row)
    NUMPY_MATRIX = np.frombuffer(flat.tobytes(), dtype=np.float32).reshape(len(embs), dim)

def semantic_candidates(query, n_s):
    t0 = time.monotonic()
    try:
        q_emb = ollama_embed_batch([query])[0]
    except urllib.error.URLError as e:
        sys.stderr.write("✗ Ollama no responde en %s — ¿corre `ollama serve`?\n" % ollama_url)
        sys.exit(2)
    q_vec = norm(q_emb)
    n = len(embs)
    if NUMPY_MATRIX is not None:
        scores = (NUMPY_MATRIX @ np.array(q_vec, dtype=np.float32)).tolist()
    else:
        scores = [sum(a * b for a, b in zip(row, q_vec)) for row in embs]
    if not scores:
        sys.stderr.write("✗ índice vacío\n")
        sys.exit(2)
    top = sorted(range(n), key=lambda i: (-scores[i], meta['entries'][i]['path'], meta['entries'][i]['lineno']))[:n_s]
    cands = []
    for i in top:
        path = meta['entries'][i]['path']
        lineno = meta['entries'][i]['lineno']
        if not os.path.exists(os.path.join(repo, path)):
            continue
        cands.append((path, lineno, read_line(path, lineno)))
    return cands, (time.monotonic() - t0) * 1000

# ── fusión ──
def fuse(pool, ranks, variant):
    """pool: lista (path, lineno, text) dedup (L primero, S después, tiebreak de
    estabilidad). ranks: dict {(path,lineno): {'L': r|None, 'S': r|None}} 1-based.
    Devuelve la lista ordenada por (-score, path, lineno)."""
    scored = []
    for item in pool:
        key = (item[0], item[1])
        rL = ranks[key].get('L')
        rS = ranks[key].get('S')
        if variant == 'rrf':
            s = 0.0
            if rL is not None:
                s += 1.0 / (K_RRF + rL)
            if rS is not None:
                s += 1.0 / (K_RRF + rS)
        else:  # pool
            s = (1.0 / rL if rL is not None else 0.0) + (1.0 / rS if rS is not None else 0.0)
        scored.append((s, item))
    scored.sort(key=lambda x: (-x[0], x[1][0], x[1][1]))
    return [item for _, item in scored]

# ── runner ──
fixture = json.load(open(eval_path, encoding='utf-8'))
files = discover_corpus(repo)
entries = read_entries(repo, files)
meta, embs, cache_hit = load_or_build_index(files, entries)
dim = meta['dim']

# para G-H0: existencia de la aguja en el corpus (línea completa, normalizada UNA vez
# — evita re-normalizar ~6.9k líneas por cada aguja gold)
corpus_norm = [deaccent(t).lower() for t in (t for _, _, t in entries)]

per_query = []
router_p, router_r, multi_p, multi_r, srec, srec_other, srec_raw, crel, leak, toks, lats = [], [], [], [], [], [], [], [], [], [], []
g_h0_counts = {"in_pool_top10": 0, "in_pool_ranked_out": 0, "in_pool_budget_cut": 0, "out_of_pool": 0, "not_in_corpus": 0}

for q in fixture["queries"]:
    qid, query = q["id"], q["query"]
    gold_domains = set(q.get("gold_domains", []))
    gold_files = set(q.get("gold_files", []))
    gold_facts = q.get("gold_facts", [])

    r, lat_router = run_router(query)
    cats = r.get("categories", [])
    kno = r.get("knowledge", [])
    skills = r.get("skills", [])

    # ── generación de candidatos (ramas independientes) ──
    cands_l, lat_l, q_tokens, hits_before, hits_after = lexical_candidates(query, N_L)
    cands_s, lat_s = semantic_candidates(query, N_S)
    latency = round(lat_router + lat_l + lat_s, 1)

    # ── pool dedup por (path, lineno); L primero (tiebreak de estabilidad, no peso) ──
    pool = []
    seen = set()
    ranks = {}
    for i, item in enumerate(cands_l):
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        ranks[key] = {'L': len(pool) + 1, 'S': None}
        pool.append(item)
    for i, item in enumerate(cands_s):
        key = (item[0], item[1])
        if key in seen:
            ranks[key]['S'] = None  # ya tenía rank L; el rank S se asigna abajo
            continue
        seen.add(key)
        ranks[key] = {'L': None, 'S': len(pool) + 1}
        pool.append(item)
    # ranks reales por rama (1-based sobre la lista ORIGINAL de cada rama)
    for i, item in enumerate(cands_l):
        key = (item[0], item[1])
        ranks[key]['L'] = i + 1
    for i, item in enumerate(cands_s):
        key = (item[0], item[1])
        ranks[key]['S'] = i + 1

    # ── fusión → top-10 final ──
    reranked = fuse(pool, ranks, variant)
    top10 = reranked[:limit]
    hits = ["%s:%s: %s" % (p, l, t) for (p, l, t) in top10]

    # ── contexto final: router ∪ pool en orden de rerank, cortado por presupuesto ──
    ctx_paths = set(kno)
    chars_used = 0
    for f in ctx_paths:
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            chars_used += os.path.getsize(p)
    pool_cut = 0
    for item in reranked:
        path = item[0]
        if path in ctx_paths:
            continue
        p = os.path.join(repo, path)
        size = os.path.getsize(p) if os.path.isfile(p) else 0
        if chars_used + size > BUDGET_CHARS:
            pool_cut += 1
            continue
        ctx_paths.add(path)
        chars_used += size

    # ── métricas: router (control) ──
    router_kno_set = set(kno)
    gold_in_router = router_kno_set & gold_files
    rp = len(gold_in_router) / len(router_kno_set) if router_kno_set else 0.0
    rr = len(gold_in_router) / len(gold_files) if gold_files else 0.0
    cats_recall = len(gold_domains & set(cats)) / len(gold_domains) if gold_domains else 0.0
    spurious = sorted(set(cats) - gold_domains)
    router_p.append(rp); router_r.append(rr)
    if len(gold_domains) >= 2:
        multi_p.append(rp); multi_r.append(rr)

    # ── search — instrumento v2/v3.1 (clasificación por path sobre el top-10 final) ──
    gold_facts_matches = []
    gold_matches = 0
    other_matches = 0
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        gold_paths, other_paths = [], []
        for hit in hits:
            hpath, _, snip = hit_parts(hit)
            if needle in deaccent(snip).lower():
                if hpath in gold_files:
                    gold_paths.append(hpath)
                else:
                    other_paths.append(hpath)
        if gold_paths:
            status = "gold_file_match"; gold_matches += 1
        elif other_paths:
            status = "other_file_match"; other_matches += 1
        else:
            status = "no_match"
        gold_facts_matches.append({
            "text": f["text"], "status": status,
            "path": sorted(set(gold_paths + other_paths)) or None,
        })
    nf = len(gold_facts) if gold_facts else 0
    sr = gold_matches / nf if nf else 0.0
    sr_other = other_matches / nf if nf else 0.0
    sr_raw = (gold_matches + other_matches) / nf if nf else 0.0
    srec.append(sr); srec_other.append(sr_other); srec_raw.append(sr_raw)

    # ── G-H0: candidate availability por aguja (pool ANTERIOR al recorte de presupuesto) ──
    candidate_status = []
    pool_norm = [(deaccent(t).lower(), p) for t, p in ((item[2], item[0]) for item in reranked)]
    hit_norm = [(deaccent(s).lower(), p) for p, _, s in (hit_parts(h) for h in hits)]
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        in_top10 = any(needle in snip_norm for snip_norm, _ in hit_norm)
        if in_top10:
            st = "in_pool_top10"
            needle_in_corpus = True
        else:
            found_idx = next((i for i, (txt_n, _p) in enumerate(pool_norm)
                              if needle in txt_n), None)
            if found_idx is None:
                needle_in_corpus = any(needle in c for c in corpus_norm)
                st = "not_in_corpus" if not needle_in_corpus else "out_of_pool"
            else:
                needle_in_corpus = True
                hit_path = pool_norm[found_idx][1]
                st = "in_pool_budget_cut" if hit_path not in ctx_paths else "in_pool_ranked_out"
        g_h0_counts[st] += 1
        candidate_status.append({"text": f["text"], "candidate_status": st,
                                 "needle_in_corpus": needle_in_corpus})

    # ── contexto final: relevance / leakage / tokens (mismo instrumento v3) ──
    files_gold = gold_files
    crel_q = len(ctx_paths & files_gold) / len(ctx_paths) if ctx_paths else 0.0
    leak_q = len({f for f in ctx_paths if f not in files_gold and dom_of(f) not in gold_domains}) / len(ctx_paths) if ctx_paths else 0.0
    crel.append(crel_q); leak.append(leak_q)

    ctx_chars = 0
    for f in ctx_paths:
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            ctx_chars += os.path.getsize(p)
    tok_q = ctx_chars // 4
    toks.append(tok_q)
    lats.append(latency)

    per_query.append({
        "id": qid, "query": query, "coverage": q.get("coverage"),
        "strategy": "hybrid", "variant": variant,
        "gold_domains": sorted(gold_domains),
        "router_categories": cats,
        "categories_recall": round(cats_recall, 3),
        "spurious_categories": spurious,
        "router_precision": round(rp, 3),
        "router_recall": round(rr, 3),
        "gold_files": sorted(gold_files),
        "router_knowledge": kno,
        "gold_in_router": sorted(gold_in_router),
        "search_top_n": len(hits),
        "search_recall": round(sr, 3),
        "search_other_recall": round(sr_other, 3),
        "search_recall_raw": round(sr_raw, 3),
        "gold_facts_matches": gold_facts_matches,
        "g_h0": {
            "candidate_status": candidate_status,
            "pool_stats": {"L": len(cands_l), "S": len(cands_s), "total": len(pool), "cut": pool_cut},
            "cooccurrence_stats": {"query_tokens": sorted(q_tokens), "hits_before_gate": hits_before, "hits_after_gate": hits_after},
        },
        "context_relevance": round(crel_q, 3),
        "cross_domain_leakage": round(leak_q, 3),
        "context_estimated_tokens": tok_q,
        "latency_ms": latency,
        "search_hit_paths": sorted({p for p, _, _ in top10}),
    })

n = len(per_query)

def agg(name, vals, multi=False):
    if not vals:
        return "n/a"
    m = sum(vals) / len(vals)
    if multi:
        return {"avg": round(m, 3), "n": len(vals)}
    if name in ("latency_ms", "token_cost"):
        s = sorted(vals)
        idx = min(len(s) - 1, int(round(0.95 * (len(s) - 1))))
        return {"avg": round(m, 3), "p95": round(s[idx], 3)}
    return {"avg": round(m, 3)}

label = {"rrf": "E", "pool": "F"}[variant]
pipeline_desc = (
    "buffy-router.sh (control) → L: buffy-search.sh OR top-%d + gate co-ocurrencia ≥2 tokens → "
    "S: %s coseno top-%d (índice cacheado de D) → pool dedup(%d∪%d) → fusión V1-%s → "
    "presupuesto %d tokens → top-%d"
) % (N_L, model, N_S, N_L, N_S, "RRF (k=60)" if variant == "rrf" else "POOL (rank⁻¹)", BUDGET_TOKENS, limit)

summary = {
    "baseline": label,
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": eval_hash,
    "strategy": "hybrid",
    "variant": variant,
    "model": model,
    "instrument_version": "v3.1",
    "pipeline": pipeline_desc,
    "snippet_scope": "full_line",
    "runtime_changed": False,
    "params": {"N_L": N_L, "N_S": N_S, "K_RRF": K_RRF if variant == "rrf" else None,
               "budget_tokens": BUDGET_TOKENS, "limit": limit},
    "index_stats": {
        "files": len(files),
        "lines": len(entries),
        "dim": dim,
        "cache_hit": cache_hit,
        "build_seconds": meta.get('build_seconds'),
    },
    "num_queries": n,
    "aggregate": {
        "router_precision_avg": round(sum(router_p)/n, 3) if router_p else "n/a",
        "router_recall_avg": round(sum(router_r)/n, 3) if router_r else "n/a",
        "multi_domain_precision": agg("m", multi_p, multi=True),
        "multi_domain_recall": agg("m", multi_r, multi=True),
        "categories_recall_avg": round(sum([q["categories_recall"] for q in per_query])/n, 3),
        "search_recall_avg": round(sum(srec)/n, 3),
        "search_other_recall_avg": round(sum(srec_other)/n, 3),
        "search_recall_raw_avg": round(sum(srec_raw)/n, 3),
        "context_relevance_avg": round(sum(crel)/n, 3),
        "cross_domain_leakage_avg": round(sum(leak)/n, 3),
        "total_spurious_categories": sum(len(q["spurious_categories"]) for q in per_query),
        "token_cost": agg("token_cost", toks),
        "latency_ms": agg("latency_ms", lats),
        "window_utilization_avg": round((sum(toks)/n)/200000, 5),
        "g_h0": dict(g_h0_counts),
    },
    "per_query": per_query,
}

def strip_nondet(o):
    if isinstance(o, dict):
        return {k: strip_nondet(v) for k, v in o.items()
                if k not in ("latency_ms", "built_at", "build_seconds", "cache_hit")}
    if isinstance(o, list):
        return [strip_nondet(x) for x in o]
    return o

summary["determinism_hash"] = hashlib.sha1(
    json.dumps(strip_nondet(summary), sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

out = os.path.join(tmpdir, "hybrid.json")
json.dump(summary, open(out, "w", encoding='utf-8'), indent=2, ensure_ascii=False)
print(out)
PY
)"

cp "$RESULT_FILE" "$OUT_FILE"

if [ "$JSON" = true ]; then
  cat "$RESULT_FILE"
fi
if [ "$QUIET" = false ]; then
  python3 - "$RESULT_FILE" "$SCRIPT_DIR" <<'PY'
import json, os, sys
d = json.load(open(sys.argv[1]))
a = d["aggregate"]
idx = d.get("index_stats", {})
par = d.get("params", {})
label = d.get("baseline", "?")
print("── Variante %s — hybrid bounded candidate retrieval (perfil PC, %s, fusión V1-%s, instrumento v3.1) ──" % (label, d.get("model", "?"), d.get("variant", "?")))
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s · queries: %d · índice: %s archivos / %s líneas / dim %s (cache %s)" % (
    d["runtime_changed"], d["num_queries"], idx.get("files"), idx.get("lines"), idx.get("dim"),
    "sí" if idx.get("cache_hit") else "no"))
print("  params: N_L=%s N_S=%s budget=%s tokens · determinism_hash: %s (gate G2)" % (
    par.get("N_L"), par.get("N_S"), par.get("budget_tokens"), d.get("determinism_hash")))
print("  ── agregado ──")
print("  router_precision_avg:    %s  (control, Δ=0 esperado)" % a["router_precision_avg"])
print("  router_recall_avg:       %s" % a["router_recall_avg"])
print("  categories_recall_avg:   %s" % a["categories_recall_avg"])
print("  search_recall_avg:       %s  (solo gold_file_match)" % a["search_recall_avg"])
print("  search_other_recall_avg: %s  (diagnóstico)" % a["search_other_recall_avg"])
print("  search_recall_raw_avg:   %s  (gold+other)" % a["search_recall_raw_avg"])
print("  context_relevance_avg:   %s" % a["context_relevance_avg"])
print("  cross_domain_leakage_avg:%s" % a["cross_domain_leakage_avg"])
print("  spurious_categories:     %s" % a["total_spurious_categories"])
print("  token_cost:              %s (media) / p95 %s" % (a["token_cost"]["avg"], a["token_cost"].get("p95")))
print("  latency_ms:              %s (media) / p95 %s" % (a["latency_ms"]["avg"], a["latency_ms"].get("p95")))
print("  window_utilization:      %s (200k)" % a["window_utilization_avg"])
gh = a.get("g_h0", {})
print("  G-H0 (por aguja gold):   %s" % " · ".join("%s=%s" % (k, v) for k, v in gh.items()))
print("  ── por query ──")
print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-8s  %s" % ("ID", "rPrec", "rRec", "sRec", "sOth", "cRel", "leak", "tok", "latMs", "pool L/S/cut"))
for q in d["per_query"]:
    ps = q["g_h0"]["pool_stats"]
    print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-8s  %s/%s/%s" % (
        q["id"], q["router_precision"], q["router_recall"], q["search_recall"],
        q["search_other_recall"], q["context_relevance"], q["cross_domain_leakage"],
        q["context_estimated_tokens"], q["latency_ms"], ps["L"], ps["S"], ps["cut"]))
print("  ── G-H0 por query (Q03/Q06/Q08 y resto) ──")
for q in d["per_query"]:
    sts = [f"{x['candidate_status']}" for x in q["g_h0"]["candidate_status"]]
    print("  %-4s %s" % (q["id"], ", ".join(sts)))
# comparación contra baselines A/B/C/D si existen — prioriza el instrumento MÁS
# reciente (v3/v3.1 con gold definitivo) sobre duplicados v2 (mismo archivo, dos
# versiones: baseline-A-PC-*.json era v2; baseline-and-PC-*.json es v3).
base_map = {"A": None, "B": None, "C": None, "D": None}
base_inst = {}
def _inst_rank(v):
    return 0 if not v else (1 if v.startswith("v2") else (2 if v.startswith("v3") else 3))
for f in os.listdir(sys.argv[2]):
    if f.startswith("baseline-") and f.endswith(".json") and "hybrid" not in f:
        try:
            bd = json.load(open(os.path.join(sys.argv[2], f), encoding='utf-8'))
        except Exception:
            continue
        k = bd.get("baseline")
        if k not in base_map or k is None:
            continue
        rank = _inst_rank(bd.get("instrument_version"))
        if base_map[k] is None or rank > base_inst.get(k, -1):
            base_map[k] = bd
            base_inst[k] = rank
present = [k for k, v in base_map.items() if v]
if present:
    print("  ── comparación agregada (baselines congeladas vs %s) ──" % label)
    print("  %-4s %-8s %-10s %-8s %-8s %-8s" % ("base", "sRec", "cRel", "leak", "tokAvg", "tokP95"))
    for k in ("A", "B", "C", "D"):
        bd = base_map[k]
        if not bd:
            continue
        ba = bd["aggregate"]
        print("  %-4s %-8s %-10s %-8s %-8s %-8s" % (k, ba["search_recall_avg"], ba["context_relevance_avg"],
              ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95")))
    ba = d["aggregate"]
    print("  %-4s %-8s %-10s %-8s %-8s %-8s" % (label, ba["search_recall_avg"], ba["context_relevance_avg"],
          ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95")))
PY
fi

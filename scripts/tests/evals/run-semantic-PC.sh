#!/usr/bin/env bash
# run-semantic-PC.sh — Paso 7: experimento semántico DIAGNÓSTICO (variante D) sobre el EVAL PC.
#
# Responde: ¿un retrieval semántico recupera Q03/Q06/Q08 sin reproducir el leakage
# y coste de OR?
#
# MISMO EVAL / MISMO gold definitivo / MISMO LIMIT / MISMAS métricas (instrumento
# v3.1) que el runner lexical (run-baseline-PC.sh). Cambia UNA variable:
#
#   lexical retrieval (FTS5 BM25)  →  semantic retrieval (embeddings + coseno)
#
# Indexa el corpus (mismo alcance que buffy-search.sh: raíz *.md/*.yaml +
# ai-context/ + Knowledge/, excluyendo deprecated/) línea por línea, genera
# embeddings vía Ollama (/api/embed) y recupera top-LIMIT por similitud coseno.
#
# NO toca el runtime: buffy-search.sh, buffy-router.sh y el cap-selector quedan
# congelados. El router SOLO se usa como control (router_* debe quedar Δ=0).
#
# Uso:
#   run-semantic-PC.sh [--model bge-m3|nomic-embed-text] [--ollama URL]
#                      [--out FILE] [--limit N] [--reindex] [--json] [--quiet]
#   --model   modelo de embeddings (default: bge-m3; nomic-embed-text = sanity inglés)
#   --ollama  URL del servidor Ollama (default: http://localhost:11434)
#   --out     archivo de salida (default: baseline-D-semantic-PC-2026-08-11.json)
#   --limit   top-K recuperado (default: 10, igual que A/B/C)
#   --reindex fuerza reconstrucción del índice (ignora cache)
#   --json    además volcar el JSON a stdout
#   --quiet   no imprimir tabla
#
# Exit: 0 si la medición corre (es medición, no gate) · 2 error de uso/precondición.
# Precondiciones: `ollama serve` corriendo y modelo descargado (`ollama pull bge-m3`).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"

MODEL="bge-m3"
OLLAMA_URL="http://localhost:11434"
OUT_FILE=""
JSON=false
QUIET=false
REINDEX=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --model) MODEL="${2:?falta modelo}"; shift 2 ;;
    --ollama) OLLAMA_URL="${2:?falta URL}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta ruta}"; shift 2 ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --reindex) REINDEX=true; shift ;;
    --json) JSON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router (control)" >&2; exit 2; }

if [ -z "$OUT_FILE" ]; then
  OUT_FILE="$SCRIPT_DIR/baseline-D-semantic-PC-2026-08-11.json"
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-eval-semantic"
mkdir -p "$CACHE_DIR"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/semantic.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(MODEL="$MODEL" OLLAMA_URL="$OLLAMA_URL" LIMIT="$LIMIT" REPO_DIR="$REPO_DIR" EVAL="$EVAL" TMP="$TMP" EVAL_HASH="$EVAL_HASH" CACHE_DIR="$CACHE_DIR" REINDEX="$REINDEX" QUIET="$QUIET" python3 - "$REPO_DIR" "$EVAL" "$TMP" "$MODEL" "$OLLAMA_URL" "$LIMIT" "$EVAL_HASH" "$CACHE_DIR" "$REINDEX" <<'PY'
import json, os, re, subprocess, sys, time, urllib.request, urllib.error, hashlib, math, unicodedata, array

repo, eval_path, tmpdir, model, ollama_url, limit, eval_hash, cache_dir, reindex = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5],
    int(sys.argv[6]), sys.argv[7], sys.argv[8], sys.argv[9] == "true",
)
router = os.path.join(repo, "scripts/buffy-router.sh")

try:
    import numpy as np
    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False

def deaccent(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def dom_of(path):
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"

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
    """(path, lineno, text) por línea no vacía — misma granularidad que FTS5 (una fila por línea)."""
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
    """/api/embed (nuevo) con fallback a /api/embeddings (deprecado) si el server no lo tiene.
    Errores 404 (modelo no disponible) y de conexión se traducen a salida amigable + exit 2."""
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
    """GET /api/tags (Ollama solo define GET; un POST responde 405)."""
    try:
        req = urllib.request.Request(ollama_url.rstrip('/') + '/api/tags')
        with urllib.request.urlopen(req, timeout=5) as resp:
            resp.read()
    except Exception:
        sys.stderr.write("✗ Ollama no responde en %s — ¿corre `ollama serve`?\n" % ollama_url)
        sys.exit(2)

# ── índice semántico (cache por hash del corpus; determinista) ──
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

    t0 = time.monotonic()
    check_ollama()
    # batch por tamaño: ~64 líneas o ~6000 chars por request
    batches, cur, cur_chars = [], [], 0
    for _, _, text in entries:
        cur.append(text)
        cur_chars += len(text) + 1
        if len(cur) >= 64 or cur_chars >= 6000:
            batches.append(cur)
            cur, cur_chars = [], 0
    if cur:
        batches.append(cur)

    flat = array.array('f')
    dim = None
    total = len(entries)
    done = 0
    for bi, batch in enumerate(batches, 1):
        for emb in ollama_embed_batch(batch):
            if dim is None:
                dim = len(emb)
            elif len(emb) != dim:
                sys.stderr.write("✗ dimensión inconsistente (%d vs %d) — ¿modelo de embeddings correcto?\n" % (len(emb), dim))
                sys.exit(2)
            flat.extend(norm(emb))
        done += len(batch)
        if not os.environ.get('QUIET') == 'true':
            sys.stderr.write("  índice %s: %d/%d líneas (batch %d/%d)\r" % (model, done, total, bi, len(batches)))
    if not os.environ.get('QUIET') == 'true':
        sys.stderr.write("\n")
    if dim is None:
        sys.stderr.write("✗ no se generó ningún embedding — modelo '%s' disponible? (ollama pull %s)\n" % (model, model))
        sys.exit(2)

    meta = {
        'model': model, 'dim': dim, 'n': len(entries),
        'corpus_hash': h,
        'entries': [{'path': p, 'lineno': l} for p, l, _ in entries],
        'built_at': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'build_seconds': round(time.monotonic() - t0, 1),
    }
    json.dump(meta, open(meta_path, 'w', encoding='utf-8'), ensure_ascii=False)
    with open(emb_path, 'wb') as fh:
        flat.tofile(fh)
    embs = [flat[i*dim:(i+1)*dim] for i in range(len(entries))]
    return meta, embs, False

# ── router (control, Δ=0 esperado) ──
def run_router(q):
    t0 = time.monotonic()
    try:
        out = subprocess.run(["bash", router, "--json", q], capture_output=True, text=True, timeout=30)
        return json.loads(out.stdout), (time.monotonic() - t0) * 1000
    except Exception as e:
        return {"error": str(e)}, 0.0

# ── semantic retrieval ──
# Matriz numpy construida UNA vez (si disponible) para el ranking vectorizado.
NUMPY_MATRIX = None
if HAVE_NUMPY:
    flat = array.array('f')
    for row in embs:
        flat.extend(row)
    NUMPY_MATRIX = np.frombuffer(flat.tobytes(), dtype=np.float32).reshape(len(embs), dim)

def semantic_search(query, limit, embs, dim):
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
        sys.stderr.write("✗ índice vacío — no se generó ningún embedding\n")
        sys.exit(2)
    top = sorted(range(n), key=lambda i: (-scores[i], meta['entries'][i]['path'], meta['entries'][i]['lineno']))[:limit]
    hits = []
    for i in top:
        path = meta['entries'][i]['path']
        lineno = meta['entries'][i]['lineno']
        hits.append("%s:%s: %s" % (path, lineno, read_line(path, lineno)))
    return hits, (time.monotonic() - t0) * 1000

def valid_hit(hit):
    if ':' not in hit:
        return False
    path, rest = hit.split(':', 1)
    if not path or not rest[:1].isdigit():
        return False
    return os.path.exists(os.path.join(repo, path))

def hit_parts(hit):
    path, rest = hit.split(':', 1)
    lineno, _, snip = rest.partition(': ')
    return path, lineno, snip

# ── runner ──
fixture = json.load(open(eval_path, encoding='utf-8'))
files = discover_corpus(repo)
entries = read_entries(repo, files)
meta, embs, cache_hit = load_or_build_index(files, entries)
dim = meta['dim']

per_query = []
router_p, router_r, multi_p, multi_r, srec, srec_other, srec_raw, crel, leak, toks, lats = [], [], [], [], [], [], [], [], [], [], []

for q in fixture["queries"]:
    qid, query = q["id"], q["query"]
    gold_domains = set(q.get("gold_domains", []))
    gold_files = set(q.get("gold_files", []))
    gold_facts = q.get("gold_facts", [])

    r, lat_router = run_router(query)
    cats = r.get("categories", [])
    kno = r.get("knowledge", [])
    skills = r.get("skills", [])

    hits, lat_search = semantic_search(query, limit, embs, dim)
    hits = [h for h in hits if valid_hit(h)]
    latency = round(lat_router + lat_search, 1)

    # ── router (control) ──
    router_kno_set = set(kno)
    gold_in_router = router_kno_set & gold_files
    rp = len(gold_in_router) / len(router_kno_set) if router_kno_set else 0.0
    rr = len(gold_in_router) / len(gold_files) if gold_files else 0.0
    cats_recall = len(gold_domains & set(cats)) / len(gold_domains) if gold_domains else 0.0
    spurious = sorted(set(cats) - gold_domains)
    router_p.append(rp); router_r.append(rr)
    if len(gold_domains) >= 2:
        multi_p.append(rp); multi_r.append(rr)

    # ── search — instrumento v2 (clasificación por path, no texto concatenado) ──
    gold_facts_matches = []
    gold_matches = 0
    other_matches = 0
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        gold_paths, other_paths = [], []
        for hit in hits:
            path, lineno, snip = hit_parts(hit)
            if needle in deaccent(snip).lower():
                if path in gold_files:
                    gold_paths.append(path)
                else:
                    other_paths.append(path)
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

    # ── contexto final ctx_q = router ∪ topK (dedup) ──
    hit_paths = {p for p, _, _ in [hit_parts(x) for x in hits] if p}
    ctx = router_kno_set | hit_paths
    files_gold = gold_files
    crel_q = len(ctx & files_gold) / len(ctx) if ctx else 0.0
    # Instrumento v3 (Paso 6): un archivo gold NUNCA es leakage.
    leak_q = len({f for f in ctx if f not in files_gold and dom_of(f) not in gold_domains}) / len(ctx) if ctx else 0.0
    crel.append(crel_q); leak.append(leak_q)

    # ── token cost: chars(ctx)/4 (mismo estimador del bench realista) ──
    ctx_chars = 0
    for f in ctx:
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            ctx_chars += os.path.getsize(p)
    tok_q = ctx_chars // 4
    toks.append(tok_q)
    lats.append(latency)

    per_query.append({
        "id": qid, "query": query, "coverage": q.get("coverage"),
        "strategy": "semantic",
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
        "context_relevance": round(crel_q, 3),
        "cross_domain_leakage": round(leak_q, 3),
        "context_estimated_tokens": tok_q,
        "latency_ms": latency,
        "search_hit_paths": sorted(hit_paths),
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

summary = {
    "baseline": "D",
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": eval_hash,
    "strategy": "semantic",
    "model": model,
    "instrument_version": "v3.1",
    "pipeline": "buffy-router.sh (control) → Ollama %s embeddings por línea → coseno → top-%d" % (model, limit),
    "snippet_scope": "full_line",
    "runtime_changed": False,
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
    },
    "per_query": per_query,
}

# determinism_hash: sha1 del JSON sin latencia NI metadatos de build (gate G2:
# 2 corridas → mismo hash, aunque la segunda use cache).
def strip_nondet(o):
    if isinstance(o, dict):
        return {k: strip_nondet(v) for k, v in o.items()
                if k not in ("latency_ms", "built_at", "build_seconds", "cache_hit")}
    if isinstance(o, list):
        return [strip_nondet(x) for x in o]
    return o

summary["determinism_hash"] = hashlib.sha1(
    json.dumps(strip_nondet(summary), sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

out = os.path.join(tmpdir, "semantic.json")
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
print("── Variante D — retrieval semántico (perfil PC, modelo %s, estrategia 'semantic', instrumento v3.1) ──" % d.get("model", "?"))
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s · queries: %d · índice: %s archivos / %s líneas / dim %s (cache %s)" % (
    d["runtime_changed"], d["num_queries"], idx.get("files"), idx.get("lines"), idx.get("dim"),
    "sí" if idx.get("cache_hit") else "no"))
print("  determinism_hash: %s (gate G2: 2 corridas → mismo hash, sin latencia)" % d.get("determinism_hash"))
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
print("  multi_domain_precision:  %s (n=%s)" % (a["multi_domain_precision"]["avg"], a["multi_domain_precision"]["n"]))
print("  multi_domain_recall:     %s (n=%s)" % (a["multi_domain_recall"]["avg"], a["multi_domain_recall"]["n"]))
print("  ── por query ──")
print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-8s" % ("ID", "rPrec", "rRec", "sRec", "sOth", "cRel", "leak", "tok", "latMs"))
for q in d["per_query"]:
    print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-7s %-8s" % (
        q["id"], q["router_precision"], q["router_recall"], q["search_recall"],
        q["search_other_recall"], q["context_relevance"], q["cross_domain_leakage"],
        q["context_estimated_tokens"], q["latency_ms"]))
# comparación contra baselines A/B/C si existen
base_map = {"A": None, "B": None, "C": None}
for f in os.listdir(sys.argv[2]):
    if f.startswith("baseline-") and f.endswith(".json") and "semantic" not in f:
        try:
            bd = json.load(open(os.path.join(sys.argv[2], f), encoding='utf-8'))
            if bd.get("baseline") in base_map:
                base_map[bd["baseline"]] = bd
        except Exception:
            pass
present = [k for k, v in base_map.items() if v]
if present:
    print("  ── comparación agregada (baselines congeladas vs D) ──")
    print("  %-4s %-8s %-10s %-8s %-8s %-8s" % ("base", "sRec", "cRel", "leak", "tokAvg", "tokP95"))
    for k in ("A", "B", "C"):
        bd = base_map[k]
        if not bd:
            continue
        ba = bd["aggregate"]
        print("  %-4s %-8s %-10s %-8s %-8s %-8s" % (k, ba["search_recall_avg"], ba["context_relevance_avg"],
              ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95")))
    ba = d["aggregate"]
    print("  %-4s %-8s %-10s %-8s %-8s %-8s" % ("D", ba["search_recall_avg"], ba["context_relevance_avg"],
          ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95")))
PY
fi

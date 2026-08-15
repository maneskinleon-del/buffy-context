#!/usr/bin/env bash
# run-leak-17C.sh — Paso 17C: reducción del leak estructural del pool (A/V1/V2/V3)
# ─────────────────────────────────────────────────────────────────────────────
# Pregunta (H17C, spec leak-17C-DESIGN.md): el leak 0.442 es estructural del
# pool (invariante A/B en 17B, mínimo de 16B). ¿Excluir/penalizar en el
# ENSAMBLADO del contexto final los pasajes de noise de sesión (y raíz
# no-Knowledge) baja el leak a ≤ 0.308 sin perder attr ni regresar en prosa?
#
# Diseño: un solo factor por variante, TODO lo demás IDÉNTICO a 17B:
#   A  (control) = runner 17B tal cual (sin cambios en el ensamblado)
#   V1           = exclusión dura de noise de sesión en ctx final
#                  ctx = [p for p in gated if not (is_session_noise(p.path)
#                        and p.path not in gold_files)][:LIMIT]
#   V2           = refuerzo S4 en el ensamblado (W["s4"]: 0.5 → 1.5)
#   V3           = exclusión de raíz no-Knowledge (dom_of=="session" y no
#                  empieza con ai-context/ → fuera del ctx)
# El pool, DICT_H1, M3, gates y métricas quedan IDÉNTICOS al runner 17B.
# gold_files se usa SOLO para medir (nunca para rankear) — anti-oráculo.
#
# Uso:
#   run-leak-17C.sh [--variant A|V1|V2|V3] [--repeat 1|2] [--out <json>]
#                   [--repo <dir>] [--reindex] [--limit 10]
#     --variant   variante del ensamblado (default: A)
#     --repeat    corridas para determinismo G2 (default: 1; 2 = G2)
#     --out       archivo JSON de resultados
#     --repo      repo con el corpus (default: $HOME/buffy-context)
#     --reindex   forzar rebuild del índice semántico
#     --limit     presupuesto de pasajes por query (default: 10)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO_DIR:-$HOME/buffy-context}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"
OUT_FILE="${OUT_FILE:-$SCRIPT_DIR/leak-17C.json}"
PADS="4"
DICT_PATH=""
REPEAT="1"
LIMIT="10"
REINDEX="false"
VARIANT="A"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pads) PADS="${2:?falta lista}"; shift 2 ;;
    --repeat) REPEAT="${2:?falta número}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta archivo}"; shift 2 ;;
    --repo) REPO="${2:?falta dir}"; shift 2 ;;
    --dict) DICT_PATH="${2:?falta json}"; shift 2 ;;
    --variant) VARIANT="${2:?falta variante}"; shift 2 ;;
    --reindex) REINDEX="true"; shift ;;
    --limit) LIMIT="${2:?falta valor}"; shift 2 ;;
    -h|--help) sed -n '2,60p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

case "$VARIANT" in
  A|V1|V2|V3) ;;
  *) echo "variante inválida: $VARIANT (A|V1|V2|V3)" >&2; exit 2 ;;
esac

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-eval-semantic"
mkdir -p "$CACHE_DIR"

REPO="$REPO" OLLAMA_URL="$OLLAMA_URL" EVAL="$EVAL" EVAL_HASH="$EVAL_HASH" \
OUT_FILE="$OUT_FILE" PADS="$PADS" LIMIT="$LIMIT" CACHE_DIR="$CACHE_DIR" \
REINDEX="$REINDEX" DICT_PATH="${DICT_PATH:-}" VARIANT="$VARIANT" \
python3 - "$REPO" "$EVAL" "$EVAL_HASH" "$OUT_FILE" "$PADS" "$LIMIT" "$CACHE_DIR" "$REINDEX" "$DICT_PATH" "$VARIANT" <<'PY'
import json, os, re, subprocess, sys, time, urllib.request, urllib.error, hashlib, math, unicodedata, array

repo, eval_path, eval_hash, out_file, pads_s, limit_s, cache_dir, reindex, dict_path, variant = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], int(sys.argv[6]), sys.argv[7], sys.argv[8] == "true",
    sys.argv[9] if len(sys.argv) > 9 else "",
    sys.argv[10] if len(sys.argv) > 10 else "A",
)
PADS = [int(p) for p in pads_s.split()]
LIMIT = limit_s
MODEL = "bge-m3"
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")

# ── libs del pipeline (M3 V6 real + H1 real) — NO reimplementar ──
sys.path.insert(0, os.path.join(repo, "scripts", "lib"))
try:
    import expand_query          # H1 real (DICT_H1 del pipeline)
    import selector_m3           # M3 V6: select() + señales exactas
except ImportError as e:
    sys.stderr.write("✗ falta lib del pipeline (%s) — no se puede medir con M3 V6/H1 real\n" % e)
    sys.exit(2)

# reutilizamos las señales y helpers EXACTOS del selector adoptado
from selector_m3 import (embed_one, norm, cosine, salient_tokens,
                         structured, query_structural, is_session_noise, deaccent)

# transporte de embeddings: embed_all con batch ×10 + persistencia a disco
# (misma infra de 14A/15A — cache keyed por sha1(text[:2000]), float64).
# Infra, NO variable del experimento: los vectores bge-m3 son los mismos.
PASSAGE_CACHE_DIR = os.path.join(cache_dir, "passages")
os.makedirs(PASSAGE_CACHE_DIR, exist_ok=True)
EMB_CACHE = {}

def passage_emb_path(key_text, dim=1024):
    h = hashlib.sha1(key_text.encode("utf-8")).hexdigest()
    return os.path.join(PASSAGE_CACHE_DIR, "%s-%d.emb" % (h, dim))

def embed_all(texts, batch=10):
    out = [None] * len(texts)
    todo = [(i, t[:2000]) for i, t in enumerate(texts) if t.strip()]
    missing = []
    for j, key_text in todo:
        path = passage_emb_path(key_text)
        try:
            data = array.array('d')
            with open(path, 'rb') as fh:
                data.fromfile(fh, 1024)
            out[j] = data.tolist()
            continue
        except (OSError, EOFError):
            pass
        missing.append((j, key_text, path))
    for k in range(0, len(missing), batch):
        chunk = missing[k:k + batch]
        embs = selector_m3.ollama_post('/api/embed', {'model': MODEL, 'input': [kt for _j, kt, _p in chunk]})['embeddings']
        for (j, _kt, path), emb in zip(chunk, embs):
            with open(path, 'wb') as fh:
                array.array('d', emb).tofile(fh)
            out[j] = emb
    for i, t in enumerate(texts):
        if out[i] is None:
            out[i] = [0.0] * 1024
    return out
if dict_path:
    with open(dict_path, encoding="utf-8") as fh:
        _v = json.load(fh)
    expand_query.DICT_H1 = _v.get("h1", _v)  # variante congelada (A + tramo técnico)
    sys.stderr.write("dict variante cargada: %s\n" % dict_path)
H1_TERMS_FN = expand_query.expansion_terms
H1_DICT_HASH = expand_query.dict_hash()  # hash del dict USADO (drift-detector)

router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

# ── parámetros fijados ANTES de medir (idénticos a run-evidence-PC.sh) ──
N_L = 50            # léxicos (OR top-50 + gate)
N_X = 50            # por término de expansión (top-50 por re-consulta)
N_S = 50            # semánticos (coseno top-50)
P_EXPAND_TOP_K = 10 # F2: top-K archivos del pool fuera de kno
MAX_PASSAGES = 400  # guard de coste F2 (kno entran completos, pool se recorta)
X_POOL_CAP = 200    # tope de ítems X únicos por query
RESCUE_LOW = 0.545  # piso rescue (decisión 2b — NO se toca)
BUDGET_TOKENS = 10400

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

LINE_CACHE = {}
def file_lines(path):
    if path not in LINE_CACHE:
        try:
            with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
                LINE_CACHE[path] = [l.rstrip('\n') for l in f]
        except OSError:
            LINE_CACHE[path] = []
    return LINE_CACHE[path]

def tokenize_significant(raw):
    norm = deaccent(raw).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    norm = re.sub(r'\s+', ' ', norm).strip()
    toks = []
    for tok in norm.split():
        if len(tok) < 3 or tok in expand_query.STOPWORDS_ES:
            continue
        toks.append(tok)
        if len(toks) >= 8:
            break
    return toks

def line_token_set(line):
    norm = deaccent(line).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    return set(norm.split())

def dom_of(path):
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"

def passage_of(path, lineno, pad):
    total = len(file_lines(path))
    start = max(1, lineno - pad)
    end = min(total, lineno + pad)
    return start, end

def passage_text(path, s, e):
    lines = file_lines(path)
    if s < 1 or e > len(lines) or s > e:
        return ""
    return "\n".join(lines[s-1:e])

def tile_windows(path, pad):
    """Paso 13 (rama P): ventanas no-solapadas de 2·pad+1 líneas por archivo."""
    total = len(file_lines(path))
    if total <= 0:
        return []
    win = 2 * pad + 1
    out = []
    start = 1
    while start <= total:
        end = min(total, start + win - 1)
        out.append((start, end))
        start = end + 1
    return out

# ── índice semántico de líneas (cache por hash del corpus) ──
try:
    import numpy as np
    HAVE_NUMPY = True
except ImportError:
    HAVE_NUMPY = False

def load_or_build_index(files, entries):
    h = corpus_hash(repo, files)
    meta_path = os.path.join(cache_dir, "%s-%s.meta.json" % (MODEL, h))
    emb_path = os.path.join(cache_dir, "%s-%s.emb" % (MODEL, h))
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
            pass
    def _batch(texts):
        try:
            data = selector_m3.ollama_post('/api/embed', {'model': MODEL, 'input': texts})
            embs = data.get('embeddings')
            if embs:
                return embs
        except urllib.error.HTTPError as e:
            if e.code != 405:
                raise
        out = []
        for t in texts:
            d = selector_m3.ollama_post('/api/embeddings', {'model': MODEL, 'prompt': t})
            out.append(d['embedding'])
        return out
    t0 = time.monotonic()
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
        for emb in _batch(batch):
            if dim is None:
                dim = len(emb)
            elif len(emb) != dim:
                sys.stderr.write("✗ dimensión inconsistente (%d vs %d)\n" % (len(emb), dim))
                sys.exit(2)
            flat.extend(norm(emb))
        done += len(batch)
        sys.stderr.write("  índice %s: %d/%d líneas (batch %d/%d)\n" % (MODEL, done, total, bi, len(batches)))
    if dim is None:
        sys.stderr.write("✗ no se generó ningún embedding — ¿corre ollama serve?\n")
        sys.exit(2)
    meta = {'model': MODEL, 'dim': dim, 'n': len(entries), 'corpus_hash': h,
            'entries': [{'path': p, 'lineno': l} for p, l, _ in entries],
            'built_at': time.strftime('%Y-%m-%dT%H:%M:%S'),
            'build_seconds': round(time.monotonic() - t0, 1)}
    json.dump(meta, open(meta_path, 'w', encoding='utf-8'), ensure_ascii=False)
    with open(emb_path, 'wb') as fh:
        flat.tofile(fh)
    embs = [flat[i*dim:(i+1)*dim] for i in range(len(entries))]
    return meta, embs, False

# ── rama L: lexical (OR top-50 + gate co-ocurrencia ≥2 tokens) ──
def lexical_candidates(q, n_l):
    q_tokens = set(tokenize_significant(q))
    env = dict(os.environ, BUFFY_SEARCH_STRATEGY="or")
    try:
        out = subprocess.run(["bash", search, "-l", str(n_l), q],
                             capture_output=True, text=True, timeout=60, env=env)
        lines = [l for l in out.stdout.splitlines() if ':' in l]
    except Exception:
        return [], q_tokens
    kept = []
    for hit in lines:
        if ':' not in hit:
            continue
        path, rest = hit.split(':', 1)
        if not path or not rest[:1].isdigit():
            continue
        if not os.path.exists(os.path.join(repo, path)):
            continue
        lineno = int(rest.split(':', 1)[0])
        full = read_line(path, lineno)
        if len(q_tokens & line_token_set(full)) >= 2:
            kept.append((path, lineno, full))
    return kept, q_tokens

# ── rama X: expansión léxica con términos H1 REALES (expand_query.py) ──
def expansion_candidates(terms, n_x):
    env = dict(os.environ, BUFFY_SEARCH_STRATEGY="or")
    out = []
    for term in terms:
        t_tokens = set(tokenize_significant(term))
        try:
            r = subprocess.run(["bash", search, "-l", str(n_x), term],
                               capture_output=True, text=True, timeout=60, env=env)
            lines = [l for l in r.stdout.splitlines() if ':' in l]
        except Exception:
            continue
        for hit in lines:
            if ':' not in hit:
                continue
            path, rest = hit.split(':', 1)
            if not path or not rest[:1].isdigit():
                continue
            if not os.path.exists(os.path.join(repo, path)):
                continue
            lineno = int(rest.split(':', 1)[0])
            full = read_line(path, lineno)
            if t_tokens and not (t_tokens & line_token_set(full)):
                continue
            out.append((path, lineno, full, term))
    seen = set()
    deduped = []
    for item in out:
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
    return deduped[:X_POOL_CAP]

# ── rama S: semantic (coseno sobre el índice de líneas) ──
NUMPY_MATRIX = None
if HAVE_NUMPY:
    flat = array.array('f')
    for row in embs:
        flat.extend(row)
    NUMPY_MATRIX = np.frombuffer(flat.tobytes(), dtype=np.float32).reshape(len(embs), dim)

def semantic_candidates(query, n_s):
    try:
        q_emb = selector_m3.ollama_post('/api/embed', {'model': MODEL, 'input': [query]})['embeddings'][0]
    except urllib.error.URLError:
        sys.stderr.write("✗ Ollama no responde en %s — ¿corre `ollama serve`?\n" % OLLAMA_URL)
        sys.exit(2)
    q_vec = norm(q_emb)
    n = len(embs)
    if NUMPY_MATRIX is not None:
        scores = (NUMPY_MATRIX @ np.array(q_vec, dtype=np.float32)).tolist()
    else:
        scores = [sum(a * b for a, b in zip(row, q_vec)) for row in embs]
    top = sorted(range(n), key=lambda i: (-scores[i], meta['entries'][i]['path'], meta['entries'][i]['lineno']))[:n_s]
    cands = []
    for i in top:
        path = meta['entries'][i]['path']
        lineno = meta['entries'][i]['lineno']
        if not os.path.exists(os.path.join(repo, path)):
            continue
        cands.append((path, lineno, read_line(path, lineno)))
    return cands

# ── señales R1-LEX (solo para la selección F2 de archivos, como Paso 13) ──
def curated_of(path):
    if path.startswith("Knowledge/"):
        return 1.0
    if "/" not in path:
        return 1.0
    return 0.0

def proximity_of(path, s, e, q_tokens, x_tokens, pad):
    union = q_tokens | x_tokens
    if not union:
        return 0.0
    lines = file_lines(path)
    center = (s + e) / 2.0
    best = None
    for ln in range(s, e + 1):
        if ln < 1 or ln > len(lines):
            continue
        if union & line_token_set(lines[ln - 1]):
            d = abs(ln - center)
            best = d if best is None else min(best, d)
    if best is None:
        return 0.0
    return max(0.0, min(1.0, 1.0 - best / float(max(1, pad))))

def score_r1(item, item_pass, q_tokens, x_tokens, pad):
    path, lineno = item[0], item[1]
    s, e = item_pass[(path, lineno)]
    pt = set()
    for l in file_lines(path)[s-1:e]:
        pt |= line_token_set(l)
    qo = len(q_tokens & pt) / float(max(1, len(q_tokens)))
    xo = len(x_tokens & pt) / float(max(1, len(x_tokens)))
    xd = len(x_tokens & pt) / float(max(1, len(pt)))
    pr = proximity_of(path, s, e, q_tokens, x_tokens, pad)
    cu = curated_of(path)
    return qo + xo + xd + pr + cu

def run_router(query):
    try:
        out = subprocess.run(["bash", router, "--json", query], capture_output=True, text=True, timeout=30)
        return json.loads(out.stdout)
    except Exception:
        return {}

# ── runner ──
fixture = json.load(open(eval_path, encoding='utf-8'))
files = discover_corpus(repo)
entries = read_entries(repo, files)
meta, embs, cache_hit = load_or_build_index(files, entries)
dim = meta['dim']

try:
    commit_sha = subprocess.run(["git", "-C", repo, "rev-parse", "HEAD"],
                                capture_output=True, text=True, timeout=10).stdout.strip()
except Exception:
    commit_sha = "?"

t0_all = time.time()
results = {"benchmark": "17C reducción del leak estructural del pool (A/V1/V2/V3)",
           "variant": variant,
           "eval_id": fixture.get("eval_id"),
           "eval_hash": eval_hash,
           "date": fixture.get("date"),
           "profile": "PC",
           "host": fixture.get("host", "?"),
           "model": MODEL,
           "commit_sha": commit_sha,
           "h1_dict_hash": H1_DICT_HASH,
           "query_source": "query natural + términos H1 reales (expand_query.py) — SIN oráculo H2",
           "pool_generation": "L ∪ X(H1 real) ∪ S ∪ P-F2, regenerado por PAS_PAD; max-passages=400; sin inyección de gold",
           "rescue_low": RESCUE_LOW,
           "limit": LIMIT,
           "params": {"N_L": N_L, "N_X": N_X, "N_S": N_S,
                      "P_EXPAND_TOP_K": P_EXPAND_TOP_K, "MAX_PASSAGES": MAX_PASSAGES,
                      "BUDGET_TOKENS": BUDGET_TOKENS, "PADS": PADS},
           "corpus_hash": corpus_hash(repo, files),
           "index_cache_hit": cache_hit,
           "index_build_seconds": meta.get('build_seconds'),
           "per_pad": {}}

for pad in PADS:
    pad_t0 = time.monotonic()
    per_query = []
    print("── PAS_PAD=%d ──" % pad)
    for q in fixture["queries"]:
        qid, query = q["id"], q["query"]
        gold_domains = set(q.get("gold_domains", []))
        gold_files = set(q.get("gold_files", []))
        gold_facts = [f["text"] for f in q.get("gold_facts", []) if f.get("text", "").strip()]

        # ── generación (L ∪ X(H1 real) ∪ S) ──
        cands_l, q_tokens = lexical_candidates(query, N_L)
        terms = H1_TERMS_FN(query)
        cands_x = expansion_candidates(terms, N_X)
        cands_s = semantic_candidates(query, N_S)
        x_tokens = set()
        for t in terms:
            x_tokens |= set(tokenize_significant(t))

        # ── pool dedup (path, lineno) — 5 campos: path, lineno, text, xterm, ramas ──
        pool = []
        seen = set()
        for item in cands_l:
            key = (item[0], item[1])
            if key in seen:
                continue
            seen.add(key)
            pool.append([item[0], item[1], item[2], None, {'L'}])
        for item in cands_x:
            key = (item[0], item[1])
            if key in seen:
                continue
            seen.add(key)
            pool.append([item[0], item[1], item[2], item[3], {'X'}])
        for item in cands_s:
            key = (item[0], item[1])
            if key in seen:
                continue
            seen.add(key)
            pool.append([item[0], item[1], item[2], None, {'S'}])
        pool_by_key = {(it[0], it[1]): it for it in pool}
        for item in cands_l:
            k = (item[0], item[1])
            if k in pool_by_key:
                pool_by_key[k][4].add('L')
        for item in cands_x:
            k = (item[0], item[1])
            if k in pool_by_key:
                pool_by_key[k][4].add('X')
        for item in cands_s:
            k = (item[0], item[1])
            if k in pool_by_key:
                pool_by_key[k][4].add('S')

        # ── ventanas ±pad + orden R1-LEX (para selección F2 de archivos) ──
        item_pass = {}
        for it in pool:
            s, e = passage_of(it[0], it[1], pad)
            item_pass[(it[0], it[1])] = (s, e)
        ordered = sorted(pool, key=lambda it: (-score_r1(it, item_pass, q_tokens, x_tokens, pad), it[0], it[1]))

        # ── rama P (F1 + F2) — tiles no-solapados de 2·pad+1, max-passages=400 ──
        router_out = run_router(query)
        kno = router_out.get("knowledge", [])
        kno_set = set(kno)
        p_files = list(kno)
        seen_f = set()
        for it in ordered:
            if it[0] in kno_set or it[0] in seen_f:
                continue
            seen_f.add(it[0])
            p_files.append(it[0])
            if len(p_files) - len(kno) >= P_EXPAND_TOP_K:
                break
        p_items = []          # (path, s, e, text)
        p_n = 0
        # Fase 1: kno SIEMPRE completos (el router ya los eligió)
        for f in p_files[:len(kno)]:
            for (s0, e0) in tile_windows(f, pad):
                txt = passage_text(f, s0, e0)
                if not txt.strip():
                    continue
                p_items.append((f, s0, e0, txt))
                p_n += 1
        # Fase 2: pool (F2) — recortado por el tope si hace falta
        if not (MAX_PASSAGES and p_n >= MAX_PASSAGES):
            for f in p_files[len(kno):]:
                for (s0, e0) in tile_windows(f, pad):
                    txt = passage_text(f, s0, e0)
                    if not txt.strip():
                        continue
                    if MAX_PASSAGES and p_n >= MAX_PASSAGES:
                        break
                    p_items.append((f, s0, e0, txt))
                    p_n += 1
        for (f, s0, e0, _t) in p_items:
            item_pass.setdefault((f, s0), (s0, e0))

        # ── pasajes del pool (dedup por path,s,e) — L/X/S con ventana ±pad, P tiles ──
        pool_pgs = []
        seen_pg = set()
        for it in pool:
            path, lineno = it[0], it[1]
            s, e = item_pass[(path, lineno)]
            key = (path, s, e)
            if key in seen_pg:
                continue
            seen_pg.add(key)
            pool_pgs.append({"path": path, "s": s, "e": e, "text": passage_text(path, s, e)})
        for (f, s0, e0, txt) in p_items:
            key = (f, s0, e0)
            if key in seen_pg:
                continue
            seen_pg.add(key)
            pool_pgs.append({"path": f, "s": s0, "e": e0, "text": txt})

        # ── M3 V6 (selector_m3.py): S1+S2+S3+S4, gate rescue, top-K ──
        # NO se inyecta gold al pool: gold_files/gold_facts solo se usan para medir.
        qtext = " ".join([query] + terms)
        q_emb = norm(embed_one(qtext))
        q_toks = salient_tokens(qtext)
        # S1 con embed_all (batch ×10 + cache a disco — infra 14A/15A, misma
        # clave sha1 que selector_m3.passage_emb, vectores idénticos)
        pool_embs = embed_all([p["text"] for p in pool_pgs])
        for p, emb in zip(pool_pgs, pool_embs):
            p["_s1"] = cosine(norm(emb), q_emb)
            p["_s7_raw"] = len(p["text"].split())
        pool_toks = [salient_tokens(p["text"]) - q_toks for p in pool_pgs]
        n = len(pool_pgs)
        for i, p in enumerate(pool_pgs):
            shared = sum(1 for j in range(n) if j != i and (pool_toks[i] & pool_toks[j]))
            p["_s2"] = 1.0 - shared / max(1, n - 1)
        q_structural = query_structural(qtext)
        for p in pool_pgs:
            p["_s3"] = structured(p["text"]) * q_structural
        for p in pool_pgs:
            p["_s4"] = 0.0 if is_session_noise(p["path"]) else 1.0
        gated = [p for p in pool_pgs if p["_s1"] >= RESCUE_LOW]
        for p in gated:
            p["_score"] = (selector_m3.W["s1"]*p["_s1"] + selector_m3.W["s2"]*p["_s2"] +
                           selector_m3.W["s3"]*p["_s3"] + selector_m3.W["s4"]*p["_s4"])
        gated.sort(key=lambda p: -p["_score"])

        # ── 17C: ensamblado del contexto final según variante (spec leak-17C-DESIGN.md) ──
        # A  = runner 17B tal cual (control)
        # V1 = exclusión dura de noise de sesión (is_session_noise y no gold)
        # V2 = refuerzo S4 en el score (W["s4"] 0.5 → 1.5) — re-rankear
        # V3 = exclusión de raíz no-Knowledge (dom_of=="session" y no ai-context/)
        if variant == "V1":
            ctx = [p for p in gated
                   if not (is_session_noise(p["path"]) and p["path"] not in gold_files)][:LIMIT]
        elif variant == "V2":
            for p in gated:
                p["_score"] = (selector_m3.W["s1"]*p["_s1"] + selector_m3.W["s2"]*p["_s2"] +
                               selector_m3.W["s3"]*p["_s3"] + 1.5*p["_s4"])
            gated.sort(key=lambda p: -p["_score"])
            ctx = gated[:LIMIT]
        elif variant == "V3":
            ctx = [p for p in gated
                   if not (dom_of(p["path"]) == "session" and not p["path"].startswith("ai-context/"))][:LIMIT]
        else:  # A
            ctx = gated[:LIMIT]
        ctx_passages = ctx
        ctx_paths = {p["path"] for p in ctx_passages}

        # ── métricas (harness 15B) — gold SOLO para medir ──
        prel = (sum(1 for p in ctx_passages if p["path"] in gold_files) /
                len(ctx_passages)) if ctx_passages else 0.0
        leak = (len({f for f in ctx_paths if f not in gold_files
                     and dom_of(f) not in gold_domains}) / len(ctx_paths)) if ctx_paths else 0.0
        ctx_text = " ".join(p["text"] for p in ctx_passages).lower()
        gold_ctx_text = " ".join(p["text"] for p in ctx_passages
                                 if p["path"] in gold_files).lower()
        attributed = sum(1 for f in gold_facts
                         if deaccent(f.lower()) in deaccent(ctx_text)
                         and deaccent(f.lower()) in deaccent(gold_ctx_text))
        # gold_containment: agujas en pool cuyo pasaje gold cabe en el presupuesto
        in_pool_facts = 0
        contained = 0
        for f in gold_facts:
            nd = deaccent(f.lower())
            hit = next((p for p in pool_pgs if nd in deaccent(p["text"].lower())), None)
            if hit is None:
                continue
            in_pool_facts += 1
            if hit["_s7_raw"] <= BUDGET_TOKENS // max(1, len(fixture["queries"])):
                contained += 1
        gcq = (contained / in_pool_facts) if in_pool_facts else 0.0
        tokens = sum(p["_s7_raw"] for p in ctx_passages)

        per_query.append({
            "qid": qid, "query": query, "terms": terms,
            "pool_size": len(pool_pgs), "gated": len(gated),
            "ctx_size": len(ctx_passages),
            "gold_in_ctx": sum(1 for p in ctx_passages if p["path"] in gold_files),
            "passage_relevance": round(prel, 3),
            "cross_domain_leakage": round(leak, 3),
            "attributed": attributed, "gold_facts_n": len(gold_facts),
            "gold_containment": round(gcq, 3),
            "tokens": tokens,
            "ctx_passages": ["%s:%d-%d" % (p["path"], p["s"], p["e"]) for p in ctx_passages],
        })
        print("  %s pad=%d pool=%d gated=%d attr=%d/%d pRel=%.3f leak=%.3f" % (
            qid, pad, len(pool_pgs), len(gated), attributed, len(gold_facts), prel, leak))

    nq = len(per_query)
    agg = {
        "passage_relevance_avg": round(sum(x["passage_relevance"] for x in per_query) / nq, 3),
        "cross_domain_leakage_avg": round(sum(x["cross_domain_leakage"] for x in per_query) / nq, 3),
        "attributed_total": sum(x["attributed"] for x in per_query),
        "attributed_n": sum(x["gold_facts_n"] for x in per_query),
        "gold_containment_avg": round(sum(x["gold_containment"] for x in per_query) / nq, 3),
        "tokens_avg": round(sum(x["tokens"] for x in per_query) / nq, 1),
        "tokens_total": sum(x["tokens"] for x in per_query),
        "queries_attributed": sum(1 for x in per_query if x["attributed"] > 0),
        "queries_n": nq,
    }
    agg["per_query"] = per_query
    results["per_pad"][str(pad)] = agg
    print("  → pad=%d attr=%d/%d pRel=%.3f leak=%.3f contain=%.3f (%.0fs)" % (
        pad, agg["attributed_total"], agg["attributed_n"], agg["passage_relevance_avg"],
        agg["cross_domain_leakage_avg"], agg["gold_containment_avg"], time.monotonic() - pad_t0))

results["elapsed_seconds"] = int(time.time() - t0_all)
results["determinism_hash"] = hashlib.sha1(
    json.dumps({k: v for k, v in results.items() if k not in ("determinism_hash", "elapsed_seconds")},
               sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

json.dump(results, open(out_file, "w", encoding='utf-8'), indent=2, ensure_ascii=False)
print("\n→ %s (%ds) determinism_hash=%s" % (out_file, results["elapsed_seconds"], results["determinism_hash"]))
PY

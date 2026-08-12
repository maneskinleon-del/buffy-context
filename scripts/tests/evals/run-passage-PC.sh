#!/usr/bin/env bash
# run-passage-PC.sh — Paso 9: experimento DIAGNÓSTICO de passage-level context
# selection (variantes G1=VENTANA, G2=SECCIÓN) sobre el EVAL PC.
#
# Responde: ¿cambiar la unidad de contexto de archivo completo a PASaje permite
# entregar el gold dentro del presupuesto (Q04/Q06: CHANGELOG.md de 14.4k tok no
# cabía como archivo; un pasaje de 300-500 tok sí), sin romper recall/leakage/coste?
#
# MISMO EVAL / MISMO gold definitivo / MISMO LIMIT / MISMAS métricas v3.1 que A-F.
# Cambia la UNIDAD de contexto final:
#
#   archivo completo (A-F)  →  pasaje (path:start-end)
#
# Pipeline:
#   rama L (léxica)   → buffy-search.sh OR top-50 + gate co-ocurrencia ≥2 tokens
#   rama S (semántica)→ índice bge-m3 cacheado de D (coseno, top-50)
#   pool dedup(L ∪ S) → fusión V1-RRF (k=60, principal; --fuse pool opcional)
#   top-10 → cada hit se expande a un PASAJE:
#     G1-VENTANA  → líneas [lineno-4, lineno+4] (9 líneas, recortado a límites)
#     G2-SECCIÓN  → bloque markdown entre headings ^#{1,3} (o archivo si no hay)
#   ctx = router ∪ pasajes(top-10), dedup por (path, rango), presupuesto 10.4k
#   → métricas v3.1 + passage_relevance + gold_containment + G-H0 adaptado
#
# NO toca el runtime: buffy-search.sh, buffy-router.sh y cap-selector congelados
# (se invocan SOLO como generadores / control).
#
# Uso:
#   run-passage-PC.sh [--variant ventana|seccion] [--fuse rrf|pool]
#                     [--model bge-m3] [--ollama URL] [--out FILE] [--limit N]
#                     [--reindex] [--json] [--quiet]
#   --variant ventana|seccion  granularidad del pasaje (default: ventana).
#                              CADA variante es un resultado experimental
#                              independiente (mismo gate para ambas, nunca se
#                              escoge después de ver el resultado).
#   --fuse    rrf|pool  fusión V1 (default: rrf — la principal del diseño)
#   --out     archivo de salida (default: baseline-<G1|G2>-passage-<variant>-PC-2026-08-11.json)
#   --limit   top-K final (default: 10, igual que A-F)
#   --reindex fuerza reconstrucción del índice semántico (ignora cache)
#   --json    además volcar el JSON a stdout
#   --quiet   no imprimir tabla
#
# Exit: 0 si la medición corre (es medición, no gate) · 2 error de uso/precondición.
# Precondiciones: `ollama serve` corriendo, `ollama pull bge-m3`, e índice
# semántico de D cacheado (~/.cache/buffy-eval-semantic/) — MISMO índice.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"

MODEL="bge-m3"
OLLAMA_URL="http://localhost:11434"
VARIANT="ventana"
FUSE="rrf"
OUT_FILE=""
JSON=false
QUIET=false
REINDEX=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant) VARIANT="${2:?falta ventana|seccion}"; shift 2 ;;
    --fuse) FUSE="${2:?falta rrf|pool}"; shift 2 ;;
    --model) MODEL="${2:?falta modelo}"; shift 2 ;;
    --ollama) OLLAMA_URL="${2:?falta URL}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta ruta}"; shift 2 ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --reindex) REINDEX=true; shift ;;
    --json) JSON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) sed -n '2,34p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

case "$VARIANT" in
  ventana|seccion) ;;
  *) echo "variante inválida: $VARIANT (ventana|seccion)" >&2; exit 2 ;;
esac
case "$FUSE" in
  rrf|pool) ;;
  *) echo "fusión inválida: $FUSE (rrf|pool)" >&2; exit 2 ;;
esac

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router (control)" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-search.sh" ]] || { echo "falta search (rama L)" >&2; exit 2; }

if [ -z "$OUT_FILE" ]; then
  LABEL="G1"; [ "$VARIANT" = "seccion" ] && LABEL="G2"
  OUT_FILE="$SCRIPT_DIR/baseline-$LABEL-passage-$VARIANT-PC-2026-08-11.json"
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-eval-semantic"
mkdir -p "$CACHE_DIR"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/passage.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(VARIANT="$VARIANT" FUSE="$FUSE" MODEL="$MODEL" OLLAMA_URL="$OLLAMA_URL" LIMIT="$LIMIT" REPO_DIR="$REPO_DIR" EVAL="$EVAL" TMP="$TMP" EVAL_HASH="$EVAL_HASH" CACHE_DIR="$CACHE_DIR" REINDEX="$REINDEX" QUIET="$QUIET" python3 - "$REPO_DIR" "$EVAL" "$TMP" "$VARIANT" "$FUSE" "$MODEL" "$OLLAMA_URL" "$LIMIT" "$EVAL_HASH" "$CACHE_DIR" "$REINDEX" <<'PY'
import json, os, re, subprocess, sys, time, urllib.request, urllib.error, hashlib, math, unicodedata, array

repo, eval_path, tmpdir, variant, fuse_mode, model, ollama_url, limit, eval_hash, cache_dir, reindex = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6],
    sys.argv[7], int(sys.argv[8]), sys.argv[9], sys.argv[10], sys.argv[11] == "true",
)
router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

# ── parámetros V1 (fijados ANTES de medir, sin calibrar con el EVAL) ──
N_L = 50           # candidatos léxicos (OR top-50 + gate)
N_S = 50           # candidatos semánticos (coseno top-50)
K_RRF = 60         # constante de Reciprocal Rank Fusion
PAS_PAD = 4        # G1-VENTANA: [lineno-4, lineno+4] → 9 líneas
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
    norm = deaccent(line).lower()
    norm = re.sub(r'[^a-z0-9 ]', ' ', norm)
    return set(norm.split())

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

# ── líneas de un archivo (cache) ──
LINE_CACHE = {}
def file_lines(path):
    if path not in LINE_CACHE:
        try:
            with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
                LINE_CACHE[path] = [l.rstrip('\n') for l in f]
        except OSError:
            LINE_CACHE[path] = []
    return LINE_CACHE[path]

# ── pasajes ──
HEAD_CACHE = {}
def section_of(path, lineno):
    """G2-SECCIÓN: rango (start, end) del bloque markdown que contiene lineno,
    delimitado por headings ^#{1,3} (exclusivo del próximo heading). Sin headings
    → archivo completo (fallback). Devuelve (start, end, fallback)."""
    lines = file_lines(path)
    total = len(lines)
    if total == 0:
        return 1, 0, True
    if path not in HEAD_CACHE:
        heads = [i + 1 for i, l in enumerate(lines) if re.match(r'^#{1,3} ', l)]
        HEAD_CACHE[path] = heads
    heads = HEAD_CACHE[path]
    if not heads:
        return 1, total, True
    start = heads[-1]
    for h in heads:
        if h <= lineno:
            start = h
        else:
            break
    end = total
    for h in heads:
        if h > start:
            end = h - 1
            break
    return start, end, False

def passage_of(path, lineno, variant):
    """Pasaje de un hit (path, lineno). Devuelve (start, end, fallback)."""
    if variant == 'seccion':
        return section_of(path, lineno)
    total = len(file_lines(path))
    start = max(1, lineno - PAS_PAD)
    end = min(total, lineno + PAS_PAD)
    return start, end, False

def passage_chars(path, start, end):
    lines = file_lines(path)
    if start < 1 or end > len(lines) or start > end:
        return 0
    return sum(len(l) + 1 for l in lines[start - 1:end])

def passage_text(path, start, end):
    lines = file_lines(path)
    if start < 1 or end > len(lines) or start > end:
        return ""
    return "\n".join(lines[start - 1:end])

def merge_ranges(ranges):
    """Une rangos solapados/adyacentes (path-local): [(s,e), ...] → lista dedup."""
    if not ranges:
        return []
    out = []
    for s, e in sorted(ranges):
        if out and s <= out[-1][1] + 1:
            out[-1] = (out[-1][0], max(out[-1][1], e))
        else:
            out.append((s, e))
    return out

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

# ── índice semántico: REUTILIZA el cache de D (MISMO índice) ──
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
            pass
    sys.stderr.write("✗ índice semántico de D no encontrado en %s\n" % cache_dir)
    sys.stderr.write("  El Paso 9 exige el MISMO índice que D. Ejecuta primero el Paso 7\n")
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

corpus_norm = [deaccent(t).lower() for t in (t for _, _, t in entries)]

per_query = []
router_p, router_r, multi_p, multi_r, srec, srec_other, srec_raw, crel, prel, leak, toks, toks_ff, goldc, lats = [], [], [], [], [], [], [], [], [], [], [], [], [], []
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
            continue
        seen.add(key)
        ranks[key] = {'L': None, 'S': len(pool) + 1}
        pool.append(item)
    for i, item in enumerate(cands_l):
        key = (item[0], item[1])
        ranks[key]['L'] = i + 1
    for i, item in enumerate(cands_s):
        key = (item[0], item[1])
        ranks[key]['S'] = i + 1

    # ── fusión → top-K de hits path:lineno ──
    reranked = fuse(pool, ranks, fuse_mode)
    top10 = reranked[:limit]

    # ── pasajes: expandir CADA hit del pool (para G-H0) y del top-10 (para ctx) ──
    # pasaje por ítem: (path, start, end, fallback)
    item_pass = {}
    for item in pool:
        path, lineno = item[0], item[1]
        s, e, fb = passage_of(path, lineno, variant)
        item_pass[(path, lineno)] = (s, e, fb)
    # pasajes del POOL (dedup por path:rango, rangos fusionados)
    pool_passages = []
    by_path = {}
    for (path, lineno), (s, e, fb) in item_pass.items():
        by_path.setdefault(path, []).append((s, e))
    for path in sorted(by_path):
        for (s, e) in merge_ranges(by_path[path]):
            pool_passages.append((path, s, e))
    # pasajes del TOP-10 (en orden de rerank; dedup por path:rango)
    top10_passages = []
    seen_pg = set()
    for item in top10:
        s, e, fb = item_pass[(item[0], item[1])]
        key = (item[0], s, e)
        if key in seen_pg:
            continue
        seen_pg.add(key)
        top10_passages.append((item[0], s, e))

    # ── hits finales (top-10 como pasajes, snippet_scope: passage) ──
    hits = ["%s:%d-%d: %s" % (p, s, e, passage_text(p, s, e)) for (p, s, e) in top10_passages]

    # ── contexto final: router ∪ pasajes(top-10) en orden de rerank, presupuesto ──
    # router: archivos COMPLETOS (mismo tratamiento que A-F) — bloquean pasajes
    # de esos archivos (redundantes). Pasajes del top-10: TODOS entran (dedup por
    # (path, rango) exacto), permitiendo múltiples pasajes del mismo archivo —
    # la spec §5.2 lo exige explícitamente.
    ctx_entries = []   # (path, rango_None_para_archivo, chars)
    chars_used = 0
    ctx_full_paths = set(kno)   # archivos completos (router) — bloquean pasajes
    seen_ranges = set()
    for f in sorted(kno):
        p = os.path.join(repo, f)
        size = os.path.getsize(p) if os.path.isfile(p) else 0
        ctx_entries.append((f, None, size))
        chars_used += size
    ctx_cut = 0
    for (p, s, e) in top10_passages:
        if p in ctx_full_paths:
            continue  # archivo completo ya en ctx (router) → pasaje redundante
        key = (p, s, e)
        if key in seen_ranges:
            continue  # rango exacto ya en ctx
        seen_ranges.add(key)
        size = passage_chars(p, s, e)
        if chars_used + size > BUDGET_CHARS:
            ctx_cut += 1
            continue
        ctx_entries.append((p, (s, e), size))
        chars_used += size
    ctx_paths = {p for p, _rng, _sz in ctx_entries}   # paths únicos del ctx (métricas file-level)
    ctx_entries_clean = [(p, rng) for (p, rng, _sz) in ctx_entries]

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

    # ── search_recall — needle en texto del PASAJE del top-10 (snippet_scope: passage) ──
    gold_facts_matches = []
    gold_matches = 0
    other_matches = 0
    hit_norm = []
    for hit in hits:
        hpath, rest = hit.split(':', 1)
        hit_norm.append((deaccent(rest).lower(), hpath))
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        gold_paths, other_paths = [], []
        for txt_n, hpath in hit_norm:
            if needle in txt_n:
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

    # ── G-H0 adaptado a pasajes (pool ANTERIOR al recorte de presupuesto) ──
    candidate_status = []
    pool_pg_norm = [(deaccent(passage_text(p, s, e)).lower(), p) for (p, s, e) in pool_passages]
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        in_top10 = any(needle in txt_n for txt_n, _ in hit_norm)
        if in_top10:
            st = "in_pool_top10"
            needle_in_corpus = True
        else:
            found = next((i for i, (txt_n, p) in enumerate(pool_pg_norm) if needle in txt_n), None)
            if found is None:
                needle_in_corpus = any(needle in c for c in corpus_norm)
                st = "not_in_corpus" if not needle_in_corpus else "out_of_pool"
            else:
                needle_in_corpus = True
                hit_path = pool_pg_norm[found][1]
                st = "in_pool_budget_cut" if hit_path not in ctx_paths else "in_pool_ranked_out"
        g_h0_counts[st] += 1
        candidate_status.append({"text": f["text"], "candidate_status": st,
                                 "needle_in_corpus": needle_in_corpus})

    # ── gold_containment: pasaje del gold cabe COMPLETO en el presupuesto ──
    # denominador = agujas in_pool_* (todas); numerador = las que su pasaje
    # (el del pool que la contiene) cabe en BUDGET_CHARS. Independiente del status.
    containment_per_fact = []
    in_pool_facts = 0
    contained_facts = 0
    for cs in candidate_status:
        if not cs["candidate_status"].startswith("in_pool"):
            containment_per_fact.append(None)
            continue
        in_pool_facts += 1
        needle = deaccent(cs["text"].lower())
        # pasaje del POOL que contiene la aguja (mismo pasaje del G-H0)
        idx = next((i for i, (txt_n, _p) in enumerate(pool_pg_norm) if needle in txt_n), None)
        if idx is None:
            containment_per_fact.append(0.0)
            continue
        p, s, e = pool_passages[idx]
        fits = 1.0 if passage_chars(p, s, e) <= BUDGET_CHARS else 0.0
        contained_facts += int(fits == 1.0)
        containment_per_fact.append(fits)
    gcq = (contained_facts / in_pool_facts) if in_pool_facts else 0.0
    goldc.append(gcq)

    # ── contexto: relevance / leakage / tokens (sobre ctx_entries) ──
    files_gold = gold_files
    ctx_path_set = {p for p, _ in ctx_entries_clean}
    # passage_relevance: fracción de pasajes del ctx (excl. router full-file) con path gold
    passages_in_ctx = [(p, rng) for (p, rng) in ctx_entries_clean if rng is not None]
    prel_q = (sum(1 for p, _ in passages_in_ctx if p in files_gold) / len(passages_in_ctx)) if passages_in_ctx else 0.0
    # context_relevance (file-level, v3.1, incluye router): diagnóstico secundario
    crel_q = len(ctx_path_set & files_gold) / len(ctx_path_set) if ctx_path_set else 0.0
    leak_q = len({f for f in ctx_path_set if f not in files_gold and dom_of(f) not in gold_domains}) / len(ctx_path_set) if ctx_path_set else 0.0
    crel.append(crel_q); prel.append(prel_q); leak.append(leak_q)

    ctx_chars = chars_used
    tok_q = ctx_chars // 4
    toks.append(tok_q)
    # tokens_if_fullfile: mismos archivos del ctx como archivo completo (métrica secundaria)
    ff_chars = 0
    for f in ctx_path_set:
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            ff_chars += os.path.getsize(p)
    toks_ff.append(ff_chars // 4)
    lats.append(latency)

    section_fallbacks = sum(1 for (path, lineno) in ((it[0], it[1]) for it in pool) if passage_of(path, lineno, variant)[2])

    per_query.append({
        "id": qid, "query": query, "coverage": q.get("coverage"),
        "strategy": "passage", "variant": variant, "fuse": fuse_mode,
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
            "pool_stats": {"L": len(cands_l), "S": len(cands_s), "total": len(pool),
                           "passages_pool": len(pool_passages), "passages_top10": len(top10_passages),
                           "ctx_cut": ctx_cut, "section_fallbacks": section_fallbacks},
            "cooccurrence_stats": {"query_tokens": sorted(q_tokens), "hits_before_gate": hits_before, "hits_after_gate": hits_after},
        },
        "passage_relevance": round(prel_q, 3),
        "context_relevance": round(crel_q, 3),
        "cross_domain_leakage": round(leak_q, 3),
        "gold_containment": round(gcq, 3),
        "gold_containment_per_fact": containment_per_fact,
        "context_estimated_tokens": tok_q,
        "tokens_if_fullfile": ff_chars // 4,
        "latency_ms": latency,
        "search_hit_paths": sorted({p for p, _, _ in top10_passages}),
        # rangos que REALMENTE entraron al ctx (no los top-10 pre-budget)
        "ctx_passage_ranges": [(p, "%d-%d" % (s, e)) for (p, (s, e)) in
                               [(p, rng) for (p, rng) in ctx_entries_clean if rng is not None]],
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

label = {"ventana": "G1", "seccion": "G2"}[variant]
variant_name = {"ventana": "VENTANA ±%d" % PAS_PAD, "seccion": "SECCIÓN markdown"}[variant]
pipeline_desc = (
    "buffy-router.sh (control) → L: buffy-search.sh OR top-%d + gate ≥2 tokens → "
    "S: %s coseno top-%d → pool dedup(%d∪%d) → fusión V1-%s → top-%d → pasajes (%s) "
    "→ presupuesto %d tokens sobre pasajes → ctx"
) % (N_L, model, N_S, N_L, N_S, "RRF (k=60)" if fuse_mode == "rrf" else "POOL (rank⁻¹)", limit,
     variant_name, BUDGET_TOKENS)

summary = {
    "baseline": label,
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": eval_hash,
    "strategy": "passage",
    "variant": variant,
    "fuse": fuse_mode,
    "model": model,
    "instrument_version": "v3.1",
    "pipeline": pipeline_desc,
    "snippet_scope": "passage",
    "runtime_changed": False,
    "params": {"N_L": N_L, "N_S": N_S, "K_RRF": K_RRF if fuse_mode == "rrf" else None,
               "PAS_PAD": PAS_PAD, "budget_tokens": BUDGET_TOKENS, "limit": limit},
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
        "passage_relevance_avg": round(sum(prel)/n, 3),
        "context_relevance_avg": round(sum(crel)/n, 3),
        "cross_domain_leakage_avg": round(sum(leak)/n, 3),
        "gold_containment_avg": round(sum(goldc)/n, 3),
        "total_spurious_categories": sum(len(q["spurious_categories"]) for q in per_query),
        "token_cost": agg("token_cost", toks),
        "tokens_if_fullfile_avg": round(sum(toks_ff)/n, 3),
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

out = os.path.join(tmpdir, "passage.json")
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
print("── Variante %s — passage-level context selection (perfil PC, %s, pasajes %s, instrumento v3.1) ──" % (label, d.get("model", "?"), d.get("variant", "?")))
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s · queries: %d · índice: %s archivos / %s líneas / dim %s (cache %s)" % (
    d["runtime_changed"], d["num_queries"], idx.get("files"), idx.get("lines"), idx.get("dim"),
    "sí" if idx.get("cache_hit") else "no"))
print("  params: N_L=%s N_S=%s pad=%s budget=%s · snippet_scope: %s · determinism_hash: %s (gate G2)" % (
    par.get("N_L"), par.get("N_S"), par.get("PAS_PAD"), par.get("budget_tokens"),
    d.get("snippet_scope"), d.get("determinism_hash")))
print("  ── agregado ──")
print("  router_precision_avg:    %s  (control, Δ=0 esperado)" % a["router_precision_avg"])
print("  router_recall_avg:       %s" % a["router_recall_avg"])
print("  categories_recall_avg:   %s" % a["categories_recall_avg"])
print("  search_recall_avg:       %s  (solo gold_file_match)" % a["search_recall_avg"])
print("  search_other_recall_avg: %s  (diagnóstico)" % a["search_other_recall_avg"])
print("  search_recall_raw_avg:   %s  (gold+other)" % a["search_recall_raw_avg"])
print("  passage_relevance_avg:   %s  ★ NUEVA (pasaje-level)" % a["passage_relevance_avg"])
print("  context_relevance_avg:   %s  (file-level, diagnóstico)" % a["context_relevance_avg"])
print("  cross_domain_leakage_avg:%s" % a["cross_domain_leakage_avg"])
print("  gold_containment_avg:    %s  ★ NUEVA (pasaje del gold cabe en presupuesto)" % a["gold_containment_avg"])
print("  spurious_categories:     %s" % a["total_spurious_categories"])
print("  token_cost:              %s (media) / p95 %s   [no comparable con A-F]" % (a["token_cost"]["avg"], a["token_cost"].get("p95")))
print("  tokens_if_fullfile_avg:  %s   (métrica secundaria, misma base que A-F)" % a["tokens_if_fullfile_avg"])
print("  latency_ms:              %s (media) / p95 %s" % (a["latency_ms"]["avg"], a["latency_ms"].get("p95")))
print("  window_utilization:      %s (200k)" % a["window_utilization_avg"])
gh = a.get("g_h0", {})
print("  G-H0 (por aguja gold):   %s" % " · ".join("%s=%s" % (k, v) for k, v in gh.items()))
print("  ── por query ──")
print("  %-4s %-7s %-7s %-7s %-7s %-8s %-7s %-7s %-8s %-8s %-8s" % ("ID", "rPrec", "rRec", "sRec", "sOth", "pRel", "cRel", "leak", "gCont", "tok", "latMs"))
for q in d["per_query"]:
    print("  %-4s %-7s %-7s %-7s %-7s %-8s %-7s %-7s %-8s %-8s %-8s" % (
        q["id"], q["router_precision"], q["router_recall"], q["search_recall"],
        q["search_other_recall"], q["passage_relevance"], q["context_relevance"],
        q["cross_domain_leakage"], q["gold_containment"], q["context_estimated_tokens"], q["latency_ms"]))
print("  ── G-H0 por query (Q03/Q06/Q08 y resto) ──")
for q in d["per_query"]:
    sts = [f"{x['candidate_status']}" for x in q["g_h0"]["candidate_status"]]
    print("  %-4s %s" % (q["id"], ", ".join(sts)))
# comparación contra baselines A-F si existen — prioriza instrumento v3/v3.1 sobre v2
base_map = {"A": None, "B": None, "C": None, "D": None, "E": None, "F": None}
base_inst = {}
def _inst_rank(v):
    return 0 if not v else (1 if v.startswith("v2") else (2 if v.startswith("v3") else 3))
for f in os.listdir(sys.argv[2]):
    if f.startswith("baseline-") and f.endswith(".json") and "passage" not in f:
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
    for k in ("A", "B", "C", "D", "E", "F"):
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

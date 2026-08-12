#!/usr/bin/env bash
# run-expansion-PC.sh — Paso 10: experimento DIAGNÓSTICO de query expansion
# (variantes H1=DICT-MIN realista, H2=DICT-FULL techo/oráculo) sobre el EVAL PC.
#
# Responde: ¿generar términos alternativos de la consulta hace aparecer candidatos
# que hoy están FUERA del pool (candidate gap Q03/Q01/Q05/Q10), sin romper lo que
# passage-level ya logró (G1: coste ~2.6k, recall 0.417, Q04/Q06 entregados)?
#
# Evidencia previa (medida antes de diseñar): las 6 agujas out_of_pool de G1 son
# TODAS needle_in_corpus=True y TODAS recuperables por buffy-search.sh -l 50 con
# el término expandido correcto (gh pr create→Commands.md:64 top-3, adb tcpip→
# ADB.md:14, useState→React.md:26, dumpsys thermalservice→GameOptimization.md:62…).
# El gap es de REPRESENTACIÓN de la consulta, no de ausencia ni de ranking.
#
# MISMO EVAL / MISMO gold / MISMO LIMIT / MISMAS métricas v3.1 que A-G1.
# Misma unidad de contexto que G1 (pasajes VENTANA ±4, dedup path:rango).
# Cambia UNA cosa: la rama léxica L se enriquece con la rama X (re-consultas por
# término del diccionario). La expansión es ADITIVA (L y S se conservan).
#
# Pipeline:
#   rama L (léxica)   → buffy-search.sh OR top-50 (query original) + gate ≥2 tokens
#   rama X (expansión)→ por cada término t del diccionario (H1 o H2):
#                        buffy-search.sh OR top-50 "t" + gate ≥1 token significativo
#   rama S (semántica)→ índice bge-m3 cacheado de D (coseno, top-50)
#   pool dedup(L ∪ X ∪ S) → fusión V1-RRF (k=60) → top-10 → pasajes VENTANA ±4
#   ctx = router ∪ pasajes(top-10), dedup (path, rango), presupuesto 10.4k
#   → métricas v3.1 + passage_relevance + gold_containment + G-H0 (con origen
#     rama/término) + candidate_gap_recovery + métrica de regresión vs G1
#
# Restricciones (de la spec aprobada): H2 es TECNO/oráculo — jamás candidato de
# adopción. Diccionarios congelados en el runner (hash calculado en el JSON).
# Sin tocar runtime. Sin reranker nuevo. Sin calibración. NO implementar 10B.
#
# Uso:
#   run-expansion-PC.sh [--dict h1|h2] [--fuse rrf|pool] [--model bge-m3]
#                       [--ollama URL] [--out FILE] [--limit N] [--reindex]
#                       [--json] [--quiet]
#   --dict h1|h2  diccionario de expansión (default: h1). CADA variante es un
#                 resultado experimental independiente (mismo gate para ambas).
#   --fuse    rrf|pool  fusión V1 (default: rrf)
#   --out     archivo de salida (default: baseline-H1|H2-expansion-PC-2026-08-12.json)
#   --limit   top-K final (default: 10)
#   --json    además volcar el JSON a stdout
#   --quiet   no imprimir tabla
#
# Exit: 0 si la medición corre · 2 error de uso/precondición.
# Precondiciones: ollama serve, bge-m3, índice semántico de D cacheado, y el JSON
# de G1 (referencia para candidate_gap_recovery / regresión) en el mismo dir.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"
G1_REF="$SCRIPT_DIR/baseline-G1-passage-ventana-PC-2026-08-11.json"

MODEL="bge-m3"
OLLAMA_URL="http://localhost:11434"
DICT="h1"
FUSE="rrf"
OUT_FILE=""
JSON=false
QUIET=false
REINDEX=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dict) DICT="${2:?falta h1|h2}"; shift 2 ;;
    --fuse) FUSE="${2:?falta rrf|pool}"; shift 2 ;;
    --model) MODEL="${2:?falta modelo}"; shift 2 ;;
    --ollama) OLLAMA_URL="${2:?falta URL}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta ruta}"; shift 2 ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --reindex) REINDEX=true; shift ;;
    --json) JSON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) sed -n '2,44p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

case "$DICT" in
  h1|h2) ;;
  *) echo "diccionario inválido: $DICT (h1|h2)" >&2; exit 2 ;;
esac
case "$FUSE" in
  rrf|pool) ;;
  *) echo "fusión inválida: $FUSE (rrf|pool)" >&2; exit 2 ;;
esac

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -f "$G1_REF" ]] || { echo "falta referencia G1 (candidate_gap_recovery): $G1_REF" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router (control)" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-search.sh" ]] || { echo "falta search (rama L/X)" >&2; exit 2; }

if [ -z "$OUT_FILE" ]; then
  LABEL="H1"; [ "$DICT" = "h2" ] && LABEL="H2"
  OUT_FILE="$SCRIPT_DIR/baseline-$LABEL-expansion-PC-2026-08-12.json"
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-eval-semantic"
mkdir -p "$CACHE_DIR"

TMP=$(mktemp -d "${TMPDIR:-/tmp}/expansion.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(DICT="$DICT" FUSE="$FUSE" MODEL="$MODEL" OLLAMA_URL="$OLLAMA_URL" LIMIT="$LIMIT" REPO_DIR="$REPO_DIR" EVAL="$EVAL" G1_REF="$G1_REF" TMP="$TMP" EVAL_HASH="$EVAL_HASH" CACHE_DIR="$CACHE_DIR" REINDEX="$REINDEX" QUIET="$QUIET" python3 - "$REPO_DIR" "$EVAL" "$G1_REF" "$TMP" "$DICT" "$FUSE" "$MODEL" "$OLLAMA_URL" "$LIMIT" "$EVAL_HASH" "$CACHE_DIR" "$REINDEX" <<'PY'
import json, os, re, subprocess, sys, time, urllib.request, urllib.error, hashlib, math, unicodedata, array

repo, eval_path, g1_ref, tmpdir, dict_mode, fuse_mode, model, ollama_url, limit, eval_hash, cache_dir, reindex = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7],
    sys.argv[8], int(sys.argv[9]), sys.argv[10], sys.argv[11], sys.argv[12] == "true",
)
router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

# ── parámetros V1 (fijados ANTES de medir, sin calibrar con el EVAL) ──
N_L = 50            # candidatos léxicos (OR top-50 + gate)
N_X = 50            # candidatos por término de expansión (top-50 por re-consulta)
N_S = 50            # candidatos semánticos (coseno top-50)
K_RRF = 60          # constante de Reciprocal Rank Fusion
PAS_PAD = 4         # G1-VENTANA: [lineno-4, lineno+4] → 9 líneas
BUDGET_TOKENS = 10400   # ~2× A (5 197) ≈ 10.4k, gate del usuario
BUDGET_CHARS = BUDGET_TOKENS * 4
X_POOL_CAP = 200    # tope de ítems X únicos por query (declarado, no calibrado)

# ────────────────────────────────────────────────────────────────────────────
# DICCIONARIOS (congelados ANTES de medir; hash en el JSON para detectar edits)
#
# H1-DICT-MIN (realista): reglas de traducción ES→técnico GENÉRICAS aplicadas a
# los tokens significativos de la query. No contiene comandos/símbolos exactos.
# Es la señal realista: ¿una expansión razonable puede cerrar el gap?
#
# H2-DICT-FULL (techo/oráculo): H1 + términos exactos del dominio de buffy-context
# por query. JAMÁS candidato de adopción — solo mide el límite superior.
# ────────────────────────────────────────────────────────────────────────────

DICT_H1 = {  # palabra_es (deaccent, lowercase) → términos de expansión
    "crear": ["create", "make", "new", "add"],
    "pushear": ["push"],
    "commit": ["commit"],
    "pull": ["pull", "pull request"],
    "request": ["request", "pull request"],
    "conectar": ["connect", "adb connect"],
    "conecte": ["connect", "adb connect"],
    "aparece": ["list", "show", "device", "adb devices"],
    "aparecer": ["list", "show", "device", "adb devices"],
    "permisos": ["permission", "grant", "pm grant"],
    "permiso": ["permission", "grant", "pm grant"],
    "concedo": ["grant", "pm grant"],
    "shizuku": ["shizuku", "rish"],
    "app": ["application", "package"],
    "aplicacion": ["application", "package"],
    "pantalla": ["screen", "display"],
    "apaga": ["off", "disable", "dpms"],
    "apagar": ["off", "disable", "dpms"],
    "minutos": [],
    "componente": ["component"],
    "serial": ["serial", "devices"],
    "celular": ["phone", "device", "adb"],
    "anda": ["slow", "performance"],
    "lento": ["slow", "performance"],
    "hacer": [],
    "puedo": [],
    "terminal": ["terminal"],
    "opaca": ["transparent", "opacity"],
    "transparente": ["transparent", "opacity"],
    "opaco": ["transparent", "opacity"],
    "ve": ["view", "show"],
    "vea": ["view", "show"],
    "rendimiento": ["performance", "governor"],
    "optimizar": ["optimize", "performance", "governor"],
    "calienta": ["thermal", "temperature"],
    "caliente": ["thermal", "temperature"],
    "juego": ["game", "free fire"],
    "juega": ["game", "free fire"],
    "script": ["script", "sh"],
    "abre": ["launch", "open", "start"],
    "abrir": ["launch", "open", "start"],
    "revisa": ["check", "log", "status"],
    "revisar": ["check", "log", "status"],
    "celular": ["phone", "device", "adb"],
    "quiere": [],
    "quiero": [],
    "leer": ["read", "get", "serial"],
    "necesita": [],
    "necesito": [],
    "sin": [],
    "root": ["root"],
    "raiz": ["root"],
    "free": ["free fire"],
    "fire": ["free fire"],
    "pr": ["pull request", "pr"],
    "le": [],
    "por": [],
    "despues": [],
    "unos": [],
    "sola": [],
    "de": [],
}

# términos exactos del dominio por query (SOLO H2 — techo informativo/oráculo)
DICT_H2_EXTRA = {
    "Q01": ["adb tcpip", "adb connect", "tcpip", "adb devices"],
    "Q02": ["rish -c", "moe.shizuku.privileged.api", "pm grant", "shizuku"],
    "Q03": ["gh pr create", "git push origin", "pr create", "pull request", "crear pr"],
    "Q04": ["xset -dpms", "xset s off", "dpms", "blanking"],
    "Q05": ["useState", "use state", "hooks", "adb devices -l", "serial"],
    "Q06": ["FF_SEEN", "free fire", "watchdog", "scrcpy"],
    "Q07": ["dumpsys", "thermal", "governor", "force gpu rendering", "gpu rendering"],
    "Q08": ["picom", "compositor", "opacity", "transparent"],
    "Q09": ["scaling governor", "governor", "performance", "gpu rendering"],
    "Q10": ["dumpsys thermalservice", "thermal control", "temperatura", "thermal"],
}

def dict_hash():
    return hashlib.sha1(json.dumps({"h1": DICT_H1, "h2_extra": DICT_H2_EXTRA},
                                   sort_keys=True, ensure_ascii=False).encode()).hexdigest()[:16]

def expansion_terms(qid, query):
    """Términos de la rama X para la query. H1: reglas genéricas sobre tokens
    significativos. H2: H1 + términos exactos por query (oráculo declarado)."""
    terms = []
    seen = set()
    for tok in tokenize_significant(query):
        for t in DICT_H1.get(tok, []):
            if t and t not in seen:
                seen.add(t)
                terms.append(t)
    if dict_mode == "h2":
        for t in DICT_H2_EXTRA.get(qid, []):
            if t not in seen:
                seen.add(t)
                terms.append(t)
    return terms

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

LINE_CACHE = {}
def file_lines(path):
    if path not in LINE_CACHE:
        try:
            with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
                LINE_CACHE[path] = [l.rstrip('\n') for l in f]
        except OSError:
            LINE_CACHE[path] = []
    return LINE_CACHE[path]

def passage_of(path, lineno):
    """G1-VENTANA: [lineno-4, lineno+4] → 9 líneas (recortado a límites)."""
    total = len(file_lines(path))
    start = max(1, lineno - PAS_PAD)
    end = min(total, lineno + PAS_PAD)
    return start, end

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
    sys.stderr.write("  El Paso 10 exige el MISMO índice que D. Ejecuta primero el Paso 7\n")
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

# ── rama L: lexical (OR top-50 + gate co-ocurrencia ≥2 tokens) — idéntica a G1 ──
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

# ── rama X: expansión léxica (una re-consulta por término del diccionario) ──
def expansion_candidates(terms, n_x):
    """Para cada término t → buffy-search.sh OR top-50 → gate: hit contiene ≥1
    token significativo de t (si t no tiene tokens significativos, pasa el top-50
    tal cual). Devuelve (path, lineno, text, term, rank_global) + latencia."""
    t0 = time.monotonic()
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
            # gate: ≥1 token significativo del término (o sin tokens → pasa)
            if t_tokens and not (t_tokens & line_token_set(full)):
                continue
            out.append((path, lineno, full, term))
    # dedup por (path, lineno) conservando el primer término (orden de consulta)
    seen = set()
    deduped = []
    for item in out:
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
    hits_raw = len(out)
    capped = max(0, len(deduped) - X_POOL_CAP)
    # tope pool X (declarado): cap 200 ítems únicos por query
    deduped = deduped[:X_POOL_CAP]
    return deduped, (time.monotonic() - t0) * 1000, hits_raw, capped

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

# ── fusión V1 con 3 ramas (L, X, S) ──
def fuse(pool, ranks, variant):
    scored = []
    for item in pool:
        key = (item[0], item[1])
        r = ranks[key]
        if variant == 'rrf':
            s = 0.0
            for rama in ('L', 'X', 'S'):
                if r.get(rama) is not None:
                    s += 1.0 / (K_RRF + r[rama])
        else:  # pool
            s = 0.0
            for rama in ('L', 'X', 'S'):
                if r.get(rama) is not None:
                    s += 1.0 / r[rama]
        scored.append((s, item))
    scored.sort(key=lambda x: (-x[0], x[1][0], x[1][1]))
    return [it for _, it in scored]

# ── referencia G1: status por aguja (candidate_gap_recovery + regresión) ──
def g1_status_map():
    d = json.load(open(g1_ref, encoding='utf-8'))
    out = {}
    for q in d['per_query']:
        for cs in q['g_h0']['candidate_status']:
            out[(q['id'], cs['text'])] = cs['candidate_status']
    return out

G1_MAP = g1_status_map()

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
x_stats = {"terms_total": 0, "terms_by_query": {}, "hits_raw": 0, "hits_unique": 0, "capped": 0}
gap_recovered, gap_denom, reg_stayed, reg_denom = [], [], [], []
gap_origins = []

for q in fixture["queries"]:
    qid, query = q["id"], q["query"]
    gold_domains = set(q.get("gold_domains", []))
    gold_files = set(q.get("gold_files", []))
    gold_facts = q.get("gold_facts", [])

    r, lat_router = run_router(query)
    cats = r.get("categories", [])
    kno = r.get("knowledge", [])

    # ── generación de candidatos (tres ramas independientes) ──
    cands_l, lat_l, q_tokens, hits_before, hits_after = lexical_candidates(query, N_L)
    terms = expansion_terms(qid, query)
    cands_x, lat_x, hits_raw_x, capped_x = expansion_candidates(terms, N_X)
    cands_s, lat_s = semantic_candidates(query, N_S)
    latency = round(lat_router + lat_l + lat_x + lat_s, 1)
    x_stats["terms_total"] += len(terms)
    x_stats["terms_by_query"][qid] = len(terms)
    x_stats["hits_raw"] += hits_raw_x
    x_stats["hits_unique"] += len(cands_x)
    x_stats["capped"] += capped_x

    # ── pool dedup por (path, lineno); L primero (tiebreak de estabilidad, no peso) ──
    pool = []
    seen = set()
    ranks = {}
    for i, item in enumerate(cands_l):
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        ranks[key] = {'L': len(pool) + 1, 'X': None, 'S': None}
        pool.append((item[0], item[1], item[2], None))
    for i, item in enumerate(cands_x):
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        ranks[key] = {'L': None, 'X': len(pool) + 1, 'S': None}
        pool.append((item[0], item[1], item[2], item[3]))
    for i, item in enumerate(cands_s):
        key = (item[0], item[1])
        if key in seen:
            continue
        seen.add(key)
        ranks[key] = {'L': None, 'X': None, 'S': len(pool) + 1}
        pool.append((item[0], item[1], item[2], None))
    for i, item in enumerate(cands_l):
        key = (item[0], item[1])
        ranks[key]['L'] = i + 1
    for i, item in enumerate(cands_x):
        key = (item[0], item[1])
        ranks[key]['X'] = i + 1
    for i, item in enumerate(cands_s):
        key = (item[0], item[1])
        ranks[key]['S'] = i + 1

    # ── fusión → top-K de hits path:lineno ──
    reranked = fuse(pool, ranks, fuse_mode)
    top10 = reranked[:limit]

    # ── pasajes: pool (para G-H0) y top-10 (para ctx) ──
    item_pass = {}
    for item in pool:
        path, lineno = item[0], item[1]
        s, e = passage_of(path, lineno)
        item_pass[(path, lineno)] = (s, e)
    pool_passages = []
    by_path = {}
    for (path, lineno), (s, e) in item_pass.items():
        by_path.setdefault(path, []).append((s, e))
    for path in sorted(by_path):
        for (s, e) in merge_ranges(by_path[path]):
            pool_passages.append((path, s, e))
    top10_passages = []
    seen_pg = set()
    for item in top10:
        s, e = item_pass[(item[0], item[1])]
        key = (item[0], s, e)
        if key in seen_pg:
            continue
        seen_pg.add(key)
        top10_passages.append((item[0], s, e))

    hits = ["%s:%d-%d: %s" % (p, s, e, passage_text(p, s, e)) for (p, s, e) in top10_passages]

    # ── contexto final: router ∪ pasajes(top-10), presupuesto ──
    ctx_entries = []
    chars_used = 0
    ctx_full_paths = set(kno)
    seen_ranges = set()
    for f in sorted(kno):
        p = os.path.join(repo, f)
        size = os.path.getsize(p) if os.path.isfile(p) else 0
        ctx_entries.append((f, None, size))
        chars_used += size
    ctx_cut = 0
    for (p, s, e) in top10_passages:
        if p in ctx_full_paths:
            continue
        key = (p, s, e)
        if key in seen_ranges:
            continue
        seen_ranges.add(key)
        size = passage_chars(p, s, e)
        if chars_used + size > BUDGET_CHARS:
            ctx_cut += 1
            continue
        ctx_entries.append((p, (s, e), size))
        chars_used += size
    ctx_paths = {p for p, _rng, _sz in ctx_entries}
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

    # ── search_recall — needle en texto del PASAJE del top-10 ──
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

    # ── G-H0 adaptado (pasajes) con ORIGEN rama/término ──
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
        # origen: si esta aguja estaba out_of_pool en G1 y ahora es in_pool_*, ¿quién la generó?
        origin = None
        prev = G1_MAP.get((qid, f["text"]))
        if prev == "out_of_pool" and st.startswith("in_pool"):
            # atribuir el ítem del pool cuyo PASAJE (ventana ±4 del ítem) contiene
            # la aguja — consistente con cómo se deriva el status (G-H0 sobre
            # pasajes), no sobre la línea individual.
            src = None
            for item in reranked:
                s, e = item_pass[(item[0], item[1])]
                if needle in deaccent(passage_text(item[0], s, e)).lower():
                    src = item
                    break
            if src is not None:
                key = (src[0], src[1])
                ramas = [r for r in ('L', 'X', 'S') if ranks[key].get(r) is not None]
                origin = {"rama": ramas, "term": src[3],
                          "path": src[0], "lineno": src[1],
                          "rank_fusion": reranked.index(src) + 1}
                gap_origins.append({"query": qid, "needle": f["text"],
                                    "status_g1": prev, "status_h": st, "origin": origin})
        candidate_status.append({"text": f["text"], "candidate_status": st,
                                 "needle_in_corpus": needle_in_corpus,
                                 "status_g1": prev, "origin": origin})

        # candidate_gap_recovery + regresión (por aguja, agregados al final)
        if prev == "out_of_pool":
            gap_denom.append((qid, f["text"]))
            gap_recovered.append(1 if st.startswith("in_pool") else 0)
        if prev == "in_pool_top10":
            reg_denom.append((qid, f["text"]))
            reg_stayed.append(1 if st == "in_pool_top10" else 0)

    # ── gold_containment (pasaje del gold cabe completo en el presupuesto) ──
    containment_per_fact = []
    in_pool_facts = 0
    contained_facts = 0
    for cs in candidate_status:
        if not cs["candidate_status"].startswith("in_pool"):
            containment_per_fact.append(None)
            continue
        in_pool_facts += 1
        needle = deaccent(cs["text"].lower())
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

    # ── contexto: relevance / leakage / tokens ──
    files_gold = gold_files
    ctx_path_set = {p for p, _ in ctx_entries_clean}
    passages_in_ctx = [(p, rng) for (p, rng) in ctx_entries_clean if rng is not None]
    prel_q = (sum(1 for p, _ in passages_in_ctx if p in files_gold) / len(passages_in_ctx)) if passages_in_ctx else 0.0
    crel_q = len(ctx_path_set & files_gold) / len(ctx_path_set) if ctx_path_set else 0.0
    leak_q = len({f for f in ctx_path_set if f not in files_gold and dom_of(f) not in gold_domains}) / len(ctx_path_set) if ctx_path_set else 0.0
    crel.append(crel_q); prel.append(prel_q); leak.append(leak_q)

    tok_q = chars_used // 4
    toks.append(tok_q)
    ff_chars = 0
    for f in ctx_path_set:
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            ff_chars += os.path.getsize(p)
    toks_ff.append(ff_chars // 4)
    lats.append(latency)

    per_query.append({
        "id": qid, "query": query, "coverage": q.get("coverage"),
        "strategy": "expansion", "dict": dict_mode, "fuse": fuse_mode,
        "gold_domains": sorted(gold_domains),
        "router_categories": cats,
        "categories_recall": round(cats_recall, 3),
        "spurious_categories": spurious,
        "router_precision": round(rp, 3),
        "router_recall": round(rr, 3),
        "gold_files": sorted(gold_files),
        "router_knowledge": kno,
        "gold_in_router": sorted(gold_in_router),
        "expansion_terms": terms,
        "search_top_n": len(hits),
        "search_recall": round(sr, 3),
        "search_other_recall": round(sr_other, 3),
        "search_recall_raw": round(sr_raw, 3),
        "gold_facts_matches": gold_facts_matches,
        "g_h0": {
            "candidate_status": candidate_status,
            "pool_stats": {"L": len(cands_l), "X": len(cands_x), "S": len(cands_s),
                           "total": len(pool), "passages_pool": len(pool_passages),
                           "passages_top10": len(top10_passages), "ctx_cut": ctx_cut},
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

label = {"h1": "H1", "h2": "H2"}[dict_mode]
dict_name = {"h1": "DICT-MIN (reglas ES→EN genéricas)", "h2": "DICT-FULL (H1 + términos exactos del dominio — TECNO/oráculo)"}[dict_mode]
pipeline_desc = (
    "buffy-router.sh (control) → L: buffy-search.sh OR top-%d + gate ≥2 tokens → "
    "X: buffy-search.sh OR top-%d por término del diccionario %s + gate ≥1 token → "
    "S: %s coseno top-%d → pool dedup(L∪X∪S) → fusión V1-%s → top-%d → pasajes "
    "VENTANA ±%d → presupuesto %d tokens → ctx"
) % (N_L, N_X, dict_name, model, N_S, "RRF (k=60)" if fuse_mode == "rrf" else "POOL (rank⁻¹)",
     limit, PAS_PAD, BUDGET_TOKENS)

gap_recovery_frac = round(sum(gap_recovered) / len(gap_recovered), 3) if gap_recovered else None
reg_frac = round(sum(reg_stayed) / len(reg_stayed), 3) if reg_stayed else None

summary = {
    "baseline": label,
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": eval_hash,
    "strategy": "expansion",
    "dict": dict_mode,
    "dict_name": dict_name,
    "dict_hash": dict_hash(),
    "fuse": fuse_mode,
    "model": model,
    "instrument_version": "v3.1",
    "pipeline": pipeline_desc,
    "snippet_scope": "passage",
    "runtime_changed": False,
    "params": {"N_L": N_L, "N_X": N_X, "N_S": N_S, "K_RRF": K_RRF if fuse_mode == "rrf" else None,
               "PAS_PAD": PAS_PAD, "budget_tokens": BUDGET_TOKENS, "limit": limit,
               "X_POOL_CAP": X_POOL_CAP},
    "reference_g1": os.path.basename(g1_ref),
    "index_stats": {"files": len(files), "lines": len(entries), "dim": dim,
                    "cache_hit": cache_hit, "build_seconds": meta.get('build_seconds')},
    "expansion_stats": x_stats,
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
        "candidate_gap_recovery": {"fraction": gap_recovery_frac, "recovered": sum(gap_recovered),
                                   "denominator": len(gap_denom), "per_needle": gap_origins},
        "regression_vs_g1": {"stayed_in_top10_fraction": reg_frac,
                             "stayed": sum(reg_stayed), "denominator": len(reg_denom)},
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

out = os.path.join(tmpdir, "expansion.json")
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
print("── Variante %s — query expansion (%s) · perfil PC · pasajes VENTANA · instrumento v3.1 ──" % (label, d.get("dict_name", "?")))
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s · queries: %d · dict_hash: %s · determinism_hash: %s (gate G2)" % (
    d["runtime_changed"], d["num_queries"], d.get("dict_hash"), d.get("determinism_hash")))
print("  índice: %s archivos / %s líneas / dim %s (cache %s)" % (idx.get("files"), idx.get("lines"), idx.get("dim"), "sí" if idx.get("cache_hit") else "no"))
print("  expansión: %s términos · %s hits únicos X · pool cap %s" % (
    d["expansion_stats"]["terms_total"], d["expansion_stats"]["hits_unique"], par.get("X_POOL_CAP")))
print("  ── agregado ──")
print("  router_precision_avg:    %s  (control)" % a["router_precision_avg"])
print("  router_recall_avg:       %s" % a["router_recall_avg"])
print("  search_recall_avg:       %s  (solo gold_file_match)" % a["search_recall_avg"])
print("  search_other_recall_avg: %s  (diagnóstico)" % a["search_other_recall_avg"])
print("  passage_relevance_avg:   %s" % a["passage_relevance_avg"])
print("  context_relevance_avg:   %s  (file-level)" % a["context_relevance_avg"])
print("  cross_domain_leakage_avg:%s" % a["cross_domain_leakage_avg"])
print("  gold_containment_avg:    %s" % a["gold_containment_avg"])
print("  token_cost:              %s (media) / p95 %s" % (a["token_cost"]["avg"], a["token_cost"].get("p95")))
print("  tokens_if_fullfile_avg:  %s" % a["tokens_if_fullfile_avg"])
print("  latency_ms:              %s (media) / p95 %s" % (a["latency_ms"]["avg"], a["latency_ms"].get("p95")))
gh = a.get("g_h0", {})
print("  G-H0 (por aguja gold):   %s" % " · ".join("%s=%s" % (k, v) for k, v in gh.items()))
cgr = a.get("candidate_gap_recovery", {})
print("  candidate_gap_recovery:  %s (%s/%s)  ★ objetivo del paso" % (
    cgr.get("fraction"), cgr.get("recovered"), cgr.get("denominator")))
reg = a.get("regression_vs_g1", {})
print("  regresión vs G1 (top10): %s (%s/%s)" % (reg.get("stayed_in_top10_fraction"), reg.get("stayed"), reg.get("denominator")))
print("  ── por query ──")
print("  %-4s %-7s %-7s %-7s %-7s %-8s %-7s %-7s %-8s %-8s %-8s" % ("ID", "rPrec", "rRec", "sRec", "sOth", "pRel", "cRel", "leak", "gCont", "tok", "latMs"))
for q in d["per_query"]:
    print("  %-4s %-7s %-7s %-7s %-7s %-8s %-7s %-7s %-8s %-8s %-8s" % (
        q["id"], q["router_precision"], q["router_recall"], q["search_recall"],
        q["search_other_recall"], q["passage_relevance"], q["context_relevance"],
        q["cross_domain_leakage"], q["gold_containment"], q["context_estimated_tokens"], q["latency_ms"]))
print("  ── G-H0 por query (status → status_g1 · origen) ──")
for q in d["per_query"]:
    for cs in q["g_h0"]["candidate_status"]:
        org = ""
        if cs.get("origin"):
            org = " ← %s%s" % (",".join(cs["origin"]["rama"]), " via '%s'" % cs["origin"]["term"] if cs["origin"].get("term") else "")
        if cs.get("status_g1") != cs["candidate_status"] or cs.get("origin"):
            print("  %-4s %-26s G1:%-18s → %s%s" % (q["id"], cs["text"][:26], cs.get("status_g1"), cs["candidate_status"], org))
# comparación contra baselines — prioriza instrumento v3/v3.1
base_map = {"A": None, "B": None, "C": None, "D": None, "E": None, "F": None, "G1": None, "G2": None}
base_inst = {}
def _inst_rank(v):
    return 0 if not v else (1 if v.startswith("v2") else (2 if v.startswith("v3") else 3))
for f in os.listdir(sys.argv[2]):
    if f.startswith("baseline-") and f.endswith(".json") and "expansion" not in f:
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
    for k in ("A", "B", "C", "D", "E", "F", "G1", "G2"):
        bd = base_map[k]
        if not bd:
            continue
        ba = bd["aggregate"]
        extra = ""
        if k in ("G1", "G2"):
            extra = "  pRel=%s gCont=%s" % (ba.get("passage_relevance_avg"), ba.get("gold_containment_avg"))
        print("  %-4s %-8s %-10s %-8s %-8s %-8s%s" % (k, ba["search_recall_avg"], ba["context_relevance_avg"],
              ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95"), extra))
    ba = d["aggregate"]
    print("  %-4s %-8s %-10s %-8s %-8s %-8s  pRel=%s gCont=%s" % (label, ba["search_recall_avg"], ba["context_relevance_avg"],
          ba["cross_domain_leakage_avg"], ba["token_cost"]["avg"], ba["token_cost"].get("p95"),
          ba.get("passage_relevance_avg"), ba.get("gold_containment_avg")))
PY
fi

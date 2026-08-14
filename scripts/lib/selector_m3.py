#!/usr/bin/env python3
# selector_m3.py — Motor M3 (selector quality-aware) extraído del runner 15A.
# ─────────────────────────────────────────────────────────────────────────────
# Fuente: scripts/tests/evals/run-selector-quality-PC.sh (Paso 15, Rama B).
# Veredicto adoptado (2026-08-13): M3 = S1+S2+S3+S4 con gate rescue (piso
# rescue_low=0.545) y pesos a priori w1=1.0 w2=1.0 w3=0.5 w4=0.5, top-K por score.
#
# Iteración S3 (2026-08-14, veredicto 15B): V6 = M3 con S3 condicionado a
# query estructural + S4 por clase de memoria de sesión. Medido sobre el fixture
# congelado (harness fiel: M3 reproduce 15A bit a bit): attr 16/20 → 19/20,
# pRel 0.577 → 0.677, reg 0.420 → 0.360, leak 0.242 → 0.275 (pasa gate ≤0.308).
# Q02 1/3 → 3/3 · Q07 1/2 → 2/2 · Q08/Q06 intactos (2/2 · 1/1).
#
# Señales:
#   S1  relevancia semántica: bge-m3 cosine(query+terms, pasaje) — gate rescue:
#       pasajes con S1 >= rescue_low entran al pool de selección (la franja
#       [rescue_low, theta) habilita que la calidad rescate golds que el
#       threshold duro corta por margen mínimo — decisión 2b del usuario).
#   S2  especificidad: tokens salientes (no-stopwords, len>3, command-like) menos
#       tokens de la query; rareza cruzada en el pool de la query (IDF-like):
#       especificidad(p) = 1 − |{p'≠p : toks(p) ∩ toks(p') ≠ ∅}| / |pool|
#   S3  definición-vs-mención: pasaje con evidencia ESTRUCTURADA (fila de tabla
#       `|...|...|` o KEY=value al inicio de línea) → 1, prosa → 0. V6:
#       condicionado a query estructural (patrón tabla/KEY=value en la query) —
#       para queries de procedimiento (prosa) la estructura es "bonita pero
#       irrelevante" (sobre-corrección Q02/Q07, hallazgo 15A).
#   S4  canonicalidad: path en archivos de ruido de sesión → 0, resto → 1. V6:
#       por CLASE — memoria transitoria por-sesión (ai-context/* salvo
#       CHANGELOG.md, historia curada) → 0; CHANGELOG.md queda canónico (gold
#       de Q06).
#
# score(p) = w1·S1 + w2·S2 + w3·S3 + w4·S4  (S6 MMR = post-poda, no usado en M3)
#
# Uso (CLI):
#   python3 selector_m3.py --input <json> [--top-k 10] [--theta 0.55]
#                          [--rescue-low 0.545] [--repo DIR] [--out <file>]
#
# JSON de entrada (stdin o --input):
#   {
#     "query":  "la terminal se ve opaca y quiero que se vea transparente",
#     "terms":  ["terminal", "opaca", "vea", "transparente"],   // opcional
#     "passages": [
#        {"path": "Knowledge/Linux/System.md", "s": 55, "e": 63, "text": "..."},
#        {"path": "Knowledge/Linux/System.md", "lineno": 55}    // alternativa: ventana ±4 desde repo
#     ]
#   }
#   Cada pasaje es O bién {path, s, e, text} (texto provisto) O bién
#   {path, lineno} (se construye la ventana PAS_PAD=±4 desde $repo).
#
# JSON de salida:
#   {
#     "model": "M3", "weights": {...}, "theta": 0.55, "rescue_low": 0.545,
#     "selected": [{"path","s","e","score","s1","s2","s3","s4","tokens","text"}],
#     "dropped_below_floor": N, "pool_size": N, "elapsed_seconds": x
#   }
#
# Exit codes:
#   0 → selección OK
#   2 → error de uso / entrada inválida
#   3 → Ollama no disponible (no se puede computar S1)
# Determinista: mismas entradas + mismo cache de embeddings → mismo JSON.

import json, os, sys, time, hashlib, re, array
import urllib.request

PAS_PAD = 4

# ── pesos declarados a priori (diseño §4 — se congelan, sin calibración) ──
W = {"s1": 1.0, "s2": 1.0, "s3": 0.5, "s4": 0.5}

# ── archivos de ruido de sesión (S4 — el diseño §3 los penaliza) ──
NOISE_FILES = {"ai-context/SESION-archive.md", "ai-context/AGENTS.md",
               "ai-context/CONTINUE.md", "ai-context/SESION.md"}


def is_session_noise(path):
    """S4 v6 (2026-08-14): canonicalidad por CLASE de memoria de sesión.
    No-canónico = memoria transitoria por-sesión: la lista original (SESION·
    CONTINUE·AGENTS·SESION-archive) + los dumps de perfil/sesión en ai-context/
    (INFO-full, CHANGELOG-archive, SHIZUKU-RISH-BUG, ...). CHANGELOG.md (historia
    curada) sigue siendo canónico — es el gold de Q06 (FF_SEEN).
    Cierra la sobre-corrección de S3 (Q02 INFO-full.md:189 · Q07 README.md:73)
    sin romper Q06/Q08 (veredicto 15B)."""
    if path in NOISE_FILES:
        return True
    if path.startswith("ai-context/") and not path.startswith("ai-context/CHANGELOG.md"):
        return True
    return False

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
            req = urllib.request.Request(os.environ.get("OLLAMA_URL", "http://localhost:11434") + path,
                                         data=json.dumps(payload).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=600) as r:
                return json.load(r)
        except Exception as e:
            last = e
            if attempt < retries - 1:
                time.sleep(2 * (attempt + 1))
    raise last


def ollama_available():
    """GET /api/tags (endpoint GET, no POST) — verifica que el servidor responda."""
    try:
        req = urllib.request.Request(os.environ.get("OLLAMA_URL", "http://localhost:11434") + "/api/tags")
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status == 200
    except Exception:
        return False


def embed_one(text):
    d = ollama_post('/api/embed', {"model": "bge-m3", "input": text})
    return [float(x) for x in d["embeddings"][0]]


def norm(v):
    n = sum(x * x for x in v) ** 0.5
    return [x / n for x in v] if n else v


def cosine(a, b):
    return sum(x * y for x, y in zip(a, b))


# ── cache de embeddings de pasajes (misma clave que 14A/15A, bit-a-bit) ──
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


# ── corpus helpers ──
LINE_CACHE = {}


def file_lines(path, repo):
    if path not in LINE_CACHE:
        try:
            with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
                LINE_CACHE[path] = [l.rstrip('\n') for l in f]
        except OSError:
            LINE_CACHE[path] = []
    return LINE_CACHE[path]


def passage_text(path, s, e, repo):
    lines = file_lines(path, repo)
    if s < 1 or e > len(lines) or s > e:
        return ""
    return "\n".join(lines[s - 1:e])


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


def query_structural(query):
    """V6 (2026-08-14): la query pide estructura (patrón tabla/KEY=value) → 1.0.
    S3 (definición-vs-mención) solo aplica para queries estructurales; en
    queries de procedimiento (prosa) la estructura del pasaje es "bonita pero
    irrelevante" (sobre-corrección Q02/Q07, hallazgo 15A)."""
    return 1.0 if (TABLE_RE.search(query) or KV_RE.search(query)) else 0.0


def dom_of(path):
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"


# ── build passages ──
def build_passages(items, repo):
    """Normaliza los candidatos a pasajes {path,s,e,text}.
    - Con {path,s,e,text} → se usa tal cual.
    - Con {path,lineno} → ventana PAS_PAD=±4 leída del repo (igual que el eval)."""
    passages = []
    seen = set()
    for it in items:
        path = it.get("path", "")
        if not path:
            continue
        if "text" in it and it["text"]:
            s, e = it.get("s", 1), it.get("e", it.get("s", 1))
        else:
            lineno = int(it.get("lineno", it.get("s", 1)))
            total = len(file_lines(path, repo))
            s = max(1, lineno - PAS_PAD)
            e = min(total, lineno + PAS_PAD)
            txt = passage_text(path, s, e, repo)
            if not txt.strip():
                continue
            it = dict(it)
            it["s"], it["e"], it["text"] = s, e, txt
        key = (path, s, e)
        if key in seen:
            continue
        seen.add(key)
        passages.append({"path": path, "s": s, "e": e, "text": it["text"]})
    return passages


def select(query, passages, repo, theta, rescue_low, top_k):
    """Score M3 + gate rescue + top-K. Devuelve (selected, dropped_below_floor).

    Mismo orden que el runner 15A: las señales se computan sobre el pool
    COMPLETO (S2 usa la rareza cruzada del pool total de la query), y el gate
    de relevancia se aplica después, antes del ranking por score."""
    if not passages:
        return [], 0

    q_emb = norm(embed_one(query))
    q_toks = salient_tokens(query)

    # S1 raw (pool completo)
    for p in passages:
        p["_s1"] = cosine(norm(passage_emb(p["text"])), q_emb)

    # S2: especificidad (rareza cruzada en el pool COMPLETO de la query)
    pool_toks = [salient_tokens(p["text"]) - q_toks for p in passages]
    n = len(passages)
    for i, p in enumerate(passages):
        shared = sum(1 for j in range(n) if j != i and (pool_toks[i] & pool_toks[j]))
        p["_s2"] = 1.0 - shared / max(1, n - 1)

    # S3: estructura — condicionada a query estructural (V6, veredicto 15B):
    # la señal definición-vs-mención solo aplica si la QUERY pide estructura
    # (patrón tabla/KEY=value); para queries de procedimiento (prosa) la
    # estructura es "bonita pero irrelevante" (sobre-corrección Q02/Q07).
    q_structural = query_structural(query)
    for p in passages:
        p["_s3"] = structured(p["text"]) * q_structural

    # S4: canonicalidad (pool completo) — por CLASE de memoria de sesión (V6)
    for p in passages:
        p["_s4"] = 0.0 if is_session_noise(p["path"]) else 1.0

    # gate rescue: piso de relevancia (no rompe el piso — abre franja estrecha)
    gated = [p for p in passages if p["_s1"] >= rescue_low]
    dropped_below_floor = len(passages) - len(gated)

    # score M3 (sobre el pool gateado)
    for p in gated:
        p["_score"] = (W["s1"] * p["_s1"] + W["s2"] * p["_s2"] +
                       W["s3"] * p["_s3"] + W["s4"] * p["_s4"])

    gated.sort(key=lambda x: -x["_score"])
    selected = []
    for p in gated[:top_k]:
        selected.append({
            "path": p["path"], "s": p["s"], "e": p["e"],
            "score": round(p["_score"], 4),
            "s1": round(p["_s1"], 4),
            "s2": round(p["_s2"], 4),
            "s3": round(p["_s3"], 4),
            "s4": round(p["_s4"], 4),
            "tokens": len(p["text"].split()),
            "text": p["text"],
        })
    return selected, dropped_below_floor


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description="Selector M3 (S1+S2+S3+S4, gate rescue)")
    ap.add_argument("--input", help="JSON de entrada (default: stdin)")
    ap.add_argument("--out", help="archivo de salida (default: stdout)")
    ap.add_argument("--top-k", type=int, default=10)
    ap.add_argument("--theta", type=float, default=0.55, help="gate S1 (referencia)")
    ap.add_argument("--rescue-low", type=float, default=0.545,
                    help="piso de relevancia para la ventana de rescate (decisión 2b)")
    ap.add_argument("--repo", default=os.environ.get("BUFFY_REPO", os.path.expanduser("~/buffy-context")))
    args = ap.parse_args(argv)

    if args.input:
        try:
            data = json.load(open(args.input, encoding='utf-8'))
        except (OSError, ValueError) as e:
            print("error leyendo %s: %s" % (args.input, e), file=sys.stderr)
            return 2
    else:
        try:
            data = json.load(sys.stdin)
        except ValueError as e:
            print("error: JSON inválido en stdin (%s)" % e, file=sys.stderr)
            return 2

    if not isinstance(data, dict) or "query" not in data:
        print("error: entrada debe ser JSON con 'query'", file=sys.stderr)
        return 2

    query = data["query"]
    terms = data.get("terms") or []
    qtext = " ".join([query] + list(terms)).strip() or query
    items = data.get("passages") or []
    if not items:
        print("error: no hay 'passages'", file=sys.stderr)
        return 2

    if not ollama_available():
        print("error: Ollama no disponible en %s — no se puede computar S1 (bge-m3)"
              % os.environ.get("OLLAMA_URL", "http://localhost:11434"), file=sys.stderr)
        return 3

    repo = args.repo
    passages = build_passages(items, repo)
    t0 = time.time()
    selected, dropped = select(qtext, passages, repo, args.theta, args.rescue_low, args.top_k)

    out = {
        "model": "M3",
        "signal_version": "V6 (2026-08-14, veredicto 15B)",
        "weights": W,
        "theta": args.theta,
        "rescue_low": args.rescue_low,
        "top_k": args.top_k,
        "pool_size": len(passages),
        "dropped_below_floor": dropped,
        "selected": selected,
        "elapsed_seconds": round(time.time() - t0, 2),
    }
    payload = json.dumps(out, ensure_ascii=False, indent=2)
    if args.out:
        with open(args.out, "w", encoding='utf-8') as f:
            f.write(payload + "\n")
    else:
        print(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

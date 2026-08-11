#!/usr/bin/env bash
# run-baseline-PC.sh — baseline del plan EVAL del perfil PC (Paso 2: A; Paso 3: B).
#
# Mide el pipeline ACTUAL del sistema contra el EVAL congelado:
#
#   USER REQUEST → buffy-router.sh (real) → categoría → knowledge files
#                → buffy-search.sh (real, FTS5 BM25)
#
# SIN modificar nada del runtime (router/search/selector/Hybrid NO se tocan).
# Es medición pura sobre el repo real (~/buffy-context). Los resultados se
# registran como baseline del perfil PC — NO se comparan con Termux.
#
# Métricas (contrato bench-realistic-DESIGN.md §3):
#   router_precision/recall · multi_domain_precision/recall · search_recall
#   context_relevance · token_cost (media+p95) · latency (media+p95)
#   cross_domain_leakage
#   (además categories_recall y spurious_categories, específicas del EVAL)
#
# Uso:
#   run-baseline-PC.sh [--strategy and|or] [--out FILE] [--limit N] [--json] [--quiet]
#   --strategy and → baseline A (default, replica del Paso 2)
#   --strategy or  → baseline B (Paso 3: BUFFY_SEARCH_STRATEGY=or)
#   --out FILE     → archivo de salida (default: baseline-<estrategia>-PC-*.json)
#   --quiet        → no imprimir tabla (solo "registrada en ...")
#   --json         → además volcar el JSON a stdout
# Exit: 0 siempre que la medición corra (es medición, no gate).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="8e42d119bf7bc4f2014e7239f101e3c37296365f3b24158e0cb0155baaa67f5d"

STRATEGY="and"
OUT_FILE=""
JSON=false
QUIET=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strategy) STRATEGY="${2:?falta and|or}"; shift 2 ;;
    --out) OUT_FILE="${2:?falta ruta}"; shift 2 ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --json) JSON=true; shift ;;
    --quiet) QUIET=true; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

case "$STRATEGY" in
  and|or) ;;
  *) echo "estrategia inválida: $STRATEGY (and|or)" >&2; exit 2 ;;
esac

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-search.sh" ]] || { echo "falta search" >&2; exit 2; }

if [ -z "$OUT_FILE" ]; then
  OUT_FILE="$SCRIPT_DIR/baseline-$STRATEGY-PC-2026-08-11.json"
fi

TMP=$(mktemp -d "${TMPDIR:-/tmp}/baseline$STRATEGY.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(STRATEGY="$STRATEGY" LIMIT="$LIMIT" REPO_DIR="$REPO_DIR" EVAL="$EVAL" TMP="$TMP" EVAL_HASH="$EVAL_HASH" python3 - "$REPO_DIR" "$EVAL" "$TMP" "$STRATEGY" "$LIMIT" "$EVAL_HASH" <<'PY'
import json, os, subprocess, sys, time, unicodedata, statistics

repo, eval_path, tmpdir, strategy, limit, eval_hash = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), sys.argv[6]
router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

def deaccent(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def dom_of(path):
    # dominio = carpeta bajo Knowledge/ ("Knowledge/Android/x.md" → "Android")
    # archivos de sesión/raíz → "session" (nunca está en gold_domains → leakage si entra)
    if path.startswith("Knowledge/"):
        parts = path.split("/")
        return parts[1] if len(parts) > 2 else "root"
    return "session"

def run_router(q):
    t0 = time.monotonic()
    try:
        out = subprocess.run(["bash", router, "--json", q], capture_output=True, text=True, timeout=30)
        return json.loads(out.stdout), (time.monotonic() - t0) * 1000
    except Exception as e:
        return {"error": str(e)}, 0.0

def run_search(q):
    t0 = time.monotonic()
    env = dict(os.environ, BUFFY_SEARCH_STRATEGY=strategy)
    try:
        out = subprocess.run(["bash", search, "-l", str(limit), q],
                             capture_output=True, text=True, timeout=60, env=env)
        lines = [l for l in out.stdout.splitlines() if ':' in l]
        return lines, (time.monotonic() - t0) * 1000
    except Exception as e:
        return [f"ERROR: {e}"], 0.0

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

fixture = json.load(open(eval_path))
per_query = []
router_p, router_r, multi_p, multi_r, srec, crel, leak, toks, lats = [], [], [], [], [], [], [], [], []

for q in fixture["queries"]:
    qid, query = q["id"], q["query"]
    gold_domains = set(q.get("gold_domains", []))
    gold_files = set(q.get("gold_files", []))
    gold_facts = q.get("gold_facts", [])

    r, lat_router = run_router(query)
    cats = r.get("categories", [])
    kno = r.get("knowledge", [])
    skills = r.get("skills", [])

    hits, lat_search = run_search(query)
    hits = [h for h in hits if valid_hit(h)]
    latency = round(lat_router + lat_search, 1)

    # ── router ──
    router_kno_set = set(kno)
    gold_in_router = router_kno_set & gold_files
    rp = len(gold_in_router) / len(router_kno_set) if router_kno_set else 0.0
    rr = len(gold_in_router) / len(gold_files) if gold_files else 0.0
    cats_recall = len(gold_domains & set(cats)) / len(gold_domains) if gold_domains else 0.0
    spurious = sorted(set(cats) - gold_domains)
    router_p.append(rp); router_r.append(rr)
    if len(gold_domains) >= 2:
        multi_p.append(rp); multi_r.append(rr)

    # ── search ──
    hit_text = deaccent(" ".join(h[2] for h in [hit_parts(x) for x in hits] if h)).lower()
    found = 0
    found_facts = []
    for f in gold_facts:
        if deaccent(f["text"].lower()) in hit_text:
            found += 1
            found_facts.append(f["text"])
    sr = found / len(gold_facts) if gold_facts else 0.0
    srec.append(sr)

    # ── contexto final ctx_q = router ∪ topK (dedup) ──
    hit_paths = {p for p, _, _ in [hit_parts(x) for x in hits] if p}
    ctx = router_kno_set | hit_paths
    files_gold = gold_files
    crel_q = len(ctx & files_gold) / len(ctx) if ctx else 0.0
    leak_q = len({f for f in ctx if dom_of(f) not in gold_domains}) / len(ctx) if ctx else 0.0
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
        "strategy": strategy,
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
        "gold_facts_found": found_facts,
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
    "baseline": "B" if strategy == "or" else "A",
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": eval_hash,
    "strategy": strategy,
    "pipeline": "buffy-router.sh (real) → buffy-search.sh FTS5 bm25 (estrategia '%s', limit=%d)" % (strategy, limit),
    "runtime_changed": False,
    "num_queries": n,
    "aggregate": {
        "router_precision_avg": round(sum(router_p)/n, 3) if router_p else "n/a",
        "router_recall_avg": round(sum(router_r)/n, 3) if router_r else "n/a",
        "multi_domain_precision": agg("m", multi_p, multi=True),
        "multi_domain_recall": agg("m", multi_r, multi=True),
        "categories_recall_avg": round(sum([q["categories_recall"] for q in per_query])/n, 3),
        "search_recall_avg": round(sum(srec)/n, 3),
        "context_relevance_avg": round(sum(crel)/n, 3),
        "cross_domain_leakage_avg": round(sum(leak)/n, 3),
        "total_spurious_categories": sum(len(q["spurious_categories"]) for q in per_query),
        "token_cost": agg("token_cost", toks),
        "latency_ms": agg("latency_ms", lats),
        "window_utilization_avg": round((sum(toks)/n)/200000, 5),
    },
    "per_query": per_query,
}

out = os.path.join(tmpdir, "baseline.json")
json.dump(summary, open(out, "w"), indent=2, ensure_ascii=False)
print(out)
PY
)"

cp "$RESULT_FILE" "$OUT_FILE"

if [ "$JSON" = true ]; then
  cat "$RESULT_FILE"
fi
if [ "$QUIET" = false ]; then
  python3 - "$RESULT_FILE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
a = d["aggregate"]
print("── Baseline %s — perfil PC (eval-ctx-PC-2026-08-11, estrategia '%s') ──" % (d["baseline"], d["strategy"]))
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s · queries: %d" % (d["runtime_changed"], d["num_queries"]))
print("  ── agregado ──")
print("  router_precision_avg:    %s" % a["router_precision_avg"])
print("  router_recall_avg:       %s" % a["router_recall_avg"])
print("  categories_recall_avg:   %s" % a["categories_recall_avg"])
print("  search_recall_avg:       %s" % a["search_recall_avg"])
print("  context_relevance_avg:   %s" % a["context_relevance_avg"])
print("  cross_domain_leakage_avg:%s" % a["cross_domain_leakage_avg"])
print("  spurious_categories:     %s" % a["total_spurious_categories"])
print("  token_cost:              %s (media) / p95 %s" % (a["token_cost"]["avg"], a["token_cost"].get("p95")))
print("  latency_ms:              %s (media) / p95 %s" % (a["latency_ms"]["avg"], a["latency_ms"].get("p95")))
print("  window_utilization:      %s (200k)" % a["window_utilization_avg"])
print("  multi_domain_precision:  %s (n=%s)" % (a["multi_domain_precision"]["avg"], a["multi_domain_precision"]["n"]))
print("  multi_domain_recall:     %s (n=%s)" % (a["multi_domain_recall"]["avg"], a["multi_domain_recall"]["n"]))
print("  ── por query ──")
print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-8s" % ("ID", "rPrec", "rRec", "sRec", "cRel", "leak", "tok", "latMs"))
for q in d["per_query"]:
    print("  %-4s %-7s %-7s %-7s %-7s %-7s %-7s %-8s" % (
        q["id"], q["router_precision"], q["router_recall"], q["search_recall"],
        q["context_relevance"], q["cross_domain_leakage"], q["context_estimated_tokens"], q["latency_ms"]))
PY
fi
echo "baseline $STRATEGY registrada en $OUT_FILE"

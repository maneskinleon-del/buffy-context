#!/usr/bin/env bash
# run-baseline-PC.sh — Paso 2 (baseline A) del plan EVAL del perfil PC.
#
# Mide el pipeline ACTUAL del sistema contra el EVAL congelado:
#
#   USER REQUEST → buffy-router.sh (real) → categoría → knowledge files
#                → buffy-search.sh (real, FTS5 BM25, estrategia 'and' default)
#
# SIN modificar nada del runtime (router/search/selector/Hybrid NO se tocan).
# Es medición pura sobre el repo real (~/buffy-context). Los resultados se
# registran como baseline A del perfil PC — NO se comparan con Termux.
#
# Salida:
#   --json              → JSON completo (stdout) + copia en baseline-A-PC-*.json
#   (default)           → tabla legible + resumen
#
# Exit: 0 siempre que la medición corra (es medición, no gate).
# Uso:
#   bash scripts/tests/evals/run-baseline-PC.sh [--json] [--limit N]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
OUT_FILE="$SCRIPT_DIR/baseline-A-PC-2026-08-11.json"

JSON=false
LIMIT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=true; shift ;;
    --limit) LIMIT="${2:?falta número}"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$EVAL" ]] || { echo "falta fixture: $EVAL" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-router.sh" ]] || { echo "falta router" >&2; exit 2; }
[[ -x "$REPO_DIR/scripts/buffy-search.sh" ]] || { echo "falta search" >&2; exit 2; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/baselineA.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

RESULT_FILE="$(python3 - "$REPO_DIR" "$EVAL" "$TMP" "$LIMIT" <<'PY'
import json, os, subprocess, sys, unicodedata

repo, eval_path, tmpdir, limit = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
router = os.path.join(repo, "scripts/buffy-router.sh")
search = os.path.join(repo, "scripts/buffy-search.sh")

def deaccent(s):
    return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')

def run_router(q):
    try:
        out = subprocess.run(["bash", router, "--json", q], capture_output=True, text=True, timeout=30)
        return json.loads(out.stdout)
    except Exception as e:
        return {"error": str(e)}

def run_search(q):
    try:
        out = subprocess.run(["bash", search, "-l", str(limit), q],
                             capture_output=True, text=True, timeout=60)
        return [l for l in out.stdout.splitlines() if ':' in l]
    except Exception as e:
        return [f"ERROR: {e}"]

def valid_hit(hit):
    # formato válido: "path:lineno: snippet" con path que existe en el repo
    if ':' not in hit:
        return False
    path, rest = hit.split(':', 1)
    if not path or not rest[:1].isdigit():
        return False
    return os.path.exists(os.path.join(repo, path))

def hit_parts(hit):
    # formato: "path:lineno: snippet"
    path, rest = hit.split(':', 1)
    lineno, _, snip = rest.partition(': ')
    return path, lineno, snip

fixture = json.load(open(eval_path))
per_query = []
agg = {"domain_precision": [], "domain_recall": [], "search_recall": [],
       "categories_recall": [], "spurious_categories": [], "search_leaked": [],
       "context_tokens": []}

for q in fixture["queries"]:
    qid, query = q["id"], q["query"]
    gold_domains = set(q.get("gold_domains", []))
    gold_files = set(q.get("gold_files", []))
    gold_facts = q.get("gold_facts", [])

    r = run_router(query)
    cats = r.get("categories", [])
    kno = r.get("knowledge", [])
    skills = r.get("skills", [])

    hits = run_search(query)
    hits = [h for h in hits if valid_hit(h)]

    # ── métricas de router ──
    router_kno_set = set(kno)
    gold_in_router = router_kno_set & gold_files
    domain_precision = len(gold_in_router) / len(router_kno_set) if router_kno_set else 0.0
    domain_recall = len(gold_in_router) / len(gold_files) if gold_files else 0.0
    cats_recall = len(gold_domains & set(cats)) / len(gold_domains) if gold_domains else 0.0
    spurious = sorted(set(cats) - gold_domains)

    # ── métricas de search (FTS5 real) ──
    hit_text = deaccent(" ".join(h[2] for h in [hit_parts(x) for x in hits] if h)).lower()
    search_recall = 0
    found_facts = []
    for f in gold_facts:
        needle = deaccent(f["text"].lower())
        if needle in hit_text:
            search_recall += 1
            found_facts.append(f["text"])
    search_recall = search_recall / len(gold_facts) if gold_facts else 0.0

    gold_hit_paths = {p for p, _, _ in [hit_parts(x) for x in hits] if p}
    search_leaked = len(gold_hit_paths - gold_files)  # hits de archivos fuera del gold

    # ── presupuesto de contexto (lo que el router cargaría) ──
    ctx_bytes = 0
    for f in list(kno) + list(skills):
        p = os.path.join(repo, f)
        if os.path.isfile(p):
            ctx_bytes += os.path.getsize(p)
    est_tokens = ctx_bytes // 4

    agg["domain_precision"].append(domain_precision)
    agg["domain_recall"].append(domain_recall)
    agg["search_recall"].append(search_recall)
    agg["categories_recall"].append(cats_recall)
    agg["spurious_categories"].append(len(spurious))
    agg["search_leaked"].append(search_leaked)
    agg["context_tokens"].append(est_tokens)

    per_query.append({
        "id": qid, "query": query, "coverage": q.get("coverage"),
        "gold_domains": sorted(gold_domains),
        "router_categories": cats,
        "categories_recall": round(cats_recall, 3),
        "spurious_categories": spurious,
        "gold_files": sorted(gold_files),
        "router_knowledge": kno,
        "gold_in_router": sorted(gold_in_router),
        "domain_precision": round(domain_precision, 3),
        "domain_recall": round(domain_recall, 3),
        "router_skills": skills,
        "search_top_n": len(hits),
        "search_recall": round(search_recall, 3),
        "gold_facts_found": found_facts,
        "search_leaked_files": search_leaked,
        "context_estimated_tokens": est_tokens,
    })

n = len(per_query)
summary = {
    "baseline": "A",
    "profile": "PC",
    "host": "sabrewulf-a320ms2h",
    "date": fixture["date"],
    "eval_id": fixture["eval_id"],
    "eval_hash": "8e42d119bf7bc4f2014e7239f101e3c37296365f3b24158e0cb0155baaa67f5d",
    "pipeline": "buffy-router.sh (real) → buffy-search.sh FTS5 bm25 (estrategia 'and' default, limit=%d)" % limit,
    "runtime_changed": False,
    "num_queries": n,
    "aggregate": {
        "domain_precision_avg": round(sum(agg["domain_precision"])/n, 3),
        "domain_recall_avg": round(sum(agg["domain_recall"])/n, 3),
        "categories_recall_avg": round(sum(agg["categories_recall"])/n, 3),
        "search_recall_avg": round(sum(agg["search_recall"])/n, 3),
        "total_spurious_categories": sum(agg["spurious_categories"]),
        "total_search_leaked_files": sum(agg["search_leaked"]),
        "context_tokens_total": sum(agg["context_tokens"]),
        "context_tokens_avg": round(sum(agg["context_tokens"])/n),
        "window_utilization_avg": round(sum(agg["context_tokens"])/n/200000, 5),
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
else
  python3 - "$RESULT_FILE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
a = d["aggregate"]
print("── Baseline A — perfil PC (eval-ctx-PC-2026-08-11) ──")
print("  pipeline: %s" % d["pipeline"])
print("  runtime_changed: %s" % d["runtime_changed"])
print("  queries: %d" % d["num_queries"])
print("  ── agregado ──")
print("  domain_precision_avg:    %.3f" % a["domain_precision_avg"])
print("  domain_recall_avg:       %.3f" % a["domain_recall_avg"])
print("  categories_recall_avg:   %.3f" % a["categories_recall_avg"])
print("  search_recall_avg (FTS5):%.3f" % a["search_recall_avg"])
print("  spurious_categories:     %d" % a["total_spurious_categories"])
print("  search_leaked_files:     %d" % a["total_search_leaked_files"])
print("  context_tokens: %d total / %d avg (window 200k → %s)" % (
    a["context_tokens_total"], a["context_tokens_avg"], a["window_utilization_avg"]))
print("  ── por query ──")
print("  %-4s %-8s %-8s %-8s %-8s %-6s %-6s" % ("ID", "catRec", "domPre", "domRec", "sRec", "spur", "leak"))
for q in d["per_query"]:
    print("  %-4s %-8s %-8s %-8s %-8s %-6s %-6s" % (
        q["id"], q["categories_recall"], q["domain_precision"], q["domain_recall"],
        q["search_recall"], len(q["spurious_categories"]), q["search_leaked_files"]))
print("  detalle (gold_files vs router_knowledge):")
for q in d["per_query"]:
    print("  %s «%s»" % (q["id"], q["query"]))
    print("    gold:  %s" % ", ".join(q["gold_files"]))
    print("    router:%s" % (", ".join(q["router_knowledge"]) if q["router_knowledge"] else " (ninguno)"))
    print("    cats:  %s (spurious: %s)" % (", ".join(q["router_categories"]) if q["router_categories"] else "(ninguna)", ", ".join(q["spurious_categories"]) if q["spurious_categories"] else "ninguna"))
    if q["gold_facts_found"]:
        print("    facts encontradas: %s" % ", ".join(q["gold_facts_found"]))
    else:
        print("    facts encontradas: NINGUNA")
PY
fi
echo "baseline A registrada en $OUT_FILE"

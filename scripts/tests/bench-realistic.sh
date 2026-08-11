#!/usr/bin/env bash
# bench-realistic — benchmark realista de búsqueda + router de Buffy (contrato: bench-realistic-DESIGN.md).
#
# Pipeline REAL (nada simulado): buffy-search.sh (FTS5) y buffy-router.sh sobre un
# sandbox con corpus generado por fixtures-realistic/generator.py.
#
# Uso:
#   bench-realistic.sh [--facts N] [--queries N] [--seed N] [--quick] [--json]
#
# --quick: 50 hechos / 12 queries (CI).
# Exit codes: 0 healthy · 1 gate roto/fixture inválido/benchmark roto · 2 uso.
set -euo pipefail

BR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$BR_DIR/../.." && pwd)"
GEN="$BR_DIR/fixtures-realistic/generator.py"
DOMAINS="$BR_DIR/fixtures-realistic/domains.json"

FACTS=500
QUERIES=60
SEED=20260810
JSON_OUT=false

usage() {
    echo "uso: bench-realistic.sh [--facts N] [--queries N] [--seed N] [--quick] [--json]" >&2
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --facts)   FACTS="${2:?}"; shift 2 ;;
        --queries) QUERIES="${2:?}"; shift 2 ;;
        --seed)    SEED="${2:?}"; shift 2 ;;
        --quick)   FACTS=50; QUERIES=12; shift ;;
        --json)    JSON_OUT=true; shift ;;
        *) usage ;;
    esac
done

[[ ! -f "$GEN" || ! -f "$DOMAINS" ]] && {
    echo "bench-realistic: faltan fixtures-realistic/generator.py o domains.json" >&2
    exit 2
}

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
SB1=$(mktemp -d "$TMPDIR/bench-realistic.XXXXXX")
SB2=$(mktemp -d "$TMPDIR/bench-realistic.XXXXXX")
trap 'rm -rf "$SB1" "$SB2"' EXIT

# --- G1 (fixtures) + G2-a (determinismo de fixtures) -------------------------
gen_ok=1
python3 "$GEN" --seed "$SEED" --sandbox "$SB1" --facts "$FACTS" --queries "$QUERIES" --json \
    >"$SB1/g1.json" 2>"$SB1/g1.err" || gen_ok=0
if [[ $gen_ok -eq 0 ]]; then
    cat "$SB1/g1.err" >&2
    echo "bench-realistic: G1 FALLÓ (fixtures inválidos)" >&2
    exit 1
fi

sha1=$(cat "$SB1/bench-realistic/manifest.sha256")
python3 "$GEN" --seed "$SEED" --sandbox "$SB2" --facts "$FACTS" --queries "$QUERIES" --json \
    >/dev/null 2>&1
sha2=$(cat "$SB2/bench-realistic/manifest.sha256")
if [[ "$sha1" != "$sha2" ]]; then
    echo "bench-realistic: G2 FALLÓ (manifest difiere entre corridas del mismo seed)" >&2
    exit 1
fi

# --- seed del sandbox: ai-context vacío, skills, scripts/see.sh, stub adb ----
for SB in "$SB1" "$SB2"; do
    mkdir -p "$SB/ai-context" "$SB/.agents/skills" "$SB/scripts" "$SB/bin"
    : >"$SB/ai-context/INFO-core.md"
    : >"$SB/ai-context/CONTINUE.md"
    : >"$SB/ai-context/SNAPSHOT.md"
    : >"$SB/scripts/see.sh"
    for skill in $(grep -oE 'add_skill "[a-z0-9-]+"' "$REPO_DIR/scripts/buffy-router.sh" | sed -E 's/add_skill "//; s/"//' | sort -u); do
        mkdir -p "$SB/.agents/skills/$skill"
        printf 'name: %s\n' "$skill" >"$SB/.agents/skills/$skill/skill.yaml"
        printf '# %s\n' "$skill" >"$SB/.agents/skills/$skill/SKILL.md"
    done
    printf '#!/bin/sh\nexit 1\n' >"$SB/bin/adb"
    chmod +x "$SB/bin/adb"
done

# --- harness de evaluación (métricas + JSON por contrato) ---------------------
PY="$(cat <<'PYEOF'
import json, os, re, subprocess, sys, time

def load(p):
    with open(p, encoding="utf-8") as f:
        return json.load(f)

sb, seed, facts_n, queries_n = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
repo = os.environ["BR_REPO"]
facts = load(os.path.join(sb, "bench-realistic", "facts.json"))
queries = load(os.path.join(sb, "bench-realistic", "queries.json"))
with open(os.path.join(sb, "bench-realistic", "manifest.sha256"), encoding="utf-8") as f:
    manifest = f.read().strip()
dom_cfg = load(os.environ["BR_DOMAINS"])
kdirs = {d: m.get("knowledge_dir", d) for d, m in dom_cfg["domains"].items()}
dir_dom = {v: k for k, v in kdirs.items()}

fact_loc = {(f["file"], f["lineno"]): f["id"] for f in facts}
K = 10

env_search = dict(os.environ, BUFFY_REPO=sb, XDG_CACHE_HOME=os.path.join(sb, ".cache"))
env_router = dict(os.environ, BUFFY_REPO=sb, BUFFY_HOME=sb, PATH=sb + "/bin:" + os.environ["PATH"])

def run(cmd, env):
    t0 = time.time()
    p = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=120)
    return p.stdout, (time.time() - t0) * 1000.0, p.returncode

BS = os.path.join(repo, "scripts", "buffy-search.sh")
run(["bash", BS, "--reindex"], env_search)

def search(q):
    out, ms, rc = run(["bash", BS, "-l", str(K), q], env_search)
    hits = []
    for line in out.splitlines():
        line = line.strip()
        if not line or ":" not in line or "Sin resultados" in line:
            continue
        path, lineno, _ = re.split(r":", line, 2)
        if path.endswith(".md") and lineno.isdigit():
            hits.append((path, int(lineno)))
    return hits, ms, rc

def router(q):
    out, ms, rc = run(["bash", os.path.join(repo, "scripts", "buffy-router.sh"),
                       "--repo", sb, "--json", q], env_router)
    try:
        data = json.loads(out)
    except Exception:
        data = {}
    return data.get("categories", []), data.get("knowledge", []), ms, rc

def dom_of_file(path):
    # Nested "Knowledge/Dir/File.md" → dir → dominio; plano "Knowledge/Vision.md"
    # (vision usa knowledge_dir vacío, como el router/repo real) → basename.
    parts = path.split("/")
    if len(parts) >= 3:
        return dir_dom.get(parts[1])
    base = os.path.basename(path)
    for d, m in dom_cfg["domains"].items():
        if base in m.get("files", []):
            return d
    return None

results = []
totals = {"router_precision": 0.0, "router_recall": 0.0, "search_recall": 0.0,
          "context_relevance": 0.0, "cross_domain_leakage": 0.0, "token_cost": 0.0}
mults = {"multi_domain_precision": 0.0, "multi_domain_recall": 0.0}
lat_all, lat_multi = [], []
micro = {"router_p": [0, 0], "router_r": [0, 0], "search_r": [0, 0],
         "relevance": [0, 0], "leak": [0, 0]}
n_multi = 0

for q in queries:
    g_doms = q["gold_domains"]
    g_ids = q["gold_facts"]
    hits, s_ms, s_rc = search(q["text"])
    cats, ctx_know, r_ms, r_rc = router(q["text"])
    if s_rc != 0 or r_rc != 0:
        results.append({"id": q["id"], "kind": q["kind"], "gold_domains": g_doms,
                        "gold_facts": g_ids, "search_hits": len(hits),
                        "router_categories": cats, "router_knowledge": ctx_know,
                        "latency_ms": round(s_ms + r_ms, 2),
                        "error": "subprocess rc %d/%d" % (s_rc, r_rc)})
        continue

    recov = [fact_loc.get(h) for h in hits if h in fact_loc]
    recov = [x for x in recov if x is not None]
    # recall = gold recuperado ∩ gold total (recov puede incluir hechos no-gold
    # de archivos del mismo tema — no es recall si no se intersecta).
    search_recall = len(set(recov) & set(g_ids)) / len(g_ids) if g_ids else 0.0

    ctx = set(ctx_know) | {h[0] for h in hits}
    files_with_gold = {f["file"] for f in facts if f["id"] in set(g_ids)}
    relevance = len(ctx & files_with_gold) / len(ctx) if ctx else 0.0
    leak = len([f for f in ctx if dom_of_file(f) not in g_doms]) / len(ctx) if ctx else 0.0
    tok = sum(os.path.getsize(os.path.join(sb, f))
              for f in ctx if os.path.exists(os.path.join(sb, f))) // 4

    s_doms = set()
    for name in cats:
        norm = name.strip().lower()
        for cat_id, dom_id in dom_cfg.get("router_categories", {}).items():
            if norm == cat_id.lower():
                s_doms.add(dom_id)
    g_set = set(g_doms)
    rp = len(s_doms & g_set) / len(s_doms) if s_doms else 0.0
    rr = len(s_doms & g_set) / len(g_set) if g_set else 0.0

    results.append({"id": q["id"], "kind": q["kind"], "gold_domains": g_doms,
                    "gold_facts": g_ids,
                    "search": {"hits": len(hits), "recovered": len(recov),
                               "recall": search_recall},
                    "router": {"categories": cats, "ctx_files": sorted(ctx),
                               "precision": rp, "recall": rr,
                               "context_relevance": relevance,
                               "cross_domain_leakage": leak,
                               "token_cost": tok,
                               "latency_ms": round(s_ms + r_ms, 2)}})
    totals["router_precision"] += rp
    totals["router_recall"] += rr
    totals["search_recall"] += search_recall
    totals["context_relevance"] += relevance
    totals["cross_domain_leakage"] += leak
    totals["token_cost"] += tok
    lat_all.append(round(s_ms + r_ms, 2))
    micro["router_p"][0] += len(s_doms & g_set); micro["router_p"][1] += len(s_doms)
    micro["router_r"][0] += len(s_doms & g_set); micro["router_r"][1] += len(g_set)
    micro["search_r"][0] += len(recov); micro["search_r"][1] += len(g_ids)
    micro["relevance"][0] += len(ctx & files_with_gold); micro["relevance"][1] += len(ctx)
    micro["leak"][0] += len([f for f in ctx if dom_of_file(f) not in g_doms])
    micro["leak"][1] += len(ctx)

    if len(g_doms) >= 2:
        mults["multi_domain_precision"] += rp
        mults["multi_domain_recall"] += rr
        lat_multi.append(round(s_ms + r_ms, 2))
        n_multi += 1

n = max(1, len(results))
aggregates = {
    "router_precision": {"macro": totals["router_precision"] / n,
                         "micro": micro["router_p"][0] / micro["router_p"][1]
                         if micro["router_p"][1] else 0.0},
    "router_recall": {"macro": totals["router_recall"] / n,
                      "micro": micro["router_r"][0] / micro["router_r"][1]
                      if micro["router_r"][1] else 0.0},
    "search_recall": {"macro": totals["search_recall"] / n,
                      "micro": micro["search_r"][0] / micro["search_r"][1]
                      if micro["search_r"][1] else 0.0},
    "context_relevance": {"macro": totals["context_relevance"] / n,
                          "micro": micro["relevance"][0] / micro["relevance"][1]
                          if micro["relevance"][1] else 0.0},
    "cross_domain_leakage": {"macro": totals["cross_domain_leakage"] / n,
                             "micro": micro["leak"][0] / micro["leak"][1]
                             if micro["leak"][1] else 0.0},
    "token_cost": {"macro": totals["token_cost"] / n},
    "latency_ms": {"mean": sum(lat_all) / len(lat_all) if lat_all else 0.0,
                   "p95": sorted(lat_all)[int(0.95 * (len(lat_all) - 1))] if lat_all else 0.0,
                   "n": len(lat_all)},
    "multi_domain_precision": {"macro": mults["multi_domain_precision"] / n_multi
                               if n_multi else 0.0, "n": n_multi},
    "multi_domain_recall": {"macro": mults["multi_domain_recall"] / n_multi
                            if n_multi else 0.0, "n": n_multi},
}
aggregates["multi_domain_latency_ms"] = {
    "mean": sum(lat_multi) / len(lat_multi) if lat_multi else 0.0,
    "p95": sorted(lat_multi)[int(0.95 * (len(lat_multi) - 1))] if lat_multi else 0.0,
}

out = {"benchmark": "bench-realistic", "version": "1.0", "seed": seed,
       "config": {"facts": facts_n, "queries": queries_n, "top_k": K,
                  "manifest_sha256": manifest},
       "aggregates": aggregates, "results": results}
print(json.dumps(out, ensure_ascii=False))
PYEOF
)"

export BR_REPO="$REPO_DIR" BR_DOMAINS="$DOMAINS"
res1=$(python3 - "$SB1" "$SEED" "$FACTS" "$QUERIES" <<<"$PY")
res2=$(python3 - "$SB2" "$SEED" "$FACTS" "$QUERIES" <<<"$PY")

# --- G2-b: resultados idénticos salvo latencia ---------------------------------
strip_lat() { python3 -c '
import json, sys
d = json.load(sys.stdin)
def walk(x):
    if isinstance(x, dict):
        return {k: walk(v) for k, v in x.items() if "latency" not in k}
    if isinstance(x, list):
        return [walk(v) for v in x]
    return x
print(json.dumps(walk(d), ensure_ascii=False, sort_keys=True))
'; }
if [[ "$(strip_lat <<<"$res1")" != "$(strip_lat <<<"$res2")" ]]; then
    echo "bench-realistic: G2 FALLÓ (resultados difieren entre corridas del mismo seed salvo latencia)" >&2
    echo "  primer diff (salvo latencia):" >&2
    R1FILE="$TMPDIR/r1full.json" R2FILE="$TMPDIR/r2full.json" python3 - <<'DBG' || true
import json, os
def strip(x):
    if isinstance(x, dict):
        return {k: strip(v) for k, v in x.items() if "latency" not in k}
    if isinstance(x, list):
        return [strip(v) for v in x]
    return x
a = strip(json.load(open(os.environ["R1FILE"])))
b = strip(json.load(open(os.environ["R2FILE"])))
def diff(x, y, path=""):
    if type(x) != type(y):
        print("TYPE", path, type(x), type(y)); return
    if isinstance(x, dict):
        for k in set(x) | set(y):
            if k not in x: print("MISSING", path + "/" + k, "in A"); continue
            if k not in y: print("MISSING", path + "/" + k, "in B"); continue
            diff(x[k], y[k], path + "/" + k)
    elif isinstance(x, list):
        if len(x) != len(y): print("LEN", path, len(x), len(y)); return
        for i, (u, v) in enumerate(zip(x, y)):
            diff(u, v, f"{path}[{i}]")
    elif x != y:
        print("DIFF", path, repr(x), repr(y))
diff(a, b)
DBG
    exit 1
fi

# --- G3: mismo manifest para los 3 modos (por construcción) ---------------------
sha=$(echo "$res1" | python3 -c 'import json,sys; print(json.load(sys.stdin)["config"]["manifest_sha256"])')
if [[ "$sha" != "$sha1" ]]; then
    echo "bench-realistic: G3 FALLÓ (manifest inconsistente entre modos)" >&2
    exit 1
fi

# --- reporte ---------------------------------------------------------------
if [[ "$JSON_OUT" == "true" ]]; then
    python3 - "$res1" <<'RPT'
import json, sys
d = json.loads(sys.argv[1])
d["gates"] = {"G1_fixtures": True, "G2_determinismo": True, "G3_mismo_manifest": True}
d["healthy"] = True
print(json.dumps(d, ensure_ascii=False, indent=1))
RPT
else
    python3 - "$res1" <<'RPT'
import json, sys
d = json.loads(sys.argv[1])
a = d["aggregates"]
print("bench-realistic seed=%s facts=%s queries=%s manifest=%s" % (
    d["seed"], d["config"]["facts"], d["config"]["queries"],
    d["config"]["manifest_sha256"][:12]))
print("G1 fixtures OK · G2 determinismo OK · G3 mismo manifest OK")
print("=" * 62)
print("%-24s %7s %7s %6s" % ("métrica", "macro", "micro", "n"))
print("-" * 62)
for m in ("router_precision", "router_recall", "search_recall", "context_relevance",
          "cross_domain_leakage", "token_cost"):
    v = a[m]
    print("%-24s %7.3f %7.3f %6s" % (m, v["macro"], v.get("micro", 0.0), ""))
print("%-24s %7.3f %7s %6d" % ("latency_ms (mean)", a["latency_ms"]["mean"], "",
                               a["latency_ms"]["n"]))
print("%-24s %7.3f" % ("latency_ms (p95)", a["latency_ms"]["p95"]))
print("-" * 62)
for m in ("multi_domain_precision", "multi_domain_recall"):
    print("%-24s %7.3f %7s %6d" % (m, a[m]["macro"], "", a[m]["n"]))
print("exit 0 (healthy)")
RPT
fi
exit 0
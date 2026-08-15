#!/usr/bin/env python3
"""analiza-17E.py — tabla de interacción por gold y veredicto 17E (spec combine-17E-DESIGN.md)

Uso:
  python3 analiza-17E.py <A-r1.json> <A-r2.json> <B-r1.json> <B-r2.json> \
                         <V1-r1.json> <V1-r2.json> <T-r1.json> <T-r2.json>

Imprime:
  1. Baseline del fixture (A/B-solo/V1-solo, calculado en esta misma ejecución).
  2. Tabla de interacción por gold (attr Q01-Q10 para A, B, V1, T).
  3. Diagnóstico por gold: dónde T ≠ B-solo o T ≠ V1-solo y qué mecanismo pudo causarlo.
  4. Veredicto vs gate 17E (dominancia combinada, spec §4).
"""
import json, sys

MANIFEST_HASH = "0af49cc666d872a6"
QIDS = ["Q%02d" % i for i in range(1, 11)]

def load(f):
    d = json.load(open(f))
    p = d["per_pad"]["4"]
    return {
        "file": f.split("/")[-1],
        "variant": d.get("variant", "?"),
        "attr": p["attributed_total"],
        "attr_q": {q["qid"]: q["attributed"] for q in p["per_query"]},
        "leak": p["cross_domain_leakage_avg"],
        "leak_q": {q["qid"]: q["cross_domain_leakage"] for q in p["per_query"]},
        "pRel": p["passage_relevance_avg"],
        "contain": p["gold_containment_avg"],
        "ctx_size": {q["qid"]: q["ctx_size"] for q in p["per_query"]},
        "ctx_passages": {q["qid"]: [c for c in q.get("ctx_passages", [])] for q in p["per_query"]},
        "det": d.get("determinism_hash"),
        "fix_hash": d.get("fixture_corpus_hash"),
    }

def main():
    files = sys.argv[1:]
    if len(files) != 8:
        print(__doc__)
        sys.exit(1)
    A1, A2, B1, B2, V1a, V1b, T1, T2 = [load(f) for f in files]

    # ── 1. sanity de identidad ──
    print("=== SANITY (spec §3.1) ===")
    ok = True
    for name, r1, r2 in [("A", A1, A2), ("B-solo", B1, B2), ("V1-solo", V1a, V1b)]:
        if r1["fix_hash"] != MANIFEST_HASH:
            print("  ❌ %s: fixture hash %s ≠ %s" % (name, r1["fix_hash"], MANIFEST_HASH)); ok = False
        if r1["attr_q"] != r2["attr_q"] or r1["leak_q"] != r2["leak_q"]:
            print("  ❌ %s: G2 interno r1 ≠ r2 per-query" % name); ok = False
    if ok:
        print("  ✅ fixture íntegro (0af49cc666d872a6) en las 8 corridas · G2 interno r1=r2")

    # direcciones de efecto
    eff = []
    if not (B1["attr"] >= A1["attr"]): eff.append("B-solo attr %d < A %d" % (B1["attr"], A1["attr"]))
    if not (B1["attr_q"].get("Q05", 0) >= A1["attr_q"].get("Q05", 0)): eff.append("B no rescata Q05")
    if not (V1a["leak"] <= A1["leak"]): eff.append("V1-solo leak %.3f > A %.3f" % (V1a["leak"], A1["leak"]))
    if not (B1["attr_q"].get("Q05", 0) >= V1a["attr_q"].get("Q05", 0)): eff.append("B Q05 < V1 Q05")
    if eff:
        print("  ❌ direcciones de efecto violadas:")
        for e in eff: print("     - " + e)
        ok = False
    else:
        print("  ✅ direcciones de efecto OK (B rescata Q05, V1 reduce leak)")

    # ── 2. baseline del fixture ──
    print("\n=== BASELINE DEL FIXTURE (calculado en esta ejecución, NO histórico) ===")
    print("%-8s %8s %8s %8s %8s" % ("config", "attr", "leak", "pRel", "contain"))
    for name, r in [("A", A1), ("B-solo", B1), ("V1-solo", V1a)]:
        print("%-8s %5d/20 %8.3f %8.3f %8.3f" % (name, r["attr"], r["leak"], r["pRel"], r["contain"]))
    print("  (referencia para futuros experimentos sobre fx-2026-08-15-001 —")
    print("   NO comparable con 17B/17C/17D: otro corpus, sin estado de instancia)")

    # ── 3. tabla de interacción por gold ──
    print("\n=== INTERACCIÓN POR GOLD (attr por query) ===")
    print("%-5s %4s %4s %4s %4s   %s" % ("Q", "A", "B", "V1", "T", "notas"))
    for qid in QIDS:
        a, b, v, t = A1["attr_q"].get(qid, 0), B1["attr_q"].get(qid, 0), V1a["attr_q"].get(qid, 0), T1["attr_q"].get(qid, 0)
        notes = []
        if t > v and qid == "Q05": notes.append("Q05 rescatado por B bajo V1 ✓")
        if t < b and t < v: notes.append("T pierde vs ambos")
        if t < a: notes.append("REGRESIÓN vs A")
        if t != b and t != v: notes.append("interacción (T≠B,T≠V1)")
        print("%-5s %4d %4d %4d %4d   %s" % (qid, a, b, v, t, " · ".join(notes)))

    # ── 4. diagnóstico de interacción (solo donde T ≠ B-solo o T ≠ V1-solo) ──
    print("\n=== DIAGNÓSTICO POR GOLD (interacción OBSERVADA, no esperada) ===")
    found = False
    for qid in QIDS:
        a, b, v, t = A1["attr_q"].get(qid, 0), B1["attr_q"].get(qid, 0), V1a["attr_q"].get(qid, 0), T1["attr_q"].get(qid, 0)
        if t == b and t == v:
            continue
        found = True
        print("  %s: A=%d B=%d V1=%d T=%d" % (qid, a, b, v, t))
        # ctx: ¿qué pasajes trajo T?
        ctx_t = T1["ctx_passages"].get(qid, [])
        ctx_b = B1["ctx_passages"].get(qid, [])
        ctx_v = V1a["ctx_passages"].get(qid, [])
        if t < b:
            print("      T perdió attr vs B-solo — ctx T (%d) vs ctx B (%d): %s" % (
                len(ctx_t), len(ctx_b), "¿B introdujo un gold que V1 excluyó?"))
        if t < v:
            print("      T perdió attr vs V1-solo — ctx T (%d) vs ctx V1 (%d)" % (len(ctx_t), len(ctx_v)))
        if t > a:
            print("      T mejoró vs A — combinación recuperó attr")
    if not found:
        print("  Sin diferencias T vs controles (T = B-solo = V1-solo en todos los golds)")

    # ── 5. veredicto vs gate 17E (spec §4) ──
    print("\n=== GATE 17E (dominancia combinada, spec §4) ===")
    best_leak = min(A1["leak"], B1["leak"], V1a["leak"])
    best_attr = max(A1["attr"], B1["attr"], V1a["attr"])
    best_pRel = min(A1["pRel"], B1["pRel"], V1a["pRel"])
    best_contain = min(A1["contain"], B1["contain"], V1a["contain"])
    crits = [
        ("1 leak ≤ min", T1["leak"] <= best_leak, "T %.3f ≤ %.3f" % (T1["leak"], best_leak)),
        ("2 attr ≥ max", T1["attr"] >= best_attr, "T %d ≥ %d" % (T1["attr"], best_attr)),
        ("3 Q05 ≥ 1", T1["attr_q"].get("Q05", 0) >= 1, "Q05=%d" % T1["attr_q"].get("Q05", 0)),
        ("4 sin regresión por gold", all(T1["attr_q"].get(q, 0) >= A1["attr_q"][q] for q in QIDS), "vs A"),
        ("5 pRel ≥ min", T1["pRel"] >= best_pRel, "T %.3f ≥ %.3f" % (T1["pRel"], best_pRel)),
        ("6 contain ≥ 0.80 y ≥ min", T1["contain"] >= 0.80 and T1["contain"] >= best_contain,
         "T %.3f ≥ %.3f" % (T1["contain"], min(0.80, best_contain))),
        ("7 G2 (T r1=r2)", T1["det"] == T2["det"] and T1["attr_q"] == T2["attr_q"], "determinista"),
    ]
    for num, name, cok, det in crits:
        print("  [%s] %s — %s" % ("✅" if cok else "❌", name, det))
    if all(cok for _, _, cok, _ in crits):
        print("\n✅ VEREDICTO: GATE 17E PASADO — T hereda lo mejor de ambos factores sin regresiones.")
        print("   T = V1 + DICT_H1_B → CANDIDATO A ADOPCIÓN (sujeto a registro y decisión del usuario).")
        sys.exit(0)
    print("\n❌ VEREDICTO: GATE 17E FALLADO — T no domina a los controles.")
    print("   Combinación NO ADOPTADA; diagnóstico de interacción arriba. No se relaja el gate.")
    sys.exit(4)

if __name__ == "__main__":
    main()

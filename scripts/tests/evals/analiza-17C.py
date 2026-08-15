#!/usr/bin/env python3
"""analiza-17C.py — compara variantes 17C contra el gate §17.4 (spec leak-17C-DESIGN.md)

Uso:
  python3 analiza-17C.py <control-A.json> <V1.json> [V2.json] [V3.json] ...

Imprime por variante: attr, pRel, leak, contain, determinismo, y la tabla vs gate.
"""
import json, sys

GATE = {
    "leak": 0.308,
    "attr_min": 13,
    "pRel": 0.121,
    "contain": 0.80,
}

def load(f):
    d = json.load(open(f))
    pad = d["per_pad"]["4"]
    return d, pad

def resumen(f):
    d, pad = load(f)
    return {
        "file": f.split("/")[-1],
        "variant": d.get("variant", "?"),
        "attr": pad["attributed_total"],
        "attr_n": pad["attributed_n"],
        "pRel": pad["passage_relevance_avg"],
        "leak": pad["cross_domain_leakage_avg"],
        "contain": pad["gold_containment_avg"],
        "det": d.get("determinism_hash", "?"),
        "per_query": {q["qid"]: q["attributed"] for q in pad["per_query"]},
    }

def main():
    files = sys.argv[1:]
    if not files:
        print(__doc__)
        sys.exit(1)
    rows = [resumen(f) for f in files]
    # sanity: control A primero
    print("=== RESUMEN 17C ===")
    print(f"{'variante':<10} {'attr':<8} {'pRel':<7} {'leak':<7} {'contain':<8} {'det':<17}")
    for r in rows:
        print(f"{r['variant']:<10} {r['attr']}/{r['attr_n']:<5} {r['pRel']:<7.3f} {r['leak']:<7.3f} {r['contain']:<8.3f} {r['det']}")
    print()
    # gate por variante (vs control A)
    ctrl = rows[0]
    print("=== GATE §17.4 (vs control A) ===")
    for r in rows[1:]:
        ok_leak = r["leak"] <= GATE["leak"]
        ok_attr = r["attr"] >= GATE["attr_min"]
        ok_pRel = r["pRel"] >= GATE["pRel"]
        ok_contain = r["contain"] >= GATE["contain"]
        # regresiones por gold
        reg_prosa = [q for q in ("Q02", "Q06", "Q08", "Q09") if r["per_query"].get(q, 0) < ctrl["per_query"].get(q, 0)]
        reg_otros = [q for q in ("Q03", "Q04", "Q07", "Q10") if r["per_query"].get(q, 0) < ctrl["per_query"].get(q, 0)]
        print(f"  {r['variant']}: leak={r['leak']:.3f} {'✅' if ok_leak else '❌'}≤{GATE['leak']} | "
              f"attr={r['attr']} {'✅' if ok_attr else '❌'}≥{GATE['attr_min']} | "
              f"pRel={r['pRel']:.3f} {'✅' if ok_pRel else '❌'} | "
              f"contain={r['contain']:.3f} {'✅' if ok_contain else '❌'} | "
              f"regr_prosa={reg_prosa or '—'} regr_otros={reg_otros or '—'}")
        verdict = "PASS" if (ok_leak and ok_attr and ok_pRel and ok_contain and not reg_prosa and not reg_otros) else "FAIL"
        print(f"    → {verdict}")

if __name__ == "__main__":
    main()
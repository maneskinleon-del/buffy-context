#!/usr/bin/env python3
"""bench-realistic — generador determinista de fixtures (contrato: scripts/tests/bench-realistic-DESIGN.md).

Genera: Knowledge/<dominio>/<archivo>.md (hechos con id f_XXXX + lineno),
  facts.json, queries.json y manifest.sha256 dentro del sandbox.
Determinista: random.Random(SEED). Validación G1 integrada (exit 1 si falla).

Uso:
  generator.py --seed N --sandbox DIR [--facts N] [--queries N]
"""
import argparse
import hashlib
import json
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DOMAINS_JSON = os.path.join(HERE, "domains.json")

CATEGORY_MAP = {
    "Android": "android", "Code Search": "code-search", "React": "react",
    "Linux": "linux", "Git": "git", "Node": "node", "Shell": "shell",
    "Visión/VLM": "vision",
}

QUERY_KIND_SPLIT = [("single", 36), ("multi", 14), ("ambiguous", 6), ("adversarial", 4)]


def load_domains():
    with open(DOMAINS_JSON, encoding="utf-8") as f:
        return json.load(f)


def fill(text, rng, domain_vocab, other_vocab=()):
    """Rellena placeholders {A..Z} con vocabulario del dominio (y opcional de otro)."""
    pool = list(domain_vocab) + list(other_vocab)
    for ch in list(re.findall(r"\{[A-Z]\}", text)):
        text = text.replace(ch, rng.choice(pool), 1)
    return text


class FactsWriter:
    """Escribe hechos en Knowledge/<dominio>/<archivo>.md y registra id→(path, lineno)."""

    def __init__(self, sandbox, cfg, rng, dom_cfg):
        self.sb = sandbox
        self.cfg = cfg
        self.rng = rng
        self.kdirs = {d: m.get("knowledge_dir", d) for d, m in dom_cfg["domains"].items()}
        self.facts = []          # [{id, domains[], file, lineno, text, negative}]
        self._file_counter = {}  # (dominio, archivo) → lineas escritas
        self._next_id = 1

    def _path(self, domain, fname):
        # knowledge_dir vacío → layout plano (Knowledge/Vision.md), como lo
        # hardcodea buffy-router.sh (coincide con el repo real).
        k = self.kdirs[domain]
        return f"Knowledge/{k}/{fname}" if k else f"Knowledge/{fname}"

    def _wlineno(self, domain, fname):
        k = (domain, fname)
        self._file_counter[k] = self._file_counter.get(k, 0) + 1
        return self._file_counter[k]

    def add(self, domain, fname, text, domains=None, negative=False):
        path = self._path(domain, fname)
        lineno = self._wlineno(domain, fname)
        fid = f"f_{self._next_id:04d}"
        self._next_id += 1
        # id como comentario al final de la línea (detección de recuperación por path:lineno)
        line = f"{text} [@{fid}]"
        with open(os.path.join(self.sb, path), "a", encoding="utf-8") as fh:
            fh.write(line + "\n")
        self.facts.append({
            "id": fid, "primary": domain, "domains": domains or [domain],
            "file": path, "lineno": lineno, "text": text, "negative": negative,
        })
        return fid


def gen_facts(w, run_cfg, rng, dom_cfg):
    """Genera los hechos por dominio + multi + negativos."""
    targets = run_cfg["domains_target"]
    multi_target = round(run_cfg["facts"] * 0.12)
    neg_target = round(run_cfg["facts"] * 0.10)

    multi_pairs = [(p["a"], p["b"]) for p in dom_cfg["overlap_pairs"]]
    multi_made = 0
    neg_made = 0

    for d, dmeta in targets.items():
        feats = dom_cfg["domains"][d]
        files = feats["files"]
        vocab = feats["vocab"]
        templates = feats["templates"]
        for i in range(dmeta):
            is_multi = 0 < multi_target and multi_made < multi_target and rng.random() < 0.3
            other = None
            if is_multi:
                a, b = rng.choice(multi_pairs)
                if d not in (a, b):
                    a, b = d, b if b != d else a
                other = a if b == d else b
                domains = sorted({d, other})
            else:
                domains = [d]
            tpl = rng.choice(templates)
            other_vocab = dom_cfg["domains"][other]["vocab"] if other else ()
            text = fill(tpl, rng, vocab, other_vocab)
            text = re.sub(r"\s+", " ", text).strip().capitalize()
            fname = files[(i * 7 + len(text)) % len(files)]
            neg = False
            if neg_made < neg_target and domains == [d] and rng.random() < 0.2:
                neg = True
            w.add(d, fname, text, domains=domains if len(domains) > 1 else None,
                  negative=neg)
            if len(domains) > 1:
                multi_made += 1
            if neg:
                neg_made += 1

    # garantizar multi/negativos mínimos si el muestreo quedó corto
    while multi_made < multi_target:
        a, b = rng.choice(multi_pairs)
        d = a
        m = dom_cfg["domains"][d]
        other_vocab = dom_cfg["domains"][b]["vocab"]
        text = fill(rng.choice(m["templates"]), rng, m["vocab"], other_vocab)
        text = re.sub(r"\s+", " ", text).strip().capitalize()
        w.add(d, rng.choice(m["files"]), text, domains=sorted({a, b}))
        multi_made += 1
    while neg_made < neg_target:
        d = rng.choice(list(targets))
        m = dom_cfg["domains"][d]
        text = fill(rng.choice(m["templates"]), rng, m["vocab"])
        text = re.sub(r"\s+", " ", text).strip().capitalize()
        w.add(d, rng.choice(m["files"]), text, negative=True)
        neg_made += 1
    return multi_made, neg_made


def pick_facts_by_vocab(facts_pool, vocab_words, rng, k, exclude=()):
    """Elige k hechos cuyas palabras cubran ≥2 keywords dadas (para search hit)."""
    words = set(vocab_words)
    pool = [f for f in facts_pool if f["id"] not in exclude]
    scored = []
    for f in pool:
        toks = set(re.findall(r"[a-záéíóúñ]+", f["text"].lower()))
        inter = words & toks
        overlap = sum(1 for x in words if any(x in t for t in toks))
        if overlap >= 2:
            scored.append((overlap, rng.random(), f))
    scored.sort(reverse=True)
    if not scored:
        scored = [(0, rng.random(), f) for f in pool]
    return [f for _, _, f in scored[:k]]


def pick_keywords(fact, rng, n=3):
    toks = re.findall(r"[a-záéíóúñ]{4,}", fact["text"].lower())
    return rng.sample(toks, min(n, len(toks))) if len(toks) >= n else toks


def build_query_text(kind, rng, dom_cfg, gold_facts, neg_phrases):
    """Construye el texto de la query con plantillas del contrato (sin gold files)."""
    words = []
    for f in gold_facts:
        words += pick_keywords(f, rng, 2)
    rng.shuffle(words)
    a = " ".join(words[:3]) if len(words) >= 3 else " ".join(words)
    b = " ".join(words[2:5]) if len(words) >= 5 else a
    if neg_phrases:
        c = rng.choice(neg_phrases)
    else:
        c = words[0] if words else a
    tpl = rng.choice(dom_cfg["query_templates"][kind])
    return tpl.replace("{A}", a).replace("{B}", b).replace("{C}", c)


def neg_vocab_phrases(dom_cfg, shadow_domain):
    m = dom_cfg["domains"].get(shadow_domain)
    return m["vocab"] if m else []


def gen_queries(rng, run_cfg, dom_cfg, facts):
    """Genera queries: single/multi/ambiguous/adversarial con gold por construcción."""
    queries = []
    by_dom = {d: [f for f in facts if f["domains"] == [d] and not f["negative"]]
              for d in dom_cfg["domains"]}
    multi_facts = [f for f in facts if len(f["domains"]) > 1]
    qi = 1
    for kind, n in run_cfg["kind_split"]:
        for _ in range(n):
            if kind == "single":
                d = rng.choice(list(by_dom))
                pool = by_dom[d] or [f for f in facts if f["domains"] == [d]]
                gold = pick_facts_by_vocab(pool, dom_cfg["domains"][d]["vocab"], rng, rng.randint(1, 2))
                gold = gold or [rng.choice(pool)]
                doms = [d]
                neg = []
            elif kind == "multi":
                if multi_facts and rng.random() < 0.6:
                    gold = rng.sample(multi_facts, min(2, len(multi_facts)))
                    doms = sorted({x for f in gold for x in f["domains"]})
                else:
                    d1, d2 = rng.sample(list(by_dom), 2)
                    g1 = pick_facts_by_vocab(by_dom[d1], dom_cfg["domains"][d1]["vocab"], rng, 1)
                    g2 = pick_facts_by_vocab(by_dom[d2], dom_cfg["domains"][d2]["vocab"], rng, 1)
                    gold = (g1 and [g1[0]] or [rng.choice(by_dom[d1])]) + \
                           (g2 and [g2[0]] or [rng.choice(by_dom[d2])])
                    doms = sorted({d1, d2})
                neg = []
            else:  # ambiguous / adversarial: sombra con vocabulario compartido
                d = rng.choice(list(by_dom))
                shadow = rng.choice([p["b"] for p in dom_cfg["overlap_pairs"] if p["a"] == d] or list(by_dom))
                pool = by_dom[d] or [f for f in facts if f["domains"] == [d]]
                gold = pick_facts_by_vocab(pool, dom_cfg["domains"][d]["vocab"], rng, 1)
                gold = gold or [rng.choice(pool)]
                neg_pool = [f for f in facts if f["domains"] == [shadow] and f["id"] not in {g["id"] for g in gold}]
                neg = rng.sample(neg_pool, min(2, len(neg_pool))) if neg_pool else []
                doms = [d]
                neg_phrases = neg_vocab_phrases(dom_cfg, shadow)
                if kind == "adversarial" and neg_phrases:
                    neg_phrases = neg_phrases[:3]
                text = build_query_text(kind, rng, dom_cfg, gold, neg_phrases)
                queries.append({
                    "id": f"q_{qi:03d}", "kind": kind, "text": text,
                    "gold_facts": [g["id"] for g in gold],
                    "gold_domains": doms,
                    "negative_facts": [f["id"] for f in neg],
                })
                qi += 1
                continue
            text = build_query_text(kind, rng, dom_cfg, gold, [])
            queries.append({
                "id": f"q_{qi:03d}", "kind": kind, "text": text,
                "gold_facts": [g["id"] for g in gold],
                "gold_domains": doms,
                "negative_facts": [f["id"] for f in neg],
            })
            qi += 1
    return queries


def validate_g1(cfg, dom_cfg, facts, queries, errors):
    """G1: fixtures válidos (contrato §4). Devuelve True/False."""
    ok = True
    total = len(facts)
    if total != cfg["facts"]:
        ok = False
        errors.append(f"G1: hechos {total} != target {cfg['facts']}")
    counts = {}
    for f in facts:
        counts[f["primary"]] = counts.get(f["primary"], 0) + 1
    for d, n in cfg["domains_target"].items():
        if counts.get(d, 0) != n:
            ok = False
            errors.append(f"G1: dominio {d}: {counts.get(d,0)} != target {n}")
    multi = sum(1 for f in facts if len(f["domains"]) > 1)
    neg = sum(1 for f in facts if f["negative"])
    if not (cfg["multi_min"] <= multi <= cfg["multi_max"]):
        ok = False
        errors.append(f"G1: hechos multi {multi} fuera de [{cfg['multi_min']},{cfg['multi_max']}]")
    if not (cfg["neg_min"] <= neg <= cfg["neg_max"]):
        ok = False
        errors.append(f"G1: hechos negativos {neg} fuera de [{cfg['neg_min']},{cfg['neg_max']}]")
    if len(queries) != cfg["queries"]:
        ok = False
        errors.append(f"G1: queries {len(queries)} != target {cfg['queries']}")
    ids_f = {f["id"] for f in facts}
    if len(ids_f) != len(facts):
        ok = False
        errors.append("G1: ids de hechos duplicados")
    ids_q = {q["id"] for q in queries}
    if len(ids_q) != len(queries):
        ok = False
        errors.append("G1: ids de queries duplicados")
    gold_file_names = {os.path.basename(f) for d, m in dom_cfg["domains"].items() for f in m["files"]}
    for q in queries:
        if len(q["gold_facts"]) < 1:
            ok = False
            errors.append(f"G1: {q['id']} sin gold_facts")
        for fid in q["gold_facts"]:
            if fid not in ids_f:
                ok = False
                errors.append(f"G1: {q['id']} gold_fact {fid} inexistente")
        # gold_domains == unión de dominios de gold_facts
        union = sorted({x for f in facts if f["id"] in set(q["gold_facts"]) for x in f["domains"]})
        if sorted(q["gold_domains"]) != union:
            ok = False
            errors.append(f"G1: {q['id']} gold_domains {q['gold_domains']} != union {union}")
        # la query no menciona nombres de gold files
        low = q["text"].lower()
        for fn in gold_file_names:
            base = fn.lower().replace(".md", "")
            if base in low:
                ok = False
                errors.append(f"G1: {q['id']} menciona gold file '{fn}'")
    # hechos sin tokens prohibidos de su dominio (palabras sueltas → límite de
    # palabra; frases multi-palabra → subcadena, p.ej. "gg mouse")
    for f in facts:
        low = f["text"].lower()
        for d in f["domains"]:
            for tok in dom_cfg["domains"][d]["forbidden_tokens"]:
                t = tok.lower()
                if " " in t:
                    hit = t in low
                else:
                    hit = re.search(r"\b" + re.escape(t) + r"\b", low) is not None
                if hit:
                    ok = False
                    errors.append(f"G1: hecho {f['id']} [{d}] contiene token prohibido '{tok}'")
                    break
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--sandbox", required=True)
    ap.add_argument("--facts", type=int, default=500)
    ap.add_argument("--queries", type=int, default=60)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    cfg = load_domains()
    rng = random.Random(args.seed)
    sb = args.sandbox
    os.makedirs(sb, exist_ok=True)
    for d, m in cfg["domains"].items():
        os.makedirs(os.path.join(sb, "Knowledge", m.get("knowledge_dir", d)), exist_ok=True)
    os.makedirs(os.path.join(sb, "bench-realistic"), exist_ok=True)

    # targets escalados por dominio (proporciones del domains.json, suma exacta)
    total_dom = sum(m["count"] for m in cfg["domains"].values())
    raw = {d: m["count"] * args.facts / total_dom for d, m in cfg["domains"].items()}
    targets = {d: max(1, round(v)) for d, v in raw.items()}
    diff = args.facts - sum(targets.values())
    if diff != 0:
        doms = sorted(targets, key=lambda d: targets[d], reverse=True)
        i = 0
        while diff != 0:
            targets[doms[i % len(doms)]] += 1 if diff > 0 else -1
            diff += -1 if diff > 0 else 1
            i += 1
            if targets[doms[i % len(doms)]] < 1:
                i += 1

    kind_split = []
    for kind, cnt in QUERY_KIND_SPLIT:
        if kind == "adversarial":
            kind_split.append((kind, args.queries - sum(c for _, c in kind_split)))
        else:
            kind_split.append((kind, max(1, round(cnt * args.queries / 60))))

    run_cfg = {
        "facts": args.facts, "queries": args.queries, "seed": args.seed,
        "kind_split": kind_split, "domains_target": targets,
        "multi_min": int(args.facts * 0.10), "multi_max": int(args.facts * 0.14),
        "neg_min": int(args.facts * 0.08), "neg_max": int(args.facts * 0.12),
    }

    w = FactsWriter(sb, run_cfg, rng, cfg)
    for d, m in cfg["domains"].items():
        for fn in m["files"]:
            os.makedirs(os.path.dirname(os.path.join(sb, w._path(d, fn))), exist_ok=True)
            with open(os.path.join(sb, w._path(d, fn)), "a", encoding="utf-8") as fh:
                pass  # asegurar archivo existe
    gen_facts(w, run_cfg, rng, cfg)
    queries = gen_queries(rng, run_cfg, cfg, w.facts)

    errors = []
    ok = validate_g1(run_cfg, cfg, w.facts, queries, errors)

    manifest = {
        "benchmark": "bench-realistic", "version": "1.0", "seed": args.seed,
        "facts": len(w.facts), "queries": len(queries),
        "facts_by_domain": {d: sum(1 for f in w.facts if f["primary"] == d)
                            for d in cfg["domains"]},
        "multi_facts": sum(1 for f in w.facts if len(f["domains"]) > 1),
        "negative_facts": sum(1 for f in w.facts if f["negative"]),
        "queries_by_kind": {k: sum(1 for q in queries if q["kind"] == k)
                            for k, _ in QUERY_KIND_SPLIT},
        "g1_valid": ok,
    }

    if ok:
        with open(os.path.join(sb, "bench-realistic", "facts.json"), "w", encoding="utf-8") as f:
            json.dump(w.facts, f, ensure_ascii=False, indent=1)
        with open(os.path.join(sb, "bench-realistic", "queries.json"), "w", encoding="utf-8") as f:
            json.dump(queries, f, ensure_ascii=False, indent=1)
        b = json.dumps({"facts": w.facts, "queries": queries},
                       ensure_ascii=False, sort_keys=True).encode()
        manifest["manifest_sha256"] = hashlib.sha256(b).hexdigest()
        with open(os.path.join(sb, "bench-realistic", "manifest.sha256"), "w") as f:
            f.write(manifest["manifest_sha256"] + "\n")

    if args.json or not ok:
        print(json.dumps(manifest, ensure_ascii=False))
    if not ok:
        for e in errors:
            print(f"  ERROR {e}", file=sys.stderr)
        sys.exit(1)
    if not args.json:
        print(f"fixtures: {len(w.facts)} hechos, {len(queries)} queries, "
              f"multi={manifest['multi_facts']}, negativos={manifest['negative_facts']} (G1 OK)")


if __name__ == "__main__":
    main()
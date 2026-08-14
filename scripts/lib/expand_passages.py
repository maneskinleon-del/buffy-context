#!/usr/bin/env python3
# expand_passages.py — Expansión de candidatos de pasajes (rama P, Paso 13 F2).
# ─────────────────────────────────────────────────────────────────────────────
# Fuente: scripts/tests/evals/run-evidence-PC.sh (Paso 13, variante F2).
# F1/F2 no se adoptaron como SELECCIÓN (usaban el scorer E2, pRel 0.121), pero
# como GENERADOR de candidatos F2 demostró resolver el candidate gap del EVAL:
# Q08/Q06 pasaron de available 6 → 18/20 (System.md y CHANGELOG.md entran al
# pool vía esta expansión). El selector M3 (adoptado en 15A) opera sobre ese
# mismo pool expandido — es la combinación que completa el pipeline real.
#
# Pipeline (la variable en su lugar):
#   query → router (kno) → search (top-K pool) → EXPANSIÓN F2 (esta) → M3 → ctx
#
# Lógica F2 (idéntica al runner del Paso 13):
#   archivos_a_expandir = kno (router_knowledge) + top-K archivos del pool por
#       orden R1 (fuera de kno). Por CADA archivo → ventanas NO-SOLAPADAS de
#       2·PAS_PAD+1 líneas (tile_windows) → pasajes etiquetados rama 'P'.
#   gold_files NUNCA es señal de expansión (regla de la serie).
#
# Uso (CLI):
#   python3 expand_passages.py --repo DIR --kno '["a.md",...]' --pool <json|stdin>
#                             [--top-k 10] [--out <file>]
#   Entrada del pool: JSON [{"path","lineno","rank"}] — los candidatos del
#   search (path + línea de la aguja + rank R1). Solo se usa su orden (rank)
#   y path para elegir el top-K de archivos fuera de kno.
#   Salida: JSON {"kno": [...], "expanded_files": [...], "passages": [{"path","s","e","text","rama":"P"}]}
#
# Exit: 0 OK · 2 error de uso.

import json, os, sys

PAS_PAD = 4
WIN = 2 * PAS_PAD + 1  # 9 líneas no-solapadas (mismo tile que el Paso 13)


def file_lines(path, repo):
    try:
        with open(os.path.join(repo, path), encoding='utf-8', errors='replace') as f:
            return [l.rstrip('\n') for l in f]
    except OSError:
        return []


def tile_windows(total, pad=PAS_PAD):
    """Ventanas no-solapadas de 2·pad+1 líneas — la descomposición de 'todos
    los pasajes' consistente con G1-VENTANA ±pad (misma que el Paso 13)."""
    if total <= 0:
        return []
    out = []
    start = 1
    while start <= total:
        end = min(total, start + WIN - 1)
        out.append((start, end))
        start = end + 1
    return out


def expand(kno, pool_items, repo, top_k, max_passages=0):
    """Devuelve (expanded_files, passages).
    kno: lista de paths del router (router_knowledge).
    pool_items: candidatos del search ordenados por rank R1 — cada uno
        {"path": ..., "lineno": ...}. Solo interesan path + orden.
    max_passages: tope operativo de pasajes P generados (0 = sin tope).
        Guard de coste para el pipeline real: los archivos de sesión enormes
        (SESION-archive ~2000 líneas → 220+ tiles) inflan el pool y cada tile
        nuevo necesita un embed en frío. Prioridad kno > pool (los archivos del
        router se expanden completos; los del pool se recortan si el tope salta).
    """
    kno_set = set(kno)
    files = list(kno)  # F1 (y base de F2)
    # F2: + top-K archivos del pool por orden R1 (fuera de kno)
    seen_f = set()
    for it in pool_items:
        p = it.get("path", "")
        if not p or p in kno_set or p in seen_f:
            continue
        seen_f.add(p)
        files.append(p)
        if len(files) - len(kno) >= top_k:
            break

    expanded_files = []
    passages = []
    # Fase 1: archivos kno SIEMPRE completos (el router ya los eligió)
    for f in files[:len(kno)]:
        lines = file_lines(f, repo)
        if not lines:
            continue
        for (s0, e0) in tile_windows(len(lines)):
            txt = "\n".join(lines[s0 - 1:e0])
            if not txt.strip():
                continue
            passages.append({"path": f, "s": s0, "e": e0, "text": txt, "rama": "P"})
            expanded_files.append(f)
    # Fase 2: archivos del pool (F2) — recortados por el tope si hace falta
    if not (max_passages and len(passages) >= max_passages):
        for f in files[len(kno):]:
            lines = file_lines(f, repo)
            if not lines:
                continue
            for (s0, e0) in tile_windows(len(lines)):
                txt = "\n".join(lines[s0 - 1:e0])
                if not txt.strip():
                    continue
                if max_passages and len(passages) >= max_passages:
                    break
                passages.append({"path": f, "s": s0, "e": e0, "text": txt, "rama": "P"})
                expanded_files.append(f)
    return sorted(set(expanded_files)), passages


def main(argv):
    import argparse
    ap = argparse.ArgumentParser(description="Expansión de candidatos de pasajes (rama P / F2)")
    ap.add_argument("--repo", default=os.environ.get("BUFFY_REPO", os.path.expanduser("~/buffy-context")))
    ap.add_argument("--kno", default="[]", help="JSON: archivos del router_knowledge")
    ap.add_argument("--pool", default="", help="JSON: candidatos del search [{path,lineno,rank}] (default: stdin)")
    ap.add_argument("--top-k", type=int, default=10, help="top-K archivos del pool fuera de kno (F2)")
    ap.add_argument("--max-passages", type=int, default=0,
                    help="tope operativo de pasajes P (0 = sin tope); los kno entran completos")
    ap.add_argument("--out", default="", help="archivo de salida (default: stdout)")
    args = ap.parse_args(argv)

    try:
        kno = json.loads(args.kno) if args.kno else []
    except ValueError:
        print("error: --kno no es JSON válido", file=sys.stderr)
        return 2
    if not isinstance(kno, list):
        print("error: --kno debe ser una lista", file=sys.stderr)
        return 2

    if args.pool:
        try:
            pool_items = json.loads(args.pool)
        except ValueError as e:
            print("error: --pool no es JSON válido (%s)" % e, file=sys.stderr)
            return 2
    else:
        try:
            pool_items = json.load(sys.stdin)
        except ValueError as e:
            print("error: pool JSON inválido en stdin (%s)" % e, file=sys.stderr)
            return 2
    if not isinstance(pool_items, list):
        print("error: pool debe ser una lista", file=sys.stderr)
        return 2

    expanded_files, passages = expand(kno, pool_items, args.repo, args.top_k, args.max_passages)
    out = {
        "kno": sorted(kno),
        "expanded_files": expanded_files,
        "passages": passages,
        "pas_pad": PAS_PAD,
        "max_passages": args.max_passages,
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

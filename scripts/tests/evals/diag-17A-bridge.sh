#!/usr/bin/env bash
# diag-17A-bridge.sh — Paso 17.1: diagnóstico del puente semántico (Q01/Q05)
# ─────────────────────────────────────────────────────────────────────────────
# Objetivo (spec 17.1, decisión del usuario 2026-08-14): inspeccionar Q01/Q05
# sobre la config CONGELADA de 16B y registrar:
#   - consulta original
#   - expansión H1 actual (expand_query.py DICT_H1)
#   - términos generados
#   - candidatos recuperados (pool por rama L/X/S/P)
#   - candidatos relevantes que quedaron fuera (golds en pool, S1 score)
#   - dónde se pierde la señal (S1 vs gate 0.545, atribución final)
#
# Mecánica: NO toca run-granularity-PC.sh (congelado). Extrae el bloque python
# del runner (líneas del heredoc), inyecta un hook de trazado controlado por
# DIAG_TRACE=1, y lo ejecuta con la MISMA config (PADS=4, LIMIT=10, H1 real,
# sin oráculo, sin inyección de gold).
#
# Precondición: corpus congelado de 16B restaurado (git checkout bb33afa de los
# archivos de ai-context) e índice semántico aliased al hash actual del corpus
# (contenido idéntico a f36eaf1e, mtime difiere por el checkout).
#
# Uso:
#   diag-17A-bridge.sh [--out <json>] [--repo <dir>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run-granularity-PC.sh"
REPO="${REPO_DIR:-$HOME/buffy-context}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
OUT_FILE="${OUT_FILE:-/tmp/diag-17A-bridge.json}"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
EVAL_HASH="98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac"
CACHE_DIR="${CACHE_DIR:-$HOME/.cache/buffy-eval-semantic}"
TMP_PY="$(mktemp /tmp/diag-17A-XXXXXX.py)"
trap 'rm -f "$TMP_PY"' EXIT

# ── 1. extraer el bloque python del runner (heredoc, sin la línea del python3 y sin PY) ──
awk 'NR==83,NR==730' "$RUNNER" > "$TMP_PY"
# sanity: debe compilar
python3 -c "compile(open('$TMP_PY').read(), '$TMP_PY', 'exec')" || {
    echo "ERROR: extracción del bloque python del runner falló" >&2; exit 1
}

# ── 2. inyectar el hook de trazado después de 'ctx_passages = ctx' ──
python3 - "$TMP_PY" <<'PY'
import sys
p = sys.argv[1]
src = open(p).read()
anchor = '        ctx = gated[:LIMIT]\n        ctx_passages = ctx\n'
assert src.count(anchor) == 1, f"anchor ctx_passages no único: {src.count(anchor)}"
hook = anchor + '''
        # ── HOOK DIAGNÓSTICO 17A (DIAG_TRACE=1) — solo Q01/Q05 ──
        if os.environ.get("DIAG_TRACE") == "1" and qid in ("Q01", "Q05"):
            ramas_by_key = {}
            for it in pool:
                _p, _ln = it[0], it[1]
                _s, _e = item_pass[(_p, _ln)]
                ramas_by_key[(_p, _s, _e)] = sorted(it[4])
            def _contiene_needle(pg, needles):
                t = deaccent(pg["text"].lower())
                return [f for f in needles if deaccent(f.lower()) in t]
            print("\\n### TRACE %s query=%r" % (qid, query))
            print("### TRACE terms(H1 real)=%s" % terms)
            print("### TRACE gold_facts=%s" % gold_facts)
            print("### TRACE gold_files=%s" % sorted(gold_files))
            print("### TRACE pool=%d gated=%d (S1>=%.3f)" % (len(pool_pgs), len(gated), RESCUE_LOW))
            for f in gold_facts:
                nd = deaccent(f.lower())
                hits = [p for p in pool_pgs if nd in deaccent(p["text"].lower())]
                print("### needle %r → %d pasaje(s) EN el pool:" % (f, len(hits)))
                for p in hits[:6]:
                    print("    - %s:%d-%d S1=%.4f ramas=%s" % (
                        p["path"], p["s"], p["e"], p["_s1"],
                        ramas_by_key.get((p["path"], p["s"], p["e"]))))
                if not hits:
                    print("    (ningún pasaje del pool contiene el needle)")
            print("### top-15 del pool por S1:")
            for p in sorted(pool_pgs, key=lambda x: -x["_s1"])[:15]:
                nh = _contiene_needle(p, gold_facts)
                print("    - S1=%.4f %s:%d-%d ramas=%s needle=%s" % (
                    p["_s1"], p["path"], p["s"], p["e"],
                    ramas_by_key.get((p["path"], p["s"], p["e"])), nh))
            print("### ctx (%d pasajes elegidos):" % len(ctx_passages))
            for p in ctx_passages:
                nh = _contiene_needle(p, gold_facts)
                print("    - S1=%.4f %s:%d-%d needle=%s" % (p["_s1"], p["path"], p["s"], p["e"], nh))
'''
src = src.replace(anchor, hook, 1)
open(p, "w").write(src)
print("hook inyectado en", p)
PY

# ── 3. ejecutar con la MISMA config de 16B (PADS=4, LIMIT=10) ──
echo "── diag-17A: PADS=4 LIMIT=10 (config congelada 16B) ──"
DIAG_TRACE=1 OLLAMA_URL="$OLLAMA_URL" python3 "$TMP_PY" \
    "$REPO" "$EVAL" "$EVAL_HASH" "$OUT_FILE" "4" "10" "$CACHE_DIR" "false"

echo
echo "→ JSON diagnóstico: $OUT_FILE"

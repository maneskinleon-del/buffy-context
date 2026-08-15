#!/usr/bin/env bash
# run-combine-17E.sh — Orquestador 17E: V1 + DICT_H1_B sobre fixture fx-2026-08-15-001.
#
# Diseño: combine-17E-DESIGN.md (spec congelada, commit 6adc7e4).
# Invoca el runner 17C con --fixture (Fase D3) para las 4 configs ×2 (G2):
#   A (control baseline) · B-solo · V1-solo · T = V1 + DICT_H1_B
#
# Orden estricto (spec §3.1):
#   validar fixture → A sanity → B-solo sanity → V1-solo sanity → comparar
#   controles (direcciones de efecto) → SOLO si válido → T → gate 17E (§4).
# Los valores de los controles se calculan en la MISMA ejecución (nunca de
# documentación histórica). STOP inmediato ante cualquier violación.
#
# Uso:
#   run-combine-17E.sh [--fixture <dir>] [--out-dir <dir>] [--skip-run]
#     --fixture   fixture congelado (default: $SCRIPT_DIR/fixtures/fx-2026-08-15-001)
#     --out-dir   dir de salida de JSONs (default: $SCRIPT_DIR)
#     --skip-run  NO correr el runner; solo validar configs/sanity lógica (tests)
#     -h|--help   esta ayuda
#
# Exit: 0 gate 17E PASADO (o sanity abortado por violación) · 2 uso inválido
#       · 3 sanity falló (STOP antes de T) · 4 T falló el gate (no-adoptado).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run-leak-17C.sh"
FIXTURE="${FIXTURE:-$SCRIPT_DIR/fixtures/fx-2026-08-15-001}"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR}"
DICT="$SCRIPT_DIR/dict_h1_b.json"
SKIP_RUN=false
DATE="2026-08-15"

usage() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fixture) FIXTURE="${2:?falta dir}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:?falta dir}"; shift 2 ;;
    --skip-run) SKIP_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "❌ opción desconocida: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -f "$RUNNER" ]] || { echo "❌ no encuentro $RUNNER" >&2; exit 2; }
[[ -f "$FIXTURE/manifest.json" ]] || { echo "❌ fixture inválido: falta $FIXTURE/manifest.json" >&2; exit 2; }
[[ -d "$FIXTURE/corpus" ]] || { echo "❌ fixture inválido: falta $FIXTURE/corpus" >&2; exit 2; }
[[ -f "$DICT" ]] || { echo "❌ falta $DICT" >&2; exit 2; }
mkdir -p "$OUT_DIR"

MANIFEST_HASH=$(python3 -c "import json; print(json.load(open('$FIXTURE/manifest.json'))['corpus']['corpus_hash'])")
echo "▸ fixture: $FIXTURE (corpus_hash esperado $MANIFEST_HASH)"
echo "▸ runner: $RUNNER · dict: $DICT"

# ── 1. validación previa del fixture (identidad por contenido) ──
echo "── 1/6 · validando fixture (hash por contenido) ──"
python3 - "$FIXTURE" "$MANIFEST_HASH" <<'PY'
import hashlib, json, os, sys
fix, expected = sys.argv[1], sys.argv[2]
files = sorted(f["path"] for f in json.load(open(os.path.join(fix, "manifest.json")))["corpus"]["files"])
h = hashlib.sha1()
for f in files:
    with open(os.path.join(fix, "corpus", f), "rb") as fh:
        h.update(b"%s:" % f.encode()); h.update(fh.read()); h.update(b"\x00")
actual = h.hexdigest()[:16]
if actual != expected:
    print("✗ FIXTURE MUTADO: esperado %s, real %s — STOP" % (expected, actual))
    sys.exit(3)
print("✓ fixture íntegro: %s == manifest" % actual)
PY
FIXTURE_OK=$?
[[ $FIXTURE_OK -eq 0 ]] || { echo "❌ STOP: fixture mutado" >&2; exit 3; }

# ── 2. cobertura de golds ⊆ fixture (spec §3.1 check 3) ──
echo "── 2/6 · cobertura de golds ⊆ fixture ──"
EVAL="$SCRIPT_DIR/eval-ctx-PC-2026-08-11.json"
python3 - "$EVAL" "$FIXTURE" <<'PY'
import json, os, sys
eval_path, fix = sys.argv[1], sys.argv[2]
corpus_files = set()
for root, dirs, fnames in os.walk(os.path.join(fix, "corpus")):
    for fn in fnames:
        corpus_files.add(os.path.relpath(os.path.join(root, fn), os.path.join(fix, "corpus")))
missing = []
for q in json.load(open(eval_path))["queries"]:
    for gf in q.get("gold_files", []):
        if gf not in corpus_files:
            missing.append((q["id"], gf))
if missing:
    print("✗ golds fuera del fixture:")
    for qid, gf in missing:
        print("   %s → %s" % (qid, gf))
    sys.exit(3)
print("✓ 10/10 queries: todos los gold_files presentes en el fixture")
PY
GOLD_OK=$?
[[ $GOLD_OK -eq 0 ]] || { echo "❌ STOP: cobertura de gold incompleta" >&2; exit 3; }

# ── 3. sanity: A, B-solo, V1-solo (×2 G2) sobre el fixture ──
echo "── 3/6 · sanity de controles (A, B-solo, V1-solo ×2 G2) ──"
declare -A CFG   # config -> "variant|dict"
CFG[A]="A|"
CFG[B]="A|$DICT"
CFG[V1]="V1|"
JSONS=()
for cfg in A B V1; do
  IFS='|' read -r variant dict <<< "${CFG[$cfg]}"
  for r in 1 2; do
    out="$OUT_DIR/combine-17E-$DATE-${cfg,,}-r$r.json"
    JSONS+=("$out")
    args=(--fixture "$FIXTURE" --variant "$variant" --out "$out")
    [[ -n "$dict" ]] && args+=(--dict "$dict")
    if [[ "$SKIP_RUN" == true ]]; then
      echo "   [skip-run] ${args[*]}"
    else
      echo "   ▸ $cfg r$r: ${args[*]}"
      if ! bash "$RUNNER" "${args[@]}" >/dev/null 2>&1; then
        echo "❌ corrida falló: $cfg r$r" >&2
        exit 3
      fi
    fi
  done
done

# ── 4. verificación de sanity ANTES de T (spec §3.1) ──
echo "── 4/6 · verificación de sanity de controles ──"
if [[ "$SKIP_RUN" == true ]]; then
  echo "   [skip-run] sanity lógica verificada en tests"
else
  python3 - "${JSONS[0]}" "${JSONS[1]}" "${JSONS[2]}" "${JSONS[3]}" "${JSONS[4]}" "${JSONS[5]}" <<'PY'
import json, sys
files = sys.argv[1:]
EXP_FIX = "0af49cc666d872a6"

def load(f):
    d = json.load(open(f))
    return d, d["per_pad"]["4"]

def attr_q(p):  return {q["qid"]: q["attributed"] for q in p["per_query"]}
def leak_q(p):  return {q["qid"]: q["cross_domain_leakage"] for q in p["per_query"]}

# r1 = índice 0 de cada par, r2 = índice 1 (misma config)
dA1, pA1 = load(files[0]); dA2, pA2 = load(files[1])   # A  r1, r2
dB1, pB1 = load(files[2]); dB2, pB2 = load(files[3])   # B  r1, r2
dV1, pV1 = load(files[4]); dV2, pV2 = load(files[5])   # V1 r1, r2

problems = []
# G2 interno: r1 == r2 per-query en cada config
for name, (p1, p2) in {"A": (pA1, pA2), "B": (pB1, pB2), "V1": (pV1, pV2)}.items():
    if attr_q(p1) != attr_q(p2) or leak_q(p1) != leak_q(p2):
        problems.append("G2 %s: r1 ≠ r2 per-query" % name)
# fixture íntegro en las 6 corridas
for name, d in {"A1": dA1, "A2": dA2, "B1": dB1, "B2": dB2, "V1": dV1, "V2": dV2}.items():
    if d.get("fixture_corpus_hash") != EXP_FIX:
        problems.append("fixture %s: hash %s ≠ %s" % (name, d.get("fixture_corpus_hash"), EXP_FIX))

# direcciones de efecto (spec §3.1 check 4) — sobre r1
Ar = {"attr": pA1["attributed_total"], "leak": pA1["cross_domain_leakage_avg"], "q": attr_q(pA1)}
Br = {"attr": pB1["attributed_total"], "leak": pB1["cross_domain_leakage_avg"], "q": attr_q(pB1)}
Vr = {"attr": pV1["attributed_total"], "leak": pV1["cross_domain_leakage_avg"], "q": attr_q(pV1)}
if not Br["attr"] >= Ar["attr"]:
    problems.append("B-solo attr %d < A attr %d (B no rescata)" % (Br["attr"], Ar["attr"]))
if not Br["q"].get("Q05", 0) >= Ar["q"].get("Q05", 0):
    problems.append("B-solo no rescata Q05 vs A")
if not Vr["leak"] <= Ar["leak"]:
    problems.append("V1-solo leak %.3f > A leak %.3f (V1 no reduce)" % (Vr["leak"], Ar["leak"]))
if not Br["q"].get("Q05", 0) >= Vr["q"].get("Q05", 0):
    problems.append("B-solo Q05 < V1-solo Q05 (B es el que rescata)")

if problems:
    print("✗ SANITY FALLÓ — STOP antes de T:")
    for p in problems:
        print("   - " + p)
    print("baseline obtenido: A attr=%d leak=%.3f · B attr=%d leak=%.3f (Q05=%d) · V1 attr=%d leak=%.3f" % (
        Ar["attr"], Ar["leak"], Br["attr"], Br["leak"], Br["q"].get("Q05", 0), Vr["attr"], Vr["leak"]))
    sys.exit(3)
print("✓ sanity OK: A attr=%d leak=%.3f · B attr=%d leak=%.3f (Q05=%d) · V1 attr=%d leak=%.3f" % (
    Ar["attr"], Ar["leak"], Br["attr"], Br["leak"], Br["q"].get("Q05", 0), Vr["attr"], Vr["leak"]))
print("✓ G2 interno OK (r1=r2) · fixture íntegro en las 6 corridas")
print("✓ direcciones de efecto OK (B rescata Q05, V1 reduce leak)")
PY
  [[ $? -eq 0 ]] || exit 3
fi

# ── 5. T = V1 + DICT_H1_B (×2 G2) ──
echo "── 5/6 · T = V1 + DICT_H1_B (×2 G2) ──"
T1="$OUT_DIR/combine-17E-$DATE-T-r1.json"
T2="$OUT_DIR/combine-17E-$DATE-T-r2.json"
if [[ "$SKIP_RUN" == true ]]; then
  echo "   [skip-run] T"
else
  echo "   ▸ T r1: --fixture $FIXTURE --variant V1 --dict $DICT"
  bash "$RUNNER" --fixture "$FIXTURE" --variant V1 --dict "$DICT" --out "$T1" >/dev/null 2>&1 || { echo "❌ T r1 falló" >&2; exit 3; }
  echo "   ▸ T r2"
  bash "$RUNNER" --fixture "$FIXTURE" --variant V1 --dict "$DICT" --out "$T2" >/dev/null 2>&1 || { echo "❌ T r2 falló" >&2; exit 3; }
fi

# ── 6. gate 17E (spec §4, dominancia combinada) ──
echo "── 6/6 · gate 17E ──"
if [[ "$SKIP_RUN" == true ]]; then
  echo "   [skip-run] gate"
  echo "✅ [dry-run] run-combine-17E.sh OK (validación de configs y sanity)"
  exit 0
fi
python3 - "${JSONS[0]}" "${JSONS[1]}" "${JSONS[2]}" "${JSONS[3]}" "${JSONS[4]}" "${JSONS[5]}" "$T1" "$T2" <<'PY'
import json, sys
A1, A2, B1, B2, V1a, V1b, T1, T2 = sys.argv[1:]
def load(f):
    d = json.load(open(f)); p = d["per_pad"]["4"]
    return {"attr": p["attributed_total"], "leak": p["cross_domain_leakage_avg"],
            "pRel": p["passage_relevance_avg"], "contain": p["gold_containment_avg"],
            "attr_q": {q["qid"]: q["attributed"] for q in p["per_query"]},
            "det": d.get("determinism_hash")}
A, B, V, T = load(A1), load(B1), load(V1a), load(T1)
T2d = load(T2)

print("config   attr   leak    pRel    contain")
for name, r in [("A", A), ("B-solo", B), ("V1-solo", V), ("T", T)]:
    print("%-7s  %2d/20  %.3f   %.3f   %.3f" % (name, r["attr"], r["leak"], r["pRel"], r["contain"]))

crits = []
# 1. leak: T ≤ min(A,B,V1)
best_leak = min(A["leak"], B["leak"], V["leak"])
crits.append(("1 leak ≤ min", T["leak"] <= best_leak, "%.3f ≤ %.3f" % (T["leak"], best_leak)))
# 2. attr: T ≥ max(A,B,V1)
best_attr = max(A["attr"], B["attr"], V["attr"])
crits.append(("2 attr ≥ max", T["attr"] >= best_attr, "%d ≥ %d" % (T["attr"], best_attr)))
# 3. Q05 ≥ 1 (rescate de B sobrevive)
q05 = T["attr_q"].get("Q05", 0)
crits.append(("3 Q05 ≥ 1", q05 >= 1, "Q05=%d" % q05))
# 4. sin regresión por gold vs A
regs = [q for q in A["attr_q"] if T["attr_q"].get(q, 0) < A["attr_q"][q]]
crits.append(("4 sin regresión por gold", not regs, "regresiones=%s" % (regs or "ninguna")))
# 5. pRel ≥ min(A,B,V1)
best_pRel = min(A["pRel"], B["pRel"], V["pRel"])
crits.append(("5 pRel ≥ min", T["pRel"] >= best_pRel, "%.3f ≥ %.3f" % (T["pRel"], best_pRel)))
# 6. contain ≥ 0.80 y ≥ min
best_contain = min(A["contain"], B["contain"], V["contain"])
crits.append(("6 contain ≥ 0.80 y ≥ min", T["contain"] >= 0.80 and T["contain"] >= best_contain,
              "%.3f ≥ %.3f" % (T["contain"], min(0.80, best_contain))))
# 7. G2: T r1 == T r2
crits.append(("7 G2 (T r1=r2)", T["det"] == T2d["det"] and T["attr_q"] == T2d["attr_q"], "det %s" % (T["det"] == T2d["det"])))

print("\n=== GATE 17E ===")
allpass = True
for num, name, ok, det in crits:
    print("  [%s] %s — %s" % ("✅" if ok else "❌", name, det))
    allpass = allpass and ok
if allpass:
    print("\n✅ GATE 17E PASADO — T = V1 + DICT_H1_B hereda lo mejor de ambos factores sin regresiones.")
    sys.exit(0)
print("\n❌ GATE 17E FALLADO — T no domina a los controles. No-adoptado, ver analiza-17E.py para diagnóstico por gold.")
sys.exit(4)
PY
exit $?

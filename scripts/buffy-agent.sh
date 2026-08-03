#!/usr/bin/env bash
# buffy-agent.sh — Orquestador del ciclo operativo de buffy-context.
# Preflight (doctor --json) → reparar (repair --auto) → verify → carga (router).
# Envoltura mínima: no reimplementa lógica, encadena los scripts ya confiables.
#
# Uso:
#   buffy-agent.sh                      → Ciclo completo (preflight + repair + verify)
#   buffy-agent.sh "mensaje del usuario" → Igual + emite archivos a cargar (router)
#   buffy-agent.sh --no-repair          → Solo preflight + carga (sin reparar)
#   buffy-agent.sh --json               → Resultado en JSON (CI / protocolo)
#   buffy-agent.sh --repo RUTA          → Ciclo sobre otro checkout
#   buffy-agent.sh --help               → Esta ayuda
#
# Exit codes:
#   0 → Consistente tras el ciclo (o solo advertencias)
#   1 → Quedan errores de drift que requieren decisión humana
#   2 → Error de uso o fallo
#
# Creado: 2026-08-03

# ── Resolver repo (mismo patrón que doctor/repair) ────────
SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
DOCTOR="$SCRIPT_DIR/buffy-doctor.sh"
REPAIR="$SCRIPT_DIR/buffy-repair.sh"
ROUTER="$SCRIPT_DIR/buffy-router.sh"
NO_REPAIR=false
JSON_OUT=false
MESSAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="$2"; shift 2 ;;
    --no-repair) NO_REPAIR=true; shift ;;
    --json) JSON_OUT=true; shift ;;
    -h|--help)
      sed -n '2,16p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] && MESSAGE="$*"

for s in "$DOCTOR" "$REPAIR" "$ROUTER"; do
  if [ ! -f "$s" ]; then
    echo "❌ No encuentro $s (¿checkout de buffy-context incompleto?)" >&2
    exit 2
  fi
done

say() { [ "$JSON_OUT" = true ] || echo "$1"; }

# ── Preflight (1/4) ───────────────────────────────────────
PRE_JSON="$(bash "$DOCTOR" --json --repo "$REPO_DIR" 2>/dev/null || true)"
if echo "$PRE_JSON" | grep -q 'INVALID_REPO'; then
  echo "❌ No es un checkout de buffy-context: $REPO_DIR" >&2
  exit 2
fi
PRE_ERRS="$(echo "$PRE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null)"
PRE_WARNS="$(echo "$PRE_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null)"
if ! [[ "$PRE_ERRS" =~ ^[0-9]+$ ]] || ! [[ "$PRE_WARNS" =~ ^[0-9]+$ ]]; then
  echo "❌ Preflight falló (doctor --json no devolvió JSON válido)" >&2
  exit 2
fi
say "🤖 buffy-agent — ciclo operativo"
say "   repo: $REPO_DIR"
say ""
say "🔍 [1/4] Preflight (doctor --json)"
say "   errors=$PRE_ERRS warnings=$PRE_WARNS — $([ "$PRE_ERRS" = "0" ] && echo '✅ healthy' || echo '⚠️  hay drift')"

# ── Repair (2/4) — solo si hay drift y no se pidió --no-repair ──
REPAIR_RAN=false
RESULT_TSV=""
if [ "$PRE_ERRS" != "0" ]; then
  if [ "$NO_REPAIR" = true ]; then
    say "⏭️  [2/4] Repair omitido (--no-repair)"
  else
    say "🔧 [2/4] Repair (--auto)"
    REPAIR_JSON="$(bash "$REPAIR" --auto --json --repo "$REPO_DIR" 2>/dev/null || true)"
    REPAIR_RAN=true
    REPAIR_TSV="$(printf '%s' "$REPAIR_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
out = []
for a in d.get('applied', []):
    out.append('applied|%s|%s' % (a.get('fix', ''), a.get('target', '')))
for r in d.get('review_required', []):
    out.append('review|%s|%s' % (r.get('fix', ''), r.get('target', '')))
print('\n'.join(out))
" 2>/dev/null)"
    if [ -n "$REPAIR_TSV" ]; then RESULT_TSV="$REPAIR_TSV"$'\n'; fi
    N_APPLIED=$(printf '%s\n' "$REPAIR_TSV" | grep -c '^applied' || true)
    N_REVIEW=$(printf '%s\n' "$REPAIR_TSV" | grep -c '^review' || true)
    say "   aplicados=$N_APPLIED · review_requerido=$N_REVIEW"
  fi
fi

# ── Verify (3/4) ──────────────────────────────────────────
POST_JSON="$(bash "$DOCTOR" --json --repo "$REPO_DIR" 2>/dev/null || true)"
POST_ERRS="$(echo "$POST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo "?")"
POST_WARNS="$(echo "$POST_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo "?")"
if ! [[ "$POST_ERRS" =~ ^[0-9]+$ ]] || ! [[ "$POST_WARNS" =~ ^[0-9]+$ ]]; then
  echo "❌ Verify falló (doctor --json no devolvió JSON válido tras el ciclo)" >&2
  exit 2
fi
say ""
say "✅ [3/4] Verify (doctor --json)"
say "   errors=$POST_ERRS (antes: $PRE_ERRS) · warnings=$POST_WARNS"

# ── Load (4/4) — solo si hay mensaje ──────────────────────
if [ -n "$MESSAGE" ]; then
  if [ "$JSON_OUT" = true ]; then
    ROUTER_JSON="$(bash "$ROUTER" --json "$MESSAGE" 2>/dev/null || true)"
    LOAD_TSV="$(printf '%s' "$ROUTER_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
out = []
for kind in ('base', 'knowledge', 'skills', 'scripts'):
    for f in d.get(kind, []):
        out.append('load|%s|%s' % (kind, f))
print('\n'.join(out))
" 2>/dev/null)"
    [ -n "$LOAD_TSV" ] && RESULT_TSV+="$LOAD_TSV"
  else
    say ""
    say "📂 [4/4] Carga (buffy-router)"
    bash "$ROUTER" "$MESSAGE"
  fi
fi

# ── Salida ────────────────────────────────────────────────
if [ "$JSON_OUT" = true ]; then
  printf '%s' "$RESULT_TSV" | python3 -c "
import json, sys
lines = sys.stdin.read().splitlines()
applied, review, load = [], [], []
for ln in lines:
    parts = ln.split('|', 3)
    if len(parts) < 3:
        continue
    kind = parts[0]
    if kind == 'applied':
        applied.append({'fix': parts[1], 'target': parts[2]})
    elif kind == 'review':
        review.append({'fix': parts[1], 'target': parts[2]})
    elif kind == 'load':
        load.append({'kind': parts[1], 'file': parts[2]})
data = {
    'repo': sys.argv[1],
    'preflight': {'errors': int(sys.argv[2]), 'warnings': int(sys.argv[3]), 'healthy': int(sys.argv[2]) == 0},
    'repair': {'ran': sys.argv[4] == 'true', 'applied': applied, 'review_required': review},
    'verify': {'errors': int(sys.argv[5]), 'warnings': int(sys.argv[6]), 'healthy': int(sys.argv[5]) == 0},
    'load': {'message': sys.argv[7], 'files': load} if sys.argv[7] else None,
    'ready': int(sys.argv[5]) == 0,
}
print(json.dumps(data, ensure_ascii=False, indent=2))
" "$REPO_DIR" "$PRE_ERRS" "$PRE_WARNS" "$REPAIR_RAN" "$POST_ERRS" "$POST_WARNS" "$MESSAGE" 2>/dev/null \
    || printf '{"repo":"%s","preflight":{"errors":%s,"warnings":%s,"healthy":%s},"repair":{"ran":%s,"applied":[],"review_required":[]},"verify":{"errors":%s,"warnings":%s,"healthy":%s},"load":null,"ready":false}\n' \
      "$REPO_DIR" "$PRE_ERRS" "$PRE_WARNS" "$([ "$PRE_ERRS" = "0" ] && echo true || echo false)" "$REPAIR_RAN" \
      "$POST_ERRS" "$POST_WARNS" "$([ "$POST_ERRS" = "0" ] && echo true || echo false)"
else
  say ""
  if [ "$POST_ERRS" = "0" ]; then
    say "✅ buffy-context: CONSISTENTE — listo para trabajar."
  else
    say "⚠️  Quedan $POST_ERRS error(es) de drift (requieren decisión humana)."
    say "   Detalle: 'buffy-doctor.sh --quick' · decidir: regenerar o actualizar docs."
  fi
fi

[[ "$POST_ERRS" =~ ^[0-9]+$ ]] && [ "$POST_ERRS" = "0" ] && exit 0 || exit 1

#!/usr/bin/env bash
# buffy-close-day.sh — Cierre de sesión automatizado (protocolo "cerrar día").
#
# El agente escribe el contexto (SESION.md/CONTINUE.md/CHANGELOG.md) y luego
# ejecuta este script para la parte mecánica del protocolo:
#
#   1. sync push de la memoria curada  → ai-context/memories (viaja por git)
#   2. Regenerar SNAPSHOT              → buffy-context.sh (queda local)
#   3. Doctor --quick                  → valida que el cierre esté consistente
#   4. Commit + push del repo          → "docs(sesion): cerrar día — <fecha>"
#   5. Apagar el PC (solo con --poweroff) → "cerrar día+1"
#
# Uso:
#   buffy-close-day.sh                     → protocolo completo
#   buffy-close-day.sh --message "texto"   → texto extra en el mensaje de commit
#   buffy-close-day.sh --no-push           → commit local, sin push
#   buffy-close-day.sh --skip-doctor       → no corre el doctor (solo pruebas)
#   buffy-close-day.sh --extra-repo RUTA   → commit+push adicional de otro repo
#   buffy-close-day.sh --repo RUTA         → cierre sobre otro checkout
#   buffy-close-day.sh --poweroff          → tras el cierre exitoso, APAGA el PC
#                                            ("cerrar día+1"). Env: BUFFY_POWEROFF_CMD
#                                            (default poweroff) y BUFFY_POWEROFF_DELAY
#                                            (default 5s) para pruebas/override.
#   buffy-close-day.sh --help              → esta ayuda
#
# Exit: 0 cierre completo · 1 algo bloquea el cierre (memoria en conflicto,
# doctor con fallos, apagado imposible) · 2 uso inválido.
#
# Creado: 2026-08-10 · --poweroff: 2026-08-14

set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
DOCTOR="$SCRIPT_DIR/buffy-doctor.sh"
MEMORY="$SCRIPT_DIR/buffy-memory.sh"
SNAPSHOT_CMD="$SCRIPT_DIR/buffy-context.sh"

MESSAGE=""
NO_PUSH=false
SKIP_DOCTOR=false
POWEROFF=false
POWEROFF_CMD="${BUFFY_POWEROFF_CMD:-poweroff}"
POWEROFF_DELAY="${BUFFY_POWEROFF_DELAY:-5}"
EXTRA_REPOS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --message) MESSAGE="$2"; shift 2 ;;
    --no-push) NO_PUSH=true; shift ;;
    --skip-doctor) SKIP_DOCTOR=true; shift ;;
    --poweroff) POWEROFF=true; shift ;;
    --extra-repo) EXTRA_REPOS+=("$2"); shift 2 ;;
    --repo) REPO_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,24p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "❌ opción desconocida: $1" >&2; exit 2 ;;
  esac
done

log() { printf '▸ %s\n' "$*"; }

# ── Preflight: herramientas del repo ───────────────────────
for s in "$MEMORY" "$SNAPSHOT_CMD" "$DOCTOR"; do
  if [ ! -f "$s" ]; then
    echo "❌ No encuentro $s (¿checkout de buffy-context incompleto?)" >&2
    exit 1
  fi
done
if [ ! -d "$REPO_DIR/.git" ]; then
  echo "❌ $REPO_DIR no es un repo git" >&2
  exit 1
fi
cd "$REPO_DIR"

# ── 1. Memoria curada → repo (viaja a GitHub) ─────────────
log "1/4 · sync push de la memoria curada"
if ! bash "$MEMORY" sync push; then
  echo "" >&2
  echo "❌ Cierre ABORTADO: la memoria curada está en conflicto (¿el otro dispositivo escribió?)." >&2
  echo "   Resolvé primero:  buffy-memory.sh sync pull --force   (el otro lado manda)" >&2
  echo "   o                 buffy-memory.sh sync push --force   (este lado manda)" >&2
  exit 1
fi

# ── 2. SNAPSHOT regenerado (queda local, no se versiona) ──
log "2/4 · regenerando SNAPSHOT"
bash "$SNAPSHOT_CMD" >/dev/null 2>&1 || echo "   ⚠ no se pudo regenerar el SNAPSHOT (seguimos igual)"

# ── 3. Doctor --quick ──────────────────────────────────────
if [ "$SKIP_DOCTOR" = false ]; then
  log "3/4 · doctor --quick"
  DOCTOR_OUT="$(bash "$DOCTOR" --quick 2>&1)" || {
    echo "$DOCTOR_OUT" | tail -25
    echo "" >&2
    echo "❌ Cierre ABORTADO: el doctor reporta errores. Repará los bloqueos y reintentá." >&2
    echo "   (Para forzar el cierre igual: --skip-doctor — no recomendado)" >&2
    exit 1
  }
  echo "$DOCTOR_OUT" | tail -3 | sed 's/^/   /'
else
  log "3/4 · doctor --quick (SKIP)"
fi

# ── 4. Commit + push ───────────────────────────────────────
DATE="$(date +%Y-%m-%d)"
TITLE="docs(sesion): cerrar día — $DATE"
[ -n "$MESSAGE" ] && TITLE="$TITLE · $MESSAGE"
log "4/4 · commit + push → '$TITLE'"

if [ -z "$(git status --porcelain)" ]; then
  log "   sin cambios pendientes en el repo"
else
  git add -A
  git commit -q -m "$TITLE" || { echo "❌ commit falló" >&2; exit 1; }
  log "   commit hecho"
fi

if [ "$NO_PUSH" = false ]; then
  if git push -q 2>/dev/null; then
    log "   push OK"
  else
    echo "⚠ push falló (¿sin red?) — el commit quedó local; pusheá luego" >&2
  fi
fi

# ── Repos extra tocados en la sesión ───────────────────────
for repo in "${EXTRA_REPOS[@]}"; do
  if [ ! -d "$repo/.git" ]; then
    echo "⚠ --extra-repo $repo no es repo git — lo salto" >&2
    continue
  fi
  log "   repo extra: $(basename "$repo")"
  ( cd "$repo"
    if [ -n "$(git status --porcelain)" ]; then
      git add -A && git commit -q -m "$TITLE"
    fi
    if [ "$NO_PUSH" = false ] && ! git push -q 2>/dev/null; then
      echo "⚠ push falló en $(basename "$repo") — commit quedó local" >&2
    fi )
done

log "✅ día cerrado: memoria sincronizada, SNAPSHOT fresco, repo al día."

# ── 5. Apagado ("cerrar día+1") — SOLO si el cierre llegó acá sin error ──
if [ "$POWEROFF" = true ]; then
  log "5/5 · apagando el PC (cerrar día+1)"
  if ! command -v "${POWEROFF_CMD%% *}" >/dev/null 2>&1; then
    echo "❌ no encuentro el comando de apagado: $POWEROFF_CMD" >&2
    exit 1
  fi
  sleep "$POWEROFF_DELAY"
  $POWEROFF_CMD || { echo "❌ el apagado falló: $POWEROFF_CMD" >&2; exit 1; }
fi

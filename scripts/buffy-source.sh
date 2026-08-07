#!/usr/bin/env bash
# buffy-source.sh — Resolvedor de jerarquía de autoridad de fuentes.
#
# Responde: "¿qué valor es EL AUTORITATIVO para este hecho cuando las fuentes
# se contradicen?" (caso 3 adversarial: USER dice Hyprland, INFO-core dice
# bspwm, facts.yaml dice bspwm verified, SNAPSHOT dice bspwm...).
#
# Jerarquía (de mayor a menor autoridad):
#   1. REAL-TIME SYSTEM  → valor observado AHORA (comandos del sistema)
#   2. FACTS (verified)  → facts.yaml con confidence 1.0 y TTL vigente
#   3. SNAPSHOT          → estado vivo generado (buffy-context.sh)
#   4. CONTINUE          → handoff de la última sesión
#   5. INFO-core         → contexto base documentado
#   6. INFERRED          → ningún dato: inferencia marcada como tal
#
# Uso:
#   buffy-source.sh --resolve kernel            → valor autoritativo de kernel
#   buffy-source.sh --resolve all               → tabla de todos los hechos
#   buffy-source.sh --resolve kernel --json     → JSON consumible
#   buffy-source.sh --repo RUTA                 → checkout específico
#   buffy-source.sh --no-live                   → ignora real-time (tests/CI:
#                                                  simula máquina sin sistema vivo)
#   buffy-source.sh --help                      → esta ayuda
#
# Exit: 0 siempre (es informativo — no hay error de drift).
# Creado: 2026-08-07 (jerarquía propuesta en auditoría E2E)

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
JSON_MODE=false
RESOLVE=""
NO_LIVE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="$2"; shift 2 ;;
    --json) JSON_MODE=true; shift ;;
    --no-live) NO_LIVE=true; shift ;;
    --resolve) RESOLVE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "❌ Opción desconocida: $1" >&2; exit 1 ;;
  esac
done

if [ ! -d "$REPO_DIR/ai-context" ]; then
  echo -e "${RED}❌ No es un checkout de buffy-context: $REPO_DIR${NC}" >&2
  exit 1
fi
[ -z "$RESOLVE" ] && RESOLVE="all"

# norm <valor> — normaliza prefijo v/V de versiones (para comparación)
norm() { echo "$1" | sed 's/^[vV]//'; }

# ── Fuentes ──────────────────────────────────────────────
SNAPSHOT_FILE="$(buffy_snapshot)"
FACTS_FILE="$REPO_DIR/ai-context/facts.yaml"
CONTINUE_FILE="$REPO_DIR/ai-context/CONTINUE.md"
INFO_FILE="$REPO_DIR/ai-context/INFO-core.md"
RULES_FILE="$REPO_DIR/ai-context/facts_rules.yaml"

# ── Valor REAL-TIME de un hecho ──────────────────────────
# Nivel 1: el sistema AHORA (comando en vivo o variable de entorno).
live_value() {
  local f="$1"
  case "$f" in
    os)        grep -E '^NAME=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"' ;;
    kernel)    uname -r 2>/dev/null ;;
    wm)        echo "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}" ;;
    rice)      [ -f "$HOME/.config/bspwm/.rice" ] && head -1 "$HOME/.config/bspwm/.rice" 2>/dev/null | tr -d '[:space:]' ;;
    shell)     basename "${SHELL:-}" ;;
    locale)    echo "${LANG:-}" ;;
    git)       git --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,3}' | head -1 ;;
    node)      node --version 2>/dev/null | sed 's/^v//' ;;
    npm)       npm --version 2>/dev/null ;;
    python3)   python3 --version 2>/dev/null | sed 's/^Python //' ;;
    codegraph) codegraph --version 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,3}' | head -1 ;;
    cargo|rustc|adb|fastboot|gh|vercel|uv)
      command -v "$f" >/dev/null 2>&1 && echo "instalado" || echo "" ;;
    *) echo "" ;;
  esac
}

# ── Valor de facts.yaml (nivel 2) ────────────────────────
facts_value() {
  local f="$1"
  [ -f "$FACTS_FILE" ] || return
  python3 -c "
import sys, datetime, yaml
try:
    d = yaml.safe_load(open('$FACTS_FILE')) or {}
    fact = d.get('facts', {}).get('$f')
    if not fact:
        sys.exit(0)
    v = fact.get('value', '')
    hoy = datetime.date.today()
    try:
        vd = datetime.date.fromisoformat(str(fact.get('verified', '')))
        ttl = int(fact.get('ttl_days', 0))
        vigente = (hoy - vd).days <= ttl
    except Exception:
        vigente = False
    status = fact.get('status', '')
    conf = fact.get('confidence', 0)
    if status == 'verified' and conf >= 0.99 and vigente:
        print(v)
except Exception:
    sys.exit(0)
" 2>/dev/null
}

# ── Valor de un .md (niveles 3-5) ────────────────────────
# Busca "fact: valor" o tablas "| **Fact** | valor |" en SNAPSHOT/INFO-core.
# Para hechos con versión (node/npm/python3/git/codegraph): busca el patrón
# "<fact> <v?version>" explícito, evitando falsos positivos de contexto.
md_value() {
  local f="$1" file="$2"
  [ -f "$file" ] || return
  local v
  case "$f" in
    node|npm|python3|git|codegraph)
      # "| **Node** | v26.4.0 |" (SNAPSHOT) o "node v26.4.0 ·" (CONTINUE/INFO)
      v="$(grep -iE "(\*\*)?${f}(\*\*)?[[:space:]]*[:|][[:space:]]*[vV]?[0-9]+" "$file" 2>/dev/null | head -1 | grep -oE '[vV]?[0-9]+(\.[0-9]+){1,3}' | head -1 | sed 's/^[vV]//')"
      if [ -n "$v" ]; then echo "$v"; return; fi
      v="$(grep -oiE "${f}[[:space:]]+[vV]?[0-9]+(\.[0-9]+){1,3}" "$file" 2>/dev/null | head -1 | grep -oE '[vV]?[0-9]+(\.[0-9]+){1,3}' | head -1 | sed 's/^[vV]//')"
      echo "$v" ;;
    os)
      # Anclado: inicio de línea o columna de tabla "| **OS** | ..." o "OS:"
      grep -iE "(^|[|*[:space:]])(\*\*)?os(\*\*)?[[:space:]]*[:|]" "$file" 2>/dev/null | head -1 | sed -E 's/.*[:|][[:space:]]*//; s/[|]*$//; s/`//g' | grep -oE '^[A-Za-z]+' ;;
    kernel)
      grep -iE "(\*\*)?kernel(\*\*)?[[:space:]]*[:|]" "$file" 2>/dev/null | head -1 | sed -E 's/.*[:|][[:space:]]*//; s/[|]*$//; s/`//g' | grep -oE '[0-9]+(\.[0-9]+)+[-a-z0-9]*' | head -1 ;;
    *)
      grep -iE "(\*\*)?${f}(\*\*)?[[:space:]]*[:|]" "$file" 2>/dev/null \
        | head -1 \
        | sed -E 's/.*[:|][[:space:]]*//; s/[|]*$//; s/`//g; s/^[[:space:]]+//; s/[[:space:]]+$//' \
        | grep -oE '[^[:space:]]+' | head -1 ;;
  esac
}

# ── Resolver UN hecho ────────────────────────────────────
resolve_fact() {
  local f="$1"
  local live facts snap cont info
  if [ "$NO_LIVE" = true ]; then
    live=""
  else
    live="$(live_value "$f")"
  fi
  facts="$(facts_value "$f")"
  snap="$(md_value "$f" "$SNAPSHOT_FILE")"
  cont="$(md_value "$f" "$CONTINUE_FILE")"
  info="$(md_value "$f" "$INFO_FILE")"

  local winner="" wvalue="" wlevel=""
  if [ -n "$live" ]; then
    winner="$live"; wvalue="$live"; wlevel="real-time"
  elif [ -n "$facts" ]; then
    winner="$facts"; wvalue="$facts"; wlevel="facts"
  elif [ -n "$snap" ]; then
    winner="$snap"; wvalue="$snap"; wlevel="snapshot"
  elif [ -n "$cont" ]; then
    winner="$cont"; wvalue="$cont"; wlevel="continue"
  elif [ -n "$info" ]; then
    winner="$info"; wvalue="$info"; wlevel="info-core"
  else
    wlevel="inferred"
  fi

  # Conflictos: TODAS las fuentes con valor que difieren del ganador
  # (incluida la que tiene el mismo nivel pero valor distinto; la del nivel
  # ganador con igual valor no es conflicto). Compara con v/V normalizado.
  local wnorm="$(norm "$wvalue")"
  local conflicts=""
  [ -n "$facts" ] && [ "$(norm "$facts")" != "$wnorm" ] && conflicts+="facts($facts) "
  [ -n "$snap" ] && [ "$(norm "$snap")" != "$wnorm" ] && conflicts+="snapshot($snap) "
  [ -n "$cont" ] && [ "$(norm "$cont")" != "$wnorm" ] && conflicts+="continue($cont) "
  [ -n "$info" ] && [ "$(norm "$info")" != "$wnorm" ] && conflicts+="info-core($info) "

  if [ "$JSON_MODE" = true ]; then
    python3 -c "import json; print(json.dumps({'fact':'$f','value':'$wvalue' if '$wvalue' else None,'source':'$wlevel','conflicts':'$conflicts'.strip().split() if '$conflicts'.strip() else []}, ensure_ascii=False))"
  else
    if [ "$wlevel" = "inferred" ]; then
      echo -e "  ${YELLOW}➖${NC} $f → (inferido — sin fuente) [inferred]"
    elif [ -n "$conflicts" ]; then
      echo -e "  ${GREEN}✅${NC} $f → ${CYAN}$wvalue${NC} [${GREEN}$wlevel${NC}] ${RED}⚠️ conflicto: $conflicts${NC}"
    else
      echo -e "  ${GREEN}✅${NC} $f → ${CYAN}$wvalue${NC} [$wlevel]"
    fi
  fi
}

# ── Hechos conocidos ─────────────────────────────────────
KNOWN_FACTS="os kernel wm rice shell locale git node npm python3 codegraph cargo rustc adb fastboot gh vercel uv"

if [ "$RESOLVE" = "all" ]; then
  for f in $KNOWN_FACTS; do
    resolve_fact "$f"
  done
else
  case " $KNOWN_FACTS " in
    *" $RESOLVE "*) resolve_fact "$RESOLVE" ;;
    *) echo -e "${RED}❌ Hecho desconocido: $RESOLVE (conocidos: $KNOWN_FACTS)${NC}" >&2; exit 1 ;;
  esac
fi

exit 0

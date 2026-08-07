#!/usr/bin/env bash
# buffy-verify.sh — Verificación FACTUAL del contexto (complementa a buffy-doctor).
#
#   buffy-doctor  → integridad ESTRUCTURAL (¿existe el archivo? ¿la skill? ¿drift?)
#   buffy-verify  → integridad FACTUAL (¿lo que dice el contexto sigue siendo VERDAD?)
#
# Compara las afirmaciones de ai-context/INFO-core.md (OS, kernel, WM, shell,
# herramientas de uso frecuente y sus versiones) contra el sistema real
# (os-release, uname, $SHELL, $XDG_CURRENT_DESKTOP, command -v, versiones).
#
# La distinción clave: una afirmación puede ser sintácticamente válida pero
# factualmente obsoleta (ej. "WM: cynthia" cuando ya se cambió el rice, o
# "npm 11.18.0" cuando ya hay 12.0.1). El doctor la daría por buena; verify no.
#
# Uso:
#   buffy-verify.sh            → Verificación completa (human)
#   buffy-verify.sh --repo RUTA → Verificar un checkout específico
#   buffy-verify.sh --quick    → Solo resumen (sin secciones)
#   buffy-verify.sh --json     → Salida JSON consumible por scripts (python3)
#   buffy-verify.sh --help     → Esta ayuda
#
# Exit codes:
#   0 → Verificación completada (stale/unknown se reportan como warning,
#       nunca fallan: indican documentación desactualizada, no errores de drift).
#   1 → No es un checkout de buffy-context o flag inválido.
#
# Creado: 2026-08-07

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Resolver repo ────────────────────────────────────────
SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
QUICK_MODE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="$2"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    --json) JSON_MODE=true; shift ;;
    -h|--help)
      sed -n '2,17p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      if [ "$JSON_MODE" = true ]; then
        python3 -c 'import json,sys; print(json.dumps({"repo":sys.argv[1],"verified":0,"stale":0,"unknown":0,"trust_score":0,"items":[{"level":"err","fact":"general","message":"Opción desconocida: "+sys.argv[2],"id":"UNKNOWN_OPTION","source":"flag"}],"_info":"verificación factual de ai-context/INFO-core.md vs sistema real"}, ensure_ascii=False))' "$REPO_DIR" "$1"
      else
        echo "❌ Opción desconocida: $1" >&2
      fi
      exit 1 ;;
  esac
done

if [ ! -d "$REPO_DIR/ai-context" ]; then
  if [ "$JSON_MODE" = true ]; then
    python3 -c 'import json,sys; print(json.dumps({"repo":sys.argv[1],"verified":0,"stale":0,"unknown":0,"trust_score":0,"items":[{"level":"err","fact":"general","message":"No es un checkout de buffy-context","id":"INVALID_REPO","source":"flag"}],"_info":"verificación factual de ai-context/INFO-core.md vs sistema real"}, ensure_ascii=False))' "$REPO_DIR"
  else
    echo -e "${RED}❌ No es un checkout de buffy-context: $REPO_DIR${NC}" >&2
    echo -e "${YELLOW}   Usa --repo RUTA al directorio del repo.${NC}" >&2
  fi
  exit 1
fi

INFO_CORE="$REPO_DIR/ai-context/INFO-core.md"
if [ ! -f "$INFO_CORE" ]; then
  if [ "$JSON_MODE" = true ]; then
    python3 -c 'import json,sys; print(json.dumps({"repo":sys.argv[1],"verified":0,"stale":0,"unknown":0,"trust_score":0,"items":[{"level":"err","fact":"general","message":"INFO-core.md ausente — sin hechos que verificar","id":"MISSING_INFO_CORE","source":"doc"}],"_info":"verificación factual de ai-context/INFO-core.md vs sistema real"}, ensure_ascii=False))' "$REPO_DIR"
  else
    echo -e "${RED}❌ INFO-core.md ausente en $INFO_CORE${NC}" >&2
  fi
  exit 1
fi

# ── Contadores ───────────────────────────────────────────
TOTAL_OK=0
TOTAL_STALE=0
TOTAL_UNKNOWN=0
JSON_ITEMS=""

# fact <tipo> <fact> <mensaje> <id> <target>
#   tipo: verified | stale | unknown
#   fact: nombre corto del hecho (ej. kernel, node_version)
#   target: ruta/archivo donde vive la afirmación (para reparación manual)
#   source: origen del dato (doc | system | env)
fact() {
  local tipo="$1" nombre="$2" msg="$3" id="${4:-}" target="${5:-INFO-core.md}"
  case "$tipo" in
    verified) TOTAL_OK=$((TOTAL_OK+1)) ;;
    stale)    TOTAL_STALE=$((TOTAL_STALE+1)) ;;
    unknown)  TOTAL_UNKNOWN=$((TOTAL_UNKNOWN+1)) ;;
  esac
  if [ "$JSON_MODE" = true ]; then
    JSON_ITEMS+="$tipo"$'\t'"$nombre"$'\t'"$msg"$'\t'"$id"$'\t'"$target"$'\n'
  fi
}

# has <archivo> <patrón> — greppea el INFO-core sin importar formato (MD/table/plain)
has() {
  grep -qiE "$2" "$1" 2>/dev/null
}

# presente <cmd> — ¿existe el binario en PATH (y en HOME si aplica)?
presente() {
  command -v "$1" >/dev/null 2>&1
}

# running <proc> — ¿hay un proceso con ese nombre corriendo?
running() {
  pgrep -x "$1" >/dev/null 2>&1 || pgrep -f "bin/$1" >/dev/null 2>&1
}

# versión extraída de un comando → limpia a "digitos.digitos.digitos" (tolera prefijos v/V/ver.)
ver_of() {
  local out
  out="$("$@" 2>/dev/null | head -1)"
  echo "$out" | grep -oE '[vV]?[0-9]+(\.[0-9]+){1,3}' | head -1 | sed 's/^[vV]//'
}

# version_fact <nombre> <cmd...> — compara la versión del sistema contra la que
# afirma INFO-core.md. La versión del doc se extrae con el mismo patrón de
# versión (tolera "git 2.55.0", "node v26.4.0", "npm 11.18.0").
version_fact() {
  local nombre="$1"; shift
  if ! presente "$nombre"; then
    fact stale "$nombre" "$nombre está documentado pero NO instalado" "TOOL_NOT_INSTALLED" "INFO-core.md"
    return
  fi
  local real doc_ver
  real="$(ver_of "$@")"
  doc_ver="$(grep -oE "$nombre[^·|]*?[vV]?[0-9]+(\.[0-9]+){1,3}" "$INFO_CORE" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+){1,3}' | head -1)"
  if [ -z "$real" ]; then
    fact unknown "$nombre" "$nombre presente pero no pude extraer su versión" "" "INFO-core.md"
  elif [ -n "$doc_ver" ] && [ "$real" != "$doc_ver" ]; then
    fact stale "$nombre" "$nombre: doc dice $doc_ver, sistema tiene $real" "VERSION_STALE" "INFO-core.md"
  else
    fact verified "$nombre" "$nombre $real ✓" "" "INFO-core.md"
  fi
}

# ── Sección: sistema ─────────────────────────────────────
section() {
  if [ "$JSON_MODE" = true ]; then
    JSON_ITEMS+="section"$'\t'"--"$'\t'"$1"$'\t'"--"$'\t'"--"$'\n'
  elif [ "$QUICK_MODE" != true ]; then
    echo -e "\n${CYAN}═══════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
  fi
}

# emite el resultado de un hecho simple
# check_fact <nombre> <patrón_doc> <"real"> <id> <target> [msg_ok]
check_fact() {
  local nombre="$1" patron="$2" real="$3" id="$4" target="${5:-INFO-core.md}" msg_ok="${6:-}"
  if [ -z "$real" ] || [ "$real" = "?" ]; then
    fact unknown "$nombre" "$nombre: no pude obtener el valor real del sistema" "$id" "$target"
  elif has "$INFO_CORE" "$patron"; then
    fact verified "$nombre" "${msg_ok:-$nombre: $real ✓}" "" "$target"
  else
    fact stale "$nombre" "$nombre: doc no menciona '$real' (revisar INFO-core.md)" "$id" "$target"
  fi
}

section "🖥️  Sistema (INFO-core.md vs realidad)"
OS_REAL="$(grep -E '^NAME=' /etc/os-release 2>/dev/null | head -1 | cut -d= -f2 | tr -d '"')"
KERNEL_REAL="$(uname -r 2>/dev/null)"
WM_REAL="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-?}}"
SHELL_REAL="$(basename "${SHELL:-}")"
TERM_PROC="alacritty"
LOCALE_REAL="${LANG:-?}"

if [ -n "$OS_REAL" ] && has "$INFO_CORE" 'EndeavourOS|endeavouros'; then
  fact verified "os" "OS: $OS_REAL ✓" "" "INFO-core.md"
else
  fact stale "os" "OS: doc no confirma '$OS_REAL'" "OS_STALE" "INFO-core.md"
fi

check_fact "kernel" "kernel [0-9]" "$KERNEL_REAL" "KERNEL_STALE"
check_fact "wm" "bspwm" "$WM_REAL" "WM_STALE"

# Rice del WM: extrae el nombre del rice que declara el doc y lo compara con el
# activo del sistema. El cambio de rice (ej. cynthia → vista) NO cambia "bspwm",
# así que verificar solo el WM dejaría pasar el caso más común de actualización.
RICE_DOC="$(grep -oE 'rice [a-z0-9._/-]+' "$INFO_CORE" | head -1 | awk '{print $2}')"
RICE_FILE="$HOME/.config/bspwm/.rice"
if [ -n "$RICE_DOC" ] && [ -f "$RICE_FILE" ]; then
  RICE_REAL="$(head -1 "$RICE_FILE" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$RICE_REAL" ] && [ "$RICE_REAL" != "$RICE_DOC" ]; then
    fact stale "rice" "rice: doc dice $RICE_DOC, sistema tiene $RICE_REAL (actualizar INFO-core.md)" "RICE_STALE" "INFO-core.md"
  else
    fact verified "rice" "rice: $RICE_REAL ✓" "" "INFO-core.md"
  fi
elif [ -n "$RICE_DOC" ]; then
  fact unknown "rice" "rice: doc declara $RICE_DOC pero no hay ~/.config/bspwm/.rice en este entorno" "" "INFO-core.md"
fi
check_fact "shell" "zsh" "$SHELL_REAL" "SHELL_STALE"
check_fact "locale" "es_CL" "$LOCALE_REAL" "LOCALE_STALE"

if running "$TERM_PROC"; then
  fact verified "terminal" "Terminal: $TERM_PROC corriendo ✓" "" "INFO-core.md"
else
  fact unknown "terminal" "Terminal: no veo proceso alacritty activo (¿sesión headless?)" "" "INFO-core.md"
fi
if running picom; then
  fact verified "compositor" "Compositor: picom corriendo ✓" "" "INFO-core.md"
else
  fact unknown "compositor" "Compositor: no veo picom corriendo (¿X no iniciado?)" "" "INFO-core.md"
fi

# Herramientas documentadas en "Herramientas de uso frecuente" (presencia)
section "🛠️  Herramientas (presencia)"
for t in git node npm python3 cargo rustc adb fastboot gh vercel uv codegraph; do
  if has "$INFO_CORE" "$t"; then
    if presente "$t"; then
      fact verified "$t" "$t instalado ✓" "" "INFO-core.md"
    else
      fact stale "$t" "$t documentado en INFO-core pero NO instalado" "TOOL_NOT_INSTALLED" "INFO-core.md"
    fi
  fi
done

# Versiones exactas que el doc afirma (tolera prefijos v/V)
section "🔢 Versiones (doc vs sistema)"
version_fact git git --version
version_fact node node --version
version_fact npm npm --version
version_fact python3 python3 --version
version_fact codegraph codegraph --version

# ── Resumen ──────────────────────────────────────────────
if [ "$JSON_MODE" = true ]; then
  if JSON_OUT=$(printf '%s' "$JSON_ITEMS" | python3 -c "
import json, sys
lines = sys.stdin.read().splitlines()
items = []
for ln in lines:
    parts = ln.split('\t', 4)
    if len(parts) < 3:
        continue
    level, fact_, msg = parts[0], parts[1], parts[2]
    id_ = parts[3] if len(parts) > 3 else ''
    target = parts[4] if len(parts) > 4 else ''
    item = {'level': level, 'fact': fact_, 'message': msg}
    if id_ and id_ != '--':
        item['id'] = id_
    if target and target != '--':
        item['target'] = target
    items.append(item)
verified = sum(1 for i in items if i['level'] == 'verified')
stale = sum(1 for i in items if i['level'] == 'stale')
unknown = sum(1 for i in items if i['level'] == 'unknown')
trust = round(100 * verified / max(1, verified + stale), 1)
data = {
  'repo': sys.argv[1],
  'verified': verified,
  'stale': stale,
  'unknown': unknown,
  'trust_score': trust,
  'items': items,
  '_info': 'verificación factual de ai-context/INFO-core.md vs sistema real',
}
print(json.dumps(data, ensure_ascii=False, indent=2))
" "$REPO_DIR" 2>/dev/null); then
    printf '%s\n' "$JSON_OUT"
  else
    printf '{"repo":"%s","verified":%s,"stale":%s,"unknown":%s,"trust_score":%s,"items":[],"_info":"verificación factual de ai-context/INFO-core.md vs sistema real"}\n' \
      "$REPO_DIR" "$TOTAL_OK" "$TOTAL_STALE" "$TOTAL_UNKNOWN"
  fi
else
  echo -e "  ${GREEN}✅ Verificados: $TOTAL_OK${NC}   ${YELLOW}⚠️  Obsoletos: $TOTAL_STALE${NC}   ℹ️  No verificables: $TOTAL_UNKNOWN${NC}"
  echo
  if [ "$TOTAL_STALE" -eq 0 ]; then
    echo -e "${GREEN}✅ INFO-core.md es FACTUALMENTE confiable (trust 100%).${NC}"
  else
    SCORE=$(( 100 * TOTAL_OK / (TOTAL_OK + TOTAL_STALE) ))
    echo -e "${YELLOW}⚠️  Hay $TOTAL_STALE afirmación(es) obsoleta(s) — actualizar INFO-core.md.${NC}"
    echo -e "${YELLOW}   Trust: $SCORE% (verificados $TOTAL_OK / obsoletos $TOTAL_STALE)${NC}"
  fi
  if [ "$TOTAL_UNKNOWN" -gt 0 ]; then
    echo -e "  ℹ️  $TOTAL_UNKNOWN hecho(s) no verificables en este entorno (procesos X, versiones no parseables)."
  fi
fi

exit 0

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
# Desde la auditoría 2: los hechos de herramientas/versiones son DECLARATIVOS
# (ai-context/facts_rules.yaml, consumido por scripts/lib/facts_engine.py) —
# agregar un hecho nuevo NO requiere tocar este script.
#
# La distinción clave: una afirmación puede ser sintácticamente válida pero
# factualmente obsoleta (ej. "WM: cynthia" cuando ya se cambió el rice, o
# "npm 11.18.0" cuando ya hay 12.0.1). El doctor la daría por buena; verify no.
#
# Uso:
#   buffy-verify.sh             → Verificación completa (human)
#   buffy-verify.sh --repo RUTA → Verificar un checkout específico
#   buffy-verify.sh --quick     → Solo resumen (sin secciones)
#   buffy-verify.sh --json      → Salida JSON consumible por scripts (python3)
#   buffy-verify.sh --update-facts → Genera/actualiza ai-context/facts.yaml
#                                    (provenance: source/confidence/scope/verified/ttl)
#   buffy-verify.sh --scope NOM → Scope para facts.yaml (default: hostname)
#   buffy-verify.sh --help      → Esta ayuda
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
UPDATE_FACTS=false
SCOPE_NAME="$(hostname 2>/dev/null || echo 'desconocido')"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="$2"; shift 2 ;;
    --quick) QUICK_MODE=true; shift ;;
    --json) JSON_MODE=true; shift ;;
    --update-facts) UPDATE_FACTS=true; shift ;;
    --scope) SCOPE_NAME="$2"; shift 2 ;;
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
declare -A FACT_VALUES=()   # nombre → valor real del sistema (provenance)
declare -A FACT_LEVELS=()   # nombre → verified|stale|unknown (provenance)

# fact <tipo> <fact> <mensaje> <id> <target> [real]
#   tipo: verified | stale | unknown
#   fact: nombre corto del hecho (ej. kernel, npm_version)
#   target: ruta/archivo donde vive la afirmación (para reparación manual)
#   real: valor real del sistema (opcional, para provenance)
fact() {
  local tipo="$1" nombre="$2" msg="$3" id="${4:-}" target="${5:-INFO-core.md}" real="${6:-}"
  case "$tipo" in
    verified) TOTAL_OK=$((TOTAL_OK+1)) ;;
    stale)    TOTAL_STALE=$((TOTAL_STALE+1)) ;;
    unknown)  TOTAL_UNKNOWN=$((TOTAL_UNKNOWN+1)) ;;
  esac
  if [ "$JSON_MODE" = true ]; then
    JSON_ITEMS+="$tipo"$'\t'"$nombre"$'\t'"$msg"$'\t'"$id"$'\t'"$target"$'\n'
  fi
  if [ "$UPDATE_FACTS" = true ] && [ -n "$real" ]; then
    FACT_VALUES["$nombre"]="$real"
    FACT_LEVELS["$nombre"]="$tipo"
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

# reglas_engine <sección> — delega herramientas/versiones al motor declarativo
# (facts_rules.yaml). Emite TSV: level|fact|msg|id|target|real → fact()
reglas_engine() {
  local line level nombre msg id target real
  while IFS=$'\t' read -r line; do
    [ -z "$line" ] && continue
    level="$(echo "$line" | cut -f1)"
    nombre="$(echo "$line" | cut -f2)"
    msg="$(echo "$line" | cut -f3)"
    id="$(echo "$line" | cut -f4)"
    target="$(echo "$line" | cut -f5)"
    real="$(echo "$line" | cut -f6)"
    fact "$level" "$nombre" "$msg" "$id" "${target:-INFO-core.md}" "$real"
  done < <(python3 "$SCRIPT_DIR/lib/facts_engine.py" "$REPO_DIR" 2>/dev/null)
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
    fact unknown "$nombre" "$nombre: no pude obtener el valor real del sistema" "$id" "$target" "$real"
  elif has "$INFO_CORE" "$patron"; then
    fact verified "$nombre" "${msg_ok:-$nombre: $real ✓}" "" "$target" "$real"
  else
    fact stale "$nombre" "$nombre: doc no menciona '$real' (revisar INFO-core.md)" "$id" "$target" "$real"
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
  fact verified "os" "OS: $OS_REAL ✓" "" "INFO-core.md" "$OS_REAL"
else
  fact stale "os" "OS: doc no confirma '$OS_REAL'" "OS_STALE" "INFO-core.md" "$OS_REAL"
fi

# Kernel: compara la versión que declara el doc contra la real (stale real, no
# solo presencia del patrón — el fix que pidió la auditoría 2).
KERNEL_DOC="$(grep -oE 'kernel[[:space:]]+[0-9]+(\.[0-9]+)+[-a-z0-9]*' "$INFO_CORE" | head -1 | grep -oE '[0-9]+(\.[0-9]+)+[-a-z0-9]*')"
if [ -n "$KERNEL_REAL" ] && [ -n "$KERNEL_DOC" ] && [ "$KERNEL_REAL" != "$KERNEL_DOC" ]; then
  fact stale "kernel" "kernel: doc dice $KERNEL_DOC, sistema tiene $KERNEL_REAL" "KERNEL_STALE" "INFO-core.md" "$KERNEL_REAL"
else
  check_fact "kernel" "kernel [0-9]" "$KERNEL_REAL" "KERNEL_STALE"
fi
check_fact "wm" "bspwm" "$WM_REAL" "WM_STALE"

# Rice del WM: extrae el nombre del rice que declara el doc y lo compara con el
# activo del sistema. El cambio de rice (ej. cynthia → vista) NO cambia "bspwm",
# así que verificar solo el WM dejaría pasar el caso más común de actualización.
# Extrae el nombre del rice que declara el doc (tolera markdown **nom** y el
# formato "gh0stzk/nombre"): toma la palabra tras "rice " y limpia asteriscos.
RICE_DOC="$(grep -oE 'rice [^()]+' "$INFO_CORE" | head -1 | sed -E 's/rice //' | sed 's/\*//g' | awk '{print $1}' | sed 's|.*/||')"
RICE_FILE="$HOME/.config/bspwm/.rice"
if [ -n "$RICE_DOC" ] && [ -f "$RICE_FILE" ]; then
  RICE_REAL="$(head -1 "$RICE_FILE" 2>/dev/null | tr -d '[:space:]')"
  if [ -n "$RICE_REAL" ] && [ "$RICE_REAL" != "$RICE_DOC" ]; then
    fact stale "rice" "rice: doc dice $RICE_DOC, sistema tiene $RICE_REAL (actualizar INFO-core.md)" "RICE_STALE" "INFO-core.md" "$RICE_REAL"
  else
    fact verified "rice" "rice: $RICE_REAL ✓" "" "INFO-core.md" "$RICE_REAL"
  fi
elif [ -n "$RICE_DOC" ]; then
  fact unknown "rice" "rice: doc declara $RICE_DOC pero no hay ~/.config/bspwm/.rice en este entorno" "" "INFO-core.md" ""
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

# Herramientas + versiones: reglas declarativas (ai-context/facts_rules.yaml)
section "🛠️  Herramientas y versiones (reglas declarativas)"
reglas_engine

# ── Provenance (--update-facts) ──────────────────────────
# Genera ai-context/facts.yaml: registro machine-readable de QUÉ sabemos,
# DE DÓNDE salió (source), QUÉ CONFIANZA tiene (confidence) y CUÁNDO se
# verificó (verified). Diferencia: HECHO CONFIRMADO (system) vs PREFERENCIA
# (user/inferred) — los datos del sistema se marcan con confidence 1.0.
if [ "$UPDATE_FACTS" = true ]; then
  FACTS_FILE="$REPO_DIR/ai-context/facts.yaml"
  VERIFIED_DATE="$(date +%F)"
  # Se serializa con python3: el TSV de FACT_VALUES/FACT_LEVELS es de confianza
  # (los valores vienen de comandos del sistema o del propio INFO-core, nunca
  # de input del usuario), así que el quoting YAML se delega al serializer.
  # Schema: value/source/confidence/status/verified/scope/ttl_days (auditoría 2).
  TSV_FACTS=""
  for k in "${!FACT_VALUES[@]}"; do
    TSV_FACTS+="$k"$'\t'"${FACT_VALUES[$k]}"$'\t'"${FACT_LEVELS[$k]}"$'\n'
  done
  if printf '%s' "$TSV_FACTS" | python3 -c "
import sys, yaml
lines = sys.stdin.read().splitlines()
facts = {}
for ln in lines:
    parts = ln.split('\t', 2)
    if len(parts) < 3:
        continue
    name, value, level = parts[0], parts[1], parts[2]
    confidence = 1.0 if level == 'verified' else (0.4 if level == 'stale' else 0.2)
    facts[name] = {
        'value': value,
        'source': 'system',
        'confidence': confidence,
        'status': level,
        'verified': sys.argv[1],
        'scope': sys.argv[2],
        'ttl_days': 30,
    }
print(yaml.dump({'facts': facts}, sort_keys=False, allow_unicode=True, default_flow_style=False), end='')
" "$VERIFIED_DATE" "$SCOPE_NAME" > "$FACTS_FILE".tmp 2>/dev/null; then
    mv "$FACTS_FILE.tmp" "$FACTS_FILE"
    echo -e "  ℹ️  Provenance actualizada: ${CYAN}$FACTS_FILE${NC} (${#FACT_VALUES[@]} hechos · scope $SCOPE_NAME · verificados $VERIFIED_DATE)"
  else
    echo -e "  ${YELLOW}⚠️  No pude generar facts.yaml (¿falta PyYAML?) — verificación sin provenance.${NC}"
  fi
fi

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

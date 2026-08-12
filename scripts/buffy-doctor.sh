#!/usr/bin/env bash
# buffy-doctor.sh — Auditoría de salud del ecosistema buffy-context.
# Compara lo que la documentación REFERENCIA con lo que EXISTE en disco.
# Detecta drift: skills/documentos prometidos pero inexistentes (o al revés).
#
# Uso:
#   buffy-doctor.sh            → Auditoría completa
#   buffy-doctor.sh --repo RUTA → Auditar un checkout específico
#   buffy-doctor.sh --quick    → Solo resumen de errores (sin secciones)
#   buffy-doctor.sh --json     → Salida JSON consumible por scripts (python3)
#   buffy-doctor.sh --help     → Esta ayuda
#
# Exit codes:
#   0  → Todo consistente (o solo advertencias)
#   1  → Hay skills/documentos referenciados pero inexistentes
#
# Creado: 2026-08-03

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Resolver repo ────────────────────────────────────────
# Resuelve symlinks (p.ej. ~/.local/bin/buffy-doctor.sh) para encontrar el repo real.
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
      sed -n '2,15p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      if [ "$JSON_MODE" = true ]; then
        python3 -c 'import json,sys; print(json.dumps({"repo":sys.argv[1],"ok":0,"warnings":0,"errors":1,"healthy":False,"items":[{"level":"err","section":"General","message":"Opción desconocida: "+sys.argv[2],"id":"UNKNOWN_OPTION","fix":"","safe":False}]}, ensure_ascii=False))' "$REPO_DIR" "$1"
      else
        echo "❌ Opción desconocida: $1" >&2
      fi
      exit 1 ;;
  esac
done

# ── Contadores globales ───────────────────────────────────
TOTAL_OK=0
TOTAL_WARN=0
TOTAL_ERR=0
STALE_HOURS=12   # antigüedad máxima de SNAPSHOT.md antes de advertir

# En modo --quick: solo se muestran ⚠️/❌ y el resumen (sin ✅ ni cabeceras)
# En modo --json: se acumulan entradas TSV sin imprimir:
#   nivel|sección|mensaje|id|fix|safe|target   (id/fix/safe/target = catálogo buffy-repair)
JSON_ITEMS=""
JSON_SECTION="General"

# Catálogo de fixes accionables por buffy-repair.sh. safe=true → AUTO_SAFE.
declare -A FIX_SAFE=(
  [regenerate_snapshot]=true
  [create_ai_context_dir]=true
  [create_skill_dir]=true
  [update_index]=false
  [chmod_plus_x]=true
  [create_context_file]=false
  [create_knowledge_file]=false
  [recreate_script]=false
  [copy_skill_to_repo]=false
  [migrate_flat_skill]=false
  [remove_or_merge]=false
  [git_init]=false
)

jitem() { # jitem <nivel> <mensaje> <id> <fix> <target>
  local fix="${4:-}"
  local safe="false"
  # Ojo: ${FIX_SAFE[$fix]} con fix vacío expande a ${FIX_SAFE[]} → 'bad array subscript' en bash.
  if [ -n "$fix" ]; then
    safe="${FIX_SAFE[$fix]:-false}"
  fi
  JSON_ITEMS+="$1"$'\t'"$JSON_SECTION"$'\t'"$2"$'\t'"${3:-}"$'\t'"$fix"$'\t'"$safe"$'\t'"${5:-}"$'\n'
}

ok() {
  TOTAL_OK=$((TOTAL_OK+1))
  if [ "$JSON_MODE" = true ]; then
    jitem "ok" "$1" "" "" ""
  elif [ "$QUICK_MODE" != true ]; then
    echo -e "  ${GREEN}✅${NC} $1"
  fi
}
warn() {
  TOTAL_WARN=$((TOTAL_WARN+1))
  if [ "$JSON_MODE" = true ]; then
    jitem "warn" "$1" "${2:-}" "${3:-}" "${4:-}"
  else
    echo -e "  ${YELLOW}⚠️  ${NC} $1"
  fi
}
err() {
  TOTAL_ERR=$((TOTAL_ERR+1))
  if [ "$JSON_MODE" = true ]; then
    jitem "err" "$1" "${2:-}" "${3:-}" "${4:-}"
  else
    echo -e "  ${RED}❌${NC} $1"
  fi
}
info() {
  if [ "$JSON_MODE" = true ]; then
    jitem "info" "$1" "" "" ""
  elif [ "$QUICK_MODE" != true ]; then
    echo -e "  ℹ️  $1"
  fi
}
section() {
  if [ "$JSON_MODE" = true ]; then
    jitem "section" "$1" "" "" ""
    JSON_SECTION="$1"
  elif [ "$QUICK_MODE" != true ]; then
    echo -e "\n${CYAN}═══════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════${NC}"
  fi
}

if [ ! -d "$REPO_DIR/ai-context" ]; then
  if [ "$JSON_MODE" = true ]; then
    python3 -c 'import json,sys; print(json.dumps({"repo":sys.argv[1],"ok":0,"warnings":0,"errors":1,"healthy":False,"items":[{"level":"err","section":"General","message":"No es un checkout de buffy-context","id":"INVALID_REPO","fix":"","safe":False}]}, ensure_ascii=False))' "$REPO_DIR"
  else
    echo -e "${RED}❌ No es un checkout de buffy-context: $REPO_DIR${NC}" >&2
    echo -e "${YELLOW}   Usa --repo RUTA al directorio del repo.${NC}" >&2
  fi
  exit 1
fi

# ══════════════════════════════════════════════════════════
section "🏗️  Infraestructura"
# ══════════════════════════════════════════════════════════

HOME_AI_CONTEXT="$(buffy_ai_context)"
if [ -d "$HOME_AI_CONTEXT" ]; then
  ok "$HOME_AI_CONTEXT existe (destino de SNAPSHOT.md)"
else
  warn "$(buffy_ai_context) no existe — SNAPSHOT.md se generará con: bash scripts/buffy-context.sh" "NO_AI_CONTEXT_DIR" "create_ai_context_dir" "$HOME_AI_CONTEXT"
fi

# buffy-context.sh genera SNAPSHOT en el estado generado (buffy_ai_context); el repo puede tener copia gitignored.
# Frescura: parsea 'Generated:' que buffy-context.sh embebe en la cabecera.
SNAP_FOUND=""
[ -f "$REPO_DIR/ai-context/SNAPSHOT.md" ] && SNAP_FOUND="$REPO_DIR/ai-context/SNAPSHOT.md"
[ -z "$SNAP_FOUND" ] && [ -f "$(buffy_snapshot)" ] && SNAP_FOUND="$(buffy_snapshot)"
if [ -n "$SNAP_FOUND" ]; then
  GENERATED_TS=$(grep -m1 'Generated:' "$SNAP_FOUND" 2>/dev/null | sed 's/.*Generated:[[:space:]]*//')
  if [ -n "$GENERATED_TS" ]; then
    EPOCH=$(date -d "$GENERATED_TS" +%s 2>/dev/null || echo 0)
    if [ "$EPOCH" -gt 0 ]; then
      AGE_MIN=$(( ($(date +%s) - EPOCH) / 60 ))
      if [ "$AGE_MIN" -gt $((STALE_HOURS*60)) ]; then
        warn "SNAPSHOT.md tiene $AGE_MIN min de antigüedad (más de ${STALE_HOURS}h) — regenerar con buffy-context.sh" "STALE_SNAPSHOT" "regenerate_snapshot" "SNAPSHOT.md"
      else
        ok "SNAPSHOT.md presente (fresco, generado hace $AGE_MIN min)"
      fi
    else
      warn "SNAPSHOT.md presente pero timestamp 'Generated:' no parseable — regenerar" "STALE_SNAPSHOT" "regenerate_snapshot" "SNAPSHOT.md"
    fi
  else
    warn "SNAPSHOT.md presente pero sin línea 'Generated:' (formato antiguo) — regenerar con buffy-context.sh" "STALE_SNAPSHOT" "regenerate_snapshot" "SNAPSHOT.md"
  fi
else
  warn "SNAPSHOT.md ausente — se genera con: bash scripts/buffy-context.sh" "MISSING_SNAPSHOT" "regenerate_snapshot" "SNAPSHOT.md"
fi

if [ -d "$REPO_DIR/.git" ]; then
  REMOTE=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || echo "sin remote")
  BRANCH=$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || echo "?")
  DIRTY=$(git -C "$REPO_DIR" status --porcelain 2>/dev/null | wc -l)
  info "Git: rama ${CYAN}$BRANCH${NC} · remote ${CYAN}$REMOTE${NC} · $DIRTY archivos sin commitear"
else
  warn "No es un repo git (no hay .git/)" "NOT_GIT_REPO" "git_init" "$REPO_DIR"
fi

# ══════════════════════════════════════════════════════════
section "📄 Contexto (ai-context/)"
# ══════════════════════════════════════════════════════════

# Archivos que LOAD_CONTEXT.md marca como SIEMPRE obligatorios
for f in LOAD_CONTEXT.md INFO-core.md CONTINUE.md; do
  if [ -f "$REPO_DIR/ai-context/$f" ]; then ok "$f"; else err "$f (obligatorio según LOAD_CONTEXT.md)" "MISSING_MANDATORY_FILE" "create_context_file" "$f"; fi
done

# Bajo demanda / opcionales
for f in INFO-full.md SESION.md SESION-archive.md PROJECTS.md CHANGELOG.md CHANGELOG-archive.md AGENTS.md v4_MANIFIESTO.md README.md; do
  if [ -f "$REPO_DIR/ai-context/$f" ]; then ok "$f"; else warn "$f (bajo demanda)" "MISSING_OPTIONAL_FILE" "create_context_file" "$f"; fi
done

# DEPRECATED (deberían existir pero marcados obsoletos)
for f in SYSTEM.md SYSTEM_FULL.md; do
  if [ -f "$REPO_DIR/ai-context/$f" ]; then
    warn "$f — ⚠️  DEPRECATED, ver INFO-core.md" "DEPRECATED_FILE" "remove_or_merge" "$f"
  fi
done

# ══════════════════════════════════════════════════════════
section "📚 Knowledge/"
# ══════════════════════════════════════════════════════════

# Categorías y archivos esperados según Knowledge/README.md
declare -A KNOWLEDGE_EXPECTED=(
  [AI/Kimi-K3.md]="AI"
  [Android/ADB.md]="Android"
  [Android/Shizuku.md]="Android"
  [Android/HyperOS.md]="Android"
  [Android/GameOptimization.md]="Android"
  [Android/scrcpy.md]="Android"
  [Android/Keymappers.md]="Android"
  [Android/NubiaLab.md]="Android"
  [Linux/System.md]="Linux"
  [Linux/Kernel.md]="Linux"
  [React/React.md]="React"
  [React/Vite.md]="React"
  [React/Tailwind.md]="React"
  [React/PWA.md]="React"
  [Git/Commands.md]="Git"
  [Node/Node.md]="Node"
  [Shell/Shell.md]="Shell"
  [Tools/CodeGraph.md]="Tools"
  [Tools/Benchmark-realista.md]="Tools"
  [Vision.md]="Visión"
)

declare -A KNOWLEDGE_CATS=()
for f in "${!KNOWLEDGE_EXPECTED[@]}"; do
  if [ -f "$REPO_DIR/Knowledge/$f" ]; then
    ok "Knowledge/$f"
  else
    err "Knowledge/$f (esperado según Knowledge/README.md)" "MISSING_KNOWLEDGE" "create_knowledge_file" "Knowledge/$f"
  fi
  KNOWLEDGE_CATS[${KNOWLEDGE_EXPECTED[$f]}]=1
done

info "Categorías con al menos un archivo: ${CYAN}${!KNOWLEDGE_CATS[@]}${NC}"

# Archivos extra en Knowledge/ no documentados (drift inverso)
mapfile -t EXTRA_KNOWLEDGE < <(find "$REPO_DIR/Knowledge" -name '*.md' -not -name 'README.md' 2>/dev/null | sed "s|$REPO_DIR/Knowledge/||" | sort)
for f in "${EXTRA_KNOWLEDGE[@]}"; do
  if [ -z "${KNOWLEDGE_EXPECTED[$f]:-}" ]; then
    warn "Knowledge/$f existe pero no está documentado en Knowledge/README.md" "UNDOCUMENTED_KNOWLEDGE" "update_index" "Knowledge/$f"
  fi
done

# ══════════════════════════════════════════════════════════
section "🎯 Skills (referenciadas en docs vs realidad)"
# ══════════════════════════════════════════════════════════

# 1. Skills documentadas: extraídas dinámicamente de los .md del repo
#    (patrón skills/nombre en cualquier doc + lista "Skills a cargar" de LOAD_CONTEXT)
#    Se excluyen *-archive.md: son historial, no promesas activas.
mapfile -t DOCUMENTED_SKILLS < <({
  grep -rhoE 'skills/[a-z0-9_-]+' "$REPO_DIR" --include='*.md' --exclude='*-archive.md' 2>/dev/null | sed 's|skills/||'
  grep -n -A1 'Skills a cargar\|Skills relacionadas\|Skills relacionada' "$REPO_DIR/ai-context/LOAD_CONTEXT.md" "$REPO_DIR/Knowledge/README.md" 2>/dev/null \
    | grep -oE '`[a-z0-9_-]+`' | tr -d '`'
} | sort -u)

info "Skills documentadas extraídas: ${CYAN}${#DOCUMENTED_SKILLS[@]}${NC}"

if [ ${#DOCUMENTED_SKILLS[@]} -eq 0 ]; then
  warn "No se pudo extraer skills documentadas (revisa el patrón de grep)" "SKILL_EXTRACTION_FAILED" "" ""
else
  for skill in "${DOCUMENTED_SKILLS[@]}"; do
    # Omitir falsos positivos (modelos, no skills)
    case "$skill" in minicpm-v|moondream|qwen*) continue ;; esac

    IN_REPO=false
    IN_HOME=false
    HOME_FORMAT=""

    if [ -f "$REPO_DIR/.agents/skills/$skill/SKILL.md" ]; then
      IN_REPO=true
    fi
    if [ -f "$HOME/.agents/skills/$skill/SKILL.md" ]; then
      IN_HOME=true; HOME_FORMAT="nuevo"
    elif [ -f "$HOME/.agents/skills/$skill.md" ]; then
      IN_HOME=true; HOME_FORMAT="plano"
    fi

    if [ "$IN_REPO" = true ]; then
      ok "$skill (repo, formato SKILL.md)"
    elif [ "$IN_HOME" = true ]; then
      warn "$skill — solo en ~/.agents/skills/ (formato $HOME_FORMAT), NO en el repo" "SKILL_NOT_IN_REPO" "copy_skill_to_repo" "$skill"
    else
      err "$skill — referenciada en docs pero inexistente" "MISSING_SKILL" "create_skill_dir" "$skill"
    fi
  done
fi

# 2. Skills existentes en el repo no referenciadas en docs (drift inverso)
mapfile -t REPO_SKILLS < <(find "$REPO_DIR/.agents/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||' | sort)
for skill in "${REPO_SKILLS[@]}"; do
  case " ${DOCUMENTED_SKILLS[*]} " in
    *" $skill "*) : ;;
    *) warn "$skill — existe en .agents/skills/ pero no está referenciada en ninguna doc" "UNDOCUMENTED_SKILL" "update_index" "$skill" ;;
  esac
done

# 3. Skills planas en HOME (~/.agents/skills/*.md) no migradas
mapfile -t HOME_FLAT_SKILLS < <(find "$HOME/.agents/skills" -maxdepth 1 -name '*.md' 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort)
for skill in "${HOME_FLAT_SKILLS[@]}"; do
  case " ${DOCUMENTED_SKILLS[*]} " in
    *" $skill "*) : ;;
    *) warn "$skill — en ~/.agents/skills/ como .md plano, no referenciada en docs" "FLAT_SKILL_UNREFERENCED" "migrate_flat_skill" "$skill" ;;
  esac
done

# ══════════════════════════════════════════════════════════
section "🛠️  Scripts (scripts/)"
# ══════════════════════════════════════════════════════════

for s in buffy-context.sh android-detect.sh kimi_vision.js see.sh ollama-kill.sh buffy-memory.sh; do
  if [ -f "$REPO_DIR/scripts/$s" ]; then
    if [ -x "$REPO_DIR/scripts/$s" ] || [[ "$s" == *.js ]]; then
      ok "$s"
    else
      warn "$s existe pero no es ejecutable (falta chmod +x)" "NOT_EXECUTABLE" "chmod_plus_x" "$REPO_DIR/scripts/$s"
    fi
  else
    err "$s (referenciado en README/LOAD_CONTEXT)" "MISSING_SCRIPT" "recreate_script" "$s"
  fi
done

# ══════════════════════════════════════════════════════════
section "🧠 Memoria curada (buffy-memory.sh)"
# ══════════════════════════════════════════════════════════

MEM_DIR="${BUFFY_MEM_DIR:-$HOME/.buffy/memories}"
if [ -d "$MEM_DIR" ]; then
  ok "directorio de memoria: $MEM_DIR"
else
  warn "memoria no inicializada ($MEM_DIR) — primera vez: bash scripts/buffy-memory.sh add memory \"...\"" "MEMORY_NOT_INIT" "" "$MEM_DIR"
fi
for mf in "MEMORY.md:2200" "USER.md:1375"; do
  f="${mf%%:*}"; LIM="${mf##*:}"
  if [ -f "$MEM_DIR/$f" ]; then
    if [ -s "$MEM_DIR/$f" ]; then
      C=$(wc -m < "$MEM_DIR/$f" 2>/dev/null | tr -d ' ')
      if [ -n "$C" ] && [ "$C" -gt "$LIM" ]; then
        err "$f excede el límite del store: $C > $LIM chars — consolidar con: bash scripts/buffy-memory.sh" "MEMORY_OVERFLOW" "" "$f"
      else
        ok "$f presente ($C/$LIM chars)"
      fi
    else
      info "$f existe (vacío, sin entradas)"
    fi
  else
    warn "$f ausente — se crea al primer uso de buffy-memory.sh" "MEMORY_FILE_MISSING" "" "$f"
  fi
done

# ══════════════════════════════════════════════════════════
section "📊 Resumen"
# ══════════════════════════════════════════════════════════

if [ "$JSON_MODE" = true ]; then
  if JSON_OUT=$(printf '%s' "$JSON_ITEMS" | python3 -c "
import json, re, sys
lines = sys.stdin.read().splitlines()
items = []
for ln in lines:
    parts = ln.split('\t', 6)
    if len(parts) < 3:
        continue
    level, section, msg = parts[0], parts[1], parts[2]
    id_ = parts[3] if len(parts) > 3 else ''
    fix = parts[4] if len(parts) > 4 else ''
    safe = (parts[5] == 'true') if len(parts) > 5 else False
    target = parts[6] if len(parts) > 6 else ''
    item = {'level': level, 'section': section, 'message': re.sub(r'\x1b\[[0-9;]*m', '', msg), 'safe': safe}
    if id_:
        item['id'] = id_
    if fix:
        item['fix'] = fix
    if target:
        item['target'] = target
    items.append(item)
data = {'repo': sys.argv[1], 'ok': int(sys.argv[2]), 'warnings': int(sys.argv[3]), 'errors': int(sys.argv[4]), 'healthy': int(sys.argv[4]) == 0, 'items': items}
print(json.dumps(data, ensure_ascii=False, indent=2))
" "$REPO_DIR" "$TOTAL_OK" "$TOTAL_WARN" "$TOTAL_ERR" 2>/dev/null); then
    printf '%s\n' "$JSON_OUT"
  else
    printf '{"repo":"%s","ok":%s,"warnings":%s,"errors":%s,"healthy":%s,"items":[]}\n' \
      "$REPO_DIR" "$TOTAL_OK" "$TOTAL_WARN" "$TOTAL_ERR" \
      "$([ "$TOTAL_ERR" -eq 0 ] && printf true || printf false)"
  fi
else
  echo -e "  ${GREEN}✅ OK: $TOTAL_OK${NC}   ${YELLOW}⚠️  Advertencias: $TOTAL_WARN${NC}   ${RED}❌ Errores: $TOTAL_ERR${NC}"

  if [ "$QUICK_MODE" = true ]; then
    if [ "$TOTAL_ERR" -eq 0 ]; then
      echo -e "${GREEN}✅ buffy-context: CONSISTENTE${NC}"
    else
      echo -e "${RED}❌ buffy-context: $TOTAL_ERR error(es) de drift${NC}"
    fi
  else
    if [ "$TOTAL_ERR" -eq 0 ]; then
      echo -e "${GREEN}✅ El ecosistema está consistente.${NC}"
    else
      echo -e "${RED}❌ Hay $TOTAL_ERR error(es): la documentación promete cosas que no existen.${NC}"
      echo -e "${YELLOW}   Decide: regenerar lo faltante o actualizar la documentación.${NC}"
    fi
  fi
fi

[ "$TOTAL_ERR" -gt 0 ] && exit 1 || exit 0

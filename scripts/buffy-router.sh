#!/usr/bin/env bash
# buffy-router.sh — Carga condicional ejecutable (LOAD_CONTEXT.md → lista de archivos)
# Toma el mensaje del usuario y emite qué cargar: base + Knowledge/ + skills + scripts,
# con estimación de tokens. Portable entre Freebuff, Claude Code, Codex.
#
# Uso:
#   buffy-router.sh "mensaje"                → lista de archivos a cargar
#   echo "mensaje" | buffy-router.sh         → lee de stdin
#   buffy-router.sh --json "mensaje"         → salida JSON (para scripting)
#   buffy-router.sh --quick "mensaje"        → solo rutas existentes, una por línea
#   buffy-router.sh --list                   → tabla de categorías y señales
#   buffy-router.sh --repo RUTA "mensaje"    → checkout específico
#   buffy-router.sh --help                   → esta ayuda
#
# Exit codes:
#   0  → OK (se generó la lista)
#   1  → Error de uso (sin mensaje)
#
# Creado: 2026-08-03

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
# shellcheck source=lib/yaml.sh
source "$SCRIPT_DIR/lib/yaml.sh"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
REPO_DIR="${SCRIPT_DIR%/scripts}"
MODE="normal"   # normal | json | quick

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) MODE="json"; shift ;;
    --quick) MODE="quick"; shift ;;
    --list)
      cat <<'EOF'
🧭 Categorías del router (según LOAD_CONTEXT.md)

| Categoría | Señales de activación |
|---|---|
| Android | gradle/.kt/Manifest, adb device, scrcpy, Shizuku, Nubia, HyperOS, Free Fire, GG Mouse, game boost, APK |
| Code Search | "busca X en el código", "encuentra dónde se usa Y", error con definiciones, entender flujo |
| React | package.json con react, JSX/TSX, Vite, Tailwind, PWA, componente/hook/estado |
| Linux | pacman, systemd, bspwm, Hyprland, kernel, módulo, driver, sysctl, dmesg |
| Git | commit, push, merge, rebase, conflicto, stash, diff |
| Node | npm, npx, package.json, dependencia |
| Shell | bash, zsh, script, awk, sed, grep |
| Visión/VLM | imagen, screenshot, captura, OCR, VLM, error con UI visible |
EOF
      exit 0 ;;
    --repo) REPO_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    -*) echo "❌ Opción desconocida: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

# ── Mensaje: args o stdin ─────────────────────────────────
if [ $# -gt 0 ]; then
  MESSAGE="$*"
elif [ ! -t 0 ]; then
  MESSAGE=$(timeout 5 cat 2>/dev/null || true)
fi
# Sin mensaje en ninguna parte (ni args ni stdin) → error de uso.
if [ -z "$MESSAGE" ]; then
  echo -e "${RED}❌ Falta el mensaje. Uso: buffy-router.sh \"mensaje del usuario\"${NC}" >&2
  exit 1
fi

# Normalizar: minúsculas + quitar acentos (robusto a "telefono"/"teléfono")
normalize() {
  tr '[:upper:]' '[:lower:]' <<< "$1" \
    | sed 's/á/a/g; s/é/e/g; s/í/i/g; s/ó/o/g; s/ú/u/g; s/ü/u/g; s/ñ/n/g'
}
MSG_LOWER="$(normalize "$MESSAGE")"

has() { grep -qiE "$1" <<< "$MSG_LOWER" && return 0 || return 1; }

# ── Manifests de skills (contrato B2) ─────────────────────
# El router resuelve las skills desde su skill.yaml (id/entry/safe/triggers)
# en vez de rutas hardcodeadas: el manifest es la fuente de verdad.
#   SKILLS_DIR   → .agents/skills/
#   skill_path   → devuelve el SKILL.md del directorio <id> si existe
#   skill_manifest → devuelve la ruta al skill.yaml de <id> (vacío si no hay)
#   skill_triggers → lista de triggers del manifest unida por '|' (regex)
#   skill_safe     → 'true'/'false' según el manifest (vacío si no hay)
#   add_skill      → registra la skill <id> SOLO si su manifest existe
#   add_by_triggers→ registra todas las skills cuyo manifest matchee la regex
#                    (≥1 trigger). Skills sin manifest se omiten con warning.
SKILLS_DIR="$REPO_DIR/.agents/skills"

skill_path() {
  printf '%s' ".agents/skills/$1/SKILL.md"
}

skill_manifest() {
  local mf="$SKILLS_DIR/$1/skill.yaml"
  [ -f "$mf" ] && printf '%s' "$mf"
}

skill_triggers() {
  local mf; mf="$(skill_manifest "$1")"
  [ -n "$mf" ] && yaml_list "$mf" triggers
}

skill_safe() {
  local mf; mf="$(skill_manifest "$1")"
  [ -n "$mf" ] && yaml_val "$mf" safe
}

add_skill() {  # <id> — registra la skill si su manifest existe
  local id="$1" mf
  mf="$(skill_manifest "$id")"
  if [ -n "$mf" ]; then
    SKILL_FILES+=("$(skill_path "$id")")
  else
    MISSING_MANIFESTS+=("$id")
  fi
}

skill_matches() {  # <id> — true si ≥1 trigger del manifest matchea el mensaje
  local trigs; trigs="$(skill_triggers "$1")"
  [ -n "$trigs" ] && has "$trigs"
}

discover_skills() {  # añade toda skill cuyo manifest matchee el mensaje (y no esté ya)
  local d id f found
  for d in "$SKILLS_DIR"/*/; do
    [ -d "$d" ] || continue
    id="$(basename "$d")"
    found=0
    for f in "${SKILL_FILES[@]}"; do
      [ "$f" = "$(skill_path "$id")" ] && found=1 && break
    done
    [ "$found" = 1 ] && continue
    skill_matches "$id" && add_skill "$id"
  done
}

# ── Detección de proyectos (señales de archivo) ────────────
detect_android_project() { ls *.gradle.kts *.gradle 2>/dev/null | grep -q .; }
detect_android_manifest() { [ -f app/src/main/AndroidManifest.xml ]; }
detect_react_project() { [ -f package.json ] && grep -qi '"react"' package.json 2>/dev/null; }
detect_node_project() { [ -f package.json ] && ! grep -qi '"react"' package.json 2>/dev/null; }
detect_adb_device() { command -v adb >/dev/null 2>&1 && timeout 3 adb devices 2>/dev/null | grep -qw device; }

# ── Categorías (flags + arrays de archivos) ────────────────
CATS=()
KNOWLEDGE_FILES=()
SKILL_FILES=()
SCRIPT_FILES=()
MISSING_MANIFESTS=()

# BASE — siempre
BASE_FILES=(
  "ai-context/INFO-core.md"
  "ai-context/CONTINUE.md"
)
# SNAPSHOT: se resuelve entre el estado generado (BUFFY_HOME/ai-context) y el repo
if [ -f "$(buffy_snapshot)" ]; then
  BASE_FILES+=("$(buffy_snapshot)")
else
  BASE_FILES+=("ai-context/SNAPSHOT.md")
fi

# PROJECTS.md — solo si menciona un proyecto
if has 'proyecto|widgetos|pwa_securguard|timemark|gameboost|game boost pro|manuninstaller|codebuff-automation|autoscript|xuper|scrcpy-freefire\.sh'; then
  BASE_FILES+=("ai-context/PROJECTS.md")
fi

# SESION.md — solo si pregunta por sesión/historial reciente
if has 'sesion|sesión|que estabamos|qué estábamos|que hicimos|qué hicimos|historial reciente|ultima sesion|última sesión'; then
  BASE_FILES+=("ai-context/SESION.md (últimas 5 entradas)")
fi

# CHANGELOG.md — solo si pregunta qué cambió
if has 'que cambio|qué cambió|que cambió|qué cambio|cambios recientes|changelog'; then
  BASE_FILES+=("ai-context/CHANGELOG.md")
fi

# AGENTS.md — solo si necesita notas técnicas de agentes previos
if has 'notas tecnicas|notas técnicas|agente anterior|que hizo el agente|nota de agente'; then
  BASE_FILES+=("ai-context/AGENTS.md")
fi

# ── ANDROID ────────────────────────────────────────────────
# detect_adb_device es señal de ENTORNO (teléfono conectado), no de intención:
# solo dispara Android si el mensaje NO apunta claramente a otra categoría
# (React/Node/Git/Shell/Visión). Así un dispositivo conectado no contamina
# tareas de otra índole (falso positivo de routing).
android_by_device=''
if detect_adb_device \
   && ! has 'react|jsx|tsx|vite|tailwind|pwa|componente|hook|estado|npm|npx|package\.json|dependencia|commit|push|merge|rebase|branch|stash|git|bash|zsh|awk|sed|grep|imagen|screenshot|captura|vlm|ocr'; then
  android_by_device=1
fi
if has 'android|adb|scrcpy|shizuku|nubia|hyperos|xiaomi|miui|free fire|gg mouse|game boost|keymapper|mantis|apk|dispositivo|telefono|teléfono|rom|logcat|dumpsys|auto\.js|automation|permiso' \
   || detect_android_project || detect_android_manifest || [ -n "$android_by_device" ]; then
  CATS+=("Android")

  KNOWLEDGE_FILES+=("Knowledge/Android/ADB.md")
  add_skill android-adb

  if has 'shizuku|rish|permiso|privilegios|appops'; then
    KNOWLEDGE_FILES+=("Knowledge/Android/Shizuku.md")
    add_skill shizuku-rikka
  fi
  if has 'scrcpy|mirror|streaming'; then
    KNOWLEDGE_FILES+=("Knowledge/Android/scrcpy.md")
    add_skill scrcpy-freefire
  fi
  if has 'rendimiento|fps|lag|optimiz|cpu|gpu|thermal|temperatura|juego|game'; then
    KNOWLEDGE_FILES+=("Knowledge/Android/GameOptimization.md")
    add_skill android-game-opt
  fi
  if has 'hyperos|xiaomi|miui'; then
    KNOWLEDGE_FILES+=("Knowledge/Android/HyperOS.md")
    add_skill hyperos-hardening
  fi
  if has 'gg mouse|mantis|keymapper|keymapping'; then
    KNOWLEDGE_FILES+=("Knowledge/Android/Keymappers.md")
    add_skill scrcpy-freefire
  fi
  if has 'diagnostico|diagnóstico'; then
    add_skill android-agent
  fi
fi

# ── CODE SEARCH ────────────────────────────────────────────
if has 'busca .*codigo|busca .*código|encuentra donde|encuentra dónde|buscar en|buscar donde|definicion|definición|explora el codigo|entiende el flujo|donde se usa|dónde se usa'; then
  CATS+=("Code Search")
  add_skill code-search
  if has 'compleja|complejo|varias busquedas|varias búsquedas|multiple|múltiple'; then
    add_skill search_criteria_v4
  fi
fi

# ── REACT ──────────────────────────────────────────────────
if has 'react|jsx|tsx|componente|hook|estado|vite|tailwind|pwa|\btypescript\b' || detect_react_project; then
  CATS+=("React")
  KNOWLEDGE_FILES+=("Knowledge/React/React.md")
  if has 'vite|build|config|dev server|bundle'; then
    KNOWLEDGE_FILES+=("Knowledge/React/Vite.md")
  fi
  if has 'tailwind|estilo|css|design system|tema'; then
    KNOWLEDGE_FILES+=("Knowledge/React/Tailwind.md")
  fi
  if has 'pwa|manifest|service worker|offline'; then
    KNOWLEDGE_FILES+=("Knowledge/React/PWA.md")
  fi
fi

# ── LINUX ──────────────────────────────────────────────────
if has 'pacman|systemd|bspwm|hyprland|arch|kernel|modulo|módulo|driver|sysctl|dmesg|wm|compositor|error de sistema'; then
  CATS+=("Linux")
  KNOWLEDGE_FILES+=("Knowledge/Linux/System.md")
  if has 'kernel|modulo|módulo|sysctl|driver'; then
    KNOWLEDGE_FILES+=("Knowledge/Linux/Kernel.md")
  fi
fi

# ── GIT ────────────────────────────────────────────────────
if has 'commit|push|pull|merge|rebase|branch|stash|conflicto|diff|\bgit\b'; then
  CATS+=("Git")
  KNOWLEDGE_FILES+=("Knowledge/Git/Commands.md")
fi

# ── NODE ───────────────────────────────────────────────────
if has 'npm|npx|package\.json|dependencia|\bnode\b' || detect_node_project; then
  CATS+=("Node")
  KNOWLEDGE_FILES+=("Knowledge/Node/Node.md")
fi

# ── SHELL ──────────────────────────────────────────────────
if has 'bash|zsh|\bscript(s)?\b|awk|sed|grep|shell'; then
  CATS+=("Shell")
  KNOWLEDGE_FILES+=("Knowledge/Shell/Shell.md")
fi

# ── VISIÓN/VLM ─────────────────────────────────────────────
if has 'imagen|screenshot|captura|vlm|vision|visión|ocr|ve esta|mira esta|error en pantalla|ui visible'; then
  CATS+=("Visión/VLM")
  KNOWLEDGE_FILES+=("Knowledge/Vision.md")
  add_skill vision-adapter
  add_skill code-search
  SCRIPT_FILES+=("scripts/see.sh")
fi

# ── Descubrimiento por manifests (contrato B2) ─────────────
# Después de la lógica de categorías, se descubren automáticamente las skills
# cuyo skill.yaml matchee el mensaje (triggers) y que no estén ya registradas.
discover_skills

# ── Deduplicar y resolver ──────────────────────────────────
dedupe() {
  local -A seen=()
  for f in "$@"; do
    [ -n "$f" ] || continue
    [ -n "${seen[$f]:-}" ] && continue
    seen[$f]=1
    printf '%s\n' "$f"
  done
}

strip_anno() { # quita la anotación "(...)" de una ruta con nota: "a.md (nota)" → "a.md"
  printf '%s\n' "$1" | sed 's/ *([^)]*)$//'
}

real_path() { # imprime la ruta real (relativa al repo o absoluta HOME); vacío si no existe
  local f="$1" p
  p="$(strip_anno "$f")"
  if [ -f "$REPO_DIR/$p" ]; then printf '%s\n' "$p"; return; fi
  if [ -f "$HOME/$p" ]; then printf '%s\n' "$HOME/$p"; return; fi
  if [ -f "$p" ]; then printf '%s\n' "$p"; return; fi
}

est_tokens() { # ~4 bytes/token; acepta ruta con anotación, absoluta o relativa al repo
  local f="$1" p
  p="$(strip_anno "$f")"
  if [ -f "$p" ]; then
    echo $(( ($(wc -c < "$p") + 3) / 4 ))
  elif [ -f "$REPO_DIR/$p" ]; then
    echo $(( ($(wc -c < "$REPO_DIR/$p") + 3) / 4 ))
  elif [ -f "$HOME/$p" ]; then
    echo $(( ($(wc -c < "$HOME/$p") + 3) / 4 ))
  else
    echo 0
  fi
}

exists() { # acepta ruta con anotación, absoluta o relativa al repo/HOME
  local f="$1" p
  p="$(strip_anno "$f")"
  [ -f "$p" ] || [ -f "$REPO_DIR/$p" ] || [ -f "$HOME/$p" ]
}

# ── Salida JSON ────────────────────────────────────────────
if [ "$MODE" = "json" ]; then
  {
    printf '{\n'
    printf '  "message": %s,\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$MESSAGE" 2>/dev/null || printf '"%s"' "$MESSAGE")"
    printf '  "categories": ['
    first=1
    for c in "${CATS[@]}"; do
      [ "$first" = 1 ] && first=0 || printf ', '
      printf '"%s"' "$c"
    done
    printf '],\n'
    printf '  "base": ['
    first=1
    while IFS= read -r f; do
      p="$(real_path "$f")"
      [ -n "$p" ] || continue
      [ "$first" = 1 ] && first=0 || printf ', '
      printf '"%s"' "$p"
    done < <(dedupe "${BASE_FILES[@]}")
    printf '],\n'
    printf '  "knowledge": ['
    first=1
    while IFS= read -r f; do
      p="$(real_path "$f")"
      [ -n "$p" ] || continue
      [ "$first" = 1 ] && first=0 || printf ', '
      printf '"%s"' "$p"
    done < <(dedupe "${KNOWLEDGE_FILES[@]}")
    printf '],\n'
    printf '  "skills": ['
    first=1
    while IFS= read -r f; do
      p="$(real_path "$f")"
      [ -n "$p" ] || continue
      [ "$first" = 1 ] && first=0 || printf ', '
      printf '"%s"' "$p"
    done < <(dedupe "${SKILL_FILES[@]}")
    printf '],\n'
    printf '  "scripts": ['
    first=1
    while IFS= read -r f; do
      p="$(real_path "$f")"
      [ -n "$p" ] || continue
      [ "$first" = 1 ] && first=0 || printf ', '
      printf '"%s"' "$p"
    done < <(dedupe "${SCRIPT_FILES[@]}")
    printf ']\n'
    printf '}\n'
  }
  exit 0
fi

# ── Salida quick: solo rutas existentes ────────────────────
if [ "$MODE" = "quick" ]; then
  {
    dedupe "${BASE_FILES[@]}"
    dedupe "${KNOWLEDGE_FILES[@]}"
    dedupe "${SKILL_FILES[@]}"
    dedupe "${SCRIPT_FILES[@]}"
  } | while IFS= read -r f; do
    real_path "$f"
  done
  exit 0
fi

# ── Salida normal (humana) ─────────────────────────────────
section() { echo -e "\n${CYAN}═══════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════${NC}"; }
ok()   { echo -e "  ${GREEN}✅${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠️  ${NC} $1"; }
miss() { echo -e "  ${RED}❌${NC} $1"; }

echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}  🧭 buffy-router — Carga condicional${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "  💬 Mensaje: ${CYAN}$MESSAGE${NC}"

if [ ${#CATS[@]} -gt 0 ]; then
  echo -e "  🎯 Categorías detectadas: ${CYAN}${CATS[*]}${NC}"
else
  echo -e "  🎯 Categorías detectadas: ${YELLOW}ninguna (solo base)${NC}"
fi

section "📂 Base (siempre)"
TOTAL_TOKENS=0
while IFS= read -r f; do
  if exists "$f"; then
    ok "$f"
  elif [[ "$f" == "ai-context/SNAPSHOT.md" ]]; then
    warn "ai-context/SNAPSHOT.md — ausente (regenerable: bash scripts/buffy-context.sh)"
  else
    warn "$f — ausente (regenerable o bajo demanda)"
  fi
  TOTAL_TOKENS=$((TOTAL_TOKENS + $(est_tokens "$f")))
done < <(dedupe "${BASE_FILES[@]}")

if [ ${#KNOWLEDGE_FILES[@]} -gt 0 ]; then
  section "📚 Knowledge/"
  while IFS= read -r f; do
    if exists "$f"; then
      ok "$f"
    else
      miss "$f — referenciado pero inexistente (drift)"
    fi
    TOTAL_TOKENS=$((TOTAL_TOKENS + $(est_tokens "$f")))
  done < <(dedupe "${KNOWLEDGE_FILES[@]}")
fi

if [ ${#SKILL_FILES[@]} -gt 0 ]; then
  section "🎯 Skills"
  while IFS= read -r f; do
    if exists "$f"; then
      if [ "$(skill_safe "$(basename "$(dirname "$f")")")" = true ]; then
        ok "$f ${YELLOW}⚡ AUTO_SAFE${NC}"
      else
        ok "$f"
      fi
    else
      miss "$f — referenciada pero inexistente (drift)"
    fi
    TOTAL_TOKENS=$((TOTAL_TOKENS + $(est_tokens "$f")))
  done < <(dedupe "${SKILL_FILES[@]}")
fi

if [ ${#MISSING_MANIFESTS[@]} -gt 0 ]; then
  section "⚠️  Skills sin manifest (drift B2)"
  for id in "${MISSING_MANIFESTS[@]}"; do
    warn "$id — falta skill.yaml (corre: bash scripts/skill-lint.sh)"
  done
fi

if [ ${#SCRIPT_FILES[@]} -gt 0 ]; then
  section "🛠️  Scripts"
  while IFS= read -r f; do
    if exists "$f"; then
      ok "$f"
    else
      miss "$f — referenciado pero inexistente"
    fi
    TOTAL_TOKENS=$((TOTAL_TOKENS + $(est_tokens "$f")))
  done < <(dedupe "${SCRIPT_FILES[@]}")
fi

section "📊 Resumen"
TOTAL_FILES=$(dedupe "${BASE_FILES[@]}" "${KNOWLEDGE_FILES[@]}" "${SKILL_FILES[@]}" "${SCRIPT_FILES[@]}" | wc -l)
echo -e "  ${CYAN}$TOTAL_FILES${NC} archivos · ~${CYAN}$TOTAL_TOKENS${NC} tokens estimados"
echo -e "  ${GREEN}✅ Listo para cargar.${NC}"
echo -e "  💡 Usa ${CYAN}--quick${NC} para rutas puras o ${CYAN}--json${NC} para scripting."
exit 0

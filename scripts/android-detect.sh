#!/usr/bin/env bash
# android-detect.sh — Detecta contexto Android (proyecto + dispositivo)
# Útil para que cualquier agente IA sepa si está en modo Android.
#
# Uso:
#   android-detect.sh           → Diagnóstico completo
#   android-detect.sh --quick   → Solo sí/no resumido
#   android-detect.sh --watch   → Loop cada 10s
#
# Creado: 2026-07-29

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Parsear flags ─────────────────────────────────────────
QUICK_MODE=false
WATCH_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quick) QUICK_MODE=true ;;
    --watch) WATCH_MODE=true ;;
  esac
  shift
done

# ── Modo watch ────────────────────────────────────────────
if [[ "$WATCH_MODE" == true ]]; then
  echo "👀 Watch activo: verificando cada 10s..."
  while true; do
    clear 2>/dev/null || true
    bash "$0"
    sleep 10
  done
  exit 0
fi

# ── Cabecera ──────────────────────────────────────────────
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${CYAN}  🤖 Android Agent — Diagnóstico${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"
echo ""

# ── 1. Proyecto Android ─────────────────────────────────
echo -e "${YELLOW}📁 Proyecto Android:${NC}"

ANDROID_PROJECT=false

# Buscar indicadores
if [ -f "build.gradle.kts" ] || [ -f "build.gradle" ]; then
    ANDROID_PROJECT=true
    echo -e "  ✅ build.gradle(.kts) encontrado"
fi
if [ -f "app/src/main/AndroidManifest.xml" ]; then
    ANDROID_PROJECT=true
    echo -e "  ✅ AndroidManifest.xml encontrado"
fi
if ls *.kt 2>/dev/null | head -5 | grep -q .; then
    ANDROID_PROJECT=true
    echo -e "  ✅ Archivos .kt encontrados (Kotlin)"
fi
if [ -d "app/src/main/java" ]; then
    ANDROID_PROJECT=true
    echo -e "  ✅ Estructura Java/Kotlin detectada"
fi

# CWD no es proyecto, buscar en ~/proyectos/
if [ "$ANDROID_PROJECT" = false ]; then
    for proj in "$HOME/proyectos"/*/; do
        name=$(basename "$proj")
        if [ -f "$proj/build.gradle.kts" ] || [ -d "$proj/app/src/main" ]; then
            ANDROID_PROJECT=true
            echo -e "  📌 Proyecto Android cercano: ${CYAN}$name${NC}"
        fi
    done
fi

if [ "$ANDROID_PROJECT" = false ]; then
    echo -e "  ${RED}❌ No se detectó proyecto Android${NC}"
fi
echo ""

# ── 2. Dispositivo ADB ───────────────────────────────────
echo -e "${YELLOW}🔌 Dispositivo ADB:${NC}"

DEVICES=$(adb devices -l 2>/dev/null | grep -w device)
if [ -n "$DEVICES" ]; then
    echo -e "  ${GREEN}✅ Dispositivo(s) conectado(s):${NC}"
    echo "$DEVICES" | while IFS= read -r line; do
        SERIAL=$(echo "$line" | awk '{print $1}')
        MODEL=$(adb -s "$SERIAL" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
        ANDROID_VER=$(adb -s "$SERIAL" shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
        echo -e "    ${CYAN}$SERIAL${NC} → $MODEL (Android $ANDROID_VER)"
    done
else
    echo -e "  ${RED}❌ No hay dispositivo conectado${NC}"
    echo -e "  💡 Conecta el teléfono por USB y ejecuta: ${CYAN}adb devices${NC}"
fi
echo ""

# ── 3. Info del dispositivo (si conectado) ──────────────
if [ -n "$DEVICES" ]; then
    echo -e "${YELLOW}📱 Info del dispositivo (primer encontrado):${NC}"
    FIRST_SERIAL=$(echo "$DEVICES" | head -1 | awk '{print $1}')
    
    RES=$(adb -s "$FIRST_SERIAL" shell wm size 2>/dev/null | tr -d '\r')
    DPI=$(adb -s "$FIRST_SERIAL" shell wm density 2>/dev/null | tr -d '\r')
    PLATFORM=$(adb -s "$FIRST_SERIAL" shell getprop ro.board.platform 2>/dev/null | tr -d '\r')
    BATTERY=$(adb -s "$FIRST_SERIAL" shell dumpsys battery 2>/dev/null | grep level | awk '{print $2}')
    
    echo -e "  Resolución: ${CYAN}$RES${NC}"
    echo -e "  DPI: ${CYAN}$DPI${NC}"
    echo -e "  Plataforma: ${CYAN}$PLATFORM${NC}"
    echo -e "  Batería: ${CYAN}${BATTERY:-?}%${NC}"
    
    # Shizuku check
    SHIZUKU=$(adb -s "$FIRST_SERIAL" shell /data/local/tmp/rish -c "id" 2>/dev/null)
    if echo "$SHIZUKU" | grep -q "uid=2000"; then
        echo -e "  Shizuku: ${GREEN}✅ Activo${NC}"
    else
        echo -e "  Shizuku: ${RED}❌ Inactivo${NC}"
    fi
    echo ""
fi

# ── 4. Skills Android disponibles ────────────────────────
echo -e "${YELLOW}📚 Skills Android disponibles:${NC}"
for skill in "$HOME/.agents/skills"/android-* "$HOME/.agents/skills"/shizuku-* "$HOME/.agents/skills"/scrcpy-* "$HOME/.agents/skills"/hyperos-* "$HOME/.agents/skills"/mobile-* "$HOME/.agents/skills"/xiaomi-*; do
    if [ -d "$skill" ] && [ -f "$skill/SKILL.md" ]; then
        name=$(basename "$skill")
        desc=$(grep -m1 'description:' "$skill/SKILL.md" 2>/dev/null | sed 's/description: *//' | tr -d '"' | cut -c1-70)
        echo -e "  ✅ ${CYAN}$name${NC} → $desc"
    fi
done
echo ""

# ── 5. Knowledge Android disponible ─────────────────────
if [ -d "$HOME/Knowledge/Android" ]; then
    echo -e "${YELLOW}📖 Knowledge Android disponible:${NC}"
    for f in "$HOME/Knowledge/Android"/*.md; do
        name=$(basename "$f" .md)
        echo -e "  📄 ${CYAN}$name${NC}"
    done
fi
echo ""

# ── Modo quick: salida temprana con solo lo esencial ──
if [[ "$QUICK_MODE" == true ]]; then
  if [[ "$ANDROID_PROJECT" == true ]] && [ -n "$DEVICES" ]; then
    echo -e "${GREEN}Android: PROYECTO + DISPOSITIVO ✅${NC}"
  elif [[ "$ANDROID_PROJECT" == true ]]; then
    echo -e "${YELLOW}Android: PROYECTO (sin dispositivo)${NC}"
  elif [ -n "$DEVICES" ]; then
    echo -e "${YELLOW}Android: DISPOSITIVO (sin proyecto)${NC}"
  else
    echo -e "${RED}Android: NO DETECTADO${NC}"
    exit 1
  fi
  exit 0
fi

echo -e "${CYAN}═══════════════════════════════════${NC}"
echo -e "${GREEN}✅ Diagnóstico completado${NC}"
echo -e "${CYAN}═══════════════════════════════════${NC}"

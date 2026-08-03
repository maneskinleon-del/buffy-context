#!/usr/bin/env bash
# buffy-context.sh — Genera un snapshot del sistema para que Buffy sepa
# qué está pasando sin que tengas que explicarle nada.
#
# Uso:
#   buffy                      → genera SNAPSHOT.md en ~/ai-context/
#   buffy --clip               → además copia al portapapeles
#   buffy --history            → incluye historial de comandos (filtrado)
#   buffy --watch              → regenera cada 30s (loop)
#
# Creado: 2026-07-20

SNAPSHOT="$HOME/ai-context/SNAPSHOT.md"
TEMP="${SNAPSHOT}.tmp"
INCLUDE_HISTORY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --history) INCLUDE_HISTORY=true ;;
    --clip) CLIP=true ;;
    --watch) WATCH=true ;;
  esac
  shift
done

# ── Asegurar directorio destino (exit-code verificable) ──
mkdir -p "$(dirname "$SNAPSHOT")" || { echo "❌ No se pudo crear $(dirname "$SNAPSHOT")" >&2; exit 1; }

# ── Construir snapshot en temp file ──────────────────────
{
  echo "# 🧠 SNAPSHOT — Contexto vivo de mangonz"
  echo ""
  echo "> Generado automáticamente por buffy-context.sh."
  echo "> Cargar este archivo para contexto fresco del sistema."
  echo ""
  echo "📅 Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "> ⏱️  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""

  # ── Sistema ──────────────────────────────────────────────
  echo "## 💻 Estado del sistema"
  echo ""
  echo "| Métrica | Valor |"
  echo "|---|---|"
  echo "| **Uptime** | $(uptime -p | sed 's/up //') |"
  echo "| **Carga (1/5/15)** | $(cat /proc/loadavg | awk '{print $1, $2, $3}') |"
  echo "| **RAM usado/libre** | $(free -h | awk '/Mem/ {print $3 " / " $4}') |"
  echo "| **Swap** | $(free -h | awk '/Swap/ {print $3 " / " $2}') |"
  echo "| **Disco /** | $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}') |"
  echo "| **Kernel** | $(uname -r) |"
  # Detectar WM: XDG_CURRENT_DESKTOP > DESKTOP_SESSION > loginctl
  if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
    echo "| **WM** | $XDG_CURRENT_DESKTOP |"
  elif [[ -n "$DESKTOP_SESSION" ]]; then
    echo "| **WM** | $DESKTOP_SESSION |"
  else
    wm_detected=$(loginctl show-session "$XDG_SESSION_ID" 2>/dev/null | grep ^DesktopNames | cut -d= -f2)
    echo "| **WM** | ${wm_detected:-desconocido} |"
  fi
  echo ""

  # ── Procesos ─────────────────────────────────────────────
  echo "## ⚡ Procesos relevantes"
  echo ""
  echo '```'
  ps aux --sort=-%mem | head -12
  echo '```'
  echo ""

  # ── Proyectos ────────────────────────────────────────────
  echo "## 📁 Proyectos activos"
  echo ""
  echo "| Proyecto | Rama | Estado git | Último cambio |"
  echo "|---|---|---|---|"

  for proj in "$HOME/proyectos"/*/; do
    name=$(basename "$proj")
    if [ -d "$proj/.git" ]; then
      branch=$(cd "$proj" && git branch --show-current 2>/dev/null || echo "N/A")
      gcount=$(cd "$proj" && git status --short 2>/dev/null | wc -l)
      git_status="✅ limpio"
      [ "$gcount" -gt 0 ] && git_status="⚠️ $gcount modificados"
      last=$(cd "$proj" && git log -1 --format='%ci' 2>/dev/null | cut -d' ' -f1-2 || echo "N/A")
      echo "| **$name** | $branch | $git_status | $last |"
    else
      echo "| **$name** | — | sin git | — |"
    fi
  done
  echo ""

  # ── Scripts ─────────────────────────────────────────────
  echo "## 🔧 Scripts del sistema"
  echo ""
  echo "| Script | Propósito |"
  echo "|---|---|"

  for script in "$HOME/scripts"/*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script" .sh)
    desc=$(grep -m1 '^# ' "$script" 2>/dev/null | sed 's/^# //')
    echo "| **$name** | $desc |"
  done

  for script in "$HOME/.local/bin"/buffy-*; do
    [ -f "$script" ] || continue
    name=$(basename "$script")
    desc=$(grep -m1 "^#" "$script" 2>/dev/null | sed 's/# //')
    echo "| **$name** | $desc |"
  done
  echo ""

  # ── Tamaños ─────────────────────────────────────────────
  echo "## 💾 Espacio en disco"
  echo ""
  echo '```'
  df -h / 2>/dev/null | tail -1
  echo ""
  du -sh "$HOME/proyectos"/*/ 2>/dev/null | sort -rh | head -10
  echo '```'
  echo ""

  # ── Historial (solo si --history, filtrado) ─────────────
  if [[ "$INCLUDE_HISTORY" == true ]]; then
    echo "## 📜 Comandos recientes (filtrado)"
    echo ""
    echo '```'
    tail -20 "$HOME/.zsh_history" 2>/dev/null \
      | sed 's/^: [0-9]*:[0-9]*;//' \
      | grep -viE '(sk-|api[_-]?key|API_KEY|Bearer[=:]|Authorization[=:]|password[=:]|secret[=:])' \
      | tail -15
    echo '```'
    echo ""
  fi

  echo "📍 Snapshot generado: $(date '+%H:%M:%S')"
} > "$TEMP"

# ── Mover atómicamente ────────────────────────────────────
mv "$TEMP" "$SNAPSHOT"

# ── Señalizar éxito/fallo (exit codes para buffy-doctor/repair) ──
if [ ! -s "$SNAPSHOT" ]; then
  echo "❌ Fallo generando SNAPSHOT (archivo vacío o no creado)" >&2
  exit 1
fi

SIZE=$(wc -c < "$SNAPSHOT")
echo "✅ Snapshot: $SNAPSHOT ($(echo $SIZE | numfmt --to=iec 2>/dev/null || echo "${SIZE}B"))"

if [[ "$CLIP" == true ]]; then
  cat "$SNAPSHOT" | wl-copy 2>/dev/null && echo "📋 Copiado al portapapeles"
fi

if [[ "$WATCH" == true ]]; then
  echo "👀 Watch activo: regenerando cada 30s..."
  while sleep 30; do
    bash "$0" 2>/dev/null
  done
fi

exit 0

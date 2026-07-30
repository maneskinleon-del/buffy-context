#!/bin/bash
# ollama-kill.sh — Libera RAM matando procesos de modelos VLM de Ollama
# 
# Ollama mantiene los modelos cargados en memoria después de usarlos para
# respuestas rápidas. Pero un VLM como moondream (1.7GB) puede ocupar
# 2.5GB+ en RAM (~40% más que su tamaño en disco).
#
# Uso:
#   ollama-kill.sh          # Mata procesos VLM, mantiene ollama serve corriendo
#   ollama-kill.sh --all    # Mata todo (incluyendo ollama serve)
#   ollama-kill.sh --status # Solo muestra consumo sin matar

set -e

case "${1:-}" in
    --status|-s)
        echo "📊 Estado de Ollama:"
        ps aux | grep -E 'ollama|llama-server' | grep -v grep | while read -r line; do
            pid=$(echo "$line" | awk '{print $2}')
            mem=$(echo "$line" | awk '{print $6}')
            cmd=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' | head -c 60)
            if echo "$cmd" | grep -q "llama-server"; then
                model=$(echo "$cmd" | grep -oP 'sha256-[a-f0-9]+' | head -1)
                echo "  🧠 PID $pid  ${mem}KB  → modelo activo ($model)"
            elif echo "$cmd" | grep -q "ollama serve"; then
                echo "  🖥️  PID $pid  ${mem}KB  → servidor Ollama"
            fi
        done
        free -h | head -2 | tail -1
        exit 0
        ;;

    --all|-a)
        echo "🛑 Matando Ollama (servidor + modelos)..."
        pkill -f "ollama serve" 2>/dev/null || true
        sleep 1
        if pgrep -f "ollama" >/dev/null 2>&1; then
            pkill -9 -f "ollama" 2>/dev/null || true
        fi
        echo "✅ Ollama detenido completamente."
        echo "   Para reiniciar: systemctl --user start ollama"
        ;;

    --help|-h)
        echo "Uso: ollama-kill.sh [opción]"
        echo ""
        echo "  (sin opción)   Mata solo modelos VLM, mantiene ollama serve"
        echo "  --all, -a      Mata todo (servidor + modelos)"
        echo "  --status, -s   Muestra consumo sin matar"
        echo "  --help, -h     Esta ayuda"
        ;;

    *)
        echo "🛑 Matando modelos VLM (ollama serve se mantiene)..."
        killed=0
        for pid in $(pgrep -f "llama-server" 2>/dev/null); do
            mem=$(ps -o rss= -p "$pid" 2>/dev/null || echo "0")
            mem_mb=$((mem / 1024))
            kill "$pid" 2>/dev/null && echo "  ✅ Matado PID $pid (~${mem_mb}MB liberados)" && killed=1
        done
        if [ "$killed" -eq 0 ]; then
            echo "  ℹ️  No hay modelos VLM activos."
        else
            echo "✅ Memoria liberada."
        fi
        ;;
esac

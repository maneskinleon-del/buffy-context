#!/bin/bash
# check_device.sh — Detecta el dispositivo Android conectado y su estado
# Uso: bash check_device.sh [serial]
# Si hay varios dispositivos, listarlos y pedir selección (patrón de nubia_zte.sh).

SERIAL="$1"

# Sin serial: detectar automáticamente (si hay varios, pedir selección)
if [ -z "$SERIAL" ]; then
    COUNT=$(adb devices 2>/dev/null | grep -wc device)
    if [ "$COUNT" -gt 1 ]; then
        echo "📱 Dispositivos detectados:"
        adb devices | grep -w device | nl
        read -r -p "Seleccione serial: " SERIAL
    else
        SERIAL=$(adb devices 2>/dev/null | grep -w device | head -1 | awk '{print $1}')
    fi
fi

[ -z "$SERIAL" ] && { echo "❌ No hay dispositivo Android conectado (adb devices)"; exit 1; }

getprop() { adb -s "$SERIAL" shell getprop "$1" 2>/dev/null | tr -d '\r'; }

echo "📱 Serial: $SERIAL"
echo "   Modelo:     $(getprop ro.product.model)"
echo "   Marca:      $(getprop ro.product.manufacturer)"
echo "   Plataforma: $(getprop ro.board.platform)"
echo "   Android:    $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))"
echo "   Root:       $(adb -s $SERIAL shell 'command -v su >/dev/null 2>&1 && echo SI || echo NO' 2>/dev/null)"
echo "   Shizuku:    $(adb -s $SERIAL shell 'pm path moe.shizuku.privileged.api >/dev/null 2>&1 && echo instalado || echo NO-instalado' 2>/dev/null)"
echo "   Rish:       $(adb -s $SERIAL shell 'ls /data/local/tmp/rish >/dev/null 2>&1 && echo /data/local/tmp/rish || echo no-encontrado' 2>/dev/null)"
echo "   Pantalla:   $(adb -s $SERIAL shell dumpsys power 2>/dev/null | grep -o 'mWakefulness=[A-Za-z]*' | head -1)"

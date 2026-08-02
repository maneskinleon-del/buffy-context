#!/bin/bash
# grant_permissions.sh — Concede los permisos estándar que usan las apps del usuario
# (GameBoost Pro, ManUninstaller, etc.): Shizuku API + overlay + batería + usage stats.
# Uso: bash grant_permissions.sh <paquete> [serial]
# Ejemplos: bash grant_permissions.sh com.example
#           bash grant_permissions.sh com.example 320344802623

PKG="${1:?Uso: bash grant_permissions.sh <paquete> [serial]}"
SERIAL="${2:-$(adb devices 2>/dev/null | grep -w device | head -1 | awk '{print $1}')}"
[ -z "$SERIAL" ] && { echo "❌ No hay dispositivo conectado"; exit 1; }

echo "📱 Concediendo permisos a $PKG en $SERIAL..."
OK=0

# Shizuku API — apps que usan comandos privilegiados (GameBoost Pro usa Shizuku)
if adb -s "$SERIAL" shell pm grant "$PKG" moe.shizuku.manager.permission.API_V23 2>/dev/null; then
    echo "  ✅ Shizuku API (pm grant)"; OK=1
else
    echo "  ⚠️  Shizuku API — revisar si Shizuku está activo (pm list packages | grep shizuku)"
fi

# Overlay flotante (SYSTEM_ALERT_WINDOW) — necesario para el panel de métricas
adb -s "$SERIAL" shell appops set "$PKG" SYSTEM_ALERT_WINDOW allow 2>/dev/null && { echo "  ✅ SYSTEM_ALERT_WINDOW (overlay)"; OK=1; }

# Uso de stats (GET_USAGE_STATS) — detección de apps en primer plano
adb -s "$SERIAL" shell appops set "$PKG" GET_USAGE_STATS allow 2>/dev/null && { echo "  ✅ GET_USAGE_STATS"; OK=1; }

# Permiso de background (RUN_IN_BACKGROUND) — evita kills agresivos
adb -s "$SERIAL" shell appops set "$PKG" RUN_IN_BACKGROUND allow 2>/dev/null && { echo "  ✅ RUN_IN_BACKGROUND"; OK=1; }

# Notificaciones (Android 13+) — POST_NOTIFICATION
adb -s "$SERIAL" shell appops set "$PKG" POST_NOTIFICATION allow 2>/dev/null && { echo "  ✅ POST_NOTIFICATION (notificaciones)"; OK=1; }

# Batería sin restricciones (deviceidle whitelist) — evita doze/suspensión
adb -s "$SERIAL" shell dumpsys deviceidle whitelist +"$PKG" 2>/dev/null && { echo "  ✅ Batería sin restricciones (deviceidle)"; OK=1; }

echo ""
echo "=== VERIFICACIÓN (solo lectura) ==="
echo "Shizuku API:   $(adb -s $SERIAL shell dumpsys package "$PKG" 2>/dev/null | grep -oE 'moe\.shizuku\.manager\.permission\.API_V23: granted=(true|false)' | head -1)"
echo "Overlay:       $(adb -s $SERIAL shell appops get "$PKG" SYSTEM_ALERT_WINDOW 2>/dev/null | head -1)"
echo "Usage stats:   $(adb -s $SERIAL shell appops get "$PKG" GET_USAGE_STATS 2>/dev/null | head -1)"
echo "Background:    $(adb -s $SERIAL shell appops get "$PKG" RUN_IN_BACKGROUND 2>/dev/null | head -1)"
echo "Notificaciones: $(adb -s $SERIAL shell appops get "$PKG" POST_NOTIFICATION 2>/dev/null | head -1)"
echo ""
[ "$OK" -ge 1 ] && echo "✅ Permisos aplicados" || echo "⚠️  No se pudo aplicar ningún permiso (¿el paquete está instalado?)"

#!/bin/bash
# build_install.sh — Build (assembleDebug) + install + launch de un proyecto Android
# del usuario (GameBoost Pro, ManUninstaller, etc.). Usa el gradlew del proyecto.
# Uso: bash build_install.sh <ruta-proyecto> [applicationId] [--no-launch]
# Ejemplo: bash build_install.sh ~/proyectos/autoscript-mobile-interface com.example

PROJECT="${1:?Uso: bash build_install.sh <ruta-proyecto> [applicationId] [--no-launch]}"
PKG="${2}"
NO_LAUNCH="${3}"

# Auto-detect applicationId si no se pasó (app/build.gradle.kts — tolera comillas simples/dobles y espacios)
if [ -z "$PKG" ]; then
    PKG=$(grep -hoE "applicationId[[:space:]]*=[[:space:]]*[\"'][^\"']*[\"']" "$PROJECT"/app/build.gradle.kts 2>/dev/null | head -1 | sed -E "s/.*[\"']([^\"']*)[\"']/\1/")
fi

[ -d "$PROJECT" ] || { echo "❌ No existe el proyecto: $PROJECT"; exit 1; }
[ -x "$PROJECT/gradlew" ] || { echo "❌ No hay gradlew en $PROJECT"; exit 1; }

SERIAL=$(adb devices 2>/dev/null | grep -w device | head -1 | awk '{print $1}')
[ -z "$SERIAL" ] && { echo "❌ No hay dispositivo Android conectado"; exit 1; }

echo "🚀 Build de $(basename "$PROJECT") — applicationId: ${PKG:-desconocido} → $SERIAL"
cd "$PROJECT" || exit 1

BUILD_LOG=$(./gradlew assembleDebug --console=plain 2>&1)
echo "$BUILD_LOG" | tail -5
echo "$BUILD_LOG" | grep -qE "BUILD SUCCESSFUL" || { echo "❌ Build falló — revisar la salida completa"; exit 1; }

APK=$(ls -t app/build/outputs/apk/debug/*.apk 2>/dev/null | head -1)
if [ -z "$APK" ]; then
    echo "❌ No se generó APK en app/build/outputs/apk/debug/"
    exit 1
fi
echo "📦 APK: $APK"

echo "📲 Instalando (-r)..."
adb -s "$SERIAL" install -r "$APK" 2>&1 | tail -2

if [ -n "$PKG" ] && [ "$NO_LAUNCH" != "--no-launch" ]; then
    MAIN=$(adb -s "$SERIAL" shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER "$PKG" 2>/dev/null | tail -1 | tr -d '\r')
    if [ -n "$MAIN" ] && [ "$MAIN" != "No activity found" ]; then
        echo "🚀 Lanzando: $MAIN"
        adb -s "$SERIAL" shell am start -n "$MAIN" 2>/dev/null | head -1
    else
        echo "⚠️  No se encontró activity launcher para $PKG"
    fi
fi

echo "✅ Proceso completo. Para logs: bash capturar_logs.sh (dentro del proyecto)"

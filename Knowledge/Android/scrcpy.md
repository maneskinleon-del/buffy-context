# scrcpy — Referencia rápida

> scrcpy + Free Fire. Para troubleshooting completo → skill `.agents/skills/scrcpy-freefire/`.

## Comandos base

```bash
# Mínimo
scrcpy --max-size=1024 --no-audio

# Control HID (mouse+teclado físico)
scrcpy --mouse=uhid --keyboard=uhid

# Completo (gaming)
scrcpy --mouse=uhid --keyboard=uhid --shortcut-mod=rctrl \
  --max-size=1024 -b 30M --max-fps=60 --no-audio \
  --video-buffer=0 --turn-screen-off --stay-awake \
  --render-expired-frames --print-fps
```

## Encoder por plataforma

```bash
# Qualcomm (Snapdragon)
ENCODER="--video-encoder=OMX.qcom.video.encoder.avc"

# Mediatek
ENCODER="--video-encoder=c2.mediatek.avc.encoder"

# Unisoc (ZTE Nubia)
ENCODER="--video-encoder=c2.unisoc.avc.encoder"
```

## Diagnóstico de lag

```bash
# 1. Ver FPS reales
scrcpy --print-fps
# 55-60 fps ✅ | 30-45 fps ⚠️ encoder/USB saturado

# 2. Medir renderizado del juego (no de scrcpy)
adb shell dumpsys gfxinfo com.dts.freefireth
# Buscar "Janky frames" — si >10% es el juego, no scrcpy

# 3. Latencia del compositor Android
adb shell dumpsys SurfaceFlinger --latency Layer#0

# 4. Temperatura (thermal throttling)
adb shell dumpsys thermalservice | grep -i temperature
```

## Perfiles rápidos

| Perfil | Resolución | Bitrate | max-size | Uso |
|--------|-----------|---------|----------|-----|
| Competitivo | 1920x480 | 15M | 800 | Mínima latencia |
| Balanceado | 1600x720 | 30M | 1024 | Calidad + rendimiento |
| Calidad | 1920x480 | 50M | 1280 | Mejor imagen |

## Troubleshooting común

```bash
# UHID cursor invisible → presionar Ctrl derecho (liberar cursor)
# Si no funciona: SDL_VIDEODRIVER=x11 scrcpy ...

# Teclado no funciona → MOD+k dentro de scrcpy (configurar teclado físico)
# o: adb shell am start -a android.settings.HARD_KEYBOARD_SETTINGS

# GG Mouse se desactiva → whitelist batería
adb shell dumpsys deviceidle whitelist +com.zjx.ztezscreenshot
```

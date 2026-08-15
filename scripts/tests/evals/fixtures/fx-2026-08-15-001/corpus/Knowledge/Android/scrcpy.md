# scrcpy — Referencia rápida

> scrcpy + Free Fire. Para troubleshooting completo → skill `.agents/skills/scrcpy-freefire/`.

## Versiones mínimas (verificadas 2026-08-03)

| Feature usada en el setup | Versión mínima | Fuente |
|---|---|---|
| `--mouse=uhid` / `--keyboard=uhid` (control HID) | **≥ 2.0** | release v2.0 |
| `--video-buffer` | ≥ 1.18 | changelog oficial |
| `--render-expired-frames` | ≥ 1.19 | changelog oficial |
| `--stay-awake` | ≥ 1.5 | changelog oficial |
| `--power-off-on-close` | ≥ 1.20 · **recomendado ≥ 3.3.1** (fix #6146) | changelog oficial |

- **Mínimo recomendado para el setup gaming** (`scrcpy-freefire.sh`): **≥ 3.3.1**
  (cubre UHID + el fix de `--power-off-on-close`).
- **Verificado en el PC** (EndeavourOS/Arch): `scrcpy 4.1-1` (pacman) — `adb 1.0.41`.
- Nota: la release v4.0 migró SDL2 → SDL3; v4.1 agrega VP8/VP9. Sin impacto en los flags de arriba.

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

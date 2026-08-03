---
name: scrcpy-freefire
description: >
  scrcpy + Free Fire: mirroring del dispositivo con control HID, perfiles por
  plataforma (Qualcomm/Mediatek/Unisoc), diagnóstico de lag (FPS reales vs
  renderizado del juego) y troubleshooting. Incluye keymappers (GG Mouse, Mantis).
version: 1.0.0
---

# scrcpy-freefire — scrcpy + Free Fire

> **Problema:** Jugar Free Fire con teclado/mouse vía scrcpy da lag, el cursor
> UHID desaparece o el keymapper se desactiva.
>
> **Solución:** Perfiles de scrcpy optimizados por plataforma, protocolo de
> diagnóstico de lag en 4 pasos (para distinguir si el problema es scrcpy o el
> juego) y troubleshooting de keymappers.

---

## Señales de activación

| Señal | Ejemplo |
|---|---|
| Se menciona scrcpy, mirroring, streaming | "el mirror va con lag" |
| Se menciona Free Fire | "optimiza scrcpy para FF" |
| Se menciona GG Mouse, Mantis, keymapper | "el overlay de GG Mouse no aparece" |
| Se menciona FPS, lag, latencia | "va a 30fps" |
| Se menciona UHID, cursor, teclado | "el cursor no se ve" |

---

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

---

## Encoder por plataforma

```bash
# Qualcomm (Snapdragon)
ENCODER="--video-encoder=OMX.qcom.video.encoder.avc"

# Mediatek
ENCODER="--video-encoder=c2.mediatek.avc.encoder"

# Unisoc (ZTE Nubia)
ENCODER="--video-encoder=c2.unisoc.avc.encoder"
```

> Agregar `$ENCODER` al comando scrcpy. Si el encoder no es el correcto, el
> lag aumenta notablemente — este es el fix más común para Nubia ZTE (Unisoc).

---

## Diagnóstico de lag (protocolo en 4 pasos)

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

> **Regla de oro:** si `dumpsys gfxinfo` del juego muestra jank alto, el
> problema es el juego/dispositivo, no scrcpy. No cambiar config de scrcpy
> sin verificar esto primero.

---

## Perfiles rápidos

| Perfil | Resolución | Bitrate | max-size | Uso |
|--------|-----------|---------|----------|-----|
| Competitivo | 1920x480 | 15M | 800 | Mínima latencia |
| Balanceado | 1600x720 | 30M | 1024 | Calidad + rendimiento |
| Calidad | 1920x480 | 50M | 1280 | Mejor imagen |

---

## Keymappers (jugar con teclado/mouse)

### GG Mouse Pro 2 (recomendado para Free Fire)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.zjx.ztezscreenshot` |
| Activación | Shizuku |
| Riesgo ban | Muy bajo |

```bash
# Permisos (via ADB o rish)
adb shell appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow
adb shell appops set com.zjx.ztezscreenshot GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +com.zjx.ztezscreenshot
adb shell pm grant com.zjx.ztezscreenshot moe.shizuku.manager.permission.API_V23

# Abrir
adb shell am start -n com.zjx.ztezscreenshot/com.zjx.jyandroid.MainApp.MainActivity
```

### Mantis Gamepad Pro (alternativa)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.mantis.gamepadpro` |
| Activación | Shizuku o MantisBuddy |
| Ventaja | Motor NMC (no-cloning) — más seguro contra anti-cheats |

```bash
adb shell appops set com.mantis.gamepadpro SYSTEM_ALERT_WINDOW allow
adb shell appops set com.mantis.gamepadpro GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +com.mantis.gamepadpro
```

> 🚫 **Octopus NO usar para Free Fire** — usa clonación de apps (sandbox) que
> Garena detecta fácilmente. Riesgo alto de ban.

---

## Troubleshooting común

```bash
# UHID cursor invisible → presionar Ctrl derecho (liberar cursor)
# Si no funciona: SDL_VIDEODRIVER=x11 scrcpy ...

# Teclado no funciona → MOD+k dentro de scrcpy (configurar teclado físico)
# o: adb shell am start -a android.settings.HARD_KEYBOARD_SETTINGS

# GG Mouse se desactiva → whitelist batería
adb shell dumpsys deviceidle whitelist +com.zjx.ztezscreenshot
```

---

## Integración con otras skills

- **`android-adb`** — comandos ADB base (permisos, apps, screencap)
- **`shizuku-rikka`** — concesión de permisos privilegiados (SYSTEM_ALERT_WINDOW)
- **`android-game-opt`** — optimización de rendimiento adicional
- **`android-agent`** — agente orquestador Android

Referencia Knowledge/: `Knowledge/Android/scrcpy.md`, `Knowledge/Android/Keymappers.md`.

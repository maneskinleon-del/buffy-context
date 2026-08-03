---
name: android-adb
description: >
  Comandos ADB generales para Android: conexión, info del dispositivo, gestión
  de apps, permisos, rendimiento, DPI/resolución, capturas y logs. La referencia
  operativa de ADB para cualquier tarea de diagnóstico o automatización Android.
version: 1.0.0
---

# android-adb — Comandos ADB generales

> **Problema:** El agente necesita interactuar con un dispositivo Android vía ADB
> (diagnóstico, permisos, gestión de apps) pero no recuerda la sintaxis exacta de
> los comandos.
>
> **Solución:** Esta skill define la referencia de comandos ADB esenciales,
> organizados por categoría, con formato listo para copiar/ejecutar.

---

## Señales de activación

Cargar esta skill cuando:

| Señal | Ejemplo |
|---|---|
| Se menciona ADB, dispositivo, teléfono, serial | "conecta el teléfono" |
| Se necesita instalar/desinstalar/abrir una app | "instala este APK" |
| Se necesita conceder/verificar permisos | "el overlay no funciona" |
| Se necesita info del dispositivo | "¿qué modelo es?" |
| Se necesita captura de pantalla o logs | "saca un screenshot" |
| Diagnóstico de rendimiento de una app | "¿por qué va lento?" |

---

## Conexión

```bash
adb devices -l                              # Listar dispositivos
adb -s <serial> shell <cmd>                 # Comando a dispositivo específico
adb kill-server && adb start-server         # Resetear servidor ADB
adb connect <ip>:5555                       # Conectar WiFi
adb disconnect <ip>:5555                    # Desconectar WiFi
adb tcpip 5555                              # Habilitar TCP/IP (requiere USB)
```

> Si `adb devices` no muestra nada: verifica que la depuración USB esté activa
> en Opciones de desarrollador y que hayas aceptado la huella en el teléfono.

---

## Info del dispositivo

```bash
adb shell wm size                           # Resolución
adb shell wm density                        # DPI
adb shell getprop ro.product.model          # Modelo
adb shell getprop ro.board.platform         # Plataforma (SoC)
adb shell getprop ro.build.version.release  # Versión Android
adb shell dumpsys window | grep mCurrentFocus  # App en foreground
adb shell ip route                          # IP del dispositivo
```

---

## Apps

```bash
adb shell pm list packages -3               # Apps de terceros
adb shell pm list packages | grep <paq>     # Buscar paquete
adb shell pm path <package>                 # Ruta del APK
adb shell am start -n <paq>/<actividad>     # Abrir app
adb shell monkey -p <paq> 1                 # Abrir vía monkey
adb uninstall <package>                     # Desinstalar
adb install <apk>                           # Instalar
```

---

## Permisos

```bash
adb shell appops set <paq> <permiso> allow          # Conceder appop
adb shell appops get <paq> <permiso>                # Verificar appop
adb shell pm grant <paq> <permiso>                  # Conceder permiso
adb shell pm revoke <paq> <permiso>                 # Revocar permiso
adb shell dumpsys deviceidle whitelist +<paq>        # Batería sin restricciones
```

> ⚠️ `pm grant` falla para permisos especiales (SYSTEM_ALERT_WINDOW, WRITE_SETTINGS)
> con UID de shell en algunos ROMs. Si falla, usa Shizuku/rish (skill `shizuku-rikka`).

---

## Rendimiento

```bash
adb shell settings put global force_gpu_rendering 1
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb shell settings put global stay_on_while_plugged_in 7  # No dormir mientras carga
```

---

## DPI y resolución

```bash
adb shell wm size <WxH>                     # Cambiar resolución
adb shell wm density <dpi>                  # Cambiar DPI
adb shell wm size reset                     # Restaurar resolución
adb shell wm density reset                  # Restaurar DPI
```

---

## Capturas y logs

```bash
adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png  # Screenshot
adb shell screenrecord /sdcard/video.mp4    # Grabar pantalla (Ctrl+C para detener)
adb logcat -s <tag>                         # Logcat filtrado
adb shell dumpsys gfxinfo <paquete>         # Métricas de renderizado
adb shell dumpsys SurfaceFlinger            # Info del compositor
```

---

## Integración con otras skills

- **`shizuku-rikka`** — cuando `pm grant`/`appops` fallan con UID shell (permisos privilegiados sin root)
- **`android-game-opt`** — optimización de rendimiento para juegos
- **`scrcpy-freefire`** — mirroring y control del dispositivo
- **`android-agent`** — agente orquestador Android (detección + diagnóstico completo)
- **`vision-adapter`** — análisis de screenshots capturados con `screencap`

Referencia Knowledge/ para detalle: `Knowledge/Android/ADB.md`, `Knowledge/Android/Shizuku.md`.

# Android ADB — Referencia rápida

> Comandos ADB esenciales. Para detalle completo → skill `.agents/skills/android-adb/`.
> También útil: `Android/Shizuku.md` para comandos privilegiados sin root.

## Conexión

```bash
adb devices -l                              # Listar dispositivos
adb -s <serial> shell <cmd>                 # Comando a dispositivo específico
adb kill-server && adb start-server         # Resetear servidor ADB
adb connect <ip>:5555                       # Conectar WiFi
adb disconnect <ip>:5555                    # Desconectar WiFi
adb tcpip 5555                              # Habilitar TCP/IP (requiere USB)
```

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

## Permisos

```bash
adb shell appops set <paq> <permiso> allow          # Conceder appop
adb shell appops get <paq> <permiso>                # Verificar appop
adb shell pm grant <paq> <permiso>                  # Conceder permiso
adb shell pm revoke <paq> <permiso>                 # Revocar permiso
adb shell dumpsys deviceidle whitelist +<paq>        # Batería sin restricciones
```

## Rendimiento

```bash
adb shell settings put global force_gpu_rendering 1
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0
adb shell settings put global stay_on_while_plugged_in 7  # No dormir mientras carga
```

## DPI y resolución

```bash
adb shell wm size <WxH>                     # Cambiar resolución
adb shell wm density <dpi>                  # Cambiar DPI
adb shell wm size reset                     # Restaurar resolución
adb shell wm density reset                  # Restaurar DPI
```

## Capture y logs

```bash
adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png  # Screenshot
adb shell screenrecord /sdcard/video.mp4    # Grabar pantalla (Ctrl+C para detener)
adb logcat -s <tag>                         # Logcat filtrado
adb shell dumpsys gfxinfo <paquete>         # Métricas de renderizado
adb shell dumpsys SurfaceFlinger            # Info del compositor
```

## scrcpy (integrado)

```bash
scrcpy --mouse=uhid --keyboard=uhid         # Control tipo HID
scrcpy --no-audio                           # Sin audio (menos lag)
scrcpy --max-size=1024 -b 10M               # Escalar + bitrate bajo
scrcpy --turn-screen-off                    # Apagar pantalla del teléfono
scrcpy --print-fps                          # Mostrar FPS en terminal
```

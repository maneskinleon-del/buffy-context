---
name: android-game-opt
description: >
  Optimización de rendimiento para juegos Android vía Shizuku/ADB: CPU/gobernador,
  settings globales (GPU rendering, animaciones, batería), touch, thermal y
  perfiles por OEM. Incluye anti-patrones para no romper el sistema.
version: 1.0.0
---

# android-game-opt — Optimización de juegos Android

> **Problema:** El juego va lento, con lag o FPS bajos, y hay que optimizar el
> dispositivo sin root y sin romper nada.
>
> **Solución:** Secuencia de optimizaciones vía ADB/Shizuku: verificación previa,
> ajustes de GPU/animaciones, CPU, touch, thermal y perfiles por OEM. Con
> anti-patrones claros para no dañar el sistema.

---

## Señales de activación

| Señal | Ejemplo |
|---|---|
| Se menciona rendimiento, FPS, lag, juego | "Free Fire va a 30fps" |
| Se menciona Free Fire, GG Mouse, game boost | "optimiza mi Nubia para Free Fire" |
| Se menciona CPU, GPU, thermal, gobernador | "¿cómo bajo la temperatura?" |
| Optimización de batería para juegos | "la app se cierra al minimizar" |

---

## Verificación previa

```bash
# Verificar Shizuku corriendo
adb shell /data/local/tmp/rish -c "id"  # → uid=2000(shell)

# Backup de valor antes de cambiar
adb shell settings get global <key>
```

> ⚠️ Siempre guarda el valor original antes de modificar un setting global.
> Son reversibles con el mismo comando, pero el backup evita errores.

---

## CPU / Gobernador

```bash
# Ver gobernador actual
adb shell cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

# Cambiar a performance (si el kernel lo permite)
adb shell su -c "echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"
```

> ⚠️ `sysctl -w` está bloqueado por SELinux en casi todos los kernels stock.
> `su` necesario para `echo` a sysfs. En kernels stock no tiene efecto — no insistir.

---

## Settings globales

```bash
# Forzar renderizado GPU
adb shell settings put global force_gpu_rendering 1

# Desactivar animaciones (reduce lag en input)
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

# No dormir mientras carga
adb shell settings put global stay_on_while_plugged_in 7

# Desactivar optimización de batería agresiva
adb shell settings put global power_savings_mode 0
```

---

## Touch

```bash
# Sensibilidad táctil (depende del OEM)
adb shell settings put global touch_pressure_scale 0.001
adb shell settings put system touch_pressure_high_application 0

# Desactivar ghost touch al cargar (útil para gaming)
adb shell settings put global charging_optimization 0
```

---

## Thermal

```bash
# Ver temperatura
adb shell dumpsys thermalservice | grep -i temperature

# Modos térmicos (depende del OEM)
adb shell settings put global thermal_control 0  # Desactivar thermal throttling
```

> ⚠️ Desactivar thermal throttling puede causar sobrecalentamiento. Usar con
> moderación y monitorizando la temperatura.

---

## Game profiles (por OEM)

| OEM | Modo juego | Comando |
|-----|-----------|---------|
| Xiaomi | Game Turbo | `adb shell am broadcast -a com.xiaomi.gamebooster.action.ENTER` |
| Samsung | Game Booster | Via app Game Booster |
| OnePlus | Game Space | Via app Game Space |

---

## Anti-patrones

- ❌ No forzar `sysctl -w` si SELinux lo bloquea
- ❌ No cambiar gobernador CPU en kernels stock (no tiene efecto)
- ❌ No modificar `vm.swappiness` en Android (no aplica igual)
- ❌ No desactivar thermal throttling sin monitorizar temperatura
- ✅ Shizuku es suficiente para la mayoría de optimizaciones

---

## Integración con otras skills

- **`android-adb`** — comandos ADB base (conexión, permisos, apps)
- **`shizuku-rikka`** — permisos privilegiados cuando ADB shell no alcanza
- **`scrcpy-freefire`** — diagnóstico de FPS del juego vs scrcpy (gfxinfo)
- **`android-agent`** — agente orquestador Android

Referencia Knowledge/: `Knowledge/Android/GameOptimization.md`.

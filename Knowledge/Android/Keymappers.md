# Keymappers Android — Referencia

> Keymappers para jugar con teclado/mouse en Android.
> Para troubleshooting completo → skill `.agents/skills/scrcpy-freefire/`.

## GG Mouse Pro 2 (recomendado)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.zjx.ztezscreenshot` |
| Activación | Shizuku |
| Free Fire | ✅ Excelente |
| Drift | Bajo |

```bash
# Permisos
adb shell appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow
adb shell appops set com.zjx.ztezscreenshot GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +com.zjx.ztezscreenshot
adb shell pm grant com.zjx.ztezscreenshot moe.shizuku.manager.permission.API_V23

# Abrir
adb shell am start -n com.zjx.ztezscreenshot/com.zjx.jyandroid.MainApp.MainActivity
```

## Mantis Gamepad Pro (alternativa recomendada)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.mantis.gamepadpro` |
| Activación | Shizuku o MantisBuddy |
| Free Fire | ✅ Alta compatibilidad |
| Drift | Mínimo |

```bash
adb shell appops set com.mantis.gamepadpro SYSTEM_ALERT_WINDOW allow
adb shell appops set com.mantis.gamepadpro GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +com.mantis.gamepadpro
```

Ventaja: usa motor NMC (no-cloning) — más seguro contra anti-cheats.

## Panda Mouse Pro (ligero)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.panda.mousepro` |
| Activación | Shizuku o ADB |
| Free Fire | ⚠️ Moderada |
| Drift | Medio |

## Octopus (NO recomendado para Free Fire)

> ⚠️ **Riesgo alto de ban.** Usa clonación de apps (sandbox) que Garena detecta fácilmente.
> No usar para Free Fire — prefiere GG Mouse Pro o Mantis.

## Comparativa

| Keymapper | Activación | Free Fire | Drift | Riesgo ban |
|---|---|---|---|---|
| GG Mouse Pro 2 | Shizuku | ✅ Excelente | Bajo | Muy bajo |
| Mantis Gamepad Pro | Shizuku/ADB | ✅ Excelente | Mínimo | Muy bajo |
| Panda Mouse Pro | Shizuku/ADB | ⚠️ Moderada | Medio | Bajo |
| Octopus | ADB | ❌ Alto riesgo | Variable | 🚫 MUY ALTO |

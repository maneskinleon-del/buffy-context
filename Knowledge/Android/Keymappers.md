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

## Mantis Gamepad Pro (alternativa SOLO para control físico)

> ⚠️ **Actualizado 2026** — sigue activo (v3.4.8+, 54K reviews), pero v3.x tiene suscripción Pro (~$9.99) y reportes de inestabilidad (crashes, input lag). **No confundir con Octopus**: el baneable por clonación es Octopus; Mantis usa NMC sin clonar (riesgo de ban bajo, comparable a GG Mouse Pro 2).
>
> ❗ **IMPORTANTE — Mantis es mapper de GAMEPAD (control físico), NO de teclado/mouse.** No sirve para jugar con teclado+mouse desde PC (caso scrcpy). Solo relevante si jugás con control Xbox/PS/bluetooth en el teléfono.

| Aspecto | Detalle |
|---|---|
| Paquete | `app.mantispro.gamepad` |
| Activación | Android 11+: on-device (Wireless Debugging) · Android 10-: MantisBuddy (PC/segundo Android) |
| Free Fire | ✅ Alta compatibilidad |
| Drift | Mínimo |

```bash
adb shell appops set app.mantispro.gamepad SYSTEM_ALERT_WINDOW allow
adb shell appops set app.mantispro.gamepad GET_USAGE_STATS allow
adb shell dumpsys deviceidle whitelist +app.mantispro.gamepad
```

Ventaja: usa motor NMC (no-cloning) — más seguro contra anti-cheats. En Android 11+ activa in-app con Wireless Debugging (sin PC).

## Panda Mouse Pro (ligero)

| Aspecto | Detalle |
|---|---|
| Paquete | `com.panda.mousepro` |
| Activación | Shizuku o ADB |
| Free Fire | ⚠️ Moderada |
| Drift | Medio |

## Octopus (NO recomendado para Free Fire)

> ⚠️ **Riesgo alto de ban.** Usa clonación de apps (sandbox) que Garena detecta fácilmente. **Es el mapper que la gente confunde con Mantis**: la diferencia es la clonación — Mantis (NMC) no clona, Octopus sí.
> No usar para Free Fire — prefiere GG Mouse Pro o Mantis.

## Comparativa

| Keymapper | Activación | Free Fire | Drift | Riesgo ban |
|---|---|---|---|---|
| GG Mouse Pro 2 | Shizuku | ✅ Excelente | Bajo | Muy bajo |
| Mantis Gamepad Pro | Wireless Debugging / Shizuku | ✅ Excelente | Mínimo | Muy bajo |
| Panda Mouse Pro | Shizuku/ADB | ⚠️ Moderada | Medio | Bajo |
| Octopus | ADB | ❌ Alto riesgo | Variable | 🚫 MUY ALTO |

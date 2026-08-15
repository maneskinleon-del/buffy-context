# HyperOS Hardening — Referencia

> Hardening y debloat para Xiaomi HyperOS/MIUI.
> Skill relacionada: `.agents/skills/hyperos-hardening/`.

## Debloat (desinstalar bloatware)

```bash
# App del sistema (se desinstala solo para el usuario actual)
adb shell pm uninstall -k --user 0 <package>

# Apps comunes de HyperOS que se pueden eliminar:
# com.miui.analytics         → Analytics
# com.miui.notes             → Notas Mi
# com.miui.video             → Video Mi
# com.miui.player            → Música Mi
# com.miui.browser           → Mi Browser
# com.miui.miservice         → Servicios Mi
# com.miui.micloudsync       → Mi Cloud
# com.xiaomi.discover        → Discover
# com.xiaomi.mirecycle       → Mi Recycle
# com.xiaomi.glgm            → Game Center
```

## Privacidad

```bash
# Desactivar analytics
adb shell pm disable-user --user 0 com.miui.analytics

# Desactivar anuncios en sistema
adb shell settings put system miui_ad_toggle 0
adb shell settings put global adb_enabled 0

# Desactivar envío de datos
adb shell settings put secure send_action_app_error 0
adb shell settings put global online_manual_url ""
```

## Optimización batería

```bash
# Agregar app a whitelist (no la mata el sistema)
adb shell dumpsys deviceidle whitelist +<package>

# Quitar de whitelist
adb shell dumpsys deviceidle whitelist -<package>
```

## ⚠️ Notas

- **Hacer backup** antes de desinstalar apps del sistema
- Algunas apps rotan funcionalidades (ej. Mi Cloud rompe sincronización)
- `pm uninstall -k --user 0` es reversible con `pm install-existing <package>`
- Un `adb reboot` puede restaurar apps del sistema
- Shizuku también funciona para estos comandos sin root

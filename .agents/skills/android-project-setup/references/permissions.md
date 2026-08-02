# Permisos Android — concesión vía ADB (setup de apps del usuario)

## Set estándar (script `grant_permissions.sh`)

| Permiso | Comando | Para qué |
|---|---|---|
| Shizuku API | `pm grant <pkg> moe.shizuku.manager.permission.API_V23` | Comandos privilegiados (GameBoost Pro usa Shizuku) |
| Overlay | `appops set <pkg> SYSTEM_ALERT_WINDOW allow` | Panel flotante de métricas |
| Usage stats | `appops set <pkg> GET_USAGE_STATS allow` | Detección de app en primer plano |
| Background | `appops set <pkg> RUN_IN_BACKGROUND allow` | Evita kills agresivos |
| Batería | `dumpsys deviceidle whitelist +<pkg>` | Evita doze/suspensión del servicio |

## Shizuku — activación y verificación

```bash
# ¿Está instalado?
adb shell pm path moe.shizuku.privileged.api

# Iniciar el servidor vía ADB (starter del manager)
adb shell sh /data/local/tmp/shizuku_starter.sh

# ¿El servicio responde? (rish)
adb shell /data/local/tmp/rish -c "id"
```

- Si `pm grant` falla con el API_V23: Shizuku no está corriendo → reactivar con el starter.
- rish se resuelve: env `RISH` > `~/bin/rish` > `PATH` (ver `scripts/kimi_vision.js` del repo buffy-context).

## Permisos manuales (no se pueden conceder por ADB)

- **AccessibilityService**: el usuario debe activarlo en Ajustes (GameBoost Pro lo usa para
  bloqueo de gestos). Se puede abrir la pantalla:
  `adb shell am start -a android.settings.ACCESSIBILITY_SETTINGS`
- **Notificaciones** (Android 13+): `appops set <pkg> POST_NOTIFICATION allow` (a veces requiere diálogo).

## Verificación de estado

```bash
adb shell appops get <pkg> SYSTEM_ALERT_WINDOW     # debe decir "allow"
adb shell pm grant <pkg> moe.shizuku.manager.permission.API_V23
adb shell dumpsys deviceidle whitelist | grep <pkg>
```

## Troubleshooting

- **App muere en background**: whitelist de batería + RUN_IN_BACKGROUND + notificación foreground.
- **Overlay no aparece**: `appops` OK pero falta `Settings.canDrawOverlays()` dentro de la app.
- **Force-stop ignorado**: es un Device Admin → ver `references/devices.md` (truco pm disable-user).

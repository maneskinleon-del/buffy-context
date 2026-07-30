# Shizuku + rish — Referencia rápida

> Servicio de escalación de privilegios para Android sin root.
> Skill relacionada: `.agents/skills/shizuku-rikka/`.

## Setup

1. Instalar: `moe.shizuku.privileged.api`
2. Abrir app → "Start"
3. Verificar: `adb shell /data/local/tmp/rish -c "id"` → `uid=2000(shell)`

## Comandos básicos con rish

```bash
rish -c "id"                                    # Verificar que funciona
rish -c "pm grant <paq> <permiso>"              # Conceder permiso
rish -c "pm revoke <paq> <permiso>"             # Revocar permiso
rish -c "settings put global <key> <val>"       # Cambiar setting global
rish -c "settings put system <key> <val>"       # Cambiar setting system
rish -c "appops set <paq> <permiso> allow"      # Conceder appop
```

## Permisos comunes para Shizuku

```bash
# Otorgar permisos a apps vía Shizuku
adb shell pm grant <app_package> moe.shizuku.manager.permission.API_V23
```

## Optimización batería (whitelist)

```bash
adb shell dumpsys deviceidle whitelist +moe.shizuku.privileged.api
```

## Diferencia con root

| | Shizuku | Root |
|---|---|---|
| Acceso | shell (UID 2000) | root (UID 0) |
| Persistencia | Se cierra al reiniciar | Permanente |
| Seguridad | No modifica /system | Acceso total |
| `su -c` | ❌ | ✅ |
| `sysctl -w` | ❌ (SELinux) | ⚠️ (depende) |
| `pm disable` | ✅ | ✅ |
| `settings put` | ✅ | ✅ |

## Troubleshooting

```bash
# Shizuku no inicia
adb shell sh /data/local/tmp/shizuku_starter.sh

# Verificar versión
adb shell dumpsys package moe.shizuku.privileged.api | grep version

# Rish no encontrado
adb shell ls -la /data/local/tmp/rish
```

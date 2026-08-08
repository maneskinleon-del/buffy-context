# Shizuku + rish — Referencia rápida

> Servicio de escalación de privilegios para Android sin root.
> Skill relacionada: `.agents/skills/shizuku-rikka/`.
> Bug del fork Shizuku+ (resuelto 2026-08-08): `ai-context/SHIZUKU-RISH-BUG.md`.

## Shizuku+: fork vs clásico — veredicto (2026-08-08, Mi 10 / HyperOS)

- **Shizuku+ 13.6.0.r2220** (`af.shizuku.*`, daemon nativo `shizuku_plus_server`):
  bonito, watchdog, reconexión automática. PERO **no funciona rish desde Termux**:
  el diálogo de autorización se muestra y «Allow» procesa, pero el daemon rechaza
  la sesión: `Caller (uid <termux>) is not an attached client` →
  `IllegalStateException: Not an attached client` dentro de
  `af.shizuku.manager.shell.Shell.main`. Verificado con kit re-exportado (md5 del
  APK == loader), Termux autorizado en la app, batería/AppOps cubiertos.
- **RESUELTO — usar la versión clásica** (RikkaApps/Shizuku v13.6.0.r1086):
  servidor `shizuku_server` (app_process) + kit exportado desde la propia app;
  `rish -c "id"` desde Termux responde `uid=2000(shell)` sin más atajaros.
- Workaround si vuelves al fork: el módulo `RishShizukuManager.js` (de AutoJS6,
  `org.autojs.autojs6`) funciona porque esa app **declara el permiso
  `moe.shizuku.manager.permission.API_V23` y el provider Shizuku** en su manifest;
  rish desde AutoJS usa `RISH_APPLICATION_ID=<package de la app>` y el attach
  funciona via provider. Termux no declara ese permiso (`pm grant` → «has not
  requested»), por eso el server lo trata como sesión shell genérica y lo
  rechaza en el fork.

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

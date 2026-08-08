---
name: shizuku-rikka
description: >
  Shizuku + rish: escalación de privilegios Android sin root. Setup (Wireless
  Debugging / ADB / Termux), uso de rish desde Termux, concesión de permisos
  (pm grant, appops), settings del sistema y troubleshooting. Cubre también Sui.
version: 1.0.0
---

# shizuku-rikka — Shizuku + rish (privilegios sin root)

> **Problema:** ADB shell (UID 2000) no puede ejecutar `pm grant` de permisos
> especiales, `appops set`, ni modificar settings. Root no está disponible.
>
> **Solución:** Shizuku (de RikkaW) ejecuta un daemon `app_process` con identidad
> shell/root y expone un servicio Binder. Con `rish` desde Termux se ejecutan
> comandos privilegiados sin root y sin desbloquear el bootloader.

---

## Señales de activación

| Señal | Ejemplo |
|---|---|
| `pm grant`/`appops` fallan con SecurityException | "no me deja conceder el permiso" |
| Se menciona Shizuku, rish, privilegios | "activa Shizuku" |
| Permisos especiales (overlay, accesibilidad, WRITE_SETTINGS) | "el overlay no aparece" |
| Se menciona Termux + permisos | "concede X desde Termux" |
| Se menciona Sui, Magisk, root alternativo | "¿qué es Sui?" |

---

## Cómo funciona

1. **Servidor:** inicia un daemon `app_process` con identidad `shell` (ADB) o `root`
2. **Binder:** expone un servicio Binder; las apps envían peticiones privilegiadas
3. **Seguridad:** centraliza el acceso elevado en una sola app de confianza

---

## Ecosistema Rikka (RikkaW / RikkaApps)

**RikkaW** es el desarrollador de Shizuku y otras herramientas de Android power-user.

| Proyecto | Descripción | Repositorio |
|---|---|---|
| **Shizuku** | Elevar privilegios vía ADB/root sin root completo | [RikkaApps/Shizuku](https://github.com/RikkaApps/Shizuku) |
| **Shizuku-API** | Librería de API para integración | [RikkaApps/Shizuku-API](https://github.com/RikkaApps/Shizuku-API) |
| **Sui** | Implementación root (Magisk/Zygisk) de la API Shizuku | [RikkaApps/Sui](https://github.com/RikkaApps/Sui) |
| **App Ops** | Gestor de permisos fino usando Shizuku | Parte de la org RikkaApps |
| **Dhizuku** | Usar APIs Device Policy Manager vía Shizuku | Parte de la org RikkaApps |

---

## Setup (3 métodos)

### Método 1: Wireless Debugging (Android 11+, sin PC)
1. Opciones de desarrollador → **Wireless Debugging**
2. App Shizuku → sección Wireless Debugging
3. Parear con el código que muestra Android
4. Iniciar Shizuku desde la app

### Método 2: ADB vía PC
```bash
adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh
```

### Método 3: Vía Termux (en el dispositivo)
```bash
sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh
```

### Verificar que corre
```bash
cmd -l 2>&1 | grep -i shizuku
adb shell /data/local/tmp/rish -c "id"   # → uid=2000(shell)
```

---

## Uso de rish desde Termux

### Exportar rish desde la app Shizuku
1. Shizuku → **"Usar Shizuku en apps de terminal"** → **"Exportar archivos"**
2. Produce `rish` (script) y `rish_shizuku.dex`
3. Copiar a Termux:
```bash
mkdir -p ~/bin
cp /sdcard/Rish/rish ~/bin/
cp /sdcard/Rish/rish_shizuku.dex ~/bin/
chmod 755 ~/bin/rish
chmod 444 ~/bin/rish_shizuku.dex   # ⚠️ Android 14+: DEBE ser read-only (444)
```
> En Android 14+, si el `.dex` no es read-only, `app_process` no lo carga y rish falla.

### Ejecutar comandos privilegiados
```bash
export RISH_APPLICATION_ID=com.termux
export MANAGER_APPLICATION_ID=moe.shizuku.privileged.api

~/bin/rish pm list packages
~/bin/rish pm grant <package> <permission>
~/bin/rish appops set <package> <OP> allow
~/bin/rish settings put secure <key> <value>
~/bin/rish   # shell interactivo privilegiado
```

### Alternativa: addon `termux-shizuku` (F-Droid)
```bash
shizuku pm list packages
shizuku pm grant com.zjx.ztezscreenshot android.permission.SYSTEM_ALERT_WINDOW
shizuku appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow
shizuku settings put secure enabled_accessibility_services <package>/<service>
```

---

## Permisos comunes

### Permisos peligrosos (pm grant)
```bash
# Draw Over Other Apps
rish pm grant <package> android.permission.SYSTEM_ALERT_WINDOW

# Modify System Settings
rish pm grant <package> android.permission.WRITE_SETTINGS

# Install Unknown Apps
rish pm grant <package> android.permission.REQUEST_INSTALL_PACKAGES

# All Files Access
rish pm grant <package> android.permission.MANAGE_EXTERNAL_STORAGE
```

### AppOps
```bash
rish appops set <package> 24 allow        # 24 = SYSTEM_ALERT_WINDOW
rish appops get <package>
# 24 = SYSTEM_ALERT_WINDOW · 65 = MANAGE_EXTERNAL_STORAGE
# 68 = REQUEST_INSTALL_PACKAGES · 88 = ACCESS_MEDIA_LOCATION
```

### Settings del sistema
```bash
# Accesibilidad
rish settings put secure enabled_accessibility_services <package>/<accessibility_service>
rish settings put secure accessibility_enabled 1

# Global
rish settings put global <key> <value>
```

---

## Shizuku vs Root

| | Shizuku | Root |
|---|---|---|
| Acceso | shell (UID 2000) | root (UID 0) |
| Persistencia | Se cierra al reiniciar | Permanente |
| Seguridad | No modifica /system | Acceso total |
| `su -c` | ❌ | ✅ |
| `sysctl -w` | ❌ (SELinux) | ⚠️ (depende) |
| `pm disable` | ✅ | ✅ |
| `settings put` | ✅ | ✅ |

## Sui — alternativa root

Módulo Magisk/Zygisk que implementa la API de Shizuku con root. Apps compatibles
con Shizuku funcionan automáticamente. Persiste entre reinicios (a diferencia de
ADB-Shizuku).

---

## Troubleshooting

| Problema | Solución |
|---|---|
| `rish: permission denied` | `rish_shizuku.dex` en el mismo dir; permisos 444 |
| `Cannot find service` | Shizuku no corre — iniciarlo desde la app |
| `pm grant: SecurityException` | Usar `rish` (identidad shell/root), no ADB directo |
| `appops: requires MANAGE_APP_OPS_MODES` | Usar `rish appops set` |
| No persiste tras reinicio | Reiniciar vía Wireless Debugging o ADB |
| `Waiting for Shizuku authorization...` y tras «Allow» el servidor rechaza: `Caller (uid X) is not an attached client` | Fork **Shizuku+** (af.shizuku.*, daemon nativo `shizuku_plus_server`): bug del attach de sesión shell. Probado en Mi 10 / HyperOS con Shizuku+ 13.6.0.r2220: la app sí acepta apps autorizadas (check=true en Gestión de aplicaciones), el diálogo ShellConsent aparece y Allow se procesa, pero el proceso hijo lanzado por el daemon es rechazado con `IllegalStateException: Not an attached client` (dentro de `af.shizuku.manager.shell.Shell.main`). Ver ficha `SHIZUKU-RISH-BUG`. **Vuelve al fork clásico** (RikkaApps/Shizuku) que exprime mejor los recursos y no tiene esta limitante; o corre el módulo RishShizukuManager.js desde AutoJS (org.autojs.autojs6 declara el permiso API_V23 y puede attachar vía intent del provider). |

### Fork Shizuku+ vs clásico — decisión de versión (2026-08-08)

- **Shizuku+ (fork af.shizuku.*, `shizuku_plus_server`)**: visual más bonito, watchdog,
  reconexión automática al reiniciar. BUT: en HyperOS/MIUI el attach de sesión shell
  desde Termux falla siempre con «not an attached client» (no se pudo resolver;
  probado con kit re-exportado del propio fork, md5 del APK == loader).
- **Verdict (referencia experiencia)**: cambio de resto a la versión oficial clásica
  de RikkaApps/Shizuku que con el Mi 10/HyperOS daba servicio: apps autorizadas +
  rish desde Termux conectaban.
- En el fork, una app AUTORIZADA (p.ej. org.autojs.autojs6 que declara
  `org.autojs.autojs6/rikka.shizuku.ShizukuProvider` y usa permiso
  `moe.shizuku.manager.permission.API_V23`) puede conectar; el módulo
  RishShizukuManager.js de las skills/../scripts lo usa como `RISH_APPLICATION_ID`.

---

## Quick reference

```bash
# Check running
cmd -l | grep shizuku

# Overlay
rish pm grant com.zjx.ztezscreenshot android.permission.SYSTEM_ALERT_WINDOW
rish appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow

# Accesibilidad
rish settings put secure enabled_accessibility_services com.zjx.ztezscreenshot/.GGService
rish settings put secure accessibility_enabled 1

# Listar paquetes / shell interactivo
rish pm list packages
rish
```

---

## Integración con otras skills

- **`android-adb`** — comandos ADB base (conexión, diagnóstico)
- **`hyperos-hardening`** — blindaje completo contra MIUI/HyperOS vía rish
- **`android-agent`** — agente orquestador Android (verificación de Shizuku)
- **Script `scripts/kimi_vision.js`** — auto-concesión de permisos detectados por visión (usa rish)

Referencia Knowledge/: `Knowledge/Android/Shizuku.md`.

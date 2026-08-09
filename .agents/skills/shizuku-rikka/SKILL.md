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

> **Ruta canónica (usar por defecto):** kit `rish` exportado desde la app Shizuku
> + `~/bin`. **Fallback:** addon `termux-shizuku` (F-Droid).
> ⚠️ El kit exportado usa el patrón **`rish -c "comando"`** — el script `rish`
> espera `-c` como primer argumento; sin `-c`, el servidor ejecuta `sh <arg>`
> (trata el comando como path de script) y muere con `exit 127` en logcat
> (mensaje `RISH: exited with 127`) — ver troubleshooting.

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
> ⚠️ `.dex` con 444 no se sobreescribe con `cp` — mover con `mv` desde un tmp.

### Ejecutar comandos privilegiados (canónica — con `-c`)
```bash
export RISH_APPLICATION_ID=com.termux
export MANAGER_APPLICATION_ID=moe.shizuku.privileged.api

~/bin/rish -c "id"                      # → uid=2000(shell)
~/bin/rish -c "pm list packages"
~/bin/rish -c "pm grant <package> <permission>"
~/bin/rish -c "appops set <package> <OP> allow"
~/bin/rish -c "settings put secure <key> <value>"
~/bin/rish                            # shell interactivo privilegiado
```

### Watchdog (auto-reinicio sin root)
El clásico NO tiene watchdog propio (el fork sí). En Termux se envuelve con ADB
loopback (5555) que nunca se cae por red — no requiere Wi-Fi real:
```bash
# ~/bin/shizuku-watchdog.sh: vigila shizuku_server cada N s (default 30)
# Si muere: lanza la app (MainActivity) → la app detecta el adb wireless 5555
# y re-arranca el server SOLA (validado: kill   pidof → relanzamiento OK)
nohup ~/bin/shizuku-watchdog.sh 30 > /dev/null 2>&1 &
```
Detalle: si la app ya está arriba, `am start` no para el proceso caído; el
watchdog usa la detección de adb en 5555 para que la misma app rebote el
server. Matar el server a propósito solo desde `rish -c "kill -9 <pid>"`
(adb shell falla: uid distinto).

### Fallback: addon `termux-shizuku` (F-Droid)
Usar solo si el exportado no es usable. Requiere el paquete del addon
(`termux-shizuku`) instalado desde F-Droid — NO es suficiente `termux-api`:
```bash
shizuku pm list packages
shizuku pm grant com.zjx.ztezscreenshot android.permission.SYSTEM_ALERT_WINDOW
shizuku appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow
shizuku settings put secure enabled_accessibility_services <package>/<service>
```
> El addon usa la API nativa (sin wrapper app_process); puede estar algo desactualizado
> en F-Droid vs el `rish` exportado — usar como fallback.

---

## Permisos comunes

### Permisos peligrosos (pm grant)
```bash
# Draw Over Other Apps
rish -c "pm grant <package> android.permission.SYSTEM_ALERT_WINDOW"

# Modify System Settings
rish -c "pm grant <package> android.permission.WRITE_SETTINGS"

# Install Unknown Apps
rish -c "pm grant <package> android.permission.REQUEST_INSTALL_PACKAGES"

# All Files Access
rish -c "pm grant <package> android.permission.MANAGE_EXTERNAL_STORAGE"
```

### AppOps
```bash
rish -c "appops set <package> 24 allow"        # 24 = SYSTEM_ALERT_WINDOW
rish -c "appops get <package>"
# Índices OP_*: AOSP 8.0+ (API 26+, estables desde Android 8);
# 24 = SYSTEM_ALERT_WINDOW · 65 = MANAGE_EXTERNAL_STORAGE
# 68 = REQUEST_INSTALL_PACKAGES · 88 = ACCESS_MEDIA_LOCATION
# ⚠️ Verificables con `rish -c "appops get <pkg>"` — en HyperOS/MIUI algún
#    índice puede diferir; siempre validar con el dump real antes de asumir.
```

### Settings del sistema
```bash
# Accesibilidad
rish -c "settings put secure enabled_accessibility_services <package>/<accessibility_service>"
rish -c "settings put secure accessibility_enabled 1"

# Global
rish -c "settings put global <key> <value>"
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
| `Waiting for Shizuku authorization...` y tras «Allow» el servidor rechaza: `Caller (uid X) is not an attached client` | Es el fork **Shizuku+** (`af.shizuku.*`, daemon `shizuku_plus_server`): bug del attach de sesión shell en HyperOS/MIUI / Termux. **Veredicto: usar la app clásica de RikkaApps/Shizuku** (conecta sin limitante). Ficha de debugging: `SHIZUKU-RISH-BUG.md` en `ai-context/`. |
| `rish <cmd>` muere silencioso; logcat `RISH: exited with 127` | El script del kit espera `-c`: ejecutar como `rish -c "cmd"` (sin `-c`, trata el cmd como path y falla). |
| `.dex` no se puede re-reemplazar (`Permission denied` al `cp`) | `mv` desde un tmp (el dex es 444 por diseño en Android 14+) |

### Fork Shizuku+ vs clásico (veredicto)

- **Usar la app clásica** (RikkaApps/Shizuku del Play/F-Droid): con el Mi 10 /
  HyperOS el servidor `shizuku_server` conecta sin problema y `rish -c "cmd"`
  desde Termux responde `uid=2000(shell)`.
- **Fork Shizuku+** (`af.shizuku.*`, daemon `shizuku_plus_server`): watchdog y
  reconexión, pero el attach de sesión shell desde Termux rechaza con
  `not an attached client` en el Mi 10 / HyperOS (ver ficha `SHIZUKU-RISH-BUG.md`).
- Workaround noo-fork: módulo AutoJJ6 vía provider (declara `API_V23`),
  o AutoJS6 + `RishShizukuManager.js` — detenga en la ficha (el archivo
  instalado en /sdcard/Download como `módulo_rish.js.txt`).

---

## Quick reference

```bash
# Check running
cmd -l | grep shizuku

# Overlay
rish -c "pm grant com.zjx.ztezscreenshot android.permission.SYSTEM_ALERT_WINDOW"
rish -c "appops set com.zjx.ztezscreenshot SYSTEM_ALERT_WINDOW allow"

# Accesibilidad
rish -c "settings put secure enabled_accessibility_services com.zjx.ztezscreenshot/.GGService"
rish -c "settings put secure accessibility_enabled 1"

# Listar paquetes / shell interactivo
rish -c "pm list packages"
rish
```

---

## Integración con otras skills

- **`android-adb`** — comandos ADB base (conexión, diagnóstico)
- **`hyperos-hardening`** — blindaje completo contra MIUI/HyperOS vía rish
- **`android-agent`** — agente orquestador Android (verificación de Shizuku)
- **Script `scripts/kimi_vision.js`** — auto-concesión de permisos detectados
  por visión (usa rish)
- **`xiaomi-adb-tricks`** — trucos adb/rish específicos de MIUI/HyperOS

Referencia Knowledge/: `Knowledge/Android/Shizuku.md`.
Fichas de debugging: `ai-context/SHIZUKU-RISH-BUG.md` (bitácora resolvida del
attach de sesión Shell en el fork Shizuku+ y el fix clásico `-c`).

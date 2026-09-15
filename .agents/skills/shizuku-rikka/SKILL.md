---
name: shizuku-rikka
description: >
  Shizuku + rish: escalación de privilegios Android sin root. Setup (Wireless
  Debugging / ADB / Termux), uso de rish desde Termux, concesión de permisos
  (pm grant, appops), settings del sistema y troubleshooting. Cubre también Sui.
  Incluye evidencia operacional del Watchdog Shizuku Recovery (2026-09-12,
  Shizuku 13.6.0): starter nativo, serial ADB dinámico y criterio mecánico de
  recuperación. LADB_RECOVERY_MECHANICAL = VERIFIED;
  SHIZUKU_FUNCTIONAL_RECOVERY = VERIFIED. SERIAL_CHANGE = VERIFIED.
  WATCHDOG_V0 = VERIFIED (in-session). WATCHDOG_V1 = VERIFIED (daemonized,
  session-teardown scope). MULTI_EVENT_STORM = VERIFIED (daemonized).
  TERMUX_FORCE_STOP = VERIFIED (app-level kill scope). REBOOT_BOOT_SUPERVISION
  = VERIFIED (boot-glue scope). SHIZUKU_FUNCTIONAL_POST_REBOOT = VERIFIED.
  REBOOT_PERSISTENCE = VERIFIED (boot-glue supervision scope).
  REBOOT_AUTONOMOUS_RECOVERY = NOT_TESTED; Termux:Boot app-driven supervision
  (com.termux.boot) = NOT_TESTED. Nunca resumir como "WATCHDOG = VERIFIED" ni
  como "REBOOT = VERIFIED".
version: 1.3.0
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
adb -s "$SERIAL" shell /data/local/tmp/shizuku
```

### Método 3: Vía Termux (en el dispositivo)
Solo con contexto shell/UID 2000 (ADB/LADB/Wireless Debugging). Termux como
app normal NO es equivalente automático a shell 2000:
```bash
# requiere transporte ADB previo; el starter corre con identidad shell
adb -s "$SERIAL" shell /data/local/tmp/shizuku
```

> **Starter en Shizuku 13.6.0 (evidencia 2026-09-12, Mi 10 / HyperOS):** el
> starter es el binario nativo **`/data/local/tmp/shizuku`** (proviene del
> `libshizuku.so` de la arquitectura instalada). **No asumir `start.sh`:**
> `sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh` NO existe en
> esta instalación/versión, y `moe.shizuku.privileged.api.Server` NO es el
> mecanismo de arranque válido observado. Verificar el mecanismo según la
> versión instalada antes de arrancar.

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
El clásico NO tiene watchdog propio (el fork sí). El patrón actual (validado
en el Watchdog Shizuku Recovery 2026-09-12) es el reinicio directo vía ADB
con serial dinámico — no requiere Wi-Fi real:
```bash
# ~/bin/shizuku-watchdog.sh: vigila shizuku_server cada N s (default 30)
# Si muere: detecta el serial dinámicamente (estado "device") y ejecuta
# /data/local/tmp/shizuku → nuevo PID (validado: kill   pidof → relanzamiento OK)
nohup ~/bin/shizuku-watchdog.sh 30 > /dev/null 2>&1 &
```
> **Supervisión persistente entre sesiones (VALIDADO):** termux-services/
> runit (`runsv`) con `service/shizuku-watchdog/run` — el patrón `nohup` de
> fondo muere con el teardown de la sesión. Ver `WATCHDOG_V1` en la sección
> de evidencia y el repo `~/ladb-shizuku-recovery`.
Matar el server a propósito solo desde `rish -c "kill -9 <pid>"`
(adb shell falla: uid distinto).

#### Serial ADB dinámico (obligatorio)
NO usar `127.0.0.1:5555` como serial fijo. Detectar dinámicamente un
dispositivo cuyo estado sea `device`, con esta prioridad:
1. serial `_adb-tls-connect`;
2. serial TCP/local `host:port` (campo con `:`);
3. otro dispositivo con estado `device`, si corresponde.

Después de obtener el serial, usar SIEMPRE `adb -s "$SERIAL"` de forma
explícita en cada operación ADB.

#### Fallback de conexión
`127.0.0.1:37685` se documenta únicamente como endpoint de fallback para
`adb connect` (puerto observado en la evidencia; puede cambiar) — NO como
serial hardcodeado del dispositivo:
- `"127.0.0.1:37685"` = endpoint de conexión/fallback (`adb connect`)
- `"$SERIAL"` = resultado dinámico que usan las operaciones ADB

#### Criterio de recuperación (evidencia mecánica en una misma ejecución)
`WATCHDOG_RECOVERY = VERIFIED` solo cuando:
- serial ADB válido detectado;
- servidor ausente observado mecánicamente;
- ejecución del starter observada;
- nuevo PID obtenido;
- nuevo PID distinto del OLD_PID;
- nuevo PID estable en las comprobaciones temporales N0/N1/N2/N3.

NO considerar suficiente: exit code 0 del starter, mensaje textual del
starter, una sola observación de PID, o la existencia del binario. La
estabilidad temporal del PID es parte de la evidencia.

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

## Distinción epistemológica: WATCHDOG_RECOVERY vs SHIZUKU_FUNCTIONAL_RECOVERY

- **WATCHDOG_RECOVERY:** se demostró que el servidor caído fue relanzado y que
  el nuevo proceso permaneció estable.
- **SHIZUKU_FUNCTIONAL_RECOVERY:** además de lo anterior, se ejecutó y verificó
  una operación funcional posterior mediante rish/Shizuku.

Evidencia previa (Watchdog Shizuku Recovery, 2026-09-12, commit `b3b73af`,
reporte `shizuku_watchdog_recovery_final_report.txt`):

```
WATCHDOG_RECOVERY = VERIFIED
SHIZUKU_FUNCTIONAL_RECOVERY = NOT_TESTED
```

Ninguna frase de esta skill implica que el watchdog demostró automáticamente
que rish quedó funcional tras la recuperación. "Starter ejecutado
correctamente" requiere evidencia del proceso (PID nuevo + estabilidad);
"Shizuku funcional después del recovery" requiere además una prueba
funcional post-recovery vía rish/Shizuku. No mezclar ambos niveles.

## Evidencia operacional — LADB local recovery

Verified on Xiaomi Mi 10 (umi), Android 13 (API 33) / HyperOS, no root:
LADB local adbd provides UID 2000 shell access on-device.
The Shizuku native starter at /data/local/tmp/shizuku can relaunch
shizuku_server without PC, root, app_process, or CLASSPATH manipulation.

Verified recovery:
  old PID 12057
  DOWN confirmed through process table
  starter launched through LADB
  new PID 7793
  N0=N1=N2=N3=7793
  rish -c "id" succeeded after recovery
  verify.sh exit 0 -> UP + FUNCTIONAL

Therefore:
  LADB_RECOVERY_MECHANICAL = VERIFIED
  SHIZUKU_FUNCTIONAL_RECOVERY = VERIFIED
  WATCHDOG = NOT_IMPLEMENTED

Operational invariants:
- LADB serial/port must be detected dynamically; never hardcode localhost:port.
- rish requires RISH_APPLICATION_ID and MANAGER_APPLICATION_ID.
- Use rish -c "command".
- rish exit 255 immediately after killing shizuku_server is expected;
  verify process state independently.
- adb shell UID 2000 cannot kill the Shizuku server directly because
  the server has a different UID; the forced-down test used rish.

Scope:
This is verified evidence for the tested Mi 10 / Android 13 environment,
not a universal Android compatibility claim.

Checkpoint:
PoC repository commit 3efedb79831382c7b2ff6b0a643ae5d284c84c07.
Later increments (all VERIFIED, see next sections): serial change (5ded4ee),
watchdog v0 (83ec34f), watchdog v1 daemonized (a1ff0c4), multi-event storm
(b9ca628), Termux force-stop (075ff50), reboot persistence
(af14a393efc3506f9cafd6cc4d0a83abed7e74e1). REBOOT_PERSISTENCE = VERIFIED
(boot-glue supervision scope); REBOOT_AUTONOMOUS_RECOVERY = NOT_TESTED.

### Evidencia operacional — serial change y watchdog v0 (2026-09-13)

SERIAL_CHANGE = VERIFIED:
- Normal LADB app restart (no re-pairing) changed the serial in value AND format:
  localhost:38639 (host:port) -> adb-..._adb-tls-connect._tcp. (mDNS/TLS).
- doctor/recover/verify ran unmodified and detected the new serial dynamically
  (doctor.sh printed it itself); verify.sh -> UP + FUNCTIONAL; rish functional.
- shizuku_server survived the LADB restart (PID unchanged): server lifetime is
  independent of the LADB app session.
- Scope: transport detection only (relaunch branch not exercised; server stayed UP).
- PoC repository commit 5ded4ee (ladb-shizuku-recovery).

WATCHDOG_V0 = VERIFIED (in-session):
- watchdog.sh: dynamic serial detection; conservative DOWN criterion
  (adb ps succeeds AND no shizuku_server row — transport-down is NOT server
  death); recovery delegated entirely to recover.sh (zero duplicated logic).
- Single forced DOWN event: rish -c "kill -9 385" -> detected within ~3s ->
  recover.sh -> new PID 2624, stable N0-N3, rish -> uid=2000(shell),
  16 consecutive UP cycles after. In-session run; watchdog stopped by exact PID.
- PoC repository commit 83ec34f (ladb-shizuku-recovery).

WATCHDOG_DAEMON/PERSISTENCE = NOT_PROVEN:
- A backgrounded watchdog dies when its Termux session tears down (observed).
- Daemonization (Termux:service / wake-lock), Termux:Boot, reboot recovery and
  multi-event failure storms are NOT tested. Next increment: watchdog
  daemonization (v1), not reboot.
  [2026-09-13, superseded in part: daemonization EXECUTED and VERIFIED as
  WATCHDOG_V1 (session-teardown scope); multi-event storm VERIFIED; force-stop
  VERIFIED — see next section. Reboot recovery was later registered (2026-09-15)
  at boot-glue supervision scope — see the reboot section;
  REBOOT_AUTONOMOUS_RECOVERY remains NOT_TESTED.]

Do NOT summarize this board as "WATCHDOG = VERIFIED": the precise state is
WATCHDOG_V0 = VERIFIED (in-session) plus WATCHDOG_V1 = VERIFIED (daemonized,
session-teardown scope).

### Evidencia operacional — watchdog v1, failure storm y force-stop (2026-09-13)

WATCHDOG_V1 = VERIFIED (daemonized, session-teardown scope):
- runit `runsv` supervision via termux-services (`service/shizuku-watchdog/run`
  + `install-service.sh`); watchdog alive across interactive session teardown
  (16+ min, ~15 sessions); `runsv` respawned the loop after a deliberate kill
  of its session; one autonomous forced-DOWN recovery over the dynamic
  transport; conservative skip while the transport was genuinely absent (no
  false recovery). `watchdog.sh detect_serial()` fixed to the full priority
  chain (v0 only saw tls-connect serials).
- PoC repository commit a1ff0c4 (ladb-shizuku-recovery).

MULTI_EVENT_STORM = VERIFIED (daemonized):
- Three sequential forced DOWN events under the live daemon (kill chain
  2442 -> 6444 -> 7671 -> 8679): strictly sequential detections (~3-6 s),
  exactly one delegated recover.sh per event, stable N0-N3 + functional
  rish each time; log deltas +3 DOWN / +3 OK / +0 FAILED (no false positives,
  no overlapping recoveries, no duplicate processes).
- PoC repository commit b9ca628 (ladb-shizuku-recovery).

TERMUX_FORCE_STOP = VERIFIED (app-level kill scope):
- `am force-stop com.termux` (performed OUTSIDE Termux, by the user) killed
  EVERY Termux-UID process: runsv tree, watchdog, adb server — none of the
  pre-state PIDs survived. `shizuku_server` (UID shell) SURVIVED with the
  SAME PID (8679). Serial changed localhost:43459 -> localhost:42125 as a
  CONSEQUENCE of the adb-server death (mdns re-discovery); scripts detected
  it dynamically, unmodified. verify.sh exit 0 (UP + FUNCTIONAL); rish
  functional; log continuity across the kill gap.
- Explicit distinction: the watchdog did NOT survive the force-stop as a
  process (cycle counter reset to 1 = new process). The service tree was
  AUTO-REVIVED by termux-services at the next Termux start. "Daemon survived
  force-stop" is NOT proven; "service auto-restored on Termux restart" IS
  proven. WATCHDOG_V1's daemonized scope remains session-teardown, NOT
  force-stop.
- PoC repository commit 075ff50 (ladb-shizuku-recovery).

REBOOT_PERSISTENCE (registered 2026-09-15; reboot executed 2026-09-14 22:36):
- Scope: boot-glue supervision only — see the reboot section below. Never infer
  autonomous post-reboot server recovery from session-teardown, force-stop, or
  boot-glue results (REBOOT_AUTONOMOUS_RECOVERY = NOT_TESTED).

Current token board (2026-09-15, post af14a39 — PoC frozen):

```
LADB_RECOVERY_MECHANICAL       = VERIFIED
SHIZUKU_FUNCTIONAL_RECOVERY    = VERIFIED
SERIAL_CHANGE                  = VERIFIED
WATCHDOG_V0                    = VERIFIED (in-session)
WATCHDOG_V1                    = VERIFIED (daemonized, session-teardown scope)
MULTI_EVENT_STORM              = VERIFIED (daemonized)
TERMUX_FORCE_STOP              = VERIFIED (app-level kill scope)
REBOOT_BOOT_SUPERVISION        = VERIFIED (boot-glue scope)
SHIZUKU_FUNCTIONAL_POST_REBOOT = VERIFIED
REBOOT_AUTONOMOUS_RECOVERY     = NOT_TESTED
REBOOT_PERSISTENCE             = VERIFIED (boot-glue supervision scope)
```

Do NOT summarize as a bare "WATCHDOG = VERIFIED": the precise scopes are
WATCHDOG_V0 (in-session) and WATCHDOG_V1 (daemonized, session-teardown
scope) only. Likewise never a bare "REBOOT = VERIFIED": the reboot is claimed
only as REBOOT_BOOT_SUPERVISION + REBOOT_PERSISTENCE at boot-glue supervision
scope, with REBOOT_AUTONOMOUS_RECOVERY = NOT_TESTED.

### Evidencia operacional — reboot persistence (reboot 2026-09-14 22:36, registered 2026-09-15)

Evidence: PoC repo `~/ladb-shizuku-recovery` (standalone), final commit
`af14a393efc3506f9cafd6cc4d0a83abed7e74e1` (`report_reboot_persistence.md/.txt`,
`reboot_boot_evidence.log`, preregistration + abort addendum). The reboot was
user-directed WITHOUT prerequisites: com.termux.boot was NOT installed and the
transport was ABSENT at reboot time.

Demonstrated evidence (full chain across the PoC series, each at the exact scope
recorded in the sections above):

1. LADB provides the ADB transport dynamically (on-device adbd, no PC).
2. The transport rotates serial/endpoint (host:port and mDNS/tls-connect) across
   LADB restarts, force-stop and reboot; the watchdog discovers it dynamically
   (never hardcode a serial).
3. Watchdog v1 runs as a daemonized service (runit `runsv` via termux-services).
4. The watchdog mechanically distinguishes "transport absent" (conservative skip,
   "transport down is NOT server DOWN") from "server Shizuku absent" (DOWN →
   delegated recover.sh).
5. Server recovery uses the existing native starter (`/data/local/tmp/shizuku`);
   multi-fall recovery is strictly sequential, exactly one delegated recovery per
   event.
6. Termux force-stop kills every Termux-UID process, but `shizuku_server`
   survives with the SAME PID (it runs in the shell UID context, not Termux's).
7. Post-reboot, the Termux:Boot boot glue (`~/.termux/boot/`, executed by
   Termux:Boot-plugin infrastructure — NOT the com.termux.boot app, which was
   never installed) started runsvdir + the watchdog unattended at device boot,
   before any interactive session.
8. With the transport initially absent post-reboot, the watchdog stayed
   conservative (27 consecutive skip cycles, zero false recoveries).
9. After the operator restored the transport manually via LADB
   (MANUAL_INTERVENTION, transport only), the watchdog correctly detected the
   already-running server (UP, zero recovery actions) and `verify.sh` confirmed
   UP + FUNCTIONAL with rish `uid=2000(shell)` →
   `SHIZUKU_FUNCTIONAL_POST_REBOOT = VERIFIED`.

Limits that MUST be preserved (verbatim policy):

- `REBOOT_AUTONOMOUS_RECOVERY = NOT_TESTED`: the server was already UP when the
  transport returned; the watchdog performed NO post-reboot server recovery.
- `Termux:Boot app-driven supervision (com.termux.boot) = NOT_TESTED`: the
  demonstrated variant is the boot glue in `~/.termux/boot/`, not the app.
- NEVER state: "the watchdog recovered Shizuku after the reboot";
  "shizuku_server survived the reboot as a process" (post-reboot PID was new);
  "Android restores the ADB transport automatically" (it was restored manually
  via LADB); "com.termux.boot ran the test".
- Accurate phrasing: "Shizuku was functional post-reboot without the watchdog
  having to perform a server recovery during this experiment; boot-time
  supervision of the watchdog itself was mechanically verified."
- Never summarize as a bare "REBOOT = VERIFIED" — the umbrella is
  `REBOOT_PERSISTENCE = VERIFIED (boot-glue supervision scope)` only.

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

# BUG — rish (Shizuku+) no conecta desde Termux · Mi 10 / HyperOS

> Fecha: 2026-08-08 · Estado: **RESUELTO — revert a Shizuku clásico (RikkaApps).
> El fork Shizuku+ no exprime el attach de sesión shell desde Termux en este
> dispositivo; la versión clásica conecta sin más.**
> · Siguiente paso: ver «Actualización 4 — RESOLUCIÓN».

## Actualización 4 — 2026-08-08 (noche) — RESOLUCIÓN: revert a clásico FUNCIONA

- Se instaló **Shizuku clásico v13.6.0.r1086.2650830c** (RikkaApps,
  release oficial del repo RikkaApps/Shizuku) sobre el fork Shizuku+
  (desinstalar primero el paquete `moe.shizuku.privileged.api`).
- Arrancado sin root: `adb shell am start -n moe.shizuku.privileged.api/
  moe.shizuku.manager.MainActivity` → diálogo ADB clásico → el servidor
  `shizuku_server` (app_process, NO `shizuku_plus_server`) sube solo
  (pid 3020, renace automáticamente).
- La app lo expresa: `cmd -l | grep shizuku` SÍ lista el servicio clásico
  (el daemon nativo `shizuku_plus_server` del fork no se listaba).
- **Kit clásico re-exportado por la app** a /sdcard/Rish/ (`rish` 882 B,
  `rish_shizuku.dex` 59672 B, md5 `2a5fb0c2705b3fe87aa567ffe6d471b7`,
  antes era la `42b30284...` del fork → los `~/bin/rish*` se actualizaron).
- **Clave: el script clásico exige `-c`** para el comando:
  ```
  export RISH_APPLICATION_ID=com.termux
  export MANAGER_APPLICATION_ID=moe.shizuku.privileged.api
  timeout 15 ~/bin/rish -c id   # → uid=2010(shell) OK
  ./rish -c "pm grant <pkg> android.permission.SYSTEM_ALERT_WINDOW"   # OK
  ./rish -c "settings get global adb_enabled"   # → 1 OK
  ./rish -c "appops get com.termux"   # → OK
  ```
  Sin `-c`, el servidor recibe `sh id` (trata "id" como path de script)
  y muere con `RISH: exited with 127` (logcat): NO es bug de permisos.
- **Conclusión definitiva**: el bug era exclusivo del fork Shizuku+ en este
  dispositivo (attach de sesión shell rechazado). El clásico funciona con el
  mismo kit, UID 2000 (shell). Reportado al proyecto como duplicado de
  issue #387 `(maneskinleon-del` comentario en theiaustin/ShizukuPlus/issues/387).
- Nota: MIUI deja `adb wireless` y los dos `adb devices` (127.0.0.1:5555 +
  emulator-5554) intactos; `adb -s` sigue necesario.
- Acción pendiente del usuario: (a) re-autorizar/verificar las apps
  autorizadas dentro de la app clásica (la lista reinicia tras reinstalar);
  (b) opcional: reinstalar el fork si se quiere el watchdog de nuevo.

## Actualización 3 — 2026-08-08 (noche) — CONCLUSIÓN: bug del fork, volver a clásico

- Tras agotar hipótesis (lista autorizadas ✓, kit re-exportado ✓, servidor
  reiniciado 3x ✓, md5 APK==loader ✓, dialog+Allow funciona, batería ✓) el error
  `Caller (uid 10364) is not an attached client` persiste SIEMPRE desde Termux.
- **Causa raíz identificada por análisis del módulo AutoJS `RishShizukuManager.js`**
  (en /sdcard/Download, reutilizado del proyecto AutoJS6): AutoJS funcionaba
  porque `org.autojs.autojs6` **declara en su manifest el permiso
  `moe.shizuku.manager.permission.API_V23`** y el provider Shizuku, y usa
  `RISH_APPLICATION_ID=<su propio package>` con attach vía provider. Termux NO
  declara ese permiso (pm grant → «has not requested permission») y el server
  del fork rechaza la sesión shell genérica de Termux (`not an attached client`).
- **Decisión del usuario**: el fork se ve mejor y tiene watchdog/reconexión,
  pero no exprime los recursos para shizuku desde Termux en este dispositivo.
  → **Revertir a la versión oficial clásica** (RikkaApps/Shizuku) que sí
  conectaba, y reportar la limitante en issues del proyecto.
- Workaround temporal mientras no se resuelva: ejecutar comandos privilegiados
  desde **AutoJS6** con el módulo RishShizukuManager (conecta, quedaba).

## Actualización 2 — 2026-08-08 (tarde) — app Shizuku+ instalada; consent OK; attach KO

### LO QUE ARREGLÓ EL USUARIO (verificado en esta sesión)

- La app instalada YA NO es Shizuku clásico: `moe.shizuku.privileged.api` reporta
  `versionName=Shizuku+ 13.6.0.r2220` (correcta para el loader Plus).
- Verificación de "mismatch loader/server" (hipótesis 3): **descartada**.
  El APK instalado se extrajo y su `assets/rish*` + `assets/rish_shizuku.dex`
  son md5-iguales a `~/bin/rish` y `~/bin/rish_shizuku.dex` (42b30284..., efca5302).

### Flujo reproducido (reintento tras reiniciar el servidor tres 8232 → 2667/luego)

1. `~/bin/rish id`, `sh /sdcard/Rish/{+plus,su,rish}` → todas llegan a
   "Waiting for Shizuku authorization... check your notifications."
2. En el teléfono SE GENERA la notificación **"Shell access request"**
   (channel `shell_consent`, id random) — ANTES no aparera.
3. Al abrir la notificación se presenta **ShellConsentActivity**
   (`af.shizuku.manager.legacy.ShellConsentActivity`) con botón **Allow**.
   Tocar Allow (vía `adb input tap`) cierra el diálogo y...
4. El proceso `shizuku_plus_server` (daemon nativo del fork, corre como shell uid)
   crea el proceso de sesión y lo rechaza:

```
W/ShizukuPlus:UserServiceRecord(26675): Caller (uid 10364, pid 26760) is not an attached client
W/ShizukuApplication(26760): java.lang.IllegalStateException: Not an attached client
   at af.shizuku.manager.shell.Shell.main(...)  ← dentro del server del fork
```

→ Mismo patrón de rechazo que el `SecurityException: newProcess ... is not an
attached client` de la semana pasada, pero AHORA dentro del servidor correcto
(ejecutado por el exe nativo `shizuku_plus_server`, binario del fork).
El consentimiento de la *sesión* no basta: el servidor exige que el cliente
demo la shell esté en su lista de **attached clients** (clientes unidos de la
sesión *activa* de la app instalada) — ver hipótesis B abajo.

### Estado paralelo (no cambiar)

- Servidor: proceso nativo `shizuku_plus_server` (no es el `app_process`
  clásico); se reinicia solo al morir (kill 8232 → renació 2667). No lo matar
  más seguido sin necesidad.
- `cmd -l | grep shizuku` → sin salida (el daemon nativo no es un service listado).
- AdB sigue `127.0.0.1:5555` (Mi 10, serial d2c6cbda); `emulator-5554` duplicado vivo.

### Tras pruebas ADB de 18:15–18:35 (re)-test con el kit re-exportado hoy 17:10

- **Hipótesis A (lista de apps autorizadas) — DESCARTADA**: en la app,
  «Gestión de aplicaciones» (ApplicationManagementActivity) → buscar Termux:
  el switch de `com.termux` está **check=true** (autorizado). Lista total: 11.
  Se verificó además vía dump que la app gestiona la lista con switches nativos.
- **El kit /sdcard/Rish fue re-exportado HOY 17:10** (rish, rish_shizuku.dex,
  `su`, `plus` renovados). `cd `~/bin` NO fue actualizado (fechas 05-ago).
- Los scripts nuevos documentan el fix del usuario:
  - `su`: NO hardcodear `RISH_APPLICATION_ID` (el server del fork rechaza
    paquete que no pertenezca al UID llamante); parsea `su -c "cmd"`,
    `su root -c ...`, `su --mount-master -c ...` (estilo Magisk).
  - `rish` (v13): pide `RISH_APPLICATION_ID` explícito si no se exporta
    («RISH_APPLICATION_ID is not set» → exit 1) — el fix del `su` es dejarlo
    que derive del proceso cuando viene de un CALLER root-real; desde
    Termux hay que exportarlo SIEMPRE (com.termux).
- **Tests finales (tras el fix)**: `su -c "id"` con y sin env, `plus su id`,
  `rish id` con/sin env → TODOS caen en «Waiting for Shizuku authorization...»
  (exit 124). El diálogo ShellConsent SÍ sale y Allow se toca → el daemon
  nativo crea el proceso shell y lo rechaza de nuevo:
  `Caller (uid :1036x) is not an attached client` en UserServiceRecord del
  fork (pid del server nuevo según pidof). El fix del kit NO resuelve el
  attach: el error es idéntico al del doc previo.

### Hipótesis vivas tras la actualización

- **A (lista de apps) — cerrada, verificado arriba (Termux authorized).**
- **B. Attach de sesión dentro del daemon del fork**: con la app TODO
  correcto (Shizuku+ 13.6.0 + kit de su APK propio + Termux autorizado),
  el error reside en la sesión "attached client" del `shizuku_plus_server`.
  Causas candidatas no descartadas: 1) servidor iniciado por un tracer
  viejo de proceso anterior pendiente de reintegrarse en la sesión del
  server nuevo (el server se inicio vía sistema con PARTE_ENTERA del
  anterior); 2) eldiálogo ShellConsent expira (timeout ~2') y el pack
  Allow puede llegar tarde tras varios reintentos; 3) Limpieza: matar daemon
  (kill del pid actual) → en el mismo momento abrir la app (Start manual)
  y en <10 s lanzar `rish id` y tocvar Allow cuando salga (sin esperas).
- ~~Batería / deviceidle / AppOps~~ — resuelto (verificado; mensaje de batería
  ya no se emite).

## Síntoma

Cualquier invocación de `rish` desde Termux queda colgada con:

```
Waiting for Shizuku authorization... check your notifications.
```

y termina por timeout (`exit=124`, sin ejecutar el comando). Ocurre con
`~/bin/rish`, `sh /sdcard/Rish/rish` y `sh /sdcard/Rish/plus`, con o sin
`RISH_APPLICATION_ID=com.termux`, con `-c "cmd"` y sin `-c` (patrón de la skill:
`rish pm grant ...` directo).

## Evidencia clave (rice_ok.txt del 07-ago)

Cuando el timeout llega a su límite, Shizuku imprime:

```
Request timeout. The connection between the current app (com.termux) and Shizuku
app may be blocked by your system. Please disable all battery optimization
features for both current app (com.termux) and Shizuku app.
```

→ Indicación fuerte de bloqueo de conexión binder app↔app por **optimización de
batería de HyperOS/MIUI** (no es problema de permisos de app).

---

## Actualización 2026-08-08 — batería RESUELTA por ADB; queda autorización interactiva

### Blindaje de batería aplicado y verificado (vía ADB shell, serial `d2c6cbda`)

1. **Whitelist deviceidle** — los 3 paquetes ya estaban; se re-aplicó con
   `adb shell dumpsys deviceidle whitelist +<pkg>` → `Added:` OK en
   `moe.shizuku.privileged.api` (uid 10396), `com.termux` (10364) y `com.termux.api`.
2. **AppOps** — `allow` en Shizuku y Termux: `RUN_IN_BACKGROUND`,
   `RUN_ANY_IN_BACKGROUND`, `START_FOREGROUND`, `WAKE_LOCK`
   (vía `adb shell appops set`, sin errores; verificado post-cambio con `appops get`).
3. Conclusión: el requisito del mensaje de timeout («disable all battery
   optimization features for both com.termux and Shizuku») quedó **cubierto por
   completo** — Termux ya NO es el problema.

### Re-test de `rish id` (timeout 22s) — sigue colgado, pero cambió el mensaje

```
Waiting for Shizuku authorization... check your notifications.
Terminated
exit=124
```

→ Ya **no** aparece «Request timeout... blocked by your system» (el de batería).
El loader llega a la fase de **autorización interactiva**: Shizuku debe aprobar la
sesión shell de Termux (notificación/diálogo en el teléfono). Esa aprobación queda
pendiente de acción manual del usuario.

### Nota ADB — dos dispositivos registrados

`adb devices` lista `127.0.0.1:5555` (Mi 10 real, serial `d2c6cbda`) y
`emulator-5554` (duplicado/spoof de umi). Cualquier comando ADB debe usar
`adb -s 127.0.0.1:5555` o falla con «more than one device».

---

## Qué se verificó (NO es esto)

- Termux **sí está en la lista de apps autorizadas** de Shizuku (captura 17:05,
  pantalla «Gestión de aplicaciones»)
- El servidor de Shizuku **sí responde** (el loader llega al bind del servidor;
  `plus su id` devuelve `SecurityException: newProcess ... is not an attached
  client` → el servidor rechaza la *adjunción* de la sesión shell)
- `cmd -l` / `service list` no muestran el servicio → proceso servidor no
  visible desde la shell de Termux (restricción), no se infiere que esté caído
- DEX: `~/bin/rish_shizuku.dex` == `/sdcard/Rish/rish_shizuku.dex`
  (md5 42b30284...) — Los loader es del fork **Shizuku+**
  (strings: `af.shizuku.manager.shell.PlusShell`, `af.shizuku.manager.shell.Shell`)
  aunque la app instalada es `moe.shizuku.privileged.api` (Shizuku clásico).
- Invocación sin `-c` (según skill `xiaomi-adb-tricks`: `rish pm grant ...`): misma espera
- ocr de capturas: pantalla de batería de Shizuku en "No optimizar" ✓
- ~~`cmd appops set ... RUN_IN_BACKGROUND` (Termux y Shizuku): `Exception ...'set'`~~
  (bloqueado, sin shell — círculo vicioso) → **RESUELTO 08-08**: aplicado por ADB
  shell directo (`appops set` funciona desde `adb shell`), verificado `allow`.

## Hipótesis pendientes

1. ~~**Ajuste de batería/fondo de HyperOS para `com.termux`**~~ — **RESUELTA
   (08-08)**: whitelist deviceidle + AppOps `RUN_*/START_FOREGROUND/WAKE_LOCK`
   aplicados por ADB a Termux, Termux API y Shizuku; verificado. Ya no se emite
   el mensaje de bloqueo por batería.
2. **Autorización interactiva pendiente** — el «Waiting for Shizuku
   authorization...» actual es la espera de aprobación de la sesión shell en el
   teléfono (notificación de Shizuku). Revisar notificaciones y tocar
   Permitir/Allow, o reiniciar el servidor (Stop→Start) para re-aplicar la lista
   de autorizadas en memoria.
3. **Mismatch loader Shizuku+ vs server clásico** (menos probable) — si tras
   aprobar/reiniciar sigue, probar con el loader oficial clásico exportado desde
   la app (opción "Usar Shizuku en apps de terminales" → Exportar),
   sobrescribiendo `~/bin/rish*` y/o `/sdcard/Rish/rish*`.

## Estado de los archivos

- `~/bin/rish` + `~/bin/rish_shizuku.dex` (dex 444, OK Android 14)
- `/sdcard/Rish/` = `rish` + `rish_shizuku.dex` + `plus` + `su` (Shizuku+ kit;
  ejecución directa falla "Permission denied" (FUSE no ejecutable) → invocar con `sh`)
- rish_ok.txt análogo del 7-ago incluye el mensaje de timeout completo.

## Cómo reanudar (RESUELTO — modo de uso actual)

1. Verificar servidor: `adb -s 127.0.0.1:5555 shell cmd -l | grep -i shizuku` →
   debe listar el servicio clásico (o `ps -A | grep shizuku_server`).
2. Usar SIEMPRE `-c` con el kit clásico:
   `export RISH_APPLICATION_ID=com.termux; export MANAGER_APPLICATION_ID=moe.shizuku.privileged.api; ~/bin/rish -c "id"`
3. Si cuelga en «Waiting…»: aprobar sesión en el teléfono (notificación
   Shell access request) o `Stop→Start` del servidor en la app.
4. Sin `-c` sale `exited with 127` en logcat (patrón `sh id` sin `-c`) —
   no reintentar sin `-c`.
5. Recordar `adb -s 127.0.0.1:5555` para todo ADB (hay un `emulator-5554`
   duplicado registrado que rompe los comandos sin `-s`).
# Skill — android-package-origin-audit

Metodología y herramienta reutilizable para **auditar la procedencia de paquetes
Android** (preinstalados vs usuario vs restaurado vs desconocido) y, como fase 2,
clasificarlos por **función / riesgo / impacto** — **sin tocar el sistema**.

> Esta skill es genérica: no contiene paquetes, fechas, modelos ni resultados
> específicos de ningún dispositivo. Todo dato concreto pertenece a la
> auditoría que la invoca; esta skill solo describe *cómo* obtenerlo y *cómo*
> razonarlo.

---

## 1. Objetivo

Determinar, para cada paquete instalado en un dispositivo Android, **su
procedencia real** basada en evidencia (no en nombres ni fabricantes), y luego
**su función, criticidad, riesgo de eliminación e impacto energético**, de modo
que una persona pueda revisar y decidir — nunca de forma automática — qué
candidatos a desinstalación son seguros y reversibles.

## 2. Alcance

- Incluye **todo paquete instalado para el usuario 0** (`pm list packages -3`
  = FLAG_SYSTEM unset ∪ `pm list packages -s` = FLAG_SYSTEM, ambos vistos).
- No distingue por fabricante, ROM ni modelo.
- No ejecuta eliminaciones. La salida es una tabla + un reporte; la acción, si
  la hay, se realiza fuera de la auditoría.

## 3. Principio de evidencia

> Ninguna clasificación se basa en el nombre del paquete, el fabricante ni la
> ubicación "aparente". Cada conclusión se sustenta en **evidencia observable**
> del sistema.

## 4. Evidencias que deben recolectarse

| fuente | artefacto | comando base |
|---|---|---|
| PackageManager (full dump) | `pkg_dumpsys_full.txt` | `dumpsys package packages` |
| paquetes instalados (lista) | `pkgs_plain.txt` (canónico, instalados AHORA); `pkgs_sys.txt`, `pkgs_third.txt`, `pkgs_u_f.txt` | `pm list packages` / `[-s\|-3\|-u]` |
| path + installer por paquete | `pkgs_all_fi.txt` | `pm list packages -f -i` |
| UID por paquete | `pkgs_uids.txt` | `dumpsys package packages` → `appId=NNNN` (`package:pkg uid:N`) |
| resolvers (componentes) | dentro del dump | `dumpsys package` (Activity/Service/Receiver/Provider Resolvers) |
| servicios activos | `dumpsys_services.txt` | `dumpsys activity services` |
| jobs | `dumpsys_jobs.txt` | `dumpsys jobscheduler` |
| alarmas exactas | `dumpsys_alarm.txt` | `dumpsys alarm` |
| consumo energético UID | `power_use.txt` | `dumpsys batterystats` (formato legible, **no** `--checkin`; líneas `    UID <id>: <mah> … bg: … fgs: …`) |
| procesos activos | `ps_all.txt` | `ps -A` / `ps -ef` |
| whitelist doze | `doze_whitelist.txt` | `dumpsys deviceidle whitelist` |
| receivers de arranque | `boot_receivers_raw.txt` | `cmd package query-receivers -a android.intent.action.BOOT_COMPLETED` |
| actividades launcher | `launcher_acts.txt` | `cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.LAUNCHER` |
| políticas dev/admin | `dumpsys_devpolicy.txt` | `dumpsys device_policy` |
| defaults del sistema | `defaults.txt` | 5 líneas posicionales (IME listener asistente): `settings get secure default_input_method` / `enabled_notification_listeners` / `voice_interaction_service` |
| marca de tiempo de boot | `boot_epoch.txt` | `grep btime /proc/stat` → epoch unix del arranque (float) |
| backup (corroboración) | `dumpsys_backup.txt` | `dumpsys backup` — recolectado, NO consumido por parsers (ver §5.11) |
| props de OTA (corroboración) | `ota_props.txt` | `getprop` — recolectado, NO consumido por parsers (ver §5.12) |

## 5. Cómo determinar cada señal

### 5.1 partición / codePath
- `/system`, `/system_ext`, `/product`, `/vendor`, `/odm`, `/apex` => **imagen/preinstalled**.
- `/data` => instalado para el usuario (pero NO confirma que sea USER: puede ser
  updated-system-app con copia en `/system`, o RESTORED).
- Se toma `codePath` del `Package [name] (hash):` del dump principal.

### 5.2 flags SYSTEM (`flags`)
- `SYSTEM` (0x1) => en ROM. `UPDATED_SYSTEM_APP` (0x80) => system app actualizada.
- Ambas son **evidencia de preinstalación**, no de "usabilidad".

### 5.3 presencia en imagen ("Hidden system packages")
- El dump muestra `Hidden system packages:` para paquetes cuya copia APK vive en
  la partición de solo lectura. Si un paquete aparece allí => **preinstalado**,
  incluso si `firstInstallTime` es reciente (actualización vía Play).

### 5.4 isMiuiPreinstall (y equivalentes)
- Algunas ROMs marcan `isMiuiPreinstall=true`. Se trata como señal de
  preinstalación, pero **nunca como única prueba**.

### 5.5 installerPackageName
- `com.android.vending` => Play Store. `com.android.packageinstaller` =>
  sideload. `null` => sin installer (sistema / OTA).

### 5.6 initiatingPackageName / originatingPackageName
- Quien originó la instalación (p. ej. `com.android.vending` si Play la descargó).

### 5.7 installReason (0..4)
- 4 = USER, 3 = DEVICE_SETUP, 2 = DEVICE_RESTORE, 1 = POLICY, 0 = UNKNOWN.
- **2/3 es fuerte indicio de RESTORED/MIGRATED.**

### 5.8 packageSource (0..4)
- 1 = STORE, 2 = LOCAL_FILE, 3 = DOWNLOADED_FILE, 0 = UNSPECIFIED.
- STORE/DOWNLOADED + `data` => USER.

### 5.9 firstInstallTime / lastUpdateTime
- `1970-01-02` (época) => registro de aprovisionamiento/OTA.
- Coincidir con el boot epoch (`boot_epoch.txt`): si `firstInstallTime >=
  boot_epoch - margen` => instalación en este arranque (sugiere OTA).

### 5.10 estado instalado / desinstalado
- `pm list packages` enumera instalados. `pm list packages -u` incluye desinstalados.
- `User 0: installed=true/false` dentro del dump distingue instalado por el usuario 0.

### 5.11 evidencia de restore (corroboración, no consumida)
- Se recolecta `dumpsys_backup.txt` (`Start restore at install` / `Start package restore`),
  cruzado con `installReason=DEVICE_RESTORE(2)` y la ventana horaria de provisioning.
- ⚠️ **NINGÚN parser abre `dumpsys_backup.txt`.** El restore se atribuye hoy únicamente
  por `installReason=DEVICE_RESTORE/SETUP(2/3)`. El dump de backup es evidencia de
  corroboración para revisión humana futura (ver Apéndice C).

### 5.12 evidencia de OTA (corroboración, no consumida línea a línea)
- Propiedades de `ota_props.txt`: `ro.boot.bootreason=reboot,ota`, `sys.ota.type=update_engine`,
  `persist.sys.qcom.memcpy.otastatus=ota_complete`, y el historial de `boot_reason.history`.
- ⚠️ **NINGÚN parser abre `ota_props.txt`.** Un `firstInstallTime` ≈ boot del OTA confirma
  recreación de registros de imagen por OTA. La OTA se detecta hoy vía `boot_epoch.txt`
  (`grep btime /proc/stat`) + `firstInstallTime` (ver §5.9). `ota_props.txt` es evidencia
  de corroboración para revisión humana futura (ver Apéndice C).

## 6. Jerarquía de evidencia (prioridad de decisión)

1. **Evidencia directa > inferida > nominal.**
2. `installReason=USER(4)` + `packageSource=STORE/DOWNLOADED` + `data` => USER.
3. `installReason=DEVICE_RESTORE/SETUP(2/3)` + `data` => RESTORED.
4. Copia en imagen (`Hidden system packages`) o flag `SYSTEM`/`UPDATED_SYSTEM_APP`
   o `isMiuiPreinstall=true` o `firstInstallTime` en boot de OTA => PREINSTALLED.
5. Si la evidencia es contradictoria (p. ej. `data` + `SYSTEM` + play installer) =>
   **PREINSTALLED actualizado** (se trata como preinstalado; el hecho de estar en
   `/data` es una actualización de la copia de sistema, no una app de usuario).
6. Sí insuficiente o contradictoria => **UNKNOWN** (no se etiqueta, no se recomienda).

## 7. Clasificación de procedencia

| macro-grupo | criterio de evidencia |
|---|---|
| **FACTORY/ROM** | flag `SYSTEM` + copia en imagen + `firstInstallTime=1970` + `isMiuiPreinstall` |
| **OTA** | `firstInstallTime`/`lastUpdateTime` ≈ boot del OTA + copia en imagen (p. ej., apps que la OTA recrea) |
| **USER** | `data`, sin `SYSTEM`, `installReason=USER` o `packageSource=STORE/DOWNLOADED` |
| **RESTORED/MIGRATED** | `data`, sin `SYSTEM`, `installReason=DEVICE_RESTORE/SETUP` (backup Google) |
| **CARRIER** | apps de operador preinstaladas en `/system`/`/product` con package name de operador (o carrier‑specific overlay); requiere evidencia adicional de preinstalación por operador |
| **UNKNOWN** | insuficiente evidencia para atribuir con seguridad |

## 8. Reglas explícitas

1. **`pm list packages -3` NO significa automáticamente USER.** Puede ser
   PREINSTALLED_actualizado o RESTORED. Se requiere `partition=data` + `SYSTEM`
   ausente + `installReason=/packageSource` concluyente.
2. **`/data/app` por sí solo NO demuestra que sea USER.** Muchas apps
   preinstaladas se actualizan en `/data` sobre una copia de `/system`; también
   apps RESTORED viven en `/data`.
3. **Si la evidencia no permite distinguir dos orígenes, clasificar UNKNOWN.**
4. **UNKNOWN queda fuera de cualquier recomendación de eliminación.**
5. **Ninguna procedencia implica eliminación automática.**

## 9. Diferencias conceptuales (no confundir)

- **procedencia (origen):** quién/instalación originó el paquete (FACTORY/ROM,
  OTA, USER, RESTORED, CARRIER, UNKNOWN).
- **función:** qué hace el paquete (documentación AOSP/MIUI/Google; "no documentada").
- **criticidad:** si el sistema depende de él para arrancar/funcionar
  (framework, SystemUI, proveedores de Settings/Telephony/Media, HAL…).
- **impacto (energía):** consumo atribuido al UID (`dumpsys batterystats` → mAh)
  menos componentes activos (servicios en ejecución, jobs, alarmas exactas).
- **seguridad de eliminación:** riesgo de que su borrado rompa algo
  (candidato `NO - crítico` vs `SI - bajo riesgo (reversible)`). No idéntico a
  "no esencial": una app opcional inerte puede ser segura, pero una app
  "no documentada" no (faltan datos).

## 10. Segunda fase: análisis funcional de preinstalados

Aplicable **solo** a los PREINSTALLED (y no a USER/RESTORED/UNKNOWN).

| categoría | significado | riesgo de borrado |
|---|---|---|
| 1 | Framework crítico (uid 1000, `android`, `apex`, flag `PERSISTENT`, SystemUI/Settings/Phone/Telecom, proveedores Settings/Telephony/Media, GMS, instaladores, Bluetooth/NFC/SE, key/cert/credential/storage, lanzador) | NO (crítico) |
| 2 | Necesario del sistema: `<providers>`, HAL/vendor del stack (Qualcomm/QTI/WFD/UIM/Timeservice), overlays RRO, `sharedUser` system, `SYS_NECESSARY` curado | NO |
| 3 | App opcional preinstalada de MIUI (galería, reproductor, clima, notas…) | CONDICIONAL |
| 4 | App opcional de Google (YouTube/Maps/Drive/Fotos…) | CONDICIONAL |
| 5 | Telemetria/datos (analíticas, `mainline.telemetry`, AS/Compute, BSP/Western-Digital/Qualcomm diag) | CONDICIONAL |
| 6 | Servicio OEM prescindible (joyose/daemon, touchassistant, lector QR, screenshots, DTI/AOne, CIT, AT) | CONDICIONAL |
| 7 | App visible en el cajón (`LAUNCHER`); tenga o no candidato, respetar si es lanzador/IME/listener/assistant activos | NO |
| 8 | **Candidato bajo riesgo (inerte)**: de Cats 3-6 y **inerciales** (ver §10.5) | SI (reversible) |
| 9 | Función no documentada / insuficiente evidencia | NO (revisar) |

### 10.1 Definición de "inercia" (criterio para Cat 8)
Un paquete califica como bajo riesgo solo si **todos** los siguientes se cumplen:
- No es dependencia externa: `queriesPackages` referenciándolo == 0. (Los `<providers>` declarados
  **por el paquete mismo** —p. ej. para preferencias— **no** cuentan; ver §10.2.)
- No declara `<receiver>` de `BOOT_COMPLETED` (`boot_receivers`).
- No aparece en `ps -A` (no corre proceso).
- 0 servicios activos resueltos (`dumpsys activity services`).
- 0 jobs programados (`dumpsys jobscheduler`).
- 0 alarmas atribuidas (`dumpsys alarm`).
- No está en la whitelist de doze (`dumpsys deviceidle whitelist`).
- No tiene flags `PERSISTENT`, no es `APEX`, no es `PRIVILEGED` en `/system`.
- No es admin/IME/listener/assistant/lanzador ni app de pago/seguridad/eID
  (estos se excluyen explícitamente incluso si son inerciales).

### 10.2 Nota sobre proveedores propios
Una app opcional puede declarar su propio `ContentProvider` (p. ej. para
preferencias); eso **no** la hace insegura de quitar. Lo decisive es si **otro**
paquete la referencia (`queriesPackages`) o si es parte del stack del sistema.

### 10.3 Telemetria/servicios activos
Si un paquete de telemetría/servicio OEM **no** es inerte, no pasa a Cat 8; se
mantiene como Cat 5/6 (CONDICIONAL) y la recomendación es **deshabilitar, no
desinstalar**, tras observar el comportamiento.

### 10.4 Shortlist de bajo riesgo
Conjunto de Cat 8 → eliminación reversible con `pm uninstall --user 0` +
`pm install-existing --user 0` para revertir.

## 11. Regla de no-eliminación automática

- La auditoría **no desinstala**.
- Procedimiento: `observación → evidencia → clasificación → matriz → revisión
  humana → acción`.
- Única forma soportada: `pm uninstall --user 0` (no `--system`, no `rm -rf`).
- UNKNOWN y Cats 1/2/9 quedan fuera de la shortlist. Cat 9 implica revisión
  manual obligatoria.
- Para overlays RRO (Cat 2): `cmd overlay disable` (no desinstalar).

## 12. Reproducibilidad

1. Recolectar evidencia fresca (§4).
2. `python3 parse_full.py` → `pkg_origin.tsv`.
3. `python3 matriz_preinstalados.py` → `matriz_preinstalados.tsv` + resumen.
4. `python3 generar_reporte_matriz.py` → `reporte_matriz_preinstalados.md`.
5. Verificar: filas de la matriz == preinstalados; ningún candidato en UNKNOWN;
   regrabar tras cualquier OTA antes de actuar.

## 13. Formato de artefactos de salida

- `pkg_origin.tsv`: procedencia + evidencia (una fila por paquete).
- `matriz_preinstalados.tsv`: `pkg, categoria, candidato, funcion, partition,
  img_copy, uid, sharedUser, privileged, persistent, apex, activities,
  receivers, services, providers, authorities, launcher, boot_receiver,
  referenced_by, running, services_running, jobs, alarms, doze, power_mah,
  power_fgs, power_bg, impacto, inert, perms_clave, version`.
- `reporte_matriz_preinstalados.md`: informe legible por humanos.
- `reporte_origen.md`: (opcional) detalle de procedencia por paquete.

## Apéndice C — Evidencias de corroboración recolectadas, no implementadas (futuro)

Mantener este listado evita afirmar un rigor que no se consume hoy. Cada artefacto
se recolecta en `collect.sh` pero **ningún parser actual lo abre**; si se añade un
paso de clasificación que los consinja, pueden pasar a productivos.

- **§5.11 `dumpsys_backup.txt`** (`dumpsys backup`): recolectado para observar
  `Start restore at install`/`Start package restore`. El restore se detecta hoy vía
  `installReason=DEVICE_RESTORE/SETUP(2/3)`; el dump es evidencia de corroboración.
- **§5.12 `ota_props.txt`** (`getprop`): recolectado para observar
  `ro.boot.bootreason=reboot,ota` / `sys.ota.type` / `…otastatus`. La OTA se detecta
  hoy vía `boot_epoch.txt` (`grep btime /proc/stat`) + `firstInstallTime` (§5.9).
- **§5.6 `initiatingPackageName`/`originatingPackageName`**: capturado dentro de
  `pkg_dumpsys_full.txt`. `parse_full.py` lo registra como evidencia, pero
  `classify()` no lo pondera (usa `installerPackageName`). No afecta la clasificación actual.

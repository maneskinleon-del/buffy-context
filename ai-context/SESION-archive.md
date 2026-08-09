# 🧠 SESION — Buffy Freebuff (2026-08-03 — PC: digest leído + router con manifests + migración + B1 + C2)

> Tema: retomada desde el PC (Mi 10 por USB). Se leyó el digest `BUFFY-PC-CONTEXT.md` dejado desde el teléfono, se sincronizó el repo y se saldaron **todos los pendientes del digest**: router con manifests, migración SYSTEM→INFO-core, versiones mínimas scrcpy/Ollama, README al día, fix H2, schema-lite B1 y BUFFY_HOME (C2). CI verde en cada commit. Por la tarde, con el ZTE Nubia como laboratorio: ManUninstaller revisado con skills, instalado y funcionando (Shizuku ACTIVE · 329 apps), purga de 22 apps de usuario + 25 bloat de fábrica deshabilitados.

---

## 🧭 Router con manifests (pendiente §7.2 — HECHO)

- **`scripts/lib/yaml.sh`** (NUEVO): funciones compartidas `yaml_val`/`yaml_items`/`yaml_list` (movidas de skill-lint, cero duplicación).
- **`scripts/buffy-router.sh`**: ya NO hardcodea rutas de skills — `add_skill` registra si el manifest existe, `discover_skills` barre los skill.yaml y carga por **triggers** (≥1 match). Una skill nueva con manifest se activa sin editar el router. `skill_safe` marca ⚡ AUTO_SAFE.
- **Fix bonus**: mensaje vacío (ni args ni stdin) → exit 1.
- **`test-router.sh`** (NUEVO, 15 tests). Verificado en vivo: "componente react con vite" descubre vercel-react-best-practices + vite sin estar hardcodeadas.
- Commit `0c4d92a` · suite 75→90 quick / 91→106 full.

## 🔴 Migración SYSTEM.md → deprecated/ (pendiente §7.6a — HECHA)

- **`scripts/migrate-system.sh`** EJECUTADO (decisión del usuario): stubs `SYSTEM.md`/`SYSTEM_FULL.md` (contenido ya fusionado en INFO-core/full) movidos a `ai-context/deprecated/` con timestamp.
- **Correcciones manuales post-sed**: el sed global reemplazó `SYSTEM.md`→`AGENTS.md` ciegamente — corregido a mano en AGENTS.md, README, LOAD_CONTEXT (árboles), CHANGELOG, CONTINUE; bitácoras históricas (SESION.md, SESION-archive.md) **revertidas**.
- Doctor: los 2 warnings `DEPRECATED_FILE` desaparecieron (3→1). Commit `69e1be9`.

## 📌 Versiones mínimas scrcpy/Ollama (pendiente §7.6b — HECHA, con fuente)

- **scrcpy**: mínimo recomendado **≥ 3.3.1** (UHID ≥ 2.0; `--power-off-on-close` con fix en 3.3.1 #6146) — `Knowledge/Android/scrcpy.md`, verificado `4.1-1` + `adb 1.0.41`.
- **Ollama**: mínimo **≥ 0.30** — `Knowledge/Vision.md`, verificado binario `0.30.7` (sirviendo en :11434), paquete `0.32.1-1`, upstream v0.32.5. Notas: servicio de sistema activo (el de usuario deshabilitado), bug `ollama run` timeout → API, tags `:cloud` sin RAM local.
- Regla del digest respetada: versiones documentadas solo con fuente (release notes oficiales). Commit `49c18e1`.

## 🟢 README actualizado al día con el disco (pendiente §7.3 — HECHO)

- Árbol de skills: 10 → **23** agrupadas por dominio (Android 8, Web 2, Framework v4 5, Code & research 2, Frontend 4, Operación 2).
- Knowledge: agregadas categoría `AI/` (Kimi-K3.md) y `Vision.md`; scripts: 7 → 16 entradas; tabla "What's included" y de categorías actualizadas.
- Doctor sin drift falso (las 23 skills del README coinciden con disco). Commit `ec7b14a`.

## ✅ Fix H2 (revisión externa) — android-agent/SKILL.md alineado con el repo

- El análisis de otra IA tenía 7 hallazgos: **5 falsos positivos** (verificados contra disco: INFO-core/CONTINUE existen, 23/23 skill.yaml, índice Knowledge coincide, 23 skills exactas, python3/readlink presentes), **1 no-issue por diseño** (scripts sin `+x` — se ejecutan con `bash` explícito por Termux), **1 real** (H2): android-agent/SKILL.md referenciaba 3 skills del entorno (`android-native-dev`, `android-clean-architecture`, `mobile-android-design`) que NO vienen con el repo.
- **Fix**: reemplazadas por skills del repo (`android-project-setup`, `hyperos-hardening`, `xiaomi-adb-tricks`) + descripción del front-matter alineada. Commit `1166173`.

## 🟠 Schema-lite B1 (pendiente §7.4 — HECHO, modo autónomo)

- **`scripts/ai-context-lint.sh`** (NUEVO): valida las secciones obligatorias que LOAD_CONTEXT.md promete SIEMPRE (INFO-core: Sistema/Hardware/Reglas personales/Estructura de proyectos; CONTINUE: Resumen/Pendientes/Stack; LOAD_CONTEXT: Protocolo/Carga condicional/Arquitectura) + front-matter semver-lite (X.Y o X.Y.Z) + `updated` ISO. Flags `--repo/--json/--quick/--help`, exit 0/1/2, stderr limpio en JSON.
- **Hallazgo real del validador**: 3 front-matters usaban `version: X.Y` (2 segmentos) — decisión: aceptar semver-lite X.Y/X.Y.Z (convención de ai-context; skill.yaml sí exige X.Y.Z).
- **`test-ai-context-lint.sh`** (NUEVO, 5 tests, fixtures sin sandbox → corren en --quick). Integrado en run-tests.sh + bash -n.
- Suite: 90→105 quick / 106→121 full. Commit `463937e`.

## 🟠 BUFFY_HOME / common.sh (pendiente §7.5 C2 — HECHO, opt-in)

- **`scripts/lib/common.sh`** (NUEVO): `BUFFY_HOME` opt-in (default `$HOME`) + helpers `buffy_home`/`buffy_ai_context`/`buffy_snapshot`. Normaliza trailing slash.
- **Alcance deliberado**: redirige SOLO el estado generado (ai-context/ + SNAPSHOT); el escaneo del entorno del usuario ($HOME/proyectos, $HOME/scripts, .agents/skills) sigue con $HOME real.
- **Cableado**: buffy-context.sh (SNAPSHOT), buffy-doctor.sh (detección/frescura), buffy-repair.sh (fix_regenerate_snapshot), buffy-router.sh (base). Sin BUFFY_HOME → comportamiento idéntico (verificado con prueba real).
- **`test-common.sh`** (NUEVO, 6 tests). Fix del reviewer: `test_doctor_catalog` ahora usa HOME aislado en fixture (era dependiente del entorno).
- Docs: INSTALL.md (sección BUFFY_HOME), README, REVIEW-BASELINE §2.1. Suite: 105→116 quick / 121→132 full. Commit `033e6dc`.

## 🎮 Laboratorio ZTE Nubia — ManUninstaller revisado, instalado y purga de apps (tarde)

- **Revisión de ManUninstaller v2.1.0 con las skills android-native-dev + clean-architecture + adb** (contra código real, no solo docs): Clean Architecture (domain Kotlin puro → data → presentation → service AIDL). Seguridad verificada: `parseCommandSafe` (ProcessBuilder con args separados, rechaza metacaracteres `[;|&$(){}<>![]~#]`, sin `sh -c` en el path de uninstall), `DeviceAdminUtils.removeAdmin` (valida `ComponentName` antes de `dpm remove-active-admin`), `ShizukuProvider` sin `grantUriPermissions`, regex estricta de paquete en `du`, `deleteRecursively` seguro contra symlinks, `isCriticalApp` protege apps del sistema + diálogo de advertencia, concurrencia `limitedParallelism(8)`.
- **Hallazgos menores (no bloquean)**: `versionName = "2.0.0"` en build.gradle.kts vs CHANGELOG v2.1.0; README menciona `AppViewModelTest` inexistente; `trim-caches` 4GB fijo.
- **Instalación**: en el Mi 10 (`d2c6cbda`) bloqueada por el toggle "Instalar vía USB" de HyperOS — no modificable por ADB (intentado: `adb_install_need_confirm=0`, `pm clear-user-restriction`, `cmd user remove-user-restriction` no existe en la ROM, diálogo MiuiResolverActivity que se cancela solo). **En el ZTE Nubia Z2352N (`320344802623`) `pm install` → Success** (Android 13 stock sin el bloqueo).
- **En vivo verificado**: `SHIZUKU: ACTIVE · 329 apps · 1 admin · 38 grandes`, sin crashes (logcat limpio).
- **Purga de apps de usuario (90 → 68, 22 borradas, 0 fallaron)**: `com.example`, 4 PWAs webapk huérfanas, 9 apps de IA (ChatGPT, Claude, Grok, DeepSeek, Kimi, Gemini Pro, Qwen, Perplexity, Bard) y 8 financieras (MercadoPago, MercadoLibre, PayPal, Tenpo, Onepay, Tapp, WOM, Binance).
- **Bloat de fábrica ZTE deshabilitado (25, reversible con `pm enable`)**: filer, recorder, storagecleanup, privacyzone, onekeycp, alarmclock, livewallpaper, easymode, linkspeedup, womreceiver, inspiredwallpaper, beautify(+adapter), appsimcardfilter, externdevice, ztescreenshot, gamehighlights, gamenotes, flagreset, heartyservice, zbackup, aiengine, burntest.camera, gamehelperline, gamehelpmodule.
- **Preservado (verificado 1 a 1)**: Free Fire, Termux, Shizuku (corriendo), AutoJS6, MacroDroid (único Device Admin), ManUninstaller, launcher Hype/GG Mouse, ReVanced, sndcpy, Canta, Apktool, AppOps + las del gaming `cn.nubia.gamelauncher`/`keymapcenter`/`gamepad` + `com.zte.emode` (engineering mode) + críticas (launcher MiFavor, keyguard, setupwizard, faceverify, fingerprints).
- **Espacio**: las 22 desinstaladas ≈ 1.8–2.2 GB (APK + datos); `pm disable-user` no libera disco (solo RAM/batería). Disco 230G → 163G libres (70%), sin residuos en `/data/data` ni `/data/user/0`.

## 🔜 Pendientes

- [ ] **ManUninstaller**: fix `versionName` 2.0.0 → 2.1.0 en `proyectos/ManUninstaller/app/build.gradle.kts` (1 línea) + rebuild e instalación en el Nubia.
- [ ] **Mi 10**: toggle "Instalar vía USB" (Ajustes → Ajustes adicionales → Privacidad) requiere toque manual en el teléfono — no se puede activar por ADB.
- [ ] **Nubia (opcional)**: revisar restantes de usuario (Truecaller, Waze, WhatsApp, Telegram+, Excel, Sony headphones) y documentar el setup del lab en `Knowledge/Android/`.
- [ ] `gh auth login` → luego renombrar `enerador-de-boletas` → `generador-de-boletas` por API.
- [ ] Baja prioridad (D1/D2 del roadmap): sandbox hardening + installer; adapters VLM/LLM (YAGNI — solo existe un backend HF).
- [ ] Pendiente del usuario desde el teléfono: pushear `porteria_pwa` (cambiar remote a SSH), `sep=,` en exports CSV de pwa_securguard.

---

*Fin de la sesión — Última actualización: 2026-08-03*

## 2026-08-04 — SecurGuard AI fixes + Perfil de Manu

### Fixes aplicados a SecurGuard AI (pwa_securguard)
- `handleResetDay` ahora limpia TODO (logs + personas) — como Manu pidió
- `readArray` trata arrays vacíos como "sin datos" → carga defaults
- Botón eliminar chofer individual (✕) en PersonasTab
- Quitar CCTV feed de PersonasTab
- Lista de choferes con editar (✏️) en PersonasTab
- `handleUpdatePersona` NO toca activeInside — entrada/salida conservan datos originales
- ControlTab muestra datos actuales del persona (merge con master list)
- Búsqueda incluye campo `type`
- Botón "Restaurar Personas de Ejemplo"
- `handleFactoryReset` restaura defaults en vez de dejar vacío

### Perfil guardado
- Archivo: `buffy-context/USER-MANU.md`
- Manu prefiere ejecución directa, no sugerencias
- Stack: Linux/Android/React/TS/Vite/PWA
- Proyectos: SecurGuard, buffy-context, WidgetOS, GameBoostPro, Gmail Organizer



# 🧠 SESION — Buffy Freebuff (2026-08-02 — segunda parte: skills propias + triaje de repos + fixes)

> Tema: instalar skills de ComposioHQ (skill-creator, changelog-generator), crear la skill propia `android-project-setup`, auditar los 6 repos públicos de maneskinleon-del y arreglar los que tenían bugs (porteria_pwa, pwa_securguard, data_car).

---

## 🧩 Skills de ComposioHQ instaladas

- **`skill-creator`** y **`changelog-generator`** instaladas desde `ComposioHQ/awesome-claude-skills` con `npx skills add` (quedan en `~/.agents/skills/`, ya son 41 skills).
- **`changelog-generator` probada**: generó `buffy-context/CHANGELOG.md` a partir de los 43 commits del repo (29-jul → 2-ago), categorizado ✨/🔧/🐛 y en lenguaje user-friendly (filtra el ruido de commits docs).

## 🛠️ Skill propia `android-project-setup` (creada con skill-creator)

- **Estructura**: `~/.agents/skills/android-project-setup/` = SKILL.md + `scripts/{check_device,build_install,grant_permissions}.sh` + `references/{devices,permissions}.md`.
- **Workflow**: build gradle → install APK → permisos Shizuku/overlay/batería → launch, contra el ZTE Nubia (serial `320344802623`).
- **Probada en vivo**: `check_device.sh` detectó la plataforma real **`ums9620`** (corregida en references — decía ums9230); `grant_permissions.sh` concedió los 6 permisos (incluye POST_NOTIFICATION) con verificación solo-lectura.
- **Code review aplicado**: fix al build que instalaba APK viejo si fallaba (ahora aborta sin `BUILD SUCCESSFUL`), parseo de applicationId robusto (comillas simples/dobles), simplificación de multi-dispositivo.
- **Versionada en el repo** (commit `7df99bd`): `.agents/skills/android-project-setup/` + entrada en CHANGELOG.md + árbol del README. **Registrada en el stack** (commit `14dcf56`): sección Skills en `INFO-core.md` + carga condicional Android en `LOAD_CONTEXT.md`.

## 🔍 Triaje de repos `maneskinleon-del` (6 repos)

Typecheck real (`tsc --noEmit`) + build + escaneo de secrets/TODOs en los 6 repos (4 clonados frescos en /tmp + data_car/pwa_securguard locales):

| Repo | Estado | Hallazgo |
|---|---|---|
| `porteria_pwa` | ❌ 5 errores TS | Tabs con ids MAYÚSCULAS (`'INGRESO'`) vs store en minúsculas (`'registro'`) → contenido de tabs nunca renderizaba al cargar; Toast leía `toast.message` (no existe, el store tiene `toastMessage`) → nunca se mostraba |
| `pwa_securguard` | ⚠️ 1 bug funcional | Reporte CSV de incidencias se veía roto en Excel es-CL (ver sección abajo) |
| `data_car` | ⚠️ código muerto | `server.ts` (Express+Gemini, deps NO en package.json, `app` antes de declarar) y `Tachometer.tsx` (import `TelemetryStats` inexistente, sin uso) |
| `timemark` | ✅ sano | 3 console.log |
| `lista_supermercado` | ✅ sano | 10 console.log |
| `enerador-de-boletas` | ✅ sano | **typo en el nombre del repo** (→ `generador-de-boletas`), package.json ya dice el nombre correcto |

- Sin secrets filtrados: todos los `.env` son `.env.example` correctamente gitignored.
- `core-termux-brain` está vacío (0 KB) — candidato a borrar en GitHub.

## 🐛 Fix `porteria_pwa` (bugs de UI)

- `src/App.tsx`: ids de tabs unificados a los del store (`registro`/`frecuentes`/`exportar`/`importar`) + `as const` + eliminado el `as any`; Toast ahora lee `toastMessage`.
- Verificado: `tsc --noEmit` EXIT 0 (antes 5 errores) + `vite build` OK.
- Commit `d97ed4c` en `~/proyectos/porteria_pwa` — **pendiente de push** (remote HTTPS sin credenciales; falta `gh auth` o cambiar a SSH).

## 🐛 Fix `pwa_securguard` — reporte CSV de incidencias

El CSV exportado se veía "todo en una columna" / "incidencia hacia abajo en una sola celda" al abrirlo en **Excel móvil con configuración regional es-CL** (usa `;` como separador). Fix en `src/utils/report.ts`:

1. **`sep=,`** como primera línea — fuerza el delimitador coma en Excel sin importar la regional.
2. **`flatText()`** — normaliza saltos de línea de la descripción (textarea) a un espacio: cada incidente queda en UNA fila.
3. **`csvRow()` en metadatos** — la coma de `Fecha de Exportación: 02-08-2026, 5:22 p. m.` estaba sin escapar (3 columnas).
4. **Línea en blanco** antes de `--- INFORME DE INCIDENCIAS ---` (las otras secciones sí la tenían).

### Campo `date` en IncidentReport (fecha real, no de exportación)

- `types.ts`: `date: string` (fecha REAL del incidente). `useAppState.handleSaveIncident` la setea con `getLocalDateISO()`.
- **`sanitizeIncidents`** nuevo (sigue el patrón `sanitizeLogs`/`sanitizePersonas`): al rehidratar backfillea `date` a hoy para incidencias viejas y valida categoría → el tipo queda honesto y sin fallbacks duplicados.
- `SettingsTab` muestra `FECHA: {inc.date}` en la tarjeta.
- Verificado: typecheck EXIT 0, build OK, test funcional muestra `2026-07-25` (fecha real) en vez de la de exportación.
- **Commit `a375c88` pusheado** — el remote estaba en HTTPS sin credenciales, se cambió a **SSH** (`git@github.com:`) con la clave ed25519 existente.

## 🐛 Fix `data_car` — código muerto eliminado

- `git rm server.ts` (-194 líneas) y `src/components/Tachometer.tsx` (-209 líneas). Verificado antes con grep que nadie los referencia (ni .ts/.tsx/.json/.sh/.md; el `server:` de vite.config.ts es el dev server de Vite).
- Typecheck pasó de 5 errores a **EXIT 0**; build OK. Commit `642f72a` pusheado.

## 📝 Revisión del script git del usuario (descartado)

- Script de configuración git (identidad + HTTPS/PAT o SSH) con 2 bugs críticos **confirmados por ejecución**: el `sed` de limpieza de URL devuelve `https://` a secas con URLs normales (come el path), y `ssh-keygen -t ed25519 -c` (minúscula) da "Too many arguments" — debe ser `-C`. Además inyecta el token en el remote (mala práctica).
- **Decisión**: no arreglarlo — el setup real ya usa SSH y funciona.

## 🔜 Pendientes

- [ ] `gh auth login` (lo iba a correr el usuario) → luego renombrar `enerador-de-boletas` → `generador-de-boletas` por API y **pushear `porteria_pwa`** (cambiar remote a SSH).
- [ ] Aplicar `sep=,` a los exports CSV simples de pwa_securguard (`csvDownload` en LogsTab/PersonasTab).
- [ ] Limpiar `/tmp/repo_triage/` (clones temporales del triaje).

---

*Fin de la sesión — Última actualización: 2026-08-02*

---



# 🧠 SESION — Buffy Freebuff (2026-08-02 — organización del home + Ollama al HDD + unificación ai-context)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎮 Free Fire — verificación de cleanup con Alt+Q

- Confirmado que el cleanup real ya existía en `scripts/scrcpy-freefire.sh` (implementado el 2026-08-01): `alt+q` (sxhkdrc:162 → `bspc node -{c,k}`) cierra la ventana de scrcpy → el trap EXIT corre `close_game_apps()` (force-stop de apps + apagado de pantalla con 5s de gracia).
- Config: `CLOSE_APPS_ON_EXIT=1`, `SCREEN_OFF_DELAY=5`, `KILL_PERSISTENT=0`.
- Se verificó en vivo que la sesión corría estable (53-60 fps) y que el log no mostraba cleanup porque la sesión seguía activa en ese momento.

## 🔍 Repo ComposioHQ/awesome-claude-skills — análisis

- Catálogo de 1000+ Claude Skills; 864 instalables en el repo (rama master, Apache 2.0).
- El skill "WhatsApp Automation" del README **NO existe como carpeta** en el repo (2048 paths, 0 con whatsapp) — es un wrapper del SaaS de Composio (sección `composio-skills/` = embudo de marketing, lock-in + API key de su nube).
- Instalada **file-organizer** (`npx skills add`) en `~/.agents/skills/` (carpeta file-organizer).
- Veredicto: pocas joyas reales para el stack (file-organizer, skill-creator, changelog-generator); el resto es específico de Claude Code o vendor-locked.

## 🗂️ Organización del home (disco del sistema: 67% → 39%)

| Acción | Detalle |
|---|---|
| `~/Backups` (28G) | → `/media/datos/Backups` con symlink (verificado byte a byte: 29.897.717.636 bytes / 166 archivos; los videos eran de root, copia vieja borrada con sudo) |
| Proyectos sueltos | `data_car`, `codebuff-automation`, `odysseus` → `~/proyectos/` con symlinks (odysseus era root, sudo) |
| Notas | `memoria.md`, `widgetos_contexto.md`, `polybar_melissa_fix_prompt.md`, `missing_apps.txt`, `pwa_securguard_review_deepseek.txt` → `~/notas/` |
| Logs | `cf_tunnel.log`, `server.log` → `~/logs/` |
| Basura | Eliminados `ervice --no-pager -n 50`, `udo systemctl start bluetooth.service`, `.zcompdump` viejos |
| Caches | npm (-4G), gradle caches (-4G), `~/.cache` 8.5G→360M (yay, Google, mozilla, uv, go-build) |
| Resultado | 69G → 126G libres en el disco del sistema |

## 🦙 Ollama al HDD (14G liberados)

- `~/.ollama` (14G) → `/media/datos/ollama` con symlink, verificado byte a byte (14.225.477.048 bytes / 32 archivos).
- **Descubrimiento**: había DOS servicios ollama — el de **sistema** (`/usr/local/bin/ollama`, el que sirve de verdad en el puerto 11434) y uno de **usuario** (`/usr/bin/ollama`) en crash-loop por conflicto de puerto. Se detuvo y **deshabilitó el de usuario**; queda solo el de sistema.
- Verificado: `ollama list` y `ollama show qwen2.5:7b` leen desde el HDD; escritura OK para pulls futuros.
- Nota: `id_ed25519` quedó con permisos 644 en NTFS (el mount `fmask=133` no respeta chmod) — aceptable en máquina de un solo usuario; alternativa documentada: `OLLAMA_MODELS` apuntando solo a `models/`.

## 🔗 Unificación ai-context (esta tarea)

- `buffy-context/` (repo git, fuente de verdad, pusheado a GitHub) y `~/ai-context/` (copia de trabajo de los agentes) habían **divergido en ambas direcciones**: el repo tenía las sesiones 07-30 (RAM+watchdog, push GitHub) y 08-01 (systemd-boot); la raíz tenía 07-31 (Hermes/Command Code, limpieza de agentes) y 08-01 (cleanup real + limpieza del teléfono).
- **Fusión bidireccional en el repo**: `SESION.md` (1109 líneas, contenido de ambas copias) + `CHANGELOG.md` (495 líneas, + entrada systemd-boot).
- `~/ai-context` ahora es **symlink → `~/buffy-context/ai-context`** (una sola fuente de verdad; `SNAPSHOT.md` sigue gitignored por regenerarse cada sesión).
- `AGENTS-root.md` actualizado: apunta a `INFO-core.md` en vez de `SYSTEM.md` (deprecado).
- Commit en buffy-context con la unificación.

*Fin de la sesión — Última actualización: 2026-08-02*

---



# 🧠 SESION — Buffy Freebuff (2026-07-29 — día completo: memoria + Knowledge + agentes + repo GitHub)

> Contexto de todo lo implementado durante la sesión completa del 2026-07-29.

---

## 📦 Repo GitHub `buffy-context`

### Creación del repositorio
- **`~/buffy-context/`** creado con estructura: `ai-context/`, `Knowledge/`, `.agents/skills/`, `scripts/`
- Git init + push a `github.com/maneskinleon-del/buffy-context` (público)
- **MIT License** agregada
- **README.md** profesional con badges, estructura, quick start, uso con agentes IA
- **INSTALL.md** con instrucciones de setup
- **6 commits** en `main`

### Correcciones post-feedback del usuario
Basado en análisis crítico de 5 puntos:

1. **Carga condicional para 6 categorías** (antes solo Android):
   - LOAD_CONTEXT.md reescrito con señales de activación para React, Linux, Git, Node y Shell
   - Cada categoría con detección explícita (package.json, mención de tema, etc.)

2. **Presupuesto de tokens + poda automática**:
   - SESION.md: 720 → 81 líneas (archivado a SESION-archive.md)
   - CHANGELOG.md: 429 → 132 líneas (archivado a CHANGELOG-archive.md)
   - Headers de poda agregados a ambos archivos

3. **Redundancia eliminada**:
   - Sección "Jerarquía de contexto" (duplicada) eliminada de LOAD_CONTEXT.md

4. **SYSTEM.md/SYSTEM_FULL.md deprecados**:
   - Marcados DEPRECATED con redirect a INFO-core.md/INFO-full.md

5. **Primera sesión**:
   - LOAD_CONTEXT.md ahora dice qué hacer si CONTINUE.md no existe

## 📚 Base de conocimiento `Knowledge/`

16 archivos · 1,305 líneas · 6 categorías creadas:

| Categoría | Archivos | Contenido |
|-----------|----------|-----------|
| Android | 6 | ADB, Shizuku, HyperOS, GameOptimization, scrcpy, Keymappers |
| Linux | 2 | System (Arch/bspwm/systemd), Kernel |
| React | 4 | React+TS, Vite, Tailwind v4, PWA |
| Git | 1 | Commands + gh CLI |
| Node | 1 | npm, package.json |
| Shell | 1 | Bash/Zsh scripting |

## 🤖 Android Agent

- **Skill**: `.agents/skills/android-agent/SKILL.md` — detecta proyectos Android automáticamente
- **Script**: `.local/bin/android-detect.sh` — diagnóstico con `--quick` y `--watch`
- **Shizuku activado**: rish extraído del APK (Shizuku v13.7.0 corriendo en ZTE Nubia)
- **DPI cambiado**: vía Shizuku, 480 físico → 280 override
- **Free Fire diagnosticado**: CPU 0.8% (background), 13% jank sistema, temp 30.1°C

## 🔍 Code Search adapter

- **Skill portable**: `.agents/skills/code-search/SKILL.md` — funciona en Freebuff, Claude Code, Codex
- 3 modos de búsqueda: agente nativo → CLI (ripgrep) → exploración manual
- **search_criteria_v4**: skill de búsqueda estructurada copiada al repo

## 🎮 Skill scrcpy-freefire expandida

### Secciones agregadas a `.agents/skills/scrcpy-freefire/SKILL.md`

#### 🧪 Diagnóstico de lag
- Tabla para identificar tipo de lag (input vs video vs thermal vs game)
- Interpretación de `--print-fps`
- Comandos `adb shell dumpsys gfxinfo` y `dumpsys SurfaceFlinger`
- Tabla de trade-offs completa
- Procedimiento diagnóstico de 5 pasos (con verificación USB incluida)

#### 🔧 Alternativas de keymappers
- **Mantis Gamepad Pro**: Setup completo con Shizuku, recomendada
- **Panda Mouse Pro**: Alternativa ligera
- **Octopus**: Advertencia de ban para Free Fire
- Tabla comparativa (GG Mouse vs Mantis vs Panda vs Octopus)

#### 🔍 Troubleshooting detallado (expandido)
- UHID: cursor invisible/atrapado, teclado no funciona, teclas stuck
- Input desync después de alt+tab
- Wayland vs X11 — problemas y soluciones
- GG Mouse Pro 2 se desactiva solo (5 causas + soluciones)
- Lag al girar cámara en Free Fire
- Free Fire borroso
- Problemas de permisos Shizuku

### Detalles pulidos post-review
- Advertencia de input lag en `--render-expired-frames`
- Chequeo USB agregado al diagnóstico de 5 pasos
- Orden del reset drástico movido a último recurso

---

## 🧠 Sistema de memoria persistente

### Contexto inicial
El usuario ya tenía una carpeta `ai-context/` con archivos manualmente mantenidos:
- `INFO-core.md`, `INFO-full.md` — contexto de sistema
- `SNAPSHOT.md` — generado por `buffy-context.sh`
- `SESION.md` — bitácora manual de sesiones anteriores
- `PROJECTS.md`, `CHANGELOG.md`, `AGENTS.md`, etc.

### Problemas identificados
1. **Sin protocolo formal** — cada agente empezaba desde cero, no había un "cargar esto primero"
2. **No había handoff** — `CONTINUE.md` no existía
3. **`buffy-context.sh` hardcodeaba "Mango WM (Wayland)"** — el usuario corre bspwm X11
4. **`scripts/ai-context.sh`** generaba zips inútiles en vez de contexto estructurado
5. **SNAPSHOT.md** decía "WM: Mango WM (Wayland)" — información incorrecta

### Solución implementada

| Archivo | Cambio |
|---------|--------|
| `ai-context/LOAD_CONTEXT.md` | **NUEVO**: Protocolo para agentes — qué leer al inicio y qué escribir al cierre |
| `ai-context/CONTINUE.md` | **NUEVO**: Handoff entre sesiones — resumen, archivos tocados, pendientes, stack |
| `ai-context/SNAPSHOT.md` | ✅ Actualizado: WM corregido a bspwm, estado fresco del sistema |
| `ai-context/SESION.md` | ✅ Actualizado: esta entrada |
| `~/.local/bin/buffy-context.sh` | ✅ Fix: detección dinámica de WM vía `loginctl` |

### Cómo funciona

**Al inicio de cada sesión** (para cualquier agente):
1. Leer `INFO-core.md` — contexto base del sistema
2. Leer `SNAPSHOT.md` — estado vivo (procesos, RAM, proyectos)
3. Leer `CONTINUE.md` — de qué halar, qué pendientes hay

**Al cierre de cada sesión** (para cualquier agente):
1. Escribir `CONTINUE.md` — resumen de lo hecho
2. Actualizar `SNAPSHOT.md` si cambió el sistema
3. Actualizar `SESION.md` con bitácora detallada

---

*Fin de la sesión — Última actualización: 2026-07-29*

---



# 🧠 SESION — Buffy Freebuff (2026-07-30 — push repo GitHub + auditoría repo git del home)

> Tema: diagnosticar por qué "no se veían" los cambios en GitHub, subir los 12 commits pendientes, y auditar el repo git accidental del home.

---

## 📦 Repo GitHub `buffy-context` — push completado

### Diagnóstico
- Los cambios SÍ existían localmente (12 commits en `main`, incluyendo `aa556d9 Fix: token budget, conditional loading, pruning, deprecations`)
- El remoto usaba **HTTPS sin credenciales** → el push fallaba en silencio
- GitHub solo tenía el commit inicial `0c02f1a` (por eso "no se veía nada")

### Solución
- Cambiado el remote de HTTPS → **SSH** (`git@github.com:maneskinleon-del/buffy-context.git`), usando la llave `~/.ssh/id_ed25519` que ya estaba registrada en GitHub como `maneskinleon-del`
- **Push exitoso**: GitHub ahora muestra los 13 commits + README completo
- Verificado desde 3 fuentes: `git ls-remote`, GitHub API, navegador (13 commits, README "Buffy Context")

### Nota: fechas "yesterday"
- GitHub muestra la fecha de **autoría** (29/07), no la del push (30/07). Es comportamiento normal de git — los commits se escribieron ayer.

## 🗂️ Auditoría: repo git del home (`/home/mangonz`)

### Hallazgos
- `/home/mangonz` es un repo git en rama `master`, **sin remote** (3 commits: codebuff-automation + GameBoost Pro)
- Trackea **104 archivos**: `codebuff-automation/` completo + `proyectos/autoscript-mobile-interface/` (GameBoost Pro)
- **Esos proyectos NO tienen su propio `.git`** → el repo del home es su ÚNICA historia git
- **Decisión del usuario: dejarlo como está** (riesgo bajo sin remote). Opción de `.gitignore` agresivo queda disponible.

---



# 🧠 SESION — Buffy Freebuff (2026-07-30 noche — RAM + watchdog MCP + force-stop en scrcpy-freefire)

> Tema: diagnóstico de RAM, cleanup automático de chrome-devtools-mcp huérfanos, y matanza de apps de terceros antes de Free Fire.

---

## 🧹 Diagnóstico de RAM (13GB)

- Top consumidores: **Chrome (~1.1GB)**, **python3/open-webui uvicorn (~1GB)**, **freebuff (~515MB)**, **alacritty (~594MB)**
- Se identificaron **procesos huérfanos del agente**: `chrome-devtools-mcp` (npm exec + MCP + watchdog) quedaban vivos tras tareas de navegador (~1GB)

## 🛡️ Watchdog `cleanup-mcp.sh` + systemd timer

- `chrome-devtools-mcp` **NO tiene flag nativo de auto-exit** (revisado todo su `--help`)
- Se creó `~/.local/bin/cleanup-mcp.sh` (watchdog): mata MCP huérfanos con **edad > 10min** y **CPU del árbol < 1% en 2 muestras** (4s+6s+4s)
- Unidades systemd user: `mcp-cleanup.service` (oneshot) + `mcp-cleanup.timer` (cada 5 min, Persistent=true)
- Mató el MCP huérfano de la verificación GitHub → **~1.1GB liberados** (3.2GB usados)
- Log en `~/.local/state/mcp-cleanup.log`
- **3 pasadas de code review** aprobadas (fixes: guard race /proc/stat, árbol capturado una vez para KILL, doble muestra CPU, rotación log 500 líneas, clamp CPU negativa)

## 🎮 Force-stop de apps de terceros en `~/scripts/scrcpy-freefire.sh`

- Añadida función `kill_background_apps()` que ejecuta `pm list packages -3` + `am force-stop` en cada app de terceros
- **EXCLUSIONES**: `com.zjx.ztezscreenshot` (GG Mouse) y `com.dts.freefireth` (Free Fire) — se mantienen vivas
- Configurable: `KILL_BG_APPS="1"` (toggle) y `KEEP_ALIVE_APPS="com.zjx.ztezscreenshot com.dts.freefireth"`
- **Prueba real en ZTE**: 91 apps de terceros matadas, GG Mouse + Free Fire intactos ✅
- Se ejecuta ANTES de lanzar GG Mouse y Free Fire (sección previa a PERMISOS GG MOUSE)
- 2 pasadas de code review aprobadas (quoting de doble comilla + escapes verificado)

---



# 🧠 SESION — Buffy Freebuff (2026-08-01 — Kimi K3 vía Hugging Face + MCP)

> Tema: investigación de cómo usar Kimi K3 (Moonshot AI) desde Hugging Face, aclaración de MCP vs modelo, y documentación en Knowledge/.

---

## 🤖 Kimi K3 — hallazgo documentado

- **Qué es:** modelo multimodal 2.8T (MoE) de Moonshot AI, 1M tokens de contexto, tool calling ✅
- **Acceso:** HuggingChat web (gratis) | API OpenAI-compatible `https://router.huggingface.co/v1` + token HF (pago por uso) | API Moonshot `platform.kimi.ai`
- **Model ID:** `moonshotai/Kimi-K3`

## ⚠️ Aclaración clave: MCP vs modelo

- **MCP conecta herramientas**, no es la forma de "usar el modelo"
- HuggingChat es **cliente** MCP; el servidor MCP oficial de HF (`@huggingface/mcp-server`) expone el Hub, no chat con modelos
- Para usar Kimi K3 como cerebro: API OpenAI-compatible o HuggingChat web

## 📂 Acciones

- ✅ Creado `Knowledge/AI/Kimi-K3.md` — referencia completa (acceso, ejemplos curl, casos de uso)
- ✅ Actualizado `Knowledge/README.md` — nueva categoría AI + fecha
- ✅ Sesión registrada en `SESION.md`

## 💻 kimi_vision.js creado + repo clonado vía SSH

- **`kimi_vision.js`** (raíz, Node 26, CommonJS): visión IA con Kimi K3 (`moonshotai/Kimi-K3`) vía API HF OpenAI-compatible (`router.huggingface.co/v1`). Envía el screenshot en base64; el modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish (ruta resuelta automáticamente: env RISH > ~/bin/rish > PATH). Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + aceptar licencia gated del modelo. Probado con API simulada ✅, con HF_TOKEN real ✅ y con diálogo real + `--grant` ✅ (notificaciones VInstall, 98%).
- **Repo `buffy-context` clonado en este dispositivo**: `~/buffy-context` (44 archivos, working tree limpio). Remote `origin` en **SSH** (`git@github.com:maneskinleon-del/buffy-context.git`). Clave ed25519 registrada en GitHub ✅ y push exitoso (`7bcb639`).
- **`kimi_vision.js` integrado al repo** (scripts/): copiado a `scripts/kimi_vision.js` (diff 0, `node --check` ✅), documentado en `Knowledge/AI/Kimi-K3.md` (sección "Script implementado") y en el árbol de `README.md`.

## 🔜 Pendientes

- [x] `kimi_vision.js` creado — script de visión IA (upgrade de `auto_permiso.py`) ✅
- [x] Clave SSH registrada en github.com/settings/keys y push por SSH funcionando ✅
- [x] `kimi_vision.js` agregado al repo en `scripts/` y documentado ✅
- [ ] Token HF con scope de inferencia + método de pago configurado (el scope de inferencia ya se validó con la prueba real ✅; falta método de pago)
- [x] Probar `kimi_vision.js` con HF_TOKEN real ✅ (Kimi K3 respondió en 10.2s; identificó correctamente que el screenshot NO era un diálogo de permiso)
- [x] Probar `kimi_vision.js` contra un screenshot de un diálogo de permiso real (con `--grant`) ✅ — diálogo de notificaciones de VInstall (`com.vinstall.alwiz`) detectado al 98% y concedido: `pm grant POST_NOTIFICATIONS` + `appops POST_NOTIFICATION=allow`, verificado `granted=true`
- [ ] Decidir si revocar el token GitHub expuesto en el chat

---



# 🧠 SESION — Buffy Freebuff (2026-08-01 — systemd-boot fix + ask-model.js "segundo cerebro" + kimi_vision.js adoptado)

> Tema: arreglar el menú de arranque que esperaba Enter (no era GRUB), montar un complemento para consultar otros modelos (local/nube), adoptar la mejora kimi_vision.js del repo, y aclarar el mito de MCP.

---

## 🔧 systemd-boot — fix del "menú que espera Enter" (no era GRUB)

- **Diagnóstico**: el sistema usa **systemd-boot** (NO GRUB) — `efibootmgr` apunta a `\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI`, ESP montado en `/efi`.
- **Causa raíz**: variable EFI `LoaderConfigTimeout` (GUID 4a67b082-...) con el valor especial **`menu-force`** (UTF-16, verificado con xxd) → pisa el `timeout 3` de `/efi/loader/loader.conf` y obliga a esperar Enter indefinidamente.
- **Fix**: `sudo bootctl set-timeout 3` → luego el usuario pidió arranque instantáneo: `sudo bootctl set-timeout 0` + `sed -i 's/^timeout .*/timeout 0/' /efi/loader/loader.conf`. Verificado: var EFI = `0` y `loader.conf` = `timeout 0` (ambos consistentes).
- **Escape hatches con timeout 0**: boot counting + fallback automático si el kernel default falla (independiente del menú, confirmado en `man systemd-boot`); menú puntual con `systemctl reboot --boot-loader-menu=force`.

## 🧪 ask-model.js — "segundo cerebro" de terminal (local + nube)

- **Nuevo**: `codebuff-automation/ask-model.js` — consulta cualquier modelo vía API OpenAI-compatible: **Ollama local** (qwen2.5:7b, moondream, minicpm-v) o **HF Router nube** (DeepSeek V4 Flash/Pro/R1, Kimi K3). Sin MCP, sin deps nuevas (usa `lib/logger.js` + `lib/utils.js` vendored).
- Modos: one-shot, `--chat` (memoria, últimos 4 turnos), `--list`, `--json`, separador `--` para prompts con guiones.
- **Token**: `~/.huggingface/token` (chmod 600). `resolveHfToken()` extraída a `lib/utils.js` (compartida con kimi_vision.js: env HF_TOKEN > archivo > vacío, fallback Termux-aware).
- **Pruebas reales**: qwen2.5:7b local (~2.8–17s), DeepSeek V4 Flash (~0.7–3.5s), Kimi K3 (~3.5s). Todo ✅.
- **Flujo de segunda opinión demostrado**: consulté a DeepSeek sobre la decisión `timeout 0`; DeepSeek se equivocó en 1 punto (dijo que el boot counting no se activa con timeout 0 — la doc oficial confirma que SÍ es independiente del menú). Contraverificación contra `man systemd-boot`.

## 📥 kimi_vision.js adoptado (desde repo buffy-context remoto)

- Descargados `scripts/kimi_vision.js` + `scripts/lib/{logger,utils}.js` + `Knowledge/AI/Kimi-K3.md` de `maneskinleon-del/buffy-context` → `codebuff-automation/` (diff 0 con el repo).
- Skills actualizadas: `codebuff-automation/skills/image-analyzer.md` y `.agents/skills/image-analyzer/SKILL.md` (kimi_vision.js recomendado, auto_permiso.py como fallback OCR).
- Provenance documentada en `codebuff-automation/codebuff-memoria.md`.

## 🧠 MCP aclarado (dos respuestas de otro modelo evaluadas)

- El texto propuesto decía "el modelo local es el servidor MCP" — **incorrecto**: el LLM/host es el CLIENTE MCP; los servidores exponen herramientas (filesystem, DB, APIs). Confirmado con la doc oficial del SDK (`FastMCP`, stdio/SSE, handshake `initialize`).
- Conclusión: para "consultar otro modelo" no hace falta MCP — es una llamada HTTP OpenAI-compatible (como ask-model.js).

## 🔜 Pendientes

- [ ] Sincronizar clon local `~/buffy-context` con `origin/main` (25 commits atrás; 3 archivos sin commitear: INFO-core.md, INFO-full.md, PROJECTS.md)
- [ ] Decidir si rotar el HF_TOKEN (quedó expuesto en el chat)
- [ ] Alias `ask`/`askc`/`askl` en el shell

---



# 🧠 SESION — Buffy Freebuff (2026-07-31 — limpieza de agentes IA)

> Contexto de la limpieza de agentes IA en desuso.

---

## 🧹 Limpieza de agentes IA en desuso

### Pedido del usuario
"Tengo bastante basura de IAs que ya no uso" — limpiar agentes IA obsoletos.

### Seleccionado por el usuario (eliminado)
| Item | Detalle | Espacio |
|---|---|---|
| **Claude Code** | `npm uninstall -g @anthropic-ai/claude-code` + `rm ~/.claude.json` | ~223 MB |
| **Kilo** | `rm -rf ~/.kilo` + línea PATH removida de `.zshrc` | ~250 MB |
| **Mimo** | `npm uninstall -g @mimo-ai/cli` + `rm -rf ~/.mimocode` | ~480 MB |
| **aichat** | `cargo uninstall aichat` (metadata corrupta corregida en `.crates.toml`/`.crates2.json`) | pequeño |
| **Cache Playwright** | `rm -rf ~/.cache/ms-playwright` (redescargable) | ~943 MB |
| **Cache Kimchi** | `rm -rf ~/.cache/kimchi` (binario kimchi ya no existía) | ~121 MB |
| **Odysseus** | `rm -rf ~/odysseus` (confirmado por usuario; requirió sudo por permisos root) | ~772 KB |
| **Symlink `rtk`** | `rm -f ~/.local/bin/rtk` (apuntaba a kimchi, inexistente) | — |

### No eliminados (activos o recientes)
- **freebuff** (este agente), **OmniRoute** (gateway activo), **OpenClaw** (gateway activo)
- **command-code** (recién instalado para probar), **vercel**, **clasp**, **ctx7**, **playwright-cli**
- **Gemini CLI** (el usuario no lo seleccionó), **Ollama** (conservado; modelos moondream/minicpm-v/qwen permanecen, solo qwen2.5:7b se usa como fallback de OpenClaw)

### Archivos modificados
| Archivo | Cambio |
|---|---|
| `~/.zshrc` | Removida línea `export PATH=.../.kilo/bin` |
| `memoria.md` | Removidas filas Claude Code, kimchi, Odysseus, kilo/mimocode del PATH, filas kimchi/claude/rtk de ~/.local/bin |
| `ai-context/SNAPSHOT.md` | Regenerado |
| `ai-context/CHANGELOG.md` | Entrada 2026-07-31 agregada |

---

*Fin de la sesión — Última actualización: 2026-07-31*

---

## 🎮 scrcpy-freefire.sh — Cleanup real al salir (cierra apps + apaga pantalla) — 2026-08-01

### Problema
Al cerrar el script quedaban apps corriendo en el teléfono (gastaban batería). El cleanup viejo solo hacía `am force-stop` a 2 apps (Free Fire + screenshot), y **8 apps se reiniciaban solas** porque son Device Admins activos / auto-reinicio: Android prohíbe su force-stop (anti-malware).

**Misterio resuelto:** la sesión que parecía "no funcionar" corría el código viejo — su log decía `com.dts.freefireth / com.zjx.ztezscreenshot detenidas` (solo 2 apps). Al reabrir (launcher), el juego volvía a arrancar y todo parecía igual.

### Solución
| Pieza | Qué hace |
|---|---|
| `KILL_PERSISTENT="0"` | **Default seguro (OFF)**: el force-stop normal ya cierra el juego y apps normales. En `1` hace barrido agresivo con `pm disable-user` |
| `pm disable-user` al cerrar | Mata de verdad a los Device Admins (verificado: mueren y quedan muertos) |
| `pm enable` + `dpm set-active-admin` al iniciar | Restaura las apps completas, **incluido su estado de Device Admin** |
| `SESSION_STARTED` gate | Solo limpia si el juego realmente arrancó (si scrcpy falla 3 veces, no toca nada) |
| `PERSISTENT_ADMIN_RECEIVERS` | Receivers de admin a re-grantear con `dpm` (descubrimiento: `pm enable` NO restaura el estado de admin — probado en vivo) |
| **`scrcpy-freefire-restore.sh`** (nuevo) | Restauración manual independiente si saliste y no volvés a abrir el script. Lee las listas del main vía `sed` (una sola fuente de verdad) |

### Cierre con Alt+Q
- El usuario cierra con **Alt+Q** (binding `sxhkdrc:162` — bspwm cierra la ventana de scrcpy → el script detecta el cierre y corre el cleanup)
- Hint del notify actualizado: `scrcpy corriendo — Alt+Q para salir (limpia y apaga pantalla)`
- Flujo verificado en vivo: `Restaurando... → Cerrando apps → Apagando pantalla en 5s → Pantalla apagada`

### Incidente transparencia
Los ciclos disable→enable de prueba desactivaron el Device Admin de MacroDroid/Tasker/Automate. **Restaurados** con `dpm set-active-admin` (los 3 con Success + policies visibles).

### Archivos
| Archivo | Cambio |
|---|---|
| `~/scripts/scrcpy-freefire.sh` | Cleanup real: close_game_apps + screen off 5s + KILL_PERSISTENT + gates + re-enable con dpm + hint Alt+Q |
| `~/scripts/scrcpy-freefire-restore.sh` | Nuevo: restaura apps + admins leyendo listas del main |
| `.openclaw/workspace/scripts/scrcpy-freefire.sh` | Sincronizado |

---

## 🗑️ Limpieza del teléfono — laboratorio de pruebas — 2026-08-01

### Desinstaladas (verificado: `pm path` vacío)
| App | Paquete | Resultado |
|---|---|---|
| **Tasker** | `net.dinglisch.android.taskerm` | ✅ `Success` |
| **Automate** | `com.llamalab.automate` | ✅ `Success` |
| **Facebook** | `com.facebook.katana` | ✅ `Success` |

### El detalle técnico
Tasker y Automate eran **Device Admins activos** → Android bloquea su desinstalación (`DELETE_FAILED_DEVICE_POLICY_MANAGER`), y `dpm remove-active-admin` solo funciona para test-only admins (estos eran `testOnlyAdmin=false`). **Solución:** `pm disable-user` primero (desactiva el admin al deshabilitar el paquete) → `pm uninstall` después. Funcionó perfecto. Quedó demostrado que el único admin activo restante es **MacroDroid**.

### Scripts actualizados
- `PERSISTENT_APPS`: removidos `taskerm` y `llamalab.automate` (quedan macrodroid, autojs6, kustom.widget, steps, launcher.hype)
- `PERSISTENT_ADMIN_RECEIVERS`: quedó solo el receiver de MacroDroid
- El restore script se actualiza solo (lee listas del main vía `sed`)

### Pendiente para mañana (laboratorio)
- Quedan candidatos a borrar: MacroDroid, AutoJS, Kustom Widget, Steps, `com.launcher.hype`
- Considerar `KILL_PERSISTENT=1` si se quiere el lab sin nada corriendo al salir

---

*Fin de la sesión — Última actualización: 2026-08-01*



# 🧠 SESION — Buffy Freebuff (2026-07-31)

> Contexto de todo lo implementado durante esta sesión.

---

## 🤖 Command Code instalado + Hermes eliminado + OpenClaw migrado a blockrun

### Pedido del usuario
1. Probar el nuevo agente de IA **Command Code** (`https://commandcode.ai/`)
2. **Eliminar Hermes** (agente de Nous Research) — su plan gratuito duró solo 2 semanas

### Command Code (v1.6.1) — instalado
- `npm i -g command-code@latest` → `~/.npm-global/bin/command-code` (+ alias `cmd`)
- Postinstall de `protobufjs` estaba bloqueado por npm; habilitado con `--allow-scripts=protobufjs` y persistido en config (`npm config set allow-scripts=protobufjs --location=user`)
- Verificado: `command-code --version` → 1.6.1 · `--list-models` → 50 modelos (deepseek, kimi, glm, claude, gpt, gemini, grok, etc.)
- **Pendiente del usuario**: `cmd login` (OAuth por navegador) y primer uso en un proyecto

### Hermes — eliminado por completo (~1.9 GB liberados)
| Componente | Acción |
|---|---|
| `~/.hermes/` | `rm -rf` (agent, venv, state.db, skills, kanban, sessions) |
| `~/.buffy-hermes/` | `rm -rf` (workspace inbox/outbox/context) |
| `~/.local/state/hermes/` | `rm -rf` |
| `~/.ollama/backup/hermes/` | `rm -rf` |
| `~/.local/bin/{hermes,buffy-hermes,nous-refresh}` | eliminados |
| `nous-refresh.{service,timer}` (systemd user) | stop + disable + rm + daemon-reload |
| `~/.zshrc` (bloque "Nous Portal API key" + `eval nous-refresh`) | líneas 571-574 eliminadas |
| `NOUS_API_KEY` en systemd user env | `systemctl --user unset-environment` |
| `memoria.md`, `ai-context/SNAPSHOT.md` | referencias hermes removidas |

### OpenClaw — migrado de provider `nous` → `blockrun`
- El provider `nous` (plan gratuito expirado) dejó el gateway en `failed` por `NOUS_API_KEY` inexistente
- `~/.openclaw/openclaw.json`: eliminado provider `nous`; `primary=blockrun/auto`, fallbacks `['ollama/qwen2.5:7b','blockrun/free']`; aliases `nous/*` removidos
- `openclaw-gateway.service`: `OPENCLAW_SERVICE_MANAGED_ENV_KEYS` → solo `KIMCHI_API_KEY`
- Gateway ✅ **active** · `.last-good` regenerado sin refs a nous
- Backup del config en `openclaw.json.bak-hermes-removal`
- **Pendiente del usuario**: el proxy blockrun (127.0.0.1:8402) no está corriendo — sin binario ni servicio systemd; hasta levantarlo, OpenClaw usará fallback ollama local

---

*Fin de la sesión — Última actualización: 2026-07-31*

---



# 🧠 SESION — Buffy Freebuff (2026-07-29 — segunda parte: memoria persistente + skill expandida)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎮 Skill scrcpy-freefire expandida

### Secciones agregadas a `.agents/skills/scrcpy-freefire/SKILL.md`

#### 🧪 Diagnóstico de lag
- Tabla para identificar tipo de lag (input vs video vs thermal vs game)
- Interpretación de `--print-fps`
- Comandos `adb shell dumpsys gfxinfo` y `dumpsys SurfaceFlinger`
- Tabla de trade-offs completa
- Procedimiento diagnóstico de 5 pasos (con verificación USB incluida)

#### 🔧 Alternativas de keymappers
- **Mantis Gamepad Pro**: Setup completo con Shizuku, recomendada
- **Panda Mouse Pro**: Alternativa ligera
- **Octopus**: Advertencia de ban para Free Fire
- Tabla comparativa (GG Mouse vs Mantis vs Panda vs Octopus)

#### 🔍 Troubleshooting detallado (expandido)
- UHID: cursor invisible/atrapado, teclado no funciona, teclas stuck
- Input desync después de alt+tab
- Wayland vs X11 — problemas y soluciones
- GG Mouse Pro 2 se desactiva solo (5 causas + soluciones)
- Lag al girar cámara en Free Fire
- Free Fire borroso
- Problemas de permisos Shizuku

### Detalles pulidos post-review
- Advertencia de input lag en `--render-expired-frames`
- Chequeo USB agregado al diagnóstico de 5 pasos
- Orden del reset drástico movido a último recurso

---

## 🧠 Sistema de memoria persistente

### Contexto inicial
El usuario ya tenía una carpeta `ai-context/` con archivos manualmente mantenidos:
- `INFO-core.md`, `INFO-full.md` — contexto de sistema
- `SNAPSHOT.md` — generado por `buffy-context.sh`
- `SESION.md` — bitácora manual de sesiones anteriores
- `PROJECTS.md`, `CHANGELOG.md`, `AGENTS.md`, etc.

### Problemas identificados
1. **Sin protocolo formal** — cada agente empezaba desde cero, no había un "cargar esto primero"
2. **No había handoff** — `CONTINUE.md` no existía
3. **`buffy-context.sh` hardcodeaba "Mango WM (Wayland)"** — el usuario corre bspwm X11
4. **`scripts/ai-context.sh`** generaba zips inútiles en vez de contexto estructurado
5. **SNAPSHOT.md** decía "WM: Mango WM (Wayland)" — información incorrecta

### Solución implementada

| Archivo | Cambio |
|---------|--------|
| `ai-context/LOAD_CONTEXT.md` | **NUEVO**: Protocolo para agentes — qué leer al inicio y qué escribir al cierre |
| `ai-context/CONTINUE.md` | **NUEVO**: Handoff entre sesiones — resumen, archivos tocados, pendientes, stack |
| `ai-context/SNAPSHOT.md` | ✅ Actualizado: WM corregido a bspwm, estado fresco del sistema |
| `ai-context/SESION.md` | ✅ Actualizado: esta entrada |
| `~/.local/bin/buffy-context.sh` | ✅ Fix: detección dinámica de WM vía `loginctl` |

### Cómo funciona

**Al inicio de cada sesión** (para cualquier agente):
1. Leer `INFO-core.md` — contexto base del sistema
2. Leer `SNAPSHOT.md` — estado vivo (procesos, RAM, proyectos)
3. Leer `CONTINUE.md` — de qué halar, qué pendientes hay

**Al cierre de cada sesión** (para cualquier agente):
1. Escribir `CONTINUE.md` — resumen de lo hecho
2. Actualizar `SNAPSHOT.md` si cambió el sistema
3. Actualizar `SESION.md` con bitácora detallada

---

*Fin de la sesión — Última actualización: 2026-07-29*

---



# 🧠 SESION — Buffy Freebuff (2026-07-29)

> Contexto de todo lo implementado durante esta sesión.

---

## 📦 Repo GitHub `buffy-context`

### Creación del repositorio
- **`~/buffy-context/`** creado con estructura: `ai-context/`, `Knowledge/`, `.agents/skills/`, `scripts/`
- Git init + push a `github.com/maneskinleon-del/buffy-context` (público)
- **MIT License** agregada
- **README.md** profesional con badges, estructura, quick start, uso con agentes IA
- **INSTALL.md** con instrucciones de setup
- **6 commits** en `main`

### Correcciones post-feedback del usuario
Basado en análisis crítico de 5 puntos:

1. **Carga condicional para 6 categorías** (antes solo Android):
   - LOAD_CONTEXT.md reescrito con señales de activación para React, Linux, Git, Node y Shell
   - Cada categoría con detección explícita (package.json, mención de tema, etc.)

2. **Presupuesto de tokens + poda automática**:
   - SESION.md: 720 → 81 líneas (archivado a SESION-archive.md)
   - CHANGELOG.md: 429 → 132 líneas (archivado a CHANGELOG-archive.md)
   - Headers de poda agregados a ambos archivos

3. **Redundancia eliminada**:
   - Sección "Jerarquía de contexto" (duplicada) eliminada de LOAD_CONTEXT.md

4. **SYSTEM.md/SYSTEM_FULL.md deprecados**:
   - Marcados DEPRECATED con redirect a INFO-core.md/INFO-full.md

5. **Primera sesión**:
   - LOAD_CONTEXT.md ahora dice qué hacer si CONTINUE.md no existe

## 📚 Base de conocimiento `Knowledge/`

16 archivos · 1,305 líneas · 6 categorías creadas:

| Categoría | Archivos | Contenido |
|-----------|----------|-----------|
| Android | 6 | ADB, Shizuku, HyperOS, GameOptimization, scrcpy, Keymappers |
| Linux | 2 | System (Arch/bspwm/systemd), Kernel |
| React | 4 | React+TS, Vite, Tailwind v4, PWA |
| Git | 1 | Commands + gh CLI |
| Node | 1 | npm, package.json |
| Shell | 1 | Bash/Zsh scripting |

## 🤖 Android Agent

- **Skill**: `.agents/skills/android-agent/SKILL.md` — detecta proyectos Android automáticamente
- **Script**: `.local/bin/android-detect.sh` — diagnóstico con `--quick` y `--watch`
- **Shizuku activado**: rish extraído del APK (Shizuku v13.7.0 corriendo en ZTE Nubia)
- **DPI cambiado**: vía Shizuku, 480 físico → 280 override
- **Free Fire diagnosticado**: CPU 0.8% (background), 13% jank sistema, temp 30.1°C

## 🔍 Code Search adapter

- **Skill portable**: `.agents/skills/code-search/SKILL.md` — funciona en Freebuff, Claude Code, Codex
- 3 modos de búsqueda: agente nativo → CLI (ripgrep) → exploración manual
- **search_criteria_v4**: skill de búsqueda estructurada copiada al repo

## 🎮 Skill scrcpy-freefire expandida

### Secciones agregadas a `.agents/skills/scrcpy-freefire/SKILL.md`

#### 🧪 Diagnóstico de lag
- Tabla para identificar tipo de lag (input vs video vs thermal vs game)
- Interpretación de `--print-fps`
- Comandos `adb shell dumpsys gfxinfo` y `dumpsys SurfaceFlinger`
- Tabla de trade-offs completa
- Procedimiento diagnóstico de 5 pasos (con verificación USB incluida)

#### 🔧 Alternativas de keymappers
- **Mantis Gamepad Pro**: Setup completo con Shizuku, recomendada
- **Panda Mouse Pro**: Alternativa ligera
- **Octopus**: Advertencia de ban para Free Fire
- Tabla comparativa (GG Mouse vs Mantis vs Panda vs Octopus)

#### 🔍 Troubleshooting detallado (expandido)
- UHID: cursor invisible/atrapado, teclado no funciona, teclas stuck
- Input desync después de alt+tab
- Wayland vs X11 — problemas y soluciones
- GG Mouse Pro 2 se desactiva solo (5 causas + soluciones)
- Lag al girar cámara en Free Fire
- Free Fire borroso
- Problemas de permisos Shizuku

### Detalles pulidos post-review
- Advertencia de input lag en `--render-expired-frames`
- Chequeo USB agregado al diagnóstico de 5 pasos
- Orden del reset drástico movido a último recurso

---

## 🧠 Sistema de memoria persistente

### Contexto inicial
El usuario ya tenía una carpeta `ai-context/` con archivos manualmente mantenidos:
- `INFO-core.md`, `INFO-full.md` — contexto de sistema
- `SNAPSHOT.md` — generado por `buffy-context.sh`
- `SESION.md` — bitácora manual de sesiones anteriores
- `PROJECTS.md`, `CHANGELOG.md`, `AGENTS.md`, etc.

### Problemas identificados
1. **Sin protocolo formal** — cada agente empezaba desde cero, no había un "cargar esto primero"
2. **No había handoff** — `CONTINUE.md` no existía
3. **`buffy-context.sh` hardcodeaba "Mango WM (Wayland)"** — el usuario corre bspwm X11
4. **`scripts/ai-context.sh`** generaba zips inútiles en vez de contexto estructurado
5. **SNAPSHOT.md** decía "WM: Mango WM (Wayland)" — información incorrecta

### Solución implementada

| Archivo | Cambio |
|---------|--------|
| `ai-context/LOAD_CONTEXT.md` | **NUEVO**: Protocolo para agentes — qué leer al inicio y qué escribir al cierre |
| `ai-context/CONTINUE.md` | **NUEVO**: Handoff entre sesiones — resumen, archivos tocados, pendientes, stack |
| `ai-context/SNAPSHOT.md` | ✅ Actualizado: WM corregido a bspwm, estado fresco del sistema |
| `ai-context/SESION.md` | ✅ Actualizado: esta entrada |
| `~/.local/bin/buffy-context.sh` | ✅ Fix: detección dinámica de WM vía `loginctl` |

### Cómo funciona

**Al inicio de cada sesión** (para cualquier agente):
1. Leer `INFO-core.md` — contexto base del sistema
2. Leer `SNAPSHOT.md` — estado vivo (procesos, RAM, proyectos)
3. Leer `CONTINUE.md` — de qué halar, qué pendientes hay

**Al cierre de cada sesión** (para cualquier agente):
1. Escribir `CONTINUE.md` — resumen de lo hecho
2. Actualizar `SNAPSHOT.md` si cambió el sistema
3. Actualizar `SESION.md` con bitácora detallada

---

*Fin de la sesión — Última actualización: 2026-07-29*

---



# 🧠 SESION — Buffy Freebuff (2026-07-26)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎨 Thunar — Iconografía Mac (WhiteSur) + Transparencia

### Problema
Thunar usaba iconos TokyoNight-SE (no Mac-style) y no tenía transparencia. El CSS existente estaba en `~/.config/gtk-4.0/` pero Thunar usa GTK3, no GTK4.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: Cambiado `gtk-icon-theme-name` de `TokyoNight-SE` a `WhiteSur` (global GTK3)
- **`~/.config/gtk-3.0/gtk.css`**: Creado con:
  - Fondos translúcidos `rgba()` con alpha
  - Glass effect en sidebar, statusbar, frame principal
  - Bordes redondeados (14px)
  - Acento verde #24BD5C
  - Animaciones suaves en hover/selected
- **`~/.config/bspwm/config/picom/picom-rules.conf`**: Agregada regla para `class_g='Thunar'`:
  - `blur-background = true`
  - `corner-radius = 10`
  - `fade = true`, `shadow = true`

### Lecciones
- `GTK_ICON_THEME` **no funciona** como env var en GTK3 (probado con Python GTK binding)
- La única forma de cambiar icon theme es vía `settings.ini` global o wrapper con `XDG_CONFIG_HOME`
- El `.desktop` file con `env` no afecta cuando Thunar se lanza desde sxhkd
- Se modificó `OpenApps` y luego se revirtió — la solución global `settings.ini` fue la definitiva

---

## 🔤 Alacritty — Tamaño de fuente reducido

- **`~/.config/alacritty/fonts.toml`**: `size = 14` → `size = 11`

---

## 🦊 Firefox — Fuente UI + Pestañas verticales

### Problema 1: Fuente monospace en UI
Firefox usaba `UbuntuMono Nerd Font 11` (monospace) para toda su interfaz GTK3: menús, URL bar, pestañas, etc.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: `gtk-font-name` cambiado de `UbuntuMono Nerd Font 11` a `Fira Sans Semi-Bold 11`

### Problema 2: Pestañas horizontales comprimidas
Muchas pestañas abiertas (IAs, proyectos) haciendo la tab strip ilegible.

### Solución
- **`~/.config/mozilla/firefox/pw5luhdq.default-release/user.js`**: Creado con:
  - `user_pref("sidebar.revamp", true);`
  - `user_pref("sidebar.verticalTabs", true);`
  - `user_pref("sidebar.visibility", "always-show");`
- El `user.js` es persistente — Firefox nunca lo sobrescribe (a diferencia de `prefs.js`)
- Nota: `sidebar.main.tools` en prefs.js está seteado a una extensión de terceros, podría interferir

### Notas técnicas
- Perfil Firefox encontrado en `~/.config/mozilla/firefox/` (ruta XDG), NO en `~/.mozilla/firefox/`
- Intentos fallidos previos: editar `prefs.js` directamente (Firefox lo sobrescribe al cerrar)
- Firefox 152.0.6-1

---

## 🎭 Playwright — Skill instalada

- **Skill**: `microsoft/playwright-cli@playwright-cli` instalada en `.agents/skills/playwright-cli`
- **CLI**: `@playwright/cli` instalado globalmente via npm
- **Browser**: Firefox 152.0.4 descargado para Playwright (~106MB) en `~/.cache/ms-playwright/firefox-1534`
- **Comandos básicos**: `playwright-cli open`, `goto`, `screenshot`, `close`, `click`, `fill`, `snapshot`

---

## 🔄 Alacritty → Foot → Revertido

### Intento
Se intentó reemplazar Alacritty por Foot como terminal principal del sistema.

### Cambios realizados (luego revertidos)
- `~/.config/bspwm/config/.term`: `alacritty` → `foot`
- `~/.config/bspwm/bin/Term`: Agregado case `foot` con `--app-id` para todos los modos
- `~/.config/bspwm/bin/Bspwm-ScratchPad`: Agregado case `foot` con `--app-id`
- `~/.config/geany/geany.conf`: `terminal_cmd` actualizado a `foot -e /bin/zsh %c`
- `~/.config/bspwm/config/modules/05-foot.sh`: **Creado** (módulo rice para foot)

### Causa del fallo
Foot es un emulador de terminal **nativo de Wayland**. No puede ejecutarse bajo X11:
```
err: wayland.c:1788: failed to connect to wayland; no compositor running?
```
El usuario corre bspwm (X11), por lo que foot no funciona.

### Resolución
Todos los cambios revertidos. Alacritty sigue siendo el terminal por defecto.

### Lecciones
- Foot solo funciona con compositores Wayland (Mango WM, Hyprland, etc.)
- `--app-id` es el equivalente Wayland de `--class` en X11
- El módulo `05-foot.sh` se dejó en disco por si en futuro se usa Wayland (actualmente inactivo)

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/gtk-3.0/settings.ini` | Icon theme: TokyoNight-SE → WhiteSur. Font: UbuntuMono → Fira Sans. Habilite animaciones |
| `~/.config/gtk-3.0/gtk.css` | **NUEVO**: Thunar GTK3 CSS con transparencia, glass effect, rounded corners |
| `~/.config/bspwm/config/picom/picom-rules.conf` | Regla Thunar con blur-background + corner-radius |
| `~/.config/alacritty/fonts.toml` | Font size 14 → 11 |
| `~/.local/share/applications/thunar.desktop` | **NUEVO** (creado, luego mantenido como backup) |
| `~/.config/mozilla/firefox/pw5luhdq.default-release/user.js` | **NUEVO**: Pestañas verticales Firefox |
| `~/.agents/skills/playwright-cli/` | **NUEVO**: Skill playwright-cli instalada |
| `~/.config/bspwm/config/modules/05-foot.sh` | **NUEVO**: Módulo rice para Foot (inactivo — Wayland-only) |
| `ai-context/CHANGELOG.md` | Actualizado con cambios de esta sesión |
| `ai-context/SESION.md` | Actualizado con el intento Foot + revert |

---

## 🪟 Alacritty — Transparencia (opacidad 0.85) + Fix picom

### Problema
Alacritty no mostraba transparencia. El valor `opacity = 0.85` se reiniciaba al abrir una nueva terminal.

### Causa raíz
1. **Picom no estaba corriendo** — sin compositor, Alacritty no puede mostrar transparencia bajo X11
2. **El módulo `05-alacritty.sh` sobreescribe la opacidad** en cada inicio de sesión de bspwm:
   - `sed -i "s|^opacity = .*|opacity = ${P_TERM_OPACITY}|" "$HOME/.config/alacritty/alacritty.toml"`
   - El valor `P_TERM_OPACITY` venía de `theme-config.bash`
3. **`P_TERM_OPACITY="0.98"`** en `rices/melissa/theme-config.bash` — casi opaco

### Solución
- **`rices/melissa/theme-config.bash`**: `P_TERM_OPACITY="0.98"` → `"0.85"`
- **`alacritty/alacritty.toml`**: `opacity = 0.98` → `0.85` (cambio directo)
- **Picom iniciado**: `picom -b` (no estaba corriendo)

### Lecciones
- Para cambios permanentes de transparencia, modificar `P_TERM_OPACITY` en `theme-config.bash`, NO directamente en `alacritty.toml`
- Siempre verificar `ps aux | grep picom` si la transparencia no se muestra
- El `05-alacritty.sh` se ejecuta vía Theme.sh → bspwmrc

---

## 🎨 Polybar — Esquema de colores completo (tema melissa)

### Cambios visuales

**Fondo de barras:**
- Antes: `#003b4252` (transparente — 00 alpha)
- Ahora: `#1e222a` (sólido oscuro, contrasta con el terminal transparente)

**Secciones coloreadas con acentos Nord:**

| Sección | Color | Hex |
|---------|-------|-----|
| CPU | Verde | `#a3be8c` |
| RAM | Cyan | `#88c0d0` |
| DISK | Amarillo | `#ebcb8b` |
| NET | Púrpura | `#b48ead` |
| KB/Teclado | Azul | `#81a1c1` |
| Workspace focused | Verde | `#a3be8c` |
| Workspace occupied | Cyan | `#88c0d0` |
| Volumen | Cyan | `#88c0d0` |
| Brillo | Ámbar | `#FBC02D` |
| Bluetooth | Azul | `#81a1c1` |
| Batería cargando | Verde | `#a3be8c` |
| Batería descargando | Amarillo | `#ebcb8b` |
| Icono música | Púrpura | `#b48ead` |
| Icono usuario | Amarillo | `#ebcb8b` |
| Icono power | Rojo | `#bf616a` |

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `rices/melissa/config.ini` | Colores globales: bg=#1e222a, bg-alt=#2e3440 |
| `rices/melissa/modules.ini` | Acentos Nord en cada módulo, iconos descomentados |
| `rices/melissa/theme-config.bash` | P_TERM_OPACITY=0.85 |
| `bspwm/eww/colors.scss` | Sincronizado con nueva paleta |

### Recarga de polybar
```bash
polybar-msg cmd quit
RICE=$(cat ~/.config/bspwm/.rice)
MONITOR=HDMI-1 polybar mel-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
MONITOR=HDMI-1 polybar mel2-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
```

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/rices/melissa/theme-config.bash` | P_TERM_OPACITY: 0.98 → 0.85 |
| `~/.config/alacritty/alacritty.toml` | opacity: 0.98 → 0.85 |
| `~/.config/bspwm/rices/melissa/config.ini` | Colores globales polybar rediseñados |
| `~/.config/bspwm/rices/melissa/modules.ini` | Acentos Nord en cada módulo |
| `~/.config/bspwm/eww/colors.scss` | Sincronizado con nueva paleta |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/SESION.md` | ✅ Actualizado |
| `ai-context/AGENTS.md` | ✅ Añadidas notas técnicas (picom, polybar) |
| `ai-context/SYSTEM.md` | ✅ Actualizado (rice melissa, picom) |
| `ai-context/SYSTEM_FULL.md` | ✅ Actualizado (referencias, terminales) |
| `ai-context/INFO-core.md` | ✅ Actualizado (sistema, proyectos) |
| `ai-context/INFO-full.md` | ✅ Actualizado (terminales, changelog) |

*Fin de la sesión — Última actualización: 2026-07-26*

---



# 🧠 SESION — Buffy Freebuff (2026-07-27)

> Contexto de todo lo implementado durante esta sesión.

---

## 🖥️ Fix resolución de pantalla (1360x768)

### Problema
La pantalla estaba en **1280x720** en vez de la especificada **1360x768@60.02**.

### Causa raíz
El script `MonitorSetup` (gh0stzk rice) ejecuta su propio `xrandr` después del que estaba en `bspwmrc`. `MonitorSetup` usa `get_monitor_info()` que agarra el **primer modo listado** por xrandr (1280x720 por ser el preferido), pisando la resolución configurada.

### Solución
- **`~/.config/bspwm/bspwmrc`**: Movido `xrandr --output HDMI-1 --mode 1360x768 --rate 60.02` **DESPUÉS** de `MonitorSetup` en vez de antes.
- Verificado con `bspc wm -r`: la resolución persiste correctamente.
- **Investigación completa**: Ningún otro script del rice melissa (todos los módulos, Theme.sh, Bar.bash, SetSysVars, ScreenLocker, AnimatedWall) toca xrandr. Solo MonitorSetup y nuestro fix en bspwmrc.

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/bspwmrc` | xrandr movido DESPUÉS de MonitorSetup |

---

## 🤖 codebuff-automation — Proyecto completo de automatización web

> Proyecto portado de Termux (Xiaomi Mi 10 / HyperOS) a PC de escritorio.
> Creado desde el archivo `~/Descargas/SETUP_PC_DESKTOP.md`.

### Estructura del proyecto (`~/codebuff-automation/`)

| Archivo | Descripción | Estado |
|---------|-------------|:------:|
| `fill_form.js` v4.0 | Script principal — Llenador universal de formularios | ✅ ~43KB |
| `auto_permiso.py` v2.0 | OCR + root para permisos Android | ✅ (root en vez de rish) |
| `mis-datos.json` | Datos de ejemplo (chilenos) | ✅ |
| `test-form.html` | Formulario de prueba con 21 campos | ✅ |
| `Dockerfile` | Imagen Docker para ejecución aislada | ✅ |
| `docker-compose.yml` | Orquestación Docker | ✅ |
| `docker-entrypoint.sh` | Entrypoint Docker | ✅ |
| `SETUP_PC_DESKTOP.md` | Documentación original | ✅ |
| `codebuff-memoria.md` | Memoria del proyecto | ✅ |
| `skills/` (5 skills) | Documentación de skills | ✅ |

### Dependencias instaladas
| Paquete | Versión | Propósito |
|---------|:-------:|-----------|
| puppeteer-core | 25.4.0 | Control de Chromium |
| puppeteer | 25.4.0 | (instalado como dependencia) |
| tesseract-data-spa | - | OCR español para auto_permiso.py |
| Chromium | 150 | Navegador del sistema (`/usr/bin/chromium`) |

### Features de fill_form.js v4.0
| Feature | Estado | Flags |
|---------|:------:|-------|
| SmartMapper multi-idioma (28 categorías) | ✅ | — |
| CAPTCHA support (2captcha) | ✅ | `--captcha-api-key` |
| Proxy rotativo (3 estrategias) | ✅ | `--proxy`, `--proxy-list` |
| Modo entrenamiento | ✅ | `--train` |
| Webhook notifications (Slack/Discord) | ✅ | `--webhook-url` |
| Sesiones persistentes (cookies+storage) | ✅ | `--session` |
| iframe support vía frameMap | ✅ | — |
| Retry logic (backoff exponencial) | ✅ | — |
| Export JSON (ResultsTracker) | ✅ | `--export` |
| Slow mode human-like | ✅ | `--slow` |
| Modo interactivo | ✅ | `--interactive` |
| Screenshots automáticos | ✅ | `--screenshot` |
| Dockerización | ✅ | Dockerfile + compose |

### Bugs corregidos durante implementación
1. **`os` import antes de uso**: Movido `require('os')` al principio del archivo
2. **iframe field filling**: Creado `frameMap` con `Map<string, Frame>` para lookup confiable en vez de `frame._id` (interno de Puppeteer)
3. **Dead code removal**: Eliminadas funciones `clearAndTypeInFrame`, `selectOptionInFrame`, `setCheckboxInFrame`, `typeWithDelay` (reemplazadas por `fillFieldOnFrame` genérica)
4. **`frameCounter` global**: Cambiado a `localFrameCounter` dentro de `detectFormFieldsInFrames`
5. **`confirm_password` faltante**: Agregado a `DEFAULT_DATA` con el mismo valor que `password`

### Test results (contra test-form.html local)
```
📋 21 campo(s) detectado(s)
✅ Llenados: 17
❌ Fallidos: 0
⏭️ Omitidos: 4 (confirm_password + 3 radios)
⏱ Duración: 13s
```

### Radios del test-form.html — Fix
Se arregló la estructura HTML de los radios (sección "Tipo de perfil"):
- Agregados `id` únicos (`profile_dropshipper`, `profile_proveedor`, `profile_ambos`)
- Labels separados con `for` en vez de inputs envueltos en `<label>`
- Opciones envueltas en `<span class="radio-option">` para flex layout correcto
- `role="radiogroup"` y `aria-label="Tipo de perfil"`
- CSS: `.radio-option { display: inline-flex; }` + labels `display: inline`

### auto_permiso.py — Migración de rish a root
- Cambiado de `adb shell /data/local/tmp/rish -c "cmd"` a `adb shell su -c "cmd"`
- Eliminadas todas las referencias a `rish_cmd` y `PRIV_MODE`
- Comandos `pm grant` correctos para root
- `check_root()` sin `check=True` para evitar crash si ADB no está conectado

---

## 🦙 Ollama — Instalación y modelo cloud

### Instalación
Ollama **0.30.7** ya estaba instalado (`/usr/local/bin/ollama` + pacman `0.32.1-1`).

### Modelo descargado
- **`nemotron-3-super:cloud`** — Modelo cloud de Nvidia (120B params, MoE)
- El tag `:cloud` significa que corre en servidores de Ollama, no local
- **No ocupa RAM/CPU local** (solo ~345B de stub)
- **Requiere cuenta en Ollama** para usar: `ollama signin`
- **Tier Free disponible** con límites de uso ligero

### Pendiente
- Crear cuenta en ollama.com (el usuario decidirá más adelante)
- Integrar Ollama en fill_form.js (clasificación de campos vía IA)

---

## 📁 Archivos modificados/creados (sesión 2026-07-27)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/bspwmrc` | Fix resolución: xrandr después de MonitorSetup |

### Proyecto codebuff-automation
| Archivo | Cambio |
|---------|--------|
| `~/codebuff-automation/fill_form.js` | **NUEVO**: v4.0 completo (~43KB) |
| `~/codebuff-automation/auto_permiso.py` | **NUEVO**: v2.0 con root en vez de rish |
| `~/codebuff-automation/mis-datos.json` | **NUEVO**: Datos de ejemplo |
| `~/codebuff-automation/test-form.html` | **NUEVO**: 21 campos + fix radios |
| `~/codebuff-automation/Dockerfile` | **NUEVO**: Imagen Docker |
| `~/codebuff-automation/docker-compose.yml` | **NUEVO**: Orquestación |
| `~/codebuff-automation/docker-entrypoint.sh` | **NUEVO**: Entrypoint |
| `~/codebuff-automation/SETUP_PC_DESKTOP.md` | Copiado desde Descargas |
| `~/codebuff-automation/codebuff-memoria.md` | **NUEVO**: Memoria del proyecto |
| `~/codebuff-automation/skills/form-filler.md` | **NUEVO**: Skill form filler |
| `~/codebuff-automation/skills/image-analyzer.md` | **NUEVO**: Skill OCR |
| `~/codebuff-automation/skills/hyperos-hardening.md` | **NUEVO**: Skill HyperOS |
| `~/codebuff-automation/skills/xiaomi-adb-tricks.md` | **NUEVO**: Skill ADB (root) |
| `~/codebuff-automation/skills/shizuku-rikka.md` | **NUEVO**: Skill Shizuku (legacy) |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (esta entrada) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/PROJECTS.md` | ✅ codebuff-automation agregado |
| `ai-context/SYSTEM.md` | ✅ Ollama + nuevo proyecto |
| `ai-context/SNAPSHOT.md` | ✅ Regenerado |

---

## 🦙 Qwen2.5 7B — Modelo local instalado + systemd service

### Modelo descargado
- **`qwen2.5:7b`** (4.7 GB) — Modelo local de Alibaba (7B params, Q4_K_M)
- Corre 100% en CPU (no ROCm disponible para la Vega 11 integrada)
- Velocidad: ~24s primer token (carga inicial), respuestas rápidas después
- **No requiere internet** — todo local, privado y sin límites

### Sistema de servicio (systemd --user)
- Creado `~/.config/systemd/user/ollama.service`:
  - `Type=simple`, `ExecStart=/usr/bin/ollama serve`
  - `Restart=on-failure` con `RestartSec=3`
  - Habilitado (`systemctl --user enable`) e iniciado
  - Se auto-arranca al iniciar sesión

### Estado actual
| Componente | Estado |
|-----------|--------|
| Ollama service | ✅ Activo (systemd --user) |
| qwen2.5:7b | ✅ Descargado (4.7 GB) |
| nemotron-3-super:cloud | ✅ Stub cloud (345B) |
| API local | ✅ Responde en localhost:11434 |
| CLI `ollama run` | ❌ Timeout (bug conocido, usar API) |

### Nota técnica
`ollama run` tiene un bug que causa timeout en este entorno. Usar siempre la API directa:
```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:7b","prompt":"tu pregunta aquí","stream":false}'
```

### Pendiente
- Integrar Ollama en fill_form.js (usar qwen2.5:7b en vez de nemotron cloud)

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — segunda parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.config/systemd/user/ollama.service` | **NUEVO**: Servicio systemd para Ollama |

### Modelos Ollama
| Archivo/Modelo | Cambio |
|----------------|--------|
| `qwen2.5:7b` | **NUEVO**: Descargado (4.7 GB, CPU-only) |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (Qwen2.5 + systemd) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/SYSTEM.md` | ✅ Actualizado |

---

## 🦀 OpenClaw — Instalación y configuración

### Instalación
- **OpenClaw 2026.7.1-2** instalado globalmente via npm
- Gateway configurado en modo `local`, puerto `18789`
- Systemd user service creado: `openclaw-gateway.service` ✅ Activo

### Configuración de modelos
| Proveedor | Modelo primario | Rol |
|-----------|----------------|:---:|
| **kimchi** | `deepseek-v4-flash` | 🎯 Principal |
| **kimchi** | `nemotron-3-ultra-fp4` | 🔄 Fallback 1 |
| **ollama local** | `qwen2.5:7b` | 🔄 Fallback 2 |
| **kimchi** | `qwen2.5-coder:7b` | 🔄 Fallback 3 |

### Skills activas
- Habilidades no esenciales desactivadas (26) por `doctor --fix`
- Autocompletado zsh instalado
- Systemd lingering habilitado para el usuario

### vs Hermes
| Aspecto | OpenClaw | Hermes |
|---------|:--------:|:------:|
| Tamaño | ~12K (config) | 1.9 GB |
| Modelo default | deepseek-v4-flash ✅ | nemotron-3-super:cloud ❌ timeout |
| Provider activo | Kimchi API ✅ | nous (incierto) |
| Gateway | ✅ systemd, running | ❌ No tenía |
| Ollama local | ✅ Configurado | ❌ Solo cloud |

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — tercera parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.openclaw/openclaw.json` | ✅ Actualizado: Ollama provider + deepseek-v4-flash como primary |
| `~/.config/systemd/user/openclaw-gateway.service` | **NUEVO**: Servicio systemd para OpenClaw |
| Paquete npm global | `openclaw@2026.7.1-2` instalado |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (OpenClaw) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |

---

## 🎮 scrcpy-freefire.sh — Script multi-dispositivo para Free Fire

### Refactor completo
- **Auto-detección**: Detecta dispositivo ADB conectado y plataforma (kona=Qualcomm, ums=Unisoc)
- **Encoder automático**: `OMX.qcom.video.encoder.avc` para Mi 10 (Snapdragon 865), `c2.unisoc.avc.encoder` para ZTE nubia Neo 2 (Unisoc T820)
- **Resolución**: Mi 10 usa nativa (sin cambios). ZTE usa 2400x600 estirada
- **DPI**: Mi 10 usa nativo (440). ZTE usa 90
- **Regla bspwm**: scrcpy se abre en escritorio 6 (games) con `bspc rule -a scrcpy desktop='^6'`

### Problemas resueltos
- **Encoder incorrecto**: Se cambió `c2.qti.avc.encoder` (inexistente) a `OMX.qcom.video.encoder.avc`
- **Ghost touches al cargar**: Se desactivó `charging_optimization = 0` vía ADB para el Mi 10
- **Ventana incorrecta**: Se agregó regla bspwm para escritorio 6
- **pkill genérico**: Ahora mata cualquier instancia de scrcpy con `--video-encoder=`

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | Refactor completo multi-dispositivo |

### Pendiente
- Calibrar ggMouse para Mi 10 (sensibilidad y botones)
- Script AutoJS para lectura de botones de Free Fire

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — cuarta parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | ✅ Refactor multi-dispositivo (Mi 10 + ZTE) |
| ADB setting | `charging_optimization = 0` en Mi 10 |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (scrcpy + ghost touch) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |

---

## 🪟 Mango-KWin — KWin como WM minimalista con estética mango

### Contexto
El usuario quería instalar KDE Plasma pero **sin el shell de escritorio tradicional** (paneles, taskbar, etc.).
La idea era usar **KWin como gestor de ventanas** (Wayland) manteniendo la misma estética visual
minimalista de su setup actual (bspwm/mango): colores oscuros Catppuccin Mocha (#181825 bg, #CDD6F4 fg),
barra eww/waybar, lanzador rofi, terminal kitty/alacritty.

### Paquetes instalados
| Paquete | Versión | Tamaño | Propósito |
|---------|:-------:|:------:|-----------|
| `kwin` | 6.7.3-1 | 10.6 MB | WM/Compositor Wayland + X11 |
| `plasma-workspace` | 6.7.3-1 | 21.1 MB | Infraestructura de sesión |
| `kwin-x11` | 6.7.3-1 | — | Soporte X11 para KWin |
| `kde-cli-tools` | — | — | Herramientas CLI KDE |
| `polkit-kde-agent` | — | — | Diálogos de autenticación |
| `kglobalacceld` | — | — | Atajos globales de teclado |
| `xdg-desktop-portal-kde` | — | — | Portal Wayland (screenshare, flatpak) |
| **Total** | | **~80 MB** | |

### Archivos creados

**1. Script de sesión — `~/.local/bin/mango-kwin-session`**

Lanza KWin como compositor Wayland sin el shell de Plasma. Incluye:
- Variables de entorno: `XDG_CURRENT_DESKTOP=mango-kwin:KDE`, `XDG_SESSION_TYPE=wayland`
- Activación de `graphical-session.target` de systemd (compatibilidad Wayland)
- Arranque de servicios KDE esenciales: `kglobalacceld`, `kded6`, `polkit-kde-agent`
- Detección automática de barra: eww (prueba nombres: bar/shell/panel/main) → waybar
- Fallback X11 vía `KWIN_BACKEND=x11` (lanza `kwin_x11` en vez de `kwin_wayland`)
- Wait loop con `pidof` en vez de `sleep` para sincronizar servicios

**2. Entrada SDDM — `/usr/share/wayland-sessions/mango-kwin.desktop`**
```ini
Name=Mango-KWin
DesktopNames=mango-kwin;KDE
Comment=KWin como WM minimalista con estética mango
Exec=/home/mangonz/.local/bin/mango-kwin-session
```

**3. Configuración de KWin — `~/.config/kwinrc`**
| Sección | Valor | Efecto |
|---------|:-----:|--------|
| `[Desktops]` | `Number=6, Rows=2` | 6 workspaces en grid 3×2 |
| `[Compositing]` | `Backend=OpenGL, Enabled=true` | Composición GPU |
| `[Window-Decoration]` | `BorderlessMaximizedWindows=true` | Sin título al maximizar |
| `[Windows]` | `FocusPolicy=ClickToFocus, Placement=Centered` | Foco al click, ventanas centradas |
| `[Plugins]` | `kwin4_effect_tilingEnabled=true` | Tiling nativo de KWin activado |
| `[Plugins]` | `kwin4_effect_blurEnabled=true` | Blur en ventanas |
| `[Plugins]` | `kwin4_effect_wobblywindowsEnabled=true` | Efecto wobbly al mover |
| `[Translucency]` | `MoveResize=90` | Transparencia al mover/redimensionar |

**4. Atajos de teclado — `~/.config/kglobalshortcutsrc`**

Estilo bspwm, configurados via `kwriteconfig6`:

| Tecla | Acción |
|-------|--------|
| `Meta + Enter` | Terminal (kitty) |
| `Meta + Space` | Launcher (rofi -show drun) |
| `Meta + Q` | Cerrar ventana |
| `Meta + Shift + Q` | Matar ventana (force kill) |
| `Meta + F` | Fullscreen |
| `Meta + M` | Maximizar (monocle toggle) |
| `Meta + D` | Quitar/poner bordes |
| `Meta + H/J/K/L` | Quick tile izquierda/abajo/arriba/derecha |
| `Meta + Alt + H/J/K/L` | Navegar entre ventanas por dirección |
| `Meta + 1-6` | Cambiar a workspace 1-6 |
| `Meta + Shift + 1-6` | Mover ventana a workspace 1-6 |

### Notas técnicas
- **KWin vs bspwm**: KWin no es un tiling WM puro como bspwm, usa quick-tiling por defecto.
  Para tiling automático tipo bspwm, instalar el script "KWin Tiling" desde `systemsettings`
  o vía `kpackagetool6`.
- **`kwin_x11 --replace`**: En el fallback X11, `--replace` espera un WM existente. En sesión
  limpia (SDDM), se usa sin `--replace`.
- **Screen locker**: `--no-lockscreen` desactiva el bloqueo de pantalla. Si se necesita,
  instalar `kscreenlocker` o `physlock`.
- **Window rules**: Para apps en modo flotante (diálogos, popups), crear `~/.config/kwinrulesrc`
  o configurar desde `kwin_rules_dialog`.

### Archivos creados/modificados
| Archivo | Cambio |
|---------|--------|
| `~/.local/bin/mango-kwin-session` | **NUEVO**: Script de sesión minimalista |
| `/usr/share/wayland-sessions/mango-kwin.desktop` | **NUEVO**: Entrada SDDM |
| `~/.config/kwinrc` | **NUEVO**: KWin config (6 desktops, blur, tiling, sin bordes) |
| `~/.config/kglobalshortcutsrc` | **NUEVO**: Shortcuts estilo bspwm |

### Sesiones disponibles en SDDM ahora
- `mango` (original, Wayland)
- `mango-kwin` (KWin como WM, Wayland)
- `plasma` (KDE Plasma completo, Wayland)
- `bspwm` (X11)

---

## 🎮 scrcpy-freefire.sh — Configuración de Pantalla Alargada y ggmouse (Panda Mouse Pro)

### Resumen de la sesión (2026-07-29)

1. **Protocolo Operativo Activo**:
   - Se estableció la skill `modo-autonomo` como la principal regla operativa para el agente (diagnóstico directo por terminal, autonomía en decisiones técnicas, ejecución y verificación sin delegación innecesaria al usuario).

2. **Refactor y Ajustes en `scrcpy-freefire.sh`**:
   - **Pantalla Alargada / Estirada**: Configuración mediante ADB (`wm size 2400x600`, `wm density 280`, `user_rotation 1`) para vista ultra-wide estirada.
   - **Integración ggmouse (Panda Mouse Pro - `com.panda.widgetcove`)**:
     - Otorgados permisos `SYSTEM_ALERT_WINDOW`, `GET_USAGE_STATS` y `PROJECT_MEDIA` vía `appops`.
     - Inicio automático del servicio/pantalla de ggmouse previo a Free Fire.
   - **Juego Directo en Teléfono**:
     - Removido `--turn-screen-off` y configurado `--stay-awake` en `scrcpy` para permitir jugar usando la pantalla del celular mientras se espeja en la PC.
     - Lanzamiento directo de Free Fire (`com.dts.freefireth`).

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | ✅ Soporte pantalla alargada, ggmouse (Panda Mouse Pro), prevención de doze y modo UHID con `--mouse-bind=++++:++++` para control total desde PC |

| `~/.openclaw/workspace/scripts/scrcpy-freefire.sh` | ✅ Sincronizado |
| `ai-context/SESION.md` | ✅ Actualizado |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |


---




---

# 🧠 SESION — Buffy Freebuff (2026-08-05)

> Contexto de todo lo implementado durante esta sesión.

---

## 🚗 data_car — Fixes de extracción MG 350 (commit 6b3e352, pusheado)

### Bug crítico resuelto — transmission_oil "18. L" → "2 L"
La keyword `/transmisi[oó]n\s*[:：]/` **no tenía el flag `/i`**. El manual usa "**T**ransmisión:" con mayúscula (p.75: "Transmisión: Llene Relleno seca **2 L** 2,2"), así que el regex case-sensitive nunca matcheaba → la regla caía en el patrón laxo que capturaba el "18. L" de una tabla de tornillería (p.398). Fue el único `fieldKeyword` de las 16 reglas sin `/i` (verificado por charCodes con script de debug). Fix: flag `/i` + patrón estricto `(\d+(?:[.,]\d+)?)` que rechaza números truncados tipo "18. L" sin perder "2,9 l" → **"2 L" @80% p.75**.

### Otras reglas arregladas (evidencia del manual)
- **`wheel_torque`** → "115-130 Nm" @65% p.517 (keywords `tornillos? de rueda`/`pernos? de rueda`/`wheel bolt` + lookahead anti "rueda dentada") + mapeo nuevo `→ torqueTornillos` en specsSync.
- **`compression`** → renombrada "Relación de Compresión": el manual publica "Índice de compresión 10.5: 1" (p.79), no psi. Patrón de ratio + bonus de confianza +0.3 por formato → **"10.5: 1" @65%**.
- **`valve_clearance`** → keyword `/v[aá·]lvulas?:/i` tolera el á corrupto (·) → "8.2 mm" @80% p.83.
- **`tire_size`** → keyword "tamaño" agregada → "205/55 R16" @60% p.598.
- **`normalizeText`** → mapea caracteres corruptos del text-layer (í→Ì, é→È, ú→˙, ñ→Ò) → desbloquea brake_fluid (DOT4), oil_filter (BLT200010), air_filter (FN745).
- **Datos ausentes (no extraíbles)**: `tire_pressure` (solo TPMS sin valores; los 93-123 kPa son tapa del radiador) y `brake_pad` (sin espesor mm). No hay correa: el MG 350 usa **cadena** de distribución sin intervalo publicado.

### Resultado verificado
Cobertura **83%** · 12 componentes con datos · **7 campos sincronizados**: aceiteMotor=4,5 l · aceiteCaja=**2 L** · refrigerante=7.3 L · bujias=0,9 mm · dimensionNeumaticos=205/55 R16 · capacidadEstanque=55 L · torqueTornillos=115-130 Nm. Lint EXIT 0 + build ✅. Push `89f74cf..6b3e352 main -> main` ✅.

---

## 🧠 Freebuff — "temporarily busy" (429, modo limited) investigado + wrapper `fb-wait`

### Causa raíz (binario `~/.config/manicode/freebuff`, v0.0.138)
El mensaje `_qH = "Freebuff is temporarily busy. Please try again in a moment."` se dispara **solo con HTTP 429**: `QqH(H) { if (A.statusCode !== 429) return null; ... }`. Niveles de espera hardcodeados (sin config editable — no hay `settings.json` ni env `CODEBUFF_*` para esto):
- Cliente HTTP: `MB$ = {maxRetries:3, initialDelayMs:1000, maxDelayMs:1e4}` (retryable: 408/429/500/502/503/504).
- SDK AI: `maxRetries:2` + respeta `Retry-After` (cap 60s o backoff).
- Polling sesión free: `G4$ = 30000` (30s) + backoff `nl()` exponencial con **cap 300000ms (5 min)**; respeta `Retry-After` del servidor.

Freebuff es TUI interactiva pura (solo acepta `login` como subcomando; sin modo one-shot con prompt). El mensaje aparece cuando los 2-3 reintentos rápidos se agotan; no hay loop "esperar 5 min y reintentar solo".

### Solución — `~/.local/bin/fb-wait` (NUEVO, en PATH)
Launcher de guardia que lanza Freebuff y, al salir, revisa la **cola** (tail 8KB) del `log.jsonl` de la sesión más reciente (ordenada por **mtime real** vía `find -printf '%T@'`, no por nombre — bug inicial de `sort -r` corregido). Si detecta 429 busy → espera `FB_WAIT_MIN` (default 5 min) → relanza con `--continue` (retoma la conversación) hasta `FB_MAX_RETRIES` (default 10).
- Ctrl+C **con** busy reciente → reintenta (caso más común, corregido tras code review); Ctrl+C/error genérico **sin** busy → sale sin reintentar.
- Valida env vars numéricas (`FB_WAIT_MIN=abc` → error claro). Alcance documentado: no reintenta el prompt en vivo (la TUI no termina al ver busy); automatiza "salir → esperar → relanzar".
- Probado con mocks (5 escenarios: busy→ok, ctrl-c con/sin busy, error genérico, env inválido) ✅.

---

## 🚗 data_car — Sync Base Técnica → Ficha del vehículo (commit 89f74cf)

### Contexto
Sesión retomada tras un reinicio (combinación de teclas bloqueó el teclado). El WIP de la sesión anterior sobrevivió en disco pero no estaba commiteado; el último commit (`2bb0bb7`) sí estaba pusheado.

### Cambios commiteados y pusheados (`89f74cf`, 6 archivos, +592/-175)
- **`src/lib/specsSync.ts`** (NUEVO): puente Base Técnica → ficha. Solo sincroniza datos con confianza ≥ 0.5. Auto-sync (`force=false`) llena solo campos vacíos; botón "Sincronizar ficha" (`force=true`) sobreescribe. Toasts con etiquetas legibles.
- **`src/lib/technicalExtractor.ts` (v2 — cobertura honesta)**:
  - Confianza parte en 0 y suma solo por evidencia: unidad (+0.3), cercanía keyword ≤180 chars (+0.25/0.15/0.1), sección que matchea la regla (+0.2), formato especificación (+0.15), formato parte (+0.2), formato neumático (+0.35), keyword en ventana (+0.1).
  - Cada candidato trackea `page` + `section` del manual (procedencia).
  - Se descartan matches sin keyword cerca y candidatos con confianza < 0.3.
  - Componentes solo con ≥1 dato llenado; cobertura = reglas requeridas con datos reales.
  - `buildDatabase()` cacheada; `searchComponent` usa la cache.
- **`src/components/TechnicalDatabase.tsx`**: extracción por páginas (`pdfPages`), auto-sync al montar (bases construidas antes del sync), cobertura por sistema = llenados/reglas (`SYSTEM_RULE_COUNTS`), invalida `extractorRef` al cambiar PDF, botón "Sincronizar ficha".
- **`src/App.tsx`**: merge `{...defaults, ...saved}` al cargar specs (campos nuevos no quedan `undefined` → inputs no controlados).
- **`src/components/SpecForm.tsx`**: nuevos campos aceite caja, refrigerante, líquido frenos, bujías; panel "Electrónica & Luz" → "Sistemas y Líquidos".
- **`src/types.ts`**: eliminado campo `alfombra`.

### Validación
`npm run lint` (tsc --noEmit) ✅ · `npm run build` ✅ · push por SSH `2bb0bb7..89f74cf main -> main` ✅ · HEAD == origin/main ✅

---

## 🧠 Freebuff — Por qué las sesiones arrancaban sin contexto (resuelto)

### Causa raíz
Freebuff es el cliente de Codebuff (binario Bun en `~/.config/manicode/freebuff` v0.0.138, repo privado `CodebuffAI/freebuff-private`). Al iniciar sesión **auto-inyecta** en el prompt del sistema los archivos llamados exactamente:
- `AGENTS.md`, `CLAUDE.md`, `knowledge.md` / `*.knowledge.md` (en el proyecto)
- `~/.AGENTS.md`, `~/.CLAUDE.md`, `~/.knowledge.md` (globales del usuario, solo lectura)

Evidencia: binario (lista `["knowledge.md","AGENTS.md","CLAUDE.md"]` + plantilla `{CODEBUFF_KNOWLEDGE_FILES_CONTENTS}`) y docs oficiales codebuff.com/docs ("Codebuff will also read these files").

El archivo del usuario se llamaba **`AGENTS-root.md`** → no matcheaba ningún nombre reconocido → **cero knowledge files cargados** → el agente arrancaba sin memoria (aunque `ai-context/` estaba intacta).

### Solución
- Creado **`~/.AGENTS.md`** = copia de `AGENTS-root.md` (825 B). Se carga en TODA sesión, sin importar el proyecto. Apunta al protocolo: leer `ai-context/INFO-core.md` → `SNAPSHOT.md` → `CONTINUE.md`.
- `~/.AGENTS.md` es de solo lectura para el agente (fuera del proyecto) — los cambios se hacen en `AGENTS-root.md` y se re-copian.

### Lecciones
- El nombre del archivo importa: `AGENTS-root.md` ≠ `AGENTS.md` para la auto-carga.
- Los knowledge files se inyectan completos al prompt → mantenerlos livianos (puntero, no memoria entera).
- Complemento: `freebuff --continue` retoma la conversación anterior (historial en `~/.config/manicode/message-history.json`).

---

## 📁 Archivos modificados/creados (sesión 2026-08-05)

| Archivo | Cambio |
|---------|--------|
| `~/data_car/` (6 archivos) | commit `89f74cf` — sync Base Técnica → ficha + cobertura honesta |
| `~/.AGENTS.md` | **NUEVO** — auto-carga global de contexto en Freebuff |
| `ai-context/CONTINUE.md` | ✅ Regenerado (handoff 2026-08-05) |
| `ai-context/SESION.md` | ✅ Esta entrada |

---



# 🧠 SESION — Buffy Freebuff (2026-07-26)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎨 Thunar — Iconografía Mac (WhiteSur) + Transparencia

### Problema
Thunar usaba iconos TokyoNight-SE (no Mac-style) y no tenía transparencia. El CSS existente estaba en `~/.config/gtk-4.0/` pero Thunar usa GTK3, no GTK4.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: Cambiado `gtk-icon-theme-name` de `TokyoNight-SE` a `WhiteSur` (global GTK3)
- **`~/.config/gtk-3.0/gtk.css`**: Creado con:
  - Fondos translúcidos `rgba()` con alpha
  - Glass effect en sidebar, statusbar, frame principal
  - Bordes redondeados (14px)
  - Acento verde #24BD5C
  - Animaciones suaves en hover/selected
- **`~/.config/bspwm/config/picom/picom-rules.conf`**: Agregada regla para `class_g='Thunar'`:
  - `blur-background = true`
  - `corner-radius = 10`
  - `fade = true`, `shadow = true`

### Lecciones
- `GTK_ICON_THEME` **no funciona** como env var en GTK3 (probado con Python GTK binding)
- La única forma de cambiar icon theme es vía `settings.ini` global o wrapper con `XDG_CONFIG_HOME`
- El `.desktop` file con `env` no afecta cuando Thunar se lanza desde sxhkd
- Se modificó `OpenApps` y luego se revirtió — la solución global `settings.ini` fue la definitiva

---

## 🔤 Alacritty — Tamaño de fuente reducido

- **`~/.config/alacritty/fonts.toml`**: `size = 14` → `size = 11`

---

## 🦊 Firefox — Fuente UI + Pestañas verticales

### Problema 1: Fuente monospace en UI
Firefox usaba `UbuntuMono Nerd Font 11` (monospace) para toda su interfaz GTK3: menús, URL bar, pestañas, etc.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: `gtk-font-name` cambiado de `UbuntuMono Nerd Font 11` a `Fira Sans Semi-Bold 11`

### Problema 2: Pestañas horizontales comprimidas
Muchas pestañas abiertas (IAs, proyectos) haciendo la tab strip ilegible.

### Solución
- **`~/.config/mozilla/firefox/pw5luhdq.default-release/user.js`**: Creado con:
  - `user_pref("sidebar.revamp", true);`
  - `user_pref("sidebar.verticalTabs", true);`
  - `user_pref("sidebar.visibility", "always-show");`
- El `user.js` es persistente — Firefox nunca lo sobrescribe (a diferencia de `prefs.js`)
- Nota: `sidebar.main.tools` en prefs.js está seteado a una extensión de terceros, podría interferir

### Notas técnicas
- Perfil Firefox encontrado en `~/.config/mozilla/firefox/` (ruta XDG), NO en `~/.mozilla/firefox/`
- Intentos fallidos previos: editar `prefs.js` directamente (Firefox lo sobrescribe al cerrar)
- Firefox 152.0.6-1

---

## 🎭 Playwright — Skill instalada

- **Skill**: `microsoft/playwright-cli@playwright-cli` instalada vía `npx skills add` (carpeta playwright-cli en `~/.agents/skills/`)
- **CLI**: `@playwright/cli` instalado globalmente via npm
- **Browser**: Firefox 152.0.4 descargado para Playwright (~106MB) en `~/.cache/ms-playwright/firefox-1534`
- **Comandos básicos**: `playwright-cli open`, `goto`, `screenshot`, `close`, `click`, `fill`, `snapshot`

---

## 🔄 Alacritty → Foot → Revertido

### Intento
Se intentó reemplazar Alacritty por Foot como terminal principal del sistema.

### Cambios realizados (luego revertidos)
- `~/.config/bspwm/config/.term`: `alacritty` → `foot`
- `~/.config/bspwm/bin/Term`: Agregado case `foot` con `--app-id` para todos los modos
- `~/.config/bspwm/bin/Bspwm-ScratchPad`: Agregado case `foot` con `--app-id`
- `~/.config/geany/geany.conf`: `terminal_cmd` actualizado a `foot -e /bin/zsh %c`
- `~/.config/bspwm/config/modules/05-foot.sh`: **Creado** (módulo rice para foot)

### Causa del fallo
Foot es un emulador de terminal **nativo de Wayland**. No puede ejecutarse bajo X11:
```
err: wayland.c:1788: failed to connect to wayland; no compositor running?
```
El usuario corre bspwm (X11), por lo que foot no funciona.

### Resolución
Todos los cambios revertidos. Alacritty sigue siendo el terminal por defecto.

### Lecciones
- Foot solo funciona con compositores Wayland (Mango WM, Hyprland, etc.)
- `--app-id` es el equivalente Wayland de `--class` en X11
- El módulo `05-foot.sh` se dejó en disco por si en futuro se usa Wayland (actualmente inactivo)

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/gtk-3.0/settings.ini` | Icon theme: TokyoNight-SE → WhiteSur. Font: UbuntuMono → Fira Sans. Habilite animaciones |
| `~/.config/gtk-3.0/gtk.css` | **NUEVO**: Thunar GTK3 CSS con transparencia, glass effect, rounded corners |
| `~/.config/bspwm/config/picom/picom-rules.conf` | Regla Thunar con blur-background + corner-radius |
| `~/.config/alacritty/fonts.toml` | Font size 14 → 11 |
| `~/.local/share/applications/thunar.desktop` | **NUEVO** (creado, luego mantenido como backup) |
| `~/.config/mozilla/firefox/pw5luhdq.default-release/user.js` | **NUEVO**: Pestañas verticales Firefox |
| `~/.agents/skills/` (carpeta playwright-cli) | **NUEVO**: Skill playwright-cli instalada |
| `~/.config/bspwm/config/modules/05-foot.sh` | **NUEVO**: Módulo rice para Foot (inactivo — Wayland-only) |
| `ai-context/CHANGELOG.md` | Actualizado con cambios de esta sesión |
| `ai-context/SESION.md` | Actualizado con el intento Foot + revert |

---

## 🪟 Alacritty — Transparencia (opacidad 0.85) + Fix picom

### Problema
Alacritty no mostraba transparencia. El valor `opacity = 0.85` se reiniciaba al abrir una nueva terminal.

### Causa raíz
1. **Picom no estaba corriendo** — sin compositor, Alacritty no puede mostrar transparencia bajo X11
2. **El módulo `05-alacritty.sh` sobreescribe la opacidad** en cada inicio de sesión de bspwm:
   - `sed -i "s|^opacity = .*|opacity = ${P_TERM_OPACITY}|" "$HOME/.config/alacritty/alacritty.toml"`
   - El valor `P_TERM_OPACITY` venía de `theme-config.bash`
3. **`P_TERM_OPACITY="0.98"`** en `rices/melissa/theme-config.bash` — casi opaco

### Solución
- **`rices/melissa/theme-config.bash`**: `P_TERM_OPACITY="0.98"` → `"0.85"`
- **`alacritty/alacritty.toml`**: `opacity = 0.98` → `0.85` (cambio directo)
- **Picom iniciado**: `picom -b` (no estaba corriendo)

### Lecciones
- Para cambios permanentes de transparencia, modificar `P_TERM_OPACITY` en `theme-config.bash`, NO directamente en `alacritty.toml`
- Siempre verificar `ps aux | grep picom` si la transparencia no se muestra
- El `05-alacritty.sh` se ejecuta vía Theme.sh → bspwmrc

---

## 🎨 Polybar — Esquema de colores completo (tema melissa)

### Cambios visuales

**Fondo de barras:**
- Antes: `#003b4252` (transparente — 00 alpha)
- Ahora: `#1e222a` (sólido oscuro, contrasta con el terminal transparente)

**Secciones coloreadas con acentos Nord:**

| Sección | Color | Hex |
|---------|-------|-----|
| CPU | Verde | `#a3be8c` |
| RAM | Cyan | `#88c0d0` |
| DISK | Amarillo | `#ebcb8b` |
| NET | Púrpura | `#b48ead` |
| KB/Teclado | Azul | `#81a1c1` |
| Workspace focused | Verde | `#a3be8c` |
| Workspace occupied | Cyan | `#88c0d0` |
| Volumen | Cyan | `#88c0d0` |
| Brillo | Ámbar | `#FBC02D` |
| Bluetooth | Azul | `#81a1c1` |
| Batería cargando | Verde | `#a3be8c` |
| Batería descargando | Amarillo | `#ebcb8b` |
| Icono música | Púrpura | `#b48ead` |
| Icono usuario | Amarillo | `#ebcb8b` |
| Icono power | Rojo | `#bf616a` |

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `rices/melissa/config.ini` | Colores globales: bg=#1e222a, bg-alt=#2e3440 |
| `rices/melissa/modules.ini` | Acentos Nord en cada módulo, iconos descomentados |
| `rices/melissa/theme-config.bash` | P_TERM_OPACITY=0.85 |
| `bspwm/eww/colors.scss` | Sincronizado con nueva paleta |

### Recarga de polybar
```bash
polybar-msg cmd quit
RICE=$(cat ~/.config/bspwm/.rice)
MONITOR=HDMI-1 polybar mel-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
MONITOR=HDMI-1 polybar mel2-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
```

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/rices/melissa/theme-config.bash` | P_TERM_OPACITY: 0.98 → 0.85 |
| `~/.config/alacritty/alacritty.toml` | opacity: 0.98 → 0.85 |
| `~/.config/bspwm/rices/melissa/config.ini` | Colores globales polybar rediseñados |
| `~/.config/bspwm/rices/melissa/modules.ini` | Acentos Nord en cada módulo |
| `~/.config/bspwm/eww/colors.scss` | Sincronizado con nueva paleta |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/SESION.md` | ✅ Actualizado |
| `ai-context/AGENTS.md` | ✅ Añadidas notas técnicas (picom, polybar) |
| `ai-context/SYSTEM.md` | ✅ Actualizado (rice melissa, picom) |
| `ai-context/SYSTEM_FULL.md` | ✅ Actualizado (referencias, terminales) |
| `ai-context/INFO-core.md` | ✅ Actualizado (sistema, proyectos) |
| `ai-context/INFO-full.md` | ✅ Actualizado (terminales, changelog) |

*Fin de la sesión — Última actualización: 2026-07-26*

---


# 🧠 SESION — Buffy Freebuff (2026-08-06)

> Contexto de todo lo implementado durante esta sesión.

---

## 🔍 CodeGraph — setup completo (MCP + indexado + documentación)

### Qué es
`@colbymchenry/codegraph` v1.5.0 (open source MIT, 100% local) — grafo de conocimiento SQLite (AST vía tree-sitter) para descubrimiento y análisis de impacto de código. Comando MCP: `codegraph serve --mcp`. Telemetría **desactivada**.

### Servidor MCP configurado en 4 agentes (herramienta única `codegraph_explore`, probada en vivo: initialize + tools/list + explore "boost" ✅)
| Agente | Config | Extra |
|---|---|---|
| **Gemini CLI** | `~/.gemini/settings.json` | + `~/.gemini/GEMINI.md` (bloque CODEGRAPH) |
| **Claude Code** | `~/.claude.json` + `~/.claude/settings.json` | auto-allow `mcp__codegraph__*` + hook `codegraph prompt-hook` en cada prompt |
| **Antigravity IDE** | `~/.gemini/config/mcp_config.json` | backup del vacío previo |
| **Cline** (VSCodium) | `globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` | cableado a mano (no soportado oficialmente), autoApprove `codegraph_explore` |

### Proyectos indexados
| Proyecto | Índice | Cómo |
|---|---|---|
| **autoscript-mobile-interface** | 49 archivos · 1.084 símbolos · 1.896 aristas | `codegraph init` — .codegraph/ gitignored |
| **ManUninstaller** | 31 archivos · 486 nodos · 838 aristas | `codegraph init` (417ms) — .codegraph/ gitignored |

### Decisión: NO documentar en otros proyectos (datos)
Conteo de archivos fuente: autoscript 42, widgetos 28, data_car 28, ManUninstaller 25, pwa_securguard 20, lista_supermercado 17, porteria_pwa 17, GameBoostPro 10, codebuff-automation 6. El bloque global de CLAUDE.md/GEMINI.md ya activa CodeGraph donde exista `.codegraph/`, y en proyectos <30 archivos leer todo es más barato que indexar. Solo se indexó ManUninstaller como caso límite.

### Documentación escrita
- **`~/.AGENTS.md`** — sección "CodeGraph (descubrimiento de código)": regla global + proyectos indexados (aplica a todos los proyectos futuros).
- **`autoscript-mobile-interface/AGENTS.md`** — sección "CodeGraph — Descubrimiento y Análisis (obligatorio)" con comandos + ejemplos verificados.
- **`ai-context/PROJECTS.md`** — entradas para GameBoost Pro (Kotlin nativo) y ManUninstaller con nota de descubrimiento.

### Demos de `codegraph impact` (ManUninstaller)
- `impact MainActivity` → 35 símbolos, **0 fuera del archivo** (hoja del grafo — punto de entrada Android).
- `impact AppViewModel` → 47 símbolos en 2 archivos: **6 call-sites en MainActivity** (onCreate:117, setupTools:293, observeViewModel:400, onDismissed:479, showUninstallConfirmation:490, showUninstallSummary:587) — mapa de riesgo para refactors.

### Pruebas end-to-end con Antigravity (`agy --print`) — EXITOSAS
- **ManUninstaller** — consulta natural "uninstall flow": call path completo `MainActivity → AppViewModel.uninstallSelected → UninstallAppsUseCase → AppRepositoryImpl.uninstallApps → DeviceAdminUtils.removeAdmin (línea 208) → ShizukuUserService.exec`. Líneas verificadas contra el grafo (removeAdmin:38, uninstallApps:189, exec:24 ✅).
- **autoscript-mobile-interface** — consulta natural "boost flow": `GameBoostRepository.toggleBoost` (facade 1 línea, :215) → `GameSessionManager.toggleBoost` (:161-232) → `applyBoostSettings` (:195, :212, :229) → `ShizukuExecutor.runCommand` (:87-125) con **3 fallbacks** (Shizuku IPC → RishExecutor:68 → Runtime.exec). Confirmados los 11 consumers de `GameBoostRepository`.
- Sin errores de MCP en ninguna prueba. Comando usado: `agy --print '<pregunta>' --dangerously-skip-permissions` desde la raíz del proyecto indexado.

### CodeGraph visible para cualquier IA (3 capas completas)
- **Global**: `~/.AGENTS.md` + `AGENTS-root.md` (sincronizados — drift corregido, commit raíz 5862065), `~/.claude/CLAUDE.md`, `~/.gemini/GEMINI.md`.
- **Protocolo ai-context**: `INFO-core.md` (sección CodeGraph en carga obligatoria), `LOAD_CONTEXT.md` ("⚡ CodeGraph PRIMERO" en Code Search), `INFO-full.md`, `PROJECTS.md` — commit `41c07f8`.
- **Referencia completa**: `Knowledge/Tools/CodeGraph.md` (NUEVA categoría Tools — comandos, MCP, ejemplos verificados, troubleshooting) + índices README + `buffy-doctor.sh` con `KNOWLEDGE_EXPECTED[Tools/CodeGraph.md]` — commit `341c2e5`. Doctor **60 OK / 0 errores**.

### Commits
- `ManUninstaller ad6a12d` — `Chore: gitignore .codegraph/` + `e77db36` (bump 2.1.0) + `0d29483` (CHANGELOG completo) — repo local sin remote.
- `buffy-context` — `255f766` (PROJECTS.md) + `a952e44` (SESION.md) + `8b87029` (CHANGELOG.md) + `41c07f8` (INFO-core/LOAD_CONTEXT/INFO-full) + `341c2e5` (Knowledge/Tools/CodeGraph.md) — **todos pusheados**.
- `repo raíz` — `6c6b985` (`~/.AGENTS.md`) + `5862065` (`AGENTS-root.md` sincronizado) — locales, sin remote.

---

## 📁 Archivos modificados/creados (sesión 2026-08-06)

| Archivo | Cambio |
|---------|--------|
| `~/.gemini/settings.json` · `~/.gemini/config/mcp_config.json` · `~/.gemini/GEMINI.md` | MCP codegraph (Gemini + Antigravity) |
| `~/.claude.json` · `~/.claude/settings.json` · `~/.claude/CLAUDE.md` | MCP codegraph + auto-allow + hook prompt-hook |
| `VSCodium .../cline_mcp_settings.json` | MCP codegraph para Cline |
| `proyectos/autoscript-mobile-interface/.codegraph/` · `AGENTS.md` | Índice + sección CodeGraph obligatoria |
| `proyectos/ManUninstaller/.codegraph/` · `.gitignore` · `build.gradle.kts` · `CHANGELOG.md` | Índice + commits ad6a12d/e77db36/0d29483 (2.1.0) |
| `~/.AGENTS.md` · `AGENTS-root.md` | Regla global de CodeGraph (commits 6c6b985/5862065) |
| `ai-context/PROJECTS.md` · `SESION.md` · `CHANGELOG.md` · `INFO-core.md` · `LOAD_CONTEXT.md` · `INFO-full.md` | Registros + protocolo con CodeGraph (pusheados) |
| `buffy-context/Knowledge/Tools/CodeGraph.md` · `Knowledge/README.md` · `README.md` · `scripts/buffy-doctor.sh` | Referencia completa + índices + doctor (commit 341c2e5) |

---




> ⚠️ **Poda automática**: Cuando este archivo supere ~30KB o ~5 entradas
> recientes (sin contar archive), las entradas más viejas se mueven a
> `CHANGELOG-archive.md`. Última poda: 2026-08-03 (entradas 2026-07-31 y
> anteriores archivadas; front-matter duplicado eliminado).

---

version: 1.8
updated: 2026-08-08
schema: system-profile
system-id: mangonz-desktop
---

# CHANGELOG.md — Historial de cambios del sistema


### 2026-08-08 — data_car: lista de compra persistente + buffy-context apunta a opencode

**Pedido del usuario:** el botón "Agregar pack a compra" en data_car no mostraba nada (solo un toast de 2,5s, sin persistencia) — quería que los packs agregados quedaran visibles y conectados con el botón "Compartir con IA" para precios CLP. Además: buffy-context solo referenciaba Freebuff y quería que apunte también a opencode.

**Cambios aplicados (data_car — commit `c345d16`):**
- **Lista de compra persistente** en `localStorage` (`mg350_shopping_list`): "Agregar pack a compra" acumula el pack con items + referencias ya resueltas.
- **Botón "Mi compra"** en el header del panel de packs, con badge contador de packs (entero). Panel desplegable: cada pack con items/referencias, botón ✕ por pack y "Vaciar".
- **"Compartir compra con IA (precios CLP)"**: arma prompt con TODA la lista vía `buildAISharePrompt` y lo copia al portapapeles.
- Botón del pack cambia a "✓ En tu compra" cuando ya está agregado.
- Bug corregido: sumar cantidades daba "11.5 items" (aceite ×4.5 litros) → el badge cuenta packs, no unidades.

**Cambios aplicados (buffy-context — commit `12433bf`):** README, USER-MANU, INFO-core, LOAD_CONTEXT, code-search y vision-adapter actualizados para reflejar que Buffy corre en Freebuff **y** opencode (modelos free: DeepSeek).

**Verificado:** typecheck + build OK; flujo validado con playwright en local y producción (`scuderia-data.vercel.app`) — agregar pack → badge → panel → sobrevive recarga.

**Pendiente:** asignar precios de la respuesta de la IA a la lista + total CLP (reusa `parseAIResponse`).


### 2026-08-07 — scrcpy-freefire: sin auto-open de Free Fire + purga de 16 apps en el ZTE

**Pedido del usuario:** que el script de Free Fire no abra el juego automáticamente (solo GG Mouse, y el usuario abre Free Fire manual) + ver y desinstalar apps del ZTE.

**Cambios aplicados:**
- **`~/scripts/scrcpy-freefire.sh`**: eliminado `am start` de `com.dts.freefireth` (corría 0.8s después de GG Mouse). El script ahora solo lanza GG Mouse con sus permisos; Free Fire se abre manualmente desde el teléfono (comando manual comentado en el script).
- **Watchdog `FF_SEEN`**: antes mataba scrcpy cuando Free Fire "dejaba de correr"; como el juego ya no se abre desde el script, al arrancar no está corriendo → el watchdog viejo lo habría matado en 3s. Ahora espera a que Free Fire aparezca y recién ahí vigila su cierre desde el teléfono.
- **Purga de apps en ZTE Nubia (69 → 53)** con `pm uninstall --user 0` (todas Success): Film+, Drivify, KDE Connect, KLWP, KWGT, Firefox, Canta, Telegram+, Coddy, GitHub Store, AR Core, Excel, xm.csee, ES File Explorer, Downloader, tema oscuro de ES (huérfano).

**Archivos modificados:**
- `~/scripts/scrcpy-freefire.sh` — sin auto-open de Free Fire + watchdog FF_SEEN
- `buffy-context/ai-context/CONTINUE.md` — resumen de sesión agregado
- `buffy-context/ai-context/SESION.md` — bitácora de sesión agregada

**Verificado:** `bash -n` OK en el script; GG Mouse corriendo (PID 10067); 15 apps + 1 huérfana desinstaladas con Success; sin restos en `pm list packages`.


### 2026-08-07 — Fixes de teclado/pantalla/monitor-alert (super+Escape, DPMS, cálculo de CPU)

**Pedido del usuario:** eliminar la combinación `super + Escape` (bloqueaba el teclado y a veces congelaba la PC), evitar que la pantalla se apague sola, y verificar que la carga de CPU de la barra inferior de polybar concuerde con el script de alerta de CPU alta.

**Cambios aplicados:**
- **`super + Escape` eliminado del sxhkdrc** (`~/.config/bspwm/config/sxhkdrc`): ejecutaba `bspc wm -r` (reinicio del WM en caliente) — eso mataba el teclado y colgaba el sistema. Era un duplicado mal escrito del reload que ya existe en `super + r` (línea 59, mismo comando). Se dejó `super + ctrl + Escape` (recarga solo sxhkd, sin reiniciar bspwm) y un comentario NOTA en el archivo. sxhkd recargado con `pkill -USR1 -x sxhkd` (sin reiniciar bspwm), verificado vivo.
- **Pantalla ya no se apaga**: DPMS estaba habilitado (Standby/Suspend/Off a 600s) + screensaver X con blanking a 600s → la pantalla se apagaba a los 10 min. Fix: `xset -dpms` + `xset s off` aplicados en vivo **y agregados al `~/.config/bspwm/bspwmrc`** (después de SetSysVars) para persistir en reinicios.
- **`monitor-alert` calculaba mal el % de CPU** (`~/.local/bin/monitor-alert`, timer systemd cada 45s): la función `get_cpu()` usaba `u=$2+$4` (user+system) y `t=$2+$4+$5` (user+system+idle) sobre `/proc/stat` — campos incompletos que ignoraban `nice`/`iowait`/`irq`/`softirq`/`steal` en el denominador, más una ventana de 0.1s ruidosa. Fix: método estándar `(total − idle − iowait)/total × 100` sobre los 7 campos (user nice system idle iowait irq softirq), ventana de **1s**. Verificado con carga sintética: script corregido = estándar = 35% (antes 37/39/35 fluctuante).
- **Umbrales recalibrados** para Ryzen 5 3400G (4C/8T) + 13GB sin swap: CPU_WARN 70→**75**, CPU_CRIT 90, RAM_WARN 80→**75**, RAM_CRIT 92→**88** (sin swap el margen entre avisar y congelarse es todo lo que queda; 88% ≈ 11.5GB usados deja ~1.5GB libres para reaccionar).

**Archivos modificados:**
- `~/.config/bspwm/config/sxhkdrc` — eliminado binding `super + Escape`
- `~/.config/bspwm/bspwmrc` — `xset -dpms` + `xset s off` persistente
- `~/.local/bin/monitor-alert` — fórmula estándar de CPU + umbrales recalibrados

**Verificado:** `bash -n` OK en monitor-alert, script corre exit=0, timer systemd activo, valores concuerdan con polybar/top.

**Pedido del usuario:** refinar las barras polybar del rice vista (paneles de vidrio flotantes, jerarquía limpia), quitar el icono de Windows de la barra inferior, corregir los relieves "sucios" de la barra superior y añadir info a la barra inferior (temperatura, disco, fecha+tiempo).

**Cambios aplicados:**
- **Huecos de ~100px entre módulos (RESUELTO):** en polybar 3.7.2, `padding`/`spacing` sin unidad se renderizan como **N caracteres de espacio** (`builder.cpp`: `string(value, ' ')`), no píxeles (≈8px por espacio con JetBrainsMono 10). Fix: todos los espaciados con sufijo `px`.
- **Relieve "sucio" en bloques de la top bar:** los módulos `bi`/`bd` (`label-background = ${color.bg}`) pintaban costuras oscuras entre bloques; network/pulseaudio/updates tenían `format/label-background = ${color.mb}` (dobles rectángulos translúcidos) y los escritorios ocupados `label-occupied-background = ${color.mb}`. Fix: quitados bi/bd de `modules-center`/`modules-right` y eliminados los `*background = ${color.mb}` de módulos activos → texto/iconos limpios sobre vidrio.
- **Botón Start (logo Windows) retirado a pedido:** `[module/start]` eliminado de modules.ini y de `modules-left` de la barra inferior.
- **Fecha ausente en el reloj:** el label usaba `%date%` pero `[module/date]` no tenía la línea `date =` (solo `date-alt`) → renderizaba vacío. Fix: `date = "%a, %d %b %Y"`, `label = "%date%  %time%"`.
- **Temperatura leía 0 + `%units%` literal:** `hwmon-path` en 3.7.2 = ruta completa al **ARCHIVO** del sensor (`/sys/class/hwmon/hwmon2/temp1_input`), no al directorio (apuntar al dir → lee el dir como archivo → `strtol("")` = 0, confirmado con strace). `%units%` no es token (es la opción `units`); `%temperature-c%` ya agrega "°C".
- **Centro de barra inferior:** `bspwm` (duplicado con la top) → `cpu_bar sep memory_bar sep temp sep filesystem` con iconos FA6 Solid (   , colores red/yellow/orange/purple); `battery` quitado de `modules-right` (desktop, sin batería — solo logueaba error).
- **Barra inferior murió sola una vez:** crash transitorio de runtime (sin OOM/segfault; IPC de ArchUpdates probado en vivo = inofensivo). Reinicio desacoplado con `setsid` + log en `/tmp/opencode/bar2.log` para capturar el motivo si reaparece.

**Archivos modificados/creados:**
- `~/.config/bspwm/rices/vista/config.ini`, `~/.config/bspwm/rices/vista/modules.ini` — barras y módulos
- `~/.config/bspwm/rices/vista/CHANGELOG.md` — NUEVO: doc completo de la sesión (bugs, causa raíz, gotchas de polybar 3.7.2, mantenimiento)
- `ai-context/PROJECTS.md` — sección "Escritorio — Rice vista" actualizada al estado actual
- `ai-context/SESION.md` — entrada de sesión 2026-08-07

---

### 2026-08-06 — CodeGraph: descubrimiento y análisis de código (MCP + indexado + documentación)

**Pedido del usuario:** configurar el servidor MCP de CodeGraph para consultar el grafo del código directamente durante las sesiones de código; probarlo en vivo y documentar su uso para que los agentes lo usen primero en proyectos grandes.

**Cambios aplicados:**
- **`@colbymchenry/codegraph` v1.5.0** (NUEVO, global, MIT, 100% local): grafo de conocimiento SQLite vía tree-sitter. Comando MCP: `codegraph serve --mcp`. Telemetría **desactivada**.
- **Servidor MCP configurado en 4 agentes** (herramienta única `codegraph_explore`, probada en vivo con handshake JSON-RPC ✅): Gemini CLI (`~/.gemini/settings.json` + bloque en `GEMINI.md`), Claude Code (`~/.claude.json` + `~/.claude/settings.json` con auto-allow `mcp__codegraph__*` + hook `codegraph prompt-hook`), Antigravity (`~/.gemini/config/mcp_config.json`), Cline (VSCodium, cableado a mano — no está en la lista oficial).
- **Proyectos indexados**: `autoscript-mobile-interface` (49 archivos · 1.084 símbolos · 1.896 aristas) y `ManUninstaller` (31 · 486 · 838). `.codegraph/` gitignored en ambos.
- **Documentación**: sección "CodeGraph — Descubrimiento y Análisis (obligatorio)" en `AGENTS.md` de autoscript (comandos + ejemplos verificados); entradas en `PROJECTS.md` para GameBoost Pro Kotlin y ManUninstaller; regla global en `~/.AGENTS.md` (si existe `.codegraph/`, usar CodeGraph antes de grep/find).
- **Decisión de alcance (datos)**: NO documentar en proyectos <30 archivos fuente (widgetos 28, data_car 28, pwa_securguard 20, lista_supermercado 17, porteria_pwa 17, GameBoostPro 10, codebuff-automation 6) — el bloque global de CLAUDE.md/GEMINI.md ya activa CodeGraph donde exista índice, y el ahorro de descubrimiento solo se nota a escala de autoscript.
- **Demos de `impact` (ManUninstaller)**: `impact MainActivity` = 35 símbolos, 0 fuera del archivo (hoja del grafo — punto de entrada); `impact AppViewModel` = 47 símbolos en 2 archivos (6 call-sites en MainActivity) — mapa de riesgo para refactors.
- **Pruebas end-to-end con Antigravity (`agy --print --dangerously-skip-permissions`) EXITOSAS**: en ManUninstaller reconstruyó el flujo de desinstalación (removeAdmin en línea 208) y en autoscript el flujo de boost (facade 1 línea en :215, 3 fallbacks de ejecución Shizuku→rish→Runtime) — líneas verificadas contra el grafo, sin errores MCP.
- **CodeGraph visible para cualquier IA**: `AGENTS-root.md` sincronizado con `~/.AGENTS.md` (drift corregido, commit raíz 5862065); secciones en `INFO-core.md` (carga obligatoria), `LOAD_CONTEXT.md` ("CodeGraph PRIMERO"), `INFO-full.md` (commit 41c07f8); referencia completa nueva en `Knowledge/Tools/CodeGraph.md` (categoría Tools) con índices README actualizados y `buffy-doctor.sh` extendido (commit 341c2e5, doctor 60 OK / 0 errores).
- **Sesión documentada** en `ai-context/SESION.md` (entrada 2026-08-06).

**Archivos modificados/creados:**
- `~/.gemini/settings.json`, `~/.gemini/config/mcp_config.json`, `~/.gemini/GEMINI.md` — MCP (Gemini + Antigravity)
- `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/CLAUDE.md` — MCP (Claude Code)
- `VSCodium globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` — MCP (Cline)
- `proyectos/autoscript-mobile-interface/AGENTS.md`, `.codegraph/` — sección CodeGraph + índice
- `proyectos/ManUninstaller/.gitignore`, `.codegraph/` — índice + gitignore (commits ad6a12d, e77db36, 0d29483)
- `~/.AGENTS.md` — regla global (commit raíz 6c6b985)
- `ai-context/PROJECTS.md`, `ai-context/SESION.md` — registros (pusheados 255f766, a952e44)

---

### 2026-08-03 — BUFFY_HOME / common.sh (C2, opt-in): instalaciones alternativas sin romper el diseño

**Pendiente §7.5 del digest ejecutado en modo autónomo** (Buffy PC): script común que
exporta BUFFY_HOME para redirigir el estado generado a una raíz alternativa.

**Cambios aplicados:**
- **`scripts/lib/common.sh`** (NUEVO): configuración compartida — `BUFFY_HOME`
  (default `$HOME`, opt-in), helpers `buffy_home`/`buffy_ai_context`/`buffy_snapshot`.
  **Alcance deliberado**: BUFFY_HOME redirige SOLO el estado generado (ai-context/ +
  SNAPSHOT); el escaneo del entorno del usuario ($HOME/proyectos, $HOME/scripts,
  $HOME/.agents/skills, historial) sigue con el $HOME real.
- **Scripts cableados**: `buffy-context.sh` (SNAPSHOT), `buffy-doctor.sh`
  (detección/frescura), `buffy-repair.sh` (fix_regenerate_snapshot),
  `buffy-router.sh` (base incluye SNAPSHOT) — todos vía `source lib/common.sh`.
  Sin BUFFY_HOME definida → comportamiento idéntico (verificado).
- **`scripts/tests/test-common.sh`** (NUEVO): 6 tests — helpers default/custom,
  buffy-context genera SNAPSHOT bajo BUFFY_HOME, sin BUFFY_HOME no rompe,
  doctor/router respetan BUFFY_HOME. Sin sandbox → corren en --quick.
- **`scripts/tests/run-tests.sh`**: source del nuevo test + bash -n incluye los
  scripts ya listados (common.sh se valida por el test de helpers).
- **`INSTALL.md`**: sección "Configuración opcional: BUFFY_HOME (C2)" — qué redirige,
  qué no, y qué scripts lo respetan.
- **Validación**: suite `--quick` **116 OK** / completa **132 OK** · doctor 0
  errores · bash -n OK · prueba real: SNAPSHOT generado en `/tmp/...` con
  BUFFY_HOME y en `$HOME` sin él.

**Archivos modificados/creados:**
- `scripts/lib/common.sh`, `scripts/tests/test-common.sh` — NUEVOS
- `scripts/buffy-context.sh`, `scripts/buffy-doctor.sh`, `scripts/buffy-repair.sh`,
  `scripts/buffy-router.sh`, `scripts/tests/run-tests.sh`, `INSTALL.md` — MODIFICADOS

---

### 2026-08-03 — Schema-lite B1: validador estructural de ai-context (ai-context-lint.sh)

**Pendiente §7.4 del digest ejecutado en modo autónomo** (Buffy PC): JSON Schema + test
para INFO-core/CONTINUE/LOAD_CONTEXT. Decisión de diseño: validador bash puro
(consistente con el repo), no JSON Schema formal — los consumidores son LLMs que leen
markdown, y un schema-lite cubre el 80% del valor (como sugería el digest).

**Cambios aplicados:**
- **`scripts/ai-context-lint.sh`** (NUEVO): valida las secciones obligatorias que
  LOAD_CONTEXT.md promete — INFO-core (`## Sistema`, `## Hardware`, `## Reglas personales`,
  `## Estructura de proyectos`), CONTINUE (`## Resumen de la sesión`, `## Pendientes para
  próxima sesión`, `## Stack del usuario`), LOAD_CONTEXT (`## Protocolo obligatorio al
  iniciar sesión`, `## Carga condicional`, `## Arquitectura de memoria`) — + front-matter
  semver-lite (`X.Y` o `X.Y.Z`, convención del repo) y `updated` ISO. Flags `--repo`,
  `--json` (stderr limpio), `--quick`, exit 0/1/2.
- **Hallazgo real del validador**: 3 front-matters (AGENTS.md, README.md, PROJECTS.md)
  usaban `version: X.Y` (2 segmentos). Decisión: el validador acepta semver-lite X.Y/X.Y.Z
  para alinearse con la convención existente de ai-context (skill.yaml sí exige X.Y.Z).
- **`scripts/tests/test-ai-context-lint.sh`** (NUEVO): 5 tests — --help, repo sano (--json
  schema + stderr limpio), secciones obligatorias presentes, repo roto (exit 1 + JSON),
  front-matter semver-lite (X.Y y X.Y.Z válidos, rotos → exit 1), opción desconocida
  (exit 2). Fixtures temporales en /tmp, sin sandbox → corren también en --quick.
- **`scripts/tests/run-tests.sh`**: source del nuevo test + `ai-context-lint.sh` añadido
  al bash -n previo.
- **CI**: el job `suite` ya corre `run-tests.sh --json` → los 5 tests nuevos entran solos
  (sin editar el workflow).
- **Validación**: suite `--quick` 105 OK / completa **121 OK** · doctor 0 errores/1
  warning · bash -n OK.

**Archivos modificados/creados:**
- `scripts/ai-context-lint.sh`, `scripts/tests/test-ai-context-lint.sh` — NUEVOS
- `scripts/tests/run-tests.sh` — MODIFICADO

---

### 2026-08-03 — CI en GitHub Actions: suite completa + doctor con baseline de drift

**Pedido del usuario:** crear un workflow que corra la suite completa y el doctor en cada push/PR. Decisión autónoma: el doctor bloquea **solo drift nuevo** (baseline medido en CI) para no dejar el CI permanentemente rojo.

**Cambios aplicados:**
- **`.github/workflows/ci.yml`** (NUEVO): dos jobs paralelos en `ubuntu-latest` — (1) **suite**: `run-tests.sh --json` como gate obligatorio; (2) **doctor**: `buffy-doctor.sh --json` con `BASELINE_ERRORS=16` (configurable) — el parseo es directo en python (una sola llamada, imprime resumen + lista ERR, falla con `::error::` solo si el drift aumenta; JSON no parseable → job falla en voz alta). `permissions: contents: read`, `timeout-minutes`, `concurrency` (cancela runs superseded), push en todas las ramas + PRs.
- **Hallazgo de validación**: en un runner con HOME limpio el doctor ve **16 errores, no 13** — las skills que solo existen en `~/.agents/skills/` localmente pasan de `SKILL_NOT_IN_REPO` (warn) a `MISSING_SKILL` (err). El baseline se fijó a 16 (medido en clon fresco con HOME aislado). También se detectó un YAML inválido (python inline a columna 1 dentro del bloque `run: |`) y se corrigió indentándolo.
- **`README.md`**: badge de CI + sección "GitHub Actions" en Testing (nota del baseline 16 vs 13 local).
- **`CONTRIBUTING.md`**: nota sobre CI en la sección Tests (el doctor falla si un PR introduce drift nuevo).
- **Validación**: YAML parseable (pyyaml), simulación del job doctor en clon fresco con HOME aislado (errors=16 = baseline → pasa; baseline=10 → falla, probando el gate), suite local, reviewer con sign-off.

**Archivos modificados/creados:**
- `.github/workflows/ci.yml` — NUEVO
- `README.md`, `CONTRIBUTING.md` — MODIFICADOS

---

### 2026-08-03 — Entrada de release automática en el CHANGELOG (set-version + changelog-entry)

**Pedido del usuario:** integrar `set-version.sh` con el changelog para generar la entrada de release automáticamente.

**Cambios aplicados:**
- **`scripts/changelog-entry.sh`** (NUEVO): genera la entrada de release desde git log — título `### <fecha> — Release vX.Y.Z`, sección **Cambios incluidos** (asuntos de commits desde el último tag) y **Archivos modificados/creados** (git diff --name-status). Modo `--dry-run` (previsualiza sin escribir), inserta tras la cabecera del CHANGELOG y actualiza el front matter `updated:`. **Sanitiza referencias `skills/<nombre>`** para que el doctor no las tome como skills documentadas (drift falso).
- **`scripts/set-version.sh`**: ahora genera la entrada del CHANGELOG antes del commit de release y commitea `VERSION` + `ai-context/CHANGELOG.md` juntos; si la generación falla advierte y continúa; si el commit falla restaura VERSION y hace checkout del CHANGELOG.
- **`scripts/tests/test-changelog.sh`** (NUEVO): 3 tests de sandbox — estructura del `--dry-run` (cabecera + commits + archivos), sanitización de `skills/` (no expone el nombre), inserción real en copia (cabecera intacta, nueva entrada al inicio, +1 entrada).
- **`scripts/tests/run-tests.sh`**: `changelog-entry.sh` añadido al bash -n previo + source del nuevo test file.
- **`README.md`**: sección Versioning actualizada (generación automática + `--dry-run`).
- **Validación**: suite completa + suite `--quick` + reviewer con sign-off.

**Archivos modificados/creados:**
- `scripts/changelog-entry.sh`, `scripts/tests/test-changelog.sh` — NUEVOS
- `scripts/set-version.sh`, `scripts/tests/run-tests.sh`, `README.md` — MODIFICADOS

---

### 2026-08-03 — Pendientes de infraestructura: CONTRIBUTING, versionado semántico, modo --quick, installer mejorado, migración SYSTEM.md

**Cambios aplicados:**
- **`CONTRIBUTING.md`** (NUEVO): guía para contribuidores corregida a la realidad del repo (remote GitHub real, suite bash puro, hook instalado vía `scripts/hooks/install.sh`).
- **`VERSION`** (NUEVO, `v1.0.0`) + **`scripts/set-version.sh`** (NUEVO): versionado semántico — valida `vX.Y.Z`, corre la suite, commitea `VERSION`, crea tag anotado y lo pushea. Sección `## Versioning` en README.
- **`scripts/tests/run-tests.sh`**: nuevo flag `--quick` que salta los ciclos de sandbox (heurística automática: cualquier test cuyo cuerpo llame `setup_sandbox` se omite) — rápido para hooks/CI. Nuevo **`scripts/tests/test-runner.sh`** (self-tests del runner con invocación filtrada para evitar recursión).
- **`scripts/hooks/pre-commit.sh`**: ahora corre la suite en modo `--quick` por defecto; `BUFFY_HOOK_FULL=1` fuerza la suite completa puntualmente.
- **`scripts/hooks/install.sh`**: opciones `--install/--uninstall/--check/--force/--no-test/--help`, manteniendo el mecanismo de escribir el hook con el shebang real (fix Termux).
- **`scripts/migrate-system.sh`** (NUEVO): migración de los stubs `SYSTEM.md`/`SYSTEM_FULL.md` (contenido ya fusionado en `INFO-core.md`/`INFO-full.md`) a `ai-context/deprecated/` con timestamp, sed de referencias y verificación con la suite `--quick`. **EJECUTADO en el repo real el 2026-08-03** (decisión del usuario) — ver entrada de migración más abajo.
- **`README.md`**: sección `## Versioning` + docs del modo `--quick` y de las variantes del hook (`BUFFY_HOOK_FULL`, re-instalación con `--force`).
- **Validación**: suite completa 66/66 + suite `--quick` + reviewer con sign-off.

**Archivos modificados/creados:**
- `CONTRIBUTING.md`, `VERSION`, `scripts/set-version.sh`, `scripts/migrate-system.sh`, `scripts/tests/test-runner.sh` — NUEVOS
- `scripts/tests/run-tests.sh`, `scripts/hooks/pre-commit.sh`, `scripts/hooks/install.sh`, `README.md` — MODIFICADOS

---

### 2026-08-03 — README actualizado: árbol de skills/Knowledge refleja el disco

**Pedido del usuario:** el árbol del README no coincidía con el disco — el origen histórico del drift del doctor.

**Cambios aplicados:**
- **Árbol de `.agents/skills/`**: ahora muestra las **23 skills** agrupadas por dominio (Android 8, Web 2, Framework v4 5, Code & research 2, Frontend 4, Operación 2) — antes solo 10; se agregaron las 10 creadas + las 3 migradas (form-filler, image-analyzer, xiaomi-adb-tricks).
- **Árbol de `Knowledge/`**: agregadas la categoría `AI/` (Kimi-K3.md) y `Vision.md` (antes invisibles); nota de versiones mínimas en scrcpy.md.
- **Árbol de `scripts/`**: agregados skill-lint.sh, migrate-system.sh, set-version.sh, changelog-entry.sh, ollama-kill.sh, see.sh, lib/, hooks/, tests/ (antes solo 7 entradas).
- **"What's included"**: Knowledge 17 files/7 categorías + Vision, 23 skills con manifest, CI verde 106 checks.
- **Nueva sección "Skills (23 en disco)"**: tabla por grupo con nota de que el router las descubre por triggers.
- **Tabla de categorías de Knowledge**: agregadas AI (1) y Vision (1).
- **Validación**: doctor 0 errores (las 23 skills documentadas coinciden con disco — sin drift falso), suite `--quick` 90 OK.

**Archivos modificados:**
- `README.md` — MODIFICADO (71+/20-)

---

### 2026-08-03 — Versiones mínimas de scrcpy/Ollama documentadas

**Decisión del usuario:** cerrar el pendiente (b) del digest — documentar las versiones mínimas verificadas desde el PC, con fuente.

**Cambios aplicados:**
- **`Knowledge/Android/scrcpy.md`**: sección "Versiones mínimas" — UHID ≥ 2.0 (release v2.0), `--video-buffer` ≥ 1.18, `--render-expired-frames` ≥ 1.19, `--stay-awake` ≥ 1.5, `--power-off-on-close` ≥ 1.20 con **fix en 3.3.1 (#6146)** → **mínimo recomendado ≥ 3.3.1** para el setup gaming. Verificado en el PC: `scrcpy 4.1-1` + `adb 1.0.41`.
- **`Knowledge/Vision.md`**: sección "Versión de Ollama" — mínimo **≥ 0.30**, verificado binario `0.30.7` (sirviendo en `:11434`), paquete pacman `0.32.1-1`, último upstream v0.32.5. Notas: servicio de sistema activo (el de usuario deshabilitado), bug `ollama run` timeout → usar API, tags `:cloud` no ocupan RAM local.
- **`BUFFY-PC-CONTEXT.md`** §7.6(b) y **`REVIEW-BASELINE.md`** §2.6: marcados como HECHA (antes "pendiente de decisión del usuario").
- **`ai-context/CONTINUE.md`**: pendiente (b) resuelto.
- **Validación**: doctor 0 errores + suite `--quick` (antes de commit).

**Archivos modificados:**
- `Knowledge/Android/scrcpy.md`, `Knowledge/Vision.md` — MODIFICADOS
- `BUFFY-PC-CONTEXT.md`, `REVIEW-BASELINE.md`, `ai-context/CONTINUE.md` — MODIFICADOS

---

### 2026-08-03 — Migración SYSTEM.md/SYSTEM_FULL.md → deprecated/ (ejecutada)

**Decisión del usuario:** marcar como 🔴 crítica la migración de los stubs SYSTEM.md/SYSTEM_FULL.md (contenido ya fusionado en INFO-core/INFO-full desde antes).

**Cambios aplicados:**
- **`scripts/migrate-system.sh`** EJECUTADO: los 2 stubs movidos a `ai-context/deprecated/` (con timestamp), referencias en `.md`/`.sh` actualizadas (AGENTS.md, README, LOAD_CONTEXT, CHANGELOG, CONTINUE, BUFFY-PC-CONTEXT, REVIEW-BASELINE).
- **Correcciones manuales post-sed**: el sed global reemplazó `SYSTEM.md`→`AGENTS.md` ciegamente — se corrigió a mano: `ai-context/AGENTS.md` y `ai-context/README.md` ahora apuntan a `INFO-core.md`/`INFO-full.md` (destino real del contenido); árbol de `LOAD_CONTEXT.md` y `README.md` raíz muestran `deprecated/`; bitácoras históricas (SESION.md, SESION-archive.md) revertidas (no se reescriben).
- **Doctor**: ya no reporta `DEPRECATED_FILE` (los archivos ya no están en `ai-context/`).
- **Validación**: suite `--quick` ✅ (corrida por el propio script) + suite completa + doctor 0 errores.

**Archivos modificados/creados:**
- `ai-context/deprecated/{SYSTEM.md,SYSTEM_FULL.md}.20260803_150816` — MOVIDOS
- `ai-context/AGENTS.md`, `ai-context/README.md`, `ai-context/LOAD_CONTEXT.md`, `README.md`, `BUFFY-PC-CONTEXT.md`, `REVIEW-BASELINE.md`, `ai-context/CHANGELOG.md`, `ai-context/CONTINUE.md` — MODIFICADOS

---

### 2026-08-03 — Suite de tests permanente + pre-commit hook

**Pedido del usuario:** Convertir los checks ad-hoc (18/18 doctor/repair/agent) en una suite versionada con runner único, y añadir hook de pre-commit que ejecute la suite antes de cada commit.

**Cambios aplicados:**
- **`scripts/tests/`** (NUEVO): suite permanente en **bash puro** (bats no requerido — no está disponible en Termux). `run-tests.sh` es el runner único (bash -n previo de los 5 scripts, descubre `test_*` vía `declare -F`, `--json` para CI, filtro por nombre, `trap` que limpia el sandbox, exit 0/1 honesto). `helpers.sh` aporta `ok/bad/check/expect_exit/jassert` + `setup_sandbox` (copia del repo, HOME aislado, drift artificial: sin ~/ai-context y sin skills).
- **`scripts/tests/test-doctor.sh`**: `--json` schema + conteos coherentes, catálogo fix_id (id/fix/safe/target + safe coherente con FIX_SAFE), errores con identidad (INVALID_REPO/UNKNOWN_OPTION), stderr limpio, `--quick` == `--json`, exit codes honestos.
- **`scripts/tests/test-repair.sh`**: dry-run en repo real sin escribir (verificado con git status), `--auto` en sandbox reduce drift 26→0, regresión del bug `local skill dir` (cada skill en su dir con SKILL.md), `--fix` puntual, exit codes 0/1/2.
- **`scripts/tests/test-agent.sh`**: ciclo completo en sandbox (drift→0, `repair.ran=true`, exit 0), `--no-repair` en repo real, exit condicional al estado real (suite determinística).
- **`scripts/hooks/pre-commit.sh`** (NUEVO): hook versionado (no se pierde en clones) que ejecuta la suite y aborta el commit si falla.
- **`scripts/hooks/install.sh`** (NUEVO): instalador que genera `.git/hooks/pre-commit` con el shebang de bash **real del sistema** — necesario en Termux, donde `/usr/bin/env` no existe y git ejecuta los hooks con exec directo (el primer commit falló con `cannot exec '.git/hooks/pre-commit': No such file or directory`; resuelto resolviendo `command -v bash`). `git commit --no-verify` para saltar.
- **`README.md`**: sección `## Testing` (uso del runner, `--json` para CI, filtro, instalación del hook con `bash scripts/hooks/install.sh`).
- **Validación**: 59/59 checks OK (1 ronda falló por resolución de rutas del runner — SCRIPT_DIR terminaba en /tests — y por regex ERE que interpretaba los paréntesis literales de `error(es)`; ambos corregidos). 2 rondas de code review con sign-off.

**Archivos modificados/creados:**
- `scripts/tests/{run-tests.sh,helpers.sh,test-doctor.sh,test-repair.sh,test-agent.sh}` — NUEVOS
- `scripts/hooks/pre-commit.sh` — NUEVO
- `README.md`, `ai-context/CHANGELOG.md` — actualizados

---

### 2026-08-03 — Ciclo operativo completo: doctor --json con catálogo fix_id + buffy-repair + buffy-agent

**Pedido del usuario:** Cerrar el lazo doctor → decisión → acción (antes el sistema solo detectaba problemas, no actuaba). Diseño acordado: catálogo de `fix_id` en doctor --json (evita un sistema de parches), ajustes de base en buffy-context.sh, actuador buffy-repair.sh con clasificación AUTO_SAFE/REVIEW_REQUIRED, y orquestador buffy-agent.sh al final (envoltura de piezas confiables).

**Cambios aplicados:**
- **`scripts/buffy-doctor.sh`** (NUEVO): auditoría con `--json` — cada item accionable lleva identidad `{id, fix, safe, target}` (p.ej. `MISSING_SKILL / create_skill_dir / safe:true / "android-agent"`). Catálogo FIX_SAFE: AUTO_SAFE (regenerate_snapshot, create_ai_context_dir, create_skill_dir, chmod_plus_x) vs REVIEW_REQUIRED (create_*file, copy/migrate_skill, remove_or_merge, git_init, update_index). Detección de SNAPSHOT stale (STALE_SNAPSHOT) parseando `Generated:`. Errores con identidad (INVALID_REPO, UNKNOWN_OPTION); stderr limpio en modo JSON. Validado: 10/10 tests.
- **`scripts/buffy-context.sh`**: shebang zsh → bash (consistencia con doctor/router; `--watch` re-ejecuta con bash), exit codes reales (0 éxito / 1 fallo verificable), header `> ⏱️ Generated: <ts>` en SNAPSHOT.md (frescura medible), `mkdir -p` del directorio destino (bug latente en sistemas sin ~/ai-context).
- **`scripts/buffy-repair.sh`** (NUEVO): actuador con `case "$fix"` puro (sin parseo de mensajes). Dry-run por defecto; `--auto` solo AUTO_SAFE; `--fix NOMBRE`; `--json`; loop doctor → repair → verify con delta reportado. Exit codes honestos (0 limpio / 1 review pendiente o fixes fallidos / 2 error).
- **`scripts/buffy-agent.sh`** (NUEVO): orquestador del ciclo — preflight (doctor --json) → repair --auto si hay drift → verify (doctor --json) → load (buffy-router) si hay mensaje. JSON final `{repo, preflight, repair, verify, load, ready}` para CI/protocolo. Validado: 18/18 tests (sandbox: drift 19→0 errores, 19 skills creadas en disco).
- **`scripts/buffy-router.sh`** (NUEVO, ya existía localmente): carga condicional de contexto por categorías (base, knowledge, skills, scripts) con `--json`.
- **`.agents/skills/`**: 5 skills nuevas con contenido curado (android-adb, android-game-opt, hyperos-hardening, scrcpy-freefire, shizuku-rikka).
- **Bugs de bash encontrados en el camino**: `${arr[]}` con subscript vacío escupe "bad array subscript" (guard en jitem); `local skill="$1" dir="...$skill..."` expande con el valor viejo → skills se creaban en el dir equivocado (locals separados en fix_create_skill_dir).

**Archivos modificados/creados:**
- `scripts/buffy-doctor.sh`, `scripts/buffy-repair.sh`, `scripts/buffy-agent.sh`, `scripts/buffy-router.sh` — NUEVOS
- `scripts/buffy-context.sh` — modificado
- `.agents/skills/{android-adb,android-game-opt,hyperos-hardening,scrcpy-freefire,shizuku-rikka}/` — NUEVOS
- `README.md`, `INSTALL.md`, `ai-context/CHANGELOG.md` — actualizados

---

### 2026-08-02 — Organización del home + Ollama al HDD + unificación ai-context

**Pedido del usuario:** organizar el caos del home (con HDD disponible) y unificar el ai-context duplicado en una sola fuente de verdad.

**Cambios aplicados:**
- `~/Backups` (28G) → `/media/datos/Backups` con symlink (copia verificada byte a byte antes de borrar)
- `data_car`, `codebuff-automation`, `odysseus` → `~/proyectos/` con symlinks (no rompe rutas absolutas)
- Notas sueltas → `~/notas/`; logs → `~/logs/`; basura eliminada (`ervice --no-pager -n 50`, `udo systemctl start bluetooth.service`)
- Caches limpiados: npm, gradle, `~/.cache` (8.5G→360M) — disco del sistema 67% → 39%
- `~/.ollama` (14G) → `/media/datos/ollama` con symlink; deshabilitado el servicio de usuario duplicado (crash-loop); queda solo el servicio de sistema (`/usr/local/bin/ollama`)
- Skill `file-organizer` instalada desde `ComposioHQ/awesome-claude-skills`
- ai-context unificado: fusión bidireccional de `SESION.md` y `CHANGELOG.md` en `buffy-context/`; `~/ai-context` → symlink al repo; `AGENTS-root.md` → `INFO-core.md` (SYSTEM.md está deprecado)

---

### 2026-08-01 — systemd-boot fix + ask-model.js "segundo cerebro" + kimi_vision.js adoptado

**Pedido del usuario:** (1) arreglar que el menú de arranque esperara Enter, (2) montar un complemento para consultar otros modelos (local/nube) cuando yo tenga dudas, (3) adoptar la mejora kimi_vision.js del repo buffy-context.

**Cambios aplicados:**
- **systemd-boot (no GRUB)**: variable EFI `LoaderConfigTimeout` (4a67b082-...) estaba en `menu-force` → esperaba Enter indefinidamente pisando el `timeout 3` del `loader.conf`. Fix: `bootctl set-timeout 3`, luego `0` a pedido del usuario (arranque instantáneo). `loader.conf`: `timeout 0`. Escape: boot counting/fallback + `systemctl reboot --boot-loader-menu=force`.
- **`codebuff-automation/ask-model.js`** (NUEVO): consulta a Ollama local (qwen2.5:7b) o HF Router nube (DeepSeek V4 Flash/Pro/R1, Kimi K3). Modos one-shot, `--chat` (memoria), `--list`, `--json`, separador `--`.
- **`codebuff-automation/lib/utils.js`**: `resolveHfToken()` compartida (env HF_TOKEN > `~/.huggingface/token` > vacío, fallback Termux). ask-model.js y kimi_vision.js la importan (refactor post-revisión).
- **`~/.huggingface/token`** (chmod 600): token HF configurado.
- **kimi_vision.js + lib/{logger,utils}.js + Kimi-K3.md** vendored desde `maneskinleon-del/buffy-context` → `codebuff-automation/`; skills image-analyzer actualizadas (kimi_vision recomendado, auto_permiso.py fallback OCR); provenance en codebuff-memoria.md.
- **Verificado**: `node --check` en los 3 scripts; consultas reales a qwen2.5:7b, DeepSeek V4 Flash y Kimi K3 ✅; 2+ pasadas de code review aprobadas.

**Aclaración clave:** MCP conecta herramientas (el LLM es el cliente, los servidores exponen tools). Para "consultar otro modelo" no hace falta MCP — es una llamada HTTP OpenAI-compatible.

---

### 2026-08-01 — Cleanup real al salir en scrcpy-freefire.sh + limpieza del teléfono (laboratorio)

**Pedido del usuario:** al cerrar el script de Free Fire, cerrar las apps abiertas y apagar la pantalla (las apps seguían corriendo y gastaban batería). Además, empezar a limpiar el teléfono como laboratorio de pruebas.

**Qué se hizo:**
1. **Cleanup real al salir en `scrcpy-freefire.sh`**: `close_game_apps()` + apagado de pantalla a los 5s. Misterio resuelto: la sesión anterior corría código viejo (solo force-stop a 2 apps). Descubrimiento clave: 8 apps (Device Admins/auto-reinicio) ignoran el force-stop de Android.
2. **Mecanismo nuevo**: `KILL_PERSISTENT` (default `0` seguro), `pm disable-user` al cerrar para matar de verdad a los Device Admins, `pm enable` + `dpm set-active-admin` al iniciar para restaurarlos completos (incluido el estado de admin — `pm enable` NO lo restaura), gate `SESSION_STARTED` (solo limpia si el juego arrancó).
3. **Nuevo `scrcpy-freefire-restore.sh`**: restauración manual independiente; lee listas del main vía `sed` (una sola fuente de verdad).
4. **Cierre con Alt+Q** (`sxhkdrc:162`): hint del notify actualizado (`Alt+Q para salir`).
5. **Limpieza del teléfono**: desinstalados Tasker (`net.dinglisch.android.taskerm`), Automate (`com.llamalab.automate`) y Facebook (`com.facebook.katana`). Detalle técnico: eran Device Admins activos → bloqueo `DELETE_FAILED_DEVICE_POLICY_MANAGER`; solución `pm disable-user` → desactiva el admin → `pm uninstall`. Único admin restante: MacroDroid.
6. **Scripts actualizados**: `PERSISTENT_APPS` y `PERSISTENT_ADMIN_RECEIVERS` sin tasker/automate (restore se autoactualiza).

**Transparencia:** los ciclos disable→enable de prueba desactivaron el Device Admin de MacroDroid/Tasker/Automate; restaurados con `dpm set-active-admin` (los 3 con Success).

**Validación:** `bash -n` OK en ambos scripts, sync a `.openclaw/`, revisor aprobó, desinstalación verificada (`pm path` vacío).

**Pendiente mañana:** borrar más apps del lab (candidatos: MacroDroid, AutoJS, Kustom Widget, Steps, `com.launcher.hype`); considerar `KILL_PERSISTENT=1` para lab sin apps corriendo.

---

### 2026-08-01 — Fix ruta de rish + prueba real de --grant con diálogo de permiso

**Hallazgo:** En la primera prueba real con `--grant`, el script fallaba con `rish: not found` porque rish vive en `~/bin/rish` y no está en PATH en este dispositivo.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): nueva función `resolveRish()` — resuelve la ruta con prioridad env `RISH` > `~/bin/rish` (si existe) > `rish` en PATH (vía `command -v`) > fallback `rish`. La constante `RISH` usa ahora la ruta resuelta.
- **Prueba real completada**: diálogo de notificaciones de VInstall (`com.vinstall.alwiz`) detectado por Kimi K3 al 98% (título, botones PERMITIR/NO PERMITIR) y concedido: `pm grant POST_NOTIFICATIONS` + `appops POST_NOTIFICATION=allow`. Verificado: `granted=true`, appop `allow`.

---

### 2026-08-01 — Fix endpoint Kimi K3 (router.huggingface.co/v1, sin /hf)

**Hallazgo:** El endpoint `/hf/v1/chat/completions` devuelve 404; el correcto es `https://router.huggingface.co/v1/chat/completions` (verificado con prueba real: HTTP 200, Kimi K3 respondió en 10.2s).

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): `KIMI_ENDPOINT` default corregido a `router.huggingface.co/v1/chat/completions` (header + constante), + hint de error para 404 que recomienda revisar `KIMI_ENDPOINT`.
- **`Knowledge/AI/Kimi-K3.md`**: las 3 referencias al endpoint actualizadas a `/v1` (tabla de acceso, ejemplo curl, sección Script implementado).
- **Nota:** las entradas históricas de este CHANGELOG mencionan `/hf/v1`; quedan como referencia del estado previo al fix.

---

### 2026-08-01 — kimi_vision.js integrado al repo buffy-context

**Pedido del usuario:** Agregar kimi_vision.js al repo: copiarlo a scripts/ y documentarlo en Knowledge/AI/Kimi-K3.md.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (NUEVO): copia del script de visión IA (Kimi K3) para detectar diálogos de permisos — upgrade de auto_permiso.py. Idéntico al origen `~/kimi_vision.js` (22639 bytes, diff 0), `node --check` OK.
- **`scripts/lib/logger.js` + `scripts/lib/utils.js`** (NUEVOS, vendored): copias de `~/lib/` para que el script sea **autocontenido y ejecutable desde el repo** (verificado: `node scripts/kimi_vision.js --help` ✅). Marcados como copia vendored (actualizar desde `~/lib/`).
- **`Knowledge/AI/Kimi-K3.md`**: Nueva sección "Script implementado: scripts/kimi_vision.js" — modos CLI, cómo funciona (base64 → Kimi K3 → JSON → mapeo rish), robustez (retry/backoff, parseo robusto, fallback other), verificación.
- **`README.md`**: árbol de scripts actualizado con `kimi_vision.js`.

---

### 2026-08-01 — kimi_vision.js creado + repo clonado vía SSH

**Pedido del usuario:** Crear el script kimi_vision.js (visión IA con Kimi K3 para detectar diálogos de permisos, upgrade de auto_permiso.py) y sincronizar buffy-context con un clon local vía SSH.

**Cambios aplicados:**
- **`~/kimi_vision.js`** (NUEVO, fuera del repo): visión IA con `moonshotai/Kimi-K3` vía API HF OpenAI-compatible (`router.huggingface.co/hf/v1/chat/completions`). Screenshot en base64 → modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + licencia gated aceptada. Probado con API simulada ✅ (extractJson 3 casos, mapeo, pipeline completo); 2 pasadas de code review (fixes: mtime en monitorLoop, orden help-vs-token, Number.isFinite en args).
- **Repo clonado**: `~/buffy-context` vía HTTPS + remote `origin` en SSH (`git@github.com:...`). 44 archivos, working tree limpio, los 5 commits del doc Kimi K3 presentes.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 actualizada — kimi_vision.js + clon SSH + pendientes (clave SSH por registrar, HF_TOKEN, prueba real).
- **Clave SSH**: ed25519 generada en este dispositivo; **pendiente de registrar** en github.com/settings/keys (el token actual no tiene scope `admin:public_key`).

---

### 2026-08-01 — Kimi K3 vía Hugging Face + MCP documentado

**Pedido del usuario:** Investigar cómo usar Kimi K3 (Moonshot AI) desde Hugging Face vía MCP y documentar el hallazgo en el repo.

**Cambios aplicados:**
- **`Knowledge/AI/Kimi-K3.md`** (NUEVO): Referencia del modelo — 2.8T params MoE, multimodal nativo, 1M contexto, tool calling. Acceso: HuggingChat web, API OpenAI-compatible `router.huggingface.co/hf/v1` + token HF (pago por uso), API Moonshot. Aclaración clave: MCP conecta herramientas, NO es la forma de usar el modelo (HuggingChat es cliente MCP; el MCP oficial de HF expone el Hub). Casos de uso: visión de screenshots (upgrade OCR/auto_permiso.py), análisis de contexto 1M (CSVs SecurGuard, dumpsys, logcat), segunda opinión de código, JSON estructurado.
- **`Knowledge/README.md`**: Nueva categoría `AI/` indexada en el árbol + fecha actualizada a 2026-08-01.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 registrada; sesión 07-29 archivada (poda automática).
- **`ai-context/SESION-archive.md`**: Sesión 07-29 (día completo) movida al archivo.

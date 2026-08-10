# 🧠 SESION — Buffy opencode (2026-08-10 · P0 completado: memoria curada sincronizada entre PC y teléfono)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).

---

## 🔗 P0 completado: `buffy-memory.sh sync` — puente PC ↔ teléfono

### Pedido del usuario
"En el PC tenemos un modo buffy que hace referencia a lo que construimos en el repo… quizás nos falte ese puente para unificar las sesiones de PC y teléfono. Queremos llegar a la potencia de Hermes."

**Diagnóstico entregado:** el puente base ya existe (repo git: SESION/CONTINUE/PROJECTS/Knowledge/skills — validado en vivo hoy). El hueco real es que la **memoria curada (`~/.buffy/memories/`) es perfil-local y no viaja** — el PC arranca con memoria vacía. Hermes tiene UNA memoria que acompaña al agente; hoy cada dispositivo tiene la suya.

### Lo implementado (en `buffy-context`)
1. **`scripts/lib/buffy-memory-sync.sh` (NUEVO)** — `sync status|push|pull [--force]`:
   - Las copias versionadas viven en `<repo>/ai-context/memories/` (MEMORY.md + USER.md) y viajan por git.
   - **Estado per-host** en `ai-context/memories/.sync-state`: cada dispositivo registra el último sha que sincronizó → el guard de drift es fiable aunque el otro lado escriba (un push del PC no borra la marca del teléfono).
   - `push`: git pull (ff-only) → comparo contra el repo actual → conflicto si el repo cambió desde mi último sync y no conozco el cambio · `--force` resuelve.
   - `pull`: conflicto si tengo cambios locales sin sincronizar · `--force` sobrescribe. Primer sync sin marca propia y contenidos distintos → aviso preventivo (nunca piso sin decisión).
   - Git ops acotadas al repo que contiene SYNC_DIR (nunca toca archivos fuera de `ai-context/memories/`).
2. **`scripts/buffy-memory.sh`** — comando `sync` añadido (rutas `BUFFY_SYNC_DIR`/`BUFFY_SYNC_HOST` configurables).
3. **Tests** — 4 suites nuevas en `test-memory.sh` (13 checks): push→pull entre 2 hosts, conflicto push (PC escribió), conflicto pull (local cambió), primer sync preventivo. Verificados con sandbox + escenario con git real (bare origin + 2 clones).
4. **Memoria real del teléfono versionada** — primer `sync push` desde `telefono-mi10` (commit `9367a43`).
5. **README** — conteos actualizados: **229 full (224 functional + 5 meta) / 213 --quick (208 functional)**.

### Verificación
Suite completa: **229 OK / 0 FAIL** · --quick: **213 OK / 0 FAIL** (pasó el pre-commit).

### ⏳ Pendiente
- En el PC: una vez hecho `git pull`, correr `buffy-memory.sh sync pull` para adoptar la memoria del teléfono → luego la memoria es compartida. Documentar en el AGENTS.md del PC.
- P1: retorno del aprendizaje (SESION-archive → conocimiento activo). P2: concurrencia 3+ escritores sobre MEMORY.md.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · borrado de etiquetas implementado en organiza_gmail_V3)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).

---

## 🗑️ Borrado de etiquetas — implementado en Gmail Organizer V3

### Pedido del usuario
Retomando la sesión cortada: "borra las etiquetas" → la pregunta abierta era si el script podía **borrar las etiquetas que crea** (v2 quedó obsoleta → etiquetas huérfanas; desde el móvil no se borraban en script.google.com).

### Lo implementado (`~/gscript-audit/organiza_gmail_V3/`, pusheado a la web con clasp)
1. **`cleanupLabels(options)` en `labels.js`** — limpieza one-shot:
   - Borra etiquetas **gestionadas** (`CONFIG.LABELS`) cuando están vacías.
   - Borra etiquetas **huérfanas vacías** (restos de v2/limpiezas previas).
   - **NUNCA** borra etiquetas del sistema (INBOX, SPAM, TRASH, DRAFT, SENT, IMPORTANT, STARRED, UNREAD, CHAT, Scheduled) ni **manuales con hilos**.
   - `dryRun: true` solo informa · `force: true` extiende a gestionadas con hilos (los correos NO se borran, solo la etiqueta).
   - Protección de cuota: `Utilities.sleep(500)` entre borrados.
2. **`applyCleanupOnce()` en `labels.js`** — guard one-shot integrado a `main()`: corre **una sola vez** (flag `cleanupLabelsDone` en ScriptProperties) al inicio de la primera corrida, antes de `processInbox()`. Así la limpieza la ejecuta el **trigger de 10 min existente** sin intervención del usuario.
3. **`main.js`** — llamada a `applyCleanupOnce()` envuelta en try/catch (si falla la limpieza, el procesamiento continúa).

### Ejecución
- La ejecución remota vía Apps Script API **no fue posible**: el token OAuth de clasp no tiene el scope de ejecución (`script.external_request`) → `404 NOT_FOUND` (síntoma típico). Se intentó con deployment creado (`@4`) y sin él.
- La limpieza quedó **auto-programada**: corre en la próxima corrida del trigger `main` (10 min) o `manualRun()`. Alternativa manual: abrir el proyecto en `script.google.com` → función `cleanupLabels` → Run (o `{dryRun:true}` primero).

### Lecciones
- **El token de clasp NO sirve para ejecutar funciones** — solo para push/pull de código. Para invocar `scripts.run` se necesitaría OAuth re-hecho con scope `script.external_request` + los scopes de Gmail, lo cual requiere navegador.
- Solución sin fricción: acoplar la acción al ciclo de vida del script (arquitectura trigger + guard one-shot) en lugar de pelear con OAuth desde Termux.

---

## 🔍 Auditoría de Apps Scripts con Google Studio API — estado y pendientes

### Lo que se hizo
1. **Auditoría vía API de Google Studio** (API key de Google AI Studio SK-ws-...) de los proyectos de Apps Script: `organiza_gmail_V3`, `copy_organiza_gmail`, `ordenar_drive_pro`, `sin_titulo_1` — clones con `clasp` en **`~/gscript-audit/`** (teléfono; el PC los tiene en `~/proyectos/gmail-scripts` y `~/proyectos/gmail-scripts-otro`).
2. **`organiza_gmail_V3` (Gmail Organizer)**: versión local con mejoras de rate limiting/reanudación — `main.js` (entrada con rate limiting, `scheduleResume`, `scheduleDelayedRetry`, `setupTriggersIfMissing`, `resetDailyQuota`, triggers 10 min + reset diario 00:05 + resumen 22:00), `gmail.js` (snapshot único `search()`, reintentos con `withRetry`, control de cuota/runtime). Diferente de `copy_organiza_gmail` (= versión original bajada de la web).
3. **Discusión de etiquetas:** el usuario preguntó si el script, **así como crea etiquetas automáticamente, puede borrarlas** (v2 quedó obsoleta; fue reemplazada por v3 y dejó etiquetas huérfanas; desde el móvil no se pueden borrar en `script.google.com`). **Quedó como pregunta abierta** — no se implementó borrado automático de etiquetas (ni en Gmail Organizer ni en Drive Organizer).
4. El usuario haría la revisión visual desde el PC.

### ⚠️ Sesión cortada (18:51-19:02)
- **"de esto no esta enterada la version de pc, lo dejamos al dia..."** → pendiente: registrar esta sesión en buffy-context + push para que el PC quede al día (ejecutado en la sesión siguiente: commit + push).
- **"igual hice cambios en el pc, ve si dejo algo en nuestro repo"** → verificado: **origin/main = local = `4850e91`**, el PC NO dejó nada nuevo pusheado.

### ⏳ Pendientes
- Decidir si implementar **borrado de etiquetas huérfanas** en `organiza_gmail_V3` (función one-shot tipo `cleanup_tmp.js` o `deleteEmptyLabels`).
- Revisar `sin_titulo_1` (proyecto sin nombre, quedó identificado como tal).

---

## 🛒 data_car — P1 completado: precios de la IA asignados a la lista + total CLP

### Pedido del usuario
Pendiente P1 del CONTINUE (heredado de la sesión 2026-08-08): "elegir pack → agregar a compra → compartir con IA → pegar respuesta → precios asignados + total". `parseAIResponse` y `formatCLP` ya existían en `src/lib/aiShare.ts`; faltaba la UI y la lógica en el panel de compra.

### Lo implementado (`src/components/MaintenancePacks.tsx`, +118 líneas)
1. **Sección "💸 Precios desde la IA"** en el panel Mi compra: textarea para pegar la respuesta JSON de la IA + botón "Asignar precios" + contador `N/M con precio` + fila Total (CLP).
2. **`handleAssignPrices`**: `parseAIResponse(text)` → si no hay `repuestos` → toast de error; si parsea → por cada item de la shopping list busca su precio con `findPrice()` y lo guarda como `price` (unitario) en el item → toast con total o con faltantes.
3. **`findPrice` + `normalizeName`**: match tolerante — minúsculas, sin acentos (NFD), sin contenido entre paréntesis (refs tipo "UJ-1797"), solo alfanumérico, `includes` bidireccional ("Bujías NGK" ↔ "Bujías"). La IA puede variar el nombre (agregar "5W/40", "semisintético") y el match sigue funcionando.
4. **`computeTotal`**: suma `precio × cantidad` de cada item con precio → muestra con `formatCLP`. Los precios viven en el item (`price?: number`) → se persisten en `mg350_shopping_list` → sobreviven recarga.
5. Precio unitario visible por item en la lista (`— $18.490` en verde).

### Verificación (Playwright sobre `vite preview`, hash build `index-D4lIbUUa.js`)
| Caso | Resultado |
|---|---|
| JSON realista (Aceite 18.490 ×4,5 + Filtro 6.990) | Toast "total **$90.195**" ✓ (83.205 + 6.990) |
| Items con precio en lista + "2/2 con precio" + fila Total | ✓ |
| Caso límite: nombres parciales ("Aceite de Motor 5W/40 semisintético", "Filtro de aceite UJ-1797") | Match ✓ → total **$75.000** |
| JSON inválido ("esto no es json", `{"repuestos":[]}`) | Toast de error, 0 errores en consola, no rompe |
| Recarga (reload) | Total y precios persisten (localStorage) |

Typecheck (`npx tsc --noEmit`) y build (`npm run build`) OK.

### Lección
- La transformación **Python incremental** vuelve a ser el método que funciona sobre `MaintenancePacks.tsx` (confirmado por tercera vez; las ediciones con `edit` sobre este archivo no persisten). Ver sesión 2026-08-08.

### ⏳ Pendiente
- **Commit + push del cambio en data_car** (aún sin commitear).

---

# 🧠 SESION — Buffy opencode (2026-08-10 · P0 benchmark context-selection + congelamiento levantado)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 📊 P0 completado: bench-context-selection.sh — el benchmark que desbloquea el congelamiento

### Pedido del usuario
"vamos con los pendientes" + activar modo autónomo → el pendiente P0 del CONTINUE era `bench-context-selection.sh`: el benchmark pendiente que justificaba el próximo cambio en el motor de selección de contexto (congelamiento vigente: benchmark primero, feature después).

### Contexto que lo motivaba
El benchmark anterior (`bench-scale.sh --adversarial`) había demostrado que FTS5 puro NO distingue la aguja cuando los irrelevantes comparten el vocabulario de la query (`scrcpy`/`ZTE` en contextos distintos) — recall 1/2. El CONTINUE decía: "la capa que lo resuelve es el router (context selection), que este benchmark no ejercita".

### Lo implementado
1. **`scripts/tests/bench-context-selection.sh` (NUEVO, ~200 líneas)** — ejercita el pipeline COMPLETO:
   - Sandbox con repo simulado: `Knowledge/` por dominio (Android/scrcpy.md con la AGUJA, Android/ADB.md, Linux/System.md, FreeFire/GameOptimization.md, React/React.md) + manifests de skills mínimos (android-adb, scrcpy-freefire) para que el router los resuelva.
   - Tarea real: **"el teléfono no aparece en scrcpy"**.
   - Etapa 1: `buffy-router.sh --json` → categorías + knowledge files elegidos.
   - Etapa 2: `buffy-search.sh` FTS5 real sobre el índice del sandbox.
   - Métricas: `domain_precision` (¿knowledge del dominio correcto?), `domain_recall` (¿incluyó scrcpy.md + ADB.md?), `spurious_categories`, `search_recall`/`search_leaked` (límite FTS5), `context_chars`/`tokens`/`window_utilization`, `pipeline_healthy`.
   - Flags: `--count`, `--adversarial`, `--json`, `--quick`. Easy = gate (exit 0 si pipeline sano); adversarial = medición (exit 0 si corrió).
2. **Bug propio encontrado al validar:** el contador de `search_leaked` usaba `grep -cE "^(Nota Linux...)"` (anclado a inicio de línea), pero los hits de FTS5 empiezan con el path (`Knowledge/Linux/System.md:1: Nota Linux...`) → medía 0 cuando en realidad FTS5 estaba 100% contaminado. Corregido a grep sin `^`. Lección: los detectores deben considerar que el path antecede al contenido en la salida del search.
3. **`scripts/tests/test-context-selection.sh` (NUEVO)** — 2 tests en la suite: `test_context_selection` (easy: exit 0 + JSON healthy + precision 1.0 + 0 spurious) y `test_context_selection_adversarial` (medición: exit 0 + pipeline_healthy true). Registrado en `run-tests.sh`.
4. **README** — sección "Benchmark de selección de contexto con router (P0 — desbloquea el congelamiento)" + conteos actualizados: **209 full (204 functional + 5 meta) / 193 --quick (188 functional)** + árbol de tests (15 test_*.sh + 2 benchmarks).

### Resultado medido (evidencia)
| Métrica | Easy | Adversarial |
|---|---|---|
| categorías router | Android | Android |
| spurious | 0 | 0 |
| domain_precision | 1.00 | 1.00 |
| domain_recall | 2/2 | 2/2 |
| search_recall (FTS5 puro) | 2/2 | **0/2** |
| search_leaked | 0 | **10/10** |
| pipeline_healthy | true | **true** |

La tesis quedó demostrada: cuando FTS5 puro se contamina por completo (adversarial), el **router resuelve** cargando el archivo del dominio correcto → `pipeline_healthy` se mantiene. Esa es la evidencia que el congelamiento pedía.

### Verificación
- `run-tests.sh --quick`: **193 OK / 0 FAIL** · `run-tests.sh` (full): **209 OK / 0 FAIL**.
- Benchmark standalone: exit 0 en easy y adversarial.

### Lecciones
- **Un benchmark también tiene bugs** — el propio `search_leaked` medía mal (path antecede al contenido). El paso de validación contra el resultado real (¿realmente hay 0 leaked?) destapó el error.
- **El congelamiento cumplió su función:** forzó a medir el pipeline antes de tocar el motor, y la medición confirmó la hipótesis (router resuelve). Ahora cualquier cambio futuro tiene baseline.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · scripts Gmail/Drive + update opencode)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 📧🗂️ Scripts de Google Apps Script: Gmail Organizer V3 + Drive Organizer Pro

### Pedido del usuario
"Estaba viendo unos scripts de Google, para ordenar Gmail y Drive que tengo, pero no sé si la sesión del teléfono te dejó la info en el repo" → la sesión anterior (desde el teléfono) NO había quedado registrada en buffy-context; se reconstruyó desde el historial de prompts de opencode (`~/.local/state/opencode/prompt-history.jsonl`).

### Lo hecho
1. **`~/proyectos/gmail-scripts/`** = Gmail Organizer v3 (`organiza_gmail_V3`, scriptId `1yqqZXC4kysIlMMbY57Bi6Ft5Jf5mtO3fUX9EnT41BJtCOnMXmQ01I_sK`): clasifica la bandeja en etiquetas (Compras, Telecom, Bancos, Gobierno, Trabajo, Facturas, Envíos, Spam, ⭐Importante + etiquetas por empresa: BancoEstado, Tenpo, Fonasa, Mercado Libre, AliExpress, WOM...). Rate limiting + reintentos + reanudación tras pausa/cuota; **fix de paginación**: snapshot único con `search()` en vez de `getInboxThreads(pos)`; `cleanup_tmp.js` = limpieza one-shot de etiquetas de usuario (corre una sola vez vía `cleanupEtiquetasDone` en ScriptProperties).
2. **`~/proyectos/gmail-scripts-otro/`** = Drive Organizer Pro v5.0 (`ordenar_drive_pro`, scriptId `1TW8pIdyQAUeAI7ZznVY4KCZgZtGirq_leLUX8vXWQa1e0i6prPIpzBOu`): modos MAESTRO (todo el Drive, BFS limitado) / ESPECÍFICO (carpeta por ID) × PRUEBA (simula) / REAL (mueve). Motor de reglas con prioridad (MIME > nombre), carpetas administradas (Scripts, Documentación, Android, Configuraciones, Multimedia, Backups, Web, Recursos, Sin clasificar, Comprimidos, Chats) y excluidas (Google Fotos, Trash...). Rate limiting estilo Gmail Organizer + triggers cada 10 min + reanudación por cola de carpetas.
3. **Sincronizados con la web** (`script.google.com`) vía `clasp pull` — "los de la página ya tienen mejoras" (el usuario los había mejorado desde la web). Ambos quedaron con **commit inicial** local:
   - `gmail-scripts`: `a207071` — "chore: estado sincronizado con Apps Script (organiza_gmail_V3) via clasp pull" (13 archivos, 1747 líneas)
   - `gmail-scripts-otro`: `610a040` — "chore: estado sincronizado con Apps Script (ordenar_drive_pro) via clasp pull" (11 archivos, 1738 líneas)
4. **opencode actualizado** a **1.18.16** (hoy 15:19, `~/.npm-global/lib/node_modules/opencode-ai`) — la actualización que "no se realizó" en la sesión anterior finalmente se completó. Verificado: `opencode --version` = 1.18.16 = última de npm.

### Lecciones
- **La sesión desde el teléfono NO quedó en buffy-context** → los datos solo existían en disco (los repos git) y en el historial de prompts de opencode. Lección: tras una sesión que toca proyectos nuevos, registrar en SESION.md/PROJECTS.md aunque no se haya "programado" el cierre. Reconstruible vía `~/.local/state/opencode/prompt-history.jsonl`.
- Ambos repos son **git locales sin remote** — no están en GitHub. Los scripts viven en la nube de Google (source of truth) y el repo local es el backup.

---

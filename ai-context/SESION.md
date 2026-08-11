# 🧠 SESION — Buffy opencode (2026-08-11 · Fase 1 medida + Fase 2 diagnóstica aprobada + Fase 3 spec v2 + Pasos 1-6 del EVAL PC + cierre)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).
> ⚠️ La sesión se cortó antes del cierre protocolario; el cierre se completó en la sesión siguiente (mismo día).

---

## 🔬 Fases 1-2-3 del benchmark realista (buffy-context)

### Pedido del usuario
Aprobar/avanzar las fases del benchmark realista contra el hallazgo `search_recall = 0.000` (FTS5 AND) y el router débil (`router_recall ~0.225`).

### Lo hecho
1. **Fase 1 — Search mejorada** (`buffy-search.sh`): `BUFFY_SEARCH_STRATEGY` (default `and` = baseline byte a byte) con `or` = deacent + lowercase → términos ≥3 chars sin stopwords ES (~70) → máx 8 → `"t1" OR ...` + BM25 → top-K. Corrección del usuario: términos ≥3 chars (ADB/API/Git/SSH/CPU/DPI/VLM/APK/USB son valiosos; ≥4 los descartaba).
2. **Medición Fase 1 (3 seeds × and vs or)**: search_recall **0.000 → 0.736** · context_relevance → 0.505 · leakage +0.031 · token ×4.4 · latencia +52 ms · **controles router/multi EXACTOS** → aislamiento demostrado (el 0.000 era el AND absoluto, FTS5 exonerado) → **Fase 2 habilitada**.
3. **3 fixes de exactitud del benchmark**: router miraba CWD no repo (contaminaba Node espurio) → `$REPO_DIR`; corpus de visión path plano vs anidado → `knowledge_dir: ""` + fallback basename; `search_recall` contaba no-gold → `|recov ∩ gold| / |gold|`.
4. **Fase 2 — diagnóstico del router** (modo `--diagnose`, report-only): ejecutado 14 multi × 3 seeds = **42/42 invariante**, matriz por query (23/42 sin señales · react 0/22, code-search 0/13, git 0/6, vision 0/4 = cero detecciones · rom 9ok/4bad). **Veredicto usuario 🟢 aprobado.**
5. **Fase 3 — spec v2 APROBADA** (selector híbrido router léxico + evidencia de Search): gates G-R1..R6 con δ pre-fijado, regla de descarte §4.4, promoción score_d ≥ θ_c, barrido presupuesto, `BUFFY_SELECTOR=lexical` default. **Paso 1 HECHO: EVAL congelado** (`eval-set.json` 10 queries sha256 180e14a0… + `dev-set.json` 12 sha256 0cd8d5a6…). **Siguiente: paso 2 (baseline re-congelada 3 seeds × {and,or}) → paso 3 (V1).**
6. **Reglas de arquitectura registradas** (CORE/ADAPTATION/TEST/RESEARCH + aislamiento dispositivo↔usuario) en `~/AGENTS.md` y spec §11.
7. Suite: **246/246 full (241 functional + 5 meta) · 230 --quick**. Informes: `/sdcard/Download/informe-benchmark-realista.txt`, `/sdcard/Download/diagnostico-router-fase2.txt`.

### ⏳ Pendientes para otra sesión
- **Fase 3 paso 2**: baseline re-congelada 3 seeds × {and,or} → paso 3: V1 del cap-selector híbrido.
- En el PC: tras `git pull`, `buffy-memory.sh sync pull` UNA vez.
- P1: retorno del aprendizaje · P2: concurrencia 3+ escritores · Opcional: `Knowledge/Tools/Buffy-Memory.md` · Revisar `~/gscript-audit/sin_titulo_1/`.

---

## 🔎 EVAL PC — Pasos 5 y 6 (auditoría de gold + fixture corregido)

### Paso 5 — Auditoría de gold/cobertura de evidencia (COMPLETADO)
- **Q04 — gold DEFECTUOSO (crítico):** `gold_files=[System.md]` pero `xset -dpms`/`xset s off`
  NO existen en System.md (viven en CONTINUE.md:405, CHANGELOG.md:203, SESION-archive.md:1970).
  search_recall de Q04 = 0 por construcción del fixture, no por fallo del buscador.
- **Q06 — gold PARCIALMENTE defectuoso:** `FF_SEEN` no está en ningún gold file declarado;
  vive en CONTINUE/CHANGELOG/SESION. `com.dts.freefireth` sí está en scrcpy.md:57.
- **Q03/Q08 — gold CORRECTO pero puente léxico roto:** agujas SÍ en archivo gold pero la línea
  gold comparte 0-1 tokens con la query (`git push origin` overlap NINGUNO; `picom` NINGUNO).
- **Q01/Q02/Q05/Q07/Q09/Q10 — gold correcto.** Conclusión: problema MIXTO (2/10 fixture,
  Q03/Q08 puente semántico/técnico). Detalle en EVAL-REGISTRY.md → Paso 5.

### Paso 6 — Fixture gold corregido + A/B/C regenerados (COMPLETADO, instrumento v3)
- **Fixture:** Q04 → gold `ai-context/CHANGELOG.md` (fuente real, línea 203); Q06 → `CHANGELOG.md`
  añadido (FF_SEEN, línea 186). Nuevo hash `00852568…`. Solo `evidencia real → gold correcto`.
- **Instrumento v3:** `EVAL_HASH` actualizado + leakage ya no penaliza archivos gold.
- **Resultados (gold corregido):** search_recall **A=0.000 / B=0.050 / C=0.100** · other
  0.000/0.200/0.100 · context_relevance 0.600/0.202/0.355 · leakage 0.267/0.694/0.522 ·
  token 5 069/44 846/37 547 · router Δ=0.
- **Hallazgo clave:** **Q04 era 100 % fixture, no retrieval.** and-norm SÍ recupera
  `xset -dpms`+`xset s off` como gold con el fixture corregido → invalida parcialmente la
  conclusión del Paso 4 ("and-norm no captura el puente léxico").
- **Retrieval restante (con gold correcto):** Q03/Q08 puente semántico/técnico real; Q06
  ranking trae CONTINUE.md y no scrcpy.md, FF_SEEN no se recupera ni siendo gold.
- **No se adoptó ninguna variante.** Runtime congelado. Artefactos v3:
  `baseline-and/or/and-norm-PC-2026-08-11.json`. Detalle en EVAL-REGISTRY.md → Paso 6.
- **Siguiente:** decisión del usuario sobre el próximo experimento (¿Hybrid?) con gold corregido.

---

## 🔎 EVAL PC — Paso 6b (auditoría Q06 + gold definitivo) y Paso 7 (diseño)

### Paso 6b — Auditoría específica de Q06 (COMPLETADO)
- **Veredicto:** `scrcpy.md` NO contiene evidencia equivalente de `FF_SEEN` (solo
  `com.dts.freefireth:57` en diagnóstico de lag — paquete tangencial, no el hecho
  evaluado). La evidencia real vive en CHANGELOG.md:186, CONTINUE.md:448 y el script
  real `~/scripts/scrcpy-freefire.sh:272-276` (fuera del corpus).
- **Gold definitivo Q06:** `gold_files=[ai-context/CHANGELOG.md]`,
  `gold_facts=[FF_SEEN]`. `com.dts.freefireth` quitado del gold.
- **Fixture actualizado** (hash `98a0e308…`) + runner v3.1 + **A/B/C regenerados**:
  search_recall 0.000/0.050/0.100 · other 0.000/0.150/0.050 · context_relevance
  0.533/0.182/0.333 · leakage 0.267/0.694/0.522 · token 5 197/45 259/38 017.
  Nota: router_precision 0.667→0.600 por variabilidad de entorno (router no lee fixture).

### Paso 7 — Experimento semántico diagnóstico (DISEÑADO, pendiente aprobación)
- **Spec:** `scripts/tests/evals/semantic-retrieval-DESIGN.md`.
- **Pregunta:** ¿un retrieval semántico recupera Q03/Q06/Q08 sin el leakage/coste de OR?
- **Invariantes:** MISMO EVAL/gold/limit/métricas. UNA variable: lexical → semantic.
- **Enfoque:** Ollama local (ya instalado) + `bge-m3` (multilingüe, default) o
  `nomic-embed-text` (sanity). Embeddings por línea → coseno → top-LIMIT. Runner nuevo
  `run-semantic-PC.sh` — NO toca runtime.
- **Gate pre-fijado:** search_recall > 0.100 · context_relevance ≥ 0.600 · leakage
  ≤ 0.267 · token ≤ ~2× A · determinismo · mismo EVAL hash.
- **NO adoptar todavía** — experimento diagnóstico; veredicto = usuario.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · revisión: sync sin ruido git + pendientes router multi-dominio)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).

---

## 🔁 Corrección post-revisión: sync sin ruido git (punto A)

### La revisión señaló
"Versionas MEMORY/USER pero también `.sync-state` que describe quién sincronizó qué → commits adicionales de estado. Vigilaría que el mecanismo no genere ruido git."

### Lo corregido
1. **`.sync-state` movido fuera del repo** → ahora vive en `$MEM_DIR/.sync-state` (perfil-local, por dispositivo). El repo **solo contiene contenido**; el estado es conocimiento local de cada máquina y nunca viaja.
2. `pull` ya no commitea nada. `push` commitea solo los archivos de contenido (add explícito, no el directorio).
3. `.sync-state` versionado en commits anteriores eliminado con `git rm --cached`.
4. Tests: +2 checks — "el repo NO versiona .sync-state" + "cada host tiene su estado local". **Suite: 241 OK / 0 FAIL (236 functional + 5 meta) · 225 --quick (220)**.
5. Bug propio de paso en `do_pull`: última línea devolvía exit 1 tras pull exitoso → `|| true`.

### Pendientes de la misma revisión (B y C — router/benchmark)
- **B. Multi-dominio** (consulta → 2-3 dominios): medir `multi_domain_recall` / `multi_domain_precision` / `cross_domain_leakage`.
- **C. Benchmark realista**: 500 hechos, 5-10 dominios, consultas reales sin keywords artificiales; medir router precision/recall, search recall, context relevance, token cost, latency, leakage. Disciplina: benchmark primero.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · "cerrar día" automatizado con buffy-close-day.sh)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).

---

## 🌙 "Cerrar día" automatizado — `buffy-close-day.sh`

### Pedido del usuario
"En el PC creé una nueva tarea y es cuando le diga 'cerrar día', cierra la sesión de memoria con todo lo hecho en esta. ¿Si lo implementamos acá o ya con el script de buffy-memory-sync ya se hace eso?"

**Respuesta:** el sync cubre SOLO la memoria curada; el cierre completo era protocolo manual. Implementado el script que une ambas cosas.

### Lo implementado
`scripts/buffy-close-day.sh` (NUEVO) — protocolo de cierre en 4 pasos:
1. `buffy-memory.sh sync push` → la memoria curada viaja al repo/GitHub (si conflictúa con el otro dispositivo → **aborta con guía**, nunca pisa).
2. Regenera SNAPSHOT (buffy-context.sh, queda local, no se versiona).
3. `buffy-doctor.sh --quick` → valida el cierre; aborta si hay errores.
4. Commit (`docs(sesion): cerrar día — <fecha> [· mensaje]`) + push, y por cada `--extra-repo RUTA` también.

Flags: `--message "texto"` · `--no-push` · `--skip-doctor` (solo pruebas) · `--extra-repo RUTA` · `--repo RUTA`.

Tests en `scripts/tests/test-close-day.sh` (3 suites, +10 checks). **Suite: 239 OK / 0 FAIL (full, 234 functional + 5 meta) · 223 OK / 0 FAIL (--quick)**.

**Lección de bash:** `trap '...' RETURN` dentro de una función setup se dispara al retornar ESA función (borra el sandbox antes de usarlo) — el trap va en cada test, no en el setup.

### ⏳ Pendiente para el PC
Tras `git pull`: `buffy-memory.sh sync pull` UNA vez (adopta la memoria del teléfono) → desde ahí "cerrar día" en el PC = escribir el contexto + `buffy-close-day.sh`.

---

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


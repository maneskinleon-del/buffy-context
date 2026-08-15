# EVAL REGISTRY — Context Selection (perfil PC)

> Registro del EVAL congelado para el pipeline `USER REQUEST → router → categoría → search → ranking`.
> Este archivo es parte de TEST (no CORE ni ADAPTATION). Nada de lo aquí registrado es
> conocimiento compartido del perfil ni entra en memoria curada.

## ⛔ Estado: CONGELADO

- **Congelado ANTES de tocar código.** No se implementó Hybrid, no se modificó
  router/search/selector.
- **Este EVAL NO podrá utilizarse posteriormente para calibrar `θ_c`, presupuesto
  ni pesos.** Es referencia de TEST, no dato de adaptación. Los parámetros de
  adaptación (`θ_c`, presupuesto, pesos) permanecen locales al perfil del
  dispositivo y nunca se convierten en conocimiento global.

## Registro

| Campo | Valor |
|---|---|
| **hash** | `8e42d119bf7bc4f2014e7239f101e3c37296365f3b24158e0cb0155baaa67f5d` |
| **fecha** | 2026-08-11 |
| **perfil** | PC |
| **host/perfil relevante** | `sabrewulf-a320ms2h` (EndeavourOS/Arch x86_64) — distinto de Mi 10/Termux |
| **número de queries** | 10 |
| **criterio de selección** | queries reales/representativas del uso de Buffy (sesiones 08-03→08-10) con cobertura: single-domain, multi-domain, sin señales léxicas, ambiguas, susceptibles de leakage; gold manual verificado contra el corpus |

## Ubicación del EVAL

- Fixture: `scripts/tests/evals/eval-ctx-PC-2026-08-11.json`
- Hash: `scripts/tests/evals/eval-ctx-PC-2026-08-11.json.sha256`
- Verificación: `cd scripts/tests/evals && sha256sum -c eval-ctx-PC-2026-08-11.json.sha256`

## Perfil y aislamiento

- Los resultados de Fase 1 y la baseline de Termux **NO son comparables** con los
  del PC. La baseline del PC (próximo paso) debe registrarse explícitamente como
  perfil PC.
- Separación mantenida:
  - CORE → router léxico, search/FTS5, comportamiento histórico (no tocado).
  - ADAPTATION — PC → perfil del PC, `.sync-state`, parámetros locales (no creado aún).
  - TEST → este EVAL + benchmark + diagnósticos.
  - RESEARCH → OR+BM25, Hybrid (no implementado).
- Nada específico del PC entró ni entrará en memoria curada (`MEMORY.md`/`USER.md`).

## Queries (resumen)

| ID | Query | Cobertura | gold_domains |
|---|---|---|---|
| Q01 | el teléfono no aparece en scrcpy | single-domain | Android |
| Q02 | cómo concedo permisos a una app con shizuku sin root | single-domain | Android |
| Q03 | quiero pushear el commit y crear el pull request | single-domain | Git |
| Q04 | la pantalla se apaga sola después de unos minutos | sin señales léxicas | Linux |
| Q05 | el componente React de la app necesita leer el serial del teléfono por adb | multi-domain | React, Android |
| Q06 | el script bash de scrcpy no abre free fire, revisá el script | multi-domain | Android, Shell |
| Q07 | el celular anda lento, qué puedo hacer | sin señales léxicas | Android |
| Q08 | la terminal se ve opaca y quiero que se vea transparente | sin señales léxicas | Linux |
| Q09 | quiero optimizar el rendimiento | ambigua | Android |
| Q10 | la ZTE se calienta cuando juego free fire | leakage | Android |

---

## ✅ Paso 2 — Baseline A (perfil PC) · 2026-08-11

Medición del pipeline **actual** (`buffy-router.sh` → `buffy-search.sh`) contra el
EVAL congelado, sobre el repo real (`~/buffy-context`), **sin tocar runtime**
(`runtime_changed: false` — no se implementó Hybrid, no se modificó
router/search/selector).

Runner: `scripts/tests/evals/run-baseline-PC.sh`
Resultado: `scripts/tests/evals/baseline-A-PC-2026-08-11.json`

| Métrica | Valor |
|---|---|
| **domain_precision_avg** | 0.667 |
| **domain_recall_avg** | 0.667 |
| **categories_recall_avg** | 0.800 |
| **search_recall_avg (FTS5, estrategia `and` default)** | 0.000 |
| **spurious_categories** | 2 (Q04, Q08 → Android espurio) |
| **search_leaked_files** | 4 (Q01) |
| **context_tokens** | 47 726 total / 4 773 avg → ventana 200k = 2.4% |

### Hallazgos de la baseline A

1. **Router sano en dominios con señal léxica** (Q01/Q02/Q03/Q05): precision y
   recall 1.0 — el pipeline actual resuelve los casos canónicos.
2. **Casos sin señales léxicas (Q04/Q08, gold Linux) → Android espurio**: el router
   activa Android por *entorno* (`detect_adb_device`: dispositivo Mi 10 conectado)
   y no hay señal Linux. Es el comportamiento real del perfil PC con el teléfono
   conectado; gold esperaba Linux.
3. **search_recall = 0.000 en las 10 queries**: con la estrategia `and` por defecto,
   el FTS5 exige que TODAS las palabras de la query natural estén en una misma
   línea indexada → no recupera ninguna aguja gold. Coincide con la conclusión de
   `bench-realistic-FASE1-Search.md` (0.000 → 0.736 con `or`), que es del track
   RESEARCH: la baseline A confirma que el runtime actual (default `and`) no
   recupera las agujas con queries en lenguaje natural.
4. **Domain gaps del router** (Q06/Q07/Q09/Q10): falta Keymappers (Q06), falta
   GameOptimization (Q07 — "lento" no es señal), ADB sobra en Q09/Q10, falta
   NubiaLab (Q10 — el router no mapea ese archivo).

> ⛔ Esta baseline es del perfil PC y NO se compara contra Termux.
> ⛔ No se usará para calibrar `θ_c`, presupuesto ni pesos (es referencia de TEST).

---

## ⏸️ Paso 3 — Baseline B (perfil PC, Search OR/BM25) · 2026-08-11 · MEDIDA, SIN VEREDICTO

Experimento controlado **A → Search OR/BM25 → mismo EVAL PC → comparar contra A**,
autorizado por el usuario. Mismo EVAL congelado, mismo gold, mismo perfil PC.
`BUFFY_SEARCH_STRATEGY=or` (variable que `buffy-search.sh` ya soporta; el default
`sigue siendo and`). **No se modificó ningún código de runtime** (`runtime_changed: false`).
**No se implementó Hybrid ni cap-selector. No se calibró nada.**

Runner: `scripts/tests/evals/run-baseline-PC.sh --strategy or`
Resultado: `scripts/tests/evals/baseline-B-PC-2026-08-11.json`
(la baseline A original `baseline-A-PC-2026-08-11.json` queda intacta)

### Comparación A (and) vs B (or) — agregado

| Métrica | A (and) | B (or) | Δ |
|---|---|---|---|
| **router_precision_avg** | 0.667 | 0.667 | 0.0 (aislado ✓) |
| **router_recall_avg** | 0.667 | 0.667 | 0.0 (aislado ✓) |
| **categories_recall_avg** | 0.800 | 0.800 | 0.0 (aislado ✓) |
| **search_recall_avg** | 0.000 | **0.250** | **+0.250** |
| **context_relevance_avg** | 0.600 | **0.192** | **−0.408** |
| **cross_domain_leakage_avg** | 0.267 | **0.704** | **+0.437** |
| spurious_categories | 2 | 2 | 0 |
| token_cost avg | 4 881 | **43 910** | **×9.0** |
| token_cost p95 | 37 726 | 68 954 | +31 228 |
| latency avg | 582 ms | 592 ms | +10 ms |
| window_utilization | 2.4% | 22.0% | +19.6 pp |

### Por query — search_recall A→B

| ID | sRec A | sRec B | Δ | cRel A→B |
|---|---|---|---|---|
| Q01 | 0.0 | 0.0 | 0 | 0.333→0.286 |
| Q02 | 0.0 | 0.0 | 0 | 1.0→0.286 |
| Q03 | 0.0 | **0.5** | +0.5 | 1.0→0.2 |
| Q04 | 0.0 | **1.0** | +1.0 | 0.0→0.0 |
| Q05 | 0.0 | 0.0 | 0 | 1.0→0.25 |
| Q06 | 0.0 | **0.5** | +0.5 | 0.667→0.2 |
| Q07 | 0.0 | 0.0 | 0 | 1.0→0.111 |
| Q08 | 0.0 | **0.5** | +0.5 | 0.0→0.125 |
| Q09 | 0.0 | 0.0 | 0 | 0.5→0.125 |
| Q10 | 0.0 | 0.0 | 0 | 0.5→0.333 |

**Mejoraron (4/10):** Q03, Q04, Q06, Q08. **Sin cambio (6/10):** Q01, Q02, Q05, Q07, Q09, Q10.

### Leakage detectado en B

OR trae al top-10 muchos archivos **no-gold**: README.md, INSTALL.md, CONTRIBUTING.md,
Knowledge/README.md, ai-context/LOAD_CONTEXT.md, ai-context/INFO-full.md,
ai-context/CONTINUE.md, archivos de sesión, y Knowledge de otros dominios
(Node.md, Vite.md, Kernel.md, HyperOS.md, Vision.md, Keymappers.md, NubiaLab.md).
`cross_domain_leakage` sube de 0.267 → 0.704.

### Lectura cruda (sin veredicto — decisión pendiente del usuario)

- OR **recupera** lo que AND no podía (search_recall 0 → 0.25, 4 queries con agujas).
- Pero **destruye** context_relevance (0.6 → 0.192) y **dispara** leakage (0.267 → 0.704)
  y token cost (×9, 22% de la ventana).
- Las métricas de router permanecen **aisladas** (Δ=0 en precision/recall/categories).
- El EVAL PC **reproduce el fenómeno** del benchmark realista (OR sube recall) pero
  con un coste de contexto/leakage que el benchmark realista no penalizaba igual.

> ⛔ **Sin veredicto todavía.** El usuario pidió ver la medición cruda y la comparación
> antes de decidir adoptar OR. No se convirtió OR en default. No se avanzó a Hybrid.

---

## ✅ Paso 3 — CERRADO como experimento diagnóstico · 2026-08-11 · OR NO adoptado

**Veredicto del usuario:** Paso 3 aprobado como medición y cerrado. **OR no se adopta
como default.** Los resultados quedan congelados como evidencia para el diseño del
siguiente experimento. No se toca `buffy-search.sh` ni `buffy-router.sh`.

**Lectura objetiva (del usuario):** OR mejoró search_recall (0.000 → 0.250, 4/10
queries) pero con caída fuerte de context_relevance (0.600 → 0.192) y aumento de
cross_domain_leakage (0.267 → 0.704) y token cost ×9. **El trade-off
recuperación ↔ relevancia/leakage/coste no justifica sustituir AND por OR.**

**Siguiente paso (diagnóstico, antes de Hybrid):** revisar las 4 queries que OR
recuperó (Q03, Q04, Q06, Q08) para determinar **qué patrón de consulta/documentos
hizo que AND fallara y OR acertara** — hipótesis verificable para el diseño del
siguiente experimento, en vez de saltar a `AND → OR → Hybrid` sin saber qué
problema se intenta resolver.

## 🔬 Diagnóstico Q03/Q04/Q06/Q08 — patrón AND-falla / OR-acierta · 2026-08-11

**Objetivo:** determinar qué patrón de consulta/documentos hizo que AND fallara y OR
acertara, para diseñar el siguiente experimento con hipótesis verificable.

### Causa raíz de AND = 0.000

AND exige **todas las palabras crudas de la query en la misma línea**, incluyendo
stopwords (`el/de/no/y/que/se/la`). Las queries naturales de 8-12 palabras hacen
prácticamente imposible matchear una línea del corpus.

| Query | Tokens AND (crudos) | Tokens OR (normalizados) |
|---|---|---|
| Q03 | quiero, pushear, el, commit, y, crear, el, pull, request | pushear, commit, crear, pull, request |
| Q04 | la, pantalla, se, apaga, sola, después, de, unos, minutos | pantalla, apaga, sola, despues, unos, minutos |
| Q06 | el, script, bash, de, scrcpy, no, abre, free, fire,, revisá, el, script | script, bash, scrcpy, abre, free, fire, revisa, script |
| Q08 | la, terminal, se, ve, opaca, y, quiero, que, se, vea, transparente | terminal, opaca, vea, transparente |

### Puente léxico de OR (por qué acertó)

OR normaliza (quita stopwords, exige ≥3 chars) y matchea **cualquier** token. Las
líneas gold que recuperó comparten 1-2 tokens significativos con la query:

- **Q03** → `Knowledge/Git/Commands.md:64` "gh pr create **# Crear PR**" — puente:
  `crear` (comentario en español de la línea, no el comando). `git push origin`
  (Commands.md:13) NO se recuperó: la línea no comparte tokens OR.
- **Q04** → `ai-context/CONTINUE.md:339` "**Pantalla** ya no se **apaga**: `xset -dpms`
  + `xset s off`..." — puente: `pantalla` + `apaga`. Ambas agujas viven en la misma
  línea → 2/2.

### Hallazgo crítico: 2 de las 4 "recuperaciones" son artefactos cross-file

El runner cuenta agujas en el **texto concatenado de todos los snippets**, sin
verificar que la aguja provenga del archivo gold:

- **Q06** → `com.dts.freefireth` se encontró en `ai-context/CONTINUE.md:325`, NO en
  `Knowledge/Android/scrcpy.md:57` (el hit de scrcpy.md fue la línea 3, no la 57).
  `FF_SEEN` NO se recuperó.
- **Q08** → `picom` se encontró en `ai-context/AGENTS.md:36`, NO en
  `Knowledge/Linux/System.md:3` (el hit de System.md fue la línea 27, no la 3).
  `P_TERM_OPACITY` NO se recuperó.

**Corrección del recall real de OR:** con artefactos = 0.250; sin artefactos (aguja
en el snippet del archivo gold) = **0.150** (solo Q03/Q04). La mejora real de OR es
~60% menor de lo que reporta el runner.

### Conclusión → hipótesis para el siguiente experimento

1. **El problema no es AND vs OR en abstracto**: las líneas gold comparten solo 1-2
   tokens con la query. AND no recupera nada; OR recupera con ruido.
2. **El puente léxico es español↔técnico**: "pushear"→push, "crear"→create,
   "apaga"→dpms/s off. OR acertó Q03 solo porque el doc tenía un comentario en español.
3. **Las anotaciones gold están incompletas**: las agujas también viven en
   `CONTINUE.md`/`AGENTS.md` (archivos de sesión/contexto) que no están en
   `gold_files`. OR las encontró ahí — contenido genuinamente relevante que el gold
   no anota.
4. **Hipótesis verificable (próximo experimento):** un **AND normalizado** (mismos
   tokens que OR, exigiendo co-ocurrencia de ≥2 tokens significativos en la línea)
   debería recuperar Q03/Q04 sin el leakage de OR. El runner debe reportar **dónde**
   se encontró cada aguja (archivo gold vs otro) para no inflar recall.

## 📋 Paso 4 — AND normalizado · ⏳ DISEÑO aprobado para implementar · 2026-08-11

**Decisión del usuario (2026-08-11):** revisado el diagnóstico, cerrado, y **aprobado
el diseño del experimento de AND normalizado** como Paso 4. Orden metodológico
mantenido: una hipótesis, un cambio experimental, una medición. **Sin modificar
runtime.** Diseño completo en `and-normalizado-DESIGN.md` (reproducible).

**Resumen del diseño (ver `and-normalizado-DESIGN.md` para especificación completa):**

- **Estrategia `and-norm`:** tokenización/normalización idéntica a OR (deaccent →
  lowercase → alnum → ≥3 chars), misma `STOPWORDS_ES`, pero exigiendo **co-ocurrencia
  de ≥2 tokens significativos en la misma línea** (comparación por sets, no substring).
- **Ranking:** bm25 conservado (misma variable que A/B) — el gate de co-ocurrencia
  actúa POST-query sobre un top-N amplio (50) y recorta a LIMIT=10.
- **Fallback:** <2 tokens significativos → AND crudo (histórico) o 1-token con marca
  `cooccurrence_gate: n/a` (defensivo; en el EVAL las 10 queries tienen ≥2).
- **Corrección del instrumento (crítica):** `search_recall` pasa a contar SOLO
  `gold_file_match` (aguja en snippet de archivo gold). `other_file_match` se reporta
  como `search_other_recall` (diagnóstico). `search_recall_raw` para comparar con el
  runner viejo. Esto corrige el falso positivo del Paso 3 (Q06/Q08).
- **Gates:** G1 (fixture verificado), G2 (determinismo: JSON idéntico salvo latency),
  G3 (A/B/C corren sobre el MISMO EVAL en la misma corrida).
- **Criterio de lectura (reportar, no bloquear):** interesante si
  search_recall_corregido ≥ 0.150 (igualar recall real de OR) con context_relevance
  ≥ 0.600 y cross_domain_leakage ≤ 0.267 (no degradar vs A); token_cost ≤ ~2× A.
- **Fuera:** Hybrid, cap-selector, calibración, default and, EVAL/baselines A/B,
  los 5 FAIL de suite, runtime de producción.

**Nota de integridad:** los JSON de A y B se REGENERAN con el instrumento corregido
(§4) para comparación justa; los originales del Paso 2/3 quedan en git history.

## 📊 Paso 4 — EJECUTADO · métricas crudas (instrumento v2) · 2026-08-11

**Ejecución:** runner corregido (instrumento v2) + estrategia `and-norm` implementada
en el runner (runtime congelado, `runtime_changed: false`). A y B regenerados con el
mismo instrumento. C = and-norm. Gates: **G1 ✅** (hash coincide), **G2 ✅** (2 corridas
and-norm idénticas salvo latency), **G3 ✅** (A/B/C mismo eval_hash, misma corrida).

### Agregado (instrumento v2)

| métrica | A (and) | B (or) | C (and-norm) |
|---|---|---|---|
| search_recall (solo gold) | 0.000 | **0.050** | 0.000 |
| search_other_recall (diag) | 0.000 | 0.200 | 0.200 |
| search_recall_raw (gold+other) | 0.000 | 0.250 | 0.200 |
| context_relevance | **0.600** | 0.192 | 0.319 |
| cross_domain_leakage | **0.267** | 0.704 | 0.558 |
| categories_recall | 0.800 | 0.800 | 0.800 |
| router_precision / recall | 0.667 / 0.667 | 0.667 / 0.667 | 0.667 / 0.667 |
| spurious_categories | 2 | 2 | 2 |
| token_cost avg / p95 | 4 967 / 38 580 | 44 337 / 69 808 | 37 038 / 69 433 |
| latency avg / p95 | 555 / 611 ms | 556 / 608 ms | 567 / 615 ms |
| window_utilization | 2.5% | 22.2% | 18.5% |

### Por query — search_recall (solo gold) / other / raw

| ID | A sRec/sOth/raw | B sRec/sOth/raw | C sRec/sOth/raw |
|---|---|---|---|
| Q01 | 0/0/0 | 0/0/0 | 0/0/0 |
| Q02 | 0/0/0 | 0/0/0 | 0/0/0 |
| Q03 | 0/0/0 | **0.5**/0/0.5 | 0/0/0 |
| Q04 | 0/0/0 | 0/**1.0**/1.0 | 0/**1.0**/1.0 |
| Q05 | 0/0/0 | 0/0/0 | 0/0/0 |
| Q06 | 0/0/0 | 0/**0.5**/0.5 | 0/**0.5**/0.5 |
| Q07 | 0/0/0 | 0/0/0 | 0/0/0 |
| Q08 | 0/0/0 | 0/**0.5**/0.5 | 0/**0.5**/0.5 |
| Q09 | 0/0/0 | 0/0/0 | 0/0/0 |
| Q10 | 0/0/0 | 0/0/0 | 0/0/0 |

**Nota de registro (hechos, sin interpretación):** con el instrumento corregido, B
pasa de search_recall 0.250 (v1, inflado) a **0.050** (v2, solo gold). Q04/Q06/Q08
quedan como `other_file_match` (aguja en archivo no-gold). C (and-norm) no recupera
ninguna aguja gold (0.000) y mantiene las mismas `other_file_match` que B en
Q04/Q06/Q08. `cooccurrence_stats` por query en el JSON de C (hits antes/después del
gate). **Sin veredicto — el usuario pidió ver los datos crudos antes de decidir.**

## ✅ Paso 4 — CERRADO como experimento diagnóstico · 2026-08-11 · C (and-norm) NO adoptado

**Veredicto del usuario (2026-08-11):** and-norm **no resuelve el problema**.
`search_recall gold = 0.000` — la hipótesis (≥2 tokens significativos en la misma
línea recuperaría Q03/Q04 sin el ruido de OR) **no ocurrió**. C reproduce las agujas
no-gold de B (other_file_match 0.200) pero no transforma ninguna en recuperación
válida del archivo gold.

**Descartado (con evidencia):** variantes pequeñas de AND (≥3 tokens, ranking, BM25,
LIMIT, stopwords) — sería optimización sobre un mecanismo que ya demostró que no
captura el puente léxico necesario (`crear`↔`create`, `pantalla no se apaga`↔`xset -dpms`).

**Conclusión del usuario:** el buscador actual resuelve por coincidencia léxica, pero
el problema es **semántico/técnico** (consulta natural → concepto → terminología
técnica → documento). **NO se salta a Hybrid todavía.**

**Pregunta fundamental del siguiente paso:** ¿el problema está en el **retrieval** o
en el **gold/fixture**? Q04/Q06/Q08 ya mostraron información encontrada en OTROS
archivos (CONTINUE.md, AGENTS.md) — el benchmark puede estar midiendo file retrieval
cuando el gold representa fact retrieval.

**Estado:** C NO adoptado. Runtime congelado. Siguiente: **Paso 5 — auditoría de
gold / cobertura de evidencia** (para las 10 queries, especialmente Q03/Q04/Q06/Q08):
gold file, gold line, gold fact, evidencia en gold, evidencia equivalente fuera de
gold, ¿el gold representa la respuesta esperada?

## 🔎 Paso 5 — Auditoría de gold / cobertura de evidencia · 2026-08-11

**Objetivo:** responder si el problema está en el **retrieval** o en el **gold/fixture**.
Para cada query: ¿la aguja gold existe en el archivo gold declarado? ¿La línea gold
comparte tokens con la query? ¿Hay evidencia equivalente fuera del gold?

### Resultado por query (10/10 auditadas)

| ID | aguja | ¿en gold declarado? | ¿línea gold comparte tokens con query? | ¿evidencia fuera de gold? |
|---|---|---|---|---|
| Q01 | adb tcpip 5555 / adb connect | ✅ GOLD (ADB.md) | — | — |
| Q02 | rish -c / moe.shizuku / pm grant | ✅ GOLD (Shizuku.md, ADB.md) | — | sí (INFO-full, SHIZUKU-RISH-BUG) |
| Q03 | git push origin | ✅ GOLD (Commands.md:13) | **NINGUNO** | — |
| Q03 | gh pr create | ✅ GOLD (Commands.md:64) | **1** (`crear`) | — |
| Q04 | xset -dpms / xset s off | ❌ **NO en System.md** | — | **sí** (CONTINUE.md:405, CHANGELOG.md:203, SESION-archive.md:1970) |
| Q05 | useState / adb devices -l | ✅ GOLD (React.md, ADB.md) | — | — |
| Q06 | FF_SEEN | ❌ **NO en gold files** | — | **sí** (CONTINUE.md, CHANGELOG.md, SESION-archive.md) |
| Q06 | com.dts.freefireth | ✅ GOLD (scrcpy.md:57) | **NINGUNO** | sí (NubiaLab.md, CONTINUE.md) |
| Q07 | dumpsys thermalservice / force_gpu_rendering | ✅ GOLD (GameOptimization.md) | — | sí (scrcpy.md) |
| Q08 | picom | ✅ GOLD (System.md:3) | **NINGUNO** | sí (README, INFO-core, CONTINUE.md) |
| Q08 | P_TERM_OPACITY | ✅ GOLD (System.md:78) | **NINGUNO** | sí (AGENTS.md, INFO-full) |
| Q09 | scaling_governor / force_gpu_rendering | ✅ GOLD (GameOptimization.md) | — | sí (ADB.md) |
| Q10 | dumpsys thermalservice / thermal_control | ✅ GOLD (GameOptimization.md) | — | sí (scrcpy.md) |

### Hallazgos

1. **Q04 — gold DEFECTUOSO (crítico):** `gold_files = [Knowledge/Linux/System.md]`
   pero las agujas `xset -dpms` / `xset s off` **NO existen en System.md** (grep: 0
   coincidencias de pantalla/dpms/blanking). Viven en `CONTINUE.md:405`,
   `CHANGELOG.md:203`, `SESION-archive.md:1970`. El gold declara un archivo que NO
   contiene la respuesta → search_recall de Q04 es 0 **por construcción del fixture**,
   no por fallo del buscador. Es `other_file_match` inevitable.
2. **Q06 — gold PARCIALMENTE defectuoso:** `FF_SEEN` no está en ningún gold file
   declarado (scrcpy.md/Keymappers.md/Shell.md); vive en CONTINUE.md/CHANGELOG/
   SESION-archive. `com.dts.freefireth` sí está en scrcpy.md:57 pero esa línea no
   comparte tokens con la query.
3. **Q03/Q08 — gold CORRECTO pero puente léxico roto:** las agujas SÍ están en el
   archivo gold, pero la línea gold comparte 0-1 tokens con la query:
   - Q03 `git push origin` (Commands.md:13) → overlap NINGUNO.
   - Q03 `gh pr create` (Commands.md:64) → overlap 1 (`crear`, por el comentario ES).
   - Q08 `picom` (System.md:3) → overlap NINGUNO.
   - Q08 `P_TERM_OPACITY` (System.md:78) → overlap NINGUNO.
4. **Conclusión de la auditoría:** el problema es **MIXTO**:
   - **2/10 queries (Q04, Q06)** tienen gold que no representa la respuesta esperada
     (aguja fuera del archivo gold declarado) → el benchmark mide file retrieval
     cuando el gold representa fact retrieval.
   - **Q03/Q08** tienen gold correcto pero el buscador léxico no captura el puente
     semántico/técnico (`crear`↔`create`, `pantalla no se apaga`↔`xset -dpms`,
     `terminal opaca`↔`picom`).
   - **Q01/Q02/Q05/Q07/Q09/Q10** tienen gold correcto y agujas en el archivo gold.

### Implicación para el diseño del próximo experimento

Antes de gastar presupuesto en Hybrid/embeddings/query expansion, conviene **corregir
el fixture gold** (Q04: apuntar a CONTINUE.md/CHANGELOG.md o mover la evidencia a
System.md; Q06: añadir el archivo de sesión donde vive FF_SEEN). Con el gold corregido,
la medición de search_recall reflejará fact retrieval real y no penalizará al buscador
por un fixture mal anotado. Decisión del usuario.

## ✅ Paso 6 — Fixture gold CORREGIDO (Q04/Q06) + A/B/C regenerados (instrumento v3) · 2026-08-11

**Decisión del usuario (autorizada en sesión):** corregir el fixture gold ANTES de cualquier
experimento de retrieval. Solo `evidencia real → gold correcto`, NUNCA
`resultado del buscador → gold adaptado al resultado`. No tocar runtime ni estrategias.

### Qué se corrigió en el fixture

| Query | Antes | Después | Evidencia verificada |
|---|---|---|---|
| Q04 | `gold_files = [Knowledge/Linux/System.md]` (NO contenía la evidencia) | `gold_files = [ai-context/CHANGELOG.md]` + facts `xset -dpms`/`xset s off` source CHANGELOG.md | `CHANGELOG.md:203` (fix DPMS/blanking, registro histórico estable) |
| Q06 | `gold_files = [scrcpy.md, Keymappers.md, Shell.md]` (FF_SEEN en ninguno) | `gold_files += [ai-context/CHANGELOG.md]` + fact `FF_SEEN` source CHANGELOG.md | `CHANGELOG.md:186` (watchdog FF_SEEN) |
| Resto | sin cambios (solo reformateo JSON) | — | — |

Nuevo hash del fixture: `0085256874af80e0677a6121384c5702d0aea600d21c2a175441449f4fd19ffd`
(los v1/v2 quedan en git history).

### Qué se corrigió en el instrumento (v2 → v3)

- `EVAL_HASH` actualizado al hash del fixture corregido.
- **`cross_domain_leakage` excluye `files_gold`**: un archivo gold NUNCA es leakage — si el
  fixture declara que CHANGELOG.md es la respuesta esperada, traerlo no puede penalizar.

### Comparación limpia — A/B/C sobre gold corregido (mismo EVAL, 10 queries, 1 corrida)

| métrica | A (and) | B (or) | C (and-norm) |
|---|---|---|---|
| search_recall (gold) | 0.000 | 0.050 | **0.100** |
| search_other_recall | 0.000 | 0.200 | 0.100 |
| search_recall_raw | 0.000 | 0.250 | 0.200 |
| context_relevance | 0.600 | 0.202 | 0.355 |
| cross_domain_leakage | 0.267 | 0.694 | 0.522 |
| token_cost avg | 5 069 | 44 846 | 37 547 |
| latency avg | 786 | 564 | 577 ms |
| router_precision / recall / categories / spurious | 0.667 / 0.650 / 0.800 / 2 | idéntico (Δ=0) | idéntico (Δ=0) |

### Por query — desglose de agujas (v3)

| ID | and | or | and-norm | lectura |
|---|---|---|---|---|
| Q03 | — | `gh pr create` gold (Commands.md) | — | puente semántico real (`crear`↔`create`), no lo resuelve ninguna variante |
| Q04 | — | `xset` en CONTINUE.md (other) | **`xset -dpms` + `xset s off` GOLD (CHANGELOG.md)** | **RESUELTO por and-norm con gold corregido** |
| Q06 | — | `com.dts.freefireth` en CONTINUE.md (other) | `com.dts.freefireth` en CONTINUE.md (other); FF_SEEN no_match en las 3 | problema de ranking (trae CONTINUE.md, no scrcpy.md) + FF_SEEN sin recuperar |
| Q08 | — | `picom` en AGENTS.md (other) | `picom` en AGENTS.md (other); P_TERM_OPACITY no_match | puente técnico real (`opaca/transparente`↔`picom`), gold correcto (System.md:3/78) |

### Lectura

1. **Q04 era 100 % fixture, no retrieval.** La evidencia existía y **and-norm la recuperaba**;
   el gold apuntaba al archivo equivocado → contaba como `other_file_match`. Con el gold
   corregido, and-norm recupera Q04 completo. **Invalida parcialmente la conclusión del
   Paso 4** ("and-norm no captura el puente léxico"): el mecanismo SÍ lo captura cuando el
   fixture declara la fuente correcta.
2. **and-norm queda como la mejor variante sobre gold corregido**: search_recall 0.100 (vs
   or 0.050, and 0.000), leakage 0.522 (vs or 0.694) y tokens 37.5k (vs or 44.8k). Sigue por
   debajo del umbral aspiracional (≥ 0.150) pero es la única que convierte un caso de
   fact-retrieval completo en recuperación gold válida.
3. **El problema de retrieval restante es real, específico y medible con gold correcto:**
   - Q03/Q08 → puente semántico/técnico (aguja en archivo gold, cero overlap léxico).
   - Q06 → el ranking trae CONTINUE.md y no scrcpy.md (gold); FF_SEEN no se recupera ni
     siendo gold (CHANGELOG.md:186 comparte tokens `scrcpy`/`free`/`fire` pero el snippet
     no llega al top).
4. **Router intacto en las 3 corridas (Δ=0)** — el problema sigue acotado a la capa Search.

### Estado tras el Paso 6

- Artefactos v3: `baseline-and-PC-2026-08-11.json`, `baseline-or-PC-2026-08-11.json`,
  `baseline-and-norm-PC-2026-08-11.json` (nombres planos; los v2 `baseline-A/B/C-andnorm`
  quedan en git history).
- **No se adoptó ninguna variante.** La comparación limpia es la base para decidir el
  próximo experimento (Hybrid o no) con datos que ya no mezclan fixture con retrieval.
- Runtime congelado: `buffy-search.sh`/`buffy-router.sh` sin tocar.

## 🔎 Paso 6b — Auditoría específica de Q06 + gold definitivo · 2026-08-11

**Motivo:** antes de diseñar el experimento semántico, resolver si Q06 es otro caso de
gold incompleto/múltiple. La query Q06 ("el script bash de scrcpy no abre free fire,
revisá el script") pretende recuperar el hecho `FF_SEEN` (cambio del script).

### Evidencia verificada

| Fuente | ¿Contiene FF_SEEN / watchdog / auto-open? |
|---|---|
| `Knowledge/Android/scrcpy.md` | ❌ **NO.** Solo `com.dts.freefireth:57` (diagnóstico de lag) y `am start:82` (teclado). Es referencia de comandos scrcpy, NO documenta el script. |
| `ai-context/CHANGELOG.md:186` | ✅ Documenta el cambio (sin auto-open + watchdog FF_SEEN). |
| `ai-context/CONTINUE.md:448` | ✅ Documenta el watchdog FF_SEEN. |
| `~/scripts/scrcpy-freefire.sh:272-276` | ✅ Fuente primaria real (watchdog FF_SEEN) — fuera del corpus del benchmark. |

### Veredicto

**Q06 era otro caso de gold incompleto/múltiple.** El gold mezclaba dos agujas de
naturaleza distinta:
- `FF_SEEN` → hecho central (cambio del script) → vive en CHANGELOG.md/CONTINUE.md.
- `com.dts.freefireth` → paquete tangencial (evidencia de "Free Fire", NO del cambio
  del script) → vive en scrcpy.md:57.

**Gold definitivo Q06:** `gold_files = [ai-context/CHANGELOG.md]`,
`gold_facts = [FF_SEEN]`. `com.dts.freefireth` quitado del gold (no es el hecho
evaluado). Nuevo hash del fixture: `98a0e3082d920e71a30b1f1a759332808a251f9d02b899a7db3e2604369b34ac`.

### A/B/C regenerados con gold definitivo (instrumento v3.1)

| métrica | A (and) | B (or) | C (and-norm) |
|---|---|---|---|
| search_recall (gold) | 0.000 | 0.050 | **0.100** |
| search_other_recall | 0.000 | 0.150 | 0.050 |
| search_recall_raw | 0.000 | 0.200 | 0.150 |
| context_relevance | 0.533 | 0.182 | 0.333 |
| cross_domain_leakage | 0.267 | 0.694 | 0.522 |
| token_cost avg | 5 197 | 45 259 | 38 017 |
| latency avg | 900 | 525 | 538 ms |
| router_precision / recall | 0.600 / 0.600 | idéntico (Δ=0) | idéntico (Δ=0) |

> ⚠️ Nota de entorno: `router_precision/recall` bajaron de 0.667/0.650 (v3) a
> 0.600/0.600 (v3.1) — el router NO lee el fixture; es variabilidad de entorno
> (detección de dispositivo/CWD). No afecta la comparación de Search (Δ=0 entre
> estrategias en la misma corrida).

### Lectura tras gold definitivo

1. **search_recall se mantiene** (0.000/0.050/0.100): Q06 no se recuperaba como gold
   en ninguna variante → el cierre del gold no cambia el recall, pero **elimina el
   ruido de `com.dts.freefireth` como aguja** (other baja: or 0.200→0.150,
   and-norm 0.100→0.050).
2. **El gap de retrieval restante es exactamente Q03/Q06/Q08** — los tres casos que
   el experimento semántico debe atacar.
3. **context_relevance de A baja a 0.533** (antes 0.600): Q06 con gold de 1 archivo
   reduce el overlap del router. Sigue siendo el más limpio.

## 📋 Paso 7 — Experimento semántico diagnóstico · ⏳ DISEÑO (2026-08-11)

**Spec:** `scripts/tests/evals/semantic-retrieval-DESIGN.md` (completa y reproducible).

**Pregunta:** ¿un retrieval semántico puede recuperar Q03/Q06/Q08 sin reproducir el
nivel de leakage y coste de OR?

**Invariantes:** MISMO EVAL (hash `98a0e308…`), MISMAS QUERIES, MISMO GOLD, MISMO
LIMIT, MISMAS MÉTRICAS. Cambia UNA variable: lexical → semantic.

**Enfoque:** Ollama local (ya instalado) + modelo `bge-m3` (multilingüe, default) o
`nomic-embed-text` (sanity). Embeddings por línea → coseno → top-LIMIT. Runner nuevo
`run-semantic-PC.sh` — NO toca runtime ni router.

**Gate pre-fijado (todos obligatorios):** search_recall **> 0.100** ·
context_relevance **≥ 0.600** · leakage **≤ 0.267** · token **≤ ~2× A (≈10.4k)** ·
latencia reportada · determinismo (2 corridas) · mismo EVAL hash.

**Criterio de lectura:** benchmark↑+EVAL↑ = fuerte (considerar Hybrid) ·
benchmark↑+EVAL↓ = DESCARTAR · EVAL↑+benchmark↓ = investigar.

**NO adoptar todavía** — experimento diagnóstico; veredicto = usuario.

---

## 🔬 Paso 7 — EJECUTADO · D (bge-m3, embeddings por línea + coseno) · 2026-08-12

**Aprobado por el usuario (2026-08-12):** spec aprobada tal cual, gate pre-fijado sin
relajación, per-query obligatorio (foco Q03/Q06/Q08), UNA variable (semantic), sin
`nomic-embed-text` salvo fallo reproducible de bge-m3 (no ocurrió). Orden autorizado:
pull modelo → runner → verificar → corrida → determinismo → comparar → registrar →
commit+push → detenerse.

**Ejecución:** `ollama pull bge-m3` (1.2 GB) → `run-semantic-PC.sh --model bge-m3
--limit 10`. Índice: 46 archivos / 6 880 líneas / dim 1024, construido en ~38 min en
CPU (~3.3 líneas/s), cacheado en `~/.cache/buffy-eval-semantic/`. Runner nuevo
(`run-semantic-PC.sh`, instrumento v3.1 idéntico al lexical). Runtime congelado
(`runtime_changed: false`). **Gates: G1 ✅** (EVAL hash `98a0e308…` verificado),
**G2 ✅ determinismo** (2 corridas → determinism_hash `046fc9ee…` idéntico, cache
1ª corrida no / 2ª sí), **G3 ✅** (mismo EVAL que A/B/C).

### Agregado — A vs B vs C vs D

| métrica | A (and) | B (or) | C (and-norm) | **D (semantic)** |
|---|---|---|---|---|
| search_recall (gold) | 0.000 | 0.050 | 0.100 | **0.200** |
| search_other_recall | 0.000 | 0.150 | 0.050 | 0.083 |
| search_recall_raw | 0.000 | 0.200 | 0.150 | **0.283** |
| context_relevance | **0.533** | 0.182 | 0.333 | 0.192 |
| cross_domain_leakage | **0.267** | 0.694 | 0.522 | 0.669 |
| token_cost avg | **5 197** | 45 259 | 38 017 | 47 980 |
| token_cost p95 | 40 881 | 69 808 | 69 433 | 77 651 |
| latency avg | 900 ms | 525 ms | 538 ms | 1 449 ms |
| router_precision / recall | 0.600 / 0.600 | idéntico (Δ=0) | idéntico (Δ=0) | idéntico (Δ=0) |
| categories_recall | 0.800 | 0.800 | 0.800 | 0.800 |
| spurious_categories | 2 | 2 | 2 | 2 |
| window_utilization | 2.6% | 22.6% | 19.0% | 24.0% |

> ⚠️ Nota de entorno: router_* vuelve a 0.600/0.600 (Δ=0 entre estrategias en la misma
> corrida; el router no lee el fixture — variabilidad de detección de dispositivo/CWD).

### Por query — desglose gold_facts_matches (D)

| ID | sRec | sOth | agujas gold | resultado |
|---|---|---|---|---|
| Q01 | 0.0 | 0.0 | adb tcpip 5555 / adb connect | no_match |
| Q02 | 0.0 | 0.333 | rish -c / moe.shizuku / pm grant | `rish -c` → other (CONTINUE.md) |
| Q03 | 0.0 | 0.0 | git push origin / gh pr create | **no_match ambas** — el puente ES→EN no lo captura |
| Q04 | **1.0** | 0.0 | xset -dpms / xset s off | **GOLD (CHANGELOG.md)** — resuelto, igual que C |
| Q05 | 0.0 | 0.0 | useState / adb devices -l | no_match |
| Q06 | **1.0** | 0.0 | FF_SEEN | **GOLD (CHANGELOG.md)** — ÚNICA variante que lo resuelve |
| Q07 | 0.0 | 0.0 | dumpsys thermalservice / force_gpu_rendering | no_match |
| Q08 | 0.0 | 0.5 | picom / P_TERM_OPACITY | `picom` → other (AGENTS.md); P_TERM_OPACITY no_match |
| Q09 | 0.0 | 0.0 | scaling_governor / force_gpu_rendering | no_match |
| Q10 | 0.0 | 0.0 | dumpsys thermalservice / thermal_control | no_match |

### Hallazgos

1. **D mejora el recall gold (0.100 → 0.200) resolviendo Q06** — el caso que ninguna
   variante léxica resolvía (`FF_SEEN` en CHANGELOG.md como gold_file_match). Q04 ya
   lo resolvía C; D lo mantiene.
2. **Q03 y Q08 NO se resuelven** — el puente semántico que motivó el experimento
   (`crear`↔`create` en Q03; `opaca/transparente`↔`picom` en Q08) **no lo captura
   bge-m3 por línea**: Q03 no_match ambas agujas; Q08 `picom` cae en AGENTS.md
   (other) y `P_TERM_OPACITY` no_match. La granularidad por línea + coseno no
   reconstruye el salto concepto → término técnico.
3. **El coste destruye la mejora** — D se comporta como OR: leakage 0.669 (≈OR 0.694),
   token avg 48k (≈OR 45k), context_relevance 0.192 (≈OR 0.182). El modelo semántico
   recupera la aguja gold de Q04/Q06 pero arrastra el repositorio al top-10 igual que OR.
4. **Latencia alta**: 1 449 ms avg (vs ~550 ms de A/B/C) — el embed de cada query
   domina. Con cache del índice la segunda corrida fue igual de lenta en queries.

### Veredicto del gate (pre-fijado, sin relajación)

| Criterio | Umbral | D | ¿Pasa? |
|---|---|---|---|
| search_recall | **> 0.100** | 0.200 | ✅ |
| context_relevance | **≥ 0.600** | 0.192 | ❌ |
| cross_domain_leakage | **≤ 0.267** | 0.669 | ❌ |
| token_cost | **≤ ~10.4k** | 47 980 | ❌ |
| determinismo (G2) | 2 corridas idénticas | ✅ | ✅ |
| EVAL hash | `98a0e308…` | ✅ | ✅ |

**D NO pasa el gate** (3 de 4 umbrales de calidad/coste fallan). Es exactamente el
escenario "fracaso" que el usuario anticipó en la aprobación: *"recall espectacular
pero relevance/leakage/tokens colapsan"*. Según el criterio de lectura §7:
**EVAL↑ (recall) + EVAL↓ (calidad/coste) → el patrón de D es el de OR: recupera más,
no resuelve el trade-off.** El semantic naive por línea NO es la pieza que falta
para Q03/Q08, y su coste lo descarta como reemplazo directo.

**NO se adopta nada.** Runtime congelado. La evidencia de D apunta a que el problema
de Q03/Q08 no es de granularidad por línea: el salto ES→EN y concepto→término técnico
necesita otra aproximación (¿documento completo? ¿passage reranking? ¿hybrid con
fusión acotada de candidatos?). Siguiente decisión del usuario.

## ✅ Paso 7 — CERRADO · D descartado · 2026-08-12

**Veredicto del usuario (2026-08-12):** el resultado es útil aunque D haya fallado el gate.
D demuestra que **la capacidad semántica existe** (Q06 recuperado por primera vez) pero
que **el retrieval semántico puro no tiene precisión suficiente para ser buscador final**.

**Lectura oficial del usuario (transcrita):**

> | Estrategia | Recall | Relevance | Leakage | Tokens |
> |---|---|---|---|---|
> | AND | 0.000 | **0.533** | **0.267** | **5.2k** |
> | OR | 0.050 | 0.182 | 0.694 | 45.3k |
> | AND-norm | 0.100 | 0.333 | 0.522 | 38.0k |
> | **Semantic D** | **0.200** | 0.192 | 0.669 | 48.0k |
>
> - Léxico: bueno en precisión/coste/leakage/terminología exacta; pierde sinónimos,
>   traducciones, conceptos→herramientas, queries naturales.
> - Semántico: bueno en recuperar evidencia sin vocabulario compartido (Q06 lo
>   demuestra); malo como resultado final (leakage, relevancia, coste).
> - **Candidate generation ≠ final retrieval**: cada mecanismo debería hacer aquello
>   en lo que demostró ser bueno → diseño del siguiente experimento (Paso 8).
> - Q03/Q08 ni siquiera entran al pool semántico → la unión naive de candidatos
>   NO puede resolverlos; el Paso 8 debe incluir hipótesis de expansión/
>   representación de consulta o granularidad distinta.

**Decisión:** Paso 7 cerrado · D descartado · runtime permanece congelado · siguiente
paso: **diseñar el experimento Hybrid bounded candidate retrieval (Paso 8), sin
implementarlo** hasta fijar candidatos, presupuesto, fórmula de fusión/reranking y
gates. Spec: `scripts/tests/evals/hybrid-bounded-DESIGN.md`.

**Evidencia adicional para el diseño (candidate availability, medida 2026-08-12):**
con el índice semántico de D, los ranks de las agujas gold objetivo son:

| Query | Aguja | Rank semántico (de 6 880) | ¿en pool ≤ 50? |
|---|---|---:|---|
| Q03 | git push origin | 254 | ❌ |
| Q03 | gh pr create | 200 | ❌ |
| Q08 | picom | 2 553 | ❌ |
| Q08 | P_TERM_OPACITY | 266 | ❌ |

→ **G-H0 (pre-gate de candidate availability)**: por query, verificar que las agujas
gold están dentro del candidate pool ANTES de atribuir el resultado a la fusión/rerank.
Q03/Q08 fallarían G-H0 por construcción → la fusión sola no los resuelve.

## 🔬 Paso 8 — EJECUTADO · E y F no pasan el gate · 2026-08-12

**Autorizado por el usuario (2026-08-12):** implementar runner → ejecutar G-H0 → medir
RRF → medir POOL → registrar → detenerse. Sin tocar `buffy-search.sh`, `buffy-router.sh`
ni convertir ninguna estrategia en default.

**Runner:** `scripts/tests/evals/run-hybrid-PC.sh` — rama L (OR top-50 de `buffy-search.sh`
+ gate co-ocurrencia ≥2 tokens, N_L=50) + rama S (índice bge-m3 de D, N_S=50) → pool
dedup por `(path, lineno)` → fusión V1 (RRF k=60 | POOL rank⁻¹) → presupuesto 10 400
tokens → top-10 → métricas v3.1 + G-H0 por aguja. Determinismo G2: hash idéntico en 2
corridas por variante (E `06056504…`, F `337f4ac8…`). Instrumento v3.1, EVAL `98a0e308…`.

### Resultados agregados (gold definitivo, v3.1)

| Estrategia | Recall | Relevance | Leakage | Tokens avg | Tokens p95 |
|---|---:|---:|---:|---:|---:|
| A — AND | 0.000 | **0.533** | **0.267** | **5 197** | 40 881 |
| B — OR | 0.050 | 0.182 | 0.694 | 45 259 | 71 538 |
| C — AND-norm | 0.100 | 0.333 | 0.522 | 38 017 | 71 163 |
| D — Semantic | 0.200 | 0.192 | 0.669 | 47 980 | 77 651 |
| **E — Hybrid-RRF** | **0.200** | 0.185 | 0.605 | **9 951** | **10 379** |
| **F — Hybrid-POOL** | **0.200** | 0.179 | 0.612 | **10 039** | **10 384** |

### Gate (pre-fijado, 4 criterios simultáneos) — E y F

| Criterio | Umbral | E | F | ¿Pasa? |
|---|---|---:|---:|---|
| search_recall | > 0.100 | 0.200 | 0.200 | ✅ |
| context_relevance | ≥ 0.600 | 0.185 | 0.179 | ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.605 | 0.612 | ❌ |
| token_cost | ≤ ~10.4k | 9 951 | 10 039 | ✅ |

→ **E y F NO pasan el gate** (relevance y leakage). La fusión bounded controla el
**coste** (tokens 9.9-10.0k, ~4.8× menos que D, dentro del gate) pero **hereda el
ruido de la rama semántica** en el ctx (leakage 0.6, relevance 0.18). Veredicto:
**la fusión naive de candidatos acotada no se adopta** — misma conclusión que D/OR.

### G-H0 (diagnóstico por aguja, idéntico en E y F — mismo pool)

```text
in_pool_top10=5 · in_pool_ranked_out=3 · in_pool_budget_cut=1 · out_of_pool=11 · not_in_corpus=0
```

| Query | Aguja | G-H0 | Interpretación |
|---|---|---|---|
| Q03 | git push origin / gh pr create | `out_of_pool` ×2 | **candidate gap confirmado**: la fusión NO puede resolver Q03 (ni L ni S generan la aguja) |
| Q04 | xset -dpms / xset s off | `in_pool_top10` ×2 | recuperada (sRec=1.0) — pero cRel=0.0 (ver hallazgo de presupuesto) |
| Q06 | FF_SEEN | `in_pool_top10` | **capacidad semántica conservada**: la fusión mantiene lo que D logró |
| Q08 | picom | `in_pool_top10` (other_file_match) | **la rama L genera la aguja** (antes rank 2553 semántico) pero el gold file (`Knowledge/Linux/System.md`) no queda en el top-10 → fallo del rerank |
| Q08 | P_TERM_OPACITY | `in_pool_budget_cut` | disponible en pool pero cortado por presupuesto |
| Q01/Q05/Q07/Q09/Q10 | resto | `out_of_pool` | candidate gap (ninguna rama las genera) |

### Hallazgos

1. **El presupuesto es menor que el gold canónico**: el gold de Q04/Q06
   (`ai-context/CHANGELOG.md`, 57.5k chars ≈ 14.4k tokens) no cabe en el presupuesto
   de 10.4k tokens → el archivo completo entra en el ctx SOLO hasta agotar presupuesto
   → cRel=0.0 con sRec=1.0 (la aguja está en el top-10 pero el archivo gold no entra al
   ctx). Riesgo 3 del diseño, materializado y medido.
2. **G-H0 separa correctamente candidate gap vs fallo de rerank**: Q03 = candidate
   gap (nunca generada), Q08 picom = generada pero rankeada fuera (el pool la tiene,
   el top-10 no). La atribución diagnóstica funciona.
3. **La rama L aporta algo que la semántica no tiene**: Q08 `picom` entra al pool vía
   OR léxico (D ni lo generaba). Pero el top-10 fusionado la pierde → el rerank no
   compensa el ranking del pool.
4. **Q03/Q05/Q07/Q09/Q10 siguen siendo candidate gaps** — la fusión no crea
   capacidad de generación, solo reordena lo generado.

### Conclusión

La hipótesis central (candidate generation ≠ final retrieval) se confirma **parcialmente**:
la fusión bounded produce un top-10 final con coste controlado (~10k tokens) y conserva
la recuperación de Q04/Q06, PERO no controla la calidad del ctx (leakage 0.6). El límite
no es el coste ni la generación: es el **ctx final por archivo completo** + el **rerank**
que no puede separar agujas gold de ruido. La evidencia apunta a que el siguiente
nivel es **query expansion (Q03/Q08)** y/o **granularidad del ctx distinta** (pasajes,
no archivos enteros) — fuera del alcance de este paso. Runtime sigue congelado.

## ✅ Paso 8 — CERRADO · E/F descartados · 2026-08-12

**Veredicto del usuario (2026-08-12, transcrito):** el Hybrid bounded V1 NO es
adoptable. El diagnóstico es más interesante que "falló el gate":

> | | AND | AND-norm | Semantic | Hybrid |
> |---|---|---|---|---|
> | Recall | 0.000 | 0.100 | **0.200** | **0.200** |
> | Relevance | **0.533** | 0.333 | 0.192 | 0.185 |
> | Leakage | **0.267** | 0.522 | 0.669 | 0.605 |
> | Tokens | **5.2k** | 38k | 48k | **~10k** |
>
> **El presupuesto ya no es el problema principal**: el Hybrid redujo ~4.8× el coste de
> D pero no recuperó la calidad del contexto → descarta "mezclar mejor las ramas".
>
> Hay DOS problemas distintos, medibles por G-H0:
>
> 1. **Candidate generation** — Q03 y varias queries más son `out_of_pool`: ni RRF ni
>    rank⁻¹ pueden solucionarlas → se necesita **query expansion / representación
>    alternativa de la consulta** (más adelante, no ahora).
> 2. **Context selection** — Q08: `picom` SÍ entra al pool vía rama léxica pero queda
>    fuera del top-10 (generación ✅ pool ✅ fusión ❌ contexto ❌) → problema real de
>    selección. Y Q04/Q06 revelan el problema estructural:
>
>    ```
>    gold encontrado → top-10 → archivo correcto → 14.4k tokens → budget=10.4k
>    → archivo truncado → context_relevance = 0
>    ```
>
> **Decisión:** Paso 8 cerrado · E/F descartados · runtime intacto · NO implementar
> todavía query expansion. **Primero diseñar Paso 9: passage-level context selection**
> (cambiar la unidad de contexto de archivo completo a pasajes), con gate nuevo que
> mida: recuperación del hecho · relevancia del pasaje · leakage · tokens · capacidad
> de contener el gold dentro del presupuesto. Spec: `scripts/tests/evals/passage-level-DESIGN.md`.
>
> **Evidencia de viabilidad (medida 2026-08-12):** los gold facts de Q04/Q06 viven en
> CHANGELOG.md (14 375 tok completo) en ventanas de pocas líneas:
>
> | Query | Gold completo | Ventana ±4 del hecho | Sección markdown |
> |---|---|---:|---:|
> | Q04 | 14 375 tok | **505 tok** (líneas 199-213) | 1 266 tok |
> | Q06 | 14 375 tok | **310 tok** (líneas 182-194) | 376 tok |
> | Q01-Q10 Knowledge/* | 492-1 493 tok | 58-700 tok | — |
>
> → entregar `CHANGELOG.md:199-213` (~500 tok) en vez del archivo completo elimina
> truncamiento, coste, ruido interno y pérdida de relevancia de golpe.

## 🔬 Paso 9 — EJECUTADO · G1 y G2 no pasan el gate (relevance/leakage) · 2026-08-12

**Autorizado por el usuario (2026-08-12):** implementar runner → verificar G-H0 →
ejecutar G1 → ejecutar G2 → determinismo → comparar contra gates → registrar →
commit → detenerse. Sin query expansion, sin tocar `buffy-search.sh`/`buffy-router.sh`,
sin pesos/calibración/modelos nuevos/EVAL modificado.

**Runner:** `scripts/tests/evals/run-passage-PC.sh` — ramas L/S idénticas a E/F (misma
fusión V1-RRF k=60), pero cada hit del top-10 se expande a un **pasaje**: G1-VENTANA
(`[lineno-4, lineno+4]`, 9 líneas) o G2-SECCIÓN (bloque entre headings `#{1,3}`).
ctx = router ∪ pasajes(top-10) con **dedup por (path, rango)** (permitiendo MÚLTIPLES
pasajes del mismo archivo — corregido en review), presupuesto 10.4k sobre el
**pasaje** (chars/4), métricas v3.1 + `passage_relevance` + `gold_containment` +
G-H0 re-derivado sobre pasajes. Determinismo G2: hashes idénticos en 2 corridas por
variante (G1 `b7d17efd…`, G2 `528fe12a…`). Instrumento v3.1, EVAL `98a0e308…`,
`snippet_scope: passage`.

### Resultados agregados (gold definitivo, v3.1)

| Estrategia | Recall | pRel | cRel(file) | Leakage | Tokens avg | gold_containment |
|---|---:|---:|---:|---:|---:|---:|
| A — AND | 0.000 | — | 0.533 | 0.267 | 5 197 | — |
| C — AND-norm | 0.100 | — | 0.333 | 0.522 | 38 017 | — |
| D — Semantic | 0.200 | — | 0.192 | 0.669 | 47 980 | — |
| E — Hybrid-RRF | 0.200 | — | 0.185 | 0.605 | 9 951 | 0.0 (Q04/Q06) |
| F — Hybrid-POOL | 0.200 | — | 0.179 | 0.612 | 10 039 | 0.0 (Q04/Q06) |
| **G1 — VENTANA** | **0.417** | 0.072 | 0.214 | 0.606 | **2 569** | **0.8** |
| **G2 — SECCIÓN** | 0.333 | 0.054 | 0.214 | 0.606 | **3 373** | 0.7 |

> ⚠️ Tokens de G1/G2 **no comparables** con A-F (unidad = pasaje, no archivo): se
> reporta `tokens_if_fullfile` secundaria (43.8k media, misma base que A-F).

### Gate (5 criterios simultáneos) — G1 y G2

| Criterio | Umbral | G1 | G2 | ¿Pasa? |
|---|---|---:|---:|---|
| search_recall | > 0.100 | 0.417 | 0.333 | ✅ (mejor de la serie) |
| passage_relevance | ≥ 0.600 | 0.072 | 0.054 | ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.606 | 0.606 | ❌ |
| token_cost | ≤ ~10.4k | 2 569 | 3 373 | ✅ |
| gold_containment | ≥ 0.80 | 0.8 | 0.7 | ✅/❌ (justo/falta) |

→ **G1 y G2 NO pasan el gate** (passage_relevance y leakage fallan). El pasaje
resuelve el problema de PRESUPUESTO (gold_containment de Q04/Q06 = 1.0, tokens ~2k)
pero NO el de CALIDAD del ctx: los pasajes no-gold del top-10 siguen dominando.

### G-H0 adaptado (por aguja, sobre pasajes)

| Query | Aguja | G1 | G2 | Interpretación |
|---|---|---|---|---|
| Q04 | xset -dpms / xset s off | `in_pool_top10` ×2 | `in_pool_top10` ×2 | **gold entregado en pasaje CHANGELOG.md:199-207 (~505 tok)** — el truncamiento estructural del Paso 8 queda RESUELTO |
| Q06 | FF_SEEN | `in_pool_top10` | `in_pool_top10` | gold en CHANGELOG.md:186-194 (~310 tok) — idem |
| Q03 | git push origin | `in_pool_ranked_out` | `in_pool_ranked_out` | **cambio respecto a E/F**: con pasajes la aguja SÍ entra al pool (cerca de hits) pero queda rankeada fuera; gh pr create sigue `out_of_pool` |
| Q08 | picom / P_TERM_OPACITY | `in_pool_top10` ×2 (other_file_match) | idem | **el pasaje no arregla la selección**: el gold file (System.md) sigue fuera del top-10; los pasajes que entran son de ai-context no-gold |
| Q01/Q10 | resto | `out_of_pool` | `out_of_pool` | candidate gap (Paso 10) |

### Hallazgos

1. **La unidad de contexto SÍ era parte del problema**: Q04/Q06 pasan de
   gold_containment 0.0 (E/F: archivo de 14.4k no cabía) a 1.0 (G1/G2: pasaje de
   310-505 tok cabe y se entrega con sRec=1.0). La hipótesis de pasaje se confirma
   para el problema de presupuesto.
2. **El recall sube a 0.417 (G1) — el mejor de toda la serie**: el matching sobre
   pasaje (no línea) captura agujas que el snippet por línea perdía (Q02 sube a
   0.667, Q05/Q07/Q09 a 0.5).
3. **PERO passage_relevance (0.072/0.054) y leakage (0.606) no mejoran**: el top-10
   fusionado sigue trayendo pasajes de archivos no-gold (SESION-archive, CONTINUE,
   etc.) que dominan el ctx. El pasaje arregla el TAMAÑO, no la SELECCIÓN.
4. **Q08 confirma el límite del paso**: `picom` entra al pool y al top-10, pero el
   gold file (`Knowledge/Linux/System.md`) queda fuera del top-10 → los pasajes
   entregados son de archivos no-gold. Problema de rerank/selección, no de tamaño.
5. **G1 > G2 en recall (0.417 vs 0.333) y gold_containment (0.8 vs 0.7)**: la
   ventana ±4 es más precisa que la sección (que infla pasajes con ruido interno —
   p.ej. sección 196-329 de CONTINUE.md en G2-Q04).
6. **Corrección metodológica post-review**: la primera versión deduplicaba el ctx
   por path (solo 1 pasaje por archivo entraba — herencia del runner híbrido); se
   corrigió a dedup por (path, rango) permitiendo múltiples pasajes del mismo
   archivo (Q04-G1 pasó de 3 a 10 pasajes de ctx, pRel 0.333→0.2 per-query). Las
   conclusiones cualitativas no cambian; los números del registro son los corregidos.

### Conclusión

El Paso 9 demuestra que **cambiar la unidad de contexto de archivo a pasaje es
NECESARIO pero NO SUFICIENTE**: elimina el truncamiento estructural (Q04/Q06) y
mejora el recall (0.417), pero el gate exige además calidad del ctx (relevance ≥
0.6, leakage ≤ 0.267) y los pasajes no-gold del top-10 la hunden igual que en D/E/F.
El límite se movió de "cómo entrego el gold" a "**qué pasajes selecciono**".
Evidencia para el siguiente nivel (Paso 10): **query expansion** para candidate gap
(Q03/Q01/Q10) y **selección/rerank de pasajes** para Q08. Runtime sigue congelado;
nada se adopta.

## ✅ Paso 9 — CERRADO · G1/G2 no adoptados · passage-level VALIDADO como componente · 2026-08-12

**Veredicto del usuario (2026-08-12):** el experimento cumplió su objetivo aunque
ambas variantes fallaron el gate. Conclusión central:

> Pasar de archivo completo a pasajes SÍ fue una mejora arquitectónica real, pero no
> resuelve por sí solo la selección del pasaje correcto.

Esto evita el error de ver Q04/Q06 funcionando y concluir que "passage retrieval está
resuelto".

### Separación de problemas (lo que el EVAL dibujó)

| Problema | Evidencia | Estado |
|---|---|---|
| Archivo completo demasiado grande | Q04/Q06: 14.4k → pasajes de 310-505 tok | 🟢 Resuelto conceptualmente |
| Recuperar evidencia correcta | G1 recall 0.417 | 🟢 Mejoró mucho |
| Selección de evidencia | Q08 llega al pool/top-10, pero no el gold | 🔴 Pendiente |
| Candidate generation | Q03 `gh pr create` sigue `out_of_pool` | 🔴 Pendiente |
| Coste | 2.6k / 3.4k tok | 🟢 Excelente |
| Leakage | 0.606 | 🔴 Pendiente |
| Passage relevance | 0.072 / 0.054 | 🔴 Serio pendiente |

La preocupación principal NO es el recall: es **passage_relevance 0.072/0.054** frente
al objetivo 0.600 y **leakage 0.606** — el sistema selecciona pasajes que cumplen
algún criterio de similitud pero no son evidencia útil.

### Mapa de fallas por query (tres capas distintas)

- **Q03 → generación**: `gh pr create` no aparece en el pool; ningún reranker puede
  arreglar un candidato que no se genera.
- **Q08 → ranking**: `picom` entra al pool y al top-10, pero System.md (gold) queda
  fuera del top-10 → aquí SÍ existe oportunidad real de mejora de ranking.
- **Q04/Q06 → contexto**: pasaje pequeño con gold completo dentro del presupuesto →
  **RESUELTO** por passage-level (gold_containment 1.0).

### Lo que NO se hará (listado por el usuario)

No volver a: aumentar top-10 · subir top-50 · meter más embeddings · aumentar
presupuesto · volver a OR · tocar pesos de RRF arbitrariamente · aceptar leakage alto
a cambio de recall. Ya hay evidencia de que **más candidatos no equivalen a mejor
contexto**.

### Estado de Fase 3 (serie completa)

| Estrategia | Recall | Relevance | Leakage | Tokens avg | Estado |
|---|---:|---:|---:|---:|---|
| A — AND | 0.000 | 0.533 | 0.267 | 5.2k | ❌ |
| B — OR | 0.050 | 0.182 | 0.694 | 45.3k | ❌ |
| C — AND-norm | 0.100 | 0.333 | 0.522 | 38.0k | ❌ |
| D — Semantic | 0.200 | 0.192 | 0.669 | 48.0k | ❌ |
| E — Hybrid-RRF | 0.200 | 0.185 | 0.605 | 9.9k | ❌ |
| F — Hybrid-POOL | 0.200 | 0.179 | 0.612 | 10.0k | ❌ |
| G1 — VENTANA | 0.417 | 0.072 | 0.606 | 2.6k | ❌ gate |
| G2 — SECCIÓN | 0.333 | 0.054 | 0.606 | 3.4k | ❌ gate |

Pero: **passage-level → hipótesis confirmada ✅** · Q03 → candidate-gap 🔴 · Q08 →
ranking/selection gap 🔴 · Q04/Q06 → context-size problem 🟢.

### Decisión

**Fase 3 NO se cierra todavía.** El Paso 9 produce evidencia suficiente para el
siguiente experimento: **Query Expansion (Paso 10)**, aislado y con gates pre-fijados
— sin implementar todavía. El reranking de pasajes queda como **otra hipótesis
separada** (Q08: existe un candidato correcto que el sistema no sabe priorizar). El
usuario aprueba además la corrección del dedup a (path, rango) hecha durante la
implementación: evitó que el experimento quedara contaminado por una violación de su
propia spec.

## 🔬 Paso 10 — EJECUTADO · H1 y H2 no pasan el gate (pRel/leakage) · 2026-08-12

**Runner:** `scripts/tests/evals/run-expansion-PC.sh` · dicts H1/H2 congelados
(dict_hash `b0406a3368003bea`, incluido en el JSON) · pasajes VENTANA ±4 (G1) ·
presupuesto 10.4k · fusión V1-RRF · EVAL 98a0e308… · instrumento v3.1 ·
`runtime_changed: false`. Determinismo G2 OK ×2 por variante (H1 `3618caf4…`,
H2 `e942eadc…`). Referencia del gap: G1 (6 agujas out_of_pool, corpus=True).

| Estrategia | Recall | pRel | cRel(file) | Leakage | Tokens | gold_containment |
|---|---:|---:|---:|---:|---:|---:|
| A — AND | 0.000 | — | 0.533 | 0.267 | 5 197 | — |
| C — AND-norm | 0.100 | — | 0.333 | 0.522 | 38 017 | — |
| D — Semantic | 0.200 | — | 0.192 | 0.669 | 47 980 | — |
| E/F — Hybrid | 0.200 | — | 0.185/0.179 | 0.605/0.612 | ~10 000 | 0.0 |
| G1 — VENTANA | **0.417** | 0.072 | 0.214 | 0.606 | 2 569 | 0.8 |
| G2 — SECCIÓN | 0.333 | 0.054 | 0.214 | 0.606 | 3 373 | 0.7 |
| **H1 — DICT-MIN** | 0.317 | 0.064 | 0.199 | 0.616 | 2 451 | **1.0** |
| **H2 — DICT-FULL** | 0.367 | 0.064 | 0.197 | 0.621 | 2 454 | **1.0** |

### Gate (5 criterios simultáneos) — H1 y H2 NO pasan

| Criterio | Umbral | H1 | H2 |
|---|---|---:|---:|
| search_recall | > 0.100 | 0.317 ✅ | 0.367 ✅ |
| passage_relevance | ≥ 0.600 | 0.064 ❌ | 0.064 ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.616 ❌ | 0.621 ❌ |
| token_cost | ≤ ~10.4k | 2 451 ✅ | 2 454 ✅ |
| gold_containment | ≥ 0.80 | 1.0 ✅ | 1.0 ✅ |

### ★ candidate_gap_recovery — el objetivo del paso SÍ se cumplió

| Variante | Fracción | Agujas recuperadas (G1 `out_of_pool` → H `in_pool_*`) |
|---|---|---|
| **H1-DICT-MIN** | **5/6 (0.833)** | `adb tcpip 5555` (X: adb devices) · `adb connect` (X: adb devices) · `gh pr create` (X: **push** — regla de `pushear`) · `dumpsys thermalservice` (X: thermal) · `thermal_control` (X: thermal) |
| **H2-DICT-FULL** | **6/6 (1.0)** | las 5 de H1 + `useState` (X: useState — símbolo exacto, solo H2) |

**El diccionario GENÉRICO (H1) cerró 5/6 del gap.** Q03 `gh pr create` (la aguja
estrella) pasó de `out_of_pool` a `in_pool_ranked_out` **vía la rama X con términos
ES→EN genéricos** (`pushear→push`; `crear→create` también era término X). Solo
`useState` (símbolo de código) requirió el término exacto de H2. Todas las agujas
quedaron `in_pool_ranked_out` (rank de fusión 50-132 — muy fuera del top-10).

### Hallazgo principal: generación resuelta, SELECCIÓN rota (Caso D confirmado)

**Ninguna de las 6 agujas del gap llegó al top-10** → todas quedaron
`in_pool_ranked_out` → Q01/Q03/Q05/Q10 siguen con search_recall 0.0. El recall
global de H1/H2 (0.317/0.367) es **inferior al de G1 (0.417)**:

```text
candidate gap    ✅ resuelto (H1 5/6, H2 6/6)   → generación OK
pool             ✅ agujas DENTRO del pool
fusión/ranking   ❌ RRF no las prioriza → ranked_out
contexto final   ❌ fuera del top-10 → sRec no sube
```

Esto es exactamente el **Caso D** que el usuario anticipó al aprobar la spec:
"H1/H2 recuperan candidatos pero pRel/leakage siguen ~0.07/~0.61 → generación
resuelta, selección todavía rota". Se cumple al pie de la letra.

### Regresión vs G1 (9/12) — el ruido de X desplaza gold del top-10

3 agujas que en G1 estaban `in_pool_top10` salieron del top-10 en H1/H2: Q05
`adb devices -l`, Q07 `dumpsys thermalservice`, Q07 `force_gpu_rendering`. El pool
más grande (1071-1364 hits X únicos vs ~100 de G1) inunda el RRF. Contrapartida
positiva: **Q09 sube 0.5 → 1.0 en H2** (`force_gpu_rendering` pasa de
`ranked_out` a `top10` vía X).

### Otros datos

- **gold_containment 1.0** en ambas (igual que G1 en Q04/Q06) — el pasaje sigue
  siendo la unidad correcta.
- **Costo**: tokens 2.5k ✅ se mantiene; pero **latency sube a ~4.1 s** (59-90
  re-consultas X por corrida vs 1 de la rama L) — coste de la expansión, no gate.
- Q08 sigue sin resolverse (selección — `picom`/`P_TERM_OPACITY` ahora incluso
  `other_file_match` por el ruido de X) — 10B confirmado como hipótesis pendiente.

### Conclusión

H1 y H2 **NO se adoptan** (fallan el gate por pRel/leakage, capa de selección). Pero
el Paso 10 demostró con evidencia: **la expansión léxica cierra el candidate gap
(5/6 con diccionario genérico; 6/6 con términos exactos) y el cuello de botella se
movió al reranking** — las agujas existen en el pool y el RRF no las prioriza. El
**Paso 10B (selección/rerank de pasajes)** queda con una justificación experimental
muy fuerte. Fase 3 sigue abierta; runtime congelado; nada se adopta.

## ✅ Paso 10 — CERRADO · H1/H2 no adoptados · generación resuelta, ranking = cuello de botella · 2026-08-12

**Veredicto del usuario (2026-08-12):** probablemente el resultado más útil de toda
la Fase 3 — aisló casi perfectamente el cuello de botella:

```text
Query expansion → candidate gap ✅ resuelto → pool ✅ → ranking ❌ → top-10 ❌ contexto
```

Y apareció un segundo efecto: **hacer crecer el pool sin cambiar el ranking puede
empeorar el sistema** (regresión 9/12).

| Etapa | Resultado |
|---|---:|
| H1 candidate-gap recovery | 5/6 = 83.3% |
| H2 candidate-gap recovery | 6/6 = 100% |
| H1 / H2 recall global | 0.317 / 0.367 |
| G1 recall | 0.417 |
| Passage relevance | 0.064 |
| Leakage | ~0.62 |
| Tokens | ~2.45k |

### El hallazgo más importante

Las agujas quedan en **rank 50-132** — el problema ya NO es "¿existe una
representación que encuentre la evidencia?" (la respuesta es sí) sino
"**¿cómo distinguimos evidencia útil de los cientos/miles de candidatos
adicionales?**" — un problema de **reranking/context selection**. La regresión 9/12
es la prueba: pool pequeño → RRF → agujas sobreviven; pool expandido (1071-1364
candidatos) → RRF → agujas enterradas.

### Decisiones del usuario

- **NO seguir experimentando con diccionarios** — H2 llegó a 6/6, el techo de
  generación está demostrado.
- **NO otro generador; se necesita un SELECTOR.** El reranker debe trabajar sobre
  candidatos ya generados: **candidate generation = congelado, ranking = única
  variable**.
- Empezar con **reranker diagnóstico sencillo** (no modelo pesado), combinando
  señales gold-independent que Buffy ya tiene: lexical evidence + expansion evidence
  + semantic similarity + proximity/co-occurrence + calidad del documento. **Pesos
  fijados antes de medir**, no ajustados hasta que Q03/Q08 pasen.
- Dos variantes: **R1 — lexical evidence rerank** (tokens significativos,
  co-ocurrencia, proximidad, términos expandidos, posición del match) y **R2 —
  lexical + semantic** (bge-m3 SOLO como señal de ranking, no generador). Responde:
  ¿el embedding falló por malo para recuperar o porque necesitaba estar subordinado
  a señales léxicas más precisas?
- **Atención especial a Q08** (picom: candidate ✅ pool ✅ top-10/pasaje ❌) — si 10B
  sube System.md sin disparar leakage, el reranking es la pieza que falta. Y Q03
  (gh pr create: generado por H1/H2, ranked_out) — si el reranker lo recupera, cadena
  completa: query expansion → candidate → reranking → passage → context.
- **Advertencia anti-sobreajuste**: el objetivo NO es "hacer subir agujas" sino el
  gate completo + **evitar la regresión 9/12** → nueva métrica `baseline_regression`.

### Decisión

**Cerrar Paso 10 como experimento no adoptado y diseñar Paso 10B — Reranking /
Passage Selection.** Sin tocar runtime. Sin ampliar diccionarios. Sin otro
embedding. Sin aumentar presupuesto. Primero aislar ranking. H2 = 6/6 candidate-gap
recovery da permiso experimental: **la información está disponible; ahora hay que
aprender a elegirla.**

### Estado de la Fase 3 (veredicto del usuario)

| Estrategia | Estado |
|---|---|
| A AND · B OR · C AND-norm · D Semantic · E/F Hybrid · G1/G2 Passage · H1/H2 Expansion | ❌ todos |

Pero experimentalmente: **Candidate generation ✅ · Passage granularity ✅ ·
Context-size issue ✅ identificado/resuelto · Ranking/selection 🔴 cuello de botella
actual** — mucho mejor que probar algoritmos a ciegas.

## 🔬 Paso 10B — EJECUTADO · R1 y R2 no pasan el gate (pRel/leakage) · 2026-08-12

**Runner:** `scripts/tests/evals/run-rerank-PC.sh` · pool CONGELADO de H2 (verificado
== H2, dict_hash `b0406a3368003bea`) · señales normalizadas [0,1] pesos 1.0 fijos ·
pasajes VENTANA ±4 · presupuesto 10.4k · EVAL 98a0e308… · instrumento v3.1 ·
`runtime_changed: false`. Determinismo G2 OK ×2 por variante (R1 `8316343e…`,
R2 `06037bab…`). Generación congelada: **el único cambio es el orden del pool**
(RRF → reranker R1/R2).

| Estrategia | Recall | pRel | cRel(file) | Leakage | Tokens | gold_containment |
|---|---:|---:|---:|---:|---:|---:|
| G1 — VENTANA | 0.417 | 0.072 | 0.214 | 0.606 | 2 569 | 0.8 |
| H1 — DICT-MIN | 0.317 | 0.064 | 0.199 | 0.616 | 2 451 | 1.0 |
| H2 — DICT-FULL | 0.367 | 0.064 | 0.197 | 0.621 | 2 454 | 1.0 |
| **R1 — LEX** | **0.750** | 0.175 | 0.175 | **0.441** | **1 903** | **1.0** |
| **R2 — LEX+SEM** | 0.700 | 0.131 | 0.131 | 0.502 | 2 169 | **1.0** |

### Gate (6 criterios simultáneos) — R1 y R2 NO pasan

| Criterio | Umbral | R1 | R2 |
|---|---|---:|---:|
| search_recall | > 0.100 | **0.750** ✅ (récord serie) | 0.700 ✅ |
| passage_relevance | ≥ 0.600 | 0.175 ❌ | 0.131 ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.441 ❌ | 0.502 ❌ |
| token_cost | ≤ ~10.4k | 1 903 ✅ | 2 169 ✅ |
| gold_containment | ≥ 0.80 | 1.0 ✅ | 1.0 ✅ |
| baseline_regression | ≤ 0.167 | **0.167** ✅ (10/12) | **0.083** ✅ (11/12) |

### ★ gap_to_top10 — el objetivo del paso se cumplió en R1

| Variante | gap_to_top10 (H2 = 0/6) | Agujas al top-10 |
|---|---|---|
| **R1-LEX** | **4/6** | Q01 `adb tcpip 5555`/`adb connect` (rank 2, X: adb devices) · Q10 `dumpsys thermalservice`/`thermal_control` (**rank 1**, X: thermal) |
| **R2-LEX+SEM** | 2/6 | solo Q10 ×2 (rank 9) |

Q03 `gh pr create` quedó a **rank 12** (R1) — entró al pool por X (`create`), el
reranker lo acercó de 58→12 pero no al top-10. Q05 `useState` a rank 42 (R1).

### El cuello de botella ERA el ranking

Con el MISMO pool (H2, congelado y verificado) y solo cambiando el orden: **sRec
0.367 → 0.750 (2.0×)**, leakage **0.621 → 0.441**, gap 0/6 → 4/6. El reranker
filtró el ruido de sesión (señal estructural `curated`) y priorizó los ítems con
señal de expansión. Por query (R1): Q01/Q02/Q04/Q07/Q09/Q10 **1.0**, Q03/Q05/Q08
0.5, **Q06 0.0** (FF_SEEN perdida — única regresión por aguja del reranker).

### Ablación — qué señal produce la mejora (diagnóstico, no gate)

| Config | sRec | gap_to_top10 |
|---|---:|---:|
| **r1_full** | 0.750 | 4/6 |
| r1_no_x_overlap | 0.450 | **0/6** ← LA señal crítica |
| r1_no_x_density | 0.750 | 4/6 (sin efecto) |
| r1_no_proximity | 0.750 | 4/6 (sin efecto) |
| r1_no_curated | 0.800 | 2/6 (aporta 2 de las 4) |
| r1_no_q_overlap | 0.700 | **5/6** (¡quitar q_overlap MEJORA el gap!) |
| r2_full | 0.750 | 2/6 |
| **r2_no_sem** | 0.750 | **4/6** ← el embedding EMPEORA la selección |

**`x_overlap` (señal de expansión) es la señal decisiva**: sin ella el gap colapsa
a 0/6. `curated` aporta 2/6. `q_overlap` (tokens crudos de la query) incluso
estorba para el gap (5/6 sin ella).

### Respuesta a la pregunta del usuario sobre bge-m3

> ¿El embedding falló porque era malo para recuperar, o porque necesitaba estar
> subordinado a señales léxicas precisas?

**Ninguna de las dos lo salva como señal de ranking.** R2 < R1 en sRec (0.700 vs
0.750), gap (2/6 vs 4/6) y leakage (0.502 vs 0.441). La ablación lo demuestra sin
ambigüedad: `r2_no_sem` (equivale a R1) supera a `r2_full`. El coseno bge-m3 como
señal subordinada **empeora** la selección de las agujas del gap (los ítems S de
alto coseno son similitud semántica, no evidencia). Curiosamente R2 SÍ mejoró Q08
(1.0: ambas agujas gold en System.md) y Q06 (1.0) — el sem ayuda donde la señal
léxica es débil, pero perjudica Q01/Q05 (0.0).

### Hallazgos por query (R1)

- **Q10 — perfecto**: ambas agujas del gap a rank 1 (X: thermal) — la señal de
expansión x_overlap=5/5 domina.
- **Q08 — el experimento del usuario**: `picom` gold en System.md sube al top-10
  (`curated` + x_overlap), `P_TERM_OPACITY` aún fuera (R1). En R2, las dos entran.
- **Q06 — coste del reranker**: FF_SEEN cae (0.0) — el top-10 de R1 pierde el
  pasaje de CHANGELOG.md que G1/R2 mantenían.
- **Q03 — la cadena casi completa**: `gh pr create` generado por X → rank 12 (R1),
  sin entrar al top-10; `git push origin` sí (0.5).

### Conclusión

R1 y R2 **NO se adoptan** (fallan pRel/leakage — falta una capa de selección
quality-aware, el Caso 3 del usuario). Pero el 10B demostró lo que faltaba probar:
**Buffy ya tiene la evidencia disponible y el problema era ordenarla** — el mismo
pool con un reranker diagnóstico sencillo (5 señales, pesos 1.0 fijos) multiplicó
el recall por 2 (0.367 → 0.750), cerró 4/6 del gap y redujo leakage 29%. La señal
`x_overlap` (expansión) es la pieza clave; el embedding no aporta como señal de
ranking. Fase 3 sigue abierta; runtime congelado; nada se adopta.

## ✅ Paso 10B — CERRADO · R1/R2 no adoptados · ranking = cuello de botella real · calidad del contexto = problema dominante · 2026-08-12

**Veredicto del usuario (confirmación del estado de Fase 3 + punto de continuación):**

> El handoff deja una línea de continuidad clara: A 0.000 → G1 0.417 → H2 0.367 →
> **R1 0.750** (récord). Nada adoptado y runtime congelado.
> La conclusión queda separada por capas: **generación** resuelta (H2 6/6 agujas),
> **granularidad** resuelta (pasajes 28-46×), **ranking** = cuello de botella real
> (R1 lo demostró), **calidad del contexto** = problema dominante (pRel 0.175, leak
> 0.441). La próxima sesión NO debe volver a recorrer A→R1 ni reabrir decisiones.

**Punto exacto de continuación — Paso 11: diseñar `quality-aware passage selection`**, manteniendo:

```text
EVAL = 98a0e308… · runtime = congelado · H2 pool = congelado
R1-LEX = baseline de ranking · presupuesto = 10.4k
```

**Pregunta experimental del Paso 11:**

> Dado que R1 ya coloca bastante de la evidencia correcta entre los candidatos,
> ¿podemos distinguir evidencia realmente útil de pasajes relacionados/ruidosos
> ANTES de construir el contexto final?

### Señales medidas HOY que dimensionan el diseño (pool/contexto de R1)

**1. El contexto R1 tiene 60 pasajes y solo 15 (25%) contienen la aguja** → pRel 0.175.

**2. Las señales de similitud NO discriminan gold vs noise a nivel de pasaje:**

| Señal | Pasajes con aguja | Pasajes sin aguja | ¿Discrimina? |
|---|---|---:|---|
| `x_hits` | 2.47 | 1.71 | ❌ casi (e invertido en Q03/Q06: el ruido tiene MÁS) |
| `q_hits` | 0.68 | **1.89** | ❌ **INVERTIDA** — el ruido matchea más la query que el gold |
| `curated` | 91% | 100% | ❌ no separa |
| `cmds` (tokens de comando) | 1.8 | **7.0** | ❌ **INVERTIDA** — el ruido tiene MÁS comandos (hipótesis refutada) |

**3. La señal que SÍ discrimina — densidad de evidencia X:** `x_hits / tokens` =
**0.071** (con aguja, 2.47/35) vs **0.026** (sin aguja, 1.71/65) → **2.7× más denso**.
El pasaje con aguja es más corto y concentrado (35 vs 65 tokens).

**4. Redundancia estructural cuantificada:** 8/10 queries tienen pasajes solapados
en el contexto (la ventana ±4 duplica cuando entran ítems adyacentes del mismo
archivo). **Dedup greedy por solapamiento (overlap > 4 líneas): elimina 17/60
pasajes (28%), recorta 15-59% de tokens por query, sin perder ni una aguja**
(Q07/Q08/Q10 1→1, Q04/Q06 0→0).

### Lectura por capas para el Paso 11

La poda/selección quality-aware ataca la capa de **selección de pasajes** (qué
entra al contexto), NO la generación ni el ranking — ambos congelados (pool H2,
orden R1). Si pRel sube sin perder sRec → la hipótesis (evidencia distinguible por
calidad antes del contexto) se confirma. Riesgo declarado: sobre-poda que elimine
agujas → protegido por gold_containment y baseline_regression.

### Estado de la suite en el perfil PC (2026-08-11)
> ⚠️ **La suite del perfil PC no está actualmente 100% verde** por incompatibilidades
> de entorno/drift documental **preexistentes** (verificadas: no fueron producidas por
> la Fase 3 ni por la Baseline A):
>
> - 3 FAIL en `test-scale.sh` → usa `TMPDIR:-/data/data/com.termux/files/usr/tmp`
>   (ruta hardcodeada del perfil Termux) que no existe en el PC → el sandbox no se
>   puede crear y los 3 checks de estrategia OR fallan.
> - 2 FAIL en `test-documentation.sh` → el README declara conteos de la suite
>   (`--quick`: functional 225 / total 230) que no coinciden con la suite real
>   (222 / 226) tras cambios provenientes del perfil teléfono.
>
> Estos FAIL **NO forman parte de la medición de Baseline A** y quedan **fuera de
> alcance** de esta fase: arreglarlos ahora introduciría ruido en el experimento.
> No tocar hasta que se decida un cleanup de portabilidad del perfil PC, con su
> propia justificación.

---

## 🔬 Paso 11 — EJECUTADO · Q1/Q2 no pasan el gate (pRel/leakage) · 2026-08-12

**Contexto de ejecución — incidente FWD tipo CONFLICT resuelto con worktree aislado:**

al lanzar el runner, la precondición falló: el índice semántico cacheado
(`e1cf6011…`, construido al medir R1) no correspondía al corpus actual
(`9aafac49…`). La otra sesión había modificado el corpus del EVAL entre la
medición de R1 y ahora (+5 archivos, +7 modificados, −1 eliminado: FWD-DESIGN,
MCP_REGISTRY, SKILLS_INDEX, SNAPSHOT, facts.yaml, README, CHANGELOG, CONTINUE,
INFO-core, LOAD_CONTEXT, SESION-archive, SESION). Re-medir sobre el corpus actual
habría contaminado la comparación Q1/Q2 vs R1 (corpus A vs corpus B). **Usuario
aprobó: worktree aislado en `18df679`** — Q1/Q2 se midieron exclusivamente allí;
el working tree compartido quedó intacto. El índice se reindexó en el worktree
(`bge-m3-8a6fdc38…`); el de la rama principal no se tocó.

**Validación del worktree:** corpus de 44 archivos (45 de `18df679` menos
`deprecated/README.md`, excluido por diseño del runner) — contenido idéntico al
de R1. La corrida D de control reprodujo EXACTAMENTE los valores del Paso 7
(0.200/0.192/0.669/48.0k). EVAL `98a0e308…`, R1 determinism `8316343e…`,
dict_hash `b0406a33…` verificados en el worktree.

**Determinismo G2 CONFIRMADO (2 corridas por variante):** Q1 `f0f398c5da8d23ca`
· Q2 `e2a1821a9720f396` — métricas idénticas en ambas corridas.

| Estrategia | sRec | pRel | leak | tokAvg | gCont | gap_to_top10 | regression |
|---|---:|---:|---:|---:|---:|---:|---:|
| G1 (ventana) | 0.417 | 0.072 | 0.606 | 2569 | 0.8 | — | — |
| R1-LEX (baseline ranking) | 0.750 | 0.175 | 0.441 | 1904 | 1.0 | 0.667 (4/6) | 0.167 |
| **Q1-DEDUP** | **0.800** | 0.118 | 0.540 | 1975 | 1.0 | **0.833 (5/6)** | 0.167 |
| **Q2-DEDUP+DENS** | **0.850** | 0.066 | 0.478 | 1747 | 1.0 | **1.000 (6/6)** | **0.000** |

Gate 6 criterios: `sRec>0.100` ✓ · `pRel≥0.600` ✗ (0.118/0.066) · `leak≤0.267`
✗ (0.540/0.478) · `tok≤10.4k` ✓ · `gCont≥0.80` ✓ (1.0) · `regression≤0.167` ✓
(0.167/0.000). **Ambas variantes FALLAN el gate → no adoptadas. Runtime intacto.**

**Semántica de sRec (aclaración post-review):** en Q1/Q2 — igual que en
G1→R1 (run-passage/expansion/rerank/quality, todos definen `hits` desde
`top10_passages`) — `search_recall` mide **la aguja en el texto de los pasajes
top10 SELECCIONADOS por la variante con path en gold_files**, NO la rama L
congelada. Por eso Q04/Q06 cambian de sRec entre Q1 y Q2 (selección
dependiente de variante). La comparación Q1/Q2 vs R1/G1 es válida (mismo
instrumento pasajes); A–F usan instrumento de líneas anterior y solo valen
como contexto histórico.

**Poda (métricas nuevas):** agujas_preservadas **6/6 = 1.0** en ambas (por-gold-fact) ·
fraccion_podada_avg −0.598 (Q1) / −0.294 (Q2) · tokens_ahorrados_avg −0.818 /
−0.101 · tokens_evidencia_absolutos_avg 107.3 / 140.5 · dropped_overlap 64 / 61 ·
dropped_density 0 / **388**. pRel_delta vs R1: −0.057 / −0.109 · vs G1: +0.046 / −0.006.

**Per-query en foco:**

- Q03 `gh pr create`: **✅ resuelto** en Q1/Q2 (sRec 1.0, in_pool_top10 vía X
  'create', rank_r1=13 → rank_poda=6).
- Q06 `FF_SEEN`: Q1 lo deja budget_cut (sRec 0.0); **Q2 lo recupera (sRec 1.0)**
  — la re-selección de Q2 (dedup+densidad) coloca la aguja en un pasaje top10
  de archivo gold.
- Q08 `P_TERM_OPACITY`: sigue `ranked_out` en ambas (el candidato existe, el
  ranking no lo sube).
- Q04 `xset -dpms`: **⚠️ regresión de ATRIBUCIÓN en Q2** — la aguja NO se pierde
  del contexto (`agujas_preservadas=2/2`, `tokens_evidencia_absolutos=109`),
  pero el pasaje que la porta en Q2 es de un archivo NO gold (`sOth=1.0`,
  `sRec=0.0` vs 1.0 en Q1/R1). El filtro de densidad (388 pasajes descartados)
  reemplazó el pasaje gold por uno no-gold con la misma aguja.
- Q10 `dumpsys thermalservice`: estable (sRec 1.0, rank_r1=1).

**Lectura por capas:** (1) generación + ranking resueltos experimentalmente
(gap 1.0, regression 0.0, out_of_pool=0); (2) la poda NO fabrica calidad — pRel
sigue muy bajo y leakage alto; (3) la densidad es contraproducente a nivel de
contexto (baja pRel a 0.066 y desplaza la evidencia de Q04 a archivos no-gold);
(4) `fraccion_podada`/`tokens_ahorrados` NEGATIVOS NO indican ahorro: la poda
re-selecciona los top10 desde una lista candidata mayor que el top10 de R1
(`scanned`=11-22 en Q1, hasta 154 en Q2), cambiando la composición de pasajes —
la comparación de tokens vs R1 mezcla efecto de poda con cambio de selección, y
los contextos usan solo ~18% del presupuesto (sin presión de budget).
**La frontera sigue en la calidad del contexto** (selección del pasaje con la
aguja entre ruido relacionado).

**Nota de reproducibilidad:** el flag `--reindex` de `run-quality-PC.sh` es un
placeholder sin ruta de build (la construcción vive en `run-semantic-PC.sh`);
el índice del worktree se reindexó con `run-semantic-PC.sh --reindex`. Bug de
shadowing `rp`→`rpath` (variable de loop que rompía `round(router_precision)`)
corregido durante validación. Invariantes: `pool_ref`/`ranking_ref`/`dict_hash`
son auto-reportados por el runner y corroborados por determinismo ×2 + `dict_hash
b0406a33…` idéntico al registrado en H2.

Artefactos: `baseline-Q1-quality-PC-2026-08-12.json` (+`-r2`),
`baseline-Q2-quality-PC-2026-08-12.json` (+`-r2`), `run-quality-PC.sh`,
`quality-passage-DESIGN.md` (Anexo A). Detalle completo en la spec §8.

---

## ✅ Paso 11 — CERRADO · Q1/Q2 no adoptados · x_density ≠ evidence_quality · 2026-08-12

**Veredicto del usuario (transcrito):**

> La secuencia experimental queda: Generación ✅ H2 6/6 · Ranking ✅ R1 6/6 ·
> Deduplicación ❌ Q1/Q2 no alcanzan calidad · **Contenido 🔴 cuello de botella**.
> Q2 consigue 6/6 agujas + 0 regresión + 1.7k tokens, pero el contexto sigue
> siendo de mala calidad → **no se adopta**, aunque tenga el mejor recall de la
> serie.

**Hipótesis descartadas por Q1/Q2:** faltaban candidatos ❌ · faltaba expansión
❌ · fallaba el ranking ❌ · faltaba granularidad ❌ · faltaba deduplicación ❌ ·
falta capacidad de poda ❌. Lo que falta: **evaluar si el CONTENIDO de un pasaje
constituye evidencia útil para la consulta** → quality-aware content scorer, no
otra variante de retrieval.

**Aprendizaje central:** `x_density` sirve para **concentración**, no para
**relevancia** → `x_density ≠ evidence_quality`. La corrección del review evitó
una conclusión falsa: **Q2 no perdió la evidencia de Q04** (preservada 2/2, 109
tokens) — quedó **atribuida a un archivo no-gold**. Se separan tres conceptos:
`evidence_found` / `evidence_selected` / `evidence_attributed`, que el próximo
experimento debe reportar por separado.

**No tocar Q1/Q2 ni ajustar sus umbrales.** Embeddings: si se reutilizan, deben
responder una pregunta mucho más concreta y controlada (R2 ya mostró que como
señal de ranking empeoran R1).

---

## 🔬 Paso 12 — DISEÑO · Evidence-aware Passage Selection · 2026-08-12

Spec: `evidence-passage-DESIGN.md` (ver sección 2 — evidencia medida HOY que
dimensiona el diseño). Pregunta: ¿una señal basada en el CONTENIDO distingue un
pasaje que responde a la consulta de otro que solo comparte vocabulario/contexto?

**Evidencia medida HOY (contexto R1, 60 pasajes, 17 con aguja):**

| Señal | con | sin | ratio | selector |
|---|---:|---:|---:|---|
| S1 n-gram contiguo (query∪X) | 1.353 | 1.302 | 1.0× | ❌ descartada |
| S2 idem líneas cmd | 1.176 | 1.140 | 1.0× | ❌ descartada |
| S3 heading sección | 0.137 | 0.008 | **17.7×** | prec 1.0 @ rec 0.35 |
| **S4 bge-m3 cosine(pasaje, query+X)** | 0.596 | 0.473 | 1.26× | **prec 0.867 @ rec 0.765 @ θ=0.55** (13 TP / 2 FP) |

**Hallazgo clave:** S4 —embedding como content-scorer entre la query expandida y
el texto del pasaje (NO como generador/ranking, que falló en D/R2)— separa
evidencia de ruido relacionado con solo 2 falsos positivos en 43 ruidosos: la
mejor discriminación de toda la serie. S3 (heading, gratis) tiene precisión
perfecta pero recall bajo. S1/S2 quedan descartadas por los datos.

**Tres conceptos medidos en R1:** found=20/20 (H2) · selected=14/20 (ctx
completo) · attributed=14/20 — pero **solo 6/20 en la capa de pasajes** (las
otras 8 en los archivos completos del router). La capa de pasajes concentra el
ruido y aporta marginalmente evidencia: la señal de contenido se evalúa como
selector de ESA capa.

**Variantes (ablación por señal, como 10B):** E1-S3 (heading, gratis) · E2-S4
(bge-m3 cosine, θ=0.55 a priori) · E3-S3+S4 (0.5/0.5 fijos). Congelados: EVAL,
pool H2, orden R1, presupuesto, runtime. Tres conceptos por query obligatorios.
Gate 6 criterios idéntico a 11. **Pendiente de aprobación para implementar.**

---

## ✅ Paso 12 — EJECUTADO · CERRADO sin adopción · Evidence-aware Passage Selection · 2026-08-13

Serie E1×2 / E2×2 / E3×2 completa en worktree aislado `18df679` (patrón FWD).
G2 determinismo ✅ (pares idénticos; E2 `4ab293dacef1c914`). Artefactos:
`baseline-E1/E2/E3-evidence-PC-2026-08-12.json` (+`-r2`). Anexo completo en
`evidence-passage-DESIGN.md` (Anexo A).

### Resultados agregados (v3.1, gold definitivo)

| Variante | sRec | pRel | leak | gCont | tokAvg | gap→top10 | regresión | poda | tok_evidencia |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| R1 (ref) | 0.750 | 0.175 | 0.441 | 1.0 | 1903 | 0.667 | 0.167 | — | — |
| E1 — S3 heading | 0.600 | **0.230** | 0.382 | 1.0 | 1904 | 0.333 | 0.167 | 25% | 289 |
| E2 — S4 bge-m3 (θ=0.55) | 0.700 | 0.093 | **0.325** | 1.0 | **1789** | **0.833** | **0.0** | 38% | 297 |
| E3 — S4+0.5·S3 | 0.700 | 0.103 | 0.342 | 1.0 | 1887 | 0.833 | 0.0 | 18% | 294 |

**Gate:** ninguna variante pasa (pRel ≥ 0.600 → E1 0.230 / E2 0.093 / E3 0.103;
leakage ≤ 0.267 → 0.325-0.382). **No se adopta E1/E2/E3** — regla pre-registrada.

**Veredicto del usuario (transcrito, 2026-08-13):**

> La hipótesis de una señal de contenido útil queda parcialmente confirmada, pero
> no alcanza para resolver la selección de contexto.
> 1. **El embedding encontró su lugar: content-scorer** (D generador ❌ · R2 ranking
>    ❌ · E2 filtro de calidad ✅: leak 0.441→0.325, regresión eliminada, gap
>    0.833). bge-m3 no decide qué recuperar ni qué rankear, pero sí qué pasajes
>    son evidencia relevante — distinción arquitectónica.
> 2. **El cuello de botella real es candidate/context coverage:** solo 6/20 agujas
>    estaban en la capa de pasajes de R1 → el selector perfecto no puede elegir
>    evidencia que nunca llegó a esa capa (found 20/20 → selected 14/20 →
>    attributed 14/20 → **pasaje 6/20**).
> 3. **No calibrar más θ** (0.50/0.45/por query/combos): sería optimizar la capa
>    equivocada. E2 ≈ E3 (heading apenas aporta).

**`tok_evidencia=0`** en 5/10 queries no es un bug del contador: es el dato
(Q02/Q09 podan el 100% → ctx sin pasajes; Q01/Q03/Q05 tienen la aguja en la capa
de archivos, no en pasajes del ctx final). Es la señal que motiva el Paso 13.

**Infra:** cache de embeddings de pasajes implementado en `run-evidence-PC.sh`
(float64) y **validado bit-a-bit ✅ (2026-08-13)**: cold vs warm → embeddings
1024/1024 idénticos + determinism_hash idéntico; ambos vs congelado →
`4ab293dacef1c914` + dump completo idéntico. E2/E3 pasan de ~40 min a ~2 min.
Infra congelada como transparente (ni a favor ni en contra del Paso 13). No toca
el esquema JSON → determinism_hash comparable.

**Siguiente: Paso 13 — Passage Candidate Expansion** — atacar el salto
archivo→pasaje (coverage) antes de re-aplicar el scorer E2 congelado. Spec:
`passage-candidate-expansion-DESIGN.md`.

---

## 🔬 Paso 13 — EJECUTADO · CERRADO sin adopción · Passage Candidate Expansion · 2026-08-13

Serie F1×2 / F2×2 en worktree `18df679` (G2 ✅: F1 `23bc7460c9d07211` · F2
`7fc28c377482e2c5`), reutilizando E2/θ=0.55/R1/H2/cache. Runner con `--expand
none|f1|f2` (rama P: ventanas ±4 no-solapadas de archivos; F2 = +top-10 del pool).
Artefactos: `baseline-F1/F2-expansion-PC-2026-08-13.json` (+`-r2`). Anexo A en
`passage-candidate-expansion-DESIGN.md`.

### Resultados agregados

| Variante | sRec | pRel | leak | tokAvg | gap | regr | available | attr |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| R1 | 0.750 | 0.175 | 0.441 | 1903 | 0.667 | 0.167 | — | 14 |
| E2 | 0.700 | 0.093 | 0.325 | 1789 | 0.833 | 0.0 | 6 | 16 |
| **F1** (router) | 0.700 | 0.093 | **0.275** | 1749 | 0.833 | 0.0 | **14** | 16 |
| **F2** (router+pool) | 0.700 | **0.121** | 0.308 | 1740 | 0.833 | 0.0 | **18** | 16 |

**Gate: ninguna pasa** (pRel ≥ 0.600 → máx 0.121; leak ≤ 0.267 → F1 0.275, cerca
pero no). **No se adopta F1/F2** (regla de la serie).

**Veredicto del usuario (transcrito, 2026-08-13):** implementar F1/F2 exactamente
según el diseño, sin modificar θ/presupuesto/scorer/runtime/gates; ejecutar
determinismo ×2; registrar y detenerse sin adoptar.

**Lectura del experimento (responde su pregunta):**
1. **F1 mejora leakage** (0.325 → 0.275) sin tocar pRel — Q03 leak 0.5 → 0.0 (el
   gate ahora elige pasajes del archivo gold Commands.md). Los archivos del router
   son la fuente de pasajes correcta.
2. **F2 añade cobertura y pRel pero devuelve leakage** (0.275 → 0.308; Q09 0.0 →
   0.33): `available` 14 → 18 (Q08 picom/P_TERM_OPACITY desde System.md; Q06
   FF_SEEN) y pRel 0.093 → 0.121, pero **la atribución no mejora (16/20)** →
   ampliar el universo de archivos del pool NO convierte disponibilidad en
   atribución.
3. **Q04 roto por construcción:** su gold (CHANGELOG.md) no está en kno ni en el
   top-K del pool → `available=0` en F1 y F2.
4. **El cuello de botella se desplaza: disponibilidad → atribución** (18
   available vs 16 attributed): el pasaje con la aguja existe en el pool pero no
   llega al ctx final como pasaje gold.

**Nota de integridad (lección FWD aplicada):** el refactor se validó con E2
`--expand none` bit-idéntico al congelado (`4ab293dacef1c914`). La primera
verificación falló por drift de corpus FTS5 (el cierre de sesión editó
`ai-context/CONTINUE.md`/`SESION.md`, que buffy-search indexa del repo real);
restaurados + reindex → bit-idéntico. **No tocar archivos del corpus mientras se
mide.**

**Estado:** runtime intacto. Fase 3 sigue abierta; siguiente decisión del usuario
con la evidencia (posible hipótesis: atribución/presupuesto, no más cobertura).

---

## 🔬 Paso 14A — EJECUTADO · phi3.5 NO pasa el gate → Rama B, sin 14B · 2026-08-13

**Autorizado por el usuario (2026-08-13):** mini-fase de modelo ANTES del selector:
¿un juez LLM (phi3.5) discrimina gold vs distractor mejor que bge-m3? Si 14A pasa
(pair test ≥7/11, determinismo ≥10/11, tiempo <60 s/pasaje) → Rama A (Phi juez con
rúbrica) → 14B. Si no → Rama B (scorer multi-señal) → Paso 15.

**Runner:** `scripts/tests/evals/run-selector-model-PC.sh` — pool F2 congelado
(fixture `selector-pool-frozen-2026-08-13.json`, eval_hash `98a0e308…`), 11 pares
gold-vs-distractor, bge-m3 como scorer de referencia + phi3.5 como juez
(`num_ctx=2048` obligatorio, `keep_alive=0` top-level entre queries + unload para
evitar OOM por prompt cache — fix verificado: PID cambió entre queries, memoria
liberada 11 GB → 8.6 GB, corrida completa sin errores).

**Resultado** (`selector-benchmark-14A.json`, 3738 s, sin OOM):

| Métrica | Gate | phi3.5 | ¿Pasa? |
|---|---:|---:|---|
| pair test (gold vs distractor) | ≥7/11 | **5/11** (= bge) | ❌ |
| determinismo (pares) | ≥10/11 | **9/11** | ❌ |
| determinismo (pasajes) | — | 220/226 (97.3%) | — |
| tiempo | <60 s/pasaje | **14.3 s** | ✅ |

**Discriminación cruda (pool, θ=0.55):** phi recupera 13/97 gold (pRel 0.134, leak
0.705) vs bge 74/97 (pRel 0.763, leak 0.549). **phi no supera a bge en ningún
query.** (Estas métricas miden discriminación sobre el pool, NO el pRel/leak del
pipeline F2 — no comparables 1:1.)

**Veredicto:** phi3.5 falla 2/3 gates de primer nivel → **Rama B, sin 14B**. El
juez LLM no discrimina mejor que el scorer de embeddings; el problema de Q06/Q08
no es de modelo sino de señales. Anomalía menor: journal reporta `temp = 0.800`
vs `temperature: 0.0` del runner — sin resolver, irrelevante para el veredicto.

**Esquema del JSON (aclaración):** no hay `pair_test`/`discrimination`/`metrics`
top-level; todo vive en `per_query[]` + `aggregate`. `phi_pick=="A"` ⟺ gold
(A=gold, B=distractor). `tokens`/`num_ctx`/`seed` no están en el JSON.

---

## ✅ Paso 15 — EJECUTADO · M3 (S1+S2+S3+S4) + ventana de rescate 0.545 ADOPTADO · 2026-08-13

**Decisión de rama (de 14A):** Rama B — scorer multi-señal, sin juez LLM.

**Runner:** `scripts/tests/evals/run-selector-quality-PC.sh` — señales S1 (bge-m3
cosine, gate θ=0.55) · S2 (especificidad: tokens salientes menos tokens de query,
rareza cross-pool) · S3 (evidencia estructurada: tabla `^\s*\|.*\|.*\|` o
KEY=value `^\s*[\w.-]+\s*=`) · S4 (canonicalidad: NOISE_FILES =
SESION-archive/AGENTS/CONTINUE/SESION) · S5 (mtime) · S7 (concisión) · MMR λ=0.7.
Pesos declarados a priori: w1=1.0, w2=1.0, w3=0.5, w4=0.5, w5=0.25, w7=0.25.
Ablación M1 (+S2) → M2 (+S3) → M3 (+S4) → M4 (MMR) → FULL (+S5+S7). Gates
hard/soft/rescue. Gold sintético Q06 (ventana ±4, ramas SYNTH) añadido al pool.
Determinismo G2 ✅ (hash `5ab74054f1d2dcde` idéntico ×2).

### Resultados (gate hard, 15A)

| Modelo | pRel | leak | attr | gold_over_dist | tokens |
|---|---:|---:|---:|---:|---:|
| S1 (baseline) | 0.472 | 0.425 | 17/20 | 5/11 | 5766 |
| M1 (+S2) | 0.522 | 0.425 | 17/20 | 7/11 | 4610 |
| M2 (+S3) | 0.442 | 0.367 | 14/20 | 7/11 | 4818 |
| **M3 (+S4)** | 0.482 | 0.325 | 16/20 | **9/11** | 4933 |
| M4 (MMR) | 0.432 | 0.403 | 15/20 | 9/11 | — |
| FULL (+S5+S7) | 0.432 | 0.400 | 14/20 | 8/11 | — |

**Regla de parada:** M1 7/11 → M2 7/11 → **M3 9/11 (target ✓)** → M4 9/11 (MMR no
aporta). **M3 = S1+S2+S3+S4 es el punto de parada.** Gate soft (sin piso S1)
colapsa (M3 attr 1/20) → el piso de relevancia es esencial.

### Ventana de rescate (decisión 2b del usuario)

θ=0.55 corta el gold de Q08 (System.md:74, cos 0.5478) por 0.002 → contradicción
del diseño confirmada con datos. Ventana `rescue` (piso `--rescue-low`, top-K por
score): 0.50-0.53 catastrófico (attr 7-12/20), **0.545 = punto quirúrgico**:

| Config | Q06 | Q08 | Q07 | attr | leak | pRel | gold_over |
|---|---:|---:|---:|---:|---:|---:|---:|
| S1 (selector actual) | 1/1 | 0/2 | 2/2 | 17/20 | 0.425 | 0.472 | 5/11 |
| M3 hard | 1/1 | 1/2 | 2/2 | 16/20 | 0.325 | 0.482 | 9/11 |
| **M3 rescue 0.545** | 1/1 | **2/2** | 1/2 | 16/20 | **0.242** | **0.577** | 9/11 |

**M3 rescue 0.545 ADOPTADO** (decisión del usuario): arregla el caso estrella del
diseño (Q08-P_TERM_OPACITY atribuido), leak 0.242 (pasa gate ≤0.308), pRel 0.577
(mejor de la serie), gold_over 9/11. Costo: Q07-2 (`force_gpu_rendering`) perdido
— colateral de la misma familia S3 (ver hallazgos).

### Hallazgos (documentados, no corregidos — calibración post-hoc prohibida)

1. **S3 sobre-corrige estructuras:** Q02 (INFO-full.md:189, reference de
   `ai-context/` con tablas, desplaza a Shizuku.md:53/85) y Q07 (scrcpy.md:37 con
   `ENCODER="..."`, README.md:73 tabla, desplazan a GameOptimization.md:54). La
   lista de ruido declarada (S4) no cubre INFO-full.md. Refinar S3 (solo tablas,
   no code-blocks) es candidato para iteración futura.
2. **θ=0.55 corta golds reales** (Q08 a 0.5478) → ventana de rescate 0.545
   implementada como solución quirúrgica (no recalibración global).
3. **El piso S1 es esencial:** sin él (gate soft) las señales de calidad se ahogan
   en pasajes irrelevantes-pero-bonitos (attr 1/20).

**Estado:** M3 rescue 0.545 = nuevo selector del pipeline (runtime sigue
congelado; la adopción es del componente de selección, no de
`buffy-search.sh`/`buffy-router.sh`). Artefactos: `selector-quality-15A.json`
(+`-r2`), `selector-benchmark-14A.json`, `run-selector-quality-PC.sh`,
`run-selector-model-PC.sh`, `selector-pool-frozen-2026-08-13.json`.

---

## ✅ Paso 15B — EJECUTADO · ADOPTADO · Iteración S3: V6 (S3 condicionado a query + S4 por clase de memoria de sesión) · 2026-08-14

**Motivo:** el hallazgo 15A documentó que S3 (estructura binaria +0.5) sobre-corrige
pasajes estructurados no-gold (Q02 `INFO-full.md:189` tabla de perfil · Q07
`README.md:73` tabla índice y `scrcpy.md:37` con `ENCODER="..."`), desplazando
golds en prosa (Shizuku.md · GameOptimization.md). El usuario autorizó iterar sobre
el hallazgo. **Hipótesis declarada antes de medir:** S3 binario confunde estructura
*definicional* (el gold de Q08, `P_TERM_OPACITY` en tabla/KEY=value) con estructura
*incidental* (índices/perfiles que solo mencionan). Cambios de MECANISMO (semántica
de señales), sin calibración: pesos/θ/gate intactos, sin fitting per-query.

**Harness:** reproducción fiel del runner 15A sobre `selector-pool-frozen-2026-08-13.json`
(sanity: M3 = 16/20 · pRel 0.577 · leak 0.242 bit a bit; synth Q06 leído del corpus
congelado `77bf26a` para ser drift-proof). Variantes medidas:

| Variante | attr | pRel | leak | reg | Q02 | Q07 | Q08 | Q06 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| M3 (2026-08-13) | 16/20 | 0.577 | 0.242 | 0.420 | 1/3 | 1/2 | 2/2 | 1/1 |
| V1 · S3 condicionado a query estructural | 18/20 | 0.627 | **0.325** ❌ | 0.330 | 3/3 | 2/2 | **1/2** ❌ | 1/1 |
| V2 · S3 densidad (fracción de líneas) | 16/20 | 0.577 | 0.250 | 0.390 | 0/3 | 2/2 | 2/2 | 1/1 |
| V3 · S4 clase total `ai-context/*` | 15/20 | 0.587 | **0.217** | 0.450 | 1/3 | 1/2 | 2/2 | **0/1** ❌ |
| V4 · S3 solo tablas (sin KEY=value) | 16/20 | 0.577 | 0.242 | 0.420 | 1/3 | 1/2 | 2/2 | 1/1 |
| **V6 · V1 + S4 clase memoria de sesión** | **19/20** | **0.677** | **0.275** ✅ | **0.360** | **3/3** | **2/2** | **2/2** | **1/1** |

**Mecanismo (confirmado con datos):**
1. **S3 binario sobre-corrige** — cualquier tabla/KEY=value recibe +0.5 aunque sea
   mención incidental (índice README.md, perfil INFO-full.md, asignación scrcpy.md)
   y desplaza golds en prosa. Confirmado y cuantificado.
2. **V1 (S3 solo si la query es estructural** — patrón tabla/KEY=value en la query,
   mismo regex que los pasajes): queries de procedimiento (Q02/Q07 prosa) no
   reciben boost → attr 16→18/20. **Costo aislado:** el gold Q08
   `System.md:74` (P_TERM_OPACITY, s1=0.5478 en ventana rescue, s2=0.60) dependía
   del boost S3 → cae al rank 14 (Q08 1/2) y la prosa de `ai-context/` (INFO-full,
   CHANGELOG-archive) llena el top-10 → leak 0.325 (falla gate ≤0.308).
3. **V6 cierra el costo:** S4 por CLASE de memoria de sesión (no-canónico = lista
   original + dumps por-sesión en `ai-context/` — INFO-full, CHANGELOG-archive,
   SHIZUKU-RISH-BUG; **CHANGELOG.md (historia curada) sigue canónico** → preserva
   Q06 FF_SEEN). Los distractores `ai-context/` de Q08 caen → `P_TERM_OPACITY`
   vuelve al top-4 → Q08 2/2 ✓ y Q06 1/1 ✓.
4. **Descartadas con evidencia:** V2 (densidad — Q02 empeora a 0/3: los golds
   `rish -c` son code-blocks de baja densidad), V3 (rompe Q06), V4 (la sugerencia
   literal del hallazgo "solo tablas" NO arregla nada — los casos fallan por
   tablas, no por code-blocks).
5. **Q05 `useState` (React.md:22-30, s1=0.4646) queda fuera del piso 0.545 en
   TODAS las variantes** — miss preexistente ortogonal a S3 (gap de símbolos
   semánticos → rama X del Paso 10, planificada para la próxima iteración).

**Veredicto del usuario (2026-08-14): ADOPTAR V6** como nuevo selector del pipeline
(cambios de mecanismo, no calibración). Implementado en `scripts/lib/selector_m3.py`
(default = V6: `query_structural()` + `is_session_noise()`), sin tocar pesos/θ/gate.
Determinismo intacto (mismas funciones deterministas + cache). Suite: **267 OK / 4
FAIL full · 251 OK / 4 FAIL --quick** (los 4 FAIL son preexistentes: 3 × test-scale
ruta Termux + 1 × skill-lint --require-all). Test de veredicto actualizado a 15B
(attr 19/20 con Q02 3/3 · Q07 2/2 · Q08 2/2 · Q06 1/1) + test de mecánica S3/S4
sin Ollama.

---

## 🗜️ Regla de compresión para modo autónomo (2026-08-13, decisión del usuario)

**Motivo:** el pipeline real completo (`router → search → F2 expand → M3`) es
pesado para iteración en vivo — cada tile de la expansión paga un embed en frío
(fiel al Paso 13: r0 ≈ 17 min, warm ≈ 1 min). Un test end-to-end con query nueva
tardó >6 min en timeout. La disciplina de la serie ya era "smoke antes de medir";
se formaliza como REGLA para no bloquear el desarrollo.

**Regla (modo autónomo / iteración rápida):**

```text
1. Validar sintaxis de todo (bash -n, py_compile) — siempre.
2. Validar el MÓDULO modificado con entrada de prueba chica (ej. expand con un
   archivo de 25 líneas; selector con 2 pasajes) — sin pipeline completo.
3. Timeout operativo por prueba: 30 s. Si una prueba en vivo tarda más → NO
   esperar: reportar "pipeline pesado" y validar contra el EVAL congelado.
4. La validación de fidelidad se hace contra el fixture congelado (sin Ollama,
   reproducible): p.ej. expand vs rama-P del fixture, M3 vs veredicto 15A.
5. El pipeline end-to-end en vivo se corre SOLO una vez al final de la iteración
   (y con cache caliente + --max-passages acotado), no en cada ciclo.
```

**Por qué el fixture es la fuente de verdad para iterar:** el pool congelado
contiene exactamente lo que la expansión F2 genera (verificado: 133/134 rama-P
coinciden bit-a-bit; el único mismatch fue corpus drift — README 430→431 líneas
por updates de la suite — no lógica del algoritmo).

---

## 🛡️ Apéndice — Foreign Worktree Detection (FWD) · DISEÑO · 2026-08-12

**Motivo:** caso real del mismo día — dos sesiones (OpenCode + Freebuff) trabajando
en el mismo checkout de buffy-context sin pisarse. Freebuff detectó los cambios
ajenos por el estado del FS/Git (git status → diff → timestamps) y los **preservó
intactos**, pidiendo decisión. El usuario validó el comportamiento y pidió
formalizarlo como spec (roadmap Buffy 2.0), **sin implementar**.

**Spec:** `FWD-DESIGN.md` (raíz del repo) — pregunta formal, clasificación
OWN/FOREIGN/UNKNOWN/CONFLICT por señales múltiples (manifest de sesión + snapshot
baseline + timestamps solo como apoyo + atribución de contenido + estado git 3 vías
+ procesos), política de seguridad fija ("detecta, clasifica y protege; nunca
adopta, revierte, commitea ni descarta"), gate previo a escritura, puntos de
enganche (pre-flight, pre-commit, doctor, close-day) y criterios de aceptación.

**Estado:** SPEC APROBADA (2026-08-12, decisión del usuario) — congelada como
diseño, implementación posterior (no durante Fase 3, runtime deliberadamente
congelado). **Registrada en el Roadmap de Buffy 2.0** (CONTINUE.md, punto 6).
Justificada por 2 incidentes reales y simétricos el mismo día: `ed06814` (mi commit
absorbió 4 borrados staged ajenos — lección: `git commit -- paths`) y `6ed1bb1`
(commit de la otra sesión absorbió mi §4.2 unstaged — lección: pre-write re-hash +
pre-commit inspection del índice). Ambos sentidos ocurrieron, sin pérdida; la
contaminación cruzada del historial quedó documentada en la spec §4.2.
Los cambios ajenos del working tree fueron **commiteados por la otra sesión** en
`6ed1bb1` (MCP_REGISTRY, SKILLS_INDEX, README 43 skills, CONTINUE/SESION tooling,
buffy-doctor.sh drift check) — no se tocaron desde esta sesión.
**Pasos 11-12 CERRADOS (secciones arriba) — Q1/Q2 y E1/E2/E3 no adoptados;
Paso 12 (evidence-aware passage selection) EJECUTADO sin adopción: el
content-scorer (S4) confirma señal útil (leak 0.441→0.325, sin regresión) pero
ninguna variante pasa el gate; cuello de botella = candidate/context coverage
(solo 6/20 agujas en la capa de pasajes de R1) → Paso 13 en DISEÑO
(passage-candidate-expansion-DESIGN.md).**

---

## ✅ INTEGRACIÓN M3 AL PIPELINE REAL (2026-08-13) — selector operativo, runtime congelado por default

**Autorización del usuario (2026-08-13):** Opción 1 de CONTINUE.md — integrar el
selector M3 rescue 0.545 con el pipeline real (`router → search → selector →
context pack`). Los artefactos de los Pasos 12/13 (autor anterior, untracked)
quedan INTACTOS, sin commitear.

### Qué se agregó (componente de selección, opt-in)

| Componente | Archivo | Rol |
|---|---|---|
| Motor M3 reutilizable | `scripts/lib/selector_m3.py` | S1-S4 + gate rescue, extraído bit-a-bit del runner 15A |
| Wrapper CLI | `scripts/buffy-selector.sh` | `--query` + candidatos (JSON o stdin) → top-K M3 |
| Search integrado | `scripts/buffy-search.sh --select` | candidatos FTS5 (`or` para queries naturales) → selector M3 |
| Router integrado | `scripts/buffy-router.sh --context` | lista de archivos + campo `context` (pasajes top-K) |
| Tests | `scripts/tests/test-selector.sh` | sintaxis, uso, degradación sin Ollama, determinismo, 15A, no-regresión |

### Fidelidad verificada (bit-a-bit vs 15A rescue)

El módulo, sobre el fixture congelado con el mismo gold sintético del runner,
reproduce EXACTAMENTE el veredicto adoptado: **attr 16/20 · leak 0.242 · pRel
0.577 · Q06 1/1 · Q08 2/2** (System.md:74 `P_TERM_OPACITY` en top-K).

### Default intacto (no-regresión)

- `buffy-search.sh` sin `--select`: comportamiento histórico byte a byte (la
  búsqueda `and` default no cambia; `--select` es opt-in y usa `or` como
  generador de candidatos porque `and` no recupera queries naturales — gap
  medido en el EVAL, search_recall 0.000).
- `buffy-router.sh` sin `--context`: salida idéntica (verificado en tests).
- Suite: **258 OK / 4 FAIL (full) · 242 OK / 4 FAIL (--quick)** — los 4 FAIL son
  preexistentes y fuera de alcance (3 × test-scale con ruta Termux hardcodeada;
  1 × skill-lint --require-all, 22 skills sin manifest = drift del teléfono).

### Validación en vivo (queries reales, no EVAL)

| Query | Resultado |
|---|---|
| Q08 "terminal opaca/transparente" | AGENTS.md (s1 más alto 0.657) **baja al puesto 7** por S4; evidencia estructurada de opacity sube; System.md fuera del pool (candidate gap léxico conocido, no del selector) |
| Q06 "scrcpy no abre free fire" | gold real **FF_SEEN en CHANGELOG.md:217-225 entra al top-K (puesto 4)**; distractores SESION-archive con s1 más alto quedan abajo por S4 |

### Límites conocidos (documentados, no resueltos aquí)

1. **Candidate gap de Q08/Q03**: el FTS5 `or` no genera los pasajes de
   `Knowledge/Linux/System.md` por sí solo (puente semántico). RESUELTO para
   Q08 con la expansión F2 (rama P) agregada después de la integración base —
   ver sección siguiente. Q03 persiste: Commands.md entra al pool vía kno pero
   el puente `pushear`→`git push origin` es semántico (bge-m3 por línea no lo
   captura) — ese gap lo cerraba la expansión de query (Paso 10, rama X).
2. **Ollama + bge-m3 es requisito de runtime** para S1. Sin él, `--select`
   degrada a búsqueda cruda con aviso (exit 3 del motor → fallback JSON en
   `--json`), nunca rompe.
3. La señal S3 sobre-corrige estructuras (hallazgo 15A, no corregido por
   regla de no-calibración).
4. **Coste de la expansión F2 en frío**: cada tile nuevo necesita un embed
   (fiel al Paso 13: F2 r0 ≈ 17 min, warm ≈ 1 min). El pool se acota con
   `--max-passages` (default 400, los kno entran completos) como guard de
   coste operativo.

## ✅ EXPANSIÓN F2 (RAMA P) AL PIPELINE REAL (2026-08-13) — candidate gap de Q08 cerrado

**Motivación (medida):** la integración M3 base dejó Q08/Q03 como candidate
gap (el FTS5 no genera System.md). El Paso 13 ya demostró en el EVAL que F2
(archivos del router + top-K del pool → tiles ±4) genera esos pasajes
(`available` 14→18). Se implementó como componente del pipeline SIN tocar los
artefactos del autor anterior (solo lectura del diseño).

### Qué se agregó

| Componente | Archivo | Rol |
|---|---|---|
| Motor de expansión | `scripts/lib/expand_passages.py` | tile_windows ±4 no-solapados (2·PAS_PAD+1), kno + top-K del pool, `--max-passages` |
| Wrapper CLI | `scripts/buffy-expand.sh` | kno + pool → pasajes rama P (JSON/humano) |
| Selector integrado | `buffy-selector.sh --kno` | expansión ANTES del scoring M3 |
| Search/Router | `BUFFY_SELECTOR_KNO` en search · router --context la setea | pipeline completo router → F2 → M3 |

### Validación en vivo (queries reales)

- **Q08 (caso estrella):** con kno + expansión, `Knowledge/Linux/System.md:73-81`
  (P_TERM_OPACITY/picom) entra al **top-1** del selector — el candidate gap que
  motivaba el diseño quedó CERRADO en vivo. Pool 400 (tope), 387 debajo del piso.
- **Q06:** el gold FF_SEEN (CHANGELOG.md) ya entraba al top-K vía search `or`
  sin expansión; la expansión conserva la cobertura de los archivos del router.
- **Q03:** persiste el gap SEMÁNTICO (Commands.md en pool vía kno, pero
  `pushear`→`git push origin` no lo conecta bge-m3 por línea). No es cobertura
  de pasajes — es el puente léxico→técnico que atacaba la rama X (Paso 10).

### Suite

**265 OK / 4 FAIL full · 249 OK / 4 FAIL --quick** — los 4 FAIL son los
preexistentes (3 × test-scale ruta Termux + 1 × skills sin manifest). Tests de
expansión: F1 tiles 9/9/7, F2 kno+pool, max-passages recorta pool no kno,
selector --kno degrada sin Ollama.


## ✅ RAMA X (QUERY EXPANSION H1) AL PIPELINE REAL (2026-08-14) — opt-in, gap semántico Q03 aceptado como límite

**Motivación (medida):** la integración M3 + F2 dejó Q03 como gap SEMÁNTICO:
`Commands.md` entra al pool vía kno, pero el puente `pushear`→`push` /
`crear`→`create` falla en el SCORING (S1 bge-m3 por pasaje), no en la
generación. El Paso 10 ya demostró en el EVAL que la rama X (diccionario
ES→EN genérico H1) cierra el candidate gap (5/6 agujas, incl. Q03 vía
`push`/`create`); en 2026-08-12 la selección (RRF) fallaba, pero HOY la
selección es M3 → el cuello de botella de entonces ya no existe.

### Qué se agregó (opto-in, default OFF — no-regresión byte a byte)

| Componente | Archivo | Rol |
|---|---|---|
| Motor de expansión | `scripts/lib/expand_query.py` | DICT_H1 + `expansion_terms` portados del runner del Paso 10 (fidelidad 10/10 vs baseline-H1 congelado, dict_hash `8294f200…`) |
| Search | `buffy-search.sh --expand-query` | (1) **X-candidatos**: re-consultas FTS5 por término → hits extra al pool (tope 100 declarado, gate ≥1 token por construcción OR); (2) **X-query**: términos → selector como `--terms` |
| Selector | `buffy-selector.sh --terms` | la query expandida (original + términos X) alimenta S1 (bge-m3) |
| Env | `BUFFY_EXPAND_QUERY=true` | activable desde `router --context` |

### Validación en vivo (Q03 — foco del plan)

| Métrica | Sin expansión | Con `--expand-query` |
|---|---|---|
| Pool | 15 candidatos | **91** (X-candidatos activos) |
| Commands.md:64 en pool | ✅ | ✅ (generación resuelta) |
| S1 del gold (ventana ±4) | 0.468 | 0.493 (+0.025) |
| piso rescue M3 | 0.545 | 0.545 → **fuera del top-K** |

### 🔎 Hallazgo: la granularidad del pasaje, no el modelo

Medición fina sobre el gold (Commands.md:64, `gh pr create`):

| Query | Línea exacta | Ventana ±4 (60-68) | Tile F2 (64-72) |
|---|---|---|---|
| natural | 0.515 | 0.468 | — |
| + todos los términos X | 0.539 | 0.493 | 0.487 |
| + solo términos relevantes | **0.613** ✅ | 0.519 | 0.523 |
| símbolo exacto `gh pr create` | 0.873 | — | — |

**La línea exacta CRUZA el piso (0.613 con términos relevantes); la ventana ±4
la diluye** (5 comandos `gh` vecinos). El cuello de botella es la granularidad
del pasaje (PAS_PAD=4, congelada en G1-VENTANA) combinada con bge-m3 — no el
embedding per se.

### Veredicto del usuario (2026-08-14)

- **A) Bajar el piso 0.545 → 0.490: DESCARTADO** — contradice la evidencia 15A
  (el soft gate colapsó attr 1/20: "el piso de relevancia es esencial") y la
  decisión 2b del piso quirúrgico (Q08 gold a 0.5478, leak gate 0.308).
- **B) Otro embedding (e5-mistral…): DESCARTADO por ahora** — la línea exacta
  ya cruza el piso; cambiar de modelo no arreglaría la dilución por ventana.
- **C) Aceptar Q03 como límite documentado: ADOPTADO** — la rama X queda como
  componente opt-in (mejora generación + S1, no rompe nada); Q03 es el límite
  conocido de bge-m3 + PAS_PAD=4 para golds de código.
- **Dirección futura (misma raíz):** evaluar granularidad alternativa de pasaje
  (línea exacta o ventana 1/2) para golds de código, con su propio gate
  (leak ≤0.308, pRel ≥0.121) — sin tocar el piso 0.545 ni el modelo.

### Suite

**283 OK / 4 FAIL full · 267 OK / 4 FAIL --quick** — los 4 FAIL son los
preexistentes (3 × test-scale ruta Termux + 1 × skills sin manifest). Tests de
rama X (+13 checks): fidelidad vs runner H1 (10/10), dict_hash estable,
no-regresión del default, degradación sin Ollama (exit 3 limpio), pool crece
con X-candidatos (15→91), smoke Q03 (gold en pool, S1 mejora sin cruzar piso).

## 🛑 CORRECCIÓN DE LECTURA (2026-08-14) — 15B midió con oráculo H2 en la query; baseline válido = H1 11/20

**Dato medido (diagnóstico previo al Paso 16):** el harness del veredicto 15B
puntúa `qtext = query + terms_del_fixture`. Los `terms` del fixture congelado
incluyen, para varias queries, **términos H2 = oráculo por query** (prohibido
por la regla de la serie). Ejemplo Q03: `gh pr create`, `git push origin`,
`pr create`, `crear pr`. Sobre el MISMO pool congelado:

| Mecanismo de query | attr | Q01 | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09 | Q10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| fixture-terms (H1+H2, como midió 15B) | **19/20** | 2 | 3 | 2 | 2 | 1 | 1 | 2 | 2 | 2 | 2 |
| **H1 real** (query + DICT_H1, pipeline 2026-08-14) | **11/20** | 0 | 3 | 0 | 2 | 0 | 1 | 1 | 1 | 2 | 1 |

**Consecuencias (registradas ANTES de correr el Paso 16):**

1. **El attr 19/20 del veredicto 15B pasa a ser DIAGNÓSTICO con oráculo H2, NO
   evidencia de adopción.** La mejora V6 (16→19) es real dentro de ese harness,
   pero el harness mezcla oráculo en la query → no es el rendimiento del
   pipeline real.
2. **El baseline válido para runtime es H1: 11/20.** El pipeline real (rama X
   H1, `expand_query.py`) atribuye 11/20 sobre el pool congelado; Q01/Q03/Q05
   (comandos/símbolos puros) caen a 0.
3. **RETRACCIÓN: la conclusión "Q03 es granularidad, no modelo" (sesión
   2026-08-14) queda RETRACTADA.** La medición S1 por granularidad (query
   natural) mostró que la línea exacta NO cruza el piso para Q03 (0.515) ni
   Q05 (0.411) — el S1 es bajo por el puente semántico símbolo↔query, no por
   la ventana. El "0.613 que cruzaba" fue con un subconjunto de términos
   seleccionado a mano (= calibración post-hoc, prohibida).
4. **Hipótesis H16 (declarada antes de medir):** ninguna granularidad uniforme
   (PAS_PAD ∈ {0,1,2,4}) supera el gate H1 ni rescata Q01/Q03/Q05 sin dañar
   los golds de prosa (Q02/Q06/Q08/Q09). Ver `granularity-DESIGN.md` (Paso 16).
5. **16A descartado como decisión** (solo prueba de cableado rápida): el pool
   congelado fija la granularidad en ±4 → 16A no puede medir la granularidad
   real. La medición que sella o descarta es **16B** (pool regenerado por
   PAS_PAD, H1 real) — decisión del usuario 2026-08-14.

---

## ✅ VEREDICTO PASO 16B (2026-08-14) — granularidad uniforme DESCARTADA; puente semántico H1 = límite

**Aprobado por el usuario (2026-08-14):** 16B = PASS experimental. Granularidad
uniforme DESCARTADA (las 4 variantes fallan el gate §10.1), PAS_PAD = ±4
CONSERVADO (mejor medido), Q01/Q05 = problema ABIERTO, siguiente frente =
DICT_H1/expand_query sin tocarlo hasta congelar el diseño del experimento
(spec primero, ejecución después; no implementar solución a mano). No tocar:
PAS_PAD, ventana, selector M3, gates, EVAL, corpus, defaults. No abrir Hybrid
ni re-tocar el selector antes del experimento del puente semántico.

**Runner:** `run-granularity-PC.sh` (pool regenerado por PAS_PAD, H1 real, sin
oráculo ni inyección de gold). Corpus congelado `bb33afa` (7644 líneas),
`corpus_hash f36eaf1e…`, `dict_hash H1 b0406a33…`, `eval_hash 98a0e308…`.
G2: 2 corridas (`-r2.json`, 252 s con cache vs 7181 s frío) — **JSONs idénticos
per-query en los 4 pads** (determinismo confirmado; difieren solo duración).

### Resultados por PAS_PAD

| pad | attr | pRel | leak | contain | Q01 | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09 | Q10 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **0** | **5/20** | 0.310 | **0.619** | 1.0 | . | 1 | . | 1 | . | 1 | . | . | . | . |
| **1** | **8/20** | 0.385 | 0.589 | 1.0 | . | 1 | **1** | 1 | . | 1 | . | 1 | 1 | . |
| **2** | **8/20** | 0.357 | 0.625 | 1.0 | . | 1 | **1** | . | . | 1 | 1 | 1 | 1 | . |
| **4 (baseline)** | **12/20** | **0.415** | **0.442** | 1.0 | . | 1 | . | 1 | . | 1 | 1 | 1 | 1 | **1** |

### Evaluación contra el gate §10.1 (baseline = pad 4 del mismo runner)

| Criterio | Resultado |
|---|---|
| mejora ≥1 gold de Q01/Q03/Q05 | **PARCIAL**: Q03 rescatado por pads 1 y 2 (no por 0 ni 4); **Q01 y Q05 = 0 en las 4 variantes** |
| sin regresión en Q02/Q06/Q08/Q09 | pad 0 **regresa Q08 y Q09**; pads 1/2 OK; Q02/Q06 intactos en todas |
| leakage ≤ 0.308 | **FALLA en las 4 variantes** (0.442 es el menor, en pad 4; afinar empeora: 0.619/0.589/0.625) |
| pRel ≥ 0.121 | ✅ 0.310–0.415 en todas |
| containment ≥ 0.80 | ✅ 1.0 en todas |

### Veredicto

1. **El gate NO se cruza en ninguna variante.** La condición que falla en las 4
   es leakage (≤0.308); además Q01/Q05 nunca se rescatan.
2. **La granularidad fina empeora el sistema**: attr cae 12→8→8→5, el leak
   sube 0.442→0.589–0.625, y pierde prosa (Q10 solo en pad 4; Q08/Q09 caen en
   pad 0). El pad ±4 (el que ya usaba el pipeline) es el mejor en attr, leak y
   prosa.
3. **Q03 es un efecto real pero no-monótono** (rescatado por 1/2, no por 0/4) y
   a costo de perder Q10 → no es una palanca uniforme, y no sobrevive al gate.
4. **H16 CONFIRMADA**: ninguna granularidad uniforme cruza el gate H1.
   **Q01/Q05 quedan como límite del puente semántico** query natural ↔
   comando/símbolo — inalcanzables por la ventana de pasaje.
5. **Conclusión de adopción: NO hay cambio que adoptar en PAS_PAD.** El default
   ±4 del pipeline queda como el mejor medido. Cerrar el gap Q01/Q05 requiere
   trabajar el puente semántico (DICT_H1 / query), no la granularidad.

---

## ✅ VEREDICTO PASO 17B (2026-08-14) — puente semántico DICT_H1_B: PASS experimental / NO ADOPTED

**Aprobado por el usuario (2026-08-14):** 17B = PASS experimental, **NO ADOPTED
en producción**. El tratamiento B (DICT_H1_B, hash `f534283f`) mejora el sistema
(12→13/20, Q05 rescatado, pRel +0.116) **sin regresiones**, pero el gate formal
§17.4 NO se cruza completo: leak 0.442 > 0.308. El leak es **invariante entre
A y B** (0.442 en ambos) → no es atribuible al tratamiento; se ataca en un
experimento independiente (17C). **No se modifica el umbral de leak.**
**No se hace commit de adopción de B.** B queda registrado como candidato
positivo/no adoptado.

**Runner:** `run-bridge-17B.sh` (pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, piso
0.545, sin oráculo ni inyección de gold). Corpus congelado `bb33afa` (7644
líneas), `corpus_hash f36eaf1e…`, `eval_hash 98a0e308…`, `commit_sha
1eea1d86…`. G2: 2 corridas por variante — **JSONs idénticos per-query**
(determinismo confirmado; `determinism_hash` A=`eba82567`, B=`cfd02b25`).

### Resultados (pad 4, A vs B)

| Métrica | A (control, `8294f200`) | B (tratamiento, `f534283f`) | Gate §17.4 |
|---|---|---|---|
| attr total | **12/20** | **13/20** | ✅ ≥12 |
| Q01 | 0 | 0 | ❌ (objetivo: ≥1) |
| Q05 | 0 | **1** | ✅ rescatado |
| Q02/Q06/Q08/Q09 | 3/1/1/2 | 3/1/1/2 | ✅ sin regresión |
| Q03/Q04/Q07/Q10 | 0/2/2/1 | 0/2/2/1 | ✅ sin regresión |
| pRel | 0.415 | **0.531** | ✅ ≥0.121 |
| leak | 0.442 | 0.442 | ❌ ≤0.308 |
| containment | 1.0 | 1.0 | ✅ ≥0.80 |
| determinismo G2 | — | B1=B2 idénticos | ✅ |

### Análisis por gold

- **Q05 rescatado (0→1):** `adb devices -l` ahora entra al contexto — el pasaje
  ADB.md:1-9 cruza el piso con `phone/adb/device` en el qtext. pRel sube
  0.415→0.531.
- **Q01 sigue en 0:** el pasaje con los needles (`adb tcpip 5555` / `adb
  connect`, líneas 12/14) no cruza el piso; el que cruza (ADB.md:1-9) contiene
  `adb devices -l`, no los needles Q01. El tramo `telefono→phone/device/adb`
  no alcanza para `tcpip`/`connect` — necesita un puente **conceptual/
  relacional** (ADB discovery → transport → authorization), no solo léxico.
- **Cero regresiones** en los 8 golds restantes; leak y containment idénticos.

### Veredicto

1. **B funciona como tratamiento**: rescata Q05, sube pRel, cero regresiones,
   determinista. Evidencia limpia de señal positiva del puente léxico.
2. **B NO está aprobado para producción**: el contrato de evaluación exige
   leak ≤ 0.308 y no se modifica retrospectivamente el criterio tras ver el
   resultado (regla metodológica conservada).
3. **El leak 0.442 es estructural del pool**, no del tratamiento: idéntico en
   A y B, y era el mínimo de las 4 variantes de 16B. Se ataca en una línea
   experimental separada.
4. **Q01 no se rescata con más sinónimos**: el siguiente salto es una relación
   semántica operacional entre conceptos ADB (discovery/transport/
   authorization), no ampliar DICT_H1 a ciegas.
5. **Conclusión de adopción: NO adoptar B todavía.** Congelar 17B como
   evidencia válida; B = candidato positivo/no adoptado. Próximo frente:
   **17C — reducción del leak estructural del pool** (0.442 → ≤0.308), con su
   propio diseño y gate. Después, volver a Q01 con el conocimiento obtenido.

---

## ✅ VEREDICTO PASO 17C (2026-08-14) — reducción del leak estructural del pool: PASS experimental del objetivo primario / NO ADOPTED

**Spec:** `leak-17C-DESIGN.md` (commit `51b8079`). **H17C:** el leak 0.442 es
estructural del pool (invariante A/B en 17B); atacarlo en el ENSAMBLADO del
contexto final con un solo factor por variante. **Gate §17.4 pre-fijado:**
(1) leak ≤ 0.308 PRIMARIO, (2) attr ≥ 13/20, (3) sin regresión Q02/Q06/Q08/Q09,
(4) sin regresión Q03/Q04/Q07/Q10, (5) pRel ≥ 0.121, (6) contain ≥ 0.80,
(7) G2 determinismo.

**Runner:** `run-leak-17C.sh` (copia del mecanismo 17B + `--variant {A,V1,V2,V3}`).
Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, piso 0.545, LIMIT=10, sin oráculo ni
inyección de gold. Corpus congelado `236a87fa` (7653 líneas), `eval_hash
98a0e308…`, `commit_sha 51b8079…`, `h1_dict_hash 8294f200…` (DICT_H1 de 17B-A).
G2: 2 corridas por variante — **JSONs idénticos per-query** (determinismo
confirmado; `determinism_hash` A=`0d44653e`, V1=`289f8470`, V2=`0c471a33`,
V3=`48888238`).

### Resultados (pad 4, A vs V1/V2/V3)

| Métrica | A (control) | V1 (excl. noise) | V2 (S4×3) | V3 (excl. raíz) | Gate §17.4 |
|---|---|---|---|---|---|
| **leak** | 0.442 | **0.250** | 0.442 | 0.433 | **✅ V1 ≤0.308** |
| attr total | 12/20 | 12/20 | 12/20 | 12/20 | ❌ (≥13) |
| pRel | 0.415 | **0.584** | 0.415 | 0.421 | ✅ ≥0.121 |
| containment | 1.0 | 1.0 | 1.0 | 1.0 | ✅ ≥0.80 |
| Q02/Q06/Q08/Q09 | 3/1/1/2 | 3/1/1/2 | 3/1/1/2 | 3/1/1/2 | ✅ sin regresión |
| Q03/Q04/Q07/Q10 | 0/2/2/1 | 0/2/2/1 | 0/2/2/1 | 0/2/2/1 | ✅ sin regresión |
| determinismo G2 | — | V1r1=V1r2 | V2r1=V2r2 | V3r1=V3r2 | ✅ |

### Análisis por variante

- **V1 (exclusión dura de noise en ctx final) — CRUZA el objetivo PRIMARIO:**
  leak 0.442 → **0.250** (-43%), pRel 0.415 → **0.584** (+41%), contain 1.0,
  **cero regresiones** en los 8 golds, G2 determinista. La fuente A (noise de
  sesión, 55% del leak) era la causa dominante y la exclusión la elimina sin
  tocar golds (Q04/Q06 viven en CHANGELOG.md, que NO es noise → preservados).
  **PERO attr = 12/20 < 13/20** (gate #2): V1 no incluye DICT_H1_B de 17B, así
  que Q05 sigue en 0 (el pasaje ADB.md:1-9 con `adb devices -l` no cruza el
  piso para el qtext de Q05). El gate completo NO se cruza.
- **V2 (refuerzo S4, W 0.5→1.5) — SIN EFECTO:** resultados IDÉNTICOS a A en
  todo (leak 0.442, pRel 0.415, attr 12/20). El peso de S4 en el score final
  no cambia el ranking cuando s1/s2/s3 dominan — la fuente A entra por el gate
  S1 ≥ 0.545, no por el score final. Variante descartada.
- **V3 (exclusión raíz no-Knowledge) — EFECTO MÍNIMO:** leak 0.442 → 0.433
  (-2%), pRel 0.421. La fuente D (3 paths, 10%) era demasiado pequeña para
  cruzar el umbral. Variante descartada.

### Veredicto

1. **El leak estructural SÍ es reducible**: V1 demuestra que excluir el noise
   de sesión del contexto final baja el leak 0.442 → 0.250 (-43%) sin perder
   attr ni regresar en prosa, con pRel mejorado y determinismo G2. La hipótesis
   H17C queda **confirmada** (la fuente A era la causa dominante).
2. **V1 NO está aprobado para producción**: el gate §17.4 exige attr ≥ 13/20 y
   V1 da 12/20 (Q05 no rescatado sin DICT_H1_B). No se modifica el criterio
   retrospectivamente (regla metodológica conservada).
3. **V2 y V3 descartadas**: sin efecto / efecto mínimo; no cruzan leak.
4. **Combinación natural pendiente (NO probada en este paso, sería 2 factores):**
   V1 (ensamblado: mata el leak) + DICT_H1_B de 17B (ranking: rescata Q05) son
   ORTOGONALES — V1 ataca el ensamblado, B ataca el ranking. La combinación
   podría cruzar el gate completo (leak 0.250 + attr 13/20). Requiere un
   experimento nuevo (17D) con diseño y gate propios y aprobación del usuario.
5. **Conclusión de adopción: NO adoptar V1 todavía.** Congelar 17C como
   evidencia válida; V1 = candidato positivo/no adoptado (igual que B en 17B).
   Próximo frente: **17D — V1 + DICT_H1_B combinados** (si el usuario lo
   aprueba), o volver a Q01 con puente conceptual/relacional (ADB discovery/
   transport/authorization).

---

## ⛔ VEREDICTO PASO 17D (2026-08-15) — combinación V1 + DICT_H1_B: STOP metodológico / NO EVALUADO

**Spec:** `combine-17D-DESIGN.md` (commit `ad04631`). **H17D:** V1 (ensamblado:
excluye noise de sesión del ctx final) + DICT_H1_B (ranking: rescata Q05) son
ortogonales por construcción; la combinación podría cruzar el gate completo
§17.4 por primera vez. **Regla §3.1 de la spec:** los controles A, B-solo y
V1-solo deben reproducir EXACTAMENTE sus esperados históricos (todas las
métricas contractuales, igualdad per-query, sin tolerancia) antes de evaluar
T = V1 + DICT_H1_B. Si cualquiera no reproduce → **STOP, no se evalúa T**.

**Runner:** mecanismo 17C congelado (`run-leak-17C.sh`, `--variant` + `--dict`).
Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, piso 0.545, LIMIT=10. Sin runner nuevo
(la combinación es una invocación, no un mecanismo nuevo). **T NO se ejecutó.**

### Resultados de los controles (×2 corridas G2 cada uno, corpus 17D `029ed669`)

| Métrica | **A** esperado §3.1 → obtenido | **B-solo** esperado → obtenido | **V1-solo** esperado → obtenido |
|---|---|---|---|
| `attributed` per-gold | 0,3,0,2,0,1,2,1,2,1 → **idéntico** ✅ | 0,3,0,2,1,1,2,1,2,1 → **idéntico** ✅ | 0,3,0,2,0,1,2,1,2,1 → **idéntico** ✅ |
| attr total | 12/20 → **12/20** ✅ | 13/20 → **13/20** ✅ (Q05 rescatado) | 12/20 → **12/20** ✅ |
| `cross_domain_leakage` | Q10 0.5 → **0.333** ❌ | Q10 0.5 → **0.333** ❌ | **idéntico** ✅ |
| leak avg | 0.442 → **0.425** ❌ | 0.442 → **0.425** ❌ | 0.250 → **0.250** ✅ |
| `passage_relevance` | 0.415 → **0.415** ✅ | 0.531 → **0.531** ✅ | 0.584 → **0.581** ❌ (Q10 0.333→0.300) |
| contain | 1.0 → 1.0 ✅ | 1.0 → 1.0 ✅ | 1.0 → 1.0 ✅ |
| G2 interno (r1=r2) | ✅ per-query idéntico (hash difiere solo por `index_cache_hit`/`elapsed`) | ✅ idéntico (hash `c0dedcba…` igual) | ✅ idéntico (hash `8962fc9d…` igual) |

### Diagnóstico: drift real del corpus, no aleatoriedad

- **`corpus_hash`: `236a87fa` (17C, 7653 líneas) → `029ed669` (17D, 7803 líneas).**
- Archivos del corpus modificados entre 17C y 17D:
  `README.md` (+16/-4, commit A), `ai-context/CHANGELOG.md` (+12),
  `ai-context/CONTINUE.md` (+31/-7), `ai-context/SESION.md` (+64).
- Queries afectadas (comparación `ctx_passages` histórico vs nuevo):
  - **Q10** (leak 0.5→0.333; pRel 0.333→0.300 en V1): CHANGELOG.md creció +12 →
    pasajes gold desplazados (`CHANGELOG.md:261-269` → `273-281`) y
    `PROJECTS.md:82-90` salió del ctx.
  - **Q03** (ctx_size 2→3): CONTINUE.md creció +31 → pasajes distintos de
    `ai-context/CONTINUE.md` en el ctx (147-155 → 109-117/181-189).
  - **Q04/Q06**: mismas líneas desplazadas de CHANGELOG.md (solo range; métricas
    agregadas sin cambio).

### Veredicto

1. **STOP según la regla §3.1** — A no reproduce (leak 0.425 ≠ 0.442), B-solo no
   reproduce (leak 0.425 ≠ 0.442), V1-solo no reproduce (pRel 0.581 ≠ 0.584).
   La regla funcionó exactamente como fue diseñada: **el drift silencioso del
   corpus quedó detectado ANTES de evaluar T**, evitando una conclusión falsa
   sobre una mejora del sistema.
2. **T = V1 + DICT_H1_B NO se ejecutó.** No existe veredicto sobre la
   combinación (ni PASS ni FAIL del tratamiento); 17D queda **bloqueado antes
   del tratamiento / NO EVALUADO**.
3. **Gates y esperados históricos NO modificados.** 17B/17C siguen siendo
   referencia histórica válida (corpus `236a87fa`).
4. **Los 6 JSONs de sanity son internamente deterministas** (G2 confirmado bajo
   el corpus `029ed669`); lo que no se reproduce es la comparación vs el
   histórico 17B/17C, por drift del corpus — no por no-determinismo.
5. **Hallazgo metodológico registrado:** el corpus de Buffy NO está aislado de
   su propio estado operativo — CHANGELOG/CONTINUE/SESION/README participan del
   fenómeno medido y su crecimiento entre pasos altera posiciones de pasajes,
   contenido recuperado, leak, pRel y paths del ctx. Conecta con el frente
   arquitectónico pendiente SESION/CONTINUE local.
6. **No se re-congela `029ed669` ni se actualizan los esperados** (decisión del
   usuario): cambiar la referencia después de observar el drift debilitaría la
   disciplina. Continuar exigiría diseñar primero un mecanismo de
   **fixture/corpus experimental congelado e inmutable** (trabajo de diseño
   nuevo, no parte de 17D). Próximo experimento solo después de eso.

**Evidencia:** `combine-17D-PC-2026-08-15-{control-A,control-A-r2,B-solo,B-solo-r2,V1-solo,V1-solo-r2}.json`
(6 JSONs, commit de cierre). **Estado: CERRADO — STOP metodológico / NO EVALUADO.**

---

## 🏗️ INFRAESTRUCTURA — Fase D1 del fixture experimental (2026-08-15)

**Diseño:** `FIXTURE-EXPERIMENTAL-DESIGN.md` (congelado, commit `bd52050`).
**D1 implementado:** `scripts/tests/evals/build-fixture.sh` — congela el corpus en
`fixtures/<fixture_id>/corpus/` + `manifest.json` de identidad completa.

### Verificación D1 (ejecutada, sin EVAL nuevo)

| Criterio | Resultado |
|---|---|
| Sintaxis (`bash -n`) | ✅ |
| Build real (corpus vivo actual) | ✅ 45 archivos / 366358 bytes / 5338 líneas · `corpus_hash 0af49cc…` · `config_hash b2b8b35…` |
| **Determinismo: re-build → mismo hash** | ✅ `0af49cc666d872a6` idéntico |
| **mtime NO afecta** (touch de todos los archivos) | ✅ mismo hash por contenido |
| **contenido SÍ afecta** (editar README.md del corpus) | ✅ `b9430213f5054a12` ≠ original |
| **Exclusión efectiva** (gate §6.7) | ✅ 0 archivos de instancia/memoria en `corpus/` (find vacío) |
| **`--include` opt-in de memoria** | ✅ `--include ai-context/memories/MEMORY.md` → 46 archivos, MEMORY.md presente |
| Fixture ya existente → `exit 2` | ✅ |

### Semántica implementada (diseño §3.2)

- **Excluidos por defecto** (nunca en fixture normal): SESION, SESION-archive,
  CONTINUE, SNAPSHOT, facts.yaml, `.sync-state` (instancia) + `memories/` (memoria).
- **`--include`** re-incluye explícitamente (distractores, memoria para EVALs que la midan).
- **`corpus_hash` POR CONTENIDO** (`sha1(path:contenido)`, no mtime) — determinista entre máquinas.
- **`config_hash`** = sha256 del bloque config canónico (model + params + variant + dict + eval + runner).

**Pendiente (NO abierto):** D2 (build + commit del primer fixture real), D3
(runner `--fixture` + validación de mutación + campos nuevos en el JSON), D4
(gate §6 completo), D5 (registro formal). **Ningún EVAL nuevo.**

### D3 — runner `--fixture` (2026-08-15) — implementado y verificado

**Cambio:** `run-leak-17C.sh` acepta `--fixture <dir>` (+ `--allow-fixture-mutation`).

- **Separación CORPUS/PIPELINE:** con `--fixture`, `REPO` = `<dir>/corpus` (congelado),
  `PIPELINE_ROOT` = árbol vivo (scripts/lib + router). El fixture es SOLO datos.
- **Hash por contenido en modo fixture** (no mtime); `--repo` intacto (mtime histórico).
- **Validación de inmutabilidad:** `corpus_hash` real vs `manifest.corpus.corpus_hash`
  → mismatch = **STOP (exit 2), sin reindex silencioso**; solo `--allow-fixture-mutation` + `--reindex` continúan.
- **JSON de salida:** `fixture_id`, `fixture_corpus_hash`, `config_hash`, `runner_version`
  (del manifest); `commit_sha` = `manifest.source.commit_sha` (identidad del **CORPUS**
  de origen) y `pipeline_commit` = commit del **PIPELINE/runtime** (árbol vivo que
  ejecuta la corrida). Distinción explícita corpus/source vs pipeline/runtime:
  el fixture solo sustituye DATOS, nunca la lógica (router, scripts/lib, runner).
  En modo `--repo` ambos coinciden (mismo árbol) — comportamiento histórico intacto.
- **Garantía de separación verificada:** el fixture congelado contiene 0 archivos
  `.sh`/`.py`/`.js` — es solo datos; el pipeline siempre viene de `PIPELINE_ROOT` (árbol vivo).

**Verificado (copia en /tmp, congelado intacto):**

| Caso | Resultado |
|---|---|
| `--repo` (histórico) | ✅ flags y ruta intactos |
| `--fixture` inválido (sin manifest) | ✅ exit 2 |
| `--fixture` íntegro | ✅ `✓ fixture íntegro: corpus_hash 0af49cc666d872a6 == manifest` |
| **Mutación** (editar README.md del corpus copiado) | ✅ `✗ FIXTURE MUTADO: esperado 0af49cc…, real 05cf29a…` → **exit 2, sin JSON** |
| Restauración | ✅ íntegro de nuevo |
| Congelado original | ✅ hash real == manifest (`0af49cc666d872a6`) |

**Pendiente (NO abierto):** D4 (validación multi-PC), D5 (gate final §6 completo).
**Sin EVAL nuevo; sin benchmark comparativo.**

### D4 — validación multi-dispositivo (2026-08-15) — PASADO

Criterio §6.3 del gate: *checkout limpio → mismo `corpus_hash` por contenido, sin
`--reindex`, cache miss inicial OK.*

| Entorno | Checkout | Caché | Resultado |
|---|---|---|---|
| A (repo actual) | `bd931aa` | — | `corpus_hash 0af49cc666d872a6` (referencia) |
| B (git clone limpio) | `bd931aa` | `XDG_CACHE_HOME` fresco (miss) | `✓ fixture íntegro: corpus_hash 0af49cc666d872a6 == manifest` |
| C (segundo git clone limpio) | `bd931aa` | `XDG_CACHE_HOME` fresco (miss) | `✓ fixture íntegro: corpus_hash 0af49cc666d872a6 == manifest` |

**Verificado (9 puntos de D4):**

1. ✅ Fixture obtenido desde Git en checkout limpio (clone A→B, A→C).
2. ✅ `--fixture` ejecutado en B y C (entornos independientes).
3. ✅ `corpus_hash` EXACTO e idéntico en A/B/C: `0af49cc666d872a6`.
4. ✅ `manifest.json` idéntico (sha256 `34ef78c2…` igual en A y B).
5. ✅ Cache miss inicial aceptable y NO altera la identidad (hash por contenido,
   independiente del índice; 0 cachés con `0af49cc` antes de D4).
6. ✅ **No hace falta `--reindex`** para establecer la identidad (validación ocurre
   antes de cargar/construir el índice).
7. ✅ Pipeline del checkout (árbol vivo) — `scripts/lib` presente en B/C; el fixture
   solo aporta datos (0 scripts).
8. ✅ Fixture y pipeline NO modificados; entorno de test eliminado; `git status` limpio.
9. ✅ Sin queries completas de EVAL, sin resultados 17E, sin benchmark.

**Conclusión:** mismo fixture + contenido idéntico → mismo `corpus_hash`,
independiente de la máquina/checkout/caché. D4 PASADO.

### D5 — GATE FINAL de Fase D (2026-08-15) — ✅ PASADO

**Pregunta del gate:** ¿la infraestructura de fixture cumple el contrato congelado
de Fase D? (NO reinterpreta 17B/17C/17D — solo valida el mecanismo.)

| Criterio | Verificación | Resultado |
|---|---|---|
| §6.1 Reproducibilidad | 2 validaciones de identidad consecutivas | ✅ `0af49cc666d872a6` idéntico |
| §6.2 Inmutabilidad frente al árbol vivo | editar `CONTINUE.md`/`CHANGELOG.md` → fixture sin cambios | ✅ mismo hash `0af49cc666d872a6` |
| §6.3 Estabilidad multi-máquina | 3 checkouts limpios A/B/C + re-verificación en D5 | ✅ mismo hash (D4 + confirmación) |
| §6.4 Detección de mutación → STOP | editar `README.md` del corpus copiado | ✅ `✗ FIXTURE MUTADO` → exit 2, sin reindex silencioso |
| §6.5 Config sensible | `config_hash` base vs `PADS=[8]` | ✅ `b2b8b357…` ≠ `fdfc5256…` |
| §6.6 Suite intacta | full + quick | ✅ **315 OK** · **299 OK** (0 FAIL) |
| §6.7 Exclusión efectiva | find de instancia/memoria/pipeline en corpus | ✅ 0 archivos de instancia/memoria · 0 scripts (solo datos) |

**Fase D: CERRADA y APROBADA como INFRAESTRUCTURA** (no como resultado
experimental). La barrera entre estado operativo del proyecto y estado
experimental quedó implementada y verificada: `--repo` (árbol vivo, histórico)
vs `--fixture` (corpus congelado, hash por contenido, mismatch → STOP).
**Ningún EVAL nuevo (17E+); ningún resultado experimental derivado de este gate.**

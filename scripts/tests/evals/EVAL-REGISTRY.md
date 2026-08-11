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


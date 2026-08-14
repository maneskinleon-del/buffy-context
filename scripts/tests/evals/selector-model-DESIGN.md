# Paso 14 — Selector quality-aware con pasaje disponible (diseño)

> Estado: **✅ EJECUTADO (2026-08-13)** — 14A corrido completo, veredicto: **Rama B,
> sin 14B** (phi3.5 no pasa el gate). Resultados y veredicto en EVAL-REGISTRY.md
> (§14A). Ajustes del usuario: (1) BGE scorer ≠ Phi judge (dos mecanismos
> distintos, no implementaciones intercambiables); (2) **gold-vs-distractor pair
> test** obligatorio como parte de 14A (Q06/Q08 aislados); (3) gate con
> **no-regresión ≥16/20** (guard) + **target 18/20** (no bloqueante, obligatorio
> para declarar mejora) + Q06/Q08 gold atribuidos como objetivos. `ollama pull
> phi3.5` autorizado (~2.2 GB).
> Base: Pasos 12-13 CERRADOS sin adopción (E1/E2/E3 ❌ gate · F1/F2 ❌ gate).
> Congelados (heredados): EVAL `98a0e308…`, pool H2 (dict `b0406a33…`), orden R1-LEX
> (`8316343e…`), scorer E2 (θ=0.55), presupuesto 10.4k, rama P (F1/F2), cache de
> pasajes validado, runtime.
> Dirección del usuario (2026-08-13): separar el problema de **selección** del
> problema del **modelo**. La pregunta es: *si el pasaje gold ya está disponible,
> ¿podemos seleccionarlo correctamente sin volver a modificar la generación?* —
> con una mini-fase de modelo primero (14A) para dejar de depender de corridas de
> ~40-50 min, y el selector después (14B).

---

## 1. Diagnóstico que motiva el diseño (medido en F2, Paso 13)

El funnel de F2 quedó en **found 20 → available 18 → selected 20 → attributed 16**.
Los **2 casos disponibles-no-atribuidos** son el target de este paso:

| Caso | Aguja | Estado | Causa |
|---|---|---|---|
| Q06 | `FF_SEEN` | `in_pool_top10` · `other_file_match` (SESION-archive.md) | disponible en pasaje P de CHANGELOG.md (gold), pero el gate E2 seleccionó el pasaje **no-gold** de SESION-archive.md que también contiene la aguja |
| Q08 | `P_TERM_OPACITY` | `in_pool_top10` · `other_file_match` (AGENTS.md, SESION-archive.md) | disponible en pasaje P de System.md (gold), pero el seleccionado viene de AGENTS.md/SESION-archive.md; `picom` sí se atribuye |

**Patrón común:** disponibilidad ✅, selección ✗ — cuando dos pasajes contienen la
aguja (uno gold, otro no-gold), el content-scorer actual (bge-m3 cosine ≥ 0.55) no
prefiere el gold. Q04 queda **fuera** de este paso: su gold (CHANGELOG.md) no está
ni en kno ni en el top-K del pool → `available=0` es un problema de candidatos, no
de selección (no juzgar un selector con Q04).

## 2. Preguntas experimentales

- **14A:** dado el MISMO conjunto congelado de pasajes, ¿un modelo pequeño (Phi)
  reproduce las decisiones gold/no-gold del scorer actual (bge-m3) con
  calidad suficiente × velocidad × estabilidad bajo carga, como candidato a
  **modelo operativo** (NO reemplaza la evidencia histórica)?
- **14B:** sobre los pasajes **ya disponibles** (pool expandido F2), ¿un selector
  quality-aware distinto (bge-m3 ref vs Phi juez) sube `attributed` de 16/20
  hacia 18/20 sin perder pRel/leakage? → responder *por qué los 2 pasajes
  correctos no fueron seleccionados* y si el selector puede distinguirlos.

## 3. 14A — Benchmark de modelo (sin tocar retrieval/ranking/presupuesto/corpus)

**Dos mecanismos DISTINTOS (ajuste del usuario) — NO son implementaciones
intercambiables de la misma función:**

- **bge-m3 = scorer numérico determinista** (cosine ≥ θ) — medición continua,
  barata, reproducible.
- **Phi = judge generativo semántico** (clasificación por razonamiento) — si
  acierta Q06/Q08, sería evidencia de una **capacidad diferente** (semántica),
  no simplemente "un mejor scorer".

### 3.1 Gold-vs-distractor pair test (OBLIGATORIO, primero — ajuste del usuario)

Para los 2 casos del diagnóstico tenemos exactamente el par que estudiar:

| Caso | pasaje GOLD (aguja en archivo correcto) | pasaje DISTRACTOR (misma aguja en archivo incorrecto) | Pregunta |
|---|---|---|---|
| Q06 | CHANGELOG.md (FF_SEEN) | SESION-archive.md | ¿elige Gold? |
| Q08 | System.md (picom / P_TERM_OPACITY) | AGENTS.md / SESION-archive.md | ¿elige Gold? |

- **Métrica estrella: gold-over-distractor accuracy** por modelo (¿cuál de los
dos pasajes es la evidencia? dado query + X).
- Sin ruido de ranking, presupuesto ni composición de contexto: solo los pares.
- **Si Phi no resuelve los pares aislados, no tiene sentido esperar que arregle
  el contexto completo** (gate temprano del par test).
- También se mide el par test de bge-m3 (referencia) para la comparación honesta.

### 3.2 Benchmark completo del pool congelado

**Conjunto congelado:** snapshot del pool expandido F2 por query (pasajes L∪X∪S∪P,
tal como los construyó el Paso 13 — mismo código, mismos candidatos) + etiqueta
gold por pasaje: `1` si el pasaje contiene ≥1 aguja gold (definición de la serie),
`0` si no. Fixture versionado: `selector-pool-frozen-2026-08-13.json` (el runner de
14A lo regenera con `--expand f2` y lo congela; nunca vuelve a variar).

**Tarea de decisión por pasaje** (query, términos X, pasaje):

- **bge-m3 (referencia congelada):** `cosine(emb(query+X), emb(pasaje)) ≥ 0.55` —
  exactamente el scorer E2 del Paso 12 (con su cache validado).
- **Phi (candidato):** prompt juez corto y fijo — *"¿el pasaje contiene la
  evidencia que responde la consulta? responde solo sí/no"* — `temperature=0`,
  `seed` fijo (lo que soporte Ollama), salida parseada.

**Métricas (por modelo):** gold-over-distractor accuracy (3.1) · tiempo/pasaje
(avg) · tiempo total · determinismo (2 corridas → decisiones idénticas; bge-m3 ya
probado, Phi es el que se examina) · memoria aprox (`ollama ps` RSS con modelo
cargado) · precisión / recall / accuracy de la decisión vs etiqueta gold ·
concordancia de decisiones bge-m3 vs Phi.

**Criterio operativo (decisión del usuario):** calidad suficiente × velocidad ×
estabilidad bajo carga. Phi debe superar **simultáneamente** calidad/coste/
determinismo para ser modelo operativo; si no → **conservar bge-m3** y 14B usa
bge-m3. Ejemplos de lectura: BGE 85%/2min vs Phi 95%/20min NO es mejora
operativa; BGE 85%/2min vs Phi 95%/3min SÍ es candidato interesante.

**Modelos:** bge-m3 (ref) · **phi3.5** (q4, ~2.2 GB, primario — se ajusta a 13 GB
RAM; pull autorizado) · Phi-4 Mini (alternativa si phi3.5 no alcanza).
**qwen2.5:7b descartado** (4.7 GB, lento bajo carga — decisión del usuario).

**Restricciones:** NO se modifica retrieval, ranking, presupuesto, corpus, θ ni la
evidencia histórica. Phi solo decide si puede ser el **modelo operativo barato**
para las iteraciones siguientes. Phi es **candidato, no reemplazo predeterminado**.

## 4. 14B — Selector quality-aware (solo sobre pasajes YA disponibles)

```text
H2 → R1 → F1/F2 (congelados) → pasajes candidatos (pool expandido)
        ↓
┌─────────────────────────────┐
│ selector quality (14B)      │  ← LA ÚNICA VARIABLE
│  bge-m3 θ (ref) vs Phi juez │
└─────────────────────────────┘
        ↓
   presupuesto 10.4k → CTX final
```

- **Restricción dura: el selector NO genera candidatos nuevos** (ni pasajes, ni
  archivos, ni términos). Solo decide qué pasajes del pool expandido F2 entran al
  ctx — así se mide exactamente selección, nada más.
- **Variable:** la función de decisión del gate (bge-m3 cosine ≥ 0.55 [ref] vs Phi
  juez). Todo lo demás idéntico a F2 (misma construcción de pool, mismo orden R1,
  mismo presupuesto, mismo cache).
- **Métricas:** funnel por query (found → available → selected → attributed) ·
  pRel · leak · gap_to_top10 · baseline_regression · tokens. Q06/Q08 = casos test
  (¿los 2 pasajes gold disponibles pasan al ctx como gold?).
- **Q04 excluido del veredicto** (candidate availability, no selección — documentado).

## 5. Gates (pre-fijados, idénticos a la serie — sin relajación tras ver resultados)

```text
search_recall        > 0.100      (selección pasajes, v3.1)
passage_relevance   ≥ 0.600      (capa de pasajes)
leakage             ≤ 0.267      (cross-domain)
tokens              ≤ 10.4k      (presupuesto)
gold_containment    ≥ 0.80
baseline_regression ≤ 0.167      (vs R1 top10)
attributed          ≥ 16/20      GUARD no-regresión (no perder lo de F2)
```

+ **Objetivos del veredicto de MEJORA (ajuste del usuario) — no bloqueantes pero
  obligatorios para declarar éxito (evita "éxito" por simplemente no empeorar F2):**

```text
target_attribution  = 18/20    (18 available → 18 attributed)
Q06                 = gold atribuido (FF_SEEN → CHANGELOG.md en ctx)
Q08                 = gold atribuido (P_TERM_OPACITY → System.md en ctx)
```

+ diagnósticos: funnel, casos Q06/Q08 por fact. Si 14B pasa → NO se adopta
automáticamente: se diseña el siguiente paso con la evidencia (regla de la serie).

## 6. Riesgos / confounds (declarados antes de medir)

1. **Phi en CPU puede ser ~10× más lento por pasaje que bge-m3** (LLM generativo
   vs embedding en batch). El criterio no es "mejor score": es
   calidad suficiente × velocidad × estabilidad bajo carga. Si no gana en
   calidad/atribución, el resultado del benchmark ES "mantener bge-m3".
2. **No-determinismo del LLM:** temp=0 + seed fijo en Ollama; si 2 corridas no
   coinciden en decisiones, Phi falla el gate de determinismo (G2) y queda
   descartado como juez reproducible.
3. **Descarga de Phi (~2.2-3 GB):** requiere decisión del usuario antes de `ollama
   pull` (disco/tiempo). No se asume.
4. **Etiqueta gold del benchmark:** needle-in-passage (definición de la serie).
   Si el pasaje gold y el no-gold contienen la aguja (Q06/Q08), la etiqueta es
   `1` para ambos → el benchmark mide detección de aguja, y la **atribución**
   (archivo gold en ctx) se mide en 14B con el funnel. No confundir las dos capas.
5. **Confound de composición:** 14B re-selecciona desde el pool expandido F2
   (mayor que top10 de R1) → `fraccion_podada` negativa NO es ahorro (misma
   advertencia de Q1/Q2/Paso 12).

## 7. Qué NO se hace (regla acumulada de la serie)

- NO tocar runtime (`buffy-search.sh`/`buffy-router.sh`).
- NO usar `gold_files` como señal del selector (la distinción gold/no-gold debe
  salir del contenido, no del fixture).
- NO recalibrar θ (0.55) ni K (10) — son resultados de los pasos previos, no
  variables.
- NO mezclar variables: 14A (modelo) ANTES de 14B (selector); Phi solo si el
  benchmark lo justifica.
- NO medir sobre el working tree compartido si el corpus se desvió → worktree
  `18df679` + **no tocar `ai-context/CONTINUE.md`/`SESION.md` mientras se mide**
  (lección FWD del Paso 13: drift del corpus FTS5 de buffy-search).
- NO adoptar automáticamente si el gate pasa.

## 8. Orden de ejecución (tras aprobación)

```text
0. APROBACIÓN del usuario: spec con ajustes ✅ + `ollama pull phi3.5` autorizado ✅
1. PRE-FLIGHT FWD: corpus intacto (CONTINUE/SESION sin tocar) + E2-none bit-idéntico
2. 14A: (a) pair test gold-vs-distractor Q06/Q08 → gold-over-distractor accuracy;
   (b) fixture congelado (pool F2 + etiquetas) → benchmark bge-m3 vs Phi
   (tiempo · determinismo ×2 · memoria · prec/rec) → registro
3. decisión modelo operativo (bge-m3 | Phi) basada en 14A, sin tocar evidencia histórica
4. 14B: selector con el modelo decidido, sobre el pool F2 congelado ×2 (G2)
5. comparar 14B vs F2 (funnel, Q06/Q08, pRel/leak) → registrar en EVAL-REGISTRY
6. revisar con code-reviewer
7. commit + push (git commit -- paths) + detener(se) (runtime intacto)
```

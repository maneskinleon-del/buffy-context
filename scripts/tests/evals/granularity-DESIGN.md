# Paso 16 — Granularidad del pasaje (diseño)

> Estado: **⏳ DISEÑO (2026-08-14)** — NO implementar todavía. Aprobación del
> usuario pendiente. Esta spec declara hipótesis, variantes, gates e invariantes
> ANTES de medir, con la evidencia preliminar ya medida.
>
> Base: EVAL `98a0e308…` · pool congelado `selector-pool-frozen-2026-08-13.json`
> (F2 + rama X, generado 2026-08-13) · selector M3 V6 (S1+S2+S3+S4, gate rescue
> 0.545) · rama X H1 del pipeline real (`expand_query.py`, 2026-08-14).
>
> Origen: veredicto de la sesión 2026-08-14 — Q03 aceptado como límite; la
> causa raíz se atribuyó a la granularidad del pasaje (PAS_PAD=4). Esta spec
> formaliza esa hipótesis para MEDIRLA con su propio gate (regla de la serie:
> toda atribución sin medir es sospechosa).

---

## 1. Motivación (medida, no asumida)

La sesión 2026-08-14 midió que el gold de Q03 (`gh pr create`, Commands.md:64)
tiene S1 = 0.493 con la ventana ±4 y la query expandida H1 — bajo el piso 0.545.
La línea exacta con un subconjunto relevante de términos daba 0.613 (sobre el
piso). La conclusión tentativa fue "la granularidad del pasaje es el cuello de
bottleneck". **Esta spec existe para medir esa atribución formalmente.**

### 1.1 Evidencia preliminar (medida HOY, antes de esta spec)

**Hallazgo A — el attr 19/20 del veredicto 15B incluye oráculo en la query.**
El harness 15B puntúa `qtext = query + terms_del_fixture`. Los terms del
fixture para Q03 son: `push commit create make new add pull "pull request"
request` (H1) **+ `gh pr create git push origin pr create crear pr` (H2,
oráculo por query — prohibido por la regla de la serie)**. Medido sobre el
mismo pool congelado:

| Mecanismo de query | attr | Q01 | Q02 | Q03 | Q04 | Q05 | Q06 | Q07 | Q08 | Q09 | Q10 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| fixture-terms (H1+H2, como 15B) | **19/20** | 2 | 3 | 2 | 2 | 1 | 1 | 2 | 2 | 2 | 2 |
| **H1 real** (query + DICT_H1, pipeline) | **11/20** | 0 | 3 | 0 | 2 | 0 | 1 | 1 | 1 | 2 | 1 |

**El pipeline real (rama X H1, sin oráculo) rinde 11/20 sobre el pool
congelado — no 19/20.** Q01/Q03/Q05 (golds de comando/símbolo puro) caen a 0.
El "límite Q03" documentado en la sesión es un caso particular de esto: con H1,
Q03 nunca atribuye ni con ventana ±4.

**Hallazgo B — la granularidad fina NO cruza el piso por sí sola (diagnóstico
S1 por granularidad, query natural).**

| Gold | Línea exacta | Ventana ±4 | ¿Línea cruza 0.545? |
|---|---|---|---|
| Q01 `adb tcpip 5555` | 0.372 | 0.351 | ❌ |
| Q01 `adb connect` | 0.364 | 0.329 | ❌ |
| Q02 `rish -c` | 0.441 | **0.608** | ❌ (pero ±4 sí) |
| Q02 `moe.shizuku…` | 0.636 | 0.635 | ✅ |
| Q03 `git push origin` | 0.506 | 0.491 | ❌ |
| Q03 `gh pr create` | 0.515 | 0.468 | ❌ |
| Q04 `xset -dpms` | 0.654 | 0.562 | ✅ |
| Q05 `useState` | 0.411 | 0.366 | ❌ |
| Q06 `FF_SEEN` | 0.277 | 0.408 | ❌ |
| Q07 `dumpsys thermalservice` | 0.387 | 0.484 | ❌ |
| Q07 `force_gpu_rendering` | 0.486 | 0.527 | ❌ |
| Q08 `picom` | 0.430 | 0.428 | ❌ |
| Q08 `P_TERM_OPACITY` | 0.506 | **0.597** | ❌ (pero ±4 sí) |
| Q09 `scaling_governor` | 0.498 | 0.581 | ❌ (pero ±4 sí) |
| Q10 `dumpsys thermalservice` | 0.415 | 0.389 | ❌ |
| Q10 `thermal_control` | 0.384 | 0.434 | ❌ |

Lectura: **la granularidad NO es monótona** — la línea exacta ayuda a comandos
puros (Q01/Q03/Q04) pero DAÑA golds de prosa (Q02/Q06/Q08/Q09) que dependen del
contexto vecino. Y **casi ningún gold cruza el piso 0.545 con query natural**
(con o sin granularidad fina): los únicos que cruzan son Q02/Q04/Q08/Q09 ya
resueltos. La hipótesis "línea exacta rescata Q03/Q05" **no se sostiene con la
query natural** (0.515/0.411 — ambos bajo el piso).

### 1.2 Hipótesis declarada (refinada por la evidencia)

> **H16:** cambiar la granularidad del pasaje (PAS_PAD) NO rescata los golds de
> comando/símbolo (Q01/Q03/Q05) — su S1 es bajo por el puente semántico
> (query natural ↔ símbolo técnico), no por la ventana. La granularidad afecta
> la atribución de golds de PROSA (Q02/Q06/Q08/Q09), donde la ventana ±4 es
> necesaria. Esperado: ninguna variante de PAS_PAD supera el gate con H1 real.

**Hipótesis nula (lo que la medición debe refutar para adoptar):** existe un
PAS_PAD ∈ {0,1,2} que con H1 real eleva attr ≥ 11/20 sin regresión en Q02/Q06/
Q08/Q09.

---

## 2. Qué ya se probó y falló (regla de no-repetir)

| Mecanismo | Paso | Resultado | Lección |
|---|---|---|---|
| Expansión de query H1 (generación) | 10 | candidate gap cerrado 5/6, selección RRF rota | la expansión arregla la generación, no la selección |
| Rerank R1/R2 | 10B | R1 0.750 recall pero pRel/leak fallan | falta calidad, no ranking |
| Selector M3 (S1-S4) | 15/15B | attr 19/20 (con oráculo en query), 16/20 (15A) | el piso S1 es esencial; V6 adoptado |
| Rama X al pipeline (H1) | 2026-08-14 | pool crece 15→91, S1 Q03 mejora +0.025, no cruza piso | H1 mejora la query pero no eleva el S1 del gold sobre el piso |
| **Q03/Q05 como "límite por granularidad"** | **2026-08-14 (esta sesión)** | **NO CONFIRMADO por 1.1B** | la atribución tentativa se refuta con datos: la línea exacta tampoco cruza con query natural |

**Lección acumulada:** cada capa (generación → ranking → selección → query)
mueve el cuello de botella. La granularidad es OTRA capa, y la evidencia
preliminar dice que no es la que bloquea Q01/Q03/Q05 — su S1 es bajo por el
puente semántico del símbolo, no por la ventana.

---

## 3. Alcance (qué NO se toca)

- ❌ El piso rescue 0.545 (decisión 2b + evidencia 15A: soft gate colapsa attr 1/20).
- ❌ El modelo bge-m3 (otro embedding NO arregla la dilución, ya razonado en la sesión).
- ❌ Los términos oráculo H2 (prohibidos por la serie — el fixture los trae para el
  pool, pero la query del experimento usa SOLO query natural + H1 real).
- ❌ `buffy-search.sh`, `buffy-router.sh`, `buffy-selector.sh` (runtime congelado).
- ❌ Calibración post-hoc: PAS_PAD se barre {0,1,2,4}, gates fijados ANTES de medir.

---

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMO POOL      → selector-pool-frozen-2026-08-13.json (pasajes congelados,
                  mismos path/s/e/text — NO se re-genera el pool)
MISMO SELECTOR  → M3 V6 (selector_m3.py, S1+S2+S3+S4, gate rescue 0.545, top-10)
MISMA QUERY     → query natural + terms H1 reales (expand_query.py) — NUNCA
                  los terms del fixture (contienen H2/oráculo)
MISMO GOLD      → gold_files + gold_facts del fixture
MISMA MÉTRICA   → attr (misma definición del harness 15B: gold_fact en ctx
                  Y en gold_files del ctx) + leak + pRel + gold_containment
```

Cambia **una sola cosa**: el PAS_PAD con el que se construyen los pasajes
**sintetizados** del gold (los del pool ya vienen congelados con su s/e propio).
Aclaración honesta: el pool congelado tiene pasajes de 9 líneas (tiles F2). La
variante de granularidad NO puede re-cortar el pool (violaría "MISMO POOL");
lo que se puede variar es el **synth de golds** (cómo se construye el pasaje de
referencia para verificar la atribución) y eso ya está fijo por el harness 15B.
→ **Consecuencia de diseño: la granularidad del POOL no es variable sin
regenerar el fixture, lo que rompería la comparabilidad.** El experimento
mide, por lo tanto, si la granularidad del SYNTH (referencia del gold) cambia
la atribución — proxy limitado, declarado.

> ⚠️ **Limitación estructural declarada:** el fixture congelado fija la
> granularidad del pool en ±4 (tiles F2). Un experimento real de granularidad
> necesita REGENERAR el pool con PAS_PAD variable (runner nuevo sobre el corpus
> real, como el Paso 9 G1/G2), lo que NO es comparable contra este fixture.
> Dos opciones, decisión del usuario:
> - **16A (sobre fixture, barato):** variar solo el synth + aceptar el proxy.
> - **16B (runner nuevo, fiel):** regenerar el pool con PAS_PAD ∈ {0,1,2,4}
>   sobre el corpus real (como G1/G2), EVAL completo, comparación propia —
>   más costoso (embeds por granularidad) pero honesto.

---

## 5. Gate (fijado ANTES de medir)

| Criterio | Umbral | Definición |
|---|---|---|
| attr | **≥ 11/20** (baseline H1 real) **y** mejora en ≥1 gold de Q01/Q03/Q05 | sin regresión en Q02/Q06/Q08/Q09 (golds de prosa) |
| cross_domain_leakage | ≤ 0.308 | gate de la serie |
| passage_relevance | ≥ 0.121 | gate mínimo de pRel de la serie |
| gold_containment | ≥ 0.80 | el pasaje gold cabe en presupuesto |
| determinismo | G2 (2 corridas idénticas) | regla de la serie |

**Regla de lectura (declarada):**
- **attr H1 real = 11/20 es el baseline honesto.** Si PAS_PAD variable no lo
  supera → la granularidad NO es la capa que bloquea Q01/Q03/Q05 → se cierra el
  Paso 16 con veredicto "granularidad descartada como palanca" y Q03/Q05 quedan
  como límite del puente semántico símbolo↔query (no de la ventana).
- Si alguna variante supera attr 11/20 rescatando ≥1 gold de Q01/Q03/Q05 sin
  regresión → señal fuerte para el pipeline real → decisión del usuario sobre
  integrarla (runner 16B antes, regla de compresión).

---

## 6. Riesgos / confounds (declarados antes de medir)

- **R1 — oráculo en el fixture:** los `terms` del fixture contienen H2. El
  harness 15B los usa; el experimento NO. Cualquier comparación con "19/20"
  sin aclarar esto es engañosa. Este documento corrige la lectura: el pipeline
  real rinde 11/20, no 19/20.
- **R2 — proxy de granularidad (solo 16A):** variar solo el synth no cambia la
  granularidad real del pool → el resultado mide poco. Si se quiere medir la
  granularidad de verdad → 16B.
- **R3 — no-monotonía esperada:** la línea exacta daña golds de prosa. Una
  variante global única probablemente NI mejora Q01/Q03/Q05 NI conserva
  Q02/Q06/Q08/Q09 → resultado esperado: descartar granularidad uniforme.
- **R4 — coste (solo 16B):** regenerar el pool por granularidad paga embeds en
  frío (fiel a G1/G2: r0 ≈ 17 min por variante, warm ≈ 1 min).

---

## 7. Qué NO se hace (regla acumulada de la serie)

- No se cambia el piso, el modelo, ni el runtime.
- No se usan términos oráculo (H2) en la query del experimento.
- No se calibra PAS_PAD ni pesos contra el EVAL.
- No se re-genera el fixture congelado (16A) sin decisión explícita.
- No se reabre el Paso 11 (señales Q1/Q2 ya medidas y cerradas).

---

## 8. Orden de ejecución (tras aprobación)

1. Decisión del usuario: **16A (fixture, barato, proxy)** o **16B (runner
   nuevo, fiel, costoso)**.
2. Spec cerrada → implementar runner del paso elegido (harness fiel al 15B,
   query H1 real, sin oráculo) → verificar sanity (16A debe reproducir attr
   11/20 con PAS_PAD=4 y H1 real).
3. Medir PAS_PAD ∈ {0,1,2,4} (16B: regenerando pool; 16A: solo synth) →
   tabla attr/leak/pRel/containment + por-query.
4. Reportar contra el gate §5 → decisión del usuario (adoptar / descartar /
   cerrar con veredicto).

---

## 9. Hallazgo colateral (a registrar en EVAL-REGISTRY aunque el paso no se corra)

**El veredicto 15B (attr 19/20) se midió con query que incluye términos
oráculo del fixture (H2).** El pipeline real con rama X H1 rinde **11/20**
sobre el mismo pool. Implicaciones:
- La mejora V6 (16→19) es REAL dentro del harness 15B, pero el harness mezcla
  oráculo en la query → no es directamente el rendimiento del pipeline real.
- Q01/Q03/Q05 (comandos/símbolos) son los 3 casos que el oráculo "rescataba" y
  el H1 real no atribuye → es exactamente el gap semántico, no la ventana.
- Corrección de lectura: el "límite Q03" de la sesión 2026-08-14 es un caso del
  gap H1-vs-oráculo, no de granularidad. La documentación de esa sesión queda
  corregida por esta spec (§1.1B).

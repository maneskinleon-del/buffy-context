# Paso 9 — Passage-level context selection (diseño + ejecución)

> Estado: **EJECUTADO** (2026-08-12) — G1 y G2 medidos, NO pasan el gate
> (passage_relevance/leakage), nada se adopta. Runner: `scripts/tests/evals/run-passage-PC.sh`.
> Resultados en `EVAL-REGISTRY.md` §Paso 9.
> Base: EVAL con gold definitivo (hash `98a0e308…`), baselines A/B/C/D/E/F medidos.
> Autorizado por el usuario (2026-08-12): "implementar runner → G-H0 → G1 → G2 →
> determinismo → comparar contra gates → registrar → commit → detenerse".
> Nota metodológica: el ctx se deduplica por (path, rango) — MÚLTIPLES pasajes del
> mismo archivo entran al ctx (corregido tras review; la v1 solo dejaba 1 por path).

## 1. Objetivo e hipótesis

**Pregunta:** ¿cambiar la unidad de contexto de **archivo completo** a **pasaje**
(líneas relevantes / sección) permite entregar el gold dentro del presupuesto,
eliminando el truncamiento estructural que hundió la relevance de Q04/Q06, sin
romper recall, leakage ni coste?

**Hipótesis central (derivada de A-F y G-H0):**

> recuperar el archivo correcto NO garantiza poder entregarlo correctamente al modelo.
> El límite del sistema ya no es "cómo encuentro documentos" sino "cómo selecciono la
> evidencia exacta que debo entregar al agente". Con unidad de pasaje:
>
> ```text
> archivo → líneas relevantes → pasajes/chunks → contexto
> ```
>
> en vez de:
>
> ```text
> archivo → archivo completo → contexto
> ```

**Hipótesis secundaria (budget-gold):** el gold canónico de Q04/Q06
(`ai-context/CHANGELOG.md`, 14 375 tok) NO cabe en el presupuesto de 10.4k tokens como
archivo completo, PERO sí cabe como pasaje (ventana ±4 = 310-505 tok). Si el pasaje
contiene el hecho, `context_relevance` deja de colapsar por truncamiento.

## 2. Evidencia acumulada (gold definitivo, v3.1)

| Estrategia | Recall | Relevance | Leakage | Tokens avg | Nota |
|---|---:|---:|---:|---:|---|
| A — AND | 0.000 | **0.533** | **0.267** | **5 197** | limpio pero no recupera |
| B — OR | 0.050 | 0.182 | 0.694 | 45 259 | recupera algo, ruido/coste |
| C — AND-norm | 0.100 | 0.333 | 0.522 | 38 017 | mejora algo, sigue caro |
| D — Semantic | 0.200 | 0.192 | 0.669 | 47 980 | evidencia nueva (Q06), ruido |
| E — Hybrid-RRF | 0.200 | 0.185 | 0.605 | **9 951** | coste controlado, calidad no |
| F — Hybrid-POOL | 0.200 | 0.179 | 0.612 | 10 039 | idéntico a E en lo esencial |

**Diagnóstico G-H0 que motiva este paso:**

- **Q04/Q06** (`in_pool_top10`, sRec=1.0 pero cRel=0.0): gold encontrado y rankeado,
  pero el ARCHIVO gold (14 375 tok) no cabe en el presupuesto → truncado → relevance 0.
- **Q08** (`picom` in_pool_top10 pero `other_file_match`): la rama L genera la aguja,
  pero el gold file queda fuera del top-10 → problema de selección.
- **Q03** (`out_of_pool`): candidate gap → se ataca en el Paso 10 (query expansion),
  NO aquí.

## 3. Alcance (qué NO se toca)

- ❌ `buffy-search.sh`, `buffy-router.sh`, cap-selector, defaults → **runtime congelado**.
- ❌ Query expansion / traducción / sinónimos → **Paso 10**, fuera de este diseño.
- ❌ Calibración de tamaños de pasaje ni umbrales con el EVAL (TEST, no dato de adaptación).
- ❌ Integrar pasajes al runtime antes del veredicto.

El experimento vive **fuera del runtime**: un runner nuevo que genera pasajes desde
el corpus y calcula métricas v3.1 + las nuevas métricas de pasaje.

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMAS QUERIES  → las 10 del EVAL
MISMO GOLD      → gold definitivo (Q04/Q06 corregidos)
MISMO LIMIT     → 10
MISMAS MÉTRICAS → search_recall / other / raw · context_relevance ·
                  cross_domain_leakage · token_cost · latency · determinismo
MISMO CORPUS    → mismo índice/alcance que A-F (raíz *.md/*.yaml + ai-context/ +
                  Knowledge/, excluyendo deprecated/)
```

Cambia la **unidad de contexto final**: de archivos completos a pasajes.

## 5. Arquitectura propuesta (pasaje como unidad de contexto)

### 5.1 Generación de candidatos (reusa las ramas medidas)

| Rama | Mecanismo | Parámetro |
|---|---|---|
| L — léxica | OR top-50 de `buffy-search.sh` + gate co-ocurrencia ≥2 tokens (and-norm del Paso 4) | N_L=50 |
| S — semántica | índice bge-m3 de D (coseno, cacheado) | N_S=50 |

El top-K final se genera con la **misma fusión V1-RRF (k=60)** que E — porque el
objetivo NO es volver a medir fusión sino aislar el efecto de la unidad de contexto.
(El runner acepta `--variant rrf|pool` por si se quiere sanity, pero el diseño fija
RRF como la variante principal: es la que igualó a D en recall con coste controlado.)

### 5.2 Pasaje (la variable del experimento)

Cada hit `path:lineno` del top-K se expande a un **pasaje** con DOS variantes de
granularidad (dos resultados experimentales independientes, mismo gate — igual que
E/F, sin escoger después):

| Variante | Pasaje | Racional |
|---|---|---|
| **G1-VENTANA** | líneas `[lineno-4, lineno+4]` (9 líneas), recortado a límites del archivo | granularidad fina; datos: Q04 gold cabe en ±4 (505 tok) |
| **G2-SECCIÓN** | bloque markdown delimitado por headings (`^#{1,3} `): desde el heading más cercano hacia arriba hasta el siguiente heading (o EOF) | unidad semántica natural; datos: Q04 sección = 1 266 tok, Q06 = 376 tok |

Nota G2: si el archivo no tiene headings, el pasaje = archivo completo (se reporta
como `section_fallback` — transparencia).

El ctx final = `router ∪ pasajes(top-K)` con **dedup por (path, rango de líneas)**.
El `token_cost` se estima sobre el **pasaje** (chars del pasaje / 4), NO sobre el
archivo completo. Este es EL cambio estructural del Paso 9.

> ⚠️ **Comparabilidad de métricas (declarada ANTES de medir):** el `token_cost` de
> A-F se midió con chars del ARCHIVO completo; el de G1/G2 se medirá con chars del
> PASAJE → los números de tokens NO son comparables con la serie A-F (serán mucho
> menores por construcción). El gate de tokens se lee como "el pasaje cabe en el
> presupuesto" (criterio nuevo, gold_containment), no como comparación directa con
> A. Para conservar la trazabilidad se reporta además una métrica secundaria
> `tokens_if_fullfile` (mismo estimador de A-F) — diagnóstico, no gate.
>
> De igual forma, el `search_recall` matchea el needle sobre el **texto del pasaje**
> (`snippet_scope: passage`), no sobre la línea individual como en E/F — puede subir
> por construcción (el needle puede vivir en otra línea del mismo pasaje). Se reporta
> `snippet_scope: passage` en el JSON para lectura honesta.

### 5.3 Firma del pasaje

Cada pasaje se anota con `path:start-end` para trazabilidad y para G-H0:

```text
ai-context/CHANGELOG.md:199-213
```

## 6. Presupuesto (fijado ANTES de medir)

| Parámetro | Valor V1 | Justificación |
|---|---|---|
| `N_L` | 50 | igual que E/F |
| `N_S` | 50 | igual que E/F |
| `PAS_VENTANA` | ±4 líneas (9 líneas) | datos: contiene el gold de Q04/Q06 |
| `token_budget` | **~2× A ≈ 10.4k** | mismo gate que E/F — la comparación de tokens debe ser contra A, no contra el archivo |
| LIMIT final | 10 | idéntico a A-F |

El presupuesto se aplica al ctx final (router ∪ pasajes) en orden del reranking;
el excedente se reporta como `ctx_cut` (transparencia). **La métrica crítica ya no
es "el gold cabe en presupuesto" sino "el pasaje del gold cabe"** — y con 310-505
tok por pasaje, cabe holgado.

## 7. Gate (estricto, pre-fijado ANTES de medir)

El usuario pidió un gate nuevo que mida específicamente: **recuperación del hecho ·
relevancia del pasaje · leakage · tokens · capacidad de contener el gold dentro del
presupuesto**.

| Criterio | Umbral | Definición operativa |
|---|---|---|
| search_recall | **> 0.100** | igual que A-F: solo gold_file_match (matching sobre pasaje) |
| passage_relevance | **≥ 0.600** | NUEVA: fracción de pasajes del ctx cuyo path ∈ gold_files — el criterio "relevancia del pasaje" que pidió el usuario |
| cross_domain_leakage | **≤ 0.267** | igualar a A — NO heredar OR/D/E/F (sobre pasajes) |
| token_cost | **≤ ~10.4k** | presupuesto sobre pasajes (no comparable con A-F, ver §5.2) |
| gold_containment | **≥ 0.80** | NUEVA: el pasaje del gold cabe completo en el presupuesto SIN truncar (Q04/Q06 deben pasar de 0.0 → 1.0) |

**gold_containment** (nueva métrica, sin circularidad): el denominador son TODAS
las agujas gold cuyo `candidate_status` es `in_pool_*` (top10 + ranked_out +
budget_cut, según el G-H0 re-derivado sobre pasajes); el numerador son las que su
pasaje cabría COMPLETO dentro del presupuesto del ctx — independiente del status
actual. Es decir: no se penaliza doble a una aguja cortada; se mide si el pasaje
que la contiene es entregable. Q04/Q06 en E/F tenían gold_containment 0.0 (el
archivo no cabía); con pasajes deben dar 1.0.

**passage_relevance** (nueva métrica): `|ctx_passages ∩ gold_files| / |ctx_passages|`
— análogo passage-level de `context_relevance` (que en A-F era file-level). Se
reporta además `context_relevance` (file-level, v3.1) como diagnóstico secundario.

> **Condición adicional (transcrita del Paso 8, se mantiene):** los CINCO criterios
> a la vez. No se acepta passage-retrieval solo por recall > D; debe demostrar que
> entrega el gold dentro del presupuesto con calidad de contexto de nivel A.

## 8. Pre-gate de candidate availability (G-H0) — adaptado a pasajes

G-H0 del Paso 8 se conserva con un ajuste: el status por aguja se decide sobre el
**pasaje**, no sobre la línea del pool:

```text
aguja ∈ pasaje de algún hit del pool  →  "in_pool_*" (según top-10 / budget / ranked)
aguja ∈ corpus pero en ningún pasaje  →  "out_of_pool"  (candidate gap → Paso 10)
aguja ∉ corpus                        →  "not_in_corpus"  (no ocurre — fixture auditado)
```

Los statuses se **re-derivan sobre pasajes** (no sobre líneas del pool): una aguja
que en E/F era `in_pool_budget_cut` (por el archivo de 14.4k tok) debe pasar a
`in_pool_top10`/`in_pool_ranked_out` si su pasaje de ~500 tok entra al ctx — ese es
el efecto esperado del Paso 9 y lo que `gold_containment` cuantifica. Se agrega por
query el desglose `gold_containment` por aguja (cuántos tokens ocuparía el pasaje
que la contiene y si cabe en el presupuesto).

## 9. Criterio de lectura (reportar, no bloquear)

```text
recall > 0.100 + passage_relevance ≥ 0.600 + leakage ≤ 0.267
+ tokens ≤ 10.4k + gold_containment ≥ 0.80  →  señal fuerte para passage-level
```

- **Q04/Q06 pasan de cRel=0.0 a cRel>0** con gold_containment 1.0 → el problema era
  la unidad de contexto, resuelto.
- **Q08**: si `picom` sigue `other_file_match`/`ranked_out`, el pasaje no arregla la
  selección → hallazgo de rerank (Paso 10b candidato).
- **Q03** sigue `out_of_pool` → candidate gap confirmado → alimenta el diseño del
  Paso 10 (query expansion).
- Si G1 vs G2 difieren, se leen como dos curvas independientes (nunca se escoge
  después de ver el resultado).

## 10. NO adoptar todavía

El experimento es **diagnóstico + decisión**. El veredicto de adopción (y cualquier
cambio al runtime) es decisión del usuario, con la evidencia sobre la mesa.

## 11. Pasos de implementación (tras aprobación del diseño)

1. `scripts/tests/evals/run-passage-PC.sh` — runner nuevo:
   - ramas L/S idénticas a E/F (reusa el índice bge-m3 cacheado)
   - fusión V1-RRF (k=60) → top-10 de hits `path:lineno`
   - expansión a pasajes: G1-VENTANA (±4) y G2-SECCIÓN (headings)
   - ctx = router ∪ pasajes (dedup por path:rango) con presupuesto 10.4k
   - métricas v3.1 + `gold_containment` + G-H0 adaptado
2. Verificar fixture (hash) + determinismo (2 corridas por variante).
3. Correr **G1 y G2** sobre el MISMO EVAL → comparar A/B/C/D/E/F/G1/G2.
4. Reportar: agregado + por query con `candidate_status` (foco Q03/Q04/Q06/Q08) +
   gold_containment → decisión del usuario.

## 12. Riesgos / consideraciones

- **Riesgo 1 — pasaje demasiado corto:** ±4 líneas puede separar el hecho de su
  contexto; se mitiga con G2-SECCIÓN como segunda lectura (ambas se reportan).
- **Riesgo 2 — G2 en CHANGELOG.md:** las secciones `### fecha` son de 200-1 266 tok;
  el gold cabe pero el pasaje puede incluir ruido de esa entrada del changelog.
- **Riesgo 3 — dedup por rango:** dos hits cercanos del mismo archivo generan
  pasajes solapados → dedup por (path, rango) y, si solapan, unión del rango mínimo
  que los cubre (se define en implementación, sin calibrar).
- **Riesgo 4 — leakage con pasajes:** los pasajes de archivos no-gold siguen
  entrando al ctx; el presupuesto y el rerank controlan, igual que en E/F.
- **Determinismo:** ambas ramas + fusión + pasajes son deterministas → G2 reproducible.

## 13. Fuera de alcance (explícito)

- Query expansion / traducción de la query / términos alternativos → **Paso 10**
  (candidato: atacar Q03/Q08 con `crear→create`, `opaca→picom/compositor/opacity`).
- Reranking por LLM / pasaje completo → siguiente experimento.
- Cambiar el corpus, fixture, gold o métricas (anti-gaming).
- Calibración de N_L/N_S/k/pasaje/budget con el EVAL.
- Integrar passage retrieval al runtime antes del veredicto.

---

## Anexo A — Resultados medidos (2026-08-12, EVAL 98a0e308…, instrumento v3.1)

Corridas reales con el índice bge-m3 de D (cache hit), ramas L/S reales y fusión
V1-RRF. Determinismo G2: hash idéntico en 2 corridas por variante (G1 `b7d17efd…`,
G2 `528fe12a…`). `snippet_scope: passage`.

| Estrategia | Recall | pRel | cRel(file) | Leakage | Tokens avg | gold_containment |
|---|---:|---:|---:|---:|---:|---:|
| A — AND | 0.000 | — | 0.533 | 0.267 | 5 197 | — |
| C — AND-norm | 0.100 | — | 0.333 | 0.522 | 38 017 | — |
| D — Semantic | 0.200 | — | 0.192 | 0.669 | 47 980 | — |
| E — Hybrid-RRF | 0.200 | — | 0.185 | 0.605 | 9 951 | 0.0 (Q04/Q06) |
| F — Hybrid-POOL | 0.200 | — | 0.179 | 0.612 | 10 039 | 0.0 (Q04/Q06) |
| G1 — VENTANA | **0.417** | 0.072 | 0.214 | 0.606 | 2 569 | **0.8** |
| G2 — SECCIÓN | 0.333 | 0.054 | 0.214 | 0.606 | 3 373 | 0.7 |

### Gate (5 criterios simultáneos) — G1 y G2 NO pasan

| Criterio | Umbral | G1 | G2 |
|---|---|---:|---:|
| search_recall | > 0.100 | 0.417 ✅ (mejor serie) | 0.333 ✅ |
| passage_relevance | ≥ 0.600 | 0.072 ❌ | 0.054 ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.606 ❌ | 0.606 ❌ |
| token_cost | ≤ ~10.4k | 2 569 ✅ | 3 373 ✅ |
| gold_containment | ≥ 0.80 | 0.8 ✅ | 0.7 ❌ |

### Hallazgos clave

1. **La unidad de contexto SÍ era parte del problema**: Q04/Q06 pasan de
   gold_containment 0.0 (E/F: archivo de 14.4k no cabía) a 1.0 (pasaje de 310-505
   tok cabe y se entrega con sRec=1.0). Truncamiento estructural RESUELTO.
2. **Recall 0.417 (G1) — el mejor de la serie**: matching sobre pasaje captura
   agujas que la línea perdía (Q02 0.667, Q05/Q07/Q09 0.5).
3. **passage_relevance 0.072/0.054 / leakage 0.606 no mejoran**: los pasajes no-gold
   del top-10 (SESION-archive, CONTINUE…) dominan el ctx. El pasaje arregla el
   TAMAÑO, no la SELECCIÓN.
4. **Q08**: `picom` entra al pool y al top-10, pero el gold file (System.md) queda
   fuera → pasajes entregados no-gold. Problema de rerank/selección.
5. **G1 > G2** en recall (0.417 vs 0.333) y gold_containment (0.8 vs 0.7): la
   ventana ±4 es más precisa; la sección infla pasajes con ruido interno.

### Conclusión

El pasaje es **NECESARIO pero NO SUFICIENTE**: elimina el truncamiento y mejora el
recall, pero no la calidad del ctx. El límite se movió de "cómo entrego el gold" a
"**qué pasajes selecciono**". Evidencia para el Paso 10: query expansion (candidate
gap Q03/Q01/Q10) + selección/rerank de pasajes (Q08). Runtime sigue congelado.

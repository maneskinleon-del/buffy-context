# Paso 8 — Hybrid bounded candidate retrieval (diseño)

> Estado: **DISEÑO** (2026-08-12) — pendiente de aprobación del usuario. NO implementar
> hasta fijar candidatos, presupuesto, fórmula de fusión/reranking y gates.
> Base: EVAL con gold definitivo (hash `98a0e308…`), baselines A/B/C/D medidos.
> Autorizado por el usuario (2026-08-12): "Paso 7 cerrado → D descartado → runtime
> congelado → siguiente paso: diseñar el experimento Hybrid bounded, sin implementarlo".

## 1. Objetivo e hipótesis

**Pregunta:** ¿una fusión **acotada** de candidatos (léxico + semántico) recupera la
capacidad semántica que D demostró (Q06) **sin heredar** el comportamiento de OR/D
(leakage alto, relevancia baja, coste alto)?

**Hipótesis central (derivada de A/B/C/D):**

> candidate generation ≠ final retrieval. El léxico es bueno en precisión/coste/
> terminología exacta; el semántico es bueno en recuperar evidencia sin vocabulario
> compartido. Cada mecanismo debe generar candidatos donde es bueno, y una capa de
> fusión/reranking con presupuesto debe producir el top-K final sin arrastrar el
> ruido de ninguna de las dos ramas.

**Hipótesis secundaria (candidate gap de Q03/Q08):**

> la fusión de candidatos por sí sola NO resuelve Q03/Q08: sus agujas gold ni
> siquiera entran al pool (Q03 rank 200/254, Q08 rank 266/2553 semántico; sin
> overlap léxico). Si G-H0 (pre-gate de availability) se incorpora al diseño,
> el experimento podrá atribuir correctamente: "la fusión mejora lo recuperable"
> vs "el candidato nunca existió" (caso de Q03/Q08).

## 2. Evidencia acumulada (gold definitivo, v3.1)

| Estrategia | Recall | Relevance | Leakage | Tokens avg | Latencia |
|---|---:|---:|---:|---:|---:|
| A — AND (lexical) | 0.000 | **0.533** | **0.267** | **5 197** | 900 ms |
| B — OR | 0.050 | 0.182 | 0.694 | 45 259 | 525 ms |
| C — AND-norm | 0.100 | 0.333 | 0.522 | 38 017 | 538 ms |
| D — Semantic (bge-m3) | **0.200** | 0.192 | 0.669 | 47 980 | 1 449 ms |

Queries resueltas por cada variante (solo gold_file_match):

| Query | A | B | C | D | pool ≤50 sem? |
|---|---|---:|---:|---:|---:|
| Q01 (scrcpy no aparece) | — | — | — | — | ? |
| Q02 (shizuku permisos) | — | — | — | — | ? |
| Q03 (push + crear PR) | — | — | — | — | ❌ (rank 200/254) |
| Q04 (pantalla se apaga) | — | — | ✅ | ✅ | ? |
| Q05 (React + adb serial) | — | — | — | — | ? |
| Q06 (script scrcpy FF_SEEN) | — | — | — | ✅ | ? |
| Q07 (celular lento) | — | — | — | — | ? |
| Q08 (terminal opaca→picom) | — | — | — | — | ❌ (rank 266/2553) |
| Q09 (optimizar rendimiento) | — | — | — | — | ? |
| Q10 (ZTE caliente free fire) | — | — | — | — | ? |

## 3. Alcance (qué NO se toca)

- ❌ `buffy-search.sh`, `buffy-router.sh`, cap-selector, defaults → **runtime congelado**.
- ❌ Hybrid / fusión / embeddings en producción.
- ❌ Calibración de pesos ni umbrales con el EVAL (referencia de TEST, no dato de adaptación).
- ❌ `nomic-embed-text` (sanity) salvo que bge-m3 falle de forma reproducible.

El experimento vive **fuera del runtime**: un runner nuevo que orquesta las dos ramas
(lexical real de `buffy-search.sh` + índice semántico real de D) y calcula las MISMAS
métricas v3.1.

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMAS QUERIES  → las 10 del EVAL
MISMO GOLD      → gold definitivo (Q04/Q06 corregidos)
MISMO LIMIT     → 10
MISMAS MÉTRICAS → search_recall / other / raw · context_relevance ·
                  cross_domain_leakage · token_cost · latency · determinismo
MISMO ÍNDICE    → reutiliza el cache semántico de D (bge-m3, 6 880 líneas, dim 1024);
                  la invariante exige el corpus sin cambios (el cache se invalida por
                  hash del corpus → rebuild de ~38 min si se edita un .md)
```

Cambia la capa de retrieval de UNA rama a dos ramas + fusión.

## 5. Arquitectura propuesta (candidate generation ≠ final retrieval)

```
                    QUERY
                      │
             ┌────────┴────────┐
             ↓                 ↓
        lexical search    semantic search
        (buffy-search.sh) (bge-m3 coseno)
             │                 │
      candidatos L         candidatos S
        (top-N_L)           (top-N_S)
             │                 │
             └────────┬────────┘
                      ↓
              candidate pool (dedup)
              (límites fijos §6)
                      ↓
               reranking/fusión (§7)
                      ↓
                top-10 final
```

### 5.1 Ramas generadoras

| Rama | Mecanismo real | Parámetro | Default V1 |
|---|---|---|---|
| L — léxica | **mismo mecanismo que and-norm del runner** (no es estrategia de `buffy-search.sh`): OR top-50 de `buffy-search.sh` (`BUFFY_SEARCH_STRATEGY=or`) + gate de co-ocurrencia ≥2 tokens en la línea (como `run_search_and_norm()` de `run-baseline-PC.sh`) | `N_L` | 50 |
| S — semántica | índice bge-m3 de D (coseno, cacheado) | `N_S` | 50 |

- **¿Por qué and-norm y no and/or?** and recupera 0 (no genera candidatos); or
  genera el ruido que la fusión debería evitar. and-norm es el punto medio medido
  (recall 0.100, leakage 0.522) y su `top-50` ya existió en el Paso 4.
  ⚠️ Nota de implementación: `buffy-search.sh` solo soporta `and`/`or`; el gate de
  co-ocurrencia se aplica en el runner (patrón ya usado en `run-baseline-PC.sh`).
- **Candidatos L** = líneas `path:lineno` que pasan el gate de co-ocurrencia (sin
  truncar, respetando N_L). **Candidatos S** = top-N_S por coseno del índice de D.

### 5.2 Pool

```text
pool = dedup( L ∪ S )   por (path, lineno)   — sin duplicados
```

- Dedup preserva el orden de llegada (L primero, S después) solo como tiebreak de
  estabilidad, NO como peso.
- El pool queda sujeto al **presupuesto de contexto** (§6): los candidatos entran
  al contexto final (para `context_relevance`/`leakage`/`token_cost`) SOLO hasta
  agotar el presupuesto, en orden del reranking (§7).

### 5.3 Reranking/fusión (V1 — sin calibrar)

Se prueban dos fórmulas declarativas (mismo gate, lectura separada por variante):

| Variante | Fórmula | Racional |
|---|---|---|
| **V1-RRF** | Reciprocal Rank Fusion: `score(x) = Σ_ramas 1/(k + rank_rama(x))`, `k=60` | estándar, sin pesos calibrables, determinista |
| **V1-POOL** | `score(x) = rank_L(x)⁻¹ + rank_S(x)⁻¹` (solo ramas donde x aparece; si no aparece en una rama, contribución 0) | variante de control sin constante k |

Tiebreak determinista: `(-score, path, lineno)`.

> **Sin calibración:** los parámetros (N_L, N_S, k) son V1 declarativos. NO se
> ajustan con el EVAL. Si una variante es prometedora, el ajuste de parámetros se
> haría en un set dev externo — fuera del alcance de este Paso 8.

## 6. Presupuesto (fijado ANTES de medir)

| Parámetro | Valor V1 | Justificación |
|---|---|---|
| `N_L` (candidatos léxicos) | 50 | mismo top-50 que usó and-norm en el Paso 4 |
| `N_S` (candidatos semánticos) | 50 | rango en el que D recupera Q04/Q06; fuera de 50 no hay aguja gold (G-H0) |
| **token_budget** | **~2× A ≈ 10.4k** | gate del usuario: coste ≤ ~2× AND |
| LIMIT final | 10 | idéntico a A/B/C/D |

El presupuesto se aplica al **contexto final** (`ctx = router ∪ pool`, mismo
estimador chars/4 de todos los pasos): se ordena el pool por el reranking (§5.3)
y se corta cuando el acumulado supera el presupuesto; el resto se reporta como
`pool_cut` en el JSON (transparencia, no silencio).

## 7. Gate (estricto, pre-fijado ANTES de medir)

| Criterio | Umbral | Justificación |
|---|---|---|
| search_recall | **> 0.100** | superar a C (and-norm); el usuario NO fijó 0.200 — lo que pidió fue "no aceptar solo por recall > D", es decir, que los 4 criterios se cumplan simultáneamente |
| context_relevance | **≥ 0.600** | igualar a A (el más limpio) — la condición clave del usuario |
| cross_domain_leakage | **≤ 0.267** | igualar a A — NO heredar el comportamiento de OR/D |
| token_cost | **≤ ~2× A (≈10.4k)** | presupuesto acotado |
| determinismo | 2 corridas idénticas (salvo latencia) | G2 del runner |
| EVAL hash | `98a0e308…` | mismo fixture |

> **Condición adicional del usuario (crítica, transcrita):** *"No aceptaría un Hybrid
> solamente porque recall > D. Tiene que demostrar que recupera parte de la capacidad
> semántica sin heredar el comportamiento de OR/D."* Operativamente: los CUATRO
> criterios de la tabla a la vez (recall > 0.100 Y relevance ≥ 0.600 Y leakage ≤ 0.267
> Y tokens ≤ 10.4k). El recall es el umbral del usuario (> 0.100); NO se endurece a
> 0.200 — eso sería relajar/endurecer el gate tras ver los resultados, prohibido.

## 8. Pre-gate de candidate availability (G-H0) — nuevo instrumento

**Problema que resuelve:** sin G-H0, un mal recall de la fusión podría atribuirse a
"la fusión falla" cuando en realidad el candidato nunca estuvo en el pool.

**Definición:** por cada query y cada aguja gold `f` (pool = la unión dedup de §5.2,
**anterior al recorte por presupuesto** — el ctx post-corte es otro concepto, §6):

```text
f ∈ pool  →  "in_pool"
    ├─ ¿quedó en el top-10 final?  →  (lo refleja search_recall)
    └─ ¿estaba en el pool pero NO en el top-10?
        ├─ cortado por token_budget (entró al ctx hasta agotar presupuesto pero no
        │  alcanzó el top-10)  →  "in_pool_budget_cut"
        └─ rankeado fuera por la fusión  →  "in_pool_ranked_out"
f ∉ pool pero existe en el corpus  →  "out_of_pool"  (candidate gap)
f no existe en el corpus  →  "not_in_corpus"  (gold roto, no ocurre — fixture auditado)
```

**Atribución (reporte, no bloquea):**

- `search_recall = 0` con todas las agujas `out_of_pool` → NO es fallo de la fusión:
  es candidate gap (caso Q03/Q08) y se reporta como tal.
- `search_recall = 0` con agujas `in_pool_budget_cut` → el candidato existía pero el
  presupuesto lo cortó → hallazgo de presupuesto, no de rerank.
- `search_recall = 0` con agujas `in_pool_ranked_out` → la fusión/rerank falló en su
  función real → hallazgo de diseño.

G-H0 es un **atributo diagnóstico** computado en la misma corrida (no una compuerta
que detenga la ejecución). Cada query se anota con su `candidate_status` por aguja.

## 9. Criterio de lectura (reportar, no bloquear)

```text
benchmark↑ + EVAL↑  → fuerte → considerar Hybrid con base empírica
benchmark↑ + EVAL↓  → DESCARTAR
EVAL↑ + benchmark↓  → investigar
```

Con G-H0 añadido:

- Fusión pasa los 4 gates de §7 (recall > 0.100 + relevance ≥ 0.600 + leakage
  ≤ 0.267 + tokens ≤ 10.4k) → **señal fuerte para Hybrid**.
- Fusión sube recall pero cae en leakage/relevance/tokens → **mismo fracaso que
  D/OR** → la fusión naive NO es suficiente → conclusión: investigar **query
  expansion / reranking específico** (el siguiente nivel, fuera de este paso).
- Recall bajo con agujas `out_of_pool` → el límite es el **candidate generation**, no
  la fusión → documenta que Q03/Q08 requieren otra representación.

## 10. NO adoptar todavía

El experimento es **diagnóstico + decisión**. El veredicto de adopción (y cualquier
cambio al runtime) es decisión del usuario, con la evidencia sobre la mesa.

## 11. Pasos de implementación (tras aprobación del diseño)

1. `scripts/tests/evals/run-hybrid-PC.sh` — runner nuevo:
   - rama L: OR top-50 de `buffy-search.sh` (`BUFFY_SEARCH_STRATEGY=or`) + gate de
     co-ocurrencia ≥2 tokens en el runner (mismo mecanismo and-norm del Paso 4,
     no es estrategia de buffy-search.sh)
   - rama S: índice semántico cacheado de D (reutiliza `~/.cache/buffy-eval-semantic/`)
   - pool dedup → rerank (V1-RRF y V1-POOL) → presupuesto → top-10 → métricas v3.1
   - G-H0 por query (`candidate_status` por aguja: in_pool / out_of_pool /
     in_pool_budget_cut / in_pool_ranked_out / not_in_corpus)
2. Verificar fixture (hash) + determinismo (2 corridas).
3. Correr **H (hybrid)** sobre el MISMO EVAL → comparar A/B/C/D/H (tabla + por query).
4. Reportar: agregado + por query con `candidate_status` (foco Q03/Q06/Q08) +
   G-H0 → decisión del usuario.

## 12. Riesgos / consideraciones

- **Riesgo 1 — la fusión hereda el ruido de S:** el top-50 semántico trae archivos
  no-gold (leakage de D fue 0.669). El presupuesto y el rerank son los que deben
  controlarlo; si no lo logran, el resultado documentará el límite.
- **Riesgo 2 — and-norm top-50 no basta para L:** and-norm recupera Q04 gold;
  puede no generar candidatos útiles para otras queries. Se reporta `pool` por
  query (tamaños L/S) para auditar.
- **Riesgo 3 — token_budget corta demasiado:** el pool de ~100 candidatos puede
  exceder 10.4k tokens al sumar tamaños de archivo; el corte en orden de rerank
  puede dejar fuera agujas `in_pool` que el recall necesita (se detecta como
  `in_pool_budget_cut` en G-H0). Se reporta `pool_cut` por query y se lee como
  curva, no como error.
- **Determinismo:** ambas ramas son deterministas (FTS5 bm25 fijo + embeddings
  bge-m3 fijos + tiebreak por path/lineno) → G2 reproducible.
- **Cache del índice:** si el corpus cambia tras la corrida de D (cualquier `.md`
  editado), el cache se invalida y se reconstruye (~38 min, determinista). Correr H
  sobre el MISMO corpus que D (estado actual del repo).
- **Coste de runtime:** el índice semántico ya está cacheado; la corrida añade ~10
  embeddings de query (~1.4 s c/u) → ~15-20 s totales por corrida.

## 13. Fuera de alcance (explícito)

- Query expansion / traducción de la query / términos alternativos → **candidato
  para el siguiente experimento** si G-H0 confirma el candidate gap de Q03/Q08.
- Reranking por LLM/passage-level → siguiente experimento.
- Cambiar el corpus, fixture, gold o métricas (anti-gaming).
- Calibración de N_L/N_S/k/budget con el EVAL.
- Integrar Hybrid al runtime antes del veredicto.

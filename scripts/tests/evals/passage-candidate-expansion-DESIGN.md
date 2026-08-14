# Paso 13 — Passage Candidate Expansion (diseño)

> Estado: **✅ EJECUTADO — CERRADO sin adopción** (2026-08-13). Serie F1×2 / F2×2
> completa en worktree aislado `18df679` (determinismo G2 ✅). **F1/F2 no pasan el
> gate → no se adoptan.** Resultados y veredicto en el **Anexo A**. Siguiente
> decisión: el cuello de botella ya no es cobertura de pasajes sino el salto
> disponibilidad → atribución (Q04).
> Base: serie E1/E2/E3 completa (**Paso 12 CERRADO sin adopción** — anexo A de
> `evidence-passage-DESIGN.md`). Congelados (heredados): EVAL `98a0e308…`, pool
> del Paso 10 (dict H2 `b0406a33…`), orden R1-LEX (`8316343e…`), presupuesto
> 10.4k tokens, scorer de contenido E2 (bge-m3 θ=0.55) y su cache de pasajes,
> runtime.
> Dirección del usuario (2026-08-13): el problema ya no parece ser retrieval,
> expansión, ranking ni la calidad intrínseca del embedding — es la **cobertura
> de evidencia en la transición archivo → pasajes**.

---

## 1. Pregunta experimental

> ¿El problema de pRel/leakage puede resolverse si aumentamos la **cobertura de
> pasajes relevantes** ANTES de aplicar el selector de contenido (E2)?

El Paso 12 dejó medido el cuello de botella: **solo 6/20 agujas gold viven en la
capa de pasajes del contexto R1** (las otras 14 están en el pool → contexto por
archivos completos del router, o fuera). found 20/20 · selected 14/20 ·
attributed 14/20 · **pasaje 6/20**. Un selector de pasajes perfecto no puede
elegir evidencia que nunca llegó a esa capa. El Paso 13 ataca ese salto
archivo→pasaje, manteniendo congelado TODO lo demás (incluido el scorer E2, sin
recalibrar θ).

## 2. Pipeline (la variable en su lugar)

```text
H2 (pool congelado L ∪ X ∪ S)
        │
   orden R1 congelado (r1-LEX)
        │
┌─────────────────────────────┐
│ PASSAGE CANDIDATE EXPANSION │  ← LA ÚNICA VARIABLE (Paso 13)
│  si un archivo aparece en   │
│  router_knowledge o en el   │
│  top del pool → generar sus │
│  pasajes candidatos (rama P)│
└─────────────────────────────┘
        │
   E2 content scorer (congelado, θ=0.55)
        │
   pasajes VENTANA ±4 → presupuesto 10.4k → ctx
```

- **Congelado y verificado:** pool H2, orden R1, scorer E2 (θ=0.55, pesos 1.0,
  sin sem, sin calibración), presupuesto, métricas v3.1 + Paso 12, EVAL/gold.
- **Nueva capa (rama P):** pasajes candidatos generados por **archivo**, no por
  línea. Para cada archivo relevante (ver variantes), generar sus pasajes en
  ventanas ±4 (mismo `PAS_PAD` que G1), etiquetados con rama `P` en el pool.
  Luego el scorer E2 puntúa el pool **expandido** (L∪X∪S∪P) y la selección +
  presupuesto + contexto final corren igual que en E2.

## 3. Variantes (una variable a la vez, ablación)

| Variante | Expansión | Señal de archivo | Sin gold |
|---|---|---|---|
| **F1-P** (default) | archivos de `router_knowledge` (kno) | el router ya los marcó | ✅ |
| **F2-P** | kno + top-K del pool R1 (K fijo a priori) | ranking R1 | ✅ |
| F3-P (solo si los datos lo piden) | pasajes por **sección markdown** en vez de ventana ±4 | — | ✅ |

- F1 es el caso más limpio: el router ya decidió qué archivos importan → se les
  da la oportunidad de aportar sus pasajes como evidencia en la capa correcta.
- F2 amplía a archivos que el ranking consideró candidatos pero cuyas líneas no
  llegaron al pool; K se fija ANTES de medir (sugerido K=10, el mismo LIMIT).
- F3 cambia la unidad de pasaje (sección vs ventana); solo si F1/F2 muestran que
  el problema es la **forma** del pasaje y no la cobertura.
- **Regla de la serie:** `gold_files` NO se usa como señal de expansión en
  ninguna variante (el runner nunca lee el gold para decidir qué expandir).

## 4. Métricas (v3.1 + Paso 12, por query y agregado)

- Tres conceptos por gold-fact: `evidence_found` / `evidence_selected` /
  `evidence_attributed` (+ `passage` = aguja en pasaje del ctx).
- `passage_relevance` (pRel, solo pasajes) · `context_relevance` · `leakage`.
- `agujas_preservadas` (vs R1, por-gold-fact) · `gap_to_top10` ·
  `baseline_regression` (vs R1 top10) · `tokens_evidencia_absolutos`.
- Coste: tokens, latencia, y **hit/miss del cache de pasajes** (la rama P
  aumenta el nº de embeddings — el cache del Paso 12 lo amortigua).

## 5. Gate (pre-fijado, idéntico al Paso 12 — sin relajación tras ver resultados)

```text
search_recall        > 0.100      (selección pasajes, instrumento v3.1)
passage_relevance   ≥ 0.600      (capa de pasajes)
leakage             ≤ 0.267      (cross-domain)
tokens              ≤ 10.4k      (presupuesto)
gold_containment    ≥ 0.80
baseline_regression ≤ 0.167      (vs R1 top10)
```

+ diagnósticos: tres conceptos, agujas_preservadas, gap_to_top10. Si F1 pasa →
NO se adopta automáticamente: se diseña el siguiente paso con la evidencia
(regla invariante de la serie).

## 6. Riesgos / confounds (declarados antes de medir)

1. **Leakage por expansión:** expandir archivos no-gold puede sumar ruido a la
   capa de pasajes. Se mide `leakage` por variante y por query (Q08/Q10 en
   foco: archivos de sesión/contexto son candidatos frecuentes de kno).
2. **Cobertura por construcción:** F1 garantiza cobertura de los archivos del
   router; si el router falló el archivo gold (Q03/Q08 históricamente), F1 no
   puede rescatarlo → F2 (top-pool) lo cubre parcialmente. Se reporta
   `found/selected` por query para atribuir el resultado a cobertura vs scorer.
3. **Más embeddings ≠ más evidencia:** el scorer E2 es el mismo; si la
   cobertura sube pero pRel no, la frontera vuelve al scorer (contraste futuro:
   recalibrar θ SOLO tras cerrar cobertura).
4. **Composición del pool:** la rama P cambia el pool respecto a H2 → `dict_hash`
   se reporta pero el pool ya no es idéntico a H2/R1 (es la variable declarada).
   `pool_reference`/`ranking_reference` se auto-reportan como en los pasos previos.

## 7. Qué NO se hace (regla acumulada de la serie)

- NO tocar runtime (`buffy-search.sh`, `buffy-router.sh`).
- NO usar `gold_files` como señal de expansión ni de puntuación.
- NO recalibrar θ ni pesos del scorer (E2 congelado; sin búsqueda post-hoc).
- NO medir sobre el working tree compartido si el corpus se desvió → worktree
  aislado en `18df679` (patrón FWD).
- NO adoptar automáticamente si el gate pasa.
- NO mezclar variables: F1 antes de F2, F2 antes de F3.

## 8. Orden de ejecución (tras aprobación)

```text
0. PRE-FLIGHT FWD: corpus no desviado vs referencia R1 → si desviado, worktree 18df679
1. implementar en run-evidence-PC.sh: rama P + flag --expand f1|f2 (reutiliza E2,
   cache de pasajes, presupuesto y métricas — sin tocar el esquema JSON)
2. validar sintaxis + smoke (F1 sobre 1-2 queries, con y sin cache de pasajes)  ✅
3. F1 ×2 corridas → determinismo G2  ✅ (23bc7460c9d07211)
4. comparar F1 vs E2/R1 (per-query: tres conceptos, gap, leakage)  ✅
5. F2 ×2 corridas  ✅ (7fc28c377482e2c5)
6. registrar en EVAL-REGISTRY.md + spec a EJECUTADO con Anexo  ✅ (Anexo A)
7. revisar con code-reviewer
8. commit + push (git commit -- paths) + detener(se) (runtime intacto)
```

---

## Anexo A — Resultados y veredicto (2026-08-13)

### A.1 Ejecución

Serie F1×2 / F2×2 en el worktree aislado `18df679`, reutilizando el scorer E2
(θ=0.55), el pool H2, el orden R1-LEX y el cache de pasajes validado (Paso 12).
Gates: **G1 ✅** (EVAL `98a0e308…`) · **G2 ✅** determinismo (F1 `23bc7460c9d07211`
· F2 `7fc28c377482e2c5`). Tiempos: F1 ≈ 20 min (≈173 ventanas P nuevas) · F2 r0
≈ 17 min · F2 r1 (warm) ≈ 1 min. Artefactos:
`baseline-F1/F2-expansion-PC-2026-08-13.json` (+`-r2`).

> **Precondición aplicada (lección FWD):** el refactor se validó con E2 + `--expand
> none` bit-idéntico al congelado (`4ab293dacef1c914`). La primera re-verificación
> falló por **drift de corpus FTS5**: `buffy-search.sh` indexa el repo real
> (`$HOME/buffy-context`) y el cierre de sesión había editado `ai-context/CONTINUE.md`
> y `SESION.md` (ambos en el corpus). Restaurados + reindex → E2-none bit-idéntico
> de nuevo. **No tocar archivos del corpus mientras se mide.**

### A.2 Resultados agregados (v3.1, gold definitivo, 10 queries)

| Variante | sRec | pRel | leak | tokAvg | gap→top10 | regresión | available | attributed |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| R1 (ref) | 0.750 | 0.175 | 0.441 | 1903 | 0.667 | 0.167 | — | 14 |
| E2 (ref) | 0.700 | 0.093 | 0.325 | 1789 | 0.833 | 0.0 | 6* | 16 |
| **F1** (router) | 0.700 | 0.093 | **0.275** | 1749 | 0.833 | 0.0 | **14** | 16 |
| **F2** (router+pool K=10) | 0.700 | **0.121** | 0.308 | 1740 | 0.833 | 0.0 | **18** | 16 |

*6 = agujas en la capa de pasajes del contexto R1 (medido en el Paso 12); `available`
= agujas presentes en pasajes rama-P del pool expandido.

### A.3 Gate (pre-fijado, sin relajación)

| Criterio | Umbral | F1 | F2 | ¿Pasa? |
|---|---|---:|---:|---|
| search_recall | > 0.100 | 0.700 | 0.700 | ✅ |
| passage_relevance | ≥ 0.600 | 0.093 | 0.121 | ❌ |
| leakage | ≤ 0.267 | 0.275 | 0.308 | ❌ (F1 muy cerca) |
| tokens | ≤ 10.4k | 1749 | 1740 | ✅ |
| gold_containment | ≥ 0.80 | 1.0 | 1.0 | ✅ |
| baseline_regression | ≤ 0.167 | 0.0 | 0.0 | ✅ |

→ **Ninguna variante pasa el gate** (pRel y leakage). Se cierra **sin adopción**.

### A.4 Veredicto — el experimento respondió su pregunta

1. **F1 (archivos del router) mejora el leakage sin tocar pRel** (0.325 → 0.275):
   el gate ahora selecciona pasajes del archivo correcto — **Q03 leak 0.5 → 0.0**
   (Commands.md, gold, antes quedaba ruido). Los archivos que el router ya marcó
   son la fuente de pasajes correcta; expandirlos limpia el contexto.
2. **F2 (F1 + top-10 del pool) añade cobertura y pRel pero devuelve leakage**
   (0.275 → 0.308): `available` 14 → 18 (Q08: picom/P_TERM_OPACITY aparecen por
   fin como pasajes de System.md; Q06: FF_SEEN available=1) y pRel 0.093 → 0.121,
   PERO Q09 empeora leak 0.0 → 0.33 y **la atribución no mejora (16/20)** — la
   disponibilidad extra no se convierte en pasaje gold atribuido en el ctx.
   → Ampliar el universo de archivos (K=10) **no es la solución**.
3. **Q04 sigue roto por construcción**: su gold (CHANGELOG.md) no está en kno NI
   en el top-K del pool → `available=0` en F1 y F2. Ninguna variante de expansión
   puede rescatar evidencia que ningún componente identifica.
4. **El cuello de botella se desplaza:** ya no es la cobertura archivo→pasaje
   (F2 la resuelve en 18/20) sino **disponibilidad → atribución** (18 available,
   16 attributed): el pasaje con la aguja existe en el pool pero no llega al ctx
   final como pasaje gold (presupuesto/gate/ranking intermedios).

### A.5 Nota de infraestructura

- `--expand none|f1|f2` en `run-evidence-PC.sh`; `none` es bit-idéntico al
  congelado (validado). Rama P: ventanas no-solapadas de 2·PAS_PAD+1 líneas,
  etiquetadas `{'P'}`; F2 toma top-K=10 archivos del pool por orden R1 fuera de
  kno. `gold_files` nunca es señal de expansión (verificado: los gold de Q04/Q06
  NO entran por construcción). Diagnósticos nuevos por query: `p_expand_files`,
  `p_pool_passages`, `passage_available` (funnel found → available → selected →
  attributed) + `pool_stats.P`. Esquema JSON sin cambios para `--expand none`.

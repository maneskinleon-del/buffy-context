# Paso 7 — Experimento semántico diagnóstico (retrieval aislado)

> Estado: **EJECUTADO** (2026-08-12) — D (bge-m3) medido sobre el EVAL, 2 corridas con
> determinismo G2 ✅. Resultados registrados en EVAL-REGISTRY.md → Paso 7.
> **Veredicto del gate: D NO pasa (recall 0.200 ✅, relevance 0.192 ❌, leakage 0.669 ❌,
> tokens 47.9k ❌).** No se adopta nada. Base: EVAL con gold definitivo (hash
> `98a0e308…`), baselines A/B/C regenerados (v3.1).
> Runner: `run-semantic-PC.sh` (implementado y validado con mock + corrida real).

## 1. Objetivo

Responder UNA pregunta concreta:

> **¿Un retrieval semántico puede recuperar Q03/Q06/Q08 sin reproducir el nivel de
> leakage y coste de OR?**

No se construye la arquitectura definitiva (Hybrid) todavía. Es un experimento
**diagnóstico** que aísla la variable `lexical → semantic` en la capa Search.

## 2. Contexto — el gap de retrieval restante (gold definitivo)

| Query | Problema | Evidencia |
|---|---|---|
| Q03 | puente semántico ES→EN técnico | `crear` ↔ `create` (Commands.md:64) |
| Q08 | concepto ↔ término técnico | "terminal opaca/transparente" ↔ `picom` (System.md:3/78) |
| Q06 | evidencia no llega desde gold esperado | `FF_SEEN` en CHANGELOG.md:186 no se recupera en ninguna variante |

Baselines sobre gold definitivo (v3.1):

| Estrategia | Gold recall | Context relevance | Leakage | Tokens |
|---|---|---|---|---|
| A — AND | 0.000 | 0.533 | **0.267** | **5.2k** |
| B — OR | 0.050 | 0.182 | 0.694 | 45.3k |
| C — AND-norm | **0.100** | 0.333 | 0.522 | 38.0k |

## 3. Alcance (qué NO se toca)

- ❌ `buffy-search.sh` (runtime congelado)
- ❌ `buffy-router.sh` (runtime congelado)
- ❌ cap-selector / Hybrid / embeddings en producción
- ❌ calibración de thresholds ni pesos

El experimento vive **fuera del runtime**: un runner nuevo que indexa el corpus,
recupera con embeddings y calcula las MISMAS métricas.

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMAS QUERIES  → las 10 del EVAL
MISMO GOLD      → gold definitivo (Q04/Q06 corregidos)
MISMO LIMIT     → 10 (igual que A/B/C)
MISMAS MÉTRICAS → search_recall / other / raw · context_relevance ·
                  cross_domain_leakage · token_cost · latency · determinismo
```

Cambia UNA variable:

```text
lexical retrieval (FTS5 BM25)  →  semantic retrieval (embeddings + coseno)
```

## 5. Enfoque técnico

- **Servicio**: Ollama local (`http://localhost:11434`) — ya instalado y corriendo.
- **Modelo default**: `bge-m3` (multilingüe, 1024-dim, ~1.2 GB) — captura el puente
  español↔término técnico (`crear`↔`create`, `opaca`↔`picom`).
- **Alternativa sanity**: `nomic-embed-text` (274 MB, inglés) — para verificar si el
  multilingüismo es la pieza que falta o si el problema es más profundo.
- **Granularidad**: una fila por línea (mismo granularity que FTS5 → comparable).
- **Indexación**: corpus = `Knowledge/` + `ai-context/` (mismos archivos que indexa
  `buffy-search.sh`). Embeddings por línea vía `POST /api/embed`.
- **Retrieval**: similitud coseno(query, línea) → top-LIMIT.
- **Runner nuevo**: `scripts/tests/evals/run-semantic-PC.sh` — NO toca el runner
  lexical ni el runtime. **IMPLEMENTADO (2026-08-12)**: replica el cálculo de métricas
  v3.1 del runner lexical (search_recall por path gold_file_match, ctx = router ∪ topK,
  leakage sin penalizar gold, token_cost chars/4, determinism_hash para el gate G2);
  índice cacheado en `~/.cache/buffy-eval-semantic/` (hash del corpus, `--reindex` para
  forzar rebuild); batches a `/api/embed` con fallback al endpoint deprecado; `--model`
  para bge-m3/nomic-embed-text; compara contra A/B/C en la tabla final si los JSON
  existen. Uso: `run-semantic-PC.sh [--model bge-m3] [--ollama URL] [--limit N]
  [--reindex] [--json] [--quiet]`.

## 6. Gate (estricto, pre-fijado ANTES de medir)

El experimento solo se considera una mejora útil si cumple TODOS:

| Criterio | Umbral | Justificación |
|---|---|---|
| search_recall | **> 0.100** | claramente superior a and-norm (0.100) |
| context_relevance | **≥ 0.600** | igualar a AND (el más limpio) |
| cross_domain_leakage | **≤ 0.267** | igualar a AND |
| token_cost | **≤ ~2× A (≈ 10.4k)** | coste razonable |
| latencia | medida y reportada | sin umbral pre-fijado, se reporta |
| determinismo | 2 corridas idénticas (salvo latencia) | G2 del runner lexical |
| EVAL hash | `98a0e308…` | mismo fixture |

> Si recupera Q03/Q08 pero devuelve medio repositorio → **no es una mejora**.
> El gate de leakage/coste es tan importante como el de recall.

## 7. Criterio de lectura (reportar, no bloquear)

```text
benchmark↑ + EVAL↑  → fuerte → considerar Hybrid con base empírica
benchmark↑ + EVAL↓  → DESCARTAR
EVAL↑ + benchmark↓  → investigar (¿el problema requiere algo más específico que embeddings?)
```

## 8. NO adoptar todavía

El experimento es **diagnóstico**. El veredicto de adopción (y cualquier cambio al
runtime) es decisión del usuario, con la evidencia sobre la mesa.

## 9. Pasos de implementación (próxima sesión, tras aprobación)

1. `ollama pull bge-m3` (o `nomic-embed-text` para sanity).
2. `scripts/tests/evals/run-semantic-PC.sh` — indexa corpus → embeddings por línea →
   coseno → top-LIMIT → métricas v3.1 (mismo cálculo que el runner lexical).
   **✓ Runner implementado y validado**; falta solo la corrida real con el modelo descargado.
3. Correr **D (semantic)** sobre el MISMO EVAL → comparar contra A/B/C.
4. Reportar tabla agregada + desglose per-query (Q03/Q06/Q08 en foco) → decisión del usuario.

## 10. Resultado medido (2026-08-12) — resumen para el lector

| métrica | A | B | C | **D (bge-m3)** | gate |
|---|---|---|---|---|---|
| search_recall | 0.000 | 0.050 | 0.100 | **0.200** | > 0.100 ✅ |
| context_relevance | 0.533 | 0.182 | 0.333 | 0.192 | ≥ 0.600 ❌ |
| cross_domain_leakage | 0.267 | 0.694 | 0.522 | 0.669 | ≤ 0.267 ❌ |
| token_cost avg | 5 197 | 45 259 | 38 017 | 47 980 | ≤ ~10.4k ❌ |

**Qué respondió el experimento:** D recupera Q04 y Q06 como gold (Q06 — `FF_SEEN` —
por primera vez en cualquier variante), pero **Q03/Q08 NO se resuelven** (no_match /
other). El coste se comporta como OR (leakage 0.669, tokens 48k, relevance 0.192):
el modelo arrastra medio repositorio al top-10. Latencia 1 449 ms (embed por query).
**Conclusión:** el retrieval semántico naive por línea no resuelve el puente
ES→EN/técnico de Q03/Q08 y su coste lo descarta como reemplazo de A. No se adopta.

## 11. Riesgos / consideraciones (registrados en la ejecución)

- Descarga única del modelo (1.2 GB bge-m3) — hecha el 2026-08-12.
- Python 3.14: se usó la API HTTP de Ollama (sin dependencias ML nuevas) ✓.
- Corpus: 46 archivos / 6 880 líneas (más de lo estimado) — **indexación ~38 min en
  CPU** (~3.3 líneas/s, bge-m3 1024-dim), NO "rápida" como se estimó; mitigado con
  cache en `~/.cache/buffy-eval-semantic/` (2ª corrida sin rebuild).
- Determinismo: embeddings de Ollama deterministas ✓ (2 corridas, mismo hash).
- `bge-m3` disponible en el registro; no se necesitó el fallback `nomic-embed-text`.
  (Pendiente futuro, si el usuario lo pide: sanity en inglés.)
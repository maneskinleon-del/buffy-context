# ESPECIFICACIÓN — FASE 1: mejora mínima de Search (recuperación ante queries naturales)

> Estado: **✅ IMPLEMENTADA y MEDIDA (2026-08-11)** — search_recall 0.000 → 0.736
> (3 seeds), controles del router EXACTOS (independencia demostrada). Resultados en
> `Knowledge/Tools/Benchmark-realista.md` §Fase 1. Esta spec queda como contrato.
> Basada en la baseline 3 seeds (2026-08-11,
> `Knowledge/Tools/Benchmark-realista.md`).
> No confundir con una feature B: esta fase solo corrige el problema demostrado de
> construcción de query. El router NO se toca en Fase 1.

## 0. Problema a corregir (único alcance)

La baseline demostró `search_recall = 0.000` en 3/3 seeds. El mecanismo está en cómo
`buffy-search.sh` transforma la query antes de FTS5:

```
"el teléfono no aparece en scrcpy"
        ↓  actual
"el" AND "teléfono" AND "no" AND "aparece" AND "en" AND "scrcpy"
        ↓
FTS5 exige las 6 palabras en la misma línea indexada → 0 resultados
```

No es un problema de FTS5 (el motor soporta OR, BM25, etc.): es la **estrategia de
construcción de la consulta**. Verificado manualmente: misma query con 2 términos
("conflicto historial") recupera el hecho gold; con la query completa da vacío.

## 1. Pipeline objetivo (transformación de la query)

```
Query natural (el usuario, sin tocar el runner)
        ↓  1. normalización
        ↓  2. eliminar términos poco útiles (stopwords ES)
        ↓  3. seleccionar términos significativos (longitud, tope)
        ↓  4. recuperación flexible (OR entre términos seleccionados)
        ↓  5. ranking BM25 (ya nativo en search_query)
        ↓  6. Top-K candidatos (igual que hoy: path:lineno: snippet)
```

### 1.1 Normalización
- minúsculas + sin diacríticos, coherente con el tokenizer del índice
  (`unicode61 remove_diacritics 2`): "teléfono" y "telefono" son el mismo token.
- Tokenización por espacios/puntuación.

### 1.2 Stopwords ES (lista estática, embebida en buffy-search.sh)
- Función: `el, la, los, las, un, una, unos, unas, de, del, al, a, en, y, o, u, e,
  con, por, para, sin, sobre, se, me, te, mi, tu, su, le, lo, que, como, como_,
  cuál, cuan, cuando, dónde, cuándo, dónde_, es, son, está, estan, no, sí, ya, más,
  muy, pero, también, tampoco, algo, nada, todo, hacer, hacer_, hago, haces, quiero,
  quieres, puede, pueden, necesita, ayuda, ayudame, por_que, porque, entonces,
  ningún, ninguno, nada_`
- La lista es declarativa y acotada (~60 palabras); se puede revisar tras la primera
  corrida SIN cambiar nada más (la medición lo dirá).

### 1.3 Selección de términos significativos
- Término válido si: **longitud >= 3** (NO ≥4), NO es stopword, no es puntuación,
  y conserva tokens alfanuméricos técnicos.
- **Tokens técnicos de 3 caracteres nunca se descartan por longitud** (ADB, API,
  Git, SSH, CPU, RAM, DPI, VLM, APK, USB, ...): con una regla rígida de ≥4 chars la
  query "ADB no detecta el móvil" terminaría buscando esencialmente "detecta móvil"
  — ADB es una señal valiosísima y descartarla introduciría pérdida artificial de
  recall que el benchmark atribuiría incorrectamente al buscador. No hace falta una
  lista enorme de excepciones: el propio corpus (vocabulario técnico real) ya
  permitirá observar si esos tokens ayudan.
- Tras normalizar y filtrar: tomar como máximo 8 términos (los primeros tras el
  filtro, preservando el orden de aparición; sin reordenar ni ponderar en V1).

### 1.4 Recuperación flexible
- Construir la query FTS5 en modo **OR**: `"t1" OR "t2" OR ... OR "t8"`.
- Si la query queda sin términos útiles (todo stopwords), **fallback**: buscar con la
  query normalizada completa en modo AND (comportamiento actual) para no devolver
  basura ni el universo entero.
- Orden de resultados: BM25 (ya implementado en `search_query`, sin cambios).

### 1.5 Riesgo medible y aceptado
- OR sube el recall pero también puede subir falsos positivos → `cross_domain_leakage`
  y `context_relevance` lo medirán de forma honesta. NO se agrega rerank semántico ni
  heurísticas extra en Fase 1: la pregunta es solo cuánto recupera Search con una
  estrategia razonable.

## 2. Condiciones de medición (anti-gaming, idénticas a la baseline)

Requisitos que la implementación y la corrida DEBEN cumplir (los mismos que hicieron
válida la baseline):

1. **Mismo corpus**: mismo `generator.py` + `domains.json`, mismos seeds
   (20260810/20260811/20260812) → mismo manifest sha256 por seed.
2. **Mismas 60 queries**: `queries.json` idéntico por seed.
3. **Mismos seeds** y misma configuración del runner (500 hechos / 60 queries, top-K 10).
4. **Mismas métricas**: las 9 del contrato, mismo runner y mismas definiciones
   operativas (macro + micro, latency media + p95).
5. **El buscador recibe SOLO la query del usuario**: `search(q["text"])` sin ningún
   campo gold (ni `gold_facts`, ni `gold_domains`, ni `negative_facts`). Esto ya es
   así en el runner; la implementación de Fase 1 NO debe crear ningún canal por el
   que buffy-search.sh acceda al gold (prohibido: leer facts.json/queries.json desde
   buffy-search.sh, variables de entorno con gold, etc.).
6. **Comparación directa contra la baseline** — la tabla de resultados DEBE ser:

```
                      BASELINE        FASE 1
                   (AND, ya medido)  (OR+BM25)
------------------------------------------------
 search_recall
 context_relevance
 cross_domain_leakage
 token_cost
 latency
 router_recall        ≈ igual        ≈ igual   ← control de NO-cambio
 router_precision     ≈ igual        ≈ igual   ← control de NO-cambio
 multi_domain_*       ≈ igual        ≈ igual   ← control de NO-cambio
```

7. **NO tocar el router** (`buffy-router.sh`) ni el runner ni el corpus en Fase 1.

### 2.1 Expectativa explícita (no buscar mejorar todo a la vez)

Es perfectamente aceptable (¡y útil!) que la Fase 1 termine con:

```
search_recall      ↑↑
context_relevance  ↑
cross_domain_leakage ↑
token_cost         ↑
```

Eso significaría que SE recupera correctamente pero falta una capa de
selección/reranking posterior — exactamente el insumo que alimentaría Fase 2/3.
El resultado NO se considera fallido porque suba leakage/tokens: son mediciones
honestas del trade-off de recuperación flexible.

### 2.1 Mecanismo de comparación (sin tocar el runner)
- `buffy-search.sh` lee la variable de entorno **`BUFFY_SEARCH_STRATEGY`**:
  - `and` (default) → comportamiento actual byte a byte (reproducción exacta de la
    baseline; todos los tests existentes del repo siguen verdes sin cambios).
  - `or` → pipeline de §1.
- El runner `bench-realistic.sh` NO cambia: se corre dos veces con la env var
  `and` vs `or` y se comparan los JSON con la misma tabla del informe.
- Justificación: la baseline queda reproducible exacta; el experimento no altera el
  camino real de búsqueda salvo cuando se pide explícitamente; y G2 (determinismo)
  sigue aplicando a ambos modos.

## 3. Criterios de éxito (lectura, no umbrales)

- **search_recall**: debe subir desde 0.000 de forma sustancial en las 3 seeds
  (media + sd reportadas). El contrato prohíbe fijar umbrales con una seed: se
  evalúa en las 3 y se reporta la tabla completa antes/después.
- **Control de independencia (la pregunta clave)**: `router_recall` / `router_precision`
  deben permanecer ~iguales a la baseline (0.225 / 0.250 ± sd) — evidencia de que
  Search y Router son problemas independientes. Si cambian fuera de variabilidad,
  es un hallazgo a investigar (no a tapar).
- **Efectos colaterales medidos**: `context_relevance`, `cross_domain_leakage`,
  `token_cost`, `latency` antes/después (se espera leakage mayor con OR; se reporta).
- **Gates**: G1 (fixtures), G2 (determinismo: resultados salvo latencia idénticos en
  dos corridas del mismo modo), G3 (mismo manifest) → 3/3 en ambos modos.
- **Suite del repo**: los tests existentes (en particular los que ejercitan
  `buffy-search.sh`: test-scale, test-context-selection) deben seguir verdes con el
  default `and` — sin cambios en run-tests.sh ni README en esta fase.

## 4. Pregunta que contesta esta fase (aislamiento)

> ¿Cuánto del problema actual se debe EXCLUSIVAMENTE a la estrategia AND?

- Si `search_recall` sube de 0.000 a un valor razonable y `router_recall` queda
  ~0.225 → **evidencia limpia** de que recuperación y selección son problemas
  independientes → habilitar Fase 2 (medir el router aisladamente con Search sano).
- Si `search_recall` sigue ~0 con OR → la hipótesis AND es insuficiente y hay que
  revisar antes de tocar el router (tokenización, corpus, vocabulario).

## 5. Implementación (SOLO cuando la especificación esté aprobada)

1. `scripts/buffy-search.sh`:
   - nueva función de normalización (minúsculas + diacríticos, coherente con el
     tokenizer);
   - lista `STOPWORDS_ES` declarativa;
   - construcción de query por estrategia `and`|`or` según `BUFFY_SEARCH_STRATEGY`
     (default `and` = comportamiento actual intacto);
   - con `or`: `"t1" OR ...` (≤8 términos, longitud ≥3 sin descartar tokens técnicos
     de 3 chars) + fallback AND si no quedan términos.
2. Tests nuevos (en los archivos de test existentes del repo):
   - query natural → top-K NO vacío con `or`;
   - default `and` → same output que hoy (byte a byte sobre corpus fijo);
   - determinismo de `or` (dos corridas, mismo output).
3. Corridas benchmark: 3 seeds × modo `and` (reproducción baseline) × modo `or` →
   tabla comparativa en `Knowledge/Tools/Benchmark-realista.md` (sección Fase 1).
4. NO: tocar router, corpus, queries, runner, gates, run-tests.sh, README, `--quick`.
5. Al terminar: reporte con la tabla antes/después y la respuesta a la pregunta de §4.

## 6. Fuera de alcance (explícitamente)

- Feature B / capa multi-dominio / rerank semántico / embeddings / modelos VLM.
- Cambiar el corpus, las queries o las seeds (anti-gaming).
- Cambiar métricas o gates del benchmark.
- Tocar `buffy-router.sh` por cualquier motivo en Fase 1.
- Integrar `--quick` a la suite principal.
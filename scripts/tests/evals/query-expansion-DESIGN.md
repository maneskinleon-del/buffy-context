# Paso 10 — Query Expansion (diseño + ejecución)

> Estado: **EJECUTADO** (2026-08-12) — H1 y H2 medidos, NO pasan el gate
> (passage_relevance/leakage, capa de selección), nada se adopta.
> Runner: `scripts/tests/evals/run-expansion-PC.sh`. Resultados en
> `EVAL-REGISTRY.md` §Paso 10 + Anexo A abajo.
> Base: EVAL con gold definitivo (hash `98a0e308…`), pasajes G1-VENTANA validados
> (Paso 9 ejecutado: `run-passage-PC.sh`), serie A→G2 completa en `EVAL-REGISTRY.md`.
> Autorizado por el usuario (2026-08-12): \"implementar y ejecutar H1 + H2 sobre el
> mismo EVAL, con G1-VENTANA y los gates ya fijados; después de medir, detenerse
> otra vez; NO implementar 10B todavía\".

## 1. Objetivo e hipótesis

**Pregunta:** ¿generar términos alternativos de la consulta (expansión) hace aparecer
candidatos que hoy están **fuera del pool**, cerrando el candidate gap de Q03 (y de
Q01/Q05/Q10) — sin romper lo que passage-level ya logró (coste ~2.6k, recall 0.417,
Q04/Q06 entregados)?

**Hipótesis central (derivada de G-H0 del Paso 9):**

> Q03 `gh pr create` está `out_of_pool` NO porque falte en el corpus (está en
> `Knowledge/Git/Commands.md:64`) ni porque el lexical no pueda encontrarla
> (verificado hoy: `buffy-search.sh "gh pr create"` la devuelve en top-3), sino porque
> la **representación de la consulta** no produce el término. El candidate gap es un
> problema de **representación de la consulta**, no de ausencia ni de ranking.

```text
QUERY: "quiero pushear el commit y crear el pull request"
        ↓ OR-tokenización
{push(ear), commit, crear, pull, request}
        ↓ gate co-ocurrencia ≥2 tokens contra la línea gold
Commands.md:64 "gh pr create  # Crear PR" → overlap 1 (solo «crear») → DESCATADO
        ↓
gh pr create → out_of_pool
```

**Hipótesis verificable:** si la rama léxica se re-consulta con términos expandidos
(`gh pr create`, `crear pr`, …), la línea gold entra al pool con overlap alto
(3 tokens) → pasa a `in_pool_*` → con la fusión y pasajes del Paso 9, la aguja llega
al ctx → `search_recall` sube.

## 2. Evidencia de viabilidad (medida HOY, antes de escribir esta spec)

### 2.1 El candidate gap es 100% recuperable por la rama léxica

Las **6 agujas `out_of_pool`** de G1 (todas `needle_in_corpus=True`) se probaron con
términos expandidos contra `buffy-search.sh -l 50` (rama L real, runtime intacto):

| Query | Aguja out_of_pool (G1) | Término expandido que recupera el gold | Resultado |
|---|---|---|---|
| Q01 | `adb tcpip 5555` | `adb tcpip` / `tcpip` / `conectar` | ✅ ADB.md:14 en top-50 |
| Q01 | `adb connect` | `adb connect` / `conectar adb` | ✅ ADB.md:12 en top-50 |
| Q03 | `gh pr create` | `gh pr create` / `crear pr` | ✅ Commands.md:64 en top-50 |
| Q05 | `useState` | `useState` | ✅ React.md:26 en top-50 |
| Q10 | `dumpsys thermalservice` | `dumpsys thermalservice` / `thermalservice` / `temperatura` | ✅ GameOptimization.md:62/61 |
| Q10 | `thermal_control` | `thermal control` / `thermal_control` / `temperatura` | ✅ GameOptimization.md:65/61 |

**6/6 recuperables.** El techo del Paso 10 es 100% del candidate gap (4 queries:
Q01, Q03, Q05, Q10) — si la expansión genera los términos correctos.

### 2.2 Datos que dimensionan el diccionario

- `pull request` → **NO** recupera Commands.md:64 (0 hits en top-50): la traducción
  del concepto no alcanza; el vocabulario real de la línea es el **comando/símbolo**
  (`gh pr create`) o el comentario ES (`Crear PR`).
- `useState` → sí (React.md:26); pero `hook` / `state react` → **NO**. Los símbolos
  exactos del código no se derivan por reglas genéricas.
- `temperatura` (ES) → sí recupera GameOptimization.md:61 (`# Ver temperatura`) — la
  traducción directa funciona cuando el corpus tiene anotaciones/comentarios ES.
- `git push origin` (la otra aguja de Q03) ya es `in_pool_ranked_out` en G1/G2 —
  con pasajes mejoró sola; la expansión solo necesita `gh pr create`.

### 2.3 Inestabilidad entre variantes (referencia fija)

En G2, Q07 pasa a `out_of_pool` ×2 (dumpsys thermalservice, force_gpu_rendering) por
diferencias de ranking. **La referencia del gap se fija a G1** (la corrida canónica,
mejor recall de la serie): 6 agujas en 4 queries. G2 es una segunda lectura, no la
referencia del numerador.

## 3. Alcance (qué NO se toca)

- ❌ `buffy-search.sh`, `buffy-router.sh`, cap-selector, defaults → **runtime congelado**.
- ❌ Cambiar la unidad de contexto (se REUSA G1-VENTANA del Paso 9, la mejor variante).
- ❌ Nuevos modelos / embeddings → el diccionario es **data estática curada**, no ML.
- ❌ Calibración (tamaños, pesos, presupuesto) con el EVAL (TEST, no dato de adaptación).
- ❌ Reranking/selección de pasajes (Q08) → **hipótesis separada (Paso 10B)**, NO se
  mezcla aquí. Documentada en §13.
- ❌ Integrar expansión al runtime antes del veredicto.

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMAS QUERIES  → las 10 del EVAL
MISMO GOLD      → gold definitivo
MISMO LIMIT     → 10
MISMAS MÉTRICAS → v3.1 + passage_relevance + gold_containment + G-H0 (del Paso 9)
MISMO CORPUS    → mismo índice/alcance que A-G
MISMA UNIDAD    → pasajes G1-VENTANA (±4 líneas), dedup por (path, rango)
MISMO PRESUPUESTO → 10.4k tokens sobre el pasaje
MISMA FUSIÓN    → V1-RRF (k=60) sobre el pool
```

Cambia **una sola cosa**: la rama léxica L se re-consulta con la **query expandida**
(diccionario de términos alternativos). Todo lo demás queda como en G1.

> **Comparabilidad declarada:** la base es G1 → los números de tokens, recall y
> gold_containment SÍ son comparables con la serie (misma unidad de pasaje). La única
> diferencia entre G1 y H1/H2 es el contenido del pool de la rama léxica.

## 5. Arquitectura propuesta (rama X aditiva a la rama L)

### 5.1 Mecanismo

```text
QUERY original
   │
   ├─ L ─── OR top-50 (query original) + gate co-ocurrencia ≥2 tokens ──┐
   ├─ X ─── para cada término t del diccionario de la query:            │→ POOL (dedup path:lineno)
   │        buffy-search.sh -l 50 "t" (gate: hit contiene ≥1 token      │→ fusión V1-RRF k=60
   │        significativo de t — el término es preciso por construcción)│→ top-10 hits
   └─ S ─── índice bge-m3 de D (coseno, cacheado, N_S=50) ─────────────┘→ pasajes G1 (±4)
                                                                        → ctx = router ∪ pasajes
                                                                        → presupuesto 10.4k
                                                                        → métricas v3.1 + G-H0
```

- La rama **X** es la única novedad: re-consultas léxicas con los términos del
  diccionario (deterministas, `buffy-search.sh` sin modificar). Es **aditiva**: L se
  conserva intacta, X agrega hits al pool.
- La rama **S** (semántica) se conserva tal cual: el objetivo es aislar el efecto de
  la expansión, no remezclar ramas.
- La rama **L** (query original) se conserva: la expansión es ADITIVA, no sustitutiva.

**Tokenización de la rama X (declarada):** se reutiliza la definición de "tokens
significativos" de la rama L / and-norm (deaccent → lowercase → alnum → ≥3 chars,
stopwords ES) — NO se inventa una tokenización nueva. Gate de X: el hit debe
contener ≥1 token significativo del término de expansión. Declaración honesta: para
términos de 1 token (`useState`, `tcpip`, `picom`) el gate es trivial (el propio
ranking BM25 ya lo garantiza) — el filtro real de cada re-consulta es el top-50;
para términos de ≥2 tokens el gate descarta hits que solo matchean parcialmente.

### 5.2 Diccionario — DOS variantes (dos resultados independientes, mismo gate)

| Variante | Diccionario | Naturaleza |
|---|---|---|
| **H1-DICT-MIN** | Traducción ES→técnico por reglas genéricas + acrónimos estándar: `crear→create/make/new`, `pushear→push`, `conectar→connect`, `abrir→launch/open/start`, `ver→show/list/get`, `opaca→transparent/opacity`, `apagar→off/disable/blanking/dpms`, `lento→slow/performance/governor`, `calentar→thermal/temperature`, `rendimiento→performance/governor`, `PR→pull request/pr`, `serial→serial/devices`, `app→application`, `script→script/sh` | **Realista**: lo que un diccionario genérico ES↔EN curado daría |
| **H2-DICT-FULL** | H1 + **términos exactos del dominio de buffy-context**: `gh pr create`, `git push origin`, `adb tcpip`, `adb connect`, `tcpip`, `useState`, `dumpsys thermalservice`, `thermal_control`, `thermal control`, `temperatura`, `picom`, `compositor`, `opacity`, `xset -dpms`, `xset s off`, `FF_SEEN`, `watchdog` | **Techo informativo**: mide cuánto se gana con expansión casi perfecta |

> ⚠️ **Riesgo de oráculo — declarado ANTES de medir:** H2 se cura conociendo las
> queries y el vocabulario del gold → **NO es candidato a adopción**. Su único rol es
> establecer el límite superior del experimento (¿cuánto puede ganar la expansión si
> es perfecta?). **H1 es la señal realista** para decidir. El diccionario de cada
> variante se **congela en un archivo versionado** (dentro del runner, commit de la
> spec) ANTES de correr; el runner calcula un **hash del diccionario** (junto al
> determinism_hash) para detectar cualquier edición post-hoc. No se edita después de
> ver resultados.
>
> Nota: el mapeo `opaca→transparent/opacity` de H1 es **especulativo** — la serie
> documentó overlap NINGUNO entre la query de Q08 y System.md (puente técnico
> `opaca↔picom`, no léxico); se espera que NO recupere. Se incluye en H1 para medir
> ese límite, no como promesa.

### 5.3 Gate de la rama X

Los hits de X entran al pool si el hit contiene **≥1 token significativo del término
de expansión** (los términos son cortos/precisos por construcción; exigir ≥2
descartaría `useState` o `picom`). El ranking BM25 y el top-50 de cada re-consulta
ya acotan el ruido. Se marca cada hit del pool con `rama: L|X|S` para G-H0 y
diagnóstico (métrica secundaria `pool_rama_stats`).

## 6. Presupuesto (fijado ANTES de medir)

| Parámetro | Valor | Justificación |
|---|---|---|
| `N_L` / `N_S` | 50 / 50 | igual que E/F/G |
| `N_X` | 50 por término (todas las re-consultas del diccionario) | cada término es una consulta |
| tope pool X | **cap 200 hits por query** (dedup path:lineno antes de fusionar) | G1 tenía ~100 items (L∪S); X puede sumar hasta +500 → se acota el pool X total ANTES de la fusión (declarado, no calibrado: el cap es amplio y solo evita que una sola re-consulta domine) |
| `token_budget` | **10.4k** (mismo que E/F/G1) | comparación directa con G1 |
| LIMIT final | 10 | idéntico a la serie |
| Pasaje | G1-VENTANA ±4 | la mejor variante del Paso 9 |

El presupuesto se aplica al ctx final (router ∪ pasajes) en orden del reranking,
igual que en G1. La expansión puede **aumentar el pool** pero el ctx sigue acotado —
si el ruido de los términos expandidos desplaza pasajes gold, el gate lo captura
(pRel/leakage bajan) — exactamente la advertencia del usuario: \"más candidatos no
equivalen a mejor contexto\".

## 7. Gate (estricto, pre-fijado ANTES de medir) — mismo del Paso 9 + 1 nuevo

| Criterio | Umbral | Definición operativa |
|---|---|---|
| search_recall | **> 0.100** | v3.1, matching sobre pasaje (igual que G1) |
| passage_relevance | **≥ 0.600** | fracción de pasajes del ctx con path ∈ gold_files |
| cross_domain_leakage | **≤ 0.267** | igualar a A |
| token_cost | **≤ ~10.4k** | sobre pasajes (comparable con G1) |
| gold_containment | **≥ 0.80** | el pasaje del gold cabe completo en presupuesto |
| **candidate_gap_recovery** | **reportar por aguja** (no bloquea) | NUEVA: fracción de las **6 agujas out_of_pool de G1** que pasan a `in_pool_*` — la métrica que mide literalmente el objetivo del Paso 10 |

**candidate_gap_recovery** (nueva, diagnóstico): denominador = las 6 agujas
`out_of_pool` (corpus=True) medidas en G1 (Q01×2, Q03×1, Q05×1, Q10×2); numerador =
las que en H1/H2 pasan a `in_pool_top10` / `in_pool_ranked_out` / `in_pool_budget_cut`
(G-H0 re-derivado sobre el nuevo pool). Se reporta como fracción y **por aguja** —
foco Q03 `gh pr create`, la aguja estrella del paso. **No bloquea el gate** (los 5
criterios de calidad son los bloqueantes), pero tiene regla de lectura definida (§9).

> **Condición adicional (mantenida de la serie):** los CINCO criterios a la vez. No
> se acepta expansión solo porque recupere Q03; debe demostrar que el ctx sigue con
> calidad de nivel A.

## 8. Pre-gate de candidate availability (G-H0) — adaptado

Idéntico al del Paso 9 (statuses sobre pasajes) con un añadido: por cada aguja que
en G1 era `out_of_pool` y en H1/H2 pasa a `in_pool_*`, se registra **qué rama la
generó** (`L|X|S`) y **qué término de expansión** la trajo — trazabilidad exacta del
efecto:

```text
Q03 | gh pr create | G1: out_of_pool → H2: in_pool_top10 (vía X: "gh pr create")
Q10 | dumpsys thermalservice | G1: out_of_pool → H?: in_pool_* (vía X: "...")
```

El objetivo explícito de G-H0: **las 6 agujas del gap deben moverse** de
`out_of_pool` a `in_pool_*` en H2 (techo) y ver cuántas logra H1 (realista). Se
documenta también si alguna `in_pool_top10` de G1 **se cae** con la expansión
(regresión del ranking por pool más grande).

## 9. Criterio de lectura (reportar, no bloquear)

```text
H1/H2: search_recall > 0.100 + pRel ≥ 0.600 + leakage ≤ 0.267
       + tokens ≤ 10.4k + gold_containment ≥ 0.80  →  señal fuerte
```

**⚠️ Expectativa declarada ANTES de medir (la más importante):** la expansión ataca
la capa de **generación**; no cambia el rerank ni la selección de pasajes. Es
esperable que H1/H2 cierren parte del candidate gap y aun así mantengan
pRel ≈ 0.07 y leakage ≈ 0.61 (heredados de G1, capa de selección). En ese caso el
veredicto NO es "la expansión fracasó" sino:

> la expansión resuelve la generación; la calidad del ctx depende de la selección
> (Paso 10B) — resultado esperable y medido, no un fallo del experimento.

**Regla de lectura global de candidate_gap_recovery (declarada):**

- **señal fuerte** = Q03 `gh pr create` pasa a `in_pool_*` en **H1** (realista) y,
  por tanto, en H2 (techo); idealmente 6/6 en H2.
- **señal parcial** = solo H2 lo logra → la expansión viable necesita diccionarios
  de dominio más ricos; H1 documenta el límite realista.
- **si los 5 gates pasan pero gap_recovery = 0/6** → la mejora vino de otra parte;
  se reporta y se lee como evidencia de que el gap no es el cuello de botella.
- **si Q03 pasa pero Q10 no** → se reporta por aguja; la lectura es por query, no
  solo por fracción.

- **Q01/Q10**: si H1 (reglas ES→EN) las recupera (`conectar`, `temperatura`) → la
  traducción directa ES funciona en corpus con anotaciones ES.
- **Q05 (`useState`)**: solo recuperable por H2 (símbolo exacto) → evidencia de que
  los símbolos de código requieren expansión por diccionario de dominio, no reglas.
- **Q04/Q06 (resueltos en G1)**: deben SEGUIR en `in_pool_top10` con
  gold_containment 1.0 → la expansión no debe romper lo ganado (regresión, §12).
- **Q08** (agujas en pool pero gold file fuera en G1): NO es objetivo del Paso 10 —
  se registra su estado pero no se espera mejora (es selección, capa 10B).
- **H1 vs H2** se leen como dos curvas independientes (nunca se escoge después).

## 10. NO adoptar todavía

Diagnóstico + decisión. El veredicto de adopción (y cualquier cambio al runtime) es
del usuario. H2 jamás se adopta (oráculo). Si H1 pasa el gate, aún sería decisión del
usuario diseñar la integración. **El veredicto del Paso 10 es por CAPAS**: mide si la
expansión cierra el candidate gap (generación); si pRel/leakage no se mueven, eso
queda atribuido a la capa de selección (Paso 10B), no a la expansión.

## 11. Pasos de implementación (tras aprobación de esta spec)

1. `scripts/tests/evals/run-expansion-PC.sh` — runner nuevo (hereda el pipeline de
   `run-passage-PC.sh`):
   - **diccionarios H1/H2 versionados** (archivos de data dentro del runner, parte
     del mismo commit) con **hash calculado en el JSON** (junto al determinism_hash)
   - ramas L/S idénticas a G1; **rama X** = re-consultas `buffy-search.sh -l 50`
     por término del diccionario (gate ≥1 token, tope pool X 200) — tokenización
     and-norm reutilizada
   - pool = L ∪ X ∪ S (dedup path:lineno, marca de rama, tope antes de fusionar)
     → RRF k=60 → top-10
   - pasajes G1-VENTANA → ctx = router ∪ pasajes (dedup path:rango) → presupuesto 10.4k
   - métricas v3.1 + passage_relevance + gold_containment + G-H0 con origen (rama/término)
     + métrica de regresión (§12) + candidate_gap_recovery por aguja
   - tabla comparativa H1/H2 vs G1 (y vs A-F como contexto)
2. Verificar fixture (hash) + determinismo (2 corridas por variante).
3. Correr H1 y H2 sobre el MISMO EVAL → comparar A→G1 vs H1/H2.
4. Reportar: agregado + por query con candidate_status y origen de rama/término +
   candidate_gap_recovery (foco Q03) → decisión del usuario.

## 12. Riesgos / consideraciones

- **Riesgo 1 — oráculo en H2:** declarado (§5.2); H2 es techo informativo, jamás
  adopción. El diccionario se congela antes de medir (versión + hash).
- **Riesgo 2 — ruido por expansión:** más términos → más hits no-gold en el pool →
  pRel/leakage pueden empeorar. El gate (5 criterios) lo captura; es el riesgo CENTRAL
  del experimento y la advertencia explícita del usuario. (Ojo: G1 ya tenía
  pRel 0.072/leakage 0.606; la lectura correcta es por capas, ver §9.)
- **Riesgo 3 — símbolos exactos:** `useState`/`FF_SEEN`/`picom` no se derivan por
  reglas genéricas; solo H2 los cubre → documenta el límite del diccionario ES→EN.
- **Riesgo 4 — regresión de G1:** la expansión puede desplazar pasajes gold del
  top-10 (pool más grande). Se mide con una **métrica secundaria de regresión**
  (reportar, no bloquear): fracción de agujas que en G1 eran `in_pool_top10` y
  siguen `in_pool_top10` en H1/H2 (objetivo: 1.0); si baja, se reporta qué agujas
  cayeron y por qué (desplazadas por hits de X).
- **Riesgo 5 — inestabilidad Q07:** la referencia del gap es G1 (fija); G2 es lectura
  secundaria. No se recalcula el numerador contra G2.
- **Determinismo:** rama X = `buffy-search.sh` + diccionario estático versionado →
  G2 reproducible (hash del diccionario incluido en el determinism_hash).

## 13. Fuera de alcance (explícito)

- **Paso 10B — reranking/selección de pasajes (Q08):** hipótesis SEPARADA documentada
  por el usuario. Q08 entra al pool y al top-10 pero el gold file queda fuera → es
  selección, no generación. NO se intenta resolver con expansión. Se diseñará como
  experimento propio (probablemente: puntuar pasajes por señal de dominio/co-ocurrencia
  con la query, sin calibración con el EVAL). **Tras el Paso 10, 10B gana fuerza
  experimental: las agujas del gap quedaron TODAS en el pool (ranked_out) y el RRF no
  las priorizó.**
- Cambiar la unidad de contexto, el presupuesto, la fusión o los tamaños de rama.
- Nuevos modelos / entrenamiento.
- Calibración de pesos del diccionario con el EVAL.
- Integrar la expansión al runtime antes del veredicto.
- Modificar el corpus, fixture, gold o métricas (anti-gaming).

---

## Anexo A — Resultados medidos (2026-08-12, EVAL 98a0e308…, instrumento v3.1)

Corridas reales con índice bge-m3 de D (cache hit), ramas L/X/S, fusión V1-RRF,
pasajes VENTANA ±4. Determinismo G2: hash idéntico en 2 corridas por variante
(H1 `3618caf4…`, H2 `e942eadc…`). Diccionarios congelados (dict_hash
`b0406a3368003bea` en el JSON). `snippet_scope: passage`.

| Estrategia | Recall | pRel | cRel(file) | Leakage | Tokens | gold_containment |
|---|---:|---:|---:|---:|---:|---:|
| G1 — VENTANA | 0.417 | 0.072 | 0.214 | 0.606 | 2 569 | 0.8 |
| G2 — SECCIÓN | 0.333 | 0.054 | 0.214 | 0.606 | 3 373 | 0.7 |
| H1 — DICT-MIN | 0.317 | 0.064 | 0.199 | 0.616 | 2 451 | **1.0** |
| H2 — DICT-FULL | 0.367 | 0.064 | 0.197 | 0.621 | 2 454 | **1.0** |

### Gate (5 criterios simultáneos) — H1 y H2 NO pasan

| Criterio | Umbral | H1 | H2 |
|---|---|---:|---:|
| search_recall | > 0.100 | 0.317 ✅ | 0.367 ✅ |
| passage_relevance | ≥ 0.600 | 0.064 ❌ | 0.064 ❌ |
| cross_domain_leakage | ≤ 0.267 | 0.616 ❌ | 0.621 ❌ |
| token_cost | ≤ ~10.4k | 2 451 ✅ | 2 454 ✅ |
| gold_containment | ≥ 0.80 | 1.0 ✅ | 1.0 ✅ |

### candidate_gap_recovery — objetivo cumplido

- **H1-DICT-MIN: 5/6 (0.833)** — `adb tcpip 5555` y `adb connect` (X: adb devices),
  **`gh pr create` (X: `push` — regla genérica de `pushear`; `create` de `crear`
  también era término X)**, `dumpsys thermalservice` y `thermal_control` (X: thermal).
- **H2-DICT-FULL: 6/6 (1.0)** — las 5 de H1 + `useState` (X: useState, símbolo exacto).

### Hallazgo principal: generación resuelta, SELECCIÓN rota (Caso D confirmado)

Las 6 agujas del gap pasaron a `in_pool_ranked_out` — NINGUNA llegó al top-10 →
Q01/Q03/Q05/Q10 siguen con sRec 0.0. Recall global H1/H2 (0.317/0.367) < G1 (0.417).
El RRF no prioriza las agujas frente al ruido del pool expandido (1071-1364 hits X
únicos vs ~100 de G1). **Caso D de la spec, confirmado al pie de la letra**: la
expansión resuelve la generación; la calidad del ctx depende de la selección (10B).

### Regresión vs G1 (9/12)

3 agujas `in_pool_top10` de G1 cayeron en H1/H2: Q05 `adb devices -l`, Q07
`dumpsys thermalservice`, Q07 `force_gpu_rendering`. Contrapartida: Q09 sube
0.5 → 1.0 en H2 (`force_gpu_rendering` → top10 vía X). Coste tokens 2.5k ✅;
latency ~4.1 s (coste de la expansión, no gate).

### Conclusión

H1/H2 no adoptados. La expansión cierra el candidate gap y mueve el cuello de
botella al reranking → **10B justificado experimentalmente**. Runtime congelado.

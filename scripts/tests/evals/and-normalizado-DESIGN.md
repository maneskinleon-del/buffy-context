# AND Normalizado — Diseño del experimento (Paso 4)

> **Estado:** ⏳ DISEÑO aprobado para implementar (aún NO implementado).
> **Fecha:** 2026-08-11 · **Perfil:** PC (`sabrewulf-a320ms2h`)
> **EVAL:** `eval-ctx-PC-2026-08-11.json` (hash `8e42d119...`, congelado)
> **Baselines de referencia:** A (AND crudo, Paso 2) y B (OR, Paso 3)

---

## 1. Objetivo e hipótesis

**Objetivo:** probar una hipótesis limpia — *¿podemos recuperar parte de lo que OR
recupera, reduciendo simultáneamente el ruido y el leakage?* — mediante un operador
**AND normalizado** que exige co-ocurrencia de **≥2 tokens significativos** en la
misma línea, sin cambiar el runtime de producción.

**Hipótesis verificable (del diagnóstico Q03/Q04/Q06/Q08):**
las líneas gold comparten solo 1-2 tokens significativos con la query natural.
AND crudo exige TODAS las palabras literales (incl. stopwords) → nunca matchea.
OR matchea CUALQUIER token → recupera pero inunda de ruido/leakage.
Un AND normalizado (≥2 tokens significativos, sin stopwords) debería:
- recuperar Q03/Q04 (sus líneas gold comparten 2 tokens: `crear`, `pantalla`+`apaga`),
- NO recuperar con ruido lo que OR trae por 1 token aislado,
- NO degradar context_relevance ni disparar leakage como OR.

**Criterio de éxito del experimento (no de adopción):** medir el trade-off y
reportarlo contra A y B. El experimento NO decide adoptar; solo produce evidencia.

---

## 2. Alcance y fuera de alcance

**Dentro:**
- Corregir el instrumento de medición (`search_recall` gold vs other — §5).
- Añadir la estrategia **`and-norm`** al runner del EVAL (medición, NO al runtime).
- Medir `and-norm` sobre el MISMO EVAL congelado, mismo perfil PC.
- Comparar A vs B vs and-norm con métricas idénticas y reportar.

**Fuera (explícitamente NO se toca):**
- `buffy-search.sh` y `buffy-router.sh` → **runtime congelado** (mismo criterio que
  Pasos 2-3: `runtime_changed: false`).
- Hybrid, cap-selector, calibración de `θ_c`, presupuesto o pesos.
- El default de estrategia (`and`) del sistema.
- El EVAL congelado y las baselines A/B (no se reescriben).
- Los 5 FAIL preexistentes de la suite PC (fuera de alcance, ver Paso 3).
- Re-medir A/B con el runner viejo: el runner corregido corre las 3 estrategias en
  la misma corrida para comparación justa.

---

## 3. Estrategia `and-norm` — definición operativa

### 3.1 Tokenización / normalización

Idéntica a la rama OR de `build_query` en `buffy-search.sh` (para coherencia total
con el índice FTS5 `unicode61 remove_diacritics 2`):

1. `deaccent` (á→a, é→e, ...) — misma función del script.
2. `sed 's/[^[:alnum:] ]/ /g'` — reemplazar no-alfanuméricos por espacio.
3. `tr -s ' '` — colapsar espacios.
4. `lowercase` por token.

### 3.2 Lista de stopwords

`STOPWORDS_ES` **exacta** ya existente en `buffy-search.sh` (misma lista, sin
inventar una nueva — el experimento cambia UNA variable: el operador).

### 3.3 Mínimo de longitud

**≥ 3 caracteres** por token (igual que OR). Nota técnica: tokens técnicos de 3
chars (`adb`, `api`, `dpi`, `zte`) se conservan.

### 3.4 Regla de co-ocurrencia (≥2 tokens)

Un hit es válido si **≥2 tokens significativos** (de los §3.1-3.3) aparecen como
**tokens completos en la misma línea indexada** (la fila `line` del índice FTS5).

Definición de "token completo": al normalizar la línea con el MISMO pipeline
(§3.1), el token de la query está en el conjunto de tokens de la línea
(comparación de sets — sin substring, sin parciales).

### 3.5 Ranking

Se mantiene **bm25** del índice FTS5 como ranking primario (igual que A/B — para
no introducir una segunda variable). El filtro de co-ocurrencia actúa como gate
POST-query: se pide un top-N amplio al motor (para no perder candidatos), se
filtra por co-ocurrencia ≥2 y se conserva el orden bm25. `N_amplio = 50`.

### 3.6 Tratamiento de queries con <2 tokens significativos

- **0 tokens significativos** (todo stopwords o <3 chars) → fallback al **AND crudo**
  actual (comportamiento histórico; no devolver basura).
- **1 token significativo** → no se puede aplicar la regla ≥2. Decisión: **usar ese
  token solo** (equivalente a OR de 1 término) y **marcar la query** con
  `cooccurrence_gate: "n/a"` en el JSON — caso defensivo documental; en el EVAL
  actual las 10 queries tienen ≥2 tokens significativos, así que no aplica en la
  medición.

---

## 4. Corrección del instrumento — `search_recall` gold vs other

**Problema detectado en el diagnóstico (Paso 3):** el runner actual concatena los
snippets de TODOS los hits (línea 148 de `run-baseline-PC.sh`) y busca la aguja
como substring del texto concatenado. Si la aguja aparece en un hit de un archivo
NO-gold, se cuenta como recuperada aunque el archivo gold nunca la expuso
(casos reales: Q06 `com.dts.freefireth` hallado en `CONTINUE.md:325`; Q08 `picom`
hallado en `AGENTS.md:36`).

**Corrección:** por cada aguja `f ∈ gold_facts`, clasificar el match:

| status | definición |
|---|---|
| `gold_file_match` | la aguja aparece en un snippet cuyo path ∈ `gold_files` |
| `other_file_match` | la aguja aparece en snippets, pero NINGUNO es de `gold_files` |
| `no_match` | no aparece en ningún snippet |

- **`search_recall` (métrica de contrato) = gold_file_match / \|gold_facts\|**
  (solo recuperación desde archivos gold).
- `search_other_recall` = other_file_match / \|gold_facts\| → métrica de
  **diagnóstico** (información útil, NO cuenta como recall).
- `search_recall_raw` = (gold + other) / \|gold_facts\| → para comparar con el
  runner viejo (reproducción del Paso 3).

---

## 5. Métricas

Las **9 métricas del contrato `bench-realistic-DESIGN.md` §3** (todas, sin quitar
ninguna) + 2 de diagnóstico nuevas:

| métrica | definición | comparada contra |
|---|---|---|
| router_precision / router_recall | §3 (aislado — esperado Δ=0) | A, B |
| multi_domain_precision / recall | §3 (queries multi) | A, B |
| categories_recall / spurious_categories | del EVAL | A, B |
| **search_recall (corregido)** | §4: gold_file_match / \|facts\| | A, B |
| context_relevance | §3 | A, B |
| token_cost (media + p95) | §3: Σ chars(ctx)/4 | A, B |
| latency (media + p95) | §3 | A, B |
| cross_domain_leakage | §3 | A, B |
| window_utilization | tokens/200k | A, B |
| **search_other_recall** (nuevo) | §4 diagnóstico | — |
| **cooccurrence stats** (nuevo) | por query: tokens significativos, hits antes/después del gate | — |

Por query se registra además el desglose `gold_facts_matches`:
```json
"gold_facts_matches": [
  {"text": "com.dts.freefireth", "status": "other_file_match", "path": "ai-context/CONTINUE.md"},
  {"text": "FF_SEEN", "status": "no_match", "path": null}
]
```

---

## 6. Gates y criterio de comparación

Siguiendo §4 del bench (gates de sanidad, no de calidad):

- **G1 — fixture válido:** EVAL congelado (hash verificado) — ya cumplido, se
  re-verifica al correr.
- **G2 — determinismo:** dos corridas de and-norm producen JSON idéntico salvo
  `latency_ms`.
- **G3 — comparabilidad:** A, B y and-norm corren sobre el MISMO EVAL, mismo
  runner, mismo perfil, misma corrida.

**Criterio de lectura (reportar, NO bloquear):** and-norm es interesante si
mejora sobre A en search_recall sin repetir el colapso de B:
- search_recall_corregido ≥ 0.150 (igualar el recall REAL de OR, corregido) — ideal
  ≥ 0.250 (los 4 de OR), con Q03/Q04 como mínimo recuperable por diseño.
- context_relevance ≥ 0.600 (no degradar vs A=0.600).
- cross_domain_leakage ≤ 0.267 (no aumentar vs A=0.267; OR=0.704).
- token_cost ≤ ~2× A (OR fue ×9).

Se reporta SIEMPRE la tabla comparativa; el veredicto de adopción es decisión del
usuario, fuera del experimento.

---

## 7. Procedimiento reproducible

```bash
cd ~/buffy-context
# 1. verificar fixture congelado
cd scripts/tests/evals && sha256sum -c eval-ctx-PC-2026-08-11.json.sha256

# 2. correr el runner corregido con la nueva estrategia (3 corridas: and, or, and-norm)
./run-baseline-PC.sh --strategy and     --out baseline-A-PC-2026-08-11.json  --quiet
./run-baseline-PC.sh --strategy or      --out baseline-B-PC-2026-08-11.json  --quiet
./run-baseline-PC.sh --strategy and-norm --out baseline-C-andnorm-PC-2026-08-11.json --json

# 3. comparar (tabla A vs B vs C ya calculada por el runner o script de diff)
```

**Nota de integridad:** los JSON de A y B se REGENERAN con el runner corregido
para que la comparación sea justa (la corrección de §4 cambia search_recall). Los
artefactos originales del Paso 2/3 quedan intactos en git history; los nuevos
llevan la misma ruta + nota `instrumento v2`.

**Implementación del gate en el runner** (sin tocar runtime):
- `run_search_and_norm(q)`: llama a `buffy-search.sh -l 50` (OR en env), filtra
  hits por co-ocurrencia ≥2 leyendo la línea completa del archivo del repo
  (`repo/path`, `lineno`), conserva orden bm25, recorta a `LIMIT=10`.
- `search_recall` corregido: evaluación por path de hit (§4), no por texto
  concatenado.

---

## 8. Artefactos esperados

| artefacto | contenido |
|---|---|
| `baseline-A-PC-2026-08-11.json` (v2) | A remedido con instrumento corregido |
| `baseline-B-PC-2026-08-11.json` (v2) | B remedido con instrumento corregido |
| `baseline-C-andnorm-PC-2026-08-11.json` | and-norm (nuevo) |
| `EVAL-REGISTRY.md` | sección Paso 4 + tabla comparativa + veredicto (⛔ sin adopción aún) |
| `ai-context/CONTINUE.md` | handoff actualizado |

---

## 9. Riesgos y notas

- **Riesgo 1 — el gate ≥2 en línea puede ser demasiado estricto**: las líneas
  gold de Q06/Q08 NO comparten 2 tokens con la query (el diagnóstico lo mostró);
  and-norm probablemente NO recuperará Q06/Q08 por diseño. Esperado y aceptable:
  el objetivo es el trade-off, no igualar el recall bruto de OR.
- **Riesgo 2 — N_amplio=50 puede no bastar si OR rankea los golds bajo**: se
  reporta `cooccurrence stats` (hits antes/después) para auditar.
- **Riesgo 3 — deduplicación de tokens**: la lista de tokens significativos se
  deduplica (Q06 repite `script`). Comparación por sets.
- **Sin sorpresas en router:** `router_*` debe quedar Δ=0 (no se toca) — sirve de
  control de que la medición no se contaminó.

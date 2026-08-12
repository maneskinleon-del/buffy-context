# Paso 10B — Reranking / Passage Selection (diseño)

> Estado: **⏳ DISEÑO — pendiente de aprobación** (2026-08-12) — aún SIN runner.
> Base: EVAL con gold definitivo (hash `98a0e308…`), pasajes G1-VENTANA validados,
> serie A→H2 completa en `EVAL-REGISTRY.md`. Generación CONGELADA: pool del Paso 10
> con diccionario H2 (`baseline-H2-expansion-PC-2026-08-12.json`).
> Autorizado por el usuario (2026-08-12): \"cerrar Paso 10 como experimento no
> adoptado y diseñar Paso 10B — Reranking/Passage Selection. Sin tocar runtime.
> Sin ampliar diccionarios. Sin otro embedding. Sin aumentar presupuesto.
> Primero aislar ranking.\" Implementación pendiente de aprobación de esta spec.

## 1. Objetivo e hipótesis

**Pregunta:** ¿un reranker de pasajes que trabaja sobre candidatos YA generados (sin
recuperar documentos nuevos) logra llevar las agujas del candidate gap (rank 50-132
en H2) y el gold de Q08 al top-10 — sin disparar leakage ni regresión?

**Hipótesis central (derivada del Paso 10, el resultado más útil de la Fase 3):**

> La generación ya no es el problema: H2 demostró candidate-gap recovery 6/6 y las
> agujas están DENTRO del pool (rank 50-132). El RRF no sabe distinguir evidencia
> útil del ruido (1071-1364 ítems). El cuello de botella es el **ranking**.

```text
pool (H2, congelado): L ∪ X(H2) ∪ S, 1071-1364 ítems únicos
        ↓
    RERANKER  ← ← ← la única variable
        ↓
   top-10 → pasajes VENTANA ±4 → presupuesto 10.4k → ctx → métricas
```

**Hipótesis secundaria (la pregunta del usuario para R2):** el embedding bge-m3
falló en D como **generador** (relevance 0.192, leakage 0.669). Pero ¿funciona como
**señal de ranking subordinada** a señales léxicas más precisas? R2 responde: ¿el
embedding era malo para recuperar o simplemente necesitaba estar subordinado?

## 2. Evidencia que dimensiona el diseño (medida HOY, antes de escribir esta spec)

### 2.1 El overlap léxico query↔gold es CERO — el reranker no puede apoyarse en él

Medido sobre los ítems del pool de H2 que contienen las agujas del gap y sobre los
gold files reales:

| Query | Aguja | overlap query↔línea | overlap query↔pasaje(±4) |
|---|---|---|---|
| Q01 | adb tcpip 5555 / adb connect | ∅ | ∅ |
| Q03 | gh pr create (Commands.md:64) | ∅ | `{crear}` |
| Q03 | git push origin (Commands.md:13) | ∅ | `{commit, pull}` |
| Q05 | useState (React.md:26) | ∅ | ∅ |
| Q08 | picom (System.md:3/59/63/66/69) | ∅ | ∅ |
| Q10 | dumpsys thermalservice / thermal_control | ∅ | ∅ |

**10 de 13 agujas con señal léxica de la query = 0** (a nivel pasaje). Un reranker
basado solo en tokens de la query NO puede subir las agujas del gap.

### 2.2 La señal de EXPANSIÓN sí discrimina (la señal clave de R1)

Overlap de los **términos X del diccionario** con el pasaje del gold:

| Query | Pasaje gold | x_overlap (tokens X en el pasaje) |
|---|---|---|
| Q10 | GameOptimization.md:62/65 | **5** (`control, dumpsys, temperatura, thermal, thermalservice`) |
| Q03 | Commands.md:64 | 2 (`crear, create`) |
| Q08 | System.md:59/63 | 2 (`compositor, picom`) · System.md:3/66/69: 1 |
| Q01 | ADB.md:14/12 | 1 (`adb`) |
| Q05 | React.md:26 | 1 (`usestate`) |

La señal de expansión (términos generados de la query) es la que discrimina — es
gold-independent (se deriva de la query + diccionario, no del gold).

### 2.3 Q08: el ruido vive en archivos de sesión, el gold en Knowledge/

Los términos X de Q08 (`picom`, `opacity`) recuperan tanto `System.md` (gold) como
`ai-context/SESION-archive.md` y `CHANGELOG-archive.md` (ruido). El gold vive en
`Knowledge/` (documentación curada); el ruido en `ai-context/` (sesiones). Una señal
de **estructura del corpus** (gold-independent) distingue ambos. En H2 los hits de
Q08 fueron AGENTS.md / CHANGELOG-archive / INFO-core / SESION-archive (todos
ai-context) — System.md nunca al top-10.

### 2.4 Ranks actuales de las agujas del gap en H2 (referencia)

| Query | Aguja | rank RRF (H2) | rama | término X |
|---|---|---|---|---|
| Q10 | dumpsys thermalservice | 50 | X | thermal |
| Q10 | thermal_control | 52 | X | thermal |
| Q03 | gh pr create | 58 | X | push |
| Q01 | adb connect | 124 | X | adb devices |
| Q05 | useState | 128 | X | useState |
| Q01 | adb tcpip 5555 | 132 | X | adb devices |

## 3. Alcance (qué NO se toca)

- ❌ `buffy-search.sh`, `buffy-router.sh`, cap-selector, defaults → **runtime congelado**.
- ❌ **Generación**: el pool se congela EXACTO al de H2 (L ∪ X(H2) ∪ S, dedup,
  N_L=N_X=N_S=50, tope X 200). El reranker NO puede recuperar documentos nuevos.
- ❌ Ampliar diccionarios, otro embedding/modelo, aumentar presupuesto, tocar N_L/X/S.
- ❌ Calibración de pesos con el EVAL (TEST, no dato de adaptación).
- ❌ Integrar el reranker al runtime antes del veredicto.
- ❌ Ajustar pesos \"hasta que Q03/Q08 pasen\" — los pesos se fijan ANTES y no se tocan.

## 4. Invariantes (MISMO …)

```text
MISMO EVAL      → eval-ctx-PC-2026-08-11.json (hash 98a0e308…)
MISMO GOLD      → gold definitivo
MISMO LIMIT     → 10
MISMAS MÉTRICAS → v3.1 + passage_relevance + gold_containment + G-H0
MISMO CORPUS    → mismo índice/alcance
MISMA UNIDAD    → pasajes G1-VENTANA ±4, dedup (path, rango)
MISMO PRESUPUESTO → 10.4k tokens sobre el pasaje
MISMO POOL      → pool de H2 (congelado, referencia: baseline-H2-expansion-*.json)
```

Cambia **una sola cosa**: el **orden** del pool (RRF → reranker R1 o R2). El pool,
los pasajes, el presupuesto y las métricas quedan idénticos.

## 5. Arquitectura propuesta (el RERANKER reemplaza la fusión RRF)

### 5.1 Señales por ítem del pool (todas gold-independent, pesos fijos 1.0)

Para cada ítem `(path, lineno)` del pool congelado se computan, sobre su **pasaje
G1-VENTANA** (±4):

| Señal | Definición | Justificación (datos de §2) |
|---|---|---|
| `q_overlap` | |tokens significativos de la QUERY ∩ tokens del pasaje| **normalizado** por |tokens de la query| → [0,1] | señal léxica cruda — ~0 en las agujas del gap, sirve donde la query tiene señal (Q02/Q04/Q06) |
| `x_overlap` | |tokens de los TÉRMINOS DE EXPANSIÓN X de la query ∩ tokens del pasaje| **normalizado** por |tokens X| → [0,1] | **la señal clave** — discrimina las agujas (Q10=5/5, Q03=2/7, Q08=1-2/4) |
| `x_density` | `x_overlap_raw / |tokens del pasaje|` → [0,1] | normaliza por longitud (evita que pasajes largos ganen solo por tamaño) |
| `proximity` | 1 − (distancia del match más cercano de (tokens query ∪ tokens X) al CENTRO del pasaje / half-width) → [0,1] | el match centrado es más probablemente el hecho; se define sobre la UNIÓN query∪X (q_overlap=0 en 10/13 agujas → la señal útil viene de los tokens X) |
| `curated` | 1 si path ∈ `Knowledge/` o archivo raíz `.md/.yaml` curado; 0 si path ∈ `ai-context/` | estructura del corpus: el gold de 8/10 queries vive en Knowledge/; el ruido de Q08 vive en ai-context/ (§2.3) |
| `sem` (solo R2) | score coseno bge-m3 del ítem (0 si el ítem no viene de la rama S) — ya es ≈[0,1] | embedding SOLO como señal de ranking, no generador |

> **Normalización declarada ANTES de medir:** TODAS las señales se escalan a [0,1]
> (los conteos se dividen por su máximo posible: |tokens query| y |tokens X|;
> densidad, proximidad, curated y sem ya son 0-1). Con esto, **pesos 1.0 = igual
> contribución real** (si no se normalizara, el overlap crudo 0-8 dominaría por
> artefacto de escala y el resultado sería inatribuible). Es scaling declarado, no
> calibración: no se aprende ningún peso.
>
> **Pesos fijados ANTES de medir: 1.0 cada señal.** No se ajusta nada tras observar
> el resultado (anti-sobreajuste explícito). Se registra la contribución de cada
> señal por query en el JSON (diagnóstico, no gate).
>
> ⚠️ **Tensión declarada de `curated`:** el gold de Q04/Q06 es `ai-context/CHANGELOG.md`
> → `curated=0` para esas 2 queries (2/10 con gold en ai-context/, no en Knowledge/).
> La señal que debería ayudar a Q08 penaliza por construcción las queries que G1 ya
> resuelve — exactamente las que `baseline_regression` protege. Declarado: si R1
> hunde Q04/Q06 por `curated`, baseline_regression lo captura y el veredicto se lee
> con esa atribución (ablación por señal en el JSON).

### 5.2 Dos variantes (dos resultados independientes, mismo gate — patrón de la serie)

| Variante | Score | Responde |
|---|---|---|
| **R1-LEX** | `q_overlap + x_overlap + x_density + proximity + curated` | ¿las señales léxicas (incluida la de expansión) bastan para elegir la evidencia? |
| **R2-LEX+SEM** | R1 + `sem` | ¿el embedding sirve SUBORDINADO a señales léxicas precisas (la pregunta del usuario)? |

Ambas ordenan el pool congelado por score (desc) con tiebreak `(-score, path,
lineno)` → top-10 → pasajes → ctx. El **RRF queda fuera** (es la variable
reemplazada: fusión → selección).

> `sem=0` para ítems sin rama S: un ítem L/X compite por sus señales léxicas; en R2
> los ítems S suman su señal semántica. Declarado, no calibrado.

## 6. Presupuesto (fijado ANTES de medir)

| Parámetro | Valor | Justificación |
|---|---|---|
| Pool | el de H2 (congelado) | generación no es variable |
| `token_budget` | **10.4k** | mismo que E/F/G/H |
| LIMIT final | 10 | idéntico a la serie |
| Pasaje | G1-VENTANA ±4 | la unidad validada |

El ctx se arma igual que H2: router (archivos completos) ∪ pasajes(top-10) en orden
del reranker, presupuesto 10.4k, dedup por (path, rango).

## 7. Gate (estricto, pre-fijado ANTES de medir) — 5 criterios + baseline_regression

| Criterio | Umbral | Definición operativa |
|---|---|---|
| search_recall | **> 0.100** | v3.1, matching sobre pasaje |
| passage_relevance | **≥ 0.600** | fracción de pasajes del ctx con path ∈ gold_files |
| cross_domain_leakage | **≤ 0.267** | igualar a A |
| token_cost | **≤ ~10.4k** | sobre pasajes (comparable con G1/H) |
| gold_containment | **≥ 0.80** | el pasaje del gold cabe completo en presupuesto |
| **baseline_regression** | **≤ 0.167** (≤2 de 12 agujas) | NUEVA (pedida por el usuario): fracción de agujas `in_pool_top10` en G1 que dejan de serlo en 10B — evita el sobreajuste por la puerta trasera |

**baseline_regression** (nueva): denominador = las 12 agujas `in_pool_top10` de G1
(Q02×3, Q04×2, Q05×1, Q06×1, Q07×2, Q08×2, Q09×1); numerador = las que NO siguen
`in_pool_top10` en 10B. El Paso 10 midió 9/12 (regresión 0.25); 10B debe mejorarlo.
Se reporta además a nivel query (queries con sRec>0 en G1 que caen a 0).

> Nota Q08: sus agujas están `in_pool_top10` en archivos NO-gold (other_file_match);
> el movimiento esperado del 10B es a nivel ARCHIVO (System.md sube), que puede
> dejar la aguja en top-10 (sin "regresión" por esta métrica) a la vez que mejora el
> sRec de Q08. La lectura de Q08 es a nivel archivo/search_recall, no solo de
> continuidad de aguja.

> **Condición adicional (mantenida):** los CINCO criterios a la vez + la regresión.
> No se acepta reranker solo porque suba Q03/Q08; debe mantener lo ya ganado.

## 8. Pre-gate de candidate availability (G-H0) — adaptado

Mismo G-H0 sobre pasajes, con un desglose nuevo que mide el objetivo del paso:

**`gap_to_top10`** (métrica estrella): de las **6 agujas del gap** (Q01×2, Q03×1,
Q05×1, Q10×2 — `out_of_pool` en G1, `in_pool_ranked_out` en H2), cuántas llegan a
`in_pool_top10` en R1/R2. En H2 fue 0/6; el objetivo es subir el numerador. Reportar
por aguja con su rank final del reranker.

**Origen por aguja** (mantenido del Paso 10): rama/término que generó la aguja + su
rank en el reranker — trazabilidad completa de la cadena.

```text
Q03 | gh pr create | G1:out_of_pool → H2:ranked_out(58) → R1/R2: in_pool_top10(rank X)
```

## 9. Criterio de lectura (reportar, no bloquear)

```text
R1/R2: search_recall > 0.100 + pRel ≥ 0.600 + leakage ≤ 0.267 + tokens ≤ 10.4k
       + gold_containment ≥ 0.80 + baseline_regression ≤ 0.167  →  señal fuerte
```

- **Q03**: si `gh pr create` llega al top-10 → cadena completa
  **query expansion → candidate → reranking → passage → context** (el objetivo del
  usuario, §del Paso 10).
- **Q08**: si el pasaje de `System.md` con `picom` entra al top-10 SIN disparar
  leakage (`curated` + `x_overlap` superan el ruido de sesión) → el reranking es la
  pieza que faltaba.
- **Q10**: agujas con `x_overlap=5` — si R1 las sube fácil, confirma que la señal de
  expansión es la discriminante.
- **R1 vs R2**: si R1 falla y R2 pasa → el embedding SÍ sirve subordinado (responde
  la pregunta de §1). Si ambos fallan → la selección necesita otra señal (10C
  candidato). Se leen como curvas independientes, nunca se escoge después.
- **gap_to_top10** es el criterio de lectura principal; **baseline_regression** es
  el antídoto anti-sobreajuste (subir agujas a costa de hundir Q04/Q06 = fracaso).

## 10. NO adoptar todavía

Diagnóstico + decisión. El veredicto de adopción (y cualquier cambio al runtime) es
del usuario. Los pesos 1.0 son del experimento, no de producción. Si R1 o R2 pasan,
aún sería decisión del usuario diseñar la integración (y posiblemente re-medir los
pesos con un protocolo de calibración separado, fuera de este EVAL).

## 11. Pasos de implementación (tras aprobación de esta spec)

1. `scripts/tests/evals/run-rerank-PC.sh` — runner nuevo (hereda `run-expansion-PC.sh`):
   - pool CONGELADO de H2: mismas ramas L/X(H2)/S con los MISMOS parámetros
     (N_L=N_X=N_S=50, tope X 200, diccionario H2, dict_hash igual)
   - el runner guarda además el **score coseno** de cada ítem S (para `sem`)
   - **RERANK**: score R1 o R2 (pesos 1.0 fijos) → orden → top-10 → pasajes VENTANA
     → ctx (router ∪ pasajes, presupuesto 10.4k)
   - métricas v3.1 + passage_relevance + gold_containment + G-H0 con origen +
     `gap_to_top10` + `baseline_regression` (por aguja y por query) + contribución
     de cada señal por query
   - sin RRF (reemplazado por el reranker)
2. Verificar fixture (hash) + determinismo (2 corridas por variante) +
   verificación de que el pool congelado == pool de H2 (mismos dict_hash y params).
3. Correr R1 y R2 sobre el MISMO EVAL → comparar A→H2 vs R1/R2.
4. Reportar: agregado + por query (foco Q03/Q08/Q10) + gap_to_top10 +
   baseline_regression → decisión del usuario.

## 12. Riesgos / consideraciones

- **Riesgo 1 — sobreajuste del EVAL:** pesos 1.0 fijos antes de medir, gate completo
  de 6 criterios (incl. baseline_regression), señales gold-independent declaradas.
  Se registra la contribución de cada señal (si una señal domina sospechosamente en
  el resultado, se reporta como hallazgo, no se elimina post-hoc).
- **Riesgo 2 — `curated` es específica del corpus** (Knowledge=curado vs
  ai-context=sesión): es una señal de estructura válida y gold-independent, pero su
  poder se reporta por separado (ablation) para que el veredicto no dependa solo de
  ella. Si Q08 solo mejora por `curated`, el hallazgo se lee con esa precisión.
- **Riesgo 3 — regresión del reranker:** reordenar el pool puede hundir Q04/Q06
  (que RRF resolvía por coincidencia). `baseline_regression` lo mide y gatea.
- **Riesgo 4 — `sem` con pocos ítems S en el pool:** solo los ítems de la rama S
  tienen score; si son pocos, R2 ≈ R1. Se reporta el conteo de ítems con `sem>0`.
- **Determinismo:** señales deterministas + pool congelado → G2 reproducible
  (dict_hash y pool_hash incluidos en el determinism_hash).

## 13. Fuera de alcance (explícito)

- Generadores nuevos / ampliar diccionarios / otro embedding / aumentar presupuesto.
- Cambiar la unidad de contexto o los tamaños de rama.
- Modelos de rerank pesados (LLM/cross-encoder) — el diseño pide un reranker
  diagnóstico sencillo; si R1/R2 lo justifican, un modelo pesado sería un experimento
  NUEVO, no esta variante.
- Calibración de pesos con el EVAL.
- Integrar el reranker al runtime antes del veredicto.
- Modificar el corpus, fixture, gold o métricas (anti-gaming).

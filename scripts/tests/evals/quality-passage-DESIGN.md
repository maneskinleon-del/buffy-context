# Paso 11 — Quality-aware Passage Selection (diseño)

> Estado: **⏳ DISEÑO — pendiente de aprobación** (2026-08-12) — aún SIN runner.
> Base: EVAL con gold definitivo (hash `98a0e308…`), pasajes VENTANA ±4 validados,
> serie A→R2 completa en `EVAL-REGISTRY.md`. Ranking CONGELADO: pool del Paso 10
> con diccionario H2 (`baseline-H2-expansion-PC-2026-08-12.json`) + orden del
> reranker R1-LEX (`baseline-R1-rerank-PC-2026-08-12.json`, hash `8316343e…`).
> Autorizado por el usuario (2026-08-12): "diseñar `quality-aware passage
> selection`" como Paso 11, manteniendo EVAL/runtime/pool H2/R1-LEX/presupuesto
> congelados. Implementación pendiente de aprobación de esta spec.

---

## 1. Pregunta experimental

> **Dado que R1 ya coloca bastante de la evidencia correcta entre los candidatos,
> ¿podemos distinguir evidencia realmente útil de pasajes relacionados/ruidosos
> ANTES de construir el contexto final?**

El Paso 10B demostró que el ranking era el cuello de botella (0.367 → 0.750 con el
mismo pool). Pero R1 dejó un problema nuevo en evidencia: el contexto final tiene
**60 pasajes de los cuales solo 15 (25%) contienen la aguja** — de ahí pRel 0.175.
La pregunta del Paso 11 es si una capa de **selección/poda de pasajes** (post-ranking,
pre-contexto) puede separar la evidencia útil del ruido relacionado.

### Lo que NO ataca este paso (congelado)

| Componente | Estado |
|---|---|
| EVAL (gold `98a0e308…`) | congelado |
| Runtime (`buffy-search.sh`/`buffy-router.sh`) | congelado |
| Pool de candidatos (L ∪ X(H2) ∪ S) | congelado (dict_hash `b0406a3368003bea`) |
| Ranking (orden R1-LEX, pesos 1.0) | congelado — baseline de ranking |
| Presupuesto | 10.4k tokens (sin tocar) |
| Generación de candidatos | congelada — el selector NO recupera documentos nuevos |

**Única variable:** qué pasajes del pool ordenado por R1 entran al contexto (poda
por calidad), y en qué orden.

---

## 2. Evidencia medida HOY (2026-08-12) que dimensiona el diseño

Análisis sobre el contexto real de R1 (`baseline-R1-rerank-PC-2026-08-12.json`):
60 pasajes, 15 con aguja (25%), pRel 0.175.

### 2.1 Señales de similitud que NO discriminan gold vs noise (a nivel de pasaje)

| Señal | Con aguja (n=15) | Sin aguja (n=45) | ¿Discrimina? |
|---|---|---:|---|
| `x_hits` (términos de expansión en pasaje) | 2.47 | 1.71 | ❌ casi (invertido en Q03/Q06: el ruido tiene MÁS) |
| `q_hits` (tokens de la query en pasaje) | 0.68 | **1.89** | ❌ **INVERTIDA** — el ruido matchea más la query que el gold |
| `curated` (Knowledge/ vs ai-context/) | 91% | 100% | ❌ no separa a nivel pasaje |
| `cmds` (tokens tipo comando/símbolo) | 1.8 | **7.0** | ❌ **INVERTIDA** — el ruido tiene MÁS comandos (hipótesis refutada) |

Consecuencia de diseño: **el selector NO debe usar `q_hits` ni `cmds` como señal de
calidad** — ambas empujan hacia el ruido. La ablación del 10B ya lo anticipaba
(`r1_no_q_overlap` 5/6 > `r1_full` 4/6): los tokens crudos de la query estorban.

### 2.2 La señal que SÍ discrimina — densidad de evidencia X

`x_hits / tokens_del_pasaje`:

| Grupo | x_hits | tokens | densidad |
|---|---:|---:|---:|
| Pasajes CON aguja | 2.47 | 35 | **0.071** |
| Pasajes SIN aguja | 1.71 | 65 | 0.026 |

**2.7× más densa en evidencia.** El pasaje con aguja es más corto y concentrado
(35 vs 65 tokens): la señal de expansión X aparece junto, no dispersa en pasajes
largos de sesión.

### 2.3 Redundancia estructural — señal mecánica cuantificada

8/10 queries tienen pasajes solapados en el contexto (la ventana ±4 duplica cuando
entran ítems adyacentes del mismo archivo; Q06: README 83-91/84-92/87-95 = el mismo
pasaje 3×). **Dedup greedy por solapamiento (overlap > 4 líneas, conservar el de
mayor rank):**

- elimina **17/60 pasajes (28%)**
- recorta **15-59% de tokens** por query (Q07 59%, Q03 37%, Q04 31%)
- **sin perder ni una aguja**: Q07/Q08/Q10 1→1, Q04/Q06 0→0

### 2.4 Implicación para el diseño

La calidad de un pasaje NO es predecible por "cuánto se parece a la query" (q_hits
invertida) ni por "cuánto parece técnico" (cmds invertida), pero SÍ por dos señales
gold-independent:

1. **densidad de evidencia X** (la evidencia recuperada por el diccionario
   aparece concentrada en el pasaje correcto);
2. **no-redundancia estructural** (el pasaje aporta líneas que ningún otro pasaje ya
   seleccionado contiene).

### 2.5 Definición de densidad (corrección del review — robustez antes de medir)

`x_hits` cuenta hits por término X, y varios términos X son multi-palabra solapados
("adb devices", "adb tcpip", "adb connect" matchean la misma palabra "adb" → un
pasaje con una sola aparición contaría 3). Para que la señal mida concentración y
no inflación por familias de términos:

```text
tokens_x_distintos = |{ token_X tal que token_X ∈ pasaje }|   // familias, no hits
pasaje_tokens      = nº de tokens del pasaje (ventana ±4)
densidad_x         = tokens_x_distintos / pasaje_tokens
```

Contar **familias distintas de tokens X**, no ocurrencias por término. Declarado
antes de medir; el runner lo implementa así desde el inicio.

---

## 3. Diseño experimental

### 3.1 Pipeline (único cambio: capa de poda entre ranking y contexto)

```text
QUERY
  │
  ├── L: lexical original (gate ≥2 tokens, top-50)
  ├── X: query expansion (diccionario H2, gate ≥1, tope 200)   ← congelado
  └── S: semantic bge-m3 (top-50)
        │
        ▼
     pool dedup (path:lineno) + ranks por rama                  ← congelado
        │
        ▼
     RERANK R1-LEX (5 señales normalizadas, pesos 1.0)          ← congelado
        │
        ▼
     PODA QUALITY-AWARE (Paso 11 — LA VARIABLE)                 ← NUEVO
        │
        ▼
     pasajes VENTANA ±4 → top-N → contexto (router ∪ pasajes)
        │
        ▼
     presupuesto 10.4k → métricas v3.1
```

### 3.2 Variantes declarativas (independientes, sin elegir después)

**Q1-DEDUP — poda por no-redundancia estructural (regla geométrica, declarada):**

```text
recorrer el pool ordenado por R1 (de mayor a menor score):
    si el pasaje del ítem se solapa >4 líneas con un pasaje ya seleccionado
    del mismo archivo → descartar
    si no → seleccionar
```

**Sobre el umbral de solapamiento (>4 líneas):** no es "sin umbrales" — es un umbral
con justificación geométrica a priori. La ventana es ±4 (9 líneas, `PAS_PAD=4`); dos
pasajes que comparten **más de la mitad de sus líneas** (>4 de 9) son el mismo
contenido en esencia (un ítem en línea N y otro en N+1 generan ventanas [N−4,N+4] y
[N−3,N+5] que se solapan 8 líneas). Regla derivada de la geometría de la ventana y
del corpus (un mismo archivo con ítems adyacentes), NO de los datos del EVAL.
Riesgo declarado: dentro de un clúster redundante, el greedy conserva el ítem de
mayor rank — si ese no contiene la aguja pero uno de menor rank del mismo clúster sí,
la aguja se pierde. **Es parte de lo que el experimento mide** (lo detecta
`agujas_preservadas` por-gold-fact y `baseline_regression`).

**Q2-DEDUP+DENS — Q1 + umbral de densidad de evidencia X (fijado ANTES de medir):**

```text
Q1 + descartar pasajes con densidad_x < θ, donde

densidad_x = tokens_x_distintos / pasaje_tokens   (definición §2.5)
θ = 0.050
```

**Justificación de θ (geométrica a priori, no derivada del EVAL):** un pasaje de 9
líneas (~40-70 tokens) se considera "evidencia concentrada" si contiene ≥2 familias
de tokens X **distintas** en esa ventana → θ = 2/40 ≈ 0.05. El valor sale de la
topología de la ventana y del diccionario (2 señales de expansión coincidiendo),
NO de las distribuciones medidas (0.026/0.071). Se declara y congela antes de la
corrida; no se ajusta tras observar resultados. Si Q2 pierde agujas, el umbral era
demasiado agresivo → lo dice gold_containment/baseline_regression (no se "arregla"
el umbral).

> **R1 completo** (`baseline-R1-rerank-PC-2026-08-12.json`) y **G1** como controles:
> Q1/Q2 comparten pool, ranking y presupuesto con R1 — cualquier diferencia de
> métricas se atribuye exclusivamente a la poda.

### 3.3 Congelados

- `EVAL_HASH=98a0e308…` · `dict_hash=b0406a3368003bea` · `rerank=r1` (hash `8316343e…`)
- ventana ±4 (`PAS_PAD=4`) · presupuesto 10.4k · top-10
- instrumento v3.1 (mismas funciones de métricas que G1/H/R: `search_recall` solo
  `gold_file_match`, `passage_relevance`, `gold_containment`, `cross_domain_leakage`
  sin penalizar gold, `baseline_regression`)
- determinismo G2: 2 corridas idénticas por variante (hash de determinismo)

---

## 4. Gate (6 criterios simultáneos, pre-fijados — idénticos al 10B)

| # | Criterio | Umbral | Se protege contra |
|---|---|---|---|
| 1 | search_recall | > 0.100 | poda que elimine agujas del top-10 |
| 2 | passage_relevance | ≥ 0.600 | poda que no aumente la fracción de evidencia |
| 3 | cross_domain_leakage | ≤ 0.267 | poda que no recorte el ruido de sesión |
| 4 | token_cost | ≤ ~10.4k | poda que expanda el contexto |
| 5 | gold_containment | ≥ 0.80 | pasajes parciales que parezcan evidencia |
| 6 | baseline_regression | ≤ 0.167 (≤2/12) | agujas que G1/R1 recuperaban y la poda pierde |

**Regla de lectura (reportar, no bloquear):**
- `agujas_preservadas`: fracción de las 15 agujas del contexto R1 que sobreviven la
  poda, medida **por gold-fact** (cada aguja individual de cada query — NO max por
  query: un max enmascararía la pérdida de una aguja secundaria dentro de una query
  con varias);
- `fraccion_podada`: % de pasajes eliminados;
- `tokens_ahorrados`: % de tokens de contexto eliminados;
- `tokens_evidencia_absolutos`: tokens de pasajes con aguja que quedan en el contexto
  (valor absoluto, no fracción — ver riesgo mecánico abajo);
- `pRel_delta`: variación de passage_relevance vs R1 (0.175) y vs G1 (0.072).

**Riesgo mecánico declarado (corrección del review):** la poda elimina ruido →
`pRel = evidencia/total` sube por **encogimiento del denominador**, no por más
evidencia. El gate de pRel puede alcanzarse "gratis" por deduplicación. Por eso los
gates protectores verdaderos son sRec/gold_containment/baseline_regression + el
reporte de `tokens_evidencia_absolutos` (si la evidencia absoluta cae pero pRel
sube, la mejora es mecánica).

Si Q1 y Q2 **suben pRel y reducen leakage sin perder sRec/gold_containment** →
hipótesis confirmada (la evidencia es distinguible por calidad antes del contexto).
Si ninguna pasa el gate → la selección por estas señales no basta; la evidencia
apuntaría a que la calidad del contexto requiere señales cruzadas entre pasajes o
una definición distinta de "evidencia" (nuevo experimento, no calibración).

---

## 5. Lectura por capas (corrección aprendida del review del Paso 10)

El Paso 11 ataca EXCLUSIVAMENTE la capa de **selección de pasajes** (qué entra al
contexto final). NO toca generación (pool congelado) ni ranking (R1 congelado). Por
eso:

- si **Q1 pasa** → la redundancia estructural era la fuente principal del ruido de
  contexto (mecánica, sin umbrales — muy barata de operar);
- si **Q1 falla y Q2 pasa** → la densidad de evidencia X es la señal que faltaba;
- si **ambas fallan** → el problema no es "qué pasajes entran" sino la definición
  de evidencia/utilidad → candidato natural: co-ocurrencia cruzada entre pasajes o
  selección por cobertura de hechos (nuevo experimento).

**Advertencia explícita (no-relajación):** no se relaja ningún umbral del gate tras
ver resultados. pRel ≥ 0.600 y leakage ≤ 0.267 se mantienen aunque Q1/Q2 "mejoren"
respecto a R1 sin alcanzarlos — una mejora parcial se registra como tal y la Fase 3
sigue abierta.

---

## 6. Qué NO se hace (regla de no-tocar, acumulada de la serie)

- NO aumentar top-10 ni top-50.
- NO tocar pesos del reranker R1 (1.0 fijos, normalizados).
- NO nuevos embeddings (bge-m3 ya demostró que empeora como señal).
- NO ampliar diccionarios de expansión.
- NO aumentar presupuesto.
- NO volver a OR / RRF / archivo completo.
- NO usar `q_hits` ni `cmds` como señal de calidad (ambas invertidas).
- NO usar el gold del EVAL en ninguna señal (ni `curated` se redefine con gold:
  sigue siendo estructural Knowledge/ vs ai-context/).

---

## 7. Orden de ejecución (tras aprobación)

```text
1. implementar run-quality-PC.sh (poda Q1/Q2 sobre pool+R1 congelados)
2. validar sintaxis + smoke E2E (Q1 sobre 1-2 queries)
3. Q1 ×2 corridas → determinismo G2
4. Q2 ×2 corridas → determinismo G2
5. verificar pool == H2 y orden == R1 (congelados intactos)
6. comparar Q1/Q2 vs R1 y G1 + per-query (Q03/Q06/Q08/Q10 en foco)
7. agujas_preservadas + fraccion_podada + tokens_ahorrados + pRel_delta
8. registrar resultados en EVAL-REGISTRY.md + spec a EJECUTADO con Anexo
9. revisar con code-reviewer
10. commit + push + detenerse (runtime intacto, nada se adopta automáticamente)
```

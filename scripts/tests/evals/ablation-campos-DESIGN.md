# Experimento B — Ablación por campos del contexto BuffyContext

> Estado: **DISEÑO PRE-REGISTRADO** (2026-08-26) — variantes, invariantes, scoring,
> gates y formato de resultados fijados ANTES de medir. Nada se ajusta post-hoc.
> Pipeline acordado: **A** (evidencia previa, registrada en §2) → **B** (este documento)
> → veredicto B → **C** (selector determinista) → **D** (semantic router, SOLO si C no alcanza).

## 1. Objetivo

Responder UNA pregunta concreta:

> **¿Existe un pack reducido de campos de contexto que conserve ≥95% del rendimiento
> de Full, con cero daño de contexto?**

No se implementa todavía ningún selector (determinista ni semántico). Es un
experimento de **ablación**: aislar la variable `composición de campos del contexto`
manteniendo todo lo demás congelado.

## 2. Experimento A — evidencia previa (ya observada, NO reconstruida)

Resultado previamente observado del ciclo Full vs OFF (10 consultas, scoring LLM):

| Condición | correctness |
|---|---|
| **ON — Full BuffyContext** | **0.82** |
| **OFF — sin BuffyContext** | **0.29** |

Señales secundarias (ON vs OFF):

| Métrica | Valor |
|---|---|
| context_harm_rate | **0** (OFF nunca ganó) |
| helped_rate | **0.60** |
| rule_adherence | −0.10 (regresión secundaria) |
| hallucination | +0.10 (regresión secundaria) |

Lectura registrada: BuffyContext aporta valor neto (Δ +0.53) sin casos de daño;
el objetivo original (≥0.80 / ≤0.35) quedó superado. La meta operativa de
correctness pasa a ser **≥0.779** (= 95% de 0.82).

⚠️ **Advertencia de procedencia (importante):**

- El harness y la ejecución de A **NO están reproducibles desde este entorno**
  (Termux/Mi 10): el harness no está versionado aquí.
- Los números de A se registran **como resultado ya observado** (reportados por el
  usuario). **NO se reconstruyen los datos ni se presentan como una nueva medición.**
- La relación de comparadores queda definida en §5: **Full-A (histórico) →
  Full-B (control contemporáneo) → variantes B**. Full-B es comparador interno de
  B SOLO si hay drift (Δcontrol material); el gate histórico 0.779 (vs A=0.82)
  no cambia.

## 3. Alcance (qué NO se toca)

- ❌ Runtime (`buffy-router.sh` / `buffy-search.sh` / cap-selector) — congelado.
- ❌ Embeddings / semantic router (D queda condicionado al veredicto de C).
- ❌ Leave-one-out — queda para DESPUÉS de B, solo si hace falta afinar marginales
  ("¿cuánto aporta exactamente cada campo?"). B responde la pregunta arquitectónica
  previa: "¿existe un pack reducido que conserve prácticamente todo el beneficio?".
- ❌ Modificar prompts, modelo, scoring, corpus o harness entre variantes.
- ❌ Calibrar cualquier parámetro con resultados intermedios.

## 4. Invariantes (MISMO …)

```text
MISMAS CONSULTAS → las 10 del Experimento A (congeladas)
MISMO MODELO     → misma versión/endpoint, temperatura y config congeladas
MISMOS PROMPTS   → plantillas idénticas (solo cambia el bloque de contexto)
MISMO SCORING    → las 7 métricas, mismas rúbricas y criterios de evaluación
MISMO CORPUS     → mismo contenido fuente de los campos del snapshot
MISMO HARNESS    → mismo runner y pipeline de evaluación
```

Cambia UNA variable:

```text
composición de campos del contexto BuffyContext incluido en el prompt
```

## 5. Variantes (pre-fijadas)

| Variante | Qué responde | Rol |
|---|---|---|
| **Full** | todo BuffyContext | control (medido en A) |
| **platform+tools** | SO/plataforma + herramientas | candidato principal |
| **hardware** | hardware/recursos | ablación |
| **privileges** | permisos/capacidades | ablación |
| **tools-only** | únicamente herramientas | mínimo absoluto |

Notas operativas:

- El runner debe registrar **verbatim** qué secciones del snapshot incluye cada
  variante (nombres exactos según el harness real donde corra) y el **token count
  por variante**. La tabla de arriba es la definición funcional; el mapeo exacto
  campo↔sección se documenta en los resultados, no se decide después.
- Presupuesto: **40 llamadas** para las variantes (10 queries × 4) + **10 del
  control Full-B = 50 totales**.
- **Control de sesión Full-B — NO es una variante:** dado que A no es reproducible
  desde este entorno, se re-corre Full en la MISMA sesión de B. Su única función
  es separar dos efectos:

  ```text
  drift del harness     → Full-B ≠ Full-A (0.82)
  efecto de la ablación → variante-B ≠ Full-B
  ```

  Cadena de comparadores: **Full-A (histórico) → Full-B (control contemporáneo)
  → variantes B.**

  Reglas explícitas (congeladas):
  - La desviación A→Full-B se **reporta independientemente** y NUNCA se
    reinterpretará como efecto de la ablación.
  - Full-B sustituye a Full-A como **comparador interno de B SOLO si hay drift**.
  - **El gate histórico NO se recalcula retrospectivamente con Full-B:** el umbral
    sigue siendo **0.779**, definido respecto de A=0.82. (Evita la trampa de que
    un Full-B de, p. ej., 0.79 haga que una variante de 0.78 parezca aceptable
    por compararse contra el control equivocado.)

## 6. Métricas

Las 7 existentes, sin cambios de definición:

```text
correctness · context_adherence · action_correct · rule_adherence ·
hallucination · context_harm_rate · helped_rate
```

Más dos derivadas obligatorias:

1. **Δ vs Full POR QUERY** — el dato principal (comparación emparejada).
2. **context_tokens y % de Full** por variante — para el criterio de selección (§8).

Y un **control de validez experimental** (NO es una de las métricas principales):

3. **Δcontrol = Full-B − Full-A** — estabilidad A→B de la sesión.
   Interpretación pre-definida, SIN umbral arbitrario (no existe evidencia previa
   que justifique uno; se registra primero y se decide por magnitud y contexto):

   ```text
   Δcontrol ≈ 0          → sesión estable
   desviación pequeña    → reportar y continuar con cautela
   desviación material   → el experimento queda condicionado por drift
   ```

## 7. Formato de resultados (pre-fijado)

Por query (por cada variante):

```text
query_01: Δcorrectness  Δadherence  Δaction  Δrule  Δhallucination
query_02: ...
...
query_10: ...
```

Agregado por variante:

```text
variante        tokens  %ctx  correctness(Δ)  adherence(Δ)  action(Δ)  rule(Δ)  hallu(Δ)  harm  helped
Full            100%    100%  0.82 (—)        ...           ...       ...      ...       0     ...
platform+tools   ?%      ?%   ?.?? (±.??)     ...           ...       ...      ...       ?     ?
...
```

Regla de lectura con n=10: la media agregada NUNCA se reporta sola; siempre junto
a la distribución de Δ por query (min/max, nº de queries empeoradas). Distinguir
"pierde poco en todas" de "pierde mucho en 2 queries".

Control de sesión (se reporta PRIMERO, antes de cualquier tabla de variantes):

```text
Control    Resultado
Full-A     0.820
Full-B     X
Δcontrol   X − 0.820
```

## 8. Gate de no-regresión ≠ criterio de selección

**Gate** (condiciones necesarias, para TODAS las variantes):

| Criterio | Umbral | Justificación |
|---|---|---|
| correctness promedio | **≥ 0.779** (= 95% × 0.82) | conservar el beneficio medido en A |
| context_harm_rate | **= 0** | ningún caso nuevo de daño por contexto |

Pasar el gate NO implica ser la mejor candidata.

Reglas operacionales congeladas:

1. El gate es **conjunto** (rendimiento mínimo + harm = 0). Una variante con
   correctness ≥ 0.779 pero `harm > 0` NO pasa el gate y no puede rescatarse
   mediante interpretación cualitativa.
2. Si varias superan el gate: se selecciona **la de menor contexto que preserve
   el rendimiento**, NO la de mayor score.
3. Recordatorio (§5): el gate histórico 0.779 NO se recalcula con Full-B.

**Criterio de selección** (entre las variantes que SUPERAN el gate):

> **El mínimo contexto (menos tokens) que conserva el rendimiento.**

Una variante puede superar el gate y aun así perder contra otra más chica.
Ejemplo ilustrativo de la forma del veredicto (NO son datos):

```text
Full             100% contexto → 0.82
Platform+Tools    38% contexto → 0.80  ← candidato excelente
Tools-only        22% contexto → 0.78  ← pasa si ≥ 0.779
Hardware          31% contexto → 0.65  ← descartar
Privileges        27% contexto → 0.70  ← descartar
```

## 9. Precauciones metodológicas

- **Ablation ≠ prueba causal completa.** Puede haber interacción entre campos: una
  variante peor NO significa "estos campos no sirven", puede significar que ese
  pack rompe una combinación que sí aporta.
- **Sin ajuste post-hoc.** Los modos de fallo se distinguen ANTES de medir y cada
  uno tiene su propia lectura; ninguno se rescata con interpretación cualitativa
  posterior:

  | Caso | Lectura registrada |
  |---|---|
  | ninguna variante alcanza correctness ≥ 0.779 | beneficio distribuido → Full se mantiene (motivaría LOO antes de C) |
  | alguna alcanza ≥ 0.779 pero falla harm | el pack rinde pero daña en algún caso → descartada igual |
  | algunas pasan ambas condiciones | aplicar criterio de selección §8 (mínimo contexto, no máximo score) |

  En los tres casos el resultado se registra igual y el veredicto es del usuario.
- **Regresiones secundarias de A se conservan como señal.** Si el pack reducido
  mejora rule_adherence/hallucination respecto de Full, sería evidencia de que el
  exceso de contexto también introduce ruido. Se reporta, no se descarta.

## 10. Criterio de lectura → pipeline posterior

```text
Algún pack pasa el gate y es chico → C: selector determinista por reglas
                                     (query → dominio → campos relevantes → contexto mínimo → modelo)
Ninguna variante pasa              → Full se mantiene; LOO para estudiar marginales antes de C
C alcanza                          → recién ahí D (semantic router), como comparación
                                     Full vs Field-Router (no solo vs OFF),
                                     éxito: ≥95% correctness de Full + harm = 0 +
                                     reducción significativa de contexto
```

Este orden evita introducir embeddings "porque son técnicamente interesantes": D
existe solo si C no alcanza.

## 11. Pasos de implementación (donde viva el harness — hoy: PC)

1. Congelar y registrar versión del harness + modelo + temperatura (hash de
   plantillas de prompt si aplica).
2. Fijar el mapeo exacto sección→variante + token counts (registrar verbatim, §5).
3. Correr Full-B + las 4 variantes × 10 queries en la MISMA sesión
   (intercalar/aleatorizar el orden si el proveedor cachea).
4. Calcular y reportar Δcontrol (Full-B − Full-A) ANTES de leer las variantes (§6).
5. Calcular Δ por query + agregados; llenar las tablas del §7.
6. Registrar resultados en este documento (sección `Resultados B`) + puntero en
   `EVAL-REGISTRY.md`. Veredicto de adopción = usuario.

**Disciplina de ejecución (pre-registrada):**

- No mirar ni discutir resultados parciales de las variantes con intención de
  modificar el protocolo.
- Si aparece algo inesperado, se registra como **observación**; las reglas
  congeladas de este documento siguen gobernando el veredicto.
- A partir de la aprobación de este diseño: **ejecutar exactamente lo escrito,
  sin seguir optimizando el diseño antes de ver evidencia.**

## 12. Riesgos / consideraciones

- **Drift del harness entre A y B** — mitigación: control Full-B (§5).
- **Orden/caching del proveedor** — mitigación: intercalar variantes, temperatura fija.
- **n=10 → baja potencia estadística** — conclusiones direccionales (qué pack
  sobrevive), no estimaciones finas de efecto.
- **Clasificación:** este documento es TEST. Nada de lo aquí registrado entra en
  memoria curada ni calibra parámetros globales (θ_c, presupuesto, pesos siguen
  siendo ADAPTATION local).

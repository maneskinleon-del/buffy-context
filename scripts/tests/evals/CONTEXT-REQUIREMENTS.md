# Requisitos formales del motor de selección de contexto de Buffy

> Derivados de la serie experimental 17B→17C→17E (2026-08-14/15).
> Fuente de verdad: `EVAL-REGISTRY.md` (§17B, §17C, §17E) + JSONs de resultados.
> Este documento traduce los hallazgos experimentales en requisitos medibles
> para el motor de selección de contexto. NO implementa nada: define el
> contrato de aceptación.

---

## 0. Cadena de evidencia (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 17B | **B (DICT_H1_B):** attr 12→13/20 (Q05 rescatado), pRel 0.415→0.531, leak 0.442 invariante, contain 1.0, cero regresiones. PASS exp / NO ADOPTED | `bridge-17B-PC-2026-08-14-*.json` |
| 17C | **V1 (exclusión dura de noise):** leak 0.442→0.250 (-43%), pRel 0.415→0.584, attr 12/20, contain 1.0, cero regresiones. PASS objetivo primario / NO ADOPTED | `leak-17C-PC-2026-08-14-V1*.json` |
| 17D | **STOP metodológico / NO EVALUADO** — drift del corpus vivo entre pasos | EVAL-REGISTRY §17D |
| Fase D | **Fixture congelado** `fx-2026-08-15-001` (corpus_hash `0af49cc666d872a6`, 45 archivos / 5338 líneas / 366358 bytes), hash por contenido, barrera de mutación, reproducibilidad multi-máquina | EVAL-REGISTRY Fase D |
| 17E | **T = V1 + DICT_H1_B sobre fixture:** attr **13/20**, leak **0.307**, pRel **0.630**, contain **1.0**, cero regresiones, G2 determinista. **GATE 17E PASADO 7/7 — CANDIDATO A ADOPCIÓN** | `combine-17E-2026-08-15-{a,b,v1,T}-r{1,2}.json` |

**Estado de la serie:** 17B PASS exp / NO ADOPTED · 17C PASS primario / NO ADOPTED ·
17D STOP / NO EVALUADO · **17E PASS / CANDIDATO A ADOPCIÓN** (decisión final del
usuario pendiente).

---

## 1. Benchmark de referencia (congelado)

| Componente | Valor |
|---|---|
| EVAL | `eval-ctx-PC-2026-08-11` (eval_hash `98a0e3082d920e71…`, 10 queries Q01–Q10) |
| Corpus | Fixture `fx-2026-08-15-001` (corpus_hash `0af49cc666d872a6`, 45 archivos / 5338 líneas) |
| Modelo de embeddings | `bge-m3` (determinista, cacheado por contenido) |
| Parámetros | N_L=50, N_X=50, N_S=50, P_EXPAND_TOP_K=10, MAX_PASSAGES=400, BUDGET_TOKENS=10400, RESCUE_LOW=0.545, PAD=4, LIMIT=10 |
| Pool | L∪X∪S∪P-F2, M3 V6, selector `selector_m3.py` |
| Anti-oráculo | gold_files se usa SOLO para medir, nunca para rankear/excluir |

---

## 2. Requisitos formales (contrato de aceptación)

> Cada requisito tiene: ID, umbral medible, fuente experimental que lo justifica
> y estado actual (verificado en 17E sobre el fixture).
>
> **Tipos de afirmación (distinción explícita, regla del usuario):**
>
> | Tipo | Significado | ¿Bloquea adopción? |
> |---|---|---|
> | **Gate** | Umbral de aceptación del contrato. No negociable, no se relaja. | SÍ |
> | **Objetivo** | Valor deseable, informativo. NO es gate; no bloquea adopción. | NO |
> | **Resultado fixture** | Valor demostrado en 17E sobre el corpus congelado. | — |
> | **Requisito producción** | A validar en el port al pipeline real (corpus vivo). | SÍ (en el port) |
>
> Regla: un objetivo NUNCA se convierte en gate retrospectivamente; un resultado
> de fixture NUNCA se trata como requisito de producción sin re-validar.

### R1 — Leak de contexto (cross_domain_leakage)

**Gate:** `leak ≤ 0.308` sobre el benchmark congelado.

- **Justificación:** umbral del contrato de la serie (§17.4), nunca relajado.
- **Evidencia:** 17C-V1 lo cruzó a 0.250 (corpus vivo); 17E-T lo cruzó a **0.307**
  (fixture). Es alcanzable con la exclusión de noise de sesión en el ensamblado.
- **Resultado fixture:** 0.307 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO por T (0.307) en 17E.

### R2 — Atribución (attributed)

**Gate:** `attr ≥ 13/20` sobre el benchmark congelado.

- **Justificación:** 13/20 = mejor resultado de la serie (17B-B y 17E-T).
- **Evidencia:** 17B-B rescató Q05 (12→13); 17E-T mantuvo 13/20 sobre el fixture.
- **Resultado fixture:** 13/20 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO por T (13/20) en 17E.

### R3 — Relevancia de pasajes (passage_relevance)

**Gate:** `pRel ≥ 0.121` sobre el benchmark congelado.
**Objetivo (NO gate):** `pRel ≥ 0.500`.

- **Justificación:** 0.121 es el piso del contrato; 0.500 es un objetivo deseable
  (T lo superó con 0.630, pero no es umbral de aceptación).
- **Evidencia:** 17E-T: **0.630** (vs A=0.430, B=0.547, V1=0.520).
- **Resultado fixture:** 0.630 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO con margen amplio (0.630).

### R4 — Contención de golds (gold_containment)

**Gate:** `contain ≥ 0.80` sobre el benchmark congelado.

- **Justificación:** contrato de la serie.
- **Evidencia:** 1.0 en TODAS las configs de 17B/17C/17E.
- **Resultado fixture:** 1.0 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO (1.0).

### R5 — Sin regresión por gold

**Gate:** para cada Q ∈ {Q01…Q10}: `attr_Q(T) ≥ attr_Q(A)` (control baseline).

- **Justificación:** contrato de la serie — una mejora agregada no puede ocultar
  un daño localizado.
- **Evidencia:** 17E-T: cero regresiones vs A en los 10 golds.
- **Resultado fixture:** 0 regresiones (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO.

### R6 — Rescate de Q05 (puente léxico)

**Gate:** `attr_Q05 ≥ 1` — el pasaje con `adb devices -l` debe entrar al
contexto para la query "leer el serial del teléfono por adb".

- **Justificación:** Q05 fue el único gold rescatado por DICT_H1_B (17B) y el
  rescate sobrevive la combinación con V1 (17E).
- **Evidencia:** 17E-T: Q05 = 1 (A=0, B=1, V1=0, T=1).
- **Resultado fixture:** Q05 = 1 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO por T.

### R7 — Determinismo (G2)

**Gate:** 2 corridas de la misma config producen JSONs idénticos per-query
(`determinism_hash` idéntico, salvo `index_cache_hit`/`elapsed_seconds`).

- **Justificación:** contrato de la serie; base de la reproducibilidad.
- **Evidencia:** 17E: r1=r2 per-query en las 4 configs (8 corridas); la única
  diferencia en `a` es `index_cache_hit` (False→True), resto idéntico.
- **Resultado fixture:** G2 OK (17E).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO.

### R8 — Exclusión de noise de sesión (mecanismo V1)

**Gate:** los pasajes `is_session_noise` que no son gold NO entran al
contexto final. Los golds que viven en archivos canónicos no-noise (p.ej.
`CHANGELOG.md` para Q04/Q06) se preservan.

- **Justificación:** 17C demostró que la fuente A (noise de sesión) era el 55%
  del leak y que excluirla lo baja 0.442→0.250 sin tocar golds.
- **Evidencia:** 17E-T: leak 0.307, contain 1.0, cero regresiones.
- **Resultado fixture:** fuente A eliminada (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO por T.

### R9 — Puente léxico ES→técnico (mecanismo DICT_H1_B)

**Gate:** la expansión de query debe incluir vocabulario técnico de dominio
(Android/ADB, React) genérico y acotado, sin strings de gold_facts del EVAL
(anti-oráculo verificable: `gold_facts ∩ términos_nuevos = ∅`).

- **Justificación:** 17B demostró que el puente léxico rescata Q05 y sube pRel
  sin regresiones.
- **Evidencia:** 17E-T: Q05=1, pRel 0.630.
- **Resultado fixture:** anti-oráculo verificado (17E).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO por T.

### R10 — Presupuesto de tokens

**Gate:** `tokens_avg ≤ BUDGET_TOKENS` (10400) por query.
**Objetivo (NO gate):** `tokens_avg ≤ 600`.

- **Justificación:** el contexto final debe caber en el presupuesto; T usa ~405
  tokens promedio (17E), muy por debajo del límite. El objetivo 600 es deseable
  (T lo supera), pero NO es umbral de aceptación.
- **Evidencia:** 17E-T: tokens_avg 404.9.
- **Resultado fixture:** 404.9 (17E-T).
- **Requisito producción:** re-validar sobre corpus vivo en el port.
- **Estado:** ✅ CUMPLIDO con margen amplio.

---

## 3. Resumen de estado (17E-T sobre fixture)

| Requisito | Gate | Objetivo | 17E-T | Estado |
|---|---|---|---|---|
| R1 leak | ≤ 0.308 | — | 0.307 | ✅ |
| R2 attr | ≥ 13/20 | — | 13/20 | ✅ |
| R3 pRel | ≥ 0.121 | 0.500 | 0.630 | ✅ |
| R4 contain | ≥ 0.80 | — | 1.0 | ✅ |
| R5 sin regresión | por gold | — | 0 regresiones | ✅ |
| R6 Q05 | ≥ 1 | — | 1 | ✅ |
| R7 G2 | r1=r2 | — | idéntico | ✅ |
| R8 noise excluido | — | — | fuente A eliminada | ✅ |
| R9 puente léxico | anti-oráculo | — | verificado | ✅ |
| R10 tokens | ≤ 10400 | 600 | 404.9 | ✅ |

**Veredicto: 10/10 gates cumplidos por T = V1 + DICT_H1_B sobre el fixture
congelado.** T es CANDIDATO A ADOPCIÓN (decisión final del usuario). Los
objetivos (R3: 0.500, R10: 600) son informativos y NO bloquean adopción.

---

## 4. Pendientes y riesgos

1. **Decisión de adopción del usuario**: 17E = PASS / CANDIDATO A ADOPCIÓN. Si se
   adopta, el siguiente paso es portar V1 + DICT_H1_B al pipeline de producción
   (runtime real, no fixture) con su propio gate de regresión sobre corpus vivo.
2. **Q01 sigue en 0** en todas las configs: el pasaje con `adb tcpip 5555` /
   `adb connect` no cruza el piso. El diagnóstico 17B indica que necesita un
   puente **conceptual/relacional** (ADB discovery → transport → authorization),
   no más sinónimos léxicos. Fuera de alcance de esta spec.
3. **Fixture vs producción**: los valores absolutos son del fixture (excluye
   estado de instancia). El pipeline real incluye SESION/CONTINUE/CHANGELOG —
   la adopción debe re-validar R1–R10 sobre el corpus vivo con el mecanismo
   portado. **El fixture demuestra que el mecanismo funciona; NO demuestra que
   sea seguro incorporarlo a producción.**
4. **Cache de embedding de query** (§3.3 de 17E): infraestructura pendiente para
   que las corridas no requieran levantar el modelo cuando el componente medido
   es independiente de la inferencia.
5. **Nomenclatura**: 17D (V1+B sobre corpus vivo) quedó STOP / NO EVALUADO y NO
   debe re-ejecutarse sobre el repo vivo. 17E (V1+B sobre fixture) es el
   experimento válido de la combinación. La infraestructura de aislamiento es
   Fase D (D0–D5), no un paso 17X.

---

## 5. Cómo se verifica

```bash
# Suite de tests sin Ollama (12 checks de 17E + suite completa)
cd ~/buffy-context && ./scripts/tests/test-combine-17E.sh

# Re-ejecutar el experimento completo sobre el fixture (con Ollama para bge-m3)
cd ~/buffy-context && ./scripts/tests/evals/run-combine-17E.sh

# Análisis y veredicto
python3 scripts/tests/evals/analiza-17E.py
```

Evidencia en `scripts/tests/evals/combine-17E-2026-08-15-{a,b,v1,T}-r{1,2}.json`
(8 archivos) + `EVAL-REGISTRY.md` §17E.
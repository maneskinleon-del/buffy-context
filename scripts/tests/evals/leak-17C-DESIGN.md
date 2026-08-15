# Paso 17C — Especificación congelada: reducción del leak estructural del pool

> Fecha de congelación: 2026-08-14 · Antecede a TODO el código del experimento.
> Esta spec NO implementa nada: caracteriza causalmente el leak (17C.1), define
> la hipótesis (17C.2), las variantes (17C.3) y el gate pre-fijado (17C.4) para
> aprobación del usuario. Se ejecuta SOLO tras la aprobación.
> **Decisión del usuario: diseñar 17C ahora, NO ejecutar todavía.**

---

## 0. Cadena de evidencia que justifica este paso (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 16B | attr 12/20, **leak 0.442 = mínimo de las 4 variantes** (0.619/0.589/0.625/0.442) | `granularity-16B-PC-2026-08-14.json` |
| 17B | attr 13/20 (Q05 rescatado), **leak 0.442 IDÉNTICO en A y B** | `bridge-17B-PC-2026-08-14-*.json` |

**El leak 0.442 es invariante entre A/B y fue el mínimo de 16B → es estructural
del pool, NO del puente semántico.** El gate §17.4 exige leak ≤ 0.308; ninguna
variante de 16B/17B lo cruza. Este paso ataca el leak como frente independiente.

---

## 1. Caracterización causal del leak (17C.1) — ANTES de proponer solución

> Regla del usuario: 17C empieza con caracterización, no con solución.
> POOL → ¿qué es leak? → ¿por qué aparece? → ¿qué mecanismo lo introduce? →
> ¿qué variable puede eliminarlo sin contaminar la evaluación? → recién entonces variantes.

### 1.1 Definición de leak (del runner 17B, línea 654)

```python
leak = (len({f for f in ctx_paths if f not in gold_files
             and dom_of(f) not in gold_domains}) / len(ctx_paths))
```

- `ctx_paths` = paths ÚNICOS de los pasajes en el contexto final (top-LIMIT=10).
- `gold_files` = archivos que contienen los gold_facts de la query.
- `dom_of(f)` = `Knowledge/<dominio>/...` → `<dominio>`; todo lo demás → `"session"`.
- **Leak = pasajes en el contexto cuyo archivo NO es gold Y cuyo dominio NO está
  en gold_domains de la query.**

### 1.2 Medición por query (runner 17B, tratamiento B, pad 4)

| Query | leak paths / total paths | leak_avg | gold_domains |
|---|---|---|---|
| Q01 | 0/1 | 0.000 | Android |
| Q02 | 0/2 | 0.000 | Android |
| Q03 | 2/2 | **1.000** | Git |
| Q04 | 1/2 | 0.500 | Linux |
| Q05 | 3/4 | **0.750** | React, Android |
| Q06 | 1/3 | 0.333 | Android, Shell |
| Q07 | 1/3 | 0.333 | Android |
| Q08 | 2/3 | **0.667** | Linux |
| Q09 | 1/3 | 0.333 | Android |
| Q10 | 2/4 | 0.500 | Android |

### 1.3 Clasificación causal de los 31 paths de leak (fórmula exacta del runner)

| Fuente | paths | % | Ejemplos | Mecanismo que los introduce |
|---|---|---|---|---|
| **A: noise de sesión (S4=0)** | **17** | **55%** | `ai-context/SESION-archive.md`, `CONTINUE.md`, `SHIZUKU-RISH-BUG.md`, `LOAD_CONTEXT.md`, `CHANGELOG-archive.md`, `PROJECTS.md` | `is_session_noise()` los marca S4=0, pero **el gate S1 ≥ 0.545 los deja pasar** y el score final (s4 con peso 0.5) no los baja del top-10 cuando su s1/s2/s3 es alto |
| **B: ai-context canónico** | **6** | **19%** | `ai-context/CHANGELOG.md` (Q10 ×6) | CHANGELOG.md es canónico (NO noise — es gold de Q04/Q06), pero su `dom_of` = "session" ∉ gold_domains de Q10 (Android) → cuenta como leak |
| **C: Knowledge/ de dominio NO gold** | **5** | **16%** | `Knowledge/README.md` (dom=root, Q07 ×4), `Knowledge/Linux/Kernel.md` (dom=Linux, Q09) | Archivos Knowledge/ de dominios que no son gold_domains de la query; entran por señal semántica real (README.md es índice general) |
| **D: raíz no-Knowledge** | **3** | **10%** | `CONTRIBUTING.md` (Q03), `SKILLS_INDEX.md` (Q05 ×2) | Archivos de raíz del repo, `dom_of`="session", NO marcados como noise (no están en NOISE_FILES ni empiezan con `ai-context/`) → S4=1.0, sin penalización |

### 1.4 Por qué aparecen (mecanismo)

1. **El pool (L∪X∪S∪P-F2) incluye TODO el repo**: Knowledge/ + ai-context/ + raíz.
   Los archivos de sesión/contexto son léxica y semánticamente similares a las
   queries porque documentan exactamente esas operaciones (pushear, terminal
   transparente, serial adb, ZTE caliente…).
2. **El gate S1 ≥ 0.545 no distingue dominio**: un pasaje de SESION-archive con
   coseno alto pasa igual que uno de Knowledge/.
3. **S4 penaliza en el score final pero no excluye**: `_s4=0.0` con peso 0.5
   reduce el ranking, pero si el pasaje de noise tiene s1/s2/s3 altos, igual
   entra al top-10.
4. **`dom_of` colapsa todo lo no-Knowledge a "session"**: CHANGELOG.md (canónico,
   gold de Q04/Q06) y los archivos de raíz quedan en el mismo bucket que el
   noise de sesión → cualquier query cuyo gold_domains no incluya "session"
   los cuenta como leak.

### 1.5 Variable que puede eliminarlo SIN contaminar la evaluación

- **No se puede excluir todo "session"**: Q04 y Q06 tienen gold en
  `ai-context/CHANGELOG.md` (dom=session) → excluir session rompería 2 golds.
- **No se puede cambiar `dom_of`**: es la métrica congelada del EVAL.
- **Sí se puede**: ajustar el **ensamblado del contexto final** (qué pasa del
  pool rankeado al ctx) y/o la **penalización S4**, sin tocar pool, DICT_H1,
  router, scoring M3 ni cap-selector. Cada variante toca UN solo factor.

---

## 2. Hipótesis 17C.2 (declarada ANTES de diseñar las variantes)

> **H17C:** el leak 0.442 proviene mayoritariamente (55%) de pasajes de noise de
> sesión que pasan el gate S1 y entran al contexto final a pesar de S4. Si se
> **excluye del contexto final** (o se penaliza más fuerte en el ensamblado) a
> los pasajes `is_session_noise` que no son gold, el leak baja a ≤ 0.308 **sin**
> perder attr (los golds de Q04/Q06 viven en CHANGELOG.md, que NO es noise) ni
> regresar en prosa.

Falsable: si ninguna variante cruza leak ≤ 0.308, o cruza a costa de attr/pRel/
containment/regresiones, el frente de leak se registra como **fallo** y **no se
relaja el umbral** (regla del usuario).

---

## 3. Variantes (17C.3) — un único factor por variante

> Regla del usuario: no modificar simultáneamente DICT_H1, router, scoring,
> cap-selector ni otros componentes. Cada variante toca UN solo punto del
> ensamblado del contexto final. El pool, DICT_H1, M3, gates y métricas quedan
> IDÉNTICOS al runner 17B.

| | Control (A) | V1 | V2 | V3 |
|---|---|---|---|---|
| **Factor** | runner 17B tal cual | **Exclusión dura de noise en ctx final** | **Refuerzo S4 en el ensamblado** | **Exclusión de raíz no-Knowledge** |
| **Qué cambia** | — | Tras rankear, `ctx = [p for p in gated if not (is_session_noise(p.path) and p.path not in gold_files)][:LIMIT]` | Subir peso de S4 en el score final (p.ej. `W["s4"]: 0.5 → 1.5`) SOLO en el ensamblado del runner 17C | Tras rankear, excluir del ctx los paths con `dom_of == "session"` que NO empiecen con `ai-context/` (raíz: CONTRIBUTING, SKILLS_INDEX…) |
| **Ataca** | — | Fuente A (17 paths, 55%) | Fuente A (vía ranking) | Fuente D (3 paths, 10%) |
| **Riesgo** | — | Bajo: golds de Q04/Q06 en CHANGELOG.md (no noise) se preservan | Medio: puede bajar attr si un gold tiene s1 bajo y dependía del score | Bajo: solo 3 paths; no toca golds |
| **Contaminación** | — | Ninguna (gold_files solo para medir, no para rankear) | Ninguna | Ninguna |

> **Nota:** V1 y V3 son complementarias (A + D = 65% del leak). Si V1 sola no
> cruza, V1+V3 combinadas NO se prueban en este paso (sería 2 factores) — se
> registran por separado y se decide con evidencia. V2 es la alternativa de
> ranking (no exclusión).

### 3.1 Anti-oráculo (regla de la serie, verificable)

- Las variantes NO usan los strings exactos de gold_facts ni gold_files para
  rankear — gold_files se usa SOLO para medir (como en 17B).
- La exclusión de noise usa `is_session_noise()` (función existente, congelada)
  y `dom_of()` (métrica congelada). No se agregan reglas ad-hoc por query.

---

## 4. Gate (17C.4) — pre-fijado, comparado contra Control A del runner 17C

| # | Criterio | Umbral |
|---|---|---|
| 1 | **leak (objetivo PRIMARIO)** | **≤ 0.308** |
| 2 | attr total | ≥ 13/20 (B de 17B) — no perder lo ganado |
| 3 | sin regresión en prosa Q02/Q06/Q08/Q09 | attr por gold (V) ≥ attr por gold (A) |
| 4 | sin regresión en Q03/Q04/Q07/Q10 | attr por gold (V) ≥ attr por gold (A) |
| 5 | passage_relevance | ≥ 0.121 |
| 6 | gold_containment | ≥ 0.80 |
| 7 | determinismo G2 | 2 corridas por variante, JSONs idénticos salvo duración/cache |

**Regla de descarte (conservada):** si ninguna variante cruza leak ≤ 0.308, se
registra **fallo del frente de leak** y **NO se relaja el umbral**. El objetivo
primario es leak, NO mejorar attr a costa de leak.

---

## 5. Entregables

1. `run-leak-17C.sh` versionado (copia del mecanismo 17B + flags `--variant
   {A,V1,V2,V3}`, `--repeat 2`, JSON con hashes + determinism_hash).
2. Resultados A/V1/V2/V3 (pad 4), 2 corridas cada uno (G2), JSONs + tabla
   comparativa por gold + tabla de fuentes de leak por variante.
3. Test sin Ollama: sintaxis + parámetros congelados (PAD=4, LIMIT=10, piso
   0.545) + anti-oráculo (§3.1) + `--repeat`.
4. Veredicto en EVAL-REGISTRY + esta spec (§6) + commit separado (spec primero,
   luego runner+resultados).

## 6. Orden de ejecución (tras aprobación)

1. Congelar esta spec (commit de este archivo).
2. Implementar runner 17C + test sin Ollama.
3. Correr A (control) → debe reproducir 13/20 y leak 0.442 (sanity vs 17B).
4. Correr V1 ×2, V2 ×2, V3 ×2 (G2) → tabla vs gate.
5. Veredicto: adoptar / descartar / fallo del frente — registrado y committeado.
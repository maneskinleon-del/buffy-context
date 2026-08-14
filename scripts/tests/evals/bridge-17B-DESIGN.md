# Paso 17 — Especificación congelada: experimento del puente semántico (A/B sobre DICT_H1)

> Fecha de congelación: 2026-08-14 · Antecede a TODO el código del experimento.
> Esta spec NO implementa nada: define la hipótesis (17.2), el experimento
> controlado (17.3) y el gate pre-fijado (17.4) para aprobación del usuario.
> Se ejecuta SOLO tras la aprobación.

---

## 0. Cadena de evidencia que justifica este paso (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 15B | attr 19/20 con **oráculo H2** en la query → pasa a diagnóstico | EVAL-REGISTRY (corrección 2026-08-14) |
| 16B | attr **12/20** con H1 real, G2 verificado; granularidad DESCARTADA; ±4 conservado | `granularity-16B-PC-2026-08-14.json` |
| 17.1 | **Q01/Q05 pierden señal en S1 con golds EN el pool** | `diag-17A-REPORT.md` (commit 8a60319) |

El diagnóstico 17.1 localizó el punto exacto de pérdida (evidencia, no
hipótesis): los needles de Q01/Q05 están en el pool (containment=1.0, rama X),
pero el coseno S1 de `query natural + términos H1` vs el pasaje con el
comando/símbolo rankea **0.40–0.50 contra un piso de 0.545**. Q01: mejor pasaje
con needle = 0.4993. Q05: `adb devices -l` = 0.5449 (falla por 0.0001);
`useState` = 0.4005. La expansión H1 actual **recupera los archivos pero no
rankea el pasaje con el símbolo sobre el piso**.

---

## 1. Hipótesis 17.2 (declarada ANTES de diseñar la solución)

> **H17:** el fallo de Q01/Q05 proviene de que `DICT_H1` (expand_query.py) no
> transforma el lenguaje natural de la query en el **vocabulario técnico del
> tramo final** (lenguaje natural → concepto técnico → comando/símbolo). Si la
> expansión H1 incluye ese tramo de forma **genérica y acotada** (no oráculo),
> el S1 de los pasajes con el símbolo cruza el piso 0.545 en Q01/Q05 **sin**
> regresión en los golds de prosa ni aumento de leakage.

Falsable: si con el tratamiento B no mejora ≥1 gold de Q01/Q05 sobre el piso,
o mejora a costa de regresión/leak, la hipótesis del puente léxico queda
descartada (el siguiente candidato sería el mecanismo S1 mismo — fuera de
alcance de este paso).

### 1.1 Enunciado anti-oráculo (regla de la serie, verificable)

El tratamiento B se construye con **reglas ES→técnico genéricas**, nunca con
los strings exactos de los gold_facts del EVAL. Verificación automática en el
test sin Ollama: `gold_facts del EVAL ∩ términos_nuevos_de_B = ∅`. Si un
término nuevo es igual a un gold_fact (`adb tcpip 5555`, `adb connect`,
`useState`, `adb devices -l`, …) → el tratamiento es oráculo y se invalida.

### 1.2 Observación del fenómeno que orienta B (del diagnóstico 17.1)

```
Q01 "el teléfono no aparece en scrcpy"          Q05 "…leer el serial del teléfono por adb"
        ↓  DICT_H1 actual                           ↓  DICT_H1 actual
  list, show, device, adb devices              component, application, package,
                                                 read, get, serial, devices
        ↓  falta el tramo                           ↓  falta el tramo
  phone / device / connect / tcpip              react / hooks / state / device
        ↓                                           ↓
  gold: adb tcpip 5555, adb connect             gold: adb devices -l, useState
```

El dict actual ya tiene `aparece → adb devices`, `conectar → connect/adb
connect`, `componente → component`, `serial → serial/devices`. Falta el puente
hacia el **vocabulario técnico del dominio** que acerca el qtext al pasaje con
el símbolo (Q01: `phone`, `tcpip`; Q05: `react`, `hooks`, `state`).

---

## 2. Experimento controlado (17.3)

### 2.1 Diseño: un único A/B, una sola variable

| | Control (A) | Tratamiento (B) |
|---|---|---|
| **Variable** | `expand_query.DICT_H1` (hash `8294f200`, actual — ver nota) | `DICT_H1'` = variante acotada (§2.3, hash `f534283f`) |

> **Nota de hash (corrección):** el hash del DICT_H1 del módulo
> `expand_query.py` (solo h1) es `8294f200f0a94216` — es el que registró el
> runner 16B en el JSON (`h1_dict_hash`). `b0406a33…` era el hash del runner
> del Paso 10 con formato `{h1, h2_extra}`; NO corresponde al dict actual.
> El diagnóstico 17A repitió el b0406a33 por herencia; el JSON 16B es la
> fuente correcta: `8294f200`.
| Todo lo demás | **IDÉNTICO** | **IDÉNTICO** |

**Única variable del experimento: DICT_H1.** No se toca: EVAL
(eval-ctx-PC-2026-08-11.json), corpus (congelado bb33afa, 7644 líneas), PAS_PAD
**= 4** (baseline conservado en 16B), M3 V6 (selector_m3.py), presupuesto
(LIMIT=10, BUDGET_TOKENS, MAX_PASSAGES=400), piso rescue **0.545**, modelo
bge-m3, seeds, métricas (attr/pRel/leak/containment), mecánica de pool
(L∪X∪S∪P-F2), H1 sin oráculo, sin inyección de gold.

### 2.2 Baseline de comparación

Igual que en 16B: el baseline válido es lo que produce **el MISMO runner 17B**
con DICT_H1 actual (Control A) sobre el corpus congelado. El 12/20 de 16B sirve
como sanity (el runner 17B debe reproducirlo con A), pero la comparación formal
del gate es A-vs-B dentro del runner 17B.

### 2.3 Tratamiento B — variante acotada (propuesta para aprobación)

Ampliar `DICT_H1` con entradas ES→técnico **genéricas del dominio**, acotadas a
lo observado en 17.1 (máx ~8 entradas nuevas), cada una con su justificación:

| token_es | términos nuevos (técnicos, genéricos) | justifica el tramo de… |
|---|---|---|
| `telefono` | `phone, device, adb` | Q01 (falta hoy: no hay entrada) |
| `celular` | `phone, device, adb` | Q01 (hoy: phone, device, adb — idem, ya cubre) |
| `conecta` | `connect, adb connect` | Q01 (hoy solo `conectar`/`conecte`) |
| `tcpip` | `tcpip, adb tcpip` | Q01 (símbolo del dominio ADB) |
| `react` | `react, component, hooks` | Q05 (falta hoy) |
| `hook` | `hook, hooks, state` | Q05 (símbolo del dominio React) |
| `estado` | `state, hooks` | Q05 |
| `serial` | `serial, device, devices` | Q05 (hoy: serial, devices — agrega device) |

- Regla de construcción: solo vocabulario técnico **de dominio** (Android/ADB,
  React), documentado por entrada, sin strings de gold_facts del EVAL (check
  automático §1.1).
- Sin bolsa gigante de sinónimos: se congela la lista exacta de la tabla como
  `DICT_H1_B` y no se amplía durante el experimento (anti calibración
  post-hoc).

**Nota de decisión (para el usuario):** la tabla anterior es la propuesta
concreta de B. Si preferís otra variante (más/menos entradas, otro vocabulario),
se ajusta ANTES de congelar — nunca después de medir.

### 2.4 Runner

Nuevo runner `run-bridge-17B.sh` (NO se toca `run-granularity-PC.sh`):
- copia del mecanismo 16B (pool L∪X∪S∪P-F2, M3 V6, métricas 15B)
- `--dict <path>` para elegir DICT_H1 (A = expand_query.DICT_H1, B = DICT_H1_B)
- `--repeat 2` (G2), JSON con eval_hash/corpus_hash/dict_hash/commit_sha +
  determinism_hash (idéntico formato 16B)
- `--pads 4` fijo (la granularidad NO es variable de este paso)

---

## 3. Gate (17.4) — pre-fijado, comparado contra Control A del runner 17B

| # | Criterio | Umbral |
|---|---|---|
| 1 | mejora en **≥1 gold de Q01/Q05** (objetivo: ambos crucen el piso) | attr_Q01 + attr_Q05 (B) > attr_Q01 + attr_Q05 (A) |
| 2 | sin regresión en prosa **Q02/Q06/Q08/Q09** | attr por gold (B) ≥ attr por gold (A) |
| 3 | sin regresión en **Q03/Q04/Q07/Q10** | attr por gold (B) ≥ attr por gold (A) |
| 4 | attr total | ≥ 12/20 (A) |
| 5 | cross_domain_leakage | ≤ 0.308 |
| 6 | passage_relevance | ≥ 0.121 |
| 7 | gold_containment | ≥ 0.80 |
| 8 | determinismo G2 | 2 corridas por variante, JSONs idénticos salvo duración/cache |

**Regla de descarte (Fase 3, conservada):** si B no supera los gates 1–7 y no
produce mejora sustancial en Q01/Q05, se **descarta** (no se adopta) y se
registra el veredicto — igual que con la granularidad en 16B. El objetivo del
paso es decidir con evidencia, no forzar adopción.

---

## 4. Entregables

1. `run-bridge-17B.sh` versionado (con `--dict`, `--repeat`, JSON con hashes).
2. Resultados A y B (pads 4), 2 corridas cada uno (G2), JSONs + tabla
   comparativa por gold.
3. Test sin Ollama: sintaxis + H1/no-H2 + check anti-oráculo (§1.1) +
   parámetros congelados (PAD=4, LIMIT=10, piso 0.545) + `--repeat`.
4. Veredicto en EVAL-REGISTRY + esta spec (§5) + commit separado
   (spec primero — este archivo —, luego runner+resultados).

## 5. Orden de ejecución (tras aprobación)

1. Congelar esta spec (commit de este archivo).
2. Implementar runner 17B + test sin Ollama (34 OK esperados).
3. Correr A (control) → debe reproducir 12/20 (sanity).
4. Correr B ×2 (G2) → tabla vs gate.
5. Veredicto: adoptar / descartar / cerrar — registrado y committeado.

# Production Port Spec — V1 + DICT_H1_B al pipeline de producción

> **Estado:** SPEC CONGELADA — NO implementa nada. Define el contrato del port.
> **Origen:** 17E PASS / CANDIDATO A ADOPCIÓN (10/10 gates sobre fixture
> `fx-2026-08-15-001`). Decisión del usuario: **sí a la adopción como candidato,
> sí a diseñar el port, NO modificar el runtime hasta aprobar esta spec.**
> **Serie experimental 17B/17C/17E: CERRADA.** No se abren 17F/17G salvo que el
> port revele un problema concreto.

---

## 0. Cadena de evidencia (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 17B | B (DICT_H1_B): attr 12→13/20 (Q05), pRel 0.415→0.531, leak 0.442 invariante | `bridge-17B-PC-2026-08-14-*.json` |
| 17C | V1: leak 0.442→0.250 (-43%), pRel 0.415→0.584, attr 12/20 | `leak-17C-PC-2026-08-14-V1*.json` |
| 17E | T = V1+B sobre fixture: attr 13/20, leak 0.307, pRel 0.630, contain 1.0, G2 OK, **10/10 gates** | `combine-17E-2026-08-15-*.json` |
| Requisitos | `CONTEXT-REQUIREMENTS.md` (R1–R10, gate ≠ objetivo) | commit `bc4ebdb` |

---

## 1. Objetivo

Portar al pipeline de producción los dos mecanismos validados en 17E:

1. **DICT_H1_B** — expansión léxica ES→técnico ampliada (ranking).
2. **V1** — exclusión dura de noise de sesión en el ensamblado del contexto final.

**Única hipótesis del port:** los mecanismos que demostraron cumplir el contrato
sobre el fixture congelado lo cumplen también sobre el **corpus vivo** (que
incluye estado de instancia: SESION/CONTINUE/CHANGELOG/ai-context/*).

**Falsable:** si sobre el corpus vivo el gate de producción (§6) no se cruza, el
port se revierte (rollback §8) y se registra NO ADOPT — sin relajar umbrales.

---

## 2. Puntos exactos de integración (verificados en el código real)

### 2.1 DICT_H1_B → `scripts/lib/expand_query.py`

**Archivo a modificar:** `scripts/lib/expand_query.py` — constante `DICT_H1`
(líneas 46–107, 60 entradas).

**Cambio:** incorporar las 8 entradas nuevas de `dict_h1_b.json` (hash
`f534283f`), verificadas como la diferencia exacta:

| token_es | términos nuevos | justifica |
|---|---|---|
| `telefono` | `phone, device, adb` | Q01 |
| `conecta` | `connect, adb connect` | Q01 |
| `tcpip` | `tcpip, adb tcpip` | Q01 |
| `react` | `react, component, hooks` | Q05 |
| `hook` | `hook, hooks, state` | Q05 |
| `hooks` | `hook, hooks, state` | Q05 |
| `estado` | `state, hooks` | Q05 |
| `serial` | `serial, devices, device` | Q05 (agrega `device`) |

**Punto de integración:** la constante `DICT_H1` se lee en `expansion_terms()`
(línea 141) → `terms_hash()` (línea 156). El port reemplaza la constante por la
versión B completa (67 entradas). **No se toca la lógica de `expansion_terms()`.**

**Anti-oráculo (verificado):** `gold_facts del EVAL ∩ términos_nuevos = ∅`
(ninguna entrada nueva contiene `adb tcpip 5555`, `adb connect`, `useState`,
`adb devices -l` como strings exactos — solo vocabulario de dominio genérico).

### 2.2 V1 → `scripts/lib/selector_m3.py`

**Archivo a modificar:** `scripts/lib/selector_m3.py` — función `select()`
(líneas 253–310).

**Punto de integración:** entre el ranking (`gated.sort(...)`, línea 297) y la
selección del top-K (`gated[:top_k]`, línea 299). El runner 17C implementa V1
como (líneas 744–746 del runner):

```python
ctx = [p for p in gated
       if not (is_session_noise(p["path"]) and p["path"] not in gold_files)][:LIMIT]
```

**Problema de producción a resolver en la spec:** en el runner experimental,
`gold_files` viene del EVAL (se usa SOLO para medir — anti-oráculo). En
producción NO hay gold_files conocidos. La exclusión debe usar SOLO
`is_session_noise(p["path"])`:

```python
selected = [p for p in gated if not is_session_noise(p["path"])][:top_k]
```

**Justificación:** en el fixture, los golds de Q04/Q06 viven en `CHANGELOG.md`
que NO es noise → la exclusión por `is_session_noise` sola los preserva (17C
verificó: contain 1.0, cero regresiones). La cláusula `and p["path"] not in
gold_files` del runner es una salvaguarda de medición que en producción no
aplica (no hay golds conocidos) y su ausencia NO cambia el resultado medido
(ningún gold del EVAL es noise).

**Verificación requerida en el port:** re-correr 17E con la exclusión SIN la
cláusula gold_files y confirmar que los 10/10 gates se mantienen (debe ser
idéntico: ningún gold es noise).

### 2.3 Flujo resultante (explícito, para no mezclar componentes)

```text
                    QUERY
                      │
                      ▼
              DICT_H1_B  ←── expand_query.py (ranking)
          expansión léxica
                      │
                      ▼
                  SEARCH  ←── buffy-search.sh (NO se toca)
                      │
                      ▼
                 RANKING  ←── selector_m3.py select() (NO se toca la lógica)
                      │
                      ▼
                   GATED
                      │
                      ▼
              V1: ASSEMBLY  ←── selector_m3.py select() (NUEVO filtro post-ranking)
          elimina is_session_noise
                      │
                      ▼
                CONTEXT FINAL
```

**Componentes que NO se tocan:** router (`buffy-router.sh`), search
(`buffy-search.sh`), scoring M3 (S1/S2/S3/S4), cap-selector, `dom_of()`,
`is_session_noise()` (función existente, congelada), gates, métricas.

---

## 3. Archivos/código que pueden modificarse

| Archivo | Cambio permitido |
|---|---|
| `scripts/lib/expand_query.py` | SOLO la constante `DICT_H1` (60→67 entradas) |
| `scripts/lib/selector_m3.py` | SOLO el ensamblado final de `select()` (filtro V1 post-ranking) |
| `scripts/tests/` | Tests que verifican el port (nuevos/actualizados) |
| `EVAL-REGISTRY.md` | Registro del veredicto del port |

## 4. Invariantes que NO pueden cambiar

1. **Lógica de `expansion_terms()`** — solo cambia el dict, no la función.
2. **Scoring M3** (S1/S2/S3/S4, pesos `W`) — idéntico.
3. **Gate rescue** (`rescue_low = 0.545`) — idéntico.
4. **`is_session_noise()` y `dom_of()`** — funciones congeladas, sin reglas ad-hoc.
5. **Parámetros**: LIMIT=10, BUDGET_TOKENS=10400, MAX_PASSAGES=400, PAD=4.
6. **Anti-oráculo**: gold_files/gold_facts SOLO para medir, nunca para rankear/excluir.
7. **Umbrales del gate de producción** (§6) — no se relajan, no se crean nuevos.
8. **Sin mejoras adicionales durante el port** (§9).

---

## 5. Corpus/EVAL vivo que se utilizará

- **Corpus:** el repo vivo `~/buffy-context` (estado actual, incluye
  SESION/CONTINUE/CHANGELOG/ai-context/*). **NO se congela, NO se aísla** — el
  objetivo del port es validar sobre el estado real.
- **EVAL:** `eval-ctx-PC-2026-08-11` (eval_hash `98a0e308…`, 10 queries Q01–Q10)
  — el mismo de la serie.
- **Runner:** el mecanismo 17E (`run-combine-17E.sh` / `run-leak-17C.sh`) con
  `--fixture` DESACTIVADO (modo repo vivo) + `--variant V1` + `--dict
  dict_h1_b.json`. Esto reproduce EXACTAMENTE el mecanismo evaluado sin tocar
  el runtime.
- **Baseline de comparación:** el MISMO runner en modo repo vivo con la config
  actual (sin V1, sin DICT_H1_B) — el "antes" del port. Nunca se comparan contra
  los valores del fixture (corpus distinto).

---

## 6. Gate de producción (umbrales aprobados, NO nuevos)

> Conserva los umbrales de `CONTEXT-REQUIREMENTS.md`. Los objetivos (pRel 0.500,
> tokens 600) son informativos, NO bloquean.

| # | Criterio | Umbral |
|---|---|---|
| 1 | leak | ≤ 0.308 |
| 2 | attr total | ≥ 13/20 |
| 3 | sin regresión por gold vs baseline | attr_Q(port) ≥ attr_Q(baseline) |
| 4 | Q05 | ≥ 1 |
| 5 | pRel | ≥ 0.121 |
| 6 | contain | ≥ 0.80 |
| 7 | determinismo G2 | 2 corridas idénticas per-query |
| 8 | tokens | ≤ 10400 |

**Criterio de ADOPT:** cruza los 8 criterios Y el sanity previo (§7) pasó.
**Criterio de NO ADOPT:** falla CUALQUIER criterio → revertir (§8), registrar
NO ADOPT con causa. No se relaja el umbral.

---

## 7. Orden de ejecución (sanity → port → gate)

```text
1. Baseline repo vivo (config actual, ×2 G2)     ← "antes"
        ↓
2. Sanity del port:
   a. re-correr 17E con exclusión SIN cláusula gold_files (fixture)
      → debe mantener 10/10 gates (ningún gold es noise)
   b. suite de tests sin Ollama (12 checks 17E + suite completa)
        ↓
   si sanity falla → STOP, no se toca runtime
        ↓
3. Port: aplicar DICT_H1_B + V1 (solo los 2 archivos permitidos)
        ↓
4. Gate repo vivo (config portada, ×2 G2)        ← "después"
        ↓
5. Comparación antes/después por gold + veredicto
```

---

## 8. Rollback

- **Mecanismo:** los 2 cambios son acotados y reversibles:
  - `expand_query.py`: restaurar `DICT_H1` a las 60 entradas originales (git).
  - `selector_m3.py`: restaurar `select()` sin el filtro V1 (git).
- **Trigger:** cualquier criterio del gate §6 falla, o el sanity §7 falla, o se
  detecta una regresión no cubierta por el gate en el corpus vivo.
- **Post-rollback:** se registra NO ADOPT con causa en EVAL-REGISTRY. El runtime
  queda EXACTAMENTE como antes del port (verificado por diff de git).

---

## 9. Prohibición explícita de mejoras adicionales

Durante el port NO se permite:

- ampliar DICT_H1 con más entradas (solo las 8 congeladas de 17B);
- ajustar pesos M3, gates, piso, LIMIT, BUDGET_TOKENS;
- tocar router/search/cap-selector/memory;
- "aprovechar" el port para refactors, renombres o limpieza;
- agregar reglas ad-hoc por query.

Una hipótesis, un cambio, un gate, un veredicto.

---

## 10. Entregables

1. Esta spec congelada (commit separado, antes de todo código).
2. Baseline repo vivo (2 JSONs) + gate repo vivo (2 JSONs) + comparación por gold.
3. Sanity del port: re-corrida 17E sin cláusula gold_files (2 JSONs) + suite OK.
4. Veredicto en EVAL-REGISTRY: ADOPT / NO ADOPT con causa.
5. Si ADOPT: commit del port (2 archivos) + actualización de
   `CONTEXT-REQUIREMENTS.md` (requisitos producción → cumplidos).

---

## 11. Después del port (fuera de alcance de esta spec)

- **Prime Agent:** probar la hipótesis "¿puede Buffy ofrecer este contrato de
  Context Intelligence a un runtime RLM sin asumir nada sobre su arquitectura
  interna?" — con el contrato R1–R10 como frontera arquitectónica.
- **Q01** sigue en 0: puente conceptual/relacional (ADB discovery → transport →
  authorization), no más sinónimos. Solo si el port revela que es prioritario.
- **Cache de embedding de query** (§3.3 de 17E): infraestructura pendiente.
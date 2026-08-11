# ESPECIFICACIÓN — FASE 2: diagnóstico del router aislado (gold vs selección + señales)

> Estado: **ESPECIFICACIÓN — sin implementar**. Se revisa y aprueba ANTES de tocar
> `scripts/buffy-router.sh` o `scripts/tests/bench-realistic.sh`.
> Habilitada por la Fase 1 (independencia demostrada: search 0→0.736 con router
> intacto). Baseline v2 en `Knowledge/Tools/Benchmark-realista.md`.

## 0. Problema a explicar (único alcance)

Los agregados dicen: `router_recall ~0.225` (pierde ~77% del gold) y
`multi_domain_recall ~0.107` (14 queries multi por seed, un orden bajo el single).
Eso NO dice **por qué**. Fase 2 = diagnóstico por query, no feature:

```
QUERY → ROUTER (real) → SELECTED DOMAINS
                          vs
                         GOLD DOMAINS
```

Y para cada query: ✓ detectado / ✗ perdido / + espurio + **la señal que activó cada
selección**. Ejemplo de nivel de detalle esperado (no un simple número):

```
query:  "quiero jugar Free Fire desde el PC con scrcpy pero el teclado no responde"
gold:   Android, FreeFire, Linux, Code Search
router: Android, Linux, Node, React
resultado: ✓ Android · ✓ Linux · ✗ FreeFire · ✗ Code Search · + Node · + React
señales:  Android ← has 'adb|usb|...' → 'adb'
          Node    ← detect_node_project (package.json en el repo)
          React   ← has '...' → '...'
```

### Hipótesis de modo de fallo (A-D) que el diagnóstico debe poder distinguir

| # | Escenario | Firma observada |
|---|---|---|
| A | **Falta de señales** — la query natural no activa ningún token del router | gold ≥1 y `selected = []` |
| B | **Dominio dominante** — una señal muy fuerte gana y oculta al resto | gold ≥2 y `\|selected\| = 1` |
| C | **Señales ambiguas** — vocabulario compartido activa dominios ajenos | `spurious > 0` |
| D | **Estructural** — las multi no tienen representación que el router pueda expresar | conclusión derivada de A+B+C en las 14 multi |

El diagnóstico entrega los conteos y la clasificación; la interpretación D se
escribe en la ficha con la evidencia.

## 1. Pipeline de diagnóstico

Mismo harness de `bench-realistic.sh` (mismo sandbox, mismo corpus, mismas 60
queries, mismos seeds, mismos gates G1-G3). Único cambio: la llamada al router
lleva un modo de reporte **`--diagnose`** que NO altera la selección:

```
router(q) → categories + knowledge  (idéntico al modo --json actual)
           + signals por categoría  (domain · signal · score · reason)
```

### ⚠️ Invariante crítico (observabilidad pura, no nueva lógica de routing)

`buffy-router.sh QUERY` y `buffy-router.sh --diagnose QUERY` deben producir
**exactamente la misma selección** (`categories` y `knowledge` byte-idénticos).
`--diagnose` solo explica *por qué*: añade el campo `signals` al JSON. Se verifica
con un test dedicado (sección 5.3) y con G2-diagnose (resultados de una seed
idénticos salvo el campo nuevo).

La instrumentación vive en el router (única fuente de verdad del matching): cada
bloque de categoría, al matchear, registra la señal — la regex del `has` y el
**primer token de la query que la cumplió** (extraído con `grep -oE`), con su
**score** (nº de tokens de la regex presentes en la query). Los `detect_*`
(node/react/android/adb) registran su nombre como señal.

## 2. Salida por query (contrato JSON)

```json
{
  "id": "q_042",
  "kind": "multi",
  "gold_domains": ["android", "linux", "node"],
  "selected": ["Android", "Shell"],
  "detected": ["android"],
  "lost": ["linux", "node"],
  "spurious": ["Shell"],
  "signals": {
    "Android": {"domain": "Android", "signal": "adb", "score": 2,
                "reason": "has 'android|adb|...' → 'adb' (2 tokens)"},
    "Shell":   {"domain": "Shell",   "signal": "script", "score": 1,
                "reason": "has 'bash|zsh|...' → 'script'"}
  }
}
```

- `selected` = categorías que devolvió el router (idénticas al modo normal).
- `detected` = selected ∩ gold (en ids de dominio) · `lost` = gold − selected ·
  `spurious` = selected − gold.
- `signals` = una entrada por categoría seleccionada: **domain** (nombre de la
  categoría), **signal** (token que matcheó o nombre del detector),
  **score** (nº de tokens de la regex presentes), **reason** (regex + explicación).

## 3. Análisis agregado (3 seeds × 60 queries)

**Tabla por query** (60 por seed, consolidada en la ficha para las 14 multi de la
seed de referencia y enlazada a las demás):

| query | kind | gold | detectados | perdidos | espurios | señal dominante |
|---|---|---|---|---|---|---|
| q_037 | multi | android+linux | — | android, linux | — | (sin señal) |
| q_044 | multi | node+react | — | node, react | android, shell | adb |

**Tabla por dominio** (lost/spurious agregados sobre las 3 seeds):

| dominio | lost | spurious | señal más frecuente (ok/bad) |
|---|---|---|---|
| android | X | Y | adb (12/3) |

**Clasificación de escenarios**: conteo de queries A / B / C (y subconjunto multi)
+ ranking de señales que causaron aciertos vs fallos (spurious).

## 4. Condiciones anti-gaming

- Mismo corpus, mismas 60 queries, mismos seeds, mismos gates G1-G3.
- **Invariante de observabilidad**: `categories`/`knowledge` de un mismo seed son
  byte-idénticos con y sin `--diagnose` (test dedicado + G2-diagnose). `--diagnose`
  es instrumentación pura: no hay ramas nuevas de decisión, solo registro.
- El diagnóstico es un **reporte**, no un gate: exit 0 = corrió bien; las
  conclusiones se escriben en la ficha, no en umbrales.
- No se implementa ninguna feature de selección en esta fase.

## 5. Implementación (SOLO cuando la especificación esté aprobada)

1. `buffy-router.sh`: modo `--diagnose` (report-only, requiere `--json`): `has()`
   registra token + score del primer match (`grep -oiE` + `wc -l`), los `detect_*`
   registran su nombre, y cada bloque de categoría emite su señal vía `diag_cat`
   inmediatamente después de `CATS+=`. Verificar: salida `categories`/`knowledge`
   idéntica con y sin `--diagnose`.
2. `bench-realistic.sh`: flag `--diagnose` → pasa `--diagnose` al router y enriquece
   el JSON por query (sección 2) + agregados de la sección 3 (lost/spurious por
   dominio, clasificación A/B/C, señales ok/bad).
3. Tests (en `test-router.sh`): `--diagnose` no altera la selección (mismas
   categorías/knowledge con y sin, byte a byte), contrato JSON válido (signals con
   domain/signal/score/reason, una por categoría), `--diagnose` sin `--json` → exit 2.
4. Correr 3 seeds `--diagnose` → tablas en `Knowledge/Tools/Benchmark-realista.md`
   (§Diagnóstico router aislado) + informe `/sdcard/Download/`.
5. Escribir la **recomendación de diseño de B** (Fase 3) con la evidencia.

## 6. Fuera de alcance

- Cambios a la selección del router (categorías, knowledge, umbrales).
- Feature multi-dominio / reranking / capa de selección de candidatos.
- Cambiar el default de `BUFFY_SEARCH_STRATEGY`.
- Integrar `--quick` del benchmark a la suite principal.
- Añadir gates o umbrales automáticos sobre el diagnóstico.

## 7. Preguntas que debe responder (criterios de aceptación)

1. ¿Qué fracción del lost se explica por **ausencia de tokens-puerta** en queries
   naturales vs por tokens compartidos que se asignan mal?
2. ¿Cuáles son los **dominios más perdidos** y los **espurios recurrentes**?
3. ¿Las multi fallan por quedarse en una sola categoría dominante o por elegir
   categorías equivocadas?
4. ¿Qué señales del router son responsables de la mayoría de aciertos y de fallos?
5. Con eso: el diseño de B (Fase 3) debe nombrar explícitamente qué modos de fallo
   ataca y cómo se mediría cada uno contra esta baseline.

# Benchmark realista — baseline 3 seeds + Fase 1 (AND vs OR) (2026-08-11)

> Ficha técnica del benchmark `scripts/tests/bench-realistic.sh` (contrato:
> `scripts/tests/bench-realistic-DESIGN.md`). Documenta la línea base y la primera
> mejora medida (disiplina: benchmark → evidencia → feature → benchmark).

## Correcciones de medición (2026-08-11, antes de la Fase 1)

Tres arreglos de exactitud del benchmark, validados con determinismo y gates G1-G3:

1. **`detect_node_project`/`detect_react_project`/`detect_android_project` del router
   miraban el CWD del proceso, no el repo** — con `~/package.json` presente, TODA
   query sumaba la categoría Node espuria (rompía la suite desde `~` y contaminaba
   el router en producción). Ahora miran `$REPO_DIR`.
2. **El corpus de visión se generaba `Knowledge/Vision/Vision.md` pero el router
   hardcodea `Knowledge/Vision.md`** (layout plano, igual al repo real). El
   baseline anterior incluía ese path por un fluke CWD-relativo de `real_path`.
   Fix: `knowledge_dir: ""` en `domains.json` (generador escribe plano) +
   fallback por basename en `dom_of_file` del harness.
3. **`search_recall` se calculaba `len(recov)/len(gold)` sin intersectar con gold**
   (contaba hechos no-gold recuperados del mismo archivo: "recall 10.0" imposible).
   Ahora es `|recov ∩ gold| / |gold|` — la baseline AND no cambia (0 hits), pero
   la comparación OR es honesta.

Baseline **v2** (3 seeds re-corridas con las correcciones; manifest 20260810 =
`6701f446…`):

## Qué mide

Pipeline REAL (nada simulado): `buffy-search.sh` (FTS5, top-K=10) + `buffy-router.sh`
(`--json`) sobre un sandbox con corpus generado determinísticamente por
`fixtures-realistic/generator.py`: **500 hechos / 8 dominios** (Android 90, React 70,
Linux 60, Git 60, Node 50, Shell 70, Visión/VLM 60, Code Search 40 — los 8 dominios =
categorías reales del router) y **60 queries** (36 single / 14 multi / 6 ambiguous /
4 adversarial) con gold por construcción.

Los 8 dominios sustituyen la lista abstracta del contrato (gmail-apps/buffer-ai/
red-hogar no existen en el router): **decisión registrada como actualización del
contrato en §1.3 de `bench-realistic-DESIGN.md`**. El corpus se alinea al espacio de
selección real para que router_precision/recall sean medibles. Los archivos Knowledge
siguen las rutas hardcodeadas del router (`Knowledge/Android/ADB.md`,
`Knowledge/React/React.md`, ...).

## Medición (macro = promedio por query; micro = pooling; latency = media + p95)

| métrica | s10 | s11 | s12 | media | sd |
|---|--:|--:|--:|--:|--:|
| router_precision | 0.292 | 0.142 | 0.317 | 0.250 | 0.095 |
| router_recall | 0.240 | 0.171 | 0.264 | 0.225 | 0.048 |
| search_recall | 0.000 | 0.000 | 0.000 | **0.000** | 0.000 |
| context_relevance | 0.175 | 0.117 | 0.239 | 0.177 | 0.061 |
| cross_domain_leakage | 0.175 | 0.242 | 0.150 | **0.189** | 0.047 |
| token_cost | 402 | 430 | 512 | 448 | 57 |
| latency (mean / p95) | 714/776 | 746/— | 710/— | ~723 ms | — |
| multi_domain_precision (n=14) | 0.357 | 0.071 | 0.500 | 0.310 | 0.218 |
| multi_domain_recall (n=14) | 0.101 | 0.018 | 0.202 | 0.107 | 0.092 |

Gates: **G1 (fixtures) ✓ · G2 (determinismo: manifest byte-idéntico + resultados
idénticos salvo latencia) ✓ · G3 (mismo manifest para los 3 modos) ✓** en las 3 seeds.

## Lectura (evidencia contra la que se decidirá B)

1. **search_recall = 0.000 en las 3 seeds — explicación mecánica**: `buffy-search.sh`
   une TODOS los términos de la query con `AND` (`"w1" AND "w2" ...`); una query
   natural de 6-10 palabras nunca aparece completa en una sola línea del corpus, así
   que el top-K queda vacío aunque los hechos gold sean recuperables con una estrategia
   menos estricta (verificado a mano: 2 palabras → acierto; la query completa → 0). El
   buscador NO está explotando el vocabulario compartido que el generador garantiza
   (≥2 keywords por query). Candidato n.º 1 a revisar tras la baseline.
2. **multi-dominio — señal fuerte**: `multi_domain_recall` ~0.1 (un orden de magnitud
   por debajo del recall single ~0.22) y `multi_domain_precision` con sd 0.218 (la más
   variable). 14 queries multi en cada seed. Coherente con el problema B planteado.
3. **leakage ~19%** (sd 0.047): ~1 de cada 5 archivos de contexto es de un
   dominio ajeno al gold. El router carga contexto de señales coincidentes
   (p.ej. sub-señales "permiso"/"instalación") que no son del dominio.
4. **router_recall 0.225**: el router pierde ~77% del gold; la detección por señales
   léxicas fuertes no alcanza a queries naturales sin tokens puerta (los tokens son
   justamente lo que el corpus prohíbe).
5. **latency ~0.7-0.8s/query** (p95 hasta 1.17s): el router bash por query domina;
   relevante si el pipeline se usa interactivamente.

## Cómo reproducir

```bash
# seed completa (500/60, ~2-3 min): G1 → G2 → G3 → resultado JSON
bash scripts/tests/bench-realistic.sh --seed 20260810 --json
# CI/quick (50/12, ~25 s)
bash scripts/tests/bench-realistic.sh --quick
```

Los JSON completos de las 3 seeds (per-query + agregados) se usaron para construir
esta tabla; regenerables: mismo seed → mismos fixtures (manifest sha256
`6701f446…` para 20260810).

## Fase 1 — mejora mínima de Search: AND → OR+BM25 (medida, 2026-08-11)

Especificación: `scripts/tests/bench-realistic-FASE1-Search.md`. Cambio ÚNICO en
`buffy-search.sh` (env `BUFFY_SEARCH_STRATEGY=or`, default `and` byte-idéntico):
normalización (deacent + lowercase) → términos ≥3 chars sin stopwords → `OR` +
BM25 → top-K. Mismas 60 queries, mismos seeds, mismo runner, mismo corpus,
mismo router (0 líneas de router tocadas para medir — solo el bugfix documentado
arriba). 3 seeds × 2 estrategias:

| métrica | BASELINE (AND) | FASE 1 (OR) | Δ |
|---|--:|--:|--:|
| search_recall | 0.000 | **0.736** | **+0.736** |
| context_relevance | 0.177 | 0.505 | +0.328 |
| cross_domain_leakage | 0.189 | 0.220 | +0.031 |
| token_cost | 448 | 1973 | ×4.4 |
| latency (mean) | 723 ms | 775 ms | +52 ms |
| router_precision (control) | 0.250 | 0.250 | 0.000 |
| router_recall (control) | 0.225 | 0.225 | 0.000 |
| multi_domain_precision (control) | 0.310 | 0.310 | 0.000 |
| multi_domain_recall (control) | 0.107 | 0.107 | 0.000 |

OR por seed (search_recall): 0.692 / 0.733 / 0.783 — estable (sd 0.046).

**Lectura:**

- **La pregunta de aislamiento queda respondida**: el 0.000 de search era, en la
  práctica, todo culpa del AND absoluto. Con OR+BM25 el buscador recupera el 73.6%
  del gold (con leakage +3.1 p.p. solamente y +52 ms). FTS5 quedó exonerado.
- **Controles perfectos**: router y multi EXACTAMENTE iguales en ambas estrategias
  → el experimento no tocó la capa de selección; cualquier Δ es atribuible al Search.
- **Los dos problemas son independientes**: Search 0.000→0.736 mientras
  router_recall se queda en 0.225. Arreglar la recuperación no arregla la
  selección → **Fase 2 habilitada** (router aislado, foco 14 multi).
- El costo extra (tokens ×4.4) es la señal esperada: Search ahora trae candidatos
  y la capa de selección (Fase 2/3) debe decidir qué queda en contexto. No se
  "compensa" aquí — es el insumo de diseño de B.

## Veredicto de revisión (cierre de etapa, 2026-08-11)

## Decisión sobre el default de Search (revisión del usuario, 2026-08-11)

- **AND = baseline histórica** (default actual, sin cambios).
- **OR+BM25 = estrategia experimental VALIDADA** (search_recall 0.736, controles
  intactos) — **candidata a reemplazar AND para queries naturales**, pendiente de
  resolver/medir el coste de selección y leakage en Fase 2.
- **default NO cambia todavía**: 4.4× tokens + ~22% leakage trasladan el problema a
  "recupero demasiado y hay que decidir qué conservar" — exactamente lo que Fase 2
  debe estudiar. Tras Fase 2 se decide si `OR → reranking → contexto pequeño`
  termina siendo claramente superior.

## Qué NO hacer todavía

- No implementar la feature B multi-dominio sin la evidencia de Fase 2.
- No fijar umbrales de calidad con una sola seed (el contrato pidió 3 antes de decidir).
- No integrar `--quick` a `run-tests.sh`/README todavía — la secuencia es:
  BASELINE → MEJORA SEARCH → BENCHMARK → MEJORA ROUTER/MULTI → BENCHMARK →
  comparación → recién entonces `--quick`. Una métrica nueva e inestable no entra a la
  suite principal.
- No cambiar el default de `BUFFY_SEARCH_STRATEGY` sin la decisión post-Fase 2.

## Veredicto de revisión (cierre de etapa, 2026-08-11)

🟢 Benchmark realista: **validado** (pipeline real, nada simulado)
🟢 Baseline 3 seeds: **obtenida** (v2, con correcciones de medición)
🟢 G1/G2/G3: **3/3** en 3 seeds × 2 estrategias
🟢 Fase 1 (OR+BM25): **search_recall 0.000 → 0.736**, controles router intactos
🔴 Router: recall ~0.225 (independiente de Search — confirmado)
🔴 Multi-domain: recall ~0.107
🟠 Leakage: ~19 % (baseline) / ~22 % (con OR)
🟠 Latencia: ~723-775 ms/query

**Conclusión de la etapa:** Buffy no tiene un único problema. El benchmark demostró un
problema de **recuperación** (Search) y otro de **selección** (Router), siendo el
segundo especialmente grave en consultas multi-dominio. La Fase 1 lo **probó**: con
Search arreglado (0.736), router_recall se mantiene en 0.225 — la selección pierde
gold por sí sola. Independencia demostrada empíricamente.

Nota de interpretación sobre el 0.000: **no significa que FTS5 sea malo** — el
mecanismo es la construcción de la query (`"w1" AND "w2" AND ...`): una query natural
de 8 palabras exige que las 8 aparezcan en la misma línea indexada. El problema está
en cómo Buffy transforma la query antes de entregársela a FTS5, no en el motor.

## Próximos pasos (plan acordado — NO implementar aún)

**Fase 1 — mejora mínima de Search: ✅ IMPLEMENTADA y MEDIDA** (OR+BM25 vía
`BUFFY_SEARCH_STRATEGY=or`, default and): search_recall 0.000 → 0.736, controles
del router idénticos. Ver tabla arriba. **Decisión de default: NO cambiar todavía**
(ver §Decisión sobre el default).

**Fase 2 — router aislado: 📋 ESPECIFICACIÓN LISTA** (`bench-realistic-FASE2-Router.md`,
pendiente de aprobación para implementar): diagnóstico por query con `--diagnose`
del router (report-only, selección byte-idéntica) — gold vs selected con ✓/✗/+ y
la señal que activó cada categoría; agregados sobre 3 seeds (lost/spurious por
dominio, frecuencia de señales, modo de fallo dominante). Foco: 14 multi por seed.

**Fase 3 — diseñar B**: router actual → capa multi-dominio → candidates de dominio →
candidates de search → rerank/context selection, y comparar contra esta baseline exacta.

Lo que NO se hará primero: <s>feature B grande combinando todo</s>. Los problemas se
atacan en dos capas separadas y medibles (Search y Router), nunca como un cambio único
sin especificación.
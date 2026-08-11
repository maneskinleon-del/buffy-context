# EVAL REGISTRY — Context Selection (perfil PC)

> Registro del EVAL congelado para el pipeline `USER REQUEST → router → categoría → search → ranking`.
> Este archivo es parte de TEST (no CORE ni ADAPTATION). Nada de lo aquí registrado es
> conocimiento compartido del perfil ni entra en memoria curada.

## ⛔ Estado: CONGELADO

- **Congelado ANTES de tocar código.** No se implementó Hybrid, no se modificó
  router/search/selector.
- **Este EVAL NO podrá utilizarse posteriormente para calibrar `θ_c`, presupuesto
  ni pesos.** Es referencia de TEST, no dato de adaptación. Los parámetros de
  adaptación (`θ_c`, presupuesto, pesos) permanecen locales al perfil del
  dispositivo y nunca se convierten en conocimiento global.

## Registro

| Campo | Valor |
|---|---|
| **hash** | `8e42d119bf7bc4f2014e7239f101e3c37296365f3b24158e0cb0155baaa67f5d` |
| **fecha** | 2026-08-11 |
| **perfil** | PC |
| **host/perfil relevante** | `sabrewulf-a320ms2h` (EndeavourOS/Arch x86_64) — distinto de Mi 10/Termux |
| **número de queries** | 10 |
| **criterio de selección** | queries reales/representativas del uso de Buffy (sesiones 08-03→08-10) con cobertura: single-domain, multi-domain, sin señales léxicas, ambiguas, susceptibles de leakage; gold manual verificado contra el corpus |

## Ubicación del EVAL

- Fixture: `scripts/tests/evals/eval-ctx-PC-2026-08-11.json`
- Hash: `scripts/tests/evals/eval-ctx-PC-2026-08-11.json.sha256`
- Verificación: `cd scripts/tests/evals && sha256sum -c eval-ctx-PC-2026-08-11.json.sha256`

## Perfil y aislamiento

- Los resultados de Fase 1 y la baseline de Termux **NO son comparables** con los
  del PC. La baseline del PC (próximo paso) debe registrarse explícitamente como
  perfil PC.
- Separación mantenida:
  - CORE → router léxico, search/FTS5, comportamiento histórico (no tocado).
  - ADAPTATION — PC → perfil del PC, `.sync-state`, parámetros locales (no creado aún).
  - TEST → este EVAL + benchmark + diagnósticos.
  - RESEARCH → OR+BM25, Hybrid (no implementado).
- Nada específico del PC entró ni entrará en memoria curada (`MEMORY.md`/`USER.md`).

## Queries (resumen)

| ID | Query | Cobertura | gold_domains |
|---|---|---|---|
| Q01 | el teléfono no aparece en scrcpy | single-domain | Android |
| Q02 | cómo concedo permisos a una app con shizuku sin root | single-domain | Android |
| Q03 | quiero pushear el commit y crear el pull request | single-domain | Git |
| Q04 | la pantalla se apaga sola después de unos minutos | sin señales léxicas | Linux |
| Q05 | el componente React de la app necesita leer el serial del teléfono por adb | multi-domain | React, Android |
| Q06 | el script bash de scrcpy no abre free fire, revisá el script | multi-domain | Android, Shell |
| Q07 | el celular anda lento, qué puedo hacer | sin señales léxicas | Android |
| Q08 | la terminal se ve opaca y quiero que se vea transparente | sin señales léxicas | Linux |
| Q09 | quiero optimizar el rendimiento | ambigua | Android |
| Q10 | la ZTE se calienta cuando juego free fire | leakage | Android |

---

## ✅ Paso 2 — Baseline A (perfil PC) · 2026-08-11

Medición del pipeline **actual** (`buffy-router.sh` → `buffy-search.sh`) contra el
EVAL congelado, sobre el repo real (`~/buffy-context`), **sin tocar runtime**
(`runtime_changed: false` — no se implementó Hybrid, no se modificó
router/search/selector).

Runner: `scripts/tests/evals/run-baseline-PC.sh`
Resultado: `scripts/tests/evals/baseline-A-PC-2026-08-11.json`

| Métrica | Valor |
|---|---|
| **domain_precision_avg** | 0.667 |
| **domain_recall_avg** | 0.667 |
| **categories_recall_avg** | 0.800 |
| **search_recall_avg (FTS5, estrategia `and` default)** | 0.000 |
| **spurious_categories** | 2 (Q04, Q08 → Android espurio) |
| **search_leaked_files** | 4 (Q01) |
| **context_tokens** | 47 726 total / 4 773 avg → ventana 200k = 2.4% |

### Hallazgos de la baseline A

1. **Router sano en dominios con señal léxica** (Q01/Q02/Q03/Q05): precision y
   recall 1.0 — el pipeline actual resuelve los casos canónicos.
2. **Casos sin señales léxicas (Q04/Q08, gold Linux) → Android espurio**: el router
   activa Android por *entorno* (`detect_adb_device`: dispositivo Mi 10 conectado)
   y no hay señal Linux. Es el comportamiento real del perfil PC con el teléfono
   conectado; gold esperaba Linux.
3. **search_recall = 0.000 en las 10 queries**: con la estrategia `and` por defecto,
   el FTS5 exige que TODAS las palabras de la query natural estén en una misma
   línea indexada → no recupera ninguna aguja gold. Coincide con la conclusión de
   `bench-realistic-FASE1-Search.md` (0.000 → 0.736 con `or`), que es del track
   RESEARCH: la baseline A confirma que el runtime actual (default `and`) no
   recupera las agujas con queries en lenguaje natural.
4. **Domain gaps del router** (Q06/Q07/Q09/Q10): falta Keymappers (Q06), falta
   GameOptimization (Q07 — "lento" no es señal), ADB sobra en Q09/Q10, falta
   NubiaLab (Q10 — el router no mapea ese archivo).

> ⛔ Esta baseline es del perfil PC y NO se compara contra Termux.
> ⛔ No se usará para calibrar `θ_c`, presupuesto ni pesos (es referencia de TEST).

---

## ⏸️ Paso 3 — Baseline B (perfil PC, Search OR/BM25) · 2026-08-11 · MEDIDA, SIN VEREDICTO

Experimento controlado **A → Search OR/BM25 → mismo EVAL PC → comparar contra A**,
autorizado por el usuario. Mismo EVAL congelado, mismo gold, mismo perfil PC.
`BUFFY_SEARCH_STRATEGY=or` (variable que `buffy-search.sh` ya soporta; el default
`sigue siendo and`). **No se modificó ningún código de runtime** (`runtime_changed: false`).
**No se implementó Hybrid ni cap-selector. No se calibró nada.**

Runner: `scripts/tests/evals/run-baseline-PC.sh --strategy or`
Resultado: `scripts/tests/evals/baseline-B-PC-2026-08-11.json`
(la baseline A original `baseline-A-PC-2026-08-11.json` queda intacta)

### Comparación A (and) vs B (or) — agregado

| Métrica | A (and) | B (or) | Δ |
|---|---|---|---|
| **router_precision_avg** | 0.667 | 0.667 | 0.0 (aislado ✓) |
| **router_recall_avg** | 0.667 | 0.667 | 0.0 (aislado ✓) |
| **categories_recall_avg** | 0.800 | 0.800 | 0.0 (aislado ✓) |
| **search_recall_avg** | 0.000 | **0.250** | **+0.250** |
| **context_relevance_avg** | 0.600 | **0.192** | **−0.408** |
| **cross_domain_leakage_avg** | 0.267 | **0.704** | **+0.437** |
| spurious_categories | 2 | 2 | 0 |
| token_cost avg | 4 881 | **43 910** | **×9.0** |
| token_cost p95 | 37 726 | 68 954 | +31 228 |
| latency avg | 582 ms | 592 ms | +10 ms |
| window_utilization | 2.4% | 22.0% | +19.6 pp |

### Por query — search_recall A→B

| ID | sRec A | sRec B | Δ | cRel A→B |
|---|---|---|---|---|
| Q01 | 0.0 | 0.0 | 0 | 0.333→0.286 |
| Q02 | 0.0 | 0.0 | 0 | 1.0→0.286 |
| Q03 | 0.0 | **0.5** | +0.5 | 1.0→0.2 |
| Q04 | 0.0 | **1.0** | +1.0 | 0.0→0.0 |
| Q05 | 0.0 | 0.0 | 0 | 1.0→0.25 |
| Q06 | 0.0 | **0.5** | +0.5 | 0.667→0.2 |
| Q07 | 0.0 | 0.0 | 0 | 1.0→0.111 |
| Q08 | 0.0 | **0.5** | +0.5 | 0.0→0.125 |
| Q09 | 0.0 | 0.0 | 0 | 0.5→0.125 |
| Q10 | 0.0 | 0.0 | 0 | 0.5→0.333 |

**Mejoraron (4/10):** Q03, Q04, Q06, Q08. **Sin cambio (6/10):** Q01, Q02, Q05, Q07, Q09, Q10.

### Leakage detectado en B

OR trae al top-10 muchos archivos **no-gold**: README.md, INSTALL.md, CONTRIBUTING.md,
Knowledge/README.md, ai-context/LOAD_CONTEXT.md, ai-context/INFO-full.md,
ai-context/CONTINUE.md, archivos de sesión, y Knowledge de otros dominios
(Node.md, Vite.md, Kernel.md, HyperOS.md, Vision.md, Keymappers.md, NubiaLab.md).
`cross_domain_leakage` sube de 0.267 → 0.704.

### Lectura cruda (sin veredicto — decisión pendiente del usuario)

- OR **recupera** lo que AND no podía (search_recall 0 → 0.25, 4 queries con agujas).
- Pero **destruye** context_relevance (0.6 → 0.192) y **dispara** leakage (0.267 → 0.704)
  y token cost (×9, 22% de la ventana).
- Las métricas de router permanecen **aisladas** (Δ=0 en precision/recall/categories).
- El EVAL PC **reproduce el fenómeno** del benchmark realista (OR sube recall) pero
  con un coste de contexto/leakage que el benchmark realista no penalizaba igual.

> ⛔ **Sin veredicto todavía.** El usuario pidió ver la medición cruda y la comparación
> antes de decidir adoptar OR. No se convirtió OR en default. No se avanzó a Hybrid.

### Estado de la suite en el perfil PC (2026-08-11)

> ⚠️ **La suite del perfil PC no está actualmente 100% verde** por incompatibilidades
> de entorno/drift documental **preexistentes** (verificadas: no fueron producidas por
> la Fase 3 ni por la Baseline A):
>
> - 3 FAIL en `test-scale.sh` → usa `TMPDIR:-/data/data/com.termux/files/usr/tmp`
>   (ruta hardcodeada del perfil Termux) que no existe en el PC → el sandbox no se
>   puede crear y los 3 checks de estrategia OR fallan.
> - 2 FAIL en `test-documentation.sh` → el README declara conteos de la suite
>   (`--quick`: functional 225 / total 230) que no coinciden con la suite real
>   (222 / 226) tras cambios provenientes del perfil teléfono.
>
> Estos FAIL **NO forman parte de la medición de Baseline A** y quedan **fuera de
> alcance** de esta fase: arreglarlos ahora introduciría ruido en el experimento.
> No tocar hasta que se decida un cleanup de portabilidad del perfil PC, con su
> propia justificación.


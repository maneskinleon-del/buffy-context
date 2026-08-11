# ESPECIFICACIÓN — FASE 3: capa de selección híbrida (router léxico + evidencia de candidatos)

> Estado: **APROBADA POR EL USUARIO (2026-08-11) con modificación menor incorporada**
> (δ operacional fijado antes de medir en G-R1/G-R2 + regla de descarte §4.4).
> **PENDIENTE: implementación — congelar EVAL set, recongelar baseline, V1, A/B/C/D,
> barrido presupuesto, DEV, EVAL, decisión (plan §8). NO implementar la capa híbrida
> como CORE hasta el veredicto; Hybrid es RESEARCH hasta entonces.**
> v2 incluye además las reglas de arquitectura del proyecto (§11): clasificación
> CORE/ADAPTATION/TEST/RESEARCH y aislamiento dispositivo↔usuario (recomendación
> del usuario, 2026-08-11).
> Habilitada por el diagnóstico de Fase 2 (2026-08-11, `--diagnose` del router,
> observabilidad pura): evidencia por query + agregados sobre 14 multi × 3 seeds.
> Datos de origen: `/sdcard/Download/diagnostico-router-fase2.txt` + tablas de
> `Knowledge/Tools/Benchmark-realista.md` (Fase 1 y baseline v2).
> Concepto aprobado por el usuario (2026-08-11): router léxico + evidencia de
> Search → selector híbrido. Los ajustes v2: gates de regresión + targets,
> regla de promoción de evidencia, definición operacional de "degradar", separación
> dev/eval externa, medición por componente (A/B/C/D), y reglas de arquitectura
> (§11: clasificación CORE/ADAPTATION/TEST/RESEARCH + aislamiento dispositivo↔usuario).

## 0. Problema que esta fase debe resolver (evidencia de Fase 2)

El diagnóstico aisló **dos problemas distintos** (no uno):

```
ROUTER
   │
   ├─ SIN SEÑALES (55% = 23/42 multi): la query no activa ninguna regex
   │     → selected = [] aunque gold ≥ 1   (escenario A)
   │
   └─ CON SEÑALES (45% = 19/42): selección parcial (gold≥2, |selected|=1,
        17/42 = escenario B) + espurios ocasionales (6/42 = escenario C,
        solo C puro: q_044 seed 20260810)
```

Números agregados (42 queries multi, 3 seeds):

| dominio | gold | detectado | lost | spurious |
|---|--:|--:|--:|--:|
| android | 25 | 10 | 15 | 4 |
| linux | 20 | 2 | 18 | 2 |
| react | 22 | 0 | 22 | 0 |
| node | 14 | 1 | 13 | 0 |
| shell | 19 | 1 | 18 | 1 |
| code-search | 13 | 0 | 13 | 0 |
| git | 6 | 0 | 6 | 0 |
| vision | 4 | 0 | 4 | 0 |

Señales: `rom`→android 9 ok / 4 bad · `módulo`→linux 1 ok / 2 bad ·
`script`→shell 0 ok / 1 bad · `telefono`/`dependencia`/`arch`/`scripts` 1 ok cada una.

**Hallazgo que condiciona el diseño (B no es "exclusividad"):** los bloques de
categoría del router son `if` independientes — cuando hay señales de 2 dominios el
router SÍ selecciona 2 (20260812 q_041: `linux+node` ← módulo+dependencia). El
escenario B observado (selected=1 con gold≥2) es casi siempre **A parcial**: una
señal presente + las demás categorías gold SIN señal. No hay competición entre
bloques que corregir; hay dominios que nunca reciben evidencia léxica.

**Dato de diseño decisivo:** `react 0/22`, `code-search 0/13`, `git 0/6`,
`vision 0/4` — cero detecciones, no recall bajo. El vocabulario del generator es
genérico de propósito (ventanas, formulario, paquete, arranque, error…). El gold
del corpus SÍ está señalizado en el contenido (≥2 keywords por hecho, por diseño
del generator) y Search ya lo recupera: **search_recall 0.736**. La información
para seleccionar dominios EXISTE en los candidatos que Search devuelve; el router
léxico no la ve.

## 1. Hipótesis derivadas de los datos

| # | Hipótesis | Evidencia que la apoya | Comprobable en Fase 3 por |
|---|---|---|---|
| H1 | La pérdida de recall del router se debe a **ausencia de señales léxicas**, no a errores de asignación | A = 55% con selected=[]; 0 detecciones en 4 de 8 dominios | lost/spurious por dominio antes/después |
| H2 | Los dominios gold son **recuperables por evidencia de candidatos** (Search ya los encuentra) | search_recall 0.736; el corpus garantiza keywords por hecho; los archivos candidatos pertenecen a dominios (mapeo `dom_of_file` del harness) | recall del pipeline híbrido vs recall del router léxico solo |
| H3 | La composición multi-domain se resuelve **agregando dominios por evidencia**, no compitiendo entre categorías | El router ya selecciona 2 dominios si ambos tienen señal; B ≈ A parcial | |selected| medio en multi antes/después |
| H4 | Las señales ambiguas (rom, módulo) no hay que eliminarlas sino **condicionarlas a evidencia** | rom 9 ok > 4 bad; los espurios cargan conocimiento de un dominio que Search no respalda con candidatos | espurios por señal antes/después (modo --diagnose) |

**Hipótesis nula a descartar:** "el problema es el vocabulario del benchmark y no
existe mejora posible sin sobreajustar" → se descarta si H2 mejora las métricas
también en el **set de validación externo** (sección 5).

**Hipótesis adicional de atribución (nueva en v2):** el valor del pipeline puede
venir casi todo de la evidencia de candidatos (candidate-only). La medición por
componente (sección 8) decide si la complejidad completa (degradación + presupuesto
+ unión) es necesaria o si basta una variante más simple.

## 2. Alternativas de diseño (por problema)

### A — "sin señales" (55%)

- **A1. Más regex / palabras clave** → DESCARTADO: agregar "ventanas", "formulario",
  "paquete"… es overfitting al vocabulario del generator (prohibido, sección 5).
  Además no generaliza a las queries reales (la evidencia de Fase 1/2 muestra que el
  corpus prohíbe tokens artificiales justamente para evitarlo).
- **A2. Fallback acotado**: si ninguna señal activa, cargar contexto de los
  candidatos top-K de Search (recuperación por defecto con tope de tokens).
  Simple, pero carga sin discriminar → riesgo de leakage alto si no hay filtro.
- **A3. Segunda capa de inferencia léxica**: señales indirectas cuidadosamente
  definidas (sin usar palabras del generator) — p.ej. plantillas de dominio
  ("componente", "ejecutar", "despliegue" → react/node). Riesgo: resolver el
  problema con más heurísticas ad-hoc sin evidencia de que sean las correctas.
- **A4. Selección por evidencia de candidatos**: los dominios de los archivos que
  Search recupera (el mapeo path→dominio ya existe en el harness y en el repo real
  por `Knowledge/<Dominio>/`) votan categorías; el router léxico actúa como capa de
  precisión sobre ese voto.

**Recomendación: A4 como mecanismo base + A2 como caso degenerado de A4** (cuando
no hay señales, los candidatos de Search son la única evidencia disponible; cuando
los hay, ambas se combinan — ver B/C).

### B — composición multi-domain (40%, en realidad A parcial)

- **B1. "Hacer que el router sea multi":** darle capacidad de devolver varias
  categorías por defecto → ya la tiene (bloques `if` independientes); no ataca la
  causa (falta de señales para los dominios no detectados).
- **B2. Supresión por prioridad** (rankear categorías y cortar) → NO: empeora B
  (el router ya elige poco; cortar no agrega dominios) y arriesga romper aciertos.
- **B3. Agregación de dominios por evidencia** (con regla de promoción definida,
  §3.1): la capa de selección final toma la unión {categorías por señal léxica} ∪
  {categorías respaldadas por candidatos de Search}, **cada dominio promovido pasa
  por la regla de promoción** — no es sumar dominios sin criterio (ajuste v2, §3.1).

**Recomendación: B3 con regla de promoción explícita.**

### C — señales ambiguas (rom, módulo)

- **C1. Eliminar tokens problemáticos** → DESCARTADO: rom acierta 9 veces; eliminarla
  destruye 9 detecciones para arreglar 4 espurios.
- **C2. Ponderar señales** (peso por señal) → prohibido calibrar con el benchmark
  (overfitting, sección 5); pesos declarativos arbitrarios no resuelven nada por sí.
- **C3. Condicionar la señal a evidencia**: una categoría activada por señal léxica
  solo produce contexto si hay candidatos de Search del mismo dominio; si no,
  **se degrada** con comportamiento operacional definido (§3.2).

**Recomendación: C3** — en el mismo mecanismo que A4/B3 (una sola regla:
*para cargar conocimiento de un dominio hacen falta señales léxicas Y/O evidencia
de candidatos; la señal léxica sin evidencia degrada, no carga — salvo en modo
léxico histórico o fallback sin evidencia de Search*).

## 3. Propuesta: capa de selección híbrida `hybrid`

```
QUERY
  ↓
ROUTER LÉXICO (actual, intacto)  →  categorías con señal (modo --diagnose: token+score)
  ↓                                + reporte de señales por categoría
SEARCH OR+BM25 (candidato)       →  top-K paths
  ↓
cap SELECTOR (nuevo):
  1. votes por dominio de los candidatos top-K (path → Knowledge/<dominio>)
  2. score normalizado por dominio (§3.1)
  3. promoción: dominios que superan el umbral (§3.1)
  4. unión con categorías léxicas, con degradación de las sin evidencia (§3.2)
  5. presupuesto de contexto (parámetro del experimento, §6)
  6. salida: categorías + knowledge + signals (estructura JSON actual extendida)
```

### 3.1 Regla de promoción de evidencia de candidatos (ajuste v2 — no basta "unión")

La evidencia de Search se convierte en dominio candidato así:

```
candidate evidence:
  por cada path del top-K → dominio (mapeo path → Knowledge/<dominio>)
score_d = |candidatos del dominio d| / top-K        (fracción normalizada 0..1)
promoción: score_d ≥ θ_c    (θ_c = umbral de promoción, parámetro declarativo)
```

- **V1 (valores por defecto declarados, NO calibrados):** `top-K = 10`,
  `θ_c = 0.2` (≥ 2 de 10 candidatos de un mismo dominio). Estos valores son
  parámetros de experimento, no verdades: se corren también con θ_c = 0.3/0.5
  y se reporta la sensibilidad.
- **Calibración de θ_c y presupuesto permitida SOLO en el dev set externo**
  (sección 5), jamás con el benchmark ni con el eval set.
- **Qué se promueve:** el dominio d entra como categoría seleccionada Y sus
  archivos candidatos entran al contexto (en orden BM25, sujetos al presupuesto).
- **Qué NO se promueve:** un dominio con score_d < θ_c ni un candidato huérfano
  (path sin dominio mapeable). Los candidatos de dominios no promovidos no entran
  al contexto.
- **Rol de la señal léxica en la promoción:** una señal léxica del dominio d
  compatible con evidencia de d **refuerza** a d (suma su voto simbólico al score
  → reduce la probabilidad de que d caiga bajo el umbral); una señal léxica SIN
  evidencia compatible no promueve nada (§3.2).
- **Caso degenerado A2:** si el top-K no tiene ningún dominio mapeable (o Search
  devuelve vacío), la capa cae al comportamiento léxico histórico acotado por
  presupuesto — la señal léxica conserva su rol actual (único caso en el que una
  señal léxica carga conocimiento sin evidencia de Search).

### 3.2 Definición operacional de "degradar" (ajuste v2)

Estado observable de cada categoría en la salida de `--diagnose` (campo
`status` en signals): `promoted` (evidencia de candidatos), `lexical` (señal
léxica con conocimiento cargado) o `degraded`.

**Comportamiento de una señal léxica sin evidencia compatible de candidatos:**

| # | Situación | Comportamiento en modo `hybrid` | Modo `lexical` (histórico) |
|---|---|---|---|
| 1 | Señal léxica + evidencia de candidatos del mismo dominio | promueve: categoría + conocimiento | idéntico a hoy |
| 2 | Señal léxica SIN evidencia de candidatos, pero el top-K SÍ tiene dominios mapeables (otro dominio) | **degraded**: la categoría se reporta en signals con `status: degraded`, NO carga conocimiento; no introduce dominios adicionales | idéntico a hoy |
| 3 | Señal léxica SIN evidencia de candidatos y top-K sin dominios mapeables (o vacío) | fallback A2: la señal carga como hoy, acotada por presupuesto (status: lexical) | idéntico a hoy |
| 4 | Sin señales léxicas, solo evidencia de candidatos | promoción por §3.1 (status: promoted) | idéntico a hoy (selected=[]) |

Regla conceptual (preservando el histórico): **una señal léxica puede conservarse
como evidencia, pero no debe por sí sola introducir un dominio adicional cuando
Search proporciona evidencia compatible de otros dominios — salvo que el modo
léxico histórico esté activo** (`BUFFY_SELECTOR=lexical`, byte-idéntico al actual).

Nota: el caso 2 (degraded) NO cambia la selección del router léxico en sí — el
router reporta su categoría como siempre; la capa híbrida es quien decide qué se
convierte en contexto. El `--diagnose` del router sigue intacto e invariante.

### 3.3 Por qué esta propuesta

- Ataca la causa medida (A=sin señales, 55%) con la evidencia que YA existe en el
  pipeline (search 0.736), sin inventar semántica léxica nueva (anti-A1/A3).
- Agrega dominios (B3) en vez de competir: react/code-search/git/vision dejan de
  ser 0/22, 0/13, 0/6, 0/4 si sus hechos gold aparecen en los candidatos.
- Corrige espurios (C3) sin borrar señales útiles (rom 9>4).
- Es observable de punta a punta: cada dominio final tiene su señal y su status
  (promoted/lexical/degraded) — se extiende el contrato `--diagnose` (no se toca
  su invariante: la selección del router léxico sigue siendo byte-idéntica).
- **No es** embeddings, ni VLM, ni semántica sobre el texto de la query; es
  selección de contexto por evidencia disponible.

## 4. Gates y objetivos (ajuste v2 — regresión dura + targets aspiracionales)

### 4.1 Gates duros (regresión, no valores mágicos)

El modo `hybrid` NO puede ser peor que el modo `lexical` (control) en:

| Gate | Definición operativa |
|---|---|
| G-R1 router_precision | `router_precision_hybrid ≥ router_precision_lexical − δ_p` (macro de 3 seeds, misma definición que baseline). **δ_p se fija ANTES de evaluar variantes**: δ_p = max(sd entre seeds del modo lexical en la corrida A, 0.05); el valor se registra al completar A y se anota en el informe como parte del protocolo. Prohibido elegir δ tras ver B/C/D. |
| G-R2 context_relevance | `context_relevance_hybrid ≥ context_relevance_lexical − δ_r`, con **δ_r = max(sd entre seeds del modo lexical en A, 0.05)**, misma regla de fijación previa e idéntica restricción anti post-hoc. |
| G-R3 cross_domain_leakage | ≤ leakage(OR solo) + 0.05 (= 0.220 + 0.05); el híbrido promueve dominios con evidencia, nunca debe filtrar más que recuperar todo sin seleccionar |
| G-R4 token_cost | respeta el presupuesto CONFIGURADO (§6): si el experimento se corre con presupuesto P, el coste medio observado ≤ P |
| G-R5 invariantes | router léxico byte-idéntico con/sin `--diagnose` (42/42); determinismo del híbrido (G2); G1-G3 en los 4 modos |
| G-R6 suite | tests del repo verdes con defaults (`and` + `lexical`) |

PASS/FAIL es mecánico: se comparan las medias macro de 3 seeds contra el valor de
lexical menos δ fijo, sin interpretación humana posterior. Si algún G-R falla en
las 3 seeds, la fase se detiene y se revisa el diseño — no se bajan los gates.

### 4.2 Objetivos aspiracionales (targets — lectura, no gates)

| target | baseline v2 | OR (Fase 1) | aspiración |
|---|--:|--:|--:|
| search_recall | 0.000 | 0.736 | ≥ 0.70 (no degradar) |
| router_recall | 0.225 | 0.225 | ≈ 0.50 (mejorar sustancialmente) |
| router_precision | 0.250 | 0.250 | ≈ 0.50 |
| multi_domain_recall | 0.107 | 0.107 | ≈ 0.50 |
| multi_domain_precision | 0.310 | 0.310 | ≈ 0.50 |
| cross_domain_leakage | 0.189 | 0.220 | ≤ 0.25 |
| token_cost | 448 | 1973 | ≤ 900 (~2× baseline, ver §6) |
| latencia | 723 ms | 775 ms | ≤ 2.000 ms |

Los targets 0.50 / 900 son **aspiraciones razonables derivadas de la evidencia**
(≈2× el recall actual; ≈2× el coste de la baseline), NO condiciones de aprobación
automática. La aprobación se decide por: gates de regresión cumplidos + mejora
sustancial de recall/multi + dominios 0/22, 0/13, 0/6, 0/4 pasando a > 0 +
evidencia de no-overfitting (§5). Los números exactos se reportan por seed con sd.

### 4.3 Métricas del contrato (sin cambios)

search_recall, router_precision, router_recall, context_relevance,
cross_domain_leakage, token_cost, latency, multi_domain_precision,
multi_domain_recall — macro+micro, 3 seeds. Más las nuevas de reporte:
lost/spurious y señales ok/bad por dominio (de `--diagnose`), categorías
degradadas por query, dominios aportados por candidatos (status: promoted).

### 4.4 Regla de descarte (anti-complejidad permanente)

> Si ninguna variante supera claramente a la arquitectura actual sin justificar
> una complejidad permanente adicional, se conserva CORE tal como está y se
> descarta Hybrid.

Operativamente, al completar las corridas A/B/C/D (plan §8, pasos 4-5):

1. **Descarte automático**: si NINGUNA variante cumple simultáneamente
   (a) gates G-R1..G-R6 PASS y (b) mejora sustancial sobre lexical en los
   targets de §4.2 (router_recall y multi_domain_recall), se declara que la capa
   híbrida NO se incorpora: CORE permanece con el router léxico, cap-selector
   queda descartado, y el resultado se documenta como evidencia negativa en la
   ficha. Prohibido incorporar una capa "porque funciona un poco mejor".
2. **Simplificación**: si D (hybrid completo) no mejora a la variante más simple
   en Δ ≥ 0.05 (macro, 3 seeds) en router_recall O multi_domain_recall, se adopta
   la variante simple correspondiente (B candidate-only o C unión) y se descarta
   la complejidad extra de D (degradación + presupuesto) sin beneficio demostrado.
3. La decisión SIEMPRE se toma por los datos leídos al final (media + sd), nunca
   ajustando umbrales tras ver el resultado.

## 5. Anti-overfitting al generator + separación dev/eval (ajuste v2)

### 5.1 Reglas duras sobre el benchmark

1. **Prohibido** agregar a las regex cualquier palabra del vocabulario filler del
   generator (ventanas, formulario, paquete, arranque, error, sesión,
   almacenamiento, celular, iconos, tubería, pierde, trabajador, …). El vocabulario
   del generator es material de test, no insumo de diseño.
2. **Prohibido** calibrar pesos/umbrales (θ_c, presupuesto) con el benchmark
   (3 seeds × 60 queries): el benchmark SOLO evalúa. Todo ajuste se hace en dev.
3. El benchmark conserva su rol de gate de regresión (G-R) + medición de targets.

### 5.2 Set externo real — development ≠ evaluation (ajuste v2)

| Set | Composición | Uso | Regla |
|---|---|---|---|
| **DEV** | ~10-12 queries REALES del usuario, gold anotado a mano | Calibrar θ_c, presupuesto, pesos, formato de evidencia | Libre de iterar durante el desarrollo |
| **EVAL** | ~8-10 queries REALES, gold anotado a mano, **congeladas y registradas (hash) ANTES de empezar** | Evaluación final de la variante elegida | Prohibido tocarlas durante calibración/desarrollo; se miden UNA vez al final |

- Total ~20 queries reales ("no me aparece el componente cuando ejecuto npm",
  "el teléfono no aparece en scrcpy", "cómo hago rebase de una branch", …). Si hay
  menos disponibles, se divide 60/40 y se congela el eval igualmente.
- El eval set se guarda en `scripts/tests/fixtures-realistic/` como archivo aparte
  con su hash registrado en la spec/CHANGELOG — cualquier modificación posterior
  invalida la medición.

### 5.3 EVAL set CONGELADO (2026-08-11, antes de implementar)

- `scripts/tests/fixtures-realistic/eval-set.json` (10 queries, 5 multi / 5 single)
  — **sha256 `180e14a03e07a433…`** (hash canónico sin el campo `_meta.sha256`:
  `d2668ab1ccc190cd…`).
- `scripts/tests/fixtures-realistic/dev-set.json` (12 queries para calibración) —
  **sha256 `0cd8d5a646c77c29…`** (canónico: `bdb8b2e3166d7172…`).
- Cada query del EVAL documenta su **fuente** (sesión/archivo del historial real)
  y su **justificación** (`por_que_eval`): el EVAL representa al USUARIO, no al
  benchmark. Gold anotado a mano con el mapeo `router_categories`.
- **Regla de decisión del EVAL** (acordada con el usuario):
  `benchmark↑ + EVAL↑` = evidencia fuerte · `benchmark↑ + EVAL↓` = **descartar** ·
  `EVAL↑ + benchmark↓` = **investigar antes de adoptar**.
- Modificar `eval-set.json` después de este punto invalida la medición; si el gold
  necesita corrección por error real, se documenta como enmienda en la ficha y se
  vuelve a congelar con nuevo hash ANTES de cualquier corrida.
- Criterio de no-overfitting: la variante elegida mejora sobre `lexical` TANTO en
  el benchmark como en el eval set (mismas métricas, gold a mano). Si mejora el
  benchmark pero no el eval → overfitting → se descarta y se rediseña.

## 6. Control del coste de tokens (OR sigue experimental; presupuesto como parámetro)

- `BUFFY_SEARCH_STRATEGY=or` NO se vuelve default todavía. Permanece candidato
  experimental hasta que el selector híbrido demuestre que controla su coste.
- El **presupuesto de contexto es un parámetro declarativo del experimento**, no
  un umbral de calidad: `BUFFY_SELECTOR_BUDGET` (V1: 900 tokens ≈ 2× baseline
  448). Se corre el híbrido con **barrido de presupuesto** (p.ej. 700 / 900 /
  1400 ≈ 1.5× / 2× / 3× baseline) y se reporta la curva recall/tokens/leakage.
  Así "900" deja de ser mágico: es un punto de la curva de trade-off que el
  veredicto interpreta.
- La capa híbrida recibe el top-K de Search (hoy todo entra al contexto → 1973
  tokens) y selecciona archivos por evidencia (dominio promovido + orden BM25)
  hasta agotar el presupuesto; el resto se reporta como "cortado".
- La tabla de Fase 3 DEBE mostrar: token_cost(AND)=448 → token_cost(OR solo)=1973
  → token_cost(HÍBRIDO) por presupuesto, junto a recall/precision del híbrido,
  para decidir si el trade-off (más tokens que AND, pero recall/precision
  sustancialmente mejores) justifica cambiar el default. Sin esa curva no hay
  cambio de default.
- La decisión de default (AND vs OR+híbrido) se toma DESPUÉS de la curva, con los
  datos, igual que en Fase 1 (lectura, no umbral).

## 7. Preservación de la selección actual

- `BUFFY_SELECTOR=lexical` (default) permanece **durante TODO el experimento** y
  produce la selección byte-idéntica actual (categorías + knowledge + señales).
- La capa híbrida vive detrás de `BUFFY_SELECTOR=hybrid` y NO modifica el
  `buffy-router.sh` como fuente de la selección léxica: el modo léxico actual se
  mantiene intacto (mismos tests, mismo `--diagnose`, misma salida).
- `buffy-router.sh` se modifica SOLO si la capa se integra como modo interno
  DESPUÉS del veredicto; durante el experimento el selector se orquesta fuera
  (runner), mismo patrón que `BUFFY_SEARCH_STRATEGY` en Fase 1.
- Cuando la selección léxica es correcta (señal fuerte con evidencia), el híbrido
  NO la cambia: la unión solo AÑADE dominios promovidos; la degradación (§3.2)
  solo evita conocimiento sin respaldo, nunca quita categorías léxicas con
  evidencia de candidatos.
- Regresión: todos los tests existentes del repo deben seguir verdes (defaults
  intactos).

## 8. Plan de ejecución (baseline → B) — con atribución por componente

| Paso | Qué | Salida | Gate |
|---|---|---|---|
| 0 | Aprobación final de esta spec (v2) | — | revisión usuario |
| 1 | **Congelar eval set** externo (~8-10 queries reales, gold a mano, hash registrado) ANTES de tocar código | archivo + hash | — |
| 2 | Baseline re-congelada: 3 seeds × {and, or} (reproducible; controles 0.250/0.225/0.310/0.107) | JSON + tabla | G1-G3 |
| 3 | Implementar `cap-selector` (V1) detrás de `BUFFY_SELECTOR=hybrid`: votos → score → promoción (§3.1) → degradación (§3.2) → presupuesto; **modo lexical byte-idéntico como control** | código + tests (selectividad, determinismo, presupuesto, invariante hybrid) | suite verde con defaults |
| 4 | **Corridas por componente** (atribución, ajuste v2) — 3 seeds cada una: | tabla A/B/C/D | G1-G3 + G-R |
|    | **A = lexical** (control actual) — al completar A se **fijan y registran δ_p y δ_r** (protocolo §4.1) ANTES de evaluar B/C/D | | |
|    | **B = candidate-only** (solo §3.1, sin señales léxicas) | | |
|    | **C = unión** (léxico ∪ candidatos, sin degradación ni presupuesto) | | |
|    | **D = hybrid** (propuesta completa: unión + degradación + presupuesto, barrido 700/900/1400) | | |
|    | *La pregunta: ¿cuánto aporta cada pieza? Si B ≈ D, el router léxico tiene rol menor y el diseño se simplifica (§4.4).* | | |
| 5 | Calibrar θ_c y presupuesto en **DEV** (si la variante lo requiere) y re-correr D en benchmark con los valores elegidos | tabla final | — |
| 6 | Evaluación final en **EVAL** (una sola medición, congelado) | evidencia no-overfitting | — |
| 7 | Veredicto con los datos (§4.4): adoptar variante (B/C/D) si supera claramente, o **descartar hybrid y conservar CORE**; + decidir default de `BUFFY_SEARCH_STRATEGY` con la curva de presupuesto | decisión + ficha `Benchmark-realista.md` §Fase 3 + informe /sdcard/Download | lectura usuario |
| 8 | Recién entonces: integrar `--quick` a la suite si la métrica es estable | suite ampliada | suite verde |

Prohibido en esta fase: tocar regex del router, corpus, queries, seeds, gates,
defaults, métricas del contrato. El paso 3 implementa SOLO la capa nueva.

## 9. Fuera de alcance (explícito)

- Embeddings / rerank semántico / VLM / LLM en el pipeline de selección.
- Cambiar el corpus, las queries o los seeds (anti-gaming).
- Nuevas regex o heurísticas léxicas sobre el texto de la query.
- Cambiar el default de `BUFFY_SEARCH_STRATEGY` sin la curva de la sección 6.
- Gates/umbrales automáticos sobre el diagnóstico (sigue siendo reporte).
- Integrar `--quick` a la suite principal ANTES del paso 8.
- Ponderar señales léxicas con datos del benchmark (prohibido, sección 5).

## 10. Preguntas que debe responder la fase (criterios de aceptación)

1. ¿Cuánto del lost (react 22/22, code-search 13/13, git 6/6, vision 4/4, android
   15/25, linux 18/20, node 13/14, shell 18/19) se recupera vía candidatos de
   Search sin tocar una regex?
2. ¿El híbrido compone multi-domain (selected = gold) en las queries donde las
   señales existían y en las que no (B y A)?
3. ¿Las señales ambiguas (rom, módulo, script) reducen sus espurios al degradarse
   sin evidencia, sin perder los aciertos actuales (rom 9 ok)?
4. ¿La curva de presupuesto (700/900/1400) controla el coste de OR (1973) con
   recall/precision ≥ 0.50 en algún punto razonable?
5. ¿Qué aporta cada componente (A/B/C/D)? ¿Se necesita toda la complejidad o basta
   candidate-only?
6. ¿La mejora se mantiene en el eval set de queries reales (no-overfitting)?
7. Con todo eso: ¿se adopta la capa híbrida (y qué variante) y se decide el default
   de Search?

## 11. Reglas de arquitectura del proyecto (recomendación del usuario, 2026-08-11)

### 11.1 Clasificación de complejidad: CORE / ADAPTATION / TEST / RESEARCH

Regla para el resto del proyecto: **toda complejidad nueva debe clasificarse**.
Solo CORE y ADAPTATION pueden crecer la arquitectura permanente; TEST y RESEARCH
deben poder quedarse fuera del runtime sin afectar la operación normal.

Aplicación actual:

| Componente | Clase | Runtime permanente | Nota |
|---|---|---|---|
| Router léxico (`buffy-router.sh`) | CORE | sí | selección histórica, invariante |
| `buffy-search.sh` + índice FTS5 | CORE | sí | motor de recuperación |
| Estrategia AND (default actual) | CORE | sí | byte-idéntica histórica |
| Estrategia OR+BM25 (`BUFFY_SEARCH_STRATEGY=or`) | **RESEARCH** | no | candidato validado, no default |
| Memoria curada (MEMORY/USER + sync) | CORE | sí | conocimiento del usuario |
| `.sync-state` / perfil local por dispositivo | **ADAPTATION** | sí (local) | no viaja por git |
| Benchmark realista + gates + `--diagnose` | **TEST** | no | reporte/medición, fuera de runtime |
| `cap-selector` (`BUFFY_SELECTOR=hybrid`) | **RESEARCH** | no | hasta veredicto de esta fase |
| Sets externos DEV/EVAL | TEST | no | validación, nunca runtime |
| Parámetros calibrados (θ_c, presupuesto) | **ADAPTATION** | si se adopta | ver 11.2 |

Consecuencia operativa: el runtime del proyecto = CORE + ADAPTATION local. TEST y
RESEARCH viven en `scripts/tests/` y detrás de env vars, y el proyecto debe poder
correr sin ellos (git clone limpio → suite de tests verdes + runtime normal).

### 11.2 Aislamiento dispositivo ↔ usuario (el próximo criterio arquitectónico)

Dirección confirmada para el clon/multi-dispositivo: MEMORY/USER compartidos viajan
(conocimiento del USUARIO); `.sync-state` y toda adaptación local NO viajan
(conocimiento del DISPOSITIVO). Regla que vela por eso en las próximas fases:

> **Buffy aprende del usuario; detecta el dispositivo; pero nunca confunde una
> cosa con la otra.**

- **Aprendizaje del usuario** (preferencias, hechos, correcciones) → memoria
  curada (MEMORY.md/USER.md) → viaja entre dispositivos.
- **Adaptación al dispositivo** (parámetros calibrados: θ_c, presupuesto, pesos,
  listas de skills, paths locales) → perfil local (config de la máquina) → NO
  viaja, igual que `.sync-state` hoy.
- **El `cap-selector` calibrado en el Mi 10/Termux es ADAPTATION local**: si se
  adopta, sus parámetros se guardan como configuración del dispositivo, NUNCA en
  el conocimiento global (ni en MEMORY.md ni en el repo como verdad). La
  calibración en DEV se ejecuta y registra por dispositivo; los valores no se
  convierten en "conocimiento global" accidentalmente.
- Guarda contra el accidente: ningún comando de escritura de memoria curada
  (`buffy-memory.sh add/batch/…`) puede recibir parámetros de selector/adaptación;
  si un parámetro calibrado debe documentarse, va a la ficha técnica del
  dispositivo (Knowledge/Tools) con su dispositivo anotado, no a la memoria
  global.
- El benchmark mide el pipeline con los parámetros del dispositivo que lo corre;
  al reportar resultados se anota el perfil usado (parámetros + host) para que
  una calibración de un dispositivo no se lea como verdad global.

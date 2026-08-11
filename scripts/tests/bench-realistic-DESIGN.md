# bench-realistic — Contrato de diseño del benchmark realista (iteración C)

> Estado: **CONTRATO DEFINIDO** (2026-08-10). `bench-realistic.sh` NO existe todavía.
> Regla del repo: **benchmark → evidencia → feature → benchmark nuevamente**.
> No se toca `buffy-router.sh` ni el motor de búsqueda hasta que esta medición
> independiente corra y se registre la línea base.

## 0. Hipótesis a medir

`bench-context-selection.sh` demostró: (a) con keywords de dominio obvias el router
acierta casi siempre (easy mode: `domain_precision=1.00`, `domain_recall` 2/2);
(b) FTS5 puro se contamina cuando los irrelevantes comparten vocabulario
(adversarial: recall 0/2, leaked 10/10), y el router lo rescata.

El mundo real no tiene keywords obvias ni dominios aislados. **Hipótesis: con
consultas realistas (lenguaje natural de usuario, no etiquetas artificiales) y
corpus con traslape léxico + casos multi-dominio, `router_precision`/
`router_recall` caen por debajo del nivel útil actual (~1.0 medido en el corpus
trivial).** El benchmark lo demuestra ANTES de diseñar la capa multi-dominio del
router.

## 1. Dataset (500 hechos, 8 dominios reales del ecosistema Buffy)

Generación 100% programática y determinista (`python3`, `random.Random(seed)`),
nunca mano. Cada hecho: texto + dominio primario + archivo de conocimiento del
sandbox + opcionalmente dominio secundario (multi) o marca negativo.

### 1.1 Dominios y distribución explícita

| dominio | hechos | vocabulario situacional típico (nunca tokens de dominio) |
|---|---|---|
| android | 80 | teléfono, celu, consola del terminal, paquetes instalados, permisos, dpi, usb, app colgada, reinicio |
| scrcpy-ff | 70 | pantalla proyectada, mirroring, latencia de video, gestos, mando, input, corte de imagen |
| gmail-apps | 60 | correo, bandeja, etiquetas, scripts, triggers, organizar mensajes |
| frontend | 60 | página, componentes, estilos, deploy, build, tipos, rama |
| linux-pc | 60 | escritorio, ventanas, atajos, terminal del PC, config de ventanas, sesión gráfica |
| buffer-ai | 80 | contexto del agente, memoria, skills, sesiones, conocimiento del repo |
| vision-ollama | 40 | imagen, captura de pantalla, describir, modelo local, texto en imagen |
| red-hogar | 50 | router, wifi, red local, dispositivos conectados, señal |

Total: **500**. Reproducible: la tabla ES el contrato de distribución; el generador
falla si los conteos no coinciden (gate G1).

### 1.2 Reglas de generación (anti-favoritismo)

> **ACTUALIZACIÓN DEL CONTRATO (2026-08-11, decisión registrada — ver §1.4):**
> los 8 dominios de la tabla §1.1 se sustituyen por las **categorías reales del
> router** (`buffy-router.sh`): Android, Code Search, React, Linux, Git, Node,
> Shell, Visión/VLM. El corpus se alinea al espacio de selección real (la
> distribución efectiva usada está en `fixtures-realistic/domains.json`).

1. **Sin tokens de dominio**: el nombre del dominio ni sus keywords puerta
   (`android`, `adb`, `scrcpy`, `shizuku`, `gmail`, `react`, `bspwm`, `ollama`,
   `buffy`, `clasp`, ...) NO aparecen en el texto de los hechos de ese dominio.
   Lista por dominio en `domains.json`; el dominio se infiere por situación
   ("el celu no replica la pantalla → scrcpy-ff"), no por léxico.
2. **Traslape léxico controlado (20–30%)**: `domains.json` define una matriz de
   pares con frases compartidas (ej. "pantalla", "conexión", "permisos",
   "versión", "no responde", "reinicia", "config"). Cada par genera hechos que
   usan vocabulario del otro dominio → ambigüedad de clasificación real.
3. **Casos multi-dominio (12%, ≈60 hechos)**: hechos legítimos con
   `domains: [a, b]` 2-3 dominios (p.ej. "el celu no responde al gesto de la
   pantalla proyectada" → android ∩ scrcpy-ff). Son los puentes que el router
   actual no modela.
4. **Corpus negativo (10%, ≈50 hechos)**: hechos de dominios NO gold que
   comparten vocabulario con la query (base medible de leakage/falsos positivos).
5. Cada hecho se escribe como línea de un archivo `Knowledge/<dominio>/<tema>.md`
   en el sandbox (mismo mecanismo que `bench-context-selection.sh`:
   `$SB/Knowledge/...`, `BUFFY_REPO="$SB"`), con id `f_XXXX` inyectado como
   comentario para el ground truth.

### 1.3 Dominios efectivos (actualización registrada del contrato)

La tabla §1.1 (dominios abstractos del ecosistema: gmail-apps, buffer-ai, red-hogar,
scrcpy-ff, vision-ollama, linux-pc, frontend) **NO es la que se midió**. Decisión
tomada durante la implementación (2026-08-11) y aceptada por el usuario: los dominios
abstractos no existen en el espacio de selección real del router, con lo que
`router_precision`/`router_recall` no serían medibles contra el componente real.

El corpus usado por la baseline (y por `fixtures-realistic/domains.json`,
fuente de verdad de la distribución) es:

| dominio | hechos | archivos Knowledge (rutas reales del router) |
|---|---|---|
| android | 90 | Android/{ADB,Shizuku,scrcpy,GameOptimization,HyperOS,Keymappers}.md |
| react | 70 | React/{React,Vite,Tailwind,PWA}.md |
| linux | 60 | Linux/{System,Kernel}.md |
| git | 60 | Git/Commands.md |
| node | 50 | Node/Node.md |
| shell | 70 | Shell/Shell.md |
| vision | 60 | Vision.md (plano, `knowledge_dir` vacío — layout hardcodeado del router; NO `Vision/Vision.md`) |
| code-search | 40 | CodeSearch/Search.md (el router no carga knowledge de esta categoría) |

Total: **500**. Notas:
- Identificadores de dominio en minúscula para el gold; los directorios Knowledge
  usan la capitalización hardcodeada del router (los hechos viven en el archivo de su
  dominio primario).
- `code-search` no tiene archivo de knowledge en el router (solo skill) → su
  `context_relevance` esperada es 0 por construcción; se mantiene para medir el
  recall de categoría y el hueco real.
- Sigue vigente todo lo demás del contrato: 60 queries (36/14/6/4), gold por
  construcción, reglas anti-favoritismo, gates G1-G3, 9 métricas, 3 modos, seeds
  baseline 20260810/20260811/20260812.

## 2. Queries (60, tareas reales de agente)

| kind | cantidad | definición operativa |
|---|---|---|
| single | 36 | gold de 1 dominio |
| multi | 14 | gold de 2-3 dominios (sobre hechos multi o suma de varios hechos) |
| ambiguous | 6 | gold único pero con hechos de OTRO dominio que comparten vocabulario (falsos amigos presentes) |
| adversarial | 4 | el léxico de la query matchea fuertemente un dominio NO gold; gold en otro |

Reglas:
- Texto como pedido real de usuario/agente ("se me quedó colgada una app y no
  puedo quitarle permisos desde el teléfono, ¿qué se corre?"). Nombres de
  herramienta/producto que un usuario REAL dice (scrcpy, Shizuku, Free Fire,
  Gmail, ollama) están **permitidos** en queries — son habla natural, y el
  ejemplo canónico del repo es "el teléfono no aparece en scrcpy". La
  anti-favoritismo se garantiza por: (a) gold por construcción (nunca de la
  salida del router), (b) el CORPUS sin tokens de dominio (§1.2.1: un token
  "scrcpy" en la query solo matchea hechos cuya redacción es situacional →
  ambigüedad real), (c) kinds ambiguous/adversarial + corpus negativo; y queda
  validado en G1 que **ninguna query mencione nombres de sus gold files**.
- NO diseñadas para favorecer al router: el gold se define por construcción en
  el generador (la query se arma JUNTO con sus hechos objetivo), nunca a partir
  de la salida del router.
- Cada query tiene gold de hechos (`gold_facts`, 1-4 ids), gold de dominios
  (`gold_domains`, derivado = unión de dominios de sus hechos; el generador
  verifica la consistencia) y opcional `negative_facts` (hechos que NO deben
  recuperarse) para ambiguous/adversarial.

## 3. Métricas (9, definiciones operativas)

Notación por query `q`: `S_q` = dominios seleccionados por el router (deduplicados
de los files que eligió); `G_q` = gold_domains; `topK_q` = archivos que devuelve
FTS5 con K=10; `files_gold(q)` = archivos que contienen ≥1 gold_fact; `ctx_q` =
archivos finales del pipeline (contexto del router ∪ topK, deduplicado).
Agregación: **macro** (media por query) y **micro** (pooled global); ambas se
reportan.

| métrica | definición operativa | 0/NaN cuando |
|---|---|---|
| router_precision | media_q( \|S_q ∩ G_q\| / \|S_q\| ) | \|S_q\| = 0 → 0 (sin contexto = error) |
| router_recall | media_q( \|S_q ∩ G_q\| / \|G_q\| ) | nunca (gold ≥ 1) |
| multi_domain_precision | idem router_precision restringido a queries con \|G_q\| ≥ 2 | no hay queries multi → NaN reportado como "n/a" |
| multi_domain_recall | idem router_recall restringido a queries multi | ídem |
| search_recall | media_q( gold_facts recuperados en topK_q / \|gold_facts_q\| ) | — |
| context_relevance | media_q( \|ctx_q ∩ files_gold(q)\| / \|ctx_q\| ) | ctx vacío → 0 |
| token_cost | media_q y total: Σ chars(ctx) / 4 (mismo estimador del bench actual); se reporta media + p95 | — |
| latency | ms por query del pipeline completo (router + search), `time.monotonic` en python; media + p95 | — |
| cross_domain_leakage | media_q( \|{f ∈ ctx_q : dominio(f) ∉ G_q}\| / \|ctx_q\| ) ; diagnóstico extra: leakage router vs leakage search por separado | ctx vacío → 0 |

## 4. Gates (healthy)

**Bloqueantes hoy (sin umbrales arbitrarios — son de sanidad, no de calidad):**

- **G1 — fixtures válidos**: 500 hechos con conteos exactos de la tabla §1.1;
  queries ≥ 50 con gold_facts ≥ 1 existentes en el manifiesto;
  `gold_domains == unión(dominios de gold_facts)`; ningún texto de query contiene
  nombres de sus gold files (§2); ningún hecho contiene tokens de dominio de su
  propio dominio (§1.2.1); ids únicos. Fallar G1 = el benchmark no mide nada
  válido → exit 1.
- **G2 — determinismo**: dos corridas consecutivas con la misma seed y el mismo
  tamaño producen manifiestos byte-idénticos y JSON idéntico salvo `latency_ms`.
  Fallar G2 = medición no reproducible → exit 1.
- **G3 — comparabilidad**: los 3 modos (§6) corren sobre el MISMO manifiesto y
  las mismas queries. Fallar G3 = no hay comparación válida → exit 1.

**Observación en v1 (NO bloquean — registrar y reportar):** las 9 métricas con
macro/micro, media/p95. `healthy = G1 ∧ G2 ∧ G3`; el JSON lleva las métricas de
calidad como `observations`, no como gates.

**Umbrales post-baseline (v2, con evidencia, nunca inventados):** tras la línea
base de 3 seeds (20260810, 20260811, 20260812) se fijan umbrales críticos en la
ficha técnica, con la regla: `umbral_candidato = max(media − 2σ, referencia del
corpus trivial)`. Referencias medibles hoy: `domain_precision=1.00` y
`domain_recall=2/2` (corpus trivial). Una caída sostenida en single-domain por
debajo de ese desempeño DEMUESTRA la hipótesis del §0; el umbral exacto lo decide
el usuario con la evidencia de la línea base.

## 5. Reproducibilidad

- Seed fija por defecto: **`20260810`**; override con `--seed N` o env
  `BUFFY_BENCH_SEED`. Misma seed + mismo tamaño → mismos fixtures (hash sha256
  del manifiesto reportado en el JSON) y mismos resultados salvo `latency_ms`.
- `--json`: salida machine-readable íntegra (schema en §7.5).
- Salida humana por defecto: tablas resumen (por dominio + global + por kind) +
  verdict healthy + nota de observaciones.
- Tamaños: `--facts N` (escala del corpus), `--queries N`, `--quick` (50 hechos
  + 12 queries — para integrar a la suite), `--seed N`. Escalar N NO cambia las
  proporciones de §1.1 ni los kinds de §2 (se escalan proporcionalmente).

## 6. Comparación (3 modos, mismo ground truth)

El mismo manifiesto se evalúa de tres formas; el JSON incluye un bloque
`comparison` lado a lado:

- **search**: FTS5 puro sobre la query cruda (`buffy-search.sh` sin contexto de
  router). Métricas: search_recall, leakage de search, latency search.
- **router**: pipeline completo router → search con contexto de dominio
  (`BUFFY_REPO="$SB" buffy-router.sh --repo "$SB" --json` real, como en
  bench-context-selection.sh). Métricas: las 9.
- **multi**: el mismo pipeline router→search pero evaluado SOLO sobre queries
  con \|G_q\| ≥ 2. Métricas: multi_* + leakage + search_recall ahí.

El bloque `comparison` responde: ¿qué gana añadir el router? (Δ search_recall,
Δ leakage entre search y router) y ¿qué hace el router en casos multi?
(recall multi vs single). El runner usa los componentes REALES (router y search
del repo), no emulaciones.

## 7. Contrato

### 7.1 Estructura de fixtures

```
scripts/tests/fixtures-realistic/
  generator.py        # determinista; lee domains.json, escribe domínios + manifiestos
  domains.json        # 8 dominios: conteos, keywords puerta prohibidas, matriz de
                      # traslape léxico (pares de dominios + frases compartidas)
Sandbox (generado, ephemeral, mktemp como el bench actual):
  $SB/Knowledge/<dominio>/<tema>.md      # hechos como líneas, id f_XXXX en comentario
  $SB/bench-realistic/facts.json         # [{id, domains[], file, text, negative?}]
  $SB/bench-realistic/queries.json       # [{id, text, kind, gold_facts[], gold_domains[],
                                          #   negative_facts[]}]
  $SB/bench-realistic/manifest.sha256    # hash del manifiesto (determinismo)
```

### 7.2 Formato de queries (JSON)

```json
{"id": "q_042", "text": "se me quedó colgada una app y no puedo quitarle permisos desde el teléfono",
 "kind": "single", "gold_facts": ["f_0017"], "gold_domains": ["android"], "negative_facts": ["f_0321"]}
```

### 7.3 Ground truth

Definido exclusivamente por construcción en `generator.py` (query + hechos
objetivo nacen juntos). Independiente del router: la salida del router JAMÁS
influye en el gold. Validado en G1 (consistencia `gold_domains` ↔ `gold_facts`,
ausencia de gold files en el texto de la query y de tokens de dominio en hechos).

### 7.4 Definición formal de métricas

Véase tabla §3 (operativa, con pseudo-fórmulas). Agregación siempre macro y micro.

### 7.5 Formato JSON (--json)

```json
{
  "benchmark": "bench-realistic", "version": "1.0",
  "seed": 20260810,
  "config": {"facts": 500, "queries": 60, "k": 10, "modes": ["search", "router", "multi"]},
  "fixtures": {"facts_by_domain": {"android": 80, "scrcpy-ff": 70, "...": 0}, "queries_by_kind": {"single": 36, "multi": 14, "ambiguous": 6, "adversarial": 4}, "multi_domain_facts": 60, "negative_facts": 50, "manifest_sha256": "..."},
  "results": [ {"query_id": "q_042", "kind": "single", "gold_domains": ["android"], "selected_domains": ["android"], "router_precision": 1.0, "router_recall": 1.0, "search_recall": 0.75, "context_relevance": 1.0, "token_cost": 812, "latency_ms": 14.2, "cross_domain_leakage": 0.0} ],
  "aggregates": {"macro": {"router_precision": 0.9, "router_recall": 0.85, "multi_domain_precision": "n/a", "multi_domain_recall": "n/a", "search_recall": 0.42, "context_relevance": 0.8, "cross_domain_leakage": 0.11}, "micro": {"...": 0}, "latency_p95_ms": 22.1, "token_cost_mean": 760},
  "comparison": {"search": {"search_recall": 0.31, "leakage": 0.24}, "router": {"search_recall": 0.55, "leakage": 0.05}, "multi": {"multi_domain_recall": 0.5}},
  "gates": {"G1_fixtures": true, "G2_determinism": true, "G3_comparable": true},
  "healthy": true, "observations": {"nota": "umbrales de calidad se fijan post-baseline (§4)"}
}
```

### 7.6 Exit codes

| código | significado |
|---|---|
| 0 | corrió; gates G1-G3 OK (healthy=true) |
| 1 | fixture inválido o gate bloqueante roto (G1/G2/G3) |
| 2 | uso incorrecto (flag desconocido, N inválido) |

Mismas convenciones que `bench-context-selection.sh` (0 OK / 1 medición rota /
2 error de uso).

### 7.7 Gates (resumen)

Bloqueantes y justificados (sanidad, sin umbrales de calidad): G1 fixtures, G2
determinismo, G3 comparabilidad. Calidad = observación en v1; umbrales solo en
v2 con evidencia de la línea base (§4).

### 7.8 Qué NO mide

- La calidad de la RESPUESTA final del agente (no hay LLM en el loop: solo
  router + FTS5).
- Memoria, skills, provenance ni el flujo e2e completo del agente.
- Latencia de serving: es latencia local (bash/python en Termux/PC); solo
  sirve como comparativo relativo entre modos.
- Comprensión semántica: mide RECUPERACIÓN (dominios y hechos), no que el
  contenido sea correcto (los hechos son sintéticos).
- El parámetro `k` de FTS5 se fija en 10; no barre k (fuera de alcance).
- El fixture real del repo: los hechos son sintéticos; un corpus D (muestreo de
  `Knowledge/` real) queda para una iteración posterior si la evidencia lo pide.

## 8. Próximo paso (implementación en la próxima sesión)

Orden EXACTO, ejecutar de arriba a abajo, sin saltos:

1. `scripts/tests/fixtures-realistic/generator.py` (+ `domains.json`) según §1-§2
   y §7.1; validar G1.
2. `scripts/tests/bench-realistic.sh` según §3-§7: 3 modos, `--facts/--queries/
   --seed/--quick/--json`, exit codes 0/1/2, salida humana + JSON (§7.5-7.6),
   reutilizando el mecanismo de sandbox y las llamadas reales a router/search
   de `bench-context-selection.sh`.
3. Correr G1-G3 (auto dentro del runner).
4. **Línea base**: 3 corridas con seeds 20260810/11/12 y registrar macro/micro +
   p95 en `Knowledge/Tools/Benchmark-realista.md` (ficha técnica nueva).
5. NO tocar `buffy-router.sh` ni el motor de búsqueda — con la evidencia de la
   ficha se decide la capa multi-dominio (feature) y luego se vuelve a correr
   el benchmark (benchmark → evidencia → feature → benchmark).
6. Solo tras baseline estable: integrar `--quick` a `run-tests.sh` (nuevo
   `test-realistic-bench.sh`) y actualizar README §benchmark.

Restricción dura: **no implementar ninguna feature del router ni del motor para
hacer pasar el benchmark**; la medición debe existir y registrarse ANTES.

## A. Apéndice — consultas naturales validadas (semillas para el generador)

Revisión externa (2026-08-10) sobre el repo: confirma que C necesita corpus
naturalizado y consultas cruzadas; aporta ejemplos ya validados como tareas
reales. El generador los usa como TEMPLATES-SEMILLA para producir las 60
queries (§2) — variando verbo/sujeto/objeto sin cambiar el gold por
construcción:

```text
# single (gold 1 dominio)
"el teléfono aparece conectado pero scrcpy no abre la pantalla"          # → scrcpy-ff
"quiero saber por qué Shizuku perdió los permisos después de reiniciar"  # → android
"la PWA compila pero en producción el service worker no actualiza los
 archivos"                                                               # → frontend
# multi (gold 2-3 dominios)
"el teclado funciona en Linux pero no dentro de scrcpy"                  # → linux-pc + scrcpy-ff
"el teléfono no aparece en scrcpy y quiero comprobar si la depuración
 inalámbrica sigue funcionando"                                          # → android + scrcpy-ff
# multi con keymapping (gold: android + scrcpy-ff, keymapping vive en scrcpy-ff)
"Quiero jugar Free Fire desde el PC usando scrcpy, pero el teclado no
 responde"                                                               # → android + scrcpy-ff
```

Nota: estas son QUERIES — los nombres de herramienta/producto (scrcpy,
Shizuku, Free Fire) son habla natural de usuario y están permitidos (§2). Son
los HECHOS del corpus los que no pueden contener tokens de dominio (§1.2.1):
mientras la query dice "scrcpy", el hecho que la resuelve dice "la pantalla
proyectada se corta"; la ambigüedad nace ahí. El generador debe validar que el
hecho/query de cada par seed respeta su regla (G1).
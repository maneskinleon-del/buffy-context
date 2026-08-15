# Fixture experimental congelado — diseño (Fase D)

> Estado: **⏳ DISEÑO — pendiente de aprobación** (2026-08-15) — aún SIN implementación.
> Motivo: evidencia empírica del experimento **17D** (2026-08-15): los controles de
> sanity (A/B-solo/V1-solo) NO reprodujeron sus esperados históricos por **drift real
> del corpus** — `README.md`, `ai-context/CHANGELOG.md`, `ai-context/CONTINUE.md` y
> `ai-context/SESION.md` crecieron entre 17C y 17D (corpus_hash `236a87fa` →
> `029ed669`, 7653 → 7803 líneas) y alteraron posiciones de pasajes, leak, pRel y
> paths del ctx. El experimento no debe depender del árbol vivo del proyecto.
> Pertenece al frente arquitectónico **INSTANCE-STATE-DESIGN.md** (Fase D, frente
> separado y NO abierto hasta que este diseño se apruebe). El experimento dirá
> "usa este fixture congelado", no "usa el repositorio actual".

---

## 1. Problema y requisito

### 1.1 El problema

Hoy el EVAL consume el **árbol vivo** del repo (`$HOME/buffy-context`): el runner
`run-leak-17C.sh` hace `discover_corpus(repo)` sobre el repo actual y calcula un
`corpus_hash` de `(path, mtime_ns, size)`. Cualquier cambio operativo — crecer un
handoff, editar un changelog, un commit de docs — cambia mtime y/o contenido →
`corpus_hash` nuevo → el índice semántico se reconstruye → los resultados ya no
son comparables con la corrida anterior.

17D lo demostró: A/B-solo pasaron de leak `0.442` → `0.425` y V1-solo de pRel
`0.584` → `0.581` **solo** porque el corpus vivo creció. El mecanismo anti-drift
(§3.1 de `combine-17D-DESIGN.md`) funcionó: STOP antes de evaluar T. Pero el
hallazgo estructural quedó: **el corpus de Buffy no está aislado de su propio
estado operativo.**

### 1.2 Requisito

> El benchmark debe consumir un **fixture/corpus congelado e inmutable** con
> identidad reproducible (`fixture_id`, `corpus_hash`, `eval_hash`, `config_hash`,
> `runner/version`), de modo que 100 usuarios haciendo commit/push sobre el árbol
> vivo vean **exactamente el mismo corpus**.

### 1.3 Alcance

- **SÍ:** congelar el corpus (archivos `.md`/`.yaml` que el runner lee), su hash
  por contenido, y la configuración del runner (modelo, params, eval, dict, versión).
- **SÍ:** que el runner valide el fixture antes de correr (inmutable = si el
  contenido difiere del manifest → error, no reindex silencioso).
- **NO:** tocar el pipeline de selección (router/search/selector/ranking).
- **NO:** re-ejecutar ni recalibrar EVALs históricos (17B/17C/17D quedan como
  referencia histórica con su corpus vivo).
- **NO:** tocar el mecanismo de memoria (`buffy-memory.sh`, MEMORY/USER).

---

## 2. Mecánica actual verificada (2026-08-15)

Leído del runner `scripts/tests/evals/run-leak-17C.sh`:

| Pieza | Cómo funciona hoy | Implicación para el fixture |
|---|---|---|
| `discover_corpus(repo)` | Escanea raíz `*.md/*.yaml` + `ai-context/` + `Knowledge/` (excluye `deprecated`) | **Incluye estado de instancia** (`SESION.md`, `CONTINUE.md`, `SNAPSHOT.md`, `facts.yaml`) → el fixture debe **filtrarlo** (tabla contractual §3) |
| `corpus_hash(repo, files)` | `sha1(f"{f}:{st_mtime_ns}:{st_size}")` | **Frágil por mtime**: cambia al copiar/checkout aunque el contenido sea idéntico. El fixture usa hash **por contenido** |
| `read_entries(repo, files)` | Lee todas las líneas no vacías → `(path, lineno, text)` | El fixture congela estos **archivos**, no el índice (el índice se regenera y cachea por hash) |
| `load_or_build_index` | Cache por `corpus_hash` en `~/.cache/buffy-eval-semantic/` | Con hash por contenido, el cache es **estable entre máquinas con el mismo corpus** → corridas rápidas y comparables |
| `--repo <dir>` | Ya existe (default `$HOME/buffy-context`) | Apuntar a un dir congelado **no requiere reescribir el pipeline** |
| `git -C repo rev-parse HEAD` | Registra `commit_sha` del árbol vivo | Con fixture, registrar el `commit_sha` **del fixture** (no `?`) |
| JSON de salida | Registra `corpus_hash`, `eval_hash`, `h1_dict_hash`, `params`, `determinism_hash` | Añadir: `fixture_id`, `fixture_corpus_hash`, `config_hash`, `runner_version` |
| EVAL fixture | `eval-ctx-PC-2026-08-11.json` + `.sha256` + `EVAL_HASH` en el runner | Ya es inmutable (hash + verificación). El fixture lo **referencia**, no lo duplica |

**Golds:** el EVAL usa `gold_domains`, `gold_files`, `gold_facts` (por archivo,
sin referencias a estado de instancia — verificado). La exclusión de
SESION/CONTINUE/SNAPSHOT/facts del corpus no invalida ningún gold existente.

---

## 3. Diseño del fixture

### 3.1 Estructura en disco

```text
scripts/tests/evals/fixtures/
└── <fixture_id>/                    # ej: fx-2026-08-15-001
    ├── manifest.json                # identidad completa (abajo)
    └── corpus/                      # copia congelada de los archivos del corpus
        ├── README.md
        ├── CHANGELOG.md
        ├── Knowledge/…
        ├── ai-context/INFO-core.md
        ├── ai-context/INFO-full.md
        ├── ai-context/PROJECTS.md
        └── …                        # SOLO PROYECTO + MEMORIA compartida;
                                     # NUNCA SESION/CONTINUE/SNAPSHOT/facts/.sync-state
```

- El directorio `fixtures/` se **versiona en git** (el corpus son cientos de KB →
  tamaño aceptable) → el fixture viaja con el repo y es reproducible por cualquiera.
- El `corpus/` contiene SOLO los archivos que `discover_corpus` lee **menos** la
  exclusión contractual (§3.2).

### 3.2 Exclusión (tabla contractual de INSTANCE-STATE-DESIGN.md §3)

**Corpus real hoy (verificado 2026-08-15): 52 archivos / 655666 bytes (640 KB).** Clasificación
aprobada (usuario, 2026-08-15 — decisiones explícitas):

| Archivo | ¿Va al corpus del fixture? | Motivo |
|---|---|---|
| `README.md` · `docs/` | ✅ Sí | PROYECTO (compartido) |
| `CHANGELOG.md` · `CHANGELOG-archive.md` | ✅ Sí | Histórico del proyecto (compartido) |
| `Knowledge/` | ✅ Sí | PROYECTO (compartido) |
| `ai-context/facts_rules.yaml` | ✅ Sí | **Reglas/configuración del motor de verify — PROYECTO, versionado** (NO confundir con `facts.yaml`, que es estado de instancia) |
| `ai-context/INFO-*.md` · `PROJECTS.md` · `LOAD_CONTEXT.md` · `AGENTS.md` · otros `.md` de ai-context | ✅ Sí | PROYECTO (compartido) |
| `ai-context/memories/MEMORY.md` · `USER.md` | ❌ No por defecto | **MEMORIA** — inclusión explícita con `--include` (evita que un benchmark capture memoria personal/instancia accidentalmente) |
| `SESION.md` · `SESION-archive.md` · `CONTINUE.md` | ❌ No | INSTANCIA — local |
| `SNAPSHOT.md` · `facts.yaml` · `.sync-state` | ❌ No | INSTANCIA — local, ya gitignored |
| `scripts/**` · binarios · `.git/**` | ❌ No | No `.md`/`.yaml` en el alcance de `discover_corpus` |

> **Regla:** el fixture congela el corpus **sin estado de instancia y sin memoria
> por defecto**. Si un día un experimento necesita SESION/CONTINUE o memoria como
> *distractor*, se declara explícitamente en el manifest
> (`include: ["ai-context/CONTINUE.md", "ai-context/memories/MEMORY.md"]`), nunca
> por defecto.

### 3.3 `manifest.json`

```json
{
  "fixture_id": "fx-2026-08-15-001",
  "fixture_version": 1,
  "created_at": "2026-08-15T…",
  "source": {
    "repo": "buffy-context",
    "commit_sha": "<sha del árbol vivo del que se congeló>"
  },
  "corpus": {
    "n_files": 52,
    "n_entries": 7803,
    "size_bytes": 655666,
    "corpus_hash": "<sha1 por contenido — ver §3.4>",
    "files": [ {"path": "README.md", "sha256": "…"}, … ]
  },
  "exclusions": ["ai-context/SESION.md", "ai-context/SESION-archive.md", "ai-context/CONTINUE.md", "ai-context/SNAPSHOT.md", "ai-context/facts.yaml"],
  "include_by_default_off": ["ai-context/memories/MEMORY.md", "ai-context/memories/USER.md"],
  "eval": {"eval_id": "eval-ctx-PC-2026-08-11", "eval_hash": "98a0e308…"},
  "config": {
    "model": "bge-m3",
    "params": {"N_L":…, "N_X":…, "N_S":…, "PADS": [4], "LIMIT": 10, "BUDGET_TOKENS": 10400, "RESCUE_LOW": 0.545, "MAX_PASSAGES": 400},
    "variant": "A",
    "dict": {"path": null, "h1_dict_hash": null},
    "config_hash": "<sha256 del bloque config — §3.5>"
  },
  "runner": {"name": "run-leak-17C.sh", "version": "<sha256 del script runner>", "runner_hash": "<idem>"}
}
```

### 3.4 `corpus_hash` por contenido (cambio requerido)

Reemplazar `sha1(f"{f}:{st_mtime_ns}:{st_size}")` por un hash **del contenido**:

```python
def corpus_hash(repo, files):
    h = hashlib.sha1()
    for f in sorted(files):
        with open(os.path.join(repo, f), 'rb') as fh:
            h.update(b"%s:" % f.encode())
            h.update(fh.read())
            h.update(b"\x00")
    return h.hexdigest()[:16]
```

- Determinista: el mismo contenido → el mismo hash, en cualquier máquina/checkout.
- El caché de embeddings queda keyed por este hash → estable entre máquinas.
- **Este cambio afecta a todos los EVALs** (cambia el valor de `corpus_hash` vs el
  histórico mtime-based). Se implementa SOLO cuando el fixture exista y el nuevo
  runner registre `fixture_corpus_hash`; los EVALs históricos conservan su
  `corpus_hash` mtime-based como referencia (no se re-ejecutan).

### 3.5 `config_hash`

`sha256` del JSON canónico (claves ordenadas) del bloque `config` del manifest:
modelo + params + variant + dict + eval_hash + runner_version. Detecta cambios de
configuración entre corridas sin tocar el corpus (dos corridas con el mismo
fixture pero distinto `PADS` → `config_hash` distinto → resultados no mezclables).

### 3.6 Runner/version

`runner.version` = sha256 del script runner en el momento de la corrida. Si el
runner cambia (nuevo paso, bugfix), el `runner_hash` cambia y los resultados se
distinguen. El `EVAL-REGISTRY.md` registra `fixture_id + runner.version` por
veredicto.

---

## 4. Consumo por el runner (cambio mínimo)

El runner actual ya acepta `--repo <dir>`. El fixture se integra sin reescribir
el pipeline:

1. Nuevo flag: `--fixture <dir>` (alternativa a `--repo`). Si se pasa:
   - `REPO` = `<dir>/corpus`.
   - Se lee `<dir>/manifest.json` (error si falta → "fixture inválido").
   - **Validación de inmutabilidad:** se recalcula `corpus_hash` por contenido del
     `corpus/` y se compara con `manifest.corpus.corpus_hash`. Si difiere →
     **STOP** ("fixture mutado: esperado X, real Y — no reindexar en silencio").
     (El reindex solo se permite con `--reindex` explícito y `--allow-fixture-mutation`.)
   - `commit_sha` del JSON = `manifest.source.commit_sha` (no `git rev-parse`).
   - El JSON de salida registra: `fixture_id`, `fixture_corpus_hash`,
     `config_hash`, `runner_version`.
2. Sin `--fixture` → comportamiento actual (árbol vivo) preservado para
   compatibilidad y para re-corridas históricas.

---

## 5. Construcción del fixture (script `build-fixture.sh`)

```text
build-fixture.sh --out <fixture_id> [--include ai-context/CONTINUE.md …]
```

1. `discover_corpus($REPO)` (mismo alcance que el runner).
2. Filtra las exclusiones contractuales (§3.2) salvo `--include` explícito.
3. Copia los archivos a `fixtures/<fixture_id>/corpus/` (preservando relpath).
4. Calcula `corpus_hash` por contenido + sha256 por archivo.
5. Escribe `manifest.json` (fuente = `git rev-parse HEAD` del árbol vivo, eval =
   `EVAL` + `EVAL_HASH` actuales, config = params del runner, runner_version =
   sha256 del runner).
6. Imprime el `fixture_id` para congelarlo en el diseño del experimento.

**Congelar = correr una vez y commitear** el directorio `fixtures/<id>/` con su
manifest. Después, nadie edita `corpus/` a mano (el runner lo detecta en la
validación §4.1).

---

## 6. Gate de Fase D (criterios de aceptación del mecanismo)

| # | Criterio | Verificación |
|---|---|---|
| 1 | **Reproducible**: mismo fixture + mismo runner + misma config → mismas métricas | 2 corridas del mismo fixture con `--repeat 2` → `determinism_hash` y `corpus_hash` idénticos |
| 2 | **Inmutable**: editar el árbol vivo NO cambia el fixture | tocar `SESION.md`/`CONTINUE.md`/`CHANGELOG.md` en el repo → re-correr con `--fixture` → `fixture_corpus_hash` idéntico y métricas idénticas |
| 3 | **Estable entre máquinas**: checkout limpio del repo → mismo hash por contenido | `git clone` local + correr con `--fixture` → `fixture_corpus_hash` idéntico (sin `--reindex`, cache miss inicial OK) |
| 4 | **Detección de mutación**: tocar un archivo del `corpus/` del fixture → STOP | editar `fixtures/<id>/corpus/README.md` → runner rechaza con "fixture mutado" |
| 5 | **Config sensible**: cambiar `PADS`/model → `config_hash` distinto | dos corridas del mismo fixture con distinto param → `config_hash` difiere |
| 6 | **Suite intacta**: sin EVAL nuevo no se rompe nada | suite full 315 / quick 299 OK; runner sin `--fixture` se comporta igual |
| 7 | **Exclusión efectiva**: el fixture NO contiene estado de instancia | `find fixtures/<id>/corpus -name 'SESION*' -o -name 'CONTINUE*' -o -name 'SNAPSHOT*' -o -name 'facts.yaml'` → vacío |

---

## 7. Orden de implementación (tras aprobación)

```text
Fase D1 — script build-fixture.sh + corpus_hash por contenido (solo en el runner con --fixture)
Fase D2 — build + commit del primer fixture congelado (fixtures/fx-2026-08-15-001/)
Fase D3 — runner: --fixture + validación de mutación + campos nuevos en el JSON
Fase D4 — gate §6 (reproducible, inmutable, multi-máquina, mutación, config, suite)
Fase D5 — registro en EVAL-REGISTRY.md de la infraestructura (no de un EVAL nuevo)
```

Cada fase se congela por separado. **No se abre ningún EVAL nuevo** (17E+ hasta
que el mecanismo exista y pase el gate).

---

## 8. Riesgos y decisiones abiertas

**Clasificación del corpus aprobada (usuario, 2026-08-15):**

| Elemento | Fixture | Motivo |
|---|---|---|
| `ai-context/facts_rules.yaml` | ✅ Sí | Configuración/reglas del proyecto, versionada — NO confundir con `facts.yaml` (estado de instancia, fuera) |
| `ai-context/memories/MEMORY.md` | ❌ Por defecto | Memoria — inclusión explícita vía `--include` |
| `ai-context/memories/USER.md` | ❌ Por defecto | Memoria — inclusión explícita vía `--include` |
| `ai-context/CHANGELOG-archive.md` | ✅ Sí | Histórico del proyecto, igual que `CHANGELOG.md` |

**Semántica resultante:**

```text
fixture normal
├── proyecto              ✅
├── Knowledge             ✅
├── reglas del motor      ✅ (facts_rules.yaml)
├── CHANGELOG             ✅
├── CHANGELOG-archive     ✅
└── memories/             ❌ por defecto
                              │
                              └── --include → explícito
```

| Riesgo/Decisión | Mitigación |
|---|---|
| **Cambio de `corpus_hash` a contenido rompe comparabilidad con históricos** | Los históricos (17B/17C/17D) conservan su `corpus_hash` mtime-based en sus JSONs congelados; NO se re-ejecutan. El nuevo hash rige para corridas con `--fixture` |
| **Tamaño del fixture en git** | **52 archivos / 655666 bytes (640 KB)** (verificado 2026-08-15) → aceptable versionarlo |
| **¿El fixture incluye `MEMORY/USER`?** | **Decidido (2026-08-15): excluido por defecto** + `--include ai-context/memories/MEMORY.md` explícito. Evita que un benchmark capture memoria personal/instancia accidentalmente |
| **Reindex vs mutación** | Mutación silenciosa → STOP. `--reindex` + `--allow-fixture-mutation` explícitos para casos excepcionales (con registro en el JSON) |
| **Cache stale entre máquinas** | Cache keyed por `corpus_hash` por contenido → mismo corpus = mismo cache. Cache miss solo la primera vez por máquina |
| **SESION/CONTINUE como distractor** | Experimentos futuros que los necesiten los declaran con `--include`; nunca por defecto (contrato §3) |
| **¿Dónde vive el fixture?** | En `scripts/tests/evals/fixtures/` versionado. Alternativa evaluada y descartada: tar/snapshot fuera del repo (rompería la repro de checkout limpio) |

---

## 9. Relación con el contrato madre

- `INSTANCE-STATE-DESIGN.md` §7 define la Fase D como frente separado: "el
  experimento no dice 'usa el repositorio actual' — dice 'usa este fixture
  congelado'". Este documento es el diseño detallado de esa Fase D.
- La Fase B (ya implementada, `0bafef9`) es **prerequisito**: al sacar
  SESION/CONTINUE/SESION-archive del versionado quedó claro qué es local y qué es
  compartido — el fixture excluye exactamente lo local.
- No mezcla: el fixture NO toca el mecanismo de memoria, NO re-ejecuta EVALs
  históricos, NO abre experimentos nuevos.

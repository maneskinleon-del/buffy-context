# Diseño del motor `project-state` (Paso 3)

> **Paso 3 de project-state — MOTOR (diseño) · NO implementación.**
> No se escribe código ejecutable, no se crea `project-state.yaml`, no se modifica
> `buffy-verify.sh` ni `facts_engine.py`.
> El entregable es este documento: pipeline, semántica de ejecución, contrato de
> salida y límites del motor.
> Fecha de diseño: 2026-10-07. Predecesor: `project-state-design.md` (Paso 2, esquema).

---

## RESUMEN

El motor `project-state-engine` es el verificador del esquema diseñado en el Paso 2.
Lee `ai-context/project-state.yaml`, ejecuta los `check` de las aserciones tipo A,
clasifica cada una en `verified | stale | unknown | expired`, y emite reporte
(TSV o JSON). Las aserciones tipo B **no se ejecutan** — el motor las preserva
intactas y las reporta como conteo de juicio humano.

### Decisiones de entrada (las 5 bloqueantes — resueltas 2026-10-07)

| ID | Decisión | Consecuencia para este diseño |
|---|---|---|
| **Q-03** | **Canal paralelo** — `buffy-verify.sh --json` NO se modifica; su contrato de claves exactas (`test-verify.sh` L25: `repo/verified/stale/unknown/expired/trust_score/items/_info`) queda intacto. | El motor emite su **propio** JSON con su propio root. No hay merge ni consulta cruzada. |
| **Q-04** | Si `check.command` no se puede ejecutar (binario ausente, comando inválido, timeout) → `unknown`, `confidence: 0.2`. | Taxonomía de fallos §EJECUCIÓN; nunca `stale` por fallo de infraestructura. |
| **Q-07** | **Sí hereda** el rechazo `SHELL_METACHARS` y `shell=False` de `facts_engine.py` (L28, L56). | §EJECUCIÓN de check. |
| **S-04** | `check.command` es **lista de args** (como `facts_rules.yaml`). String se rechaza (compat no se implementa). | §EJECUCIÓN de check. |
| **S-05** | **`trust_project` paralelo** al `trust_score` de buffy-verify: calculado solo sobre aserciones A; B se reporta como `human_assertions`. | §SALIDA. |

### Patrón heredado (arquitectura declarativa)

`facts_engine.py` L3-8 establece el contrato: *"AGREGAR un hecho nuevo = editar
facts_rules.yaml, sin tocar el motor."* Este motor aplica el mismo patrón:
**agregar una aserción = editar `project-state.yaml`, sin tocar el motor.**
El motor es genérico: solo conoce el esquema (Paso 2), no los contenidos.

---

## DECISIONES DE ENTRADA (detalle de las 5 bloqueantes)

### Q-03 — Canal paralelo, no integración

**Decisión**: `buffy-verify.sh` queda intacto. `project-state-engine` es un
ejecutable separado con su propia salida JSON.

**Fundamento**:
- `test-verify.sh` L25 asserta `set(d.keys())=={"repo","verified","stale","unknown","expired","trust_score","items","_info"}` — integrar aserciones A de project-state en ese JSON exige migrar un contrato de test existente.
- D2 (fijo): "archivo nuevo con motor propio". La integración en buffy-verify.sh contradiría D2.
- `buffy-verify.sh` verifica **sistema vs INFO-core.md**; `project-state-engine` verifica **aserciones vs repo**. Dominios distintos, dos canales.

**Consecuencia**: dos trust separados (§SALIDA). No hay "trust global del sistema+repo" — si se quiere uno, es un consumidor externo que agrega ambos JSON (fuera del alcance de este diseño).

### Q-04 — Fallo de infraestructura = `unknown`, nunca `stale`

**Decisión**: si el `check` no se puede ejecutar o evaluar → `status: unknown`,
`confidence: 0.2`.

| Situación | status | confidence |
|---|---|---|
| Binario del comando no existe en PATH | `unknown` | 0.2 |
| Argumento con `SHELL_METACHARS` (regla rechazada) | `unknown` | 0.2 |
| Timeout (10s, idéntico a `facts_engine.py` L56) | `unknown` | 0.2 |
| Comando corre pero no produce salida evaluable | `unknown` | 0.2 |
| Comando corre y produce salida que **contradice** `value` | `stale` | 0.4 |

**Fundamento**: consistencia con facts.yaml (`unknown` = "no se pudo ejecutar",
`stale` = "se ejecutó y difiere"). `stale` en un fallo de infraestructura sería
falso-success negativo: acusaría al repo de estar desactualizado cuando en realidad
no se pudo verificar.

### Q-07 — Herencia del hardening de shell

**Decisión**: `subprocess.run(argv, shell=False, timeout=10)` + rechazo previo de
`SHELL_METACHARS = set(";&|`$<>(){}[]*?~!\\'\" \t\n")` (`facts_engine.py` L28).

**Fundamento**: D2 dice que la validación *puede* diferir, no que deba. Reusar el
mecanismo audited (auditoría 3 del repo: "sin shell=True, defensa extra") es más
seguro que reinventarlo. Un `check.command` con `; rm -rf` jamás se ejecuta.

### S-04 — Lista estricta

**Decisión**: `check.command` debe ser lista YAML (`[git, rev-parse, HEAD]`).
String se rechaza con `unknown` + mensaje (a diferencia de `normalize_command` de
facts (`facts_engine.py` L31: acepta string retrocompat), aquí no hay retrocompat
que soportar — es un formato nuevo).

### S-05 — `trust_project` paralelo

**Decisión**: `trust_project = round(100 * verified_A / max(1, verified_A + stale_A + expired_A), 1)`
— **misma fórmula** que `trust_score` de buffy-verify (`buffy-verify.sh` L343):
excluye `unknown`, solo A. B nunca entra en la fórmula.

**Fundamento**: B no es verificable → meterlo en un trust_score produciría un
número que mide dos cosas distintas (mecánica + juicio). Se reporta aparte:
`human_assertions: {judged: n, pending: n, disputed: n}`.

---

## ARQUITECTURA — PIPELINE

```
project-state.yaml
      │
      ▼
┌─ 1. CARGA ──────────────────────────────────────────┐
│ yaml.safe_load(ai-context/project-state.yaml)       │
│ ausente/corrupto → salida de error, exit 1          │
└─────────────────────────────────────────────────────┘
      │
      ▼
┌─ 2. CLASIFICACIÓN ──────────────────────────────────┐
│ por cada assertion:                                 │
│   type == B → va directo al reporte (sin ejecutar)  │
│   type == A → pasa a ejecución                     │
└─────────────────────────────────────────────────────┘
      │ (solo A)
      ▼
┌─ 3. EJECUCIÓN ──────────────────────────────────────┐
│ normalize_command(check.command) → lista o rechazo  │
│ binario presente? (shutil.which) → no: unknown      │
│ subprocess.run(argv, shell=False, timeout=10)       │
│ salida evaluable? → no: unknown                     │
│ comparar salida contra check.comparison/expected    │
│   coincide → verified (1.0)  · difiere → stale(0.4) │
└─────────────────────────────────────────────────────┘
      │
      ▼
┌─ 4. TTL (post-ejecución) ───────────────────────────┐
│ (hoy − verified).days > ttl_days → expired (0.2)    │
│   — aplica a A verificadas; hereda ttl_days=30      │
└─────────────────────────────────────────────────────┘
      │
      ▼
┌─ 5. REPORTE ────────────────────────────────────────┐
│ TSV (default, patrón facts_engine.py L7) o --json   │
│ trust_project (A) + human_assertions (B)            │
└─────────────────────────────────────────────────────┘
```

### Elementos del pipeline

| Etapa | Inspiración en | Diferencia clave |
|---|---|---|
| Carga | `parse_rules` de facts_engine (safe_load + `except → {}`) | Archivo propio, no `facts_rules.yaml`. |
| Clasificación | — (nuevo) | El tipo A/B (D3) bifurca aquí: B **nunca** llega a ejecución. |
| Ejecución | `normalize_command` + `run_cmd` (facts_engine L31/L56) | Lista estricta (S-04); comparación configurable (§EJECUCIÓN). |
| TTL | `ttl_check` de buffy-verify.sh (fecha de facts.yaml vs hoy) | Sobre el campo `verified` de cada assertion, no sobre facts.yaml. |
| Reporte | TSV `level<TAB>fact<TAB>...` (facts_engine L7) | Claves JSON propias (Q-03), no las de buffy-verify. |

### Lenguaje y dependencias

- **Python 3** (mismo stack que facts_engine.py) + **PyYAML** (ya requerido por facts_engine, sin dependencia nueva).
- Un solo archivo nuevo en `scripts/lib/` (propuesta de ruta, sujeto a S-01 del Paso 2).

---

## EJECUCIÓN DE CHECKS (solo tipo A)

### Contrato de `check`

```yaml
check:
  command: [git, rev-parse, HEAD]   # lista estricta (S-04)
  comparison: exact                  # exact | contains | regex (default: exact)
  expected: <string>                 # opcional — valor esperado de la salida
```

| Campo | Requerido | Semántica |
|---|---|---|
| `command` | ✅ | Lista de args. Rechazada si: no-lista, vacía, o algún arg contiene `SHELL_METACHARS` → `unknown`. |
| `comparison` | ❌ (default `exact`) | `exact`: salida limpia == expected. `contains`: expected ∈ salida. `regex`: re.search(expected, salida). |
| `expected` | condicional | Valor esperado. Si ausente en comparison exact/contains → `unknown` ("check sin expected — no evaluable"): una comparación sin esperado no puede dar stale, daría verified universal (falso-success). **Requerido salvo** cuando `comparison` es una de las formas libres definidas abajo. |

### Formas de `comparison` sin `expected` (excepciones válidas)

| comparison | Sin expected significa | Ejemplo |
|---|---|---|
| `regex` con patrón en `expected`... | — | — |
| `exists` | existe la ruta indicada en `command`'s último arg | `[test, -f, ai-context/README.md]` |
| `exit_code` | exit code == 0 | `[pytest, -q]` |

*(`exists` y `exit_code` son comparaciones autocontenidas: el resultado ya está
en el código de salida, no hace falta un valor esperado separado.)*

### Proceso paso a paso (por cada assertion A)

1. **Validar `check` presente** — si falta → `unknown` + `CHECK_MISSING` (Paso 2 LINT-06 ya lo exige; el motor degrada, no rompe).
2. **`normalize_command(check.command)`** → lista o rechazo (metacaracteres) → `unknown` + `METACHARS_REJECTED`.
3. **`shutil.which(argv[0])`** → binario ausente → `unknown` + `BINARY_MISSING` (Q-04).
4. **`subprocess.run(argv, shell=False, capture_output=True, text=True, timeout=10)`** → excepción/timeout → `unknown` + `TIMEOUT` o `EXEC_ERROR`.
5. **Comparar salida** según `comparison`:
   - coincide → `verified`, confidence 1.0
   - difiere → `stale`, confidence 0.4
   - no evaluable (sin expected, salida vacía en contains) → `unknown`, confidence 0.2
6. **Escribir `verified: <hoy>`** solo si resultado es `verified` (para TTL futuro).

### Sin `shell=True` — invariante

Igual que `facts_engine.py` L56: `shell=False` siempre. No existe código de
project-state que invoque shell con string. El argumento `timeout=10` también se
hereda idéntico.

---

## SEMÁNTICA DE ESTADOS (A y B)

### Tipo A — máquina

| `status` | `confidence` | Cuándo ocurre |
|---|---|---|
| `verified` | 1.0 | `check` ejecuta y la salida coincide con `expected`. |
| `stale` | 0.4 | `check` ejecuta y la salida **difiere** de `expected`. |
| `unknown` | 0.2 | `check` no se puede ejecutar o evaluar (Q-04, §EJECUCIÓN). |
| `expired` | 0.2 | `check` fue verificado pero `(hoy − verified).days > ttl_days` (30, heredado de facts.yaml). |

**Transición `expired` → `verified`**: cuando el motor corre con `--update` y
el check resulta `verified`, actualiza `verified: <hoy>` — el próximo ciclo
tendrá TTL fresco. Esto es paralelo a `buffy-verify.sh --update-facts` que
regenera facts.yaml con fecha nueva.

### Tipo B — humano (no máquina)

| `status` | `confidence` | Cuándo ocurre |
|---|---|---|
| `judged` | 0.5–0.9 | Decisión o hipótesis registrada. |
| `pending` | 0.3–0.5 | A la espera de decisión o input adicional. |
| `disputed` | 0.2–0.4 | Desacuerdo sobre el valor. |

**El motor NUNCA modifica un assertion B** (salvo modo `--update`, y solo campos
de metadata como `verified` para reflejar fecha de última revisión manual).
`status` B solo cambia cuando un humano edita el archivo.

### Rechazo de verificación automática de B (Q-07 / D3)

Si `type: B` y `status: verified` → el motor lo detecta y lo reporta como
**`SCHEMA_VIOLATION_B_VERIFIED`** en stderr + JSON, pero **no lo clasifica**
(queda fuera de trust_project y human_assertions con conteo separado
`schema_violations`). Esto refuerza LINT-08 del Paso 2: el motor también rechaza,
no solo el linter.

---

## SALIDA

### Formato TSV (default)

Idéntico a `facts_engine.py` L7:

```
level<TAB>key<TAB>msg<TAB>id<TAB>target<TAB>real
```

| Campo | Contenido |
|---|---|
| `level` | `verified`/`stale`/`unknown`/`expired` (A) o `judged`/`pending`/`disputed` (B) |
| `key` | `key` de la aserción |
| `msg` | Mensaje de verificación (ej. "HEAD = a1b2c3d ✓") |
| `id` | ID de error opcional (`BINARY_MISSING`, `TIMEOUT`, etc.) |
| `target` | `project-state.yaml` (o `check.comparison` para debugging) |
| `real` | Salida real del comando (para provenance) |

### Formato JSON (`--json`)

```json
{
  "repo": "<repo_dir>",
  "verified": 0,
  "stale": 0,
  "unknown": 0,
  "expired": 0,
  "trust_project": 0.0,
  "human_assertions": {
    "judged": 0,
    "pending": 0,
    "disputed": 0,
    "total": 0
  },
  "schema_violations": [],
  "items": [
    {"level": "verified", "key": "main-branch-head", "message": "HEAD = a1b2c3d ✓", "target": "project-state.yaml", "real": "a1b2c3d"}
  ],
  "_info": "verificación de aserciones A de project-state.yaml — canal paralelo a buffy-verify (Q-03)"
}
```

**Contraste con `buffy-verify.sh --json`** (test-verify.sh L25):
| | buffy-verify | project-state-engine |
|---|---|---|
| Claves raíz | `repo, verified, stale, unknown, expired, trust_score, items, _info` | `repo, verified, stale, unknown, expired, **trust_project**, **human_assertions**, **schema_violations**, items, _info` |
| Scope | hostname | repo |
| Dominio | sistema vs INFO-core | assertions vs repo |

`trust_score` NO está en la salida de project-state (conflicto de semántica con
`trust_score` de buffy-verify). Se llama `trust_project` para evitar confusión.

### Fórmula `trust_project`

```python
trust_project = round(100 * verified_A / max(1, verified_A + stale_A + expired_A), 1)
```

- Numerador: solo aserciones A con `status == verified`.
- Denominador: A con `verified | stale | expired` — **excluye `unknown`** (Q-04
  dice que es 0.2, pero la fórmula de trust excluye unknown, igual que facts.yaml
  L343).
- B **no entra** al cálculo. `human_assertions` es aparte.

---

## LÍMITES DEL MOTOR (lo que NO hace)

| Límite | Por qué |
|---|---|
| **No resuelve conflictos A↔B** (Q-06) | El motor no tiene lógica para detectar contradicciones entre tipos. Si A dice `ci-green: verified` y B dice `strategy: "CI rota"`, el motor reporta ambos sin señalar el conflicto. Detección de conflictos es trabajo del linter o del operador. |
| **No integra con `buffy-verify.sh --json`** (Q-03) | Canal paralelo. No se modifica buffy-verify.sh. |
| **No promueve B a A** (S-06) | Solo un humano puede cambiar `type: B` → `type: A` y agregar `check`. |
| **No verifica hipótesis abiertas como A** (Q-05) | B con `status: pending` cubre decisiones esperando input; hipótesis abiertas son pending hasta que se cierren. |
| **No genera `project-state.yaml`** | Es un archivo versionado que el operador edita o llena con `--update` (futuro). |
| **No modifica `facts.yaml`** | Dominio separado. |
| **No sync con SNAPSHOT.md** (S-08) | Mecanismo de sincronización fuera de alcance de este diseño — es un riesgo reconocido en §SUPUESTOS PENDIENTES. |
| **No resuelve S-06/S-07** | Promoción B→A y granularidad de fecha son decisiones de implementación futura. |

---

## MODO `--update` (futuro)

Paralelo a `buffy-verify.sh --update-facts`:

| Campo A | Actualiza | Con |
|---|---|---|
| `verified` | fecha actual (`YYYY-MM-DD`) | solo si `status == verified` |
| `value` | salida real del comando | solo si `status == verified` |
| `status` | nuevo resultado | re-ejecuta check |
| `confidence` | 1.0 / 0.4 / 0.2 | mapeo facts.yaml |

**No actualiza** B (salvo `verified` como fecha de revisión manual si el operador
la toca). **No toca** `project.name` ni `project.version` automáticamente.

### Modo sin actualización (default)

Solo lee y reporta. El motor es **read-only** por defecto — misma filosofía que
`buffy-verify.sh` (verifica sin cambiar nada) vs `buffy-verify.sh --update-facts`
(modifica facts.yaml explícitamente).

---

## SUPUESTOS PENDIENTES DEL MOTOR

| ID | Supuesto | Riesgo |
|---|---|---|
| M-01 | El motor es un solo archivo Python en `scripts/lib/` (ej. `project_state_engine.py`) | S-01 aún no confirma nombre/ruta del YAML; el motor puede necesitar ajustar path de carga. |
| M-02 | El motor se invoca como `python3 scripts/lib/project_state_engine.py <repo_dir> [--json] [--update]` | Inseguro hasta Paso 5; diseño asume CLI similar a facts_engine. |
| M-03 | `comparison` soporta `exact`, `contains`, `regex`, `exists`, `exit_code` | Si se necesita otro (`numeric_range`, `set_membership`), se agrega al motor sin tocar el esquema (mismo patrón declarativo). |
| M-04 | `trust_project` no se consume en ningún dashboard todavía | Si buffy-doctor o buffy-verify lo necesitan, requiere integración explícita (y Q-03 se reabre). |
| M-05 | `timeout=10` es suficiente para todos los checks de repo | Algunos checks (ej. `git fsck`) pueden exceder 10s — se marca `unknown` + `TIMEOUT`. |
| M-06 | B con `pending` cubre hipótesis abiertas (Q-05) | Si se necesita distinción explícita `hypothesis` vs `decision`, agregar un campo `subtype` a B en Paso 4 (linter) — no rompe esquema actual. |
| M-07 | No hay sync con SNAPSHOT (S-08) | **Riesgo más concreto** — dos fuentes de "estado del repo" pueden divergir. No resuelto aquí. |

---

## PREGUNTAS ABIERTAS REMANENTES (antes de implementar)

| # | Pregunta | Bloquea implementación? |
|---|---|---|
| Q-05 | ¿`pending` cubre hipótesis abiertas o necesita `subtype`? | No — M-06 lo deja como `pending` hasta que el linter lo resuelva. |
| Q-06 | ¿Motor reporta conflictos A↔B? | No — documentado como fuera de alcance. |
| Q-08 | **RESUELTO (2026-10-07): linter ANTES del motor.** El linter es validación estática barata (gate del pipeline); el motor conserva `schema_violations` como safety net standalone (defense en depth — dos capas independientes, no una secuencia obligada). | Resuelto |
| S-01 | Nombre exacto del archivo | No — asumido `ai-context/project-state.yaml`. |
| S-08 | Sync con SNAPSHOT | Sí — si es requerido, diseñar mecanismo de sync antes de Paso 5. |

---

## ESTADO FINAL

### Verificación de esta sesión

| Check | Resultado |
|---|---|
| `git status --short` | ✅ Solo `project-state-design.md` (untracked) + 3 `.local.md` pre-existentes |
| `git diff --stat` | ✅ Vacío — ningún tracked modificado |
| `facts.yaml` modificado | ✅ No — gitignored, no presente en working tree |
| `buffy-verify.sh` / `facts_engine.py` modificados | ✅ No — solo leídos |
| Archivo creado | ✅ `ai-context/project-state-engine-design.md` (nuevo, 0 código ejecutable) |
| Líneas citadas verificadas | ✅ facts_engine.py L7/L28/L31/L56; buffy-verify.sh L343; test-verify.sh L25 |

### Archivos en este paquete

| Archivo | Contenido | Git status |
|---|---|---|
| `ai-context/project-state-design.md` | Paso 2 — esquema (12 secciones) | Untracked |
| `ai-context/project-state-engine-design.md` | Paso 3 — motor (este documento) | Untracked |

### Secuencia confirmada (reordenada 2026-10-07)

- ✅ Paso 2 — esquema (cerrado)
- ✅ 5 bloqueantes resueltas (Q-03/Q-04/Q-07/S-04/S-05)
- ✅ Paso 3 — diseño del motor (este documento)
- ✅ Q-08 resuelto: **linter ANTES** del motor
- ⏭ **Paso 6 — experimento a mano** (reordenado 2026-10-07): `project-state.yaml` escrito a mano sobre el esquema del Paso 2 + agente nuevo con solo ese archivo y una tarea. Valida el riesgo mayor (¿el esquema sirve al agente?) ANTES de construir infraestructura. Responde de paso la pregunta "cómo se puebla el primer YAML" (respuesta: a mano = UX validada).
- ⏭ Paso 4 — diseño del linter (mismo patrón: documento, no código)
- ⏭ Paso 5 — implementación real (motor + linter)

**Por qué el reordenamiento** (decisión tomada 2026-10-07): motor y linter son
infraestructura al servicio de la hipótesis "agente trabaja con project-state.yaml".
Validar la hipótesis antes de construir invierte el orden de riesgo: si el
experimento falla, ajustar esquema/motor = editar documentos; si falla después
de construir, sería reescribir infraestructura. Costo del reordenamiento ≈ 0
(pasos 2-3 ya son documentos).

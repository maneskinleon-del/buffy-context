# Diseño del esquema `project-state`

> **Paso 2 de project-state — ESQUEMA (diseño) · NO implementación.**
> No se crea motor, linter, código, ni archivo `project-state.yaml`.
> El entregable es este documento: descripción prosa + tabla de campos.
> Fecha de diseño: 2026-10-06.

---

## RESUMEN

`project-state` es un esquema para registrar **afirmaciones sobre el estado de un repo** — lo que el proyecto es, dónde está, qué se decidió — de forma estructurada, versionable y compartible por Git. Cada repo que Buffy trabaje lleva su propio `project-state.yaml` en `ai-context/`; el archivo viaja por Git (a diferencia de `facts.yaml`, que es local de instancia).

`project-state` responde a un vacío que `facts.yaml` no cubre: `facts.yaml` verifica propiedades del **sistema** (OS, kernel, herramientas) ejecutando comandos contra el sistema real y comparando con `INFO-core.md`. Un repo no tiene un "comando de verificación" equivalente — no existe una orden que diga "el estado del proyecto es X". Por eso `project-state` **hereda la convención de campos** de `facts.yaml` (D2) pero **no su mecanismo de verificación**.

### Tres decisiones fijas (D1/D2/D3 — no se reabren)

| Decisión | Qué establece | No es |
|---|---|---|
| **D1** — alcance por-repo | Un `project-state` por repo; versionable; asociado al proyecto. | No es replacement de `PROJECTS.local.md`; no es global; no es por-instancia. |
| **D2** — archivo nuevo con motor propio | Nuevo archivo (`project-state.yaml`); semántica prestada de `facts.yaml` donde aplica, pero el mecanismo de validación puede diferir. | No reutiliza el motor de `facts_engine.py` ni `buffy-verify.sh`. |
| **D3** — dos tipos de aserción | **A** = machine-verifiable (HEAD, existencia de archivos, estado de tests/CI, cantidades, existencia de config). **B** = juicio humano (decisiones arquitectónicas, hipótesis descartadas, estrategia acordada, decisiones pendientes). | B **no** se presenta como "verificado" automáticamente. |

### Relación con artefactos existentes

| Artefacto | Dominio | Localidad | Verificación |
|---|---|---|---|
| `facts.yaml` | Propiedades del sistema (OS, tools, WM) | Local de instancia (gitignored) | Comando del sistema vs `INFO-core.md` |
| `project-state.yaml` | Afirmaciones sobre el estado del repo | Versionable (shared por Git) | Esquema de aserción A/B (propio motor) |
| `INFO-core.md` | Perfil del operador | `.local.md` override | Verificado por `buffy-verify.sh` |
| `CONTINUE.md` | Handoff local de instancia | Local (gitignored) | Ninguna (es handoff) |

### Alcance de este documento (Paso 2)

- ✅ Diseña el esquema de campos, sus tipos, semántica y límites.
- ✅ Relaciona el esquema con `facts.yaml` (herencia) y `SIGNAL-STATE-COUPLING-FAILURES.md` (principio P2).
- ❌ No implementa: motor, linter, reglas de validación ejecutables, archivo `project-state.yaml`.

---

## ESTRUCTURA

### Archivo propuesto

- **Ruta**: `<repo_root>/ai-context/project-state.yaml` (por repo).
- **Formato**: YAML (consistente con `facts.yaml` y `facts_rules.yaml`).
- **Topología**: dos bloques de nivel superior.

```yaml
project:          # metadata del documento
  name: <repo>    # scope (heredado de facts.yaml.scope, semántica adaptada)
  version: <ISO date>  # fecha de esta captura
assertions:
  - <afirmación 1>
  - <afirmación 2>
```

### Tabla de campos

| Campo | Tipo | Requerido | Tipo A (machine) | Tipo B (human) | Heredado de `facts.yaml` | Descripción |
|---|---|---|---|---|---|---|
| `key` | string | ✅ | identificador único dentro del repo | idem | ❌ (nuevo) | Nombre clave de la aserción (ej. `main-branch-head`, `ci-passing`, `arch-decision-mvc`). |
| `type` | enum `A\|B` | ✅ | `A` | `B` | ❌ (nuevo — distingue mecanismo) | A=machine-verifiable; B=human judgment. **B nunca es "verified".** |
| `value` | any | ✅ | valor observado (string, bool, int) | valor afirmado | ✅ (facts.yaml) | Lo que se afirma. |
| `source` | enum `system\|user\|inferred` | ✅ | `system` (observado) o `inferred` | `user` o `inferred` | ✅ (facts.yaml L213-227) | Origen del assertion. |
| `confidence` | float 0.0–1.0 | ✅ | 1.0 verified / 0.4 stale / 0.2 unknown | 0.2–0.9 (según consenso) | ✅ (facts.yaml L213-227) | Nivel de confianza. **B: nunca 1.0 por verificación automática.** |
| `status` | enum | ✅ | `verified\|stale\|unknown\|expired` | `judged\|pending\|disputed` | ✅ (facts.yaml) | Estado de verificación o juicio. **B: nunca `verified`.** |
| `verified` | date `YYYY-MM-DD` | ✅ | fecha de última verificación machine | fecha de último juicio humano | ✅ (facts.yaml) | Marca de tiempo de la última actualización de estado. |
| `scope` | string | ✅ | nombre del repo | nombre del repo | ✅ (facts.yaml, *adaptado*) | Siempre el repo. facts.yaml usa hostname; project-state usa repo (D1). |
| `ttl_days` | int | opcional | 30 | 30 | ✅ (facts.yaml — siempre 30) | Tiempo antes de reconsiderar. Heredado para consistencia. |
| `evidence` | string | ✅ | comando, hash, URL de CI, path | decisión, notas, enlace a discusión | ❌ (nuevo) | Referencia a la prueba que sustenta la aserción. |
| `check` | object | ⚠️ | **requerido** (es la "gate") | **prohibido** | ❌ (nuevo) | Especificación de cómo verificar (comando, path, expected). |
| `notes` | string | opcional | contexto adicional | idem | ❌ (nuevo) | Comentario libre. |

#### Restricciones cruzadas entre tipo y campo

| Regla | Aplica a | Motivo |
|---|---|---|
| `check` es **requerido** | Tipo A | Sin `check`, una aserción machine-verifiable no tiene gate → riesgo de "marks without gates" (ver §LÍMITES). |
| `check` está **prohibido** | Tipo B | B no es machine-verifiable por definición (D3). |
| `status` puede ser `verified` | Tipo A | Machine-verificable sí. |
| `status` **nunca** es `verified` | Tipo B | D3: B se presenta como juicio, no como verificación automática. |
| `confidence: 1.0` | Tipo A, status=verified | Consistente con facts.yaml (1.0 = verified). |
| `confidence: 1.0` **prohibido** como default | Tipo B | La confianza en juicio humano no alcanza 1.0 por automatismo. |

### Ejemplo estructural (no es un archivo real)

```yaml
project:
  name: buffy-context
  version: 2026-10-06

assertions:
  # ── Tipo A: machine-verifiable ──────────────────────
  - key: main-branch-head
    type: A
    value: a1b2c3d
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-06
    scope: buffy-context
    ttl_days: 30
    evidence: "git rev-parse HEAD"
    check:
      command: [git, rev-parse, HEAD]
      comparison: exact

  - key: ci-green
    type: A
    value: true
    source: system
    confidence: 1.0
    status: verified
    verified: 2026-10-06
    scope: buffy-context
    ttl_days: 30
    evidence: "GH Actions run 36781193116 — conclusion: success"
    check:
      command: [gh, run, list, --limit, 1, --json, conclusion, --jq, '.[0].conclusion']
      comparison: exact
      expected: "success"

  # ── Tipo B: human judgment ───────────────────────────
  - key: arch-decision-mvc
    type: B
    value: "MVC pattern approved for new features"
    source: user
    confidence: 0.9
    status: judged
    verified: 2026-10-03
    scope: buffy-context
    ttl_days: 30
    evidence: "SESION.md 2026-10-03 — entrada de sesión"
    # NOTE: no hay campo 'check' — B no es machine-verificable (D3)
```

---

## JUSTIFICACIÓN POR CAMPO

Cada campo se justifica en función de: (a) precedente en `facts.yaml`, (b) necesidad
propia de `project-state`, o (c) restricción del esquema de tipos A/B (D3).

### Campos heredados de `facts.yaml` (riesgo de duplicación (a) resuelto por reusión, no por invención)

| Campo | Precedente | Adaptación | Justificación |
|---|---|---|---|
| `value` | facts.yaml: el valor real observado | idéntico | El assertion necesita un *qué* afirmar; es el núcleo del hecho. |
| `source` | facts.yaml L213 (`system`/`user`/`inferred`) | idéntico | `source` distingue hecho observado (system) de preferencia (user) e inferencia. Sin él, confidence es imposible de interpretar. |
| `confidence` | facts.yaml L213-227 (1.0/0.4/0.2) | idéntico *escala* | La escala 0-1 con puntos 1.0/0.4/0.2 es parte del contrato de facts.yaml. Reusarla evita inventar una escala paralela (riesgo de duplicación (a)). Para tipo B, la escala sigue siendo 0-1 pero el punto 1.0 está reservado. |
| `status` | facts.yaml (`verified`/`stale`/`unknown`/`expired`) | **A**: idéntico; **B**: `judged`/`pending`/`disputed` | Tipo A hereda los mismos valores para coherencia con facts.yaml. Tipo B usa valores que **nunca** dicen "verified" (D3). |
| `verified` | facts.yaml: fecha de verificación | idéntico | Marca de tiempo de la última operación de estado. En facts.yaml se serializa con `date +%F`; aquí se requiere el mismo formato. |
| `scope` | facts.yaml L49: hostname | **repo** (no hostname) | facts.yaml usa hostname porque verifica el *sistema*; project-state usa el *repo* porque D1 lo define. La adaptación se documenta explícitamente. |
| `ttl_days` | facts.yaml: siempre 30 | idéntico (30) | Consistencia con facts.yaml. No se inventa un TTL distinto — el valor 30 es parte del contrato. |

### Campos nuevos (no en `facts.yaml` — no heredables)

| Campo | Tipo A | Tipo B | Justificación |
|---|---|---|---|
| `key` | requerido | requerido | Identificador único dentro del repo. facts.yaml no necesita `key` porque el nombre del hecho (*fact name*) lo es; project-state agrupa múltiples aserciones en un array y necesita un identificador. |
| `type` | `A` | `B` | **El campo que distingue A de B** (D3). Sin él, el motor no sabe si puede o no machine-verificar. No existe en facts.yaml porque facts.yaml asume que TODO es machine-verificable — project-state introduce explícitamente juicio humano. |
| `evidence` | requerido | requerido | Referencia a la prueba. facts.yaml registra el valor pero no la evidencia concreta; project-state exige trazabilidad (SIGNAL-STATE-COUPLING: anti-false-success, convención `[orig]`/`[verificado]`). |
| `check` | **requerido** (gate) | **prohibido** | Especificación de verificación para tipo A. **Es la "gate" que resuelve el riesgo de duplicación (b): "marks without gates"**. Sin `check`, una aserción A no se puede verificar → no debería existir. Para tipo B está prohibido: B no es machine-verificable. |
| `notes` | opcional | opcional | Comentario libre. No afecta el esquema. |

### Restricciones de integridad (no heredables — son del tipo A/B)

1. **`type` obliga `check`**: si `type: A` → `check` debe estar presente. Si `type: B` → `check` debe ausentarse.
2. **`type` obliga `status`**: si `type: B` → `status` no puede ser `verified`.
3. **`confidence` en B**: `confidence: 1.0` requiere `source: system` y `type: A` — en B, `confidence` se expresa sobre juicio, no sobre verificación automática.

---

## HERENCIA DE FACTS.YAML

`project-state` hereda **convención de campos y escalas** de `facts.yaml`, pero **no su mecanismo de verificación**. Esta distinción nace del **límite estructural** identificado en Paso 1:

> `facts.yaml` verifica afirmaciones comparando la salida de un **comando del sistema** contra lo que afirma `INFO-core.md`. Un repo no tiene un "comando de verificación" — no existe una orden que produzca "el estado del proyecto es X". Por tanto, `project-state` hereda los campos pero **no** el mecanismo de verificación.

### Campos heredados (y cómo se adaptan)

| Campo | facts.yaml (mecanismo) | project-state (semántica adaptada) |
|---|---|---|
| `value` | salida del comando del sistema | valor afirmado sobre el repo |
| `source` | `system` (comando) / `user` / `inferred` | **mismo vocabulario** (LOAD_CONTEXT.md L119-139): `system` = observado del repo (git, archivo, CI), `user` = dicho por el operador, `inferred` = derivado |
| `confidence` | 1.0/0.4/0.2 (verificado/stale/unknown) | **misma escala** — A: 1.0 verified, 0.4 stale, 0.2 unknown; B: 0.2-0.9 según consenso humano |
| `status` | `verified`/`stale`/`unknown`/`expired` | A: **mismo vocabulario**; B: `judged`/`pending`/`disputed` (nunca `verified`) |
| `verified` | `date +%F` (buffy-verify.sh) | **mismo formato ISO date** (`YYYY-MM-DD`) |
| `scope` | hostname (`buffy-verify.sh --scope`, L49) | **repo** — adaptación D1. `hostname` era el scope de un *sistema*; project-state abarca un *repo*. |
| `ttl_days` | 30 (siempre, L213) | **30** — sin excepción. La regla "ttl_days always 30" se hereda como invariante. |

### Mecanismo NO heredado: la verificación por comando

`facts_engine.py` (L120) ejecuta reglas de `facts_rules.yaml` con `subprocess.run(argv, shell=False)`, rechaza `SHELL_METACHARS` (`;&|`$<>(){}[]*?~!'\" \t\n` — L30), extrae versiones y compara contra `INFO-core.md`. El motor es **genérico y extensible**: agregar un hecho = editar `facts_rules.yaml`, no tocar el motor (LOAD_CONTEXT.md).

`project-state` **no** reutiliza este mecanismo porque:

1. **No hay archivo "INFO-core equivalente" para el repo.** `facts.yaml` compara contra `INFO-core.md` (el perfil del operador); project-state compara contra el *estado real del repo* (HEAD, archivos, CI) — pero no hay un documento canónico que afirme "HEAD = X" de forma declarativa.
2. **Las verificaciones son heterogéneas.** Tipo A puede verificar HEAD (`git rev-parse`), existencia de archivo (`test -f`), estado de CI (`gh run`), o count de tests. No hay una sola regla como en `facts_rules.yaml`.
3. **D2 lo exige**: "semántica prestada de facts.yaml **donde aplica**, pero el mecanismo de validación **puede diferir**."

### Jerarquía de sources: project-state en el contexto

Per `buffy-source.sh --resolve <fact>`, la jerarquía de autoridad es:

```
1. REAL-TIME SYSTEM  → comandos del sistema AHORA
2. FACTS (verified)  → facts.yaml con confidence 1.0 y TTL vigente
3. SNAPSHOT          → estado vivo (buffy-context.sh)
4. CONTINUE          → handoff de última sesión
5. INFO-core         → contexto base documentado
6. INFERRED          → sin dato: inferencia marcada
```

`project-state` **no figura en esta jerarquía** porque es *assertivo* (afirma sobre el repo), no *proveniente* (viene de una fuente de autoridad). Las aserciones de project-state pueden **alimentar** nivel 3 (SNAPSHOT) o **instruir** nivel 5 (INFO-core), pero no son una capa de la jerarquía de sources.

### Convención de trazabilidad aplicada

LOAD_CONTEXT.md L149+ establece: `[orig]` para heredado no re-verificado; `[verificado YYYY-MM-DD]` para comprobado contra el sistema. `project-state` adopta ambas marcas dentro del campo `evidence`:

- Tipo A: `evidence: "[verificado 2026-10-06] git rev-parse HEAD → a1b2c3d"`
- Tipo B: `evidence: "[orig] SESION.md 2026-10-03 — discusión arquitectura"`

---

## SEMÁNTICA VERIFIED

El campo `status` es el corazón del esquema de tipos A/B. Su semántica **no es uniforme** porque A y B tienen mecanismos de verificación distintos. La distinción responde directamente al **principio P2** de `SIGNAL-STATE-COUPLING-FAILURES.md`:

> **"La verificación es un objeto más."** Un assertion A es una señal que afirma algo del estado del repo; el pegamento entre señal y estado puede fallar (caso 7: cascada, caso 8: colisión). Tipo B, por su naturaleza, no tiene este acoplamiento — y **debe permanecer sin él**.

### Tipo A — machine-verificable

| `status` | `confidence` asociada | Condición |
|---|---|---|
| `verified` | 1.0 | El `check` produce resultado que confirma `value`. |
| `stale` | 0.4 | El `check` produce resultado que **difiere** de `value`. |
| `unknown` | 0.2 | El `check` no pudo ejecutarse (comando no disponible, error). |
| `expired` | 0.0 (sistema marca expirado) | El `ttl_days` (30) se ha cumplido desde `verified`; requiere reverificación. |

#### Adaptación del trust_score de facts.yaml

`buffy-verify.sh` L229 calcula: `trust_score = round(100 * verified / max(1, verified + stale + expired), 1)` — **excluye unknown**. `project-state` propondría el mismo cálculo **solo sobre aserciones A**, manteniendo la exclusión de `unknown`. Las aserciones B se cuentan por separado (ver §SUPUESTOS PENDIENTES).

### Tipo B — human judgment

| `status` | `confidence` típica | Condición |
|---|---|---|
| `judged` | 0.5–0.9 | Decisión o hipótesis registrada por un humano. |
| `pending` | 0.3–0.5 | A la espera de decisión o información adicional. |
| `disputed` | 0.2–0.4 | Hay desacuerdo sobre el valor; la aserción es incierta. |

#### Por qué B nunca es `verified` — el gate de integridad

La restricción **"B nunca es `verified`"** (D3) se resuelve con una doble defensa:

1. **Schema-level**: el vocabulario de `status` para B (`judged`/`pending`/`disputed`) no incluye `verified`. No es un valor válido.
2. **Lint-level** (ver §REGLAS DE VALIDACIÓN/LINT): el linter rechaza cualquier aserción B con `status: verified` o `confidence: 1.0` sin `source: system`.

Este gate es crítico: el riesgo (b) de "marks without gates" y el principio anti-false-success (LOAD_CONTEXT.md, convención `[verificado]`) exigen que una afirmación de juicio humano **nunca** parezca verificada por máquina.

### Paralela con facts.yaml

| Aspecto | facts.yaml | project-state Tipo A | project-state Tipo B |
|---|---|---|---|
| ¿Todo es machine-verificable? | ✅ Sí (todas las filas vienen de commands) | ✅ Sí (cada A tiene `check`) | ❌ No |
| ¿`status` incluye `verified`? | ✅ Sí | ✅ Sí | ❌ No |
| ¿`confidence` 1.0 implica máquina? | ✅ Sí | ✅ Sí | ❌ No (prohibido sin `source: system`) |
| ¿TTL aplicado? | ✅ Sí (30 días, L213) | ✅ Sí (30) | ✅ Sí (30) |

---

## EVIDENCIA

El campo `evidence` captura **qué prueba sustenta** una aserción. La representación diferencia A de B:

### Tipo A — evidencia verificable

| Formato de `evidence` | Ejemplo | Verificable por motor? |
|---|---|---|
| Salida de comando | `"git rev-parse HEAD → a1b2c3d"` | ✅ Sí — el motor puede re-run el comando. |
| Hash de commit | `"commit a1b2c3d (2026-10-03)"` | ✅ Sí — `git log --format=%H -1`. |
| Resultado de CI | `"GH Actions run 36781193116 — conclusion: success"` | ✅ Sí — `gh run view --json conclusion`. |
| Existencia de archivo | `"test -f ai-context/project-state.yaml → true"` | ✅ Sí — el motor puede testear el path. |
| Count de tests | `"test suite: 411 passed, 0 failed"` | ✅ Sí — re-run suite. |

La convención `[verificado YYYY-MM-DD]` de LOAD_CONTEXT.md L149+ se aplica a Tipo A:

```
evidence: "[verificado 2026-10-06] git rev-parse HEAD → a1b2c3d"
```

### Tipo B — evidencia documental

| Formato de `evidence` | Ejemplo | Verificable por motor? |
|---|---|---|
| Referencia a doc | `"SESION.md 2026-10-03 — discusión arquitectura"` | ❌ No — es texto documental. |
| Enlace a conversación | `"GH issue #23 — thread sobre estrategia"` | ❌ No directamente. |
| Meeting notes | `"nota de reunión 2026-10-01 — decisión adoptada"` | ❌ No. |
| Hipótesis descartada | `"Hipótesis X descartada — SESION.md 2026-09-30"` | ❌ No. |

La convención `[orig]` de LOAD_CONTEXT.md L149+ se aplica a Tipo B:

```
evidence: "[orig] SESION.md 2026-10-03 — entrada de sesión sobre estrategia"
```

### Diferencia clave: A puede volverse stale; B no

- **Tipo A**: el `value` puede volverse `stale` si el `check` falla en una re-verificación. El motor lo detecta automáticamente.
- **Tipo B**: el `value` puede volverse `disputed` si un humano lo reabre, pero **nunca** se vuelve `verified` ni `stale` — no hay un "estado real" contra el cual comparar un juicio. El cambio de status requiere intervención humana explícita (actualización del YAML).

Esto refuerza P2: la verificación de B es un objeto con su **propio** acoplamiento señal-estado ("el humano dijo X" vs "el humano acuerda X"), y que acoplamiento **no** es el mismo que el de A. No se confunden.

---

## LÍMITES DE CONTRATO

Los límites definen **qué proyecto-state es y qué no es** — críticos para resolver el riesgo de duplicación (c) solapamiento con otros artefactos.

### Límite 1: project-state ≠ facts.yaml

| Dimensión | facts.yaml | project-state |
|---|---|---|
| **Qué verifica** | Propiedades del sistema (OS, tools, WM) | Afirmaciones sobre el estado del repo |
| **Cómo verifica** | Comando del sistema vs `INFO-core.md` | `check` por aserción (tipo A) / juicio (tipo B) |
| **Localidad** | Local de instancia (gitignored) | Versionable (shared por Git) |
| **Scope** | hostname | repo |
| **Motor** | `facts_engine.py` + `buffy-verify.sh` | Motor propio (Paso 3+) |

### Límite 2: project-state ≠ PROJECTS.local.md

`PROJECTS.local.md` (registro local del operador sobre proyectos: cuáles están activos, notas personales) es **local de instancia** y **no versionable** (INSTANCE-STATE-DESIGN.md §3). `project-state.yaml` es **versionable** y **por-repo**.

- `PROJECTS.local.md` responde: "¿qué proyectos tengo yo en ESTA instancia?"
- `project-state.yaml` responde: "¿qué se afirma sobre ESTE repo?"

No son solapables: `PROJECTS.local.md` puede **referenciar** a `project-state.yaml` de un repo (ej. "el repo X tiene `ci-green: verified`"), pero no reemplázalo. El riesgo de duplicación (c) se mitiga: project-state no registra "qué proyectos existen" — solo "qué se afirma sobre un repo específico".

### Límite 3: project-state ≠ INSTANCE-STATE-DESIGN.md

INSTANCE-STATE-DESIGN.md §2-3 establece tres grupos: PROYECTO (shared), MEMORIA (sincronizable), INSTANCIA (local: SESION/CONTINUE/SNAPSHOT/facts.yaml). `project-state.yaml` pertenece al grupo **PROYECTO** — es un artefacto compartido del repo, versionable por Git. No es estado de instancia.

### Límite 4: project-state ≠ engine/linter (Paso 3+)

Este documento (Paso 2) **no** diseña el motor de verificación, ni el linter, ni las reglas ejecutables. Define el **esquema de campos** y **semántica**; la implementación (Paso 3+) decide cómo verifica tipo A y cómo registra tipo B.

### Límite 5: project-state no verifica código

`project-state` no es un sistema de análisis estático, ni un linter de código, ni un coverage report. Registra **afirmaciones** sobre el estado del repo (ej. "HEAD = a1b2c3d", "CI es verde", "se adoptó MVC"). Un assertion como "el código pasa lint" se refiere a un **resultado externo** (el linter real), no a project-state evaluando el código directamente.

---

## REGLAS DE VALIDACIÓN / LINT

Las reglas de validación son las **gates del esquema** (riesgo de duplicación (b): "marks without gates"). La lista es exhaustiva para Paso 2; la implementación ejecuta en Paso 3+.

### Reglas estructurales

| ID | Regla | Severidad |
|---|---|---|
| LINT-01 | `project.name` es string no vacío | error |
| LINT-02 | `project.version` es fecha ISO (`YYYY-MM-DD`) | error |
| LINT-03 | `assertions` es array | error |
| LINT-04 | Cada assertion tiene `key` único dentro del repo | error |
| LINT-05 | `type` ∈ {`A`, `B`} | error |

### Reglas de integridad A/B (el gate crítico)

| ID | Regla | Severidad | Motivo |
|---|---|---|---|
| LINT-06 | Si `type: A` → `check` está presente y es objeto | error | Sin `check`, A no se puede verificar → riesgo de "marks without gates". |
| LINT-07 | Si `type: B` → `check` **ausente** | error | B no es machine-verificable (D3). Un `check` en B es una contradicción. |
| LINT-08 | Si `type: B` → `status` ∉ {`verified`} | error | D3: B nunca es "verified". |
| LINT-09 | `confidence: 1.0` → requiere `source: system` y `type: A` | error | 1.0 implica verificación machine; B o `source: user` no la alcanzan. |
| LINT-10 | Si `type: A` y `status: verified` → `confidence` = 1.0 | error | Coherencia con facts.yaml (1.0 = verified). |
| LINT-11 | `ttl_days`, si presente, = 30 | error | Heredado de facts.yaml (L213: "siempre 30"). No se admite otro valor. |

### Reglas de coherencia de source

| ID | Regla | Severidad |
|---|---|---|
| LINT-12 | `source` ∈ {`system`, `user`, `inferred`} | error |
| LINT-13 | Si `source: system` → `type` = `A` (solo machine puede observar el sistema) | error |
| LINT-14 | Si `source: user` → `type` = `B` (lo que dice el operador es juicio) | advertencia |

### Inspiración en infraestructura existente

Las reglas LINT-01..LINT-14 siguen el patrón de los tests de `test-verify.sh` (L31, L295-319): el test `test_verify_json_schema` asserta que las claves JSON exactas son `{repo, verified, stale, unknown, expired, trust_score, items, _info}` — la misma precisión se aplica aquí. La convención de tabla en `INSTANCE-STATE-DESIGN.md` §9 (verificación con tests de sandbox) y `SIGNAL-STATE-COUPLING-FAILURES.md` §4 (test de cierre de día que asserta no-versionado) son el patrón: **cada regla de lint debe tener un test que asserter su violación**.

---

## LO QUE NO CUBRE

### 1. facts.yaml provenance (sistema → sistema)

`facts.yaml` verifica propiedades del **sistema operador** (OS, kernel, WM, shell, herramientas). project-state no toca esto — es dominio de `buffy-verify.sh` + `facts_engine.py` + `facts_rules.yaml`. Si se necesita saber "¿qué versión de node tengo?", se consulta facts.yaml, no project-state.

### 2. Estado de instancia

`CONTINUE.md`, `SESION.md`, `SNAPSHOT.md`, `.sync-state` son estado de instancia por la convención de `INSTANCE-STATE-DESIGN.md` §3 — locales, no versionables. project-state no registra ni consume este estado; si una aserción A necesita el snapshot de procesos, se refiere a `SNAPSHOT.md` en `evidence`, no lo duplica.

### 3. Motor de verificación y linter (Paso 3+)

Este documento define el **esquema** y **semántica**, no el **engine**. No especifica:
- Cómo `facts_engine.py`-equivalente ejecuta `check.command` (shell=False? metachar rejection?).
- Cómo se integra con `buffy-verify.sh` (¿project-state assertions aparecen en el JSON output?).
- Cómo se calcula un `trust_score` project-state (ver §SUPUESTOS PENDIENTES).
- Cómo se promueve una aserción B a tipo A tras una decisión (el mecanismo de promoción es Paso 3+).

### 4. Evaluación de código

project-state no es un linter, static analyzer, ni coverage tool. No inspecciona código fuente. Un assertion como `"arch-decision-mvc"` documenta **qué se decidió**, no **qué código cumple** — el cumplimiento se verifica por separado (tests, CI, code review).

### 5. Comunicación entre agentes o instancias

project-state no es un protocolo de handoff ni un mecanismo de sincronización. No define cómo un assertion A verificado en una instancia se comunica a otra. Eso es del dominio de `CONTINUE.md` (handoff) y `MEMORY/` (curated memory), no de project-state.

---

## SUPUESTOS PENDIENTES

Estos supuestos se marcan como **pendientes** porque el esquema los referencia pero Paso 2 no los resuelve — se dejan para Paso 3+ (implementación) o para una sesión posterior.

| ID | Supuesto | Riesgo si se invalida |
|---|---|---|
| S-01 | El archivo se llama `project-state.yaml` y vive en `ai-context/` al root del repo | Si el nombre cambia, todas las referencias a `evidence` y `check` deben actualizarse. |
| S-02 | `ttl_days` siempre es 30, igual que facts.yaml | La regla "ttl_days always 30" (buffy-verify.sh L213) es parte del contrato del sistema. Permitir otro valor introduce una escala paralela. |
| S-03 | `scope` = nombre del repo (no hostname) es suficiente | Si un repo se trabaja desde múltiples contexts (forks, branches), `scope` podría necesitar granularidad adicional. |
| S-04 | `check.command` es una lista de args (como `facts_rules.yaml`) | Si se acepta string con shell, se abre el riesgo de metacharacters (SHELL_METACHARS de facts_engine.py L30). Se asume lista para ser consistente. |
| S-05 | Un `trust_score` para project-state se calcula solo sobre aserciones A, igual que el de facts.yaml excluye `unknown` | Si se incluyen B en el cálculo, el trust_score mezcla tipos incompatibles. Se propone: `trust_project = round(100 * verified_A / max(1, verified_A + stale_A + expired_A), 1)` — B se reporta como `human_assertions`. |
| S-06 | Las aserciones B pueden "promocionarse" a A si se añade un `check` | Esto requiere mecanismo explícito (Paso 3+), no una edición casual del YAML. |
| S-07 | `verified` usa formato `YYYY-MM-DD` (igual que facts.yaml) | Si se requiere granularidad de horas, el formato cambia y la comparación con facts.yaml se rompe. |
| S-08 | project-state se genera/combina con `buffy-context.sh` (SNAPSHOT) | Si project-state escribe en el repo pero SNAPSHOT vive en buffy-context, hay una brecha de sincronización. |

### Supuesto crítico: no hay verificación automática de B

S-06 contiene el supuesto más delicado: **una aserción B no puede ser "promovida" a verified por un motor**. Si el operador edita el YAML y pone `type: A` + `check`, el motor debe verificarlo — pero si pone `type: B` + `status: verified`, el linter (LINT-08) debe rechazarlo. Este gate es el que protege la integridad semántica de D3.

---

## PREGUNTAS ABIERTAS

| # | Pregunta | Impacto |
|---|---|---|
| Q-01 | ¿Debe project-state tener un `trust_score` propio, o basta con el de facts.yaml? | Afecta cómo se reporta confianza al operador. Ver S-05. |
| Q-02 | ¿Cómo se versiona project-state dentro del repo? ¿Commit automático, o manual? | Si es automático, el motor necesita git write access al repo (riesgo de colisión con commits del operador). |
| Q-03 | ¿Las aserciones A de project-state aparecen en la salida JSON de `buffy-verify.sh --json`? | Si sí, afecta los conteos `verified`/`stale`/`trust_score` del JSON (test-verify.sh L31 asserta claves exactas). Si no, project-state es un canal paralelo. |
| Q-04 | ¿Qué sucede con `check.command` si el comando no existe en la máquina del verificador? | facts.yaml marca `unknown`; project-state debe decidir: `unknown` (machine no disponible) o `stale` (el assertion no se pudo verificar). |
| Q-05 | ¿Debe project-state registrar hipótesis **abiertas** (no solo descartadas)? | D3 menciona "hipótesis descartadas" pero no "hipótesis abiertas". Tipo B con `status: pending` podría cubrirlo, pero necesita aclaración semántica. |
| Q-06 | ¿Cómo se resuelve el caso donde una aserción A y una B se contradicen? (ej. A dice `ci-green: verified` pero B dice `strategy: "CI rota, no confiar"`) | Project-state no define un mecanismo de resolución de conflictos entre tipos. |
| Q-07 | ¿El motor de project-state rechaza metacharacters en `check.command` igual que facts_engine.py L30? | Sí se propone, pero D2 dice "validation mechanism puede diferir" — necesita decisión explícita. |

---

## ESTADO FINAL

### Estado actual del diseño (Paso 2)

| Aspecto | Estado |
|---|---|
| Esquema de campos | ✅ Diseñado (tabla §ESTRUCTURA) |
| Tipos A/B y restricciones cruzadas | ✅ Diseñados (§JUSTIFICACIÓN, §SEMÁNTICA VERIFIED) |
| Herencia de facts.yaml | ✅ Documentada (§HERENCIA) — campos reusados, mecanismo NO heredado |
| Evidencia y convención de trazabilidad | ✅ Diseñada (§EVIDENCIA) |
| Límites de contrato | ✅ Definidos (§LÍMITES) — 5 límites contra solapamiento |
| Reglas de validación/lint | ✅ Especificadas (§REGLAS DE VALIDACIÓN/LINT) — 14 reglas |
| Non-coverage | ✅ Documentado (§LO QUE NO CUBRE) — 5 límites |
| Supuestos pendientes | ✅ Enumerados (§SUPUESTOS PENDIENTES) — 8 supuestos |
| Preguntas abiertas | ✅ Listadas (§PREGUNTAS ABIERTAS) — 7 preguntas |

### Archivos creados en esta sesión

| Archivo | Propósito | Git status |
|---|---|---|
| `ai-context/project-state-design.md` | Este documento (diseño Paso 2) | Untracked (nuevo) |

### Archivos NO creados (intencional — Paso 2 es diseño-only)

| Archivo / artefacto | ¿Por qué no? |
|---|---|
| `project-state.yaml` (en algún repo) | D2: "new file with own engine" — el file se diseña, no se crea. |
| Motor de verificación | Paso 3+ (no Paso 2). |
| Linter ejecutable | Paso 3+ (no Paso 2). |
| `facts.yaml` | No se toca — es local de instancia; este diseño NO modifica facts.yaml. |

### Verificación del entorno

- ✅ El archivo objetivo (`project-state-design.md`) **no existía** al inicio (verificado con `ls` en sesión previa).
- ✅ `facts.yaml` **no fue modificado** — este diseño es read-only sobre el sistema real.
- ✅ No se creó código, engine, linter, ni `project-state.yaml`.
- ✅ El diseño se fundamenta en hechos verificados:
  - facts.yaml schema: `buffy-verify.sh` L213-227 (`value, source, confidence, status, verified, scope, ttl_days`), test-verify.sh L31 (JSON keys exactas), test-verify.sh L308 (TTL enforcement).
  - facts_engine.py: `subprocess.run(argv, shell=False)` L120, `SHELL_METACHARS` L30.
  - facts_rules.yaml: `version_checks` + `tool_checks` con `name` + `command` (lista).
  - LOAD_CONTEXT.md: jerarquía de sources L119-139, `[orig]`/`[verificado]` L149+.
  - README.md: 411/405/395/389 totales.
  - INSTANCE-STATE-DESIGN.md: contrato local vs shared §2-3.
  - SIGNAL-STATE-COUPLING-FAILURES.md: 9 instancias, P1/P2/P3, P2 "verification is an object too".

# Experimento PASO 6 — validación manual del esquema con agente fresco

> **Estado: EJECUTADO (2026-10-11)** — evidencia en §4-§5. Cierre del criterio 3 de §8 (linter) / §0 (plan).
> Autoridad: misión del operador 2026-10-11 §4 ("Paso 6: experimento manual"). **No es implementación del Paso 5** (criterio 4 = aprobación del Paso 4).
> **Actualización 2026-10-13**: Paso 4 **APROBADO** y Paso 5 **AUTORIZADO** por el operador — ver §9.

## 1. Hipótesis y criterios de observación

**Hipótesis:** un agente que recibe **solo** `project-state.yaml` (sin explicaciones del implementador) interpreta estado, aserciones, evidencias y limitaciones, y toma decisiones operativas correctas sin asumir verificado lo que no lo está.

Criterios (los 6 de la misión §4):
1. Fixture escrito a mano sobre el esquema documentado → §2.
2. Agente nuevo con solo ese archivo y contexto mínimo → §3.
3. Tarea realista, acotada y verificable → §3.
4. Observar interpretación de estado/aserciones/evidencias/limitaciones → §5.
5. Registrar errores de comprensión, ambigüedades y contradicciones → §6.
6. ¿Permite decisiones operativas correctas sin explicaciones ocultas? → §5.5.

## 2. Fixture (`ai-context/project-state.yaml`)

- 8 aserciones (5 tipo A, 3 tipo B), todos los valores **verificados con comandos reales hoy**:
  - `git rev-parse HEAD` → `74a6374ec2cc592d9d9ab2d213b6ccc00f34a8c1` (exit 0)
  - `gh run list --limit 1 --json conclusion` → `success` (exit 0; `gh` autenticado)
  - `test -f README.md` → exit 0; `git status --porcelain` → **7 entradas** (árbol sucio hoy)
  - Árbol limpio al cierre 2026-10-10 → aserción `repo-tree-clean-at-last-close` **stale** hoy (truthful)
  - `scripts/lib/project_state_linter.py` **no existe** → aserción `project-state-linter-passes` **unknown**
- Contrato de `check` seguido del Paso 3 §EJECUCIÓN (lista estricta S-04, `expected` obligatorio en exact/contains, `exists`/`exit_code` autocontenidos). El arg `.[0].conclusion` se evitó a propósito → ver hallazgo H-1.
- **Validación ad-hoc** (`/tmp/check_fixture.py`, script descartable — **NO es el linter del Paso 5**):
  `FIXTURE_CHECK_EXIT=0` — fixture 0 errores · control negativo **5 detecciones** (A sin check, B `verified`, exact/contains sin expected ×2, metacarácter). Primer intento del check daba FAIL por bug propio (lista global compartida `errors is bad2`) → **corregido el check, no el fixture**.

## 3. Procedimiento (aislamiento)

- Entrada exacta: `/tmp/paso6_task.txt` (134 líneas) = enunciado de 6 preguntas + **íntegro** `project-state.yaml`. Sin acceso al repo, sin documentación del esquema, sin explicaciones del implementador.
- Cada run = sesión fresca (proceso nuevo), temperatura 0 donde el runtime lo permite.
- Tarea (idéntica en todos los runs): commit de main · listar verificadas/no-verificadas con motivo · ¿confiar en árbol limpio? · decisiones humanas vs pendiente · ¿ejecutar linter / publicar cambios? · ambigüedades.
- Respuesta esperada (ground truth) definida **antes** de ejecutar: HEAD correcto; 3 verified + 1 stale + 1 unknown + 3 B; NO confiar en el árbol (stale); 2 judged + 1 pending; linter no ejecutable; publicar = decisión manual del operador.

## 4. Evidencia de ejecución (3 runs)

| Run | Modelo / runtime | Comando | Exit | Resultado |
|---|---|---|---|---|
| 1 | `gemma:2b` (local, ollama) | `timeout 240 ollama run gemma:2b < /tmp/paso6_task.txt` | **0** | **2/6** — ✅HEAD (hash exacto) ✅linter ausente · ❌3: "el árbol está limpio" (ignora `stale`) · ❌4: "no hay decisiones humanas" (ignora las 3 B) · ❌6: sin ambigüedades reales. Salida en `/tmp/paso6_run1.out` |
| 2 | `qwen2.5:7b` (local, ollama) | `timeout 300 ollama run qwen2.5:7b < …` | **124 (timeout)** | Parcial correcto (HEAD + razón citando `key`/`value`/`status`) antes del corte. **Límite de hardware local**, no del esquema. Salida en `/tmp/paso6_run2.out` |
| 3 | `nvidia/nemotron-3-ultra-550b-a55b:free` (OpenRouter, **cost=0** verificado en `usage`) | `POST /api/v1/chat/completions`, temp 0, max_tokens 2500 (`/tmp/or_run.py`) | **0** | **6/6** — ver §5. Salida en `/tmp/paso6_run3.out` |

Preflight: `ollama list` local/cloud inventariado; OpenRouter `HTTP=200` y 15 modelos `:free` antes de gastar nada; modelo elegido `:free` → costo 0.

## 5. Evaluación RUN 3 (punto a punto)

| # | Criterio | Resultado | Evidencia textual |
|---|---|---|---|
| 5.1 | Commit/HEAD | ✅ | `74a6374…c1` citando `value` de `main-branch-head`, `status: verified`, `evidence` y `check.comparison: exact` |
| 5.2 | Verificadas vs no | ✅ | 3 A verified; `stale` con motivo correcto ("el valor afirmado ya no refleja la realidad"); `unknown` con motivo correcto — **"unknown significa que el check no pudo correr, no que haya fallado"**; las 3 B fuera de verificación máquina citando D3 |
| 5.3 | ¿Árbol limpio? | ✅ | **"No se puede confiar"** — `value: true` vs `status: stale`, "su check hoy devolvería ≠ 0" |
| 5.4 | Decisiones humanas | ✅ | 2 `judged` (Q-02, S-08) + 1 `pending` (`paso4-approval`) citadas literal |
| 5.5 | Operaciones pedidas | ✅ | linter: "no es posible… el archivo no existe" · publicar: "no se puede — Q-02 versionado manual (decide el operador) + árbol sucio + aprobación pendiente" → **decisión correcta sin explicaciones ocultas** |
| 5.6 | Ambigüedades | ✅ | 6 hallazgos reales — ver §6 |

Gradiente: `gemma:2b` FALLA (2/6) → `qwen2.5:7b` timeout con parcial correcto → `nemotron-3-ultra-550b` PASS (6/6). **La capacidad del modelo es variable experimental, no propiedad del esquema.**

## 6. Hallazgos (defectos de contrato/semántica — NO resueltos unilateralmente)

| ID | Hallazgo | Evidencia | Estado |
|---|---|---|---|
| **H-1** | El ejemplo `ci-green` del Paso 2 §ESTRUCTURA usa `--jq '.[0].conclusion'` — **RECHAZADO por `SHELL_METACHARS` heredado (Q-07)**: ese ejemplo jamás podría verificarse | probe: `normalize_command` → `RECHAZADO: argumento con metacaracteres de shell: '.[0].conclusion'` | **Corregida documentalmente (2026-10-12)** — ejemplo `ci-green` de Paso 2 corregido a comando seguro + `comparison: contains` con `expected` explícito (verificado con salida real y control negativo `failure`: sin falso positivo); cita `gh run view` sin run-id corregida (§EVIDENCIA). `SHELL_METACHARS` intacto. |
| **H-2** | El ejemplo `main-branch-head` del Paso 2 carece de `expected`; el Paso 3 (L172) dice que exact sin expected → `unknown` "no evaluable" | Paso 2 L~100 vs Paso 3 §check | **Corregida documentalmente (2026-10-12)** — `expected: a1b2c3d` añadido al ejemplo (en captura, `expected == value`); §SEMÁNTICA VERIFIED ahora declara que la comparación es contra `check.expected`. 2ª pasada (misma fecha): comando del ejemplo a `git rev-parse --short=7 HEAD` para que `exact` pueda coincidir con el hash abreviado (control positivo/negativo verificados con salida real). Sin regla LINT-20 (fuera de alcance). Verificación final + controles en §6.1. |
| **H-3** | Semántica observada como confusa por el agente: (a) `verified` con `status: unknown` (¿fecha de qué?), (b) `value` no refleja la realidad en `stale` (hasta `--update`) | RUN3 §6 | **Corregida documentalmente (2026-10-12)** — `status` = resultado del último intento (`verified`/`stale`/`unknown`) o estado derivado del TTL (`expired`, sin ejecutar el check); `verified` = fecha de la última verificación **exitosa** (o de registro si nunca la hubo); intento no ejecutable → `unknown` + fecha conservada, lo que **no** implica vigencia ni éxito (Paso 2 tabla + §SEMÁNTICA VERIFIED + Paso 3 paso 6/etapa TTL). Verificación en §6.1. |

### 6.1 Evidencia de la ronda de revisión (2026-10-12) — previa a solicitar la aprobación del Paso 4

**H-2 — comprobaciones con salida real (HEAD `74a6374…`):**

```bash
$ git rev-parse HEAD            # hash completo — 40 chars
74a6374ec2cc592d9d9ab2d213b6ccc00f34a8c1
$ git rev-parse --short=7 HEAD  # salida abreviada — 7 chars (coherente con value/expected)
74a6374
$ normalize_command(['git','rev-parse','--short=7','HEAD'])   # facts_engine.py (heredado Q-07)
['git', 'rev-parse', '--short=7', 'HEAD']   # ACEPTADO — sin SHELL_METACHARS (el '=' no es metacaracter)
```

- **Control positivo (coincidencia):** `command: [git, rev-parse, --short=7, HEAD]` con `expected: 74a6374` == salida → `comparison: exact` **coincide** → `verified` (1.0). Reproducible: `salida=$(git rev-parse --short=7 HEAD); [ "$salida" = "74a6374" ]` → **exit 0**.
- **Control negativo (divergencia):** mismo comando con `expected: a1b2c3d` → **diverge** → `stale` (0.4). Reproducible: `[ "$(git rev-parse --short=7 HEAD)" = "a1b2c3d" ]` → **exit 1**; y el defecto original: `[ "$(git rev-parse HEAD)" = "a1b2c3d" ]` → **exit 1** (40 vs 7 chars — jamás `verified`).
- **Nota de captura:** `--short=7` garantiza **≥ 7** chars (git alarga el prefijo si hay colisión); una salida >7 divergiría de un `expected` de 7 → `stale`, nunca un falso `verified`. Si HEAD cambia, el positivo deja de coincidir: eso es `stale`, justamente lo que el contrato pretende.
- **Cambio mínimo elegido:** abreviar la salida a 7 caracteres (`--short=7`) en el ejemplo `main-branch-head` (no documentar el hash completo): el ejemplo ilustra `value`/`expected`/`evidence` de 7 chars, y la alternativa de hash completo queda documentada y coherente en el fixture `project-state.yaml` (40/40). Coherencia de evidencia alineada en §HERENCIA (convención de trazabilidad), §EVIDENCIA (2 ejemplos + fila `%h`) y contrato `check` del Paso 3.

**H-3 — `expired` puede generarse solo por el TTL, sin ejecutar el check:**

- **Paso 2** (tabla de campos `status` + §SEMÁNTICA VERIFIED): `expired` "se calcula sobre la fecha `verified` almacenada, **sin ejecutar el check**".
- **Paso 3** (etapa TTL del pipeline + paso 6 de §EJECUCIÓN + fila `expired` de §SEMÁNTICA): la condición `(hoy − verified).days > ttl_days` usa **solo** la fecha almacenada; hereda `ttl_check()` de `buffy-verify.sh` (L145-164), que emite `expired`/`TTL_EXPIRED` leyendo el `facts.yaml` previo **sin lanzar ningún comando**.
- **Conclusión:** confirmado — `expired` no es resultado de un intento → `status` **no** puede describirse como resultado del último intento en todos los casos. La distinción **resultado de ejecución (`verified`/`stale`/`unknown`) vs estado derivado del TTL (`expired`)** ya consta en ambos documentos; **esquema y campos intactos** (sin cambios unilaterales).
- **Discrepancia de `confidence` en `expired` — RESUELTA (2026-10-12, decisión delegada al agente):** Paso 2 §SEMÁNTICA decía `0.0` y Paso 3 `0.2`. **Valor fijado: `0.2`** — es el que asigna el contrato heredado (`buffy-verify.sh` L301: `1.0` si verified, `0.4` si stale, `0.2` para el resto, incluido `expired`) y el que ya declaraba el Paso 3 en sus dos sitios; además respeta la escala de tres puntos `1.0/0.4/0.2` de `facts.yaml` (Paso 2 §JUSTIFICACIÓN: "reusarla evita inventar una escala paralela"). `0.0` habría sido un cuarto punto sin respaldo en el contrato. Cambio: 1 celda en Paso 2 §SEMÁNTICA; esquema y campos intactos; linter sin cambios (LINT-17 valida `∈ [0.0, 1.0]` en ambos casos).

*Primeras pasadas (2026-10-11):* la primera pasada solo documentó el conflicto (§5 de la misión: documentar y solicitar resolución); la corrección documental posterior (2026-10-12) queda registrada en cada fila de la tabla de §6 y en esta sección. No se implementa el motor ni el linter; sin commit ni push; Paso 4 **no** aprobado y Paso 5 **no** autorizado.

## 7. Límites de esta validación

- **3 modelos, 1 pasada c/u** (RUN2 incompleto por timeout) — no se afirma generalización; combinación probada declarada en §4.
- El agente interpretó **el archivo**, no el repo: los `check` **no se ejecutaron** (no hay motor — eso es Fase B/Paso 5).
- Estado `expired` y conflictos A↔B **no cubiertos** por el fixture (pendientes para Fase D).
- El script de validación ad-hoc vive en `/tmp` y se descarta; no es linter ni motor.

## 8. CHECKPOINT (2026-10-11, cierre Fase A)

- **Objetivo:** misión §10 — llevar project-state a validación con usuario.
- **Git:** rama `main`, HEAD `74a6374` == `origin/main`, **sin commit ni push**; modified: `project-state-design.md`, `project-state-engine-design.md` (decisiones S-08/Q-02); untracked: 3 `.local.md` (intocables) + `project-state-linter-design.md`, `project-state-paso5-plan.md`, **`project-state.yaml` (fixture)**, **este documento**.
- **Pruebas:** suite `--quick` **395/0 exit 0** (baseline pre-fixture) · `buffy-doctor --quick` exit 0 CONSISTENTE · `ai-context-lint` 0 errores (última pasada pre-experimento) · fixture check exit 0 + control negativo 5.
- **Decisiones registradas con autoridad:** Q-02 manual, S-08 no requerida, Paso 6 requisito previo — todas del operador (2026-10-11).
- **Bloqueos reales:** criterio 4 — **aprobación explícita del Paso 4** (no consta); después, autorización independiente del Paso 5. H-1/H-2/H-3 **corregidas documentalmente (2026-10-12)** — resolución y evidencia en §6 y en la ronda de correcciones; la aprobación del Paso 4 sigue **reservada al operador**.
- **Siguiente acción:** ~~verificar regresión → cerrar criterio 3~~ **hecho**: suite COMPLETA `411 OK / 0 FAIL` exit 0, lint 0 errores, doctor CONSISTENTE, todos tras crear fixture+documentos; criterio 3 cerrado con esta evidencia (§8 linter / §0 plan). ~~solicitar la aprobación explícita del Paso 4~~ **hecho (2026-10-13): aprobado — ver §9.**

## 9. Decisiones del operador (2026-10-13) — cierre documental y autorización

- **Paso 4: APROBADO.** El diseño del linter (`project-state-linter-design.md`) queda cerrado como diseño — sin afirmar que el linter esté implementado ni validado en ejecución. Habilita el Paso 5.
- **Paso 5: AUTORIZADO** como implementación controlada, con límites explícitos:
  1. Implementar motor y linter según los diseños aprobados, sin ampliar alcance ni tocar archivos protegidos (`.local.md`, `CONTINUE.md`, Paso 2/3).
  2. Ciclo autónomo: inspeccionar → implementar → probar → corregir → volver a probar.
  3. Aceptación **solo** con evidencia funcional real: pruebas del motor y del linter incluyendo casos negativos, errores de entrada y fallos de enumeración. Fallos → corregir y repetir; bloqueo real o decisión arquitectónica no autorizada → detenerse y explicar.
  4. Informe final **único**: archivos modificados, pruebas ejecutadas y resultados, defectos corregidos, limitaciones pendientes y estado de Git. **Sin commit, sin push, sin avanzar automáticamente a fases posteriores.**
- **Lo que NO se aprobó:** la ronda documental queda cerrada (sin re-auditar H-1/H-2/H-3 ni la discrepancia de `confidence`); los 395 tests rápidos **no** validan el motor (aún no existe); los 4 avisos preexistentes del doctor no bloquean; terminar el Paso 5 **no** aprueba fases posteriores (Paso 5+ requiere decisión manual separada).
- **Resultado de la ejecución (2026-10-13)**: implementados `scripts/lib/project_state_linter.py` + `scripts/lib/project_state_engine.py` y sus suites (`test-project-state-linter.sh`: matriz de 45 filas + I-2 · `test-project-state-engine.sh`: estados/comparaciones/taxonomía/errores de entrada/enumeración + I-1 + I-4). **I-1..I-4 cerradas con evidencia real** (`project-state-linter-design.md` §7); matriz **45/43** confirmada desde los IDs; recuento total actualizado en README: suite **508 OK / 0 FAIL** (full) y **491 OK / 0 FAIL** (quick). Dos defectos propios encontrados y corregidos durante la ejecución (falsos positivos LINT-02/16 por fechas YAML → `datetime.date`; fixture `[false]` parseado como booleano). **Sin commit ni push**; archivos `.local.md`, Paso 2 y Paso 3 intactos. **Paso 5+ NO aprobado.**

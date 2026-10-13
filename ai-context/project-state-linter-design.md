# Diseño del linter `project-state` (Paso 4)

> Documento de diseño. No se crea linter ejecutable, código, ni archivo `project-state.yaml`.
> No implementa: motor de verificación, linter, ni ninguna regla ejecutable.
> Fuentes: `project-state-design.md` (Paso 2), `project-state-engine-design.md` (Paso 3), hechos verificados del repo (2026-10-10).
> Repositorio observado en `74a6374` (main == origin/main). La referencia de partida `d524892` es un ancestro: el repo NO permaneció en ese estado — verificado por `git log`/`git status`.

---

## 1. OBJETIVO Y ALCANCE

**Objetivo**: diseñar el linter estático de `project-state.yaml` — validación barata, pre-ejecución, que actúa como **gate del pipeline antes del motor** (decisión Q-08, Paso 3: linter ANTES del motor; el motor conserva `schema_violations` como safety net independiente — defense in depth, no una secuencia obligada).

**Alcance (dentro)**:
- Validación **estática** de un YAML contra el esquema del Paso 2 y el contrato del Paso 3.
- Reglas LINT-01..LINT-19 con severidad y trazabilidad definidas (§3).
- Contrato de entrada/salida con códigos de salida (§4).
- Matriz de pruebas previstas con trazabilidad regla→prueba (§5).

**Alcance (fuera)**:
- **No ejecuta** `check.command` — ejecutar es dominio del motor (Paso 3 §EJECUCIÓN).
- No inspecciona código fuente, no es static analyzer de código (Paso 2 §LO QUE NO CUBRE 4).
- No modifica el esquema, ni Paso 2, ni Paso 3.
- No resuelve conflictos A↔B (Q-06, fuera de alcance en Paso 3).

**Posición en el pipeline** (Paso 3 §ESTADO FINAL, secuencia 2026-10-07): Paso 4 (este documento) → Paso 5 (implementación motor + linter) — previo a ello, Paso 6 (experimento a mano) según el reordenamiento vigente.

---

## 2. FUENTES NORMATIVAS Y CLASIFICACIÓN A/B/C/D

Orden de prioridad aplicado: (1) estado real del repo y su Git, (2) documentos normativos Paso 2 / Paso 3, (3) decisiones consolidadas en el prompt operativo de este paso, (4) historial de conversación como contexto.

| Categoría | Reglas | Fuente normativa | Naturaleza |
|---|---|---|---|
| **A — Reglas explícitas** | LINT-01..LINT-14 | Paso 2 §REGLAS DE VALIDACIÓN / LINT (L361-386) `[verificado 2026-10-10]` | Escritas literalmente en la sección normativa de reglas de Paso 2, con severidad asignada |
| **B — Derivadas de la tabla de campos** | LINT-15, LINT-16, LINT-17, LINT-08b | Paso 2 §ESTRUCTURA §Tabla de campos (columnas Tipo/Requerido/status `verified\|stale\|unknown\|expired` vs `judged\|pending\|disputed`, L152) `[verificado 2026-10-10]` | No están escritas en §REGLAS; se derivan de los tipos y la obligatoriedad declarados en la tabla |
| **C — Contrato con el motor** | LINT-19 | Paso 3 §DECISIONES DE ENTRADA S-04 (L27) + §S-04 Lista estricta (L80-84) + Paso 2 supuesto S-04 (L431) `[verificado 2026-10-10]` | El linter valida la forma; el motor exige la lista en ejecución (§6) |
| **D — Propuesta pendiente** | LINT-18 | Prompt operativo Paso 4; **sin regla normativa confirmada** | No genera ERR obligatorio (§3.4) |

**Distinción declarada** (prompt 4.1): la exhaustividad de LINT-01..LINT-14 es **respecto de la sección §REGLAS de Paso 2** — la lista de esa sección está completa. No se confunde con la tabla de campos, cuyas restricciones dan lugar a la categoría B. **Paso 2 no se modifica** para eliminar esta distinción.

**Estado de S-04 en las fuentes — RESUELTO (2026-10-10)**:
- Paso 2 §SUPUESTOS PENDIENTES (L431): S-04 figura como supuesto pendiente, con la delegación explícita en L424: "se dejan para **Paso 3+ (implementación)** o para una sesión posterior" — Paso 2 asigna el cierre de estos supuestos al Paso 3 por diseño.
- Paso 3 (L27, §L80-84, L396): S-04 declarada **resuelta** entre las 5 bloqueantes (2026-10-07), con texto de decisión propio: lista estricta, string rechazado, compat no implementada.
- **Decisión**: la evidencia alcanza para cerrar el supuesto **operativo** S-04 — la fuente normativa que exige la resolución (Paso 2 L424) designa al Paso 3 como sede, y el Paso 3 resolvió. **No hay dependencia normativa adicional** que exija otra decisión para el contrato.
- **Discrepancia documental que persiste**: la fila de Paso 2 L431 sigue escrita como pendiente (snapshot congelado de su sesión). Es deuda documental, no normativa — actualizar Paso 2 exige autorización del operador y queda registrado en §8. No bloquea este documento.

---

## 3. REGLAS

Severidades: `error` (ERR → exit 1), `advertencia` (WARN → exit 0), `guard` (procesabilidad → exit 2, §4).

### 3.1 Categoría A — reglas explícitas de Paso 2 (obligatorias)

| ID | Regla | Severidad | Salida |
|---|---|---|---|
| LINT-01 | `project.name` es string no vacío | error | 1 |
| LINT-02 | `project.version` es fecha ISO (`YYYY-MM-DD`) | error | 1 |
| LINT-03 | `assertions` es array | error (procesabilidad — §3.3) | 2 |
| LINT-04 | Cada assertion tiene `key` única dentro del repo | error | 1 |
| LINT-05 | `type` ∈ {`A`, `B`} | error | 1 |
| LINT-06 | Si `type: A` → `check` presente y es objeto | error | 1 |
| LINT-07 | Si `type: B` → `check` ausente | error | 1 |
| LINT-08a | Si `type: B` → `status` ∉ {`verified`} (regla explícita Paso 2, D3) | error | 1 |
| LINT-09 | `confidence: 1.0` → requiere `source: system` y `type: A` | error | 1 |
| LINT-10 | Si `type: A` y `status: verified` → `confidence` = 1.0 (§3.5) | error | 1 |
| LINT-11 | `ttl_days`, si presente, = 30 | error | 1 |
| LINT-12 | `source` ∈ {`system`, `user`, `inferred`} | error | 1 |
| LINT-13 | Si `source: system` → `type` = `A` | error | 1 |
| LINT-14 | Si `source: user` → `type` = `B` | **advertencia** | 0 |

Todas `[documentado]` en Paso 2 L363-386 con severidad idéntica (01-13 error, 14 advertencia).

### 3.2 Categorías B y C — derivadas y contrato

| ID | Regla | Categoría | Severidad | Salida |
|---|---|---|---|---|
| LINT-15 | Campos requeridos presentes: `key`, `type`, `value`, `source`, `confidence`, `status`, `verified`, `scope`, `evidence` | B (tabla de campos, columna Requerido ✅) | error | 1 |
| LINT-16 | `verified` es fecha válida `YYYY-MM-DD` | B (tipo de campo `date`; S-07) | error | 1 |
| LINT-17 | `confidence` ∈ [0.0, 1.0] | B (tipo `float 0.0–1.0`) | error | 1 |
| LINT-08b | `status` pertenece al conjunto permitido por su tipo: A → `verified\|stale\|unknown\|expired`; B → `judged\|pending\|disputed` | B (enums de la tabla, L152) | error | 1 |
| LINT-19 | `check.command` es **lista no vacía** de argumentos; string se rechaza | C (S-04) | error | 1 |

**LINT-08a vs LINT-08b — trazabilidad diferenciada** (prompt 4.3):
- **LINT-08a** = regla explícita de Paso 2 (L375): `type: B` nunca `status: verified`. Prueba: **V-07**.
- **LINT-08b** = derivada de la tabla de campos: `status` dentro del conjunto del tipo. Pruebas: **V-08** (B + `expired` ∈ conjunto A) y **V-09** (A + `judged` ∈ conjunto B).
- V-07 → LINT-08a; V-08, V-09 → LINT-08b. Conservan trazabilidad separada en §5.

### 3.3 LINT-03 — condición de procesabilidad (guard estructural 6)

- La **regla normativa** procede de Paso 2 (L365: "`assertions` es array", severidad error) y **se conserva intacta**.
- Su **materialización** es el **guard estructural G-6**: la comprobación corre en la fase de procesabilidad, **antes** de evaluar reglas individuales — no hay aserciones sobre las que aplicar LINT-04..LINT-19 si `assertions` no es una lista evaluable.
- Si `assertions` **falta** o **no es una lista** → el linter devuelve **exit 2** (no procesado), no exit 1.
- Cubierto por **N-06** (ausente) y **N-07** (no lista).
- **No se clasifica como ERR con exit 1**: exit 1 presupone un documento procesado con violaciones; este caso no llega a evaluarse.
- `[documentado]`: el prompt de este paso y la naturaleza misma de la regla (procesabilidad previa) son la fuente; Paso 2 no especifica códigos de salida — no hay contradicción que conciliar.

### 3.4 LINT-18 — propuesta pendiente (categoría D)

- La **presencia** de `evidence` es obligatoria (tabla de campos: Requerido ✅) y está cubierta por **LINT-15** (prueba V-18: campo ausente → ERR).
- **No existe regla normativa confirmada** que exija que su **contenido sea no vacío** — `evidence: ""` presente pero vacío queda fuera de toda regla obligatoria.
- Por tanto: la presencia se valida (LINT-15); el requisito de contenido no vacío permanece como **propuesta LINT-18**, **no genera ERR obligatorio**, y **V-22 no forma parte de la matriz obligatoria** (§5). `[pendiente]` — si se promueve a obligatoria, requiere decisión explícita del operador que la registre en Paso 2.

### 3.5 LINT-10 — obligatoria, con fuente normativa

- **Fuente normativa: Paso 2 §REGLAS DE VALIDACIÓN / LINT, L377** (categoría A, severidad error) `[verificado 2026-10-10]`. Motivo escrito: "Coherencia con facts.yaml (1.0 = verified)".
- **No es una convención externa de `facts.yaml`**: `facts.yaml` es la inspiración, pero la regla está escrita en el §normativo de Paso 2 y es vinculante para project-state por sí misma.
- Pruebas: **V-12** (`confidence: 0.4` con A+verified → ERR, exit 1) y **P-08** (`confidence: 1.0` → válido, exit 0).

### 3.6 LINT-19 — contrato con el motor (categoría C)

- Regla: `check.command` debe ser **lista no vacía** de argumentos; un string se rechaza.
- Trazabilidad: Paso 2 supuesto **S-04** (L431) + Paso 3 **§S-04 Lista estricta** (L80-84: "String se rechaza con `unknown`… aquí no hay retrocompat que soportar") + Paso 3 §DECISIONES DE ENTRADA L27.
- Pruebas: **F-03** (string → ERR, exit 1) y **P-09** (lista válida → exit 0).
- Estado de S-04: **resuelto — contrato efectivo confirmado** (2026-10-10): Paso 2 delega el cierre en Paso 3+ (L424) y Paso 3 lo cerró (L27, §L80-84, L396). Ver §7 I-5. La fila de Paso 2 L431 queda como deuda documental (§8); **no se edita Paso 2**.

### 3.7 Guard estructurales (fase de procesabilidad, exit 2)

| Guard | Condición | Pruebas |
|---|---|---|
| G-1 | Archivo existe y es legible (permisos) | N-01, N-02 |
| G-2 | Archivo no vacío | N-03 |
| G-3 | Contenido parsea como YAML válido | N-08 (← F-01 duplica) |
| G-4 | Raíz del documento es mapping | N-04 |
| G-5 | Bloque `project` presente y es mapping | N-09 |
| **G-6** | **`assertions` presente, es lista, y cada item es mapping** ← materializa **LINT-03** | **N-06, N-07** (+ N-05) |

Orden de evaluación: G-1 → G-6 en orden; el primer guard fallido detiene con exit 2. Si varios fallos coexisten, reporta el primero en orden (determinismo de diagnóstico).

---

## 4. CONTRATO DE ENTRADA Y SALIDA

### Entrada
- Ruta al archivo YAML (default por convención S-01: `ai-context/project-state.yaml`; para pruebas, ruta arbitraria).
- Flag `--json` (convención del repo: `ai-context-lint.sh`, `buffy-doctor.sh`).
- Sin escritura sobre el archivo evaluado ni sobre el repo (§5, M-01/M-02).

### Salida — códigos de salida

| Exit | Condición | Representado en |
|---|---|---|
| **0** | Procesado, **0 ERR** (WARN permitidos) | P-01..P-09, V-16 |
| **1** | Procesado, **≥ 1 ERR** | V-01..V-15, V-17..V-21, F-02, F-03 |
| **2** | **No procesado** — guard estructural G-1..G-6 falló (incluye LINT-03) o uso inválido de CLI (convención `ai-context-lint.sh` L41/L49) | N-01..N-09 (F-01, F-04 duplican) |

### Salida — forma

- **Humano**: una línea por hallazgo — `LINT-XX <key o path> <detalle>`; resumen final con conteos `errors`/`warnings`.
- **JSON (`--json`)** — contrato para I-2:

```json
{
  "healthy": true,
  "errors": 0,
  "warnings": 0,
  "items": [{ "rule": "LINT-07", "key": "mi-key", "detail": "type: B con check presente" }]
}
```

Alineado con la minimalidad del repo (`ai-context-lint.sh`: `{repo, errors, healthy}`). `healthy` ⇔ `errors == 0` (exit 1 si no). El esquema formal de este JSON es lo que **I-2** deberá verificar en Paso 5 (§7).

### Pipeline

```
archivo → [G-1..G-6: procesabilidad, exit 2] → [reglas A/B/C/D: ERR exit 1 | WARN exit 0] → reporte (humano | --json)
```

---

## 5. MATRIZ DE PRUEBAS

**Naturaleza**: **EJECUTADAS el 2026-10-13** (Paso 5 autorizado — `project-state-paso6-experiment.md` §9). Las 45 filas corrieron con IDs idénticos en `scripts/tests/test-project-state-linter.sh`; recuento desde los IDs ejecutados: **45 ejecuciones / 43 escenarios únicos — coincide con §5.1, sin corrección** (criterio 6 de §8). Evidencia: suite completa `508 OK / 0 FAIL` y `--quick` `491 OK / 0 FAIL` (2026-10-13).

### 5.1 Totales recalculados desde esta matriz

| Categoría | IDs | Ejecuciones |
|---|---|---:|
| Positivas, exit 0 | P-01..P-09 | 9 |
| Lectura/procesamiento, exit 2 | N-01..N-09 | 9 |
| Violaciones ERR, exit 1 | V-01..V-15, V-17..V-21, F-03 | 21 |
| WARN, exit 0 | V-16 | 1 |
| Falsificación/regresión | F-01, F-02, F-04 | 3 |
| No-modificación | M-01, M-02 | 2 |
| **Total ejecuciones** | | **45** |

Duplicaciones: F-01 ≡ N-08, F-04 ≡ N-07 (únicas) → **45 − 2 = 43 escenarios únicos**.

### 5.2 Positivas — exit 0 (9)

| ID | Escenario | Reglas bajo prueba |
|---|---|---|
| P-01 | Documento mínimo válido: `project` completo + 1 assertion A completa con `check` | conformidad general |
| P-02 | Documento mixto A+B completo (todas las claves requeridas) | conformidad general |
| P-03 | B con `status: judged`, `confidence: 0.9`, sin `check` | LINT-07, LINT-08a, LINT-09 conformes |
| P-04 | B con `status: pending` (hipótesis), `confidence: 0.5` | LINT-08b, LINT-14 no aplica |
| P-05 | A con `status: stale`, `confidence: 0.4` | LINT-10 no aplica (solo verified exige 1.0) |
| P-06 | A **sin** `ttl_days` (campo opcional) | LINT-11 no aplica |
| P-07 | A con `source: inferred`, `status: unknown`, `confidence: 0.2` | LINT-09, LINT-12, LINT-13 conformes |
| P-08 | A + `status: verified` + `confidence: 1.0` | **LINT-10** conforme (contrapunto de V-12) |
| P-09 | `check.command` como lista no vacía | **LINT-19** conforme (contrapunto de F-03) |

### 5.3 Lectura/procesamiento — exit 2 (9)

| ID | Escenario | Guard |
|---|---|---|
| N-01 | Archivo inexistente | G-1 |
| N-02 | Archivo sin permisos de lectura | G-1 |
| N-03 | Archivo vacío (0 bytes) | G-2 |
| N-04 | Raíz es lista (no mapping) | G-4 |
| N-05 | Item de `assertions` no es mapping | G-6 |
| N-06 | `assertions` **ausente** | **G-6 (LINT-03)** |
| N-07 | `assertions` **no es lista** (string) | **G-6 (LINT-03)** |
| N-08 | YAML inválido (error de parseo) | G-3 |
| N-09 | Bloque `project` ausente | G-5 |

### 5.4 Violaciones ERR — exit 1 (21)

| ID | Escenario | Regla |
|---|---|---|
| V-01 | `project.name` vacío | LINT-01 |
| V-02 | `version` no ISO | LINT-02 |
| V-03 | `key` duplicada | LINT-04 |
| V-04 | `type: C` | LINT-05 |
| V-05 | `type: A` sin `check` | LINT-06 |
| V-06 | `type: B` con `check` | LINT-07 |
| V-07 | `type: B` y `status: verified` | **LINT-08a** |
| V-08 | `type: B` y `status: expired` | **LINT-08b** |
| V-09 | `type: A` y `status: judged` | **LINT-08b** |
| V-10 | `confidence: 1.0` y `source: user` | LINT-09 |
| V-11 | `confidence: 1.0` y `type: B` | LINT-09 |
| V-12 | `type: A`, `status: verified`, `confidence: 0.4` | **LINT-10** |
| V-13 | `ttl_days: 60` | LINT-11 |
| V-14 | `source: guessed` | LINT-12 |
| V-15 | `source: system` y `type: B` | LINT-13 |
| V-17 | Falta `status` | LINT-15 |
| V-18 | Falta `evidence` | LINT-15 |
| V-19 | Fecha `verified` no válida | LINT-16 |
| V-20 | `confidence: 1.5` | LINT-17 |
| V-21 | `confidence: -0.1` | LINT-17 |
| F-03 | `check.command` como string | **LINT-19** |

### 5.5 WARN — exit 0 (1)

| ID | Escenario | Regla |
|---|---|---|
| V-16 | `source: user` y `type: A` | LINT-14 (advertencia) |

### 5.6 Falsificación/regresión (3)

| ID | Escenario | Relación |
|---|---|---|
| F-01 | Intento de que un YAML malformado se reporte como procesado (falsificación del "el guard no absorbe el parseo" — I-3) | **duplica N-08** |
| F-02 | Tres assertions con `type` desconocido en el mismo documento; escenario propio — el linter debe reportar las tres violaciones, no solo la primera | propio (LINT-05, exit 1) |
| F-04 | Regresión de G-6/LINT-03: `assertions` como string en un documento que además tiene reglas violables | **duplica N-07** |

### 5.7 No-modificación (2)

| ID | Escenario |
|---|---|
| M-01 | Hash SHA-256 del archivo evaluado idéntico antes y después de la corrida |
| M-02 | `git status`/HEAD del repo sin cambios tras la corrida del linter |

### 5.8 Trazabilidad regla → prueba

| Regla | Pruebas de violación | Pruebas conformes / cobertura |
|---|---|---|
| LINT-01 | V-01 | P-01, P-02 |
| LINT-02 | V-02 | P-01, P-02 |
| LINT-03 | N-06, N-07 (guard G-6, exit 2) | — |
| LINT-04 | V-03 | P-02 |
| LINT-05 | V-04 | F-02 (multi-violación) |
| LINT-06 | V-05 | P-01 |
| LINT-07 | V-06 | P-03 |
| LINT-08a | V-07 | P-03 |
| LINT-08b | V-08, V-09 | P-04, P-05 |
| LINT-09 | V-10, V-11 | P-03, P-07 |
| LINT-10 | V-12 | **P-08** |
| LINT-11 | V-13 | P-06 |
| LINT-12 | V-14 | P-07 |
| LINT-13 | V-15 | P-07 |
| LINT-14 | V-16 (WARN) | P-04 (`source: user` + B) |
| LINT-15 | V-17, V-18 | P-01..P-09 (presencia) |
| LINT-16 | V-19 | P-01..P-09 |
| LINT-17 | V-20, V-21 | P-07 |
| LINT-18 | — (V-22 **fuera de matriz**, propuesta) | — |
| LINT-19 | F-03 | **P-09** |
| Guards G-1..G-6 | N-01..N-09 | F-01 (≡N-08), F-04 (≡N-07) |
| No-modificación | M-01, M-02 | — |

Convención heredada de Paso 2 §Inspiración: *cada regla debe tener una prueba que aserte su violación* — cumplida para LINT-01..LINT-17 y LINT-19; LINT-18 (propuesta) queda deliberadamente sin prueba obligatoria.

---

## 6. DECISIÓN ARQUITECTÓNICA — METACARACTERES

### Verificado (evidencia de código actual, leído 2026-10-10)

En `scripts/lib/facts_engine.py` (motor **existente** de facts.yaml):
- **L28**: `SHELL_METACHARS = set(";&|`$<>(){}[]*?~!\\'\" \t\n")`.
- **L47**: `normalize_command` rechaza cualquier argumento que contiene un metacarácter — devuelve `[], error`, sin ejecutar.
- **L56**: `run_cmd` ejecuta con `subprocess.run(argv, ...)` **sin `shell=False` explícito pero tampoco `shell=True`** — los args van como lista, sin interpretación (docstring: "Ejecuta SIN shell"). `[verificado]`

### No verificado (futuro motor de project-state)

- El motor de project-state **no existe** (Paso 5). Su diseño (Paso 3 §EJECUCIÓN) **promete** `normalize_command` + `shell=False` + `SHELL_METACHARS`, pero **no hay código que demostrarlo**: `[no verificado]`. La evidencia de `facts_engine.py` **no se extrapola** a ese código futuro.

### Decisión de diseño

1. **El linter no ejecuta nada** (§1) → **no duplica la defensa de ejecución**. Si el contrato de ejecución asigna el rechazo de metacaracteres al motor (Paso 3 §EJECUCIÓN lo hace), el linter no implementa verificación de metacaracteres: sería defensa duplicada con riesgo de divergencia entre dos fuentes de verdad.
2. **LINT-19 valida solo forma** (lista no vacía) — comprobación estática, sin ejecución, sin `subprocess`.
3. La **aplicación real** de la defensa (metacar rechazado antes de ejecutar) se prueba **en integración en Paso 5** — es exactamente lo que encapsulan **I-1** (motor) e **I-4** (compatibilidad linter↔motor).
4. Hardening futuro posible (linter rechaza metacaracteres como early-warning): **no es regla hoy**, no está en la matriz, y promoverlo requiere decisión normativa — registrado, no implementado.

---

## 7. VERIFICACIONES I-1..I-5

Ninguna se declara resueta sin evidencia real. Convención: `[verificado]` = evidencia leída/ejecutada hoy; `[pendiente]` = condición de cierre definida, no comprobada; `[bloqueada]` = requiere decisión externa.

| ID | Verificación | Estado | Evidencia actual | Condición de cierre |
|---|---|---|---|---|
| **I-1** | El motor futuro de `project-state` rechaza `SHELL_METACHARS` **antes** de ejecutar comandos | `[resuelta 2026-10-13]` | Motor implementado (`scripts/lib/project_state_engine.py`, `normalize_command` heredado de `facts_engine.py`). Evidencia: `test_project_state_i1_metachars` 3/3 OK — (a) JSON con `level: unknown` + `id: METACHARS_REJECTED`; (b) `test ! -e /tmp/PWNED` (el hijo jamás se lanzó); (c) control de sensibilidad: sin `shell=False` el sentinel SÍ se crea, o sea el test fallaría sin el fix | Cerrada con salida real de la suite (`508 OK / 0 FAIL`, 2026-10-13) |
| **I-2** | Contrato JSON del linter contra su esquema | `[resuelta 2026-10-13]` | Esquema versionado: `scripts/lib/project_state_linter.schema.json` (draft-07); validador del test: `scripts/tests/fixtures/validate_json_schema.py` (subset, sin dependencias — el repo no tiene `jsonschema`). Evidencia: `test_project_state_linter_json_contract` 9/9 OK — esquema parsea, salida REAL `--json` valida, **3 conformes** aceptadas y **4 mutaciones** rechazadas (clave faltante, tipo wrong, y `healthy ≠ errors==0` en **ambas direcciones**) | Cerrada con salida real de la suite (2026-10-13) |
| **I-3** | El guard estructural **no absorbe silenciosamente** errores de parseo | `[resuelta 2026-10-13]` | Evidencia: fila **F-01** de `test_project_state_linter_matriz_f01_f04` (3/3 OK): YAML malformado → **exit 2** exacto, **stderr** con `error de parseo YAML` y **stdout vacío** (0 bytes — jamás `healthy: true` con archivo rojo). El check asienta las tres condiciones a la vez: falla si alguien devuelve 0 o emite JSON | Cerrada con salida real de la suite (2026-10-13) |
| **I-4** | Compatibilidad LINT-19 en el linter vs motor real | `[resuelta 2026-10-13]` | Fixture ÚNICO compartido: `scripts/tests/fixtures/project-state/cmd-string.yaml` (sin copias divergentes). Evidencia: `test_project_state_i4_linter_engine_compat` 4/4 OK — linter: exit 1 + `LINT-19` y `--json` `healthy: false`; motor: exit 0 con `level: unknown` + `id: COMMAND_NOT_LIST` (S-04); grep de aceptación vacío: ninguno lo da por `verified` | Cerrada con salida real de la suite (2026-10-13) |
| **I-5** | Resolver formalmente S-04 o confirmar que está declarado como contrato efectivo | `[resuelta documentalmente 2026-10-10]` | **Confirmado por diseño de las fuentes, no por copia**: (1) Paso 2 L424 delega el cierre de §SUPUESTOS en "Paso 3+ (implementación)" `[verificado]`; (2) Paso 3 lo cerró: L27 (tabla de decisiones), §L80-84 (texto de decisión), L396 (lista entre las 5 bloqueantes resueltas) `[verificado]`; (3) contrato efectivo = lista estricta, string rechazado, sin retrocompat | Debería cumplirse — cerrada. **Deuda documental residual (no bloquea)**: actualizar la fila L431 de Paso 2 exige autorización del operador (§8). ~~I-1..I-4 permanecen `[pendiente]`~~ **I-1..I-4 CERRADAS 2026-10-13** con pruebas reales — evidencia en cada fila de §7 |

**Nota I-5 (corregida 2026-10-10 — alcance acotado)**: el mecanismo de cierre (Paso 2 L424 delega → Paso 3 resolvió) queda aplicado **solo a S-04**. La extensión del mismo criterio a **otros** supuestos (S-05, Q-03/Q-04/Q-07, cuya fila en Paso 2 sigue como pendiente) fue una **inferencia de este documento, NO una autorización**: queda registrada como **candidata a regla de gobernanza**, no aplicada. Hasta que el operador la declare como regla explícita, **cada discrepancia entre pasos se evalúa por su cuenta** — una decisión documental válida no es permiso general para ignorar discrepancias. **S-04 opera como contrato efectivo y el linter se diseña contra él; I-5 deja de ser condición de autorización del Paso 5.** Las condiciones vigentes del Paso 5 son §8.

---

## 8. LIMITACIONES, SUPUESTOS PENDIENTES Y CRITERIOS DE PASO 5

### Limitaciones de este documento

- Es diseño documental: **cero líneas de linter** implementadas; la matriz de §5 es **prevista, no ejecutada** (45 ejecuciones / 43 escenarios únicos, contados desde los IDs de §5).
- El contrato JSON de §4 es una **propuesta de diseño** — su esquema formal es I-2.
- El linter no cubre: conflictos A↔B (Q-06), sincronización con SNAPSHOT (S-08), versionado del YAML (Q-02), ni promoción B→A (S-06).
- Campo `subtype` para hipótesis (M-06/P-05 del Paso 3): **no se introduce** aquí — añadirlo altera el esquema, lo cual está prohibido en este paso; si Q-05 exige distinción explícita, es decisión de esquema con autorización propia.

### Supuestos pendientes heredados

| ID | Estado | Nota |
|---|---|---|
| S-01 | `[pendiente]` | Nombre/ruta `ai-context/project-state.yaml` sigue siendo supuesto (Paso 2) — el contrato de §4 lo usa como default, no lo fija |
| S-04 | `[resuelto 2026-10-10]` | Contrato efectivo confirmado (delegación Paso 2 L424 + cierre Paso 3). Deuda: fila L431 de Paso 2 sin actualizar (requiere autorización) |
| S-08 | `[resuelto 2026-10-11]` | Sync con SNAPSHOT: **no es requisito del Paso 5** — decisión del operador (2026-10-11) que resuelve la condición de Paso 3 ("si es requerido" → declarado "no requerido"). No se diseña ni implementa sync; **M-07 queda como riesgo potencial aceptado** |
| Q-02 | `[resuelto 2026-10-11]` | Versionado del YAML: **manual** — el operador edita y commitea; motor sin git write access ni auto-commits (decisión del operador 2026-10-11). **No bloquea el Paso 5** |
| Q-05 / Q-06 | `[pendiente / fuera de alcance]` | No bloquean el linter (Paso 3 §REMANENTES) |
| LINT-18 | `[propuesta]` | No es obligatoria (§3.4) |

### Criterios para autorizar el Paso 5

1. ~~**I-5 / S-04**~~ — **cumplido (2026-10-10)**: cierre por evidencia de las fuentes (§7 I-5). Deuda documental: actualizar fila L431 de Paso 2 cuando el operador lo autorice (no bloquea).
2. ~~**S-08**~~ — **cumplido (2026-10-11)**: el operador declaró que la sincronización con SNAPSHOT **no es requisito del Paso 5** → no se diseña ni implementa (la condición de Paso 3 "si es requerido" queda resuelta como "no requerido"). M-07 queda como riesgo potencial aceptado, sin afirmar que la divergencia sea imposible.
3. ~~**Paso 6 — experimento a mano**~~ — **cumplido (2026-10-11)**: ejecutado y documentado en `project-state-paso6-experiment.md` — fixture de 8 aserciones escrito a mano sobre el esquema, agente fresco aislado (solo archivo + tarea), RUN con `nemotron-3-ultra-550b:free` = **6/6** criterios observados; gradiente registrado (`gemma:2b` 2/6, `qwen2.5:7b` timeout por hardware); límites declarados en §7 del experimento. No es implementación anticipada del motor (los checks no se ejecutaron — no existe motor aún).
4. ~~**Este documento aprobado** por el operador sin objeciones a la matriz ni al contrato.~~ — **cumplido (2026-10-13)**: Paso 4 aprobado (bitácora §9 de `project-state-paso6-experiment.md`).
5. En **Paso 5**: I-1..I-4 cerradas con pruebas reales (no hipotéticas) antes de declarar el linter/motor completos. — **cumplido (2026-10-13)**: §7, cada una con salida real.
6. La matriz de §5 ejecutada con evidencia real y **contada de nuevo** desde los IDs ejecutados. — **cumplido (2026-10-13)**: 45/43 confirmados desde los IDs ejecutados, sin corrección (§5).

**Nota (2026-10-11)**: el cierre de las discrepancias documentales (Q-02 resuelta, Paso 6 incorporado, §8 ↔ §0 alineados) **no equivale a aprobar el Paso 4** — el criterio 4 es una decisión separada y explícita del operador.

---

## ESTADO FINAL — verificación de este documento (2026-10-10)

| Check | Resultado |
|---|---|
| `git status` | ✅ Solo `project-state-linter-design.md` (nuevo, untracked) + 3 `.local.md` pre-existentes (intocables) |
| `git diff --stat` | ✅ Vacío — ningún tracked modificado |
| Paso 2 / Paso 3 modificados | ✅ No — solo leídos |
| Código implementado | ✅ Ninguno — diseño-only, 0 linters, 0 motores, 0 `project-state.yaml` |
| Referencias citadas | ✅ Paso 2 L363-386/L431/L152; Paso 3 L27/L80-84/L367/L396; facts_engine L28/L47/L56 — leídas 2026-10-10 |
| Recuento matriz | ✅ 45 ejecuciones / 43 únicos (§5.1) |
| I-1..I-5 | ✅ I-1..I-4 **`[resuelta 2026-10-13]`** — cerradas con pruebas reales (evidencia en §7); I-5 `[resuelta documentalmente]` con evidencia de fuentes citadas (§7). Ninguna declarada resuelta sin evidencia |

**Ejecución Paso 5 (2026-10-13)**: linter y motor implementados en `scripts/lib/project_state_linter.py` y `scripts/lib/project_state_engine.py`; suites `scripts/tests/test-project-state-linter.sh` (matriz 45 filas + I-2) y `scripts/tests/test-project-state-engine.sh` (estados/comparaciones/taxonomía/errores de entrada/enumeración + I-1 + I-4). Verificación: suite completa **508 OK / 0 FAIL** y `--quick` **491 OK / 0 FAIL** (README doc_truth actualizado); matriz §5 ejecutada con recuento **45/43** confirmado desde los IDs.

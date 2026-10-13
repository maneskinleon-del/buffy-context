# Plan de implementación — Paso 5 `project-state` (motor + linter)

> **Plan, NO implementación.** Ningún código, test o binario de este plan existe aún.
> Todo lo que este plan referencia como "ejecutado" será `[pendiente de ejecución]`
> hasta que el Paso 5 se autorice y se corra con evidencia real.
> Fuentes: `project-state-linter-design.md` (Paso 4), `project-state-engine-design.md` (Paso 3), `project-state-design.md` (Paso 2).
> Preparado: 2026-10-10.
> **Actualización 2026-10-13**: Paso 4 aprobado y Paso 5 autorizado (bitácora §9 de
> `project-state-paso6-experiment.md`) → implementación ejecutada. Los cierres I-1..I-4
> viven en `project-state-linter-design.md` §7 (regla de §2 de este plan: no se cierran aquí).

---

## 0. Puerta de entrada — condiciones antes de escribir código

Del §8 de `project-state-linter-design.md`:

| # | Criterio | Estado |
|---|---|---|
| 1 | I-5 / S-04 registrado | ✅ cumplido (2026-10-10) |
| 2 | S-08 (sync con SNAPSHOT): **no requerida** para el Paso 5 — decisión del operador (2026-10-11); no se diseña ni implementa (M-07 = riesgo aceptado) | ✅ cumplido (2026-10-11) |
| 3 | Paso 6 — experimento manual con `project-state.yaml`: validar el esquema con un caso real antes de construir linter/motor (no es implementación anticipada del motor) | ✅ cumplido (2026-10-11) — evidencia: `project-state-paso6-experiment.md` §4-§5 (6/6 con agente competente; límites §7) |
| 4 | Documento del Paso 4 aprobado sin objeciones | ✅ cumplido (2026-10-13) — aprobación explícita del operador, bitácora §9 |
| 5 | I-1..I-4 cerradas con pruebas reales | ✅ cumplido (2026-10-13) — cierres con evidencia en `project-state-linter-design.md` §7 |
| 6 | Matriz ejecutada y **recontada** desde IDs ejecutados | ✅ cumplido (2026-10-13) — 45 filas corridas, recuento 45/43 confirmado sin corrección (§5 del diseño del linter) |

**Este plan no autoriza el Paso 5.** (Lo autorizó la decisión explícita del operador — bitácora §9.) Criterios 1, 2 y 3 resueltos (1: 2026-10-10; 2: 2026-10-11; 3: 2026-10-11 con evidencia en `project-state-paso6-experiment.md`). **Criterio 4: cumplido 2026-10-13** (aprobación explícita del documento del Paso 4); 5 y 6: metas internas del paso, **cumplidas 2026-10-13** (5 → cierres en `project-state-linter-design.md` §7; 6 → matriz ejecutada y recontada). Secuencia de la puerta (decisión del operador, 2026-10-11): (1) Pasos 2-4 diseño ✅ → (2) Paso 6 experimento manual ⏳ → (3) cierre de la puerta: reconciliar Q-02, Paso 6 y §8 ↔ plan (registro hecho 2026-10-11; el criterio 3 se cierra con la evidencia del experimento) → (4) aprobación explícita del Paso 4 ⏳ → (5) autorización independiente del Paso 5: implementar y probar I-1..I-4 ⏳. **El cierre documental de estas discrepancias no equivale a aprobar el Paso 4.**

**Deuda documental conocida** (no bloqueante, NO generalizable): fila S-04 de Paso 2 L431 sin actualizar. El criterio de cierre usado para S-04 **no está aplicado** a S-05/Q-03/Q-04/Q-07 — cada discrepancia se evalúa por su cuenta hasta que exista regla de gobernanza explícita.

---

## 1. Secuencia de construcción (orden de riesgo, patrón Q-08)

```
1. Linter (validación estática)      ← primero: sin ejecución, riesgo mínimo, gate del pipeline
2. Motor (ejecución de checks)       ← después: I-1 depende de él
3. Integración de ambos              ← cierra I-4
4. Ejecución completa de la matriz   ← cierra I-2 (JSON), confirma 45/43 recontados
```

Justificación: Q-08 (Paso 3) colocó el linter antes del motor; el linter da un gate inmediato sin `subprocess`. El motor es el que necesita I-1.

**Artefactos previstos** (rutas propuestas, sujetas a S-01):
- `scripts/lib/project_state_linter.py` — linter, sin `subprocess`, sin metacaracteres que ejecutar.
- `scripts/lib/project_state_engine.py` — motor, `normalize_command` + `shell=False` heredados del patrón `facts_engine.py`.
- `scripts/tests/test-project-state-linter.sh` — suite de la matriz §5 de Paso 4.

---

## 2. Cierre de I-1..I-4: pruebas y evidencia exigida

Cada fila: **qué prueba cierra** + **qué evidencia se exige** (nada menos que salida real). `[pendiente de ejecución]`.

| ID | Prueba que lo cierra | Evidencia exigida para cerrarla |
|---|---|---|
| **I-1** — motor rechaza `SHELL_METACHARS` antes de ejecutar | Test de integración: assertion A con `check.command: [git, "rev-parse; touch /tmp/PWNED"]` (arg con metacarácter) → motor emite `unknown` + `METACHARS_REJECTED` (contrato Paso 3 §EJECUCIÓN) | (a) salida JSON del motor con `status: unknown` y código `METACHARS_REJECTED`; (b) **`test ! -e /tmp/PWNED`** = el proceso hijo jamás se lanzó; (c) el test **falla sin el fix** (falsificación previa al cierre, patrón B-1/B-3 del repo). Copia del test en la suite con nombre estable |
| **I-2** — contrato JSON del linter contra su esquema | Esquema formal del JSON de §4 (Paso 4) + `test-linter-json`: instancias conformes pasan, mutaciones (clave faltante, tipo wrong, `healthy` ≠ `errors==0`) rechazadas | (a) archivo de esquema versionado; (b) test que valida ≥3 conformes y ≥3 mutaciones rotas; (c) **ambas direcciones**: conformes aceptadas Y no-conformes rechazadas (guard de introspección, anti-falso-verde instancia 7) |
| **I-3** — el guard no absorbe errores de parseo | N-08/F-01 de la matriz: YAML malformado → linter exit 2 con mensaje de error de parseo en stderr | (a) código de salida **2** capturado (no 0, no 1); (b) stderr contiene el motivo de parseo; (c) **aserción negativa**: jamás emite JSON `healthy: true` con archivo rojo; (d) test que falla si alguien "arregla" el guard devolviendo 0 |
| **I-4** — compatibilidad LINT-19 linter ↔ motor | Test cruzado: **el mismo YAML** con `check.command` como string → linter: exit 1 + `LINT-19`; motor: `unknown` + rechazo de forma (S-04) | (a) ambas salidas del **mismo fixture**, lado a lado; (b) afirmación de que **ninguno** lo aceptó (`grep` de aceptación = vacío); (c) fixtures compartidos vía directorio de fixtures de la suite, no copias divergentes |

**Regla de cierre común a las 4:** no se marca cerrada con evidencia diseñada o hipotética — solo con salida real del binario implementado, y el registro del estado cambia en `project-state-linter-design.md` §7 en la misma entrega.

---

## 3. Ejecución de la matriz (criterio 6)

1. Implementar `test-project-state-linter.sh` con **las 45 filas exactas** de Paso 4 §5 (IDs idénticos, sin renombrar).
2. Correr full + `--quick`; capturar exit por prueba según la columna Salida de cada fila.
3. **Recontar desde los IDs ejecutados** (no heredar 45/43): si el número real difiere, corregir el recuento en el documento con justificación — nunca al revés.
4. `M-01`/`M-02` (no-modificación) corren sobre el repo real: SHA-256 previo/posterior y `git status` sin cambios.
5. Actualizar conteos `doc_truth` del README si la suite crece (convención del repo: doc_truth gatea los números declarados).
6. CI verde + `buffy-doctor --quick` sin drift nuevo antes de declarar el paso cerrado.

---

## 4. Fuera de alcance (anti-alcances)

- **No** implementa Paso 6 (experimento a mano, orden vigente anterior).
- **No** autoriza el Paso 5 por sí mismo — §0.
- **No** toca Paso 2, Paso 3, el esquema, `.local.md` ni `CONTINUE.md`.
- **No** generaliza el criterio S-04 a otras discrepancias (§0 deuda).
- **No** cierra I-1..I-4 en este documento — solo define cómo se cerrarán.

---

## ESTADO DE ESTE DOCUMENTO (2026-10-10; actualizado 2026-10-11)

| Check | Resultado |
|---|---|
| Naturaleza | ~~Plan documental~~ → **implementado (2026-10-13)**: motor + linter + suites en `scripts/lib/` y `scripts/tests/` |
| Pruebas referenciadas | **Ejecutadas (2026-10-13)**: matriz de 45 filas corrida (recuento 45/43 confirmado); suite completa `508 OK / 0 FAIL` y `--quick` `491 OK / 0 FAIL` |
| I-1..I-4 | **Cerradas (2026-10-13)** con pruebas reales — evidencia en `project-state-linter-design.md` §7 (no en este documento, regla §2) |
| Condiciones Paso 5 | §0 — criterios 1-6 **todos cumplidos** (4: aprobación Paso 4 2026-10-13; 5: §7; 6: matriz recontada). Implementación **sin commit/push** (Q-02 + instrucción del operador) |

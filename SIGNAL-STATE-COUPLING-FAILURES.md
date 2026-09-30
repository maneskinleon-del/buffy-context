# Fallo de acoplamiento señal-estado

> Taxonomía operativa — origen: ciclo C1/C2 del plan PII (2026-09-28/29).
> La lista de casos NO es cerrada: es la clase de doc que se escribe una vez
> y sirve para el resto del proyecto. Ante un fallo nuevo, la pregunta guía
> es: **¿qué dimensión del acoplamiento está rota?**

## Definición

**Fallo de acoplamiento señal-estado**: la señal de verificación existe pero
está desacoplada del estado que verifica. La documentación y la verificación
pueden ser correctas por separado y aun así fallar el pegamento entre ambas —
un contrato que promete (estados, health checks, dry-runs, CI) puede ser
fingido por la implementación que lo reporta.

No es "el test está mal" ni "el servicio está caído": es la **tercera cosa**
entre ambos — el mecanismo que se supone une señal y estado — la que falla.

## Las instancias registradas

**Registro canónico (2026-09-30).** Los números de esta tabla son ESTABLES:
un número apunta a un caso y solo a uno. Las referencias históricas
anteriores a este registro (commits `17a3742`..`82054a8`, sesiones previas)
usan la numeración de la columna «Antes» — no son errores, son alias.

| # | Dimensión | Caso | Detectado | Antes |
|---|-----------|------|-----------|-------|
| 1 | Trabajo | Ollama wedged: liveness OK, capacidad muerta | 2026-09-28 | 1 |
| 2 | Remoto | sync push fingido (intención ≠ remoto) | 2026-09-28 | 2 |
| 3 | Tiempo | time-bomb del fixture TTL | 2026-09-28 | 3 |
| 4 | Entorno | `uv` presente ⇒ test no determinista | 2026-09-28 | 4 |
| 5 | Entorno de ejecución | working tree vs clone fresco (`--quick` ≠ CI) | 2026-09-30 | 4b / «#7» del operador |
| 6 | Ejecución | hook escrito pero no instalado | 2026-09-28 | 5 |
| 7 | Cascada | doc_truth compara contra passed (contamina la señal) | 2026-09-30 | 6 / «#8» del operador |
| 8 | Colisión | stdin: router (feature) × pre-push (convención git) | 2026-09-30 | parte de «meta-momento 4» |

Respuestas a las preguntas de canonicalización (2026-09-30):

- **¿Cuántas?** Ocho. Cuatro por dimensión clásica (1-4, 6), tres por
  dimensiones nuevas de la verificación misma (5, 7, 8).
- **¿Los dos abortos del pre-push son una instancia o dos?** Un INCIDENTE
  (el bautismo del hook) = UNA instancia (la 8) con DOS mecanismos: el aborto
  1 (la sim veía el Ollama local) es acoplamiento clásico de la familia 4 —
  la señal veía un estado que el entorno verificado no tiene; el aborto 2
  (stdin heredado) es COLISIÓN pura — la forma nueva que define la 8.
- **¿«--quick» ≠ CI y la cascada entraron como variantes?** No: son
  instancias propias (5 y 7). La 5 es variante de entorno en dimensión
  propia (mismo árbol, otro checkout — no «otra máquina», no «otro
  servicio»); la 7 es una dimensión nueva (el verificador confunde su
  causa con la causa ajena).

Cada caso ilustra una forma distinta del acoplamiento.

### 1. Trabajo — la señal dice "vivo", el estado dice "no puedo trabajar"

**Caso:** Ollama wedged 3+ días (2026-09-28). `GET /api/tags` respondía 200
con generación muerta y embeds largos en 9-10s. El síntoma visible (hook
bloqueado) apuntaba a "servicio caído"; el diagnóstico real era "servicio
vivo que no puede hacer su trabajo". Explica por qué reinicios previos no
resolvían: nadie preguntaba por capacidad, solo por liveness.

**Señal:** health check (liveness) · **Estado:** capacidad real de terminar
el trabajo en tiempo acotado.
**Fix:** probe de capacidad (`POST /api/embed` bge-m3) + gate de performance
con input largo (~5.7KB ≤6s) + techos `timeout` por comando (`e9ab468`).

### 2. Remoto — la señal dice "sincronizado", el estado dice "solo lo intenté"

**Caso:** `sync push` reportaba "✔ commiteado y pusheado" sin haber pusheado
nada (add/commit/push fallidos tragados). `.sync-state` registraba intención.

**Señal:** marca de sync · **Estado:** qué hay efectivamente en el remoto.
**Fix:** `state_set` después del push OK; push fallido ⇒ `pend_set` + exit 1
sin marcar; reintento automático; tests git-real assertionando el fallo
(`8d8a388`, contrato en `scripts/lib/buffy-memory-sync.sh:30`).

### 3. Tiempo — la señal dice "pasa hoy", el estado dice "no pasará mañana"

**Caso:** time-bomb del fixture TTL (`test-verify.sh`): `verified: 2026-08-07`
con `ttl_days: 30` venció el 2026-09-06 → 3 checks fallaban por puro paso del
tiempo. Ninguna auditoría lo detecta sin correr el test **en la fecha exacta**.
"El test pasa" y "el test pasará mañana" no son la misma afirmación.

**Señal:** test verde hoy · **Estado:** test verde bajo la condición que
simula (TTL vigente).
**Fix:** fecha dinámica (`datetime.date.today()`) — el fixture siempre
simula la condición que pretende (`e9ab468`).

### 4. Entorno — la señal dice "pasa aquí", el estado dice "depende de la máquina"

**Caso:** `sin fuentes → inferred` fallaba solo donde `uv` está instalado
(el resolver lo detectaba real-time). Dependencia del entorno disfrazada de
test determinista; en CI (sin uv) pasaba siempre.

**Señal:** test pasa en esta máquina · **Estado:** el comportamiento bajo
test es independiente del entorno.
**Fix:** `--no-live` (aislar la jerarquía del sistema real — `e9ab468`).

### 5. Entorno de ejecución — working tree vs clone fresco (2026-09-30) · antes «4b»

**Caso:** CI rojo con suite full aunque `--quick` local pasara. No era "otra
máquina" (caso 4): era **el mismo árbol de trabajo vs un clone fresco** —
`--quick` corre contra el working tree (ve CONTINUE.md, memorias, `.local`),
el CI corre contra un clone (no ve nada de eso). 4 checks full acoplados a
un archivo de estado que C3 había hecho local-por-diseño. `--quick` verde es
**condición necesaria pero no suficiente** para CI verde, y no hay forma de
saberlo sin simular el clone.

**Señal:** suite verde local · **Estado:** suite verde en un checkout que
no es el mío.
**Fix:** desacoplar los tests del estado de instancia (criterio "ausente+
gitignoreado = OK", `3f512d0`) + mitigación estructural: simular el clone
antes de pushear (`scripts/tests/ci-sim.sh`), gateado por hook pre-push.

### 6. Ejecución — la señal dice "existe", el estado dice "no corre" · antes «5»

**Caso:** hook pre-commit versionado en el repo pero ausente de `.git/hooks/`.
La mitad del contrato "el hook corre la suite antes del commit" era
aspiracional: commits históricos nunca fueron gateados.

**Señal:** el mecanismo está escrito · **Estado:** el mecanismo se ejecuta.
**Fix:** instalar + verificar con corrida real (`e9ab468`).

### 7. Cascada — el verificador confunde su causa con la causa ajena (2026-09-30) · antes «6»

**Caso:** `doc_truth_check` comparaba el README contra los checks **passed**
del runner. Los passed incorporan los FAILs ajenos: cuando cualquier otro
test falla, passed baja, el total real se corrompe, y el README (correcto)
aparece como mentiroso. En el CI rojo del 2026-09-30 produjo 2 falsos
"README desactualizado" que no eran sino cascada de los 4 fallos reales.
El test que debería decir "README miente" lo dice cuando en realidad
"otro test falló" — la señal del verificador incluye el estado que no
verifica.

**Señal:** "la doc no coincide con la suite" · **Estado:** la doc no
coincide con la suite **porque la doc miente** (no porque otro test falle).
**Fix:** comparar contra TOTALES (passed+failed, invariantes ante fallos
ajenos) + guard de introspección que impide reintroducir la comparación
contra passed.

### 8. Colisión — dos contratos correctos se contradicen al anidarse (2026-09-30)

**Caso (el incidente completo del bautismo del pre-push hook, ambos
abortos):**

- **Aborto 1 — acoplamiento clásico (familia 4):** `ci-sim.sh` reproducía
  el clone pero veía el **Ollama local del operador** (servicio de estado
  variable, instancia 1). Si `ollama_up()` respondía a tiempo, el test de
  determinismo corría dentro de la sim y un pico de latencia lo rompía;
  en CI no hay Ollama → siempre skippea. Falso ❌ (y habría dado falsos ✅
  al revés). Fix: `OLLAMA_URL` muerta en la sim (`511486d`).
- **Aborto 2 — colisión pura (la forma nueva):** el router acepta mensaje
  por stdin (**feature, diseño correcto**) y git invoca pre-push con las
  ref-lines del push en stdin (**convención estándar de git, correcta**).
  Anidados: hook → sim → suite → router sin `--message` **leyó las
  ref-lines como mensaje** → exit 0 donde el contrato espera 1. El router
  cumplió su contrato; el entorno lo alimentó. Invisible al leer código:
  solo emerge cuando el sistema se ejecuta a sí mismo en condiciones de
  producción. Fix: stdin cerrado `</dev/null` (`530fb90`).

No es "señal desacoplada del estado" en el sentido obvio: son **dos
contratos correctos por separado que se contradicen en un contexto
específico**. Ante un fallo en composición, buscar la colisión antes que
el culpable — puede que no lo haya.

**Señal:** cada contrato, verificado aislado, pasa · **Estado:** la
composición de ambos, en el entorno anidado real, hace lo que ninguno
prometió.
**Fix:** la sim reproduce el entorno COMPLETO del runner (stdin cerrado,
servicios muertos) — ver Principios operativos, P1.

## Corolario operativo

- Toda verificación debe terminar en **tiempo acotado** y assertionar el
  HECHO, no la intención. Un skip es honesto solo si documenta qué condición
  no se cumplió (contrato, no silencio).
- Ante un fallo nuevo de esta clase, nombrar primero la **dimensión** (¿trabajo,
  remoto, tiempo, entorno, ejecución?, y las nuevas: entorno de ejecución,
  cascada, colisión) y después buscar el desacople concreto.

## Principios operativos

Reglas del sistema de verificación (las instancias las motivaron; la regla
es más general que el caso que la parió).

- **P1 — «¿Qué ve el runner?, no ¿qué veo yo?».** Todo verificador que corre
  en un entorno anidado o distinto del de desarrollo debe reproducir el
  **entorno COMPLETO** del entorno de referencia: filesystem (clone fresco),
  `$HOME` aislado, servicios (muertos si el runner no los tiene), stdin
  (cerrado si el runner no alimenta). Un simulador que reproduce solo el
  filesystem produce falsos ✅ y falsos ❌ con la suite perfecta (instancias 5 y 8).
  Aplica a: CI vs local, hook vs runner, y cualquier verificación anidada
  futura.
- **P2 — La verificación es un objeto más.** Desarrollada en la meta-sección
  de abajo: un test es una señal con su propio acoplamiento señal-estado;
  los guards que verifican verificadores son defensa legítima, no paranoia.
- **P3 — Composición ≠ suma de contratos.** Ante un fallo que solo emerge
  anidando dos piezas verificadas aisladas (instancia 8, aborto 2), buscar la
  **colisión** antes que el culpable: puede que no lo haya — dos decisiones
  correctas por separado se contradicen en un contexto específico.

## Observación metodológica (2026-09-29): override, no ausencia

El preflight de C4 reveló **18 fallos** por ausencia de `INFO-core.md` — la
cifra es señal, no carga de trabajo: un archivo consumido por 8 sitios + eval
+ lint + doctor **no es estado personal tolerado, es contrato del sistema**.
La ausencia de un contrato no es un estado legítimo ("checkout incompleto"),
y adaptar a todos los consumidores para tolerarla sería diseñar el contrato
para mentir.

**El patrón correcto por cantidad de consumidores:**

- **1 consumidor, ausencia semánticamente normal** (CONTINUE.md: "instancia
  sin handoff previo") → ausencia tolerada (`MISSING` informativo, no error).
- **N consumidores, ausencia anormal** (INFO-core: el sistema no funciona sin
  él) → **split tracked/local (`.local` override)**: el archivo base existe
  siempre (genérico, sin PII, válido como instancia); la versión real del
  operador vive en `<nombre>.local.md` (gitignored) y los consumidores la
  prefieren si existe. Convención de industria (`.env`/`.env.local`,
  `settings.local.json`) — se explica sola.

**La distinción público vs personal no se resuelve con presencia/ausencia,
se resuelve con override.** El archivo base existe siempre; el override vive
en la instancia. Mismo desacople de esta familia: la señal ("el archivo
existe") estaba desacoplada del estado ("el contenido personal existe") por
la ausencia — el override los re-acopla.

⚠ **Caveat empírico:** redactar el tracked cambia el corpus vivo → la
fidelidad del eval congelado (fixture 2026-08-13 con contenido original) puede
degradar aunque el archivo exista. El skip por corpus_hash sigue siendo
probablemente necesario: se redacta → se corre el eval → se mide la fidelidad.
Sin excepción para BUFFY-PC-CONTEXT/BUFFY-CURRENT-STATE (C3): cero
consumidores de sistema y estado personal puro → ausencia correcta ahí.

## Meta-propiedad: el sistema se aplica a sí mismo

Registrado como propiedad del sistema, no como anécdota — **cuatro** incidentes
del mismo ciclo en que **la verificación cazó a quien la diseñaba**:

1. Handoff del operador con la premisa "tree limpio" — el receptor la verificó
   antes de razonar (convención de trazabilidad, caso 7 en `LOAD_CONTEXT.md`).
2. El guard de PII atrapando su propia nota de anuncio (el CHANGELOG que
   citaba la literal del patrón redactado) y auto-matcheándose al commitearse
   (resuelto con auto-exclusión de pathspec, `01f33e7`).
3. **CI cazando el fix que iba a arreglar CI** (2026-09-30): el commit
   `8431ed9` que des-rompía el CI destapó, vía la suite full, 4 fallos nuevos
   — la verificación operó sobre la verificación, no sobre el objeto.
4. **El hook pre-push abortando su propio push inaugural** (2026-09-30,
   dos veces): el simulador de CI (`ci-sim.sh`) vio el Ollama local del
   operador (estado variable, instancia 1) y heredó las ref-lines de git
   por stdin (el router las leyó como mensaje — instancia 8). Su push
   inaugural fue abortado por él mismo hasta corregir su propia fidelidad
   (`511486d`, `530fb90`) — el gate nació gateándose.

En los cuatro, la herramienta de verificación opera **sobre la herramienta
de verificación**, no sobre el objeto. Eso ya no es anécdota: es el patrón
dominante del proyecto.

### Meta-sección: la verificación es un objeto más

La verificación es un artefacto del sistema como cualquier otro, y por lo
tanto **tiene su propio acoplamiento señal-estado**: un test es una señal
que afirma algo de un estado, y el pegamento entre ambas puede fallar igual
que en cualquier contrato. Consecuencias operativas:

- Todo verificador nuevo debe preguntarse: **¿mi señal incluye estados que
  no verifico?** (cascada, caso 6) · **¿mi estado existe en todo entorno
  donde corro?** (working tree vs clone, caso 4b).
- Los guards que verifican verificadores (introspección de `doc_truth`,
  auto-exclusión de pathspec) no son paranoia: son la única defensa cuando
  el verificador es el objeto.
- La verificación no puede assertionar su propia no-cascada desde adentro —
  la demostración empírica (un FAIL forzado en CI real) es parte del
  registro, no un lujo.
- **Un simulador de entorno es un verificador y tiene su propio
  acoplamiento**: reproduce el filesystem pero no el stdin, el $HOME o los
  servicios locales del operador → produce falsos ✅ y falsos ❌ con la
  suite perfecta. El estándar de fidelidad es "¿qué ve el runner?", no
  "¿qué veo yo?" — y se alcanza reproducir el entorno COMPLETO, no solo
  el filesystem (instancias 5 y 8; regla promovida a **P1**).

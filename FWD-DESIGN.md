# Foreign Worktree Detection (FWD) — diseño

> Estado: **⏳ DISEÑO — pendiente de aprobación** (2026-08-12) — aún SIN implementación.
> Motivo: caso real descubierto HOY (2026-08-12) — dos sesiones trabajando en el
> mismo checkout de buffy-context (OpenCode + Freebuff) sin pisarse mutuamente.
> Esta spec formaliza el comportamiento que ya ocurrió de forma implícita.
> Pertenece al **roadmap de Buffy 2.0** (ver CONTINUE.md — sección Roadmap; pendiente
> de registrar ahí cuando el archivo no esté bloqueado por cambios ajenos).

---

## 1. Problema y caso real

Dos (o más) sesiones de agente pueden trabajar sobre el **mismo checkout de git** de
forma independiente. El repositorio es el **estado compartido observable** entre
ellas. Sin protección, una sesión puede sobrescribir, commitear o descartar el
trabajo de la otra sin saberlo.

**Caso real (2026-08-12):** mientras Freebuff trabajaba en el EVAL PC (Fase 3),
otra sesión (OpenCode) modificó en el mismo working tree: `MCP_REGISTRY.md` y
`SKILLS_INDEX.md` (nuevos), `README.md` (23→43 skills), `ai-context/CONTINUE.md`,
`ai-context/SESION.md` y `scripts/buffy-doctor.sh` (check de drift de skills).
Freebuff detectó estos cambios **por el estado del filesystem/Git** (no por ver la
otra conversación): `git status --short` → `git diff` → `stat -c '%y'` (timestamps
19:15–19:22, posteriores al último commit propio `e9d6e6f` de 19:10) → inferencia
"cambios que yo no hice". Los **preservó intactos** y pidió decisión.

**Objetivo de esta spec:** convertir ese comportamiento implícito en una **regla
explícita y reproducible** del sistema, con definiciones precisas (qué es "ajeno"),
clasificación formal, política de seguridad y puntos de enganche.

---

## 2. Definición del problema (formal)

> **Foreign Worktree Detection (FWD):** antes de modificar el repositorio (y en
> puntos de control durante la sesión), detectar cambios en el working tree no
> atribuibles a la sesión actual; clasificarlos; **protegerlos** (no sobrescribir,
> no commitear, no descartar); y **detenerse o informar** según la política.

### 2.1 Lo que NO es FWD

- NO es un mecanismo de merge/conflict-resolution de git.
- NO es un lock exclusivo del repo (no impide que otros escriban).
- NO es una herramienta de atribución forense perfecta (ver §3: señales, no certeza).
- NO reemplaza la disciplina "check status antes de escribir" — la formaliza.

---

## 3. Cómo determinar que un cambio es "ajeno" — señales múltiples, NO solo timestamps

Los timestamps por sí solos son **heurística débil** (mtime se puede tocar, relojes
desincronizados, un proceso propio puede modificar un archivo que ya tenía mtime
reciente). FWD combina señales independientes y clasifica por **peso de evidencia**:

| # | Señal | Qué mide | Fuerza |
|---|---|---|---|
| S1 | **Manifest de la sesión** | Al iniciar, la sesión registra los archivos que **pretende** modificar (paths) + los que ya **modificó** (con hash). Un cambio fuera del manifest = ajeno por construcción. | **Alta** |
| S2 | **Snapshot de baseline** | Al iniciar, `git status --porcelain` + `git diff --stat` + hash de cada archivo rastreado. Un cambio respecto a ese snapshot que no está en el manifest propio = ajeno. | **Alta** |
| S3 | **Ventana temporal** | `stat -c '%y'` del archivo vs timestamp de inicio de sesión y del último commit propio. Sirve para **ordenar** la hipótesis, nunca como prueba única. | Media (solo apoyo) |
| S4 | **Atribución de contenido** | El contenido del diff es coherente con otra sesión (estilo, contexto, archivos agrupados — ej: MCP+skills+README+doctor van juntos). **Capa de juicio humano/LLM, NO señal del clasificador automático** (ver §3.2). | — (solo juicio) |
| S5 | **Estado git de 3 vías** | Diferencias entre `HEAD`, índice (staged) y working tree: cambios staged que la sesión no hizo = ajeno. `git stash list` / `git reflog` recientes = operaciones de otra sesión. | Media |
| S6 | **Procesos concurrentes** | Otro proceso con el repo abierto o escribiendo (p.ej. locks, sesiones activas detectables por fs). Señal de entorno, no de contenido. | Baja/contextual |

### 3.1 Clasificación por peso acumulado

```text
OWN_CHANGE      → el archivo está en el manifest de la sesión (S1) y coincide con
                  el snapshot previo de la sesión (S2)
FOREIGN_CHANGE  → fuera del manifest (S1) Y fuera del snapshot de baseline (S2);
                  S3/S4/S5/S6 corroboran (no exigen)
UNKNOWN         → no se puede atribuir con las señales disponibles
                  (p.ej. sin manifest, S1/S2 no aplican, S3 ambiguo)
CONFLICT        → FOREIGN_CHANGE O UNKNOWN sobre un archivo que la sesión
                  NECESITA modificar para su tarea actual
```

> **Regla de oro de clasificación:** la ausencia de manifest (S1) hace que todo
> cambio no-rastreable sea `UNKNOWN` como mínimo; nunca se asume `OWN` sin evidencia.

### 3.2 Alcance del clasificador automático vs capa de juicio

El **clasificador automático** (el script, usable como gate) usa **S1 + S2 + S5** y
S3 solo como tiebreak. S4 (contenido) y S6 (procesos) son **capas de interpretación**
que corren después, para informar la decisión del usuario — nunca entradas del
gate. Así el gate nunca depende de heurísticas de contenido o de procesos.

### 3.3 Casos de borde (alcance declarado)

| Caso | Tratamiento |
|---|---|
| Archivo **ignorado** (`.gitignore`) | **Fuera de alcance**: `git status --porcelain` no los muestra; FWD cubre el working tree rastreado. Declarado. |
| **Symlinks** (`~/ai-context` → repo, `~/.local/bin/*.sh`) | FWD opera sobre el repo (ruta real); un cambio vía symlink a un archivo **fuera** del repo no aparece — declarado como límite de alcance. |
| **Borrados** (estado `D`) y **renames** (`-M`) | Cubiertos por S2 (porcelain los reporta); la clasificación aplica igual (borrado no-rastreable = FOREIGN/UNKNOWN). |
| **Cambios staged por otra sesión** | S5 los detecta (staged ≠ lo que la sesión hizo) → FOREIGN. |
| **Adopción consciente** | Excepción explícita: si el **usuario** ordena adoptar un FOREIGN (p.ej. "commitea estos cambios"), FWD lo permite **extendiendo `touched` del manifest** — la decisión explícita del usuario anula el default "nunca adopta". |
| **Divergencia con origin** (otra sesión pushea) | **Fuera de alcance de FWD** (FWD = working tree local). Se detecta con `git fetch`/`reflog` como preocupación separada; declarado. |

---

## 4. Política de seguridad (fijada desde el diseño)

> **FWD detecta, clasifica y protege; nunca adopta, revierte, commitea ni descarta
> automáticamente cambios extranjeros.**

| Situación | Acción |
|---|---|
| `OWN_CHANGE` | Normal: la sesión sigue su trabajo. |
| `FOREIGN_CHANGE` en archivo que la sesión **NO** necesita tocar | **Continuar**, pero **informar** (listado al final del turno / en el reporte de sesión). |
| `FOREIGN_CHANGE` o `UNKNOWN` en archivo que la sesión **SÍ** necesita modificar | **STOP**: no escribir, no commiteear; solicitar decisión al usuario con el detalle (path, tipo de cambio, señales). |
| `FOREIGN_CHANGE` que **intersecta** los archivos de un `git commit`/`push` propio | **STOP** del commit: no incluir archivos ajenos; re-chequear (la otra sesión pudo escribir mientras tanto). |
| `FOREIGN_CHANGE` en el resto del tree, con commit **selectivo** de archivos propios (`git add <mis archivos>` explícito) | **OK**: commitear solo lo propio es seguro y es exactamente el flujo real de hoy (commit `4aa663a`). Informar al final. |

### 4.1 Gate previo a escritura (extensión propuesta) — con re-hash inmediato

FWD puede operar como **gate previo a cualquier operación de escritura** sobre un
archivo (estilo de los gates de Fase 3). **Corrección crítica (review):** la
clasificación por manifest+baseline es *estática*; si dos sesiones escriben el MISMO
archivo en paralelo, no se detecta la escritura de la otra a menos que se **re-hashee
el target justo antes de escribir**:

```text
antes de modificar el archivo X:
    hash_actual = sha256(X)                      // re-hash INMEDIATO, no el del baseline
    si X está en touched y hash_actual ≠ touched[X].sha → CONFLICT (STOP: la otra sesión escribió)
    clasificar X (S1/S2/S5)
    si CONFLICT → STOP (pedir decisión)
    si FOREIGN  → informar y pedir OK (o seguir según política §4)
    si OWN/UNKNOWN-no-usado → escribir, y actualizar touched[X].sha
```

Este gate es **extensión futura**; esta spec fija primero el detector + política.

---

## 5. Diseño del detector

### 5.1 Componentes

```text
FWD = detector (lectura pura) + clasificador (reglas §3.1) + reportero (salida)

1. fwd_manifest_init    → snapshot inicial: HEAD, rama, git status --porcelain,
                          diff --stat, hash de archivos rastreados, timestamp
2. fwd_scan             → re-ejecuta el snapshot y compara con el baseline
3. fwd_classify <path>  → clasifica UN archivo → OWN/FOREIGN/UNKNOWN/CONFLICT,
                          con exit code POR-ARCHIVO (0 own/ok · 1 foreign informativo
                          · 2 CONFLICT en ese target) — el gate pre-escritura (§4.1)
                          usa ESTA variante, no el agregado
4. fwd_report           → salida legible (tabla path × clase × señales) + agregado
                          (exit 2 si hay ≥1 CONFLICT en targets propios; 1 si solo
                          foreign informativo; 0 limpio). **exit 1 es NO bloqueante
                          por diseño** (informativo); exit 2 bloquea solo el target
                          conflictivo, no el resto del repo.
```

### 5.2 El manifest (S1) — el corazón de la atribución

El manifest resuelve el problema de atribución de raíz: **la sesión declara qué va a
tocar**. Formato propuesto (archivo de sesión, p.ej. `.fwd-manifest.json` o en
`$TMPDIR`):

```json
{
  "session_id": "freebuff-2026-08-12-1930",
  "started_at": "2026-08-12T19:30:00-04:00",
  "branch": "main",
  "head_commit": "4aa663a",
  "intended": ["scripts/tests/evals/*"],
  "touched":   [{"path": "scripts/tests/evals/quality-passage-DESIGN.md", "sha": "abc…"}]
}
```

- `intended` = paths que la sesión planea modificar (se puede poblar con globs).
- `touched` = los que ya modificó (con hash) — permite distinguir "lo mío" incluso
  después de que otro proceso toque el mismo archivo (CONFLICT se detecta porque el
  hash actual ≠ hash que la sesión dejó).
- El manifest **no** se commitea (vive en el working tree / tmp) — es conocimiento
  local de sesión, igual que `.sync-state` de buffy-memory.

### 5.3 Límites declarados de la atribución

- Sin manifest (S1 ausente) la atribución baja a `UNKNOWN` por defecto — seguro.
- S3 (timestamps) solo ordena hipótesis, no prueba nada.
- Un cambio `FOREIGN` que luego "parece" propio (mismo estilo) sigue siendo
  `FOREIGN`: la atribución se basa en el manifest, no en el contenido.

---

## 6. Puntos de enganche en buffy-context (integración)

| Punto | Cuándo | Qué hace FWD |
|---|---|---|
| **Pre-flight de sesión** | inicio de sesión / primer turno | `fwd_manifest_init` + primer `fwd_scan` → baseline |
| **Pre-escritura** | antes de tocar un archivo | clasificar el target → §4.1 |
| **Pre-commit / pre-push** | antes de `git commit` / `git push` | re-scan → si FOREIGN nuevo: STOP |
| **`buffy-doctor.sh`** | diagnóstico | sección nueva "Trabajo ajeno detectado" (informa, no bloquea) |
| **`buffy-close-day.sh`** | cierre de sesión | re-scan final + registro en el reporte |

Los hooks de git (`scripts/hooks/pre-commit.sh`) son un punto natural para un check
de "no commitear cambios staged que no son míos" — pendiente de decidir si FWD se
integra por hook o por script de sesión (puede ser ambas).

---

## 7. Criterios de aceptación (para la futura implementación)

1. `fwd_scan` detecta los 6 tipos de cambio del §2 (modificados, nuevos, post-sesión,
   otra rama/proceso, divergencia HEAD/índice/working tree, conflictos con targets).
2. Clasificación OWN/FOREIGN/UNKNOWN/CONFLICT correcta en los casos de prueba:
   - archivo tocado por la sesión → OWN;
   - archivo nuevo sin manifest → UNKNOWN;
   - archivo modificado por otro proceso entre scans → FOREIGN;
   - FOREIGN sobre target de la sesión → CONFLICT.
3. Exit codes documentados (0/1/2) y usables como gate.
4. El detector es **lectura pura**: nunca modifica, commitea, revierte ni descarta.
5. Test suite propia (estilo `test-*.sh` de buffy-context) sobre un sandbox git.

---

## 8. Qué NO hace FWD (regla de no-tocar)

- NO adopta, integra, mergea ni "mejora" cambios extranjeros automáticamente.
- NO revierte ni descarta cambios extranjeros (ni con `--force`).
- NO commitea cambios ajenos (ni siquiera "porque parecen buenos").
- NO usa el gold del EVAL ni memoria curada para la atribución.
- NO decide por el usuario en `CONFLICT`: se detiene y pregunta.
- NO bloquea la escritura del otro proceso (es observador, no cerrojo).

---

## 9. Orden de ejecución (tras aprobación)

```text
1. implementar scripts/lib/fwd.sh (manifest + scan + classify + report)
2. tests: test-fwd.sh sobre sandbox git (los 6 tipos + clasificación)
3. integrar pre-flight + pre-commit + doctor (report-only primero)
4. registrar en CONTINUE.md → Roadmap Buffy 2.0 (cuando no esté bloqueado)
5. revisar con code-reviewer
6. commit + push + detenerse
```

---

## 10. Relación con la sesión de HOY (el caso que motivó la spec)

- Los cambios de OpenCode en el working tree (MCP_REGISTRY, SKILLS_INDEX, README,
  CONTINUE/SESION, buffy-doctor.sh) **quedan intactos y sin commitear** — decisión
  del usuario: revisarlos por separado, después de diseñar FWD.
- El diseño de FWD se registra en `scripts/tests/evals/EVAL-REGISTRY.md` (apéndice
  de decisiones) y quedará pendiente su referencia en el Roadmap de CONTINUE.md.

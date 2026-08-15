# Estado de instancia local vs compartido — diseño

> Estado: **✅ APROBADO — Fase A (diseño) y Fase B (cambio mínimo) implementadas**
> (2026-08-15). Fase A congelada en commit `51a5631`; Fase B en el commit inmediato
> posterior a `51a5631` en `main` (ver `git log`).
> Fase D (fixture experimental): **diseño en borrador (`FIXTURE-EXPERIMENTAL-DESIGN.md`),
> NO implementada — pendiente de aprobación**. El borrador no implica apertura ni
> implementación del frente; sigue separado hasta su aprobación explícita.
> Motivo original: evidencia empírica del experimento **17D** (2026-08-15): los controles de
> sanity (A/B-solo/V1-solo) NO reprodujeron sus esperados históricos por **drift real
> del corpus** — `README.md`, `ai-context/CHANGELOG.md`, `ai-context/CONTINUE.md` y
> `ai-context/SESION.md` crecieron entre 17C y 17D y alteraron posiciones de pasajes,
> leak, pRel y paths del ctx. El corpus de Buffy NO está aislado de su propio estado
> operativo.
> Pertenece al **frente arquitectónico SESION/CONTINUE local** (independiente de la
> serie experimental, que queda cerrada: 17B/17C PASS exp / NO ADOPTED, 17D STOP /
> NO EVALUADO). La complejidad debe ser proporcional a la tarea: cambio MÍNIMO.

---

## 1. Problema y evidencia

Buffy mezcla tres conceptos con ciclos de vida distintos:

```text
PROYECTO
  código, Knowledge, skills, configuración
       │
       ├── debe compartirse por Git
       │
MEMORIA
  MEMORY/USER
       │
       ├── debe poder sincronizarse
       │
ESTADO DE INSTANCIA
  SESION.md
  CONTINUE.md
  SNAPSHOT.md
  facts.yaml
  .sync-state
       │
       └── pertenece al dispositivo/instancia
```

El último grupo **no debería viajar por Git**. Representa:
> "¿Dónde quedó ESTE dispositivo/agente con ESTE trabajo?" — no "¿cuál es el estado universal de Buffy?"

**Evidencia 17D:** modificaciones puramente operativas en `CONTINUE.md`, `SESION.md`
y `CHANGELOG.md` (crecimiento de sesión, handoff, changelog) cambiaron el
`corpus_hash` de `236a87fa` → `029ed669` (7653 → 7803 líneas) y rompieron la
reproducibilidad de los controles (A/B leak 0.442→0.425, V1-solo pRel 0.584→0.581).
El experimento no debe depender del árbol vivo.

---

## 2. Los tres grupos (contrato)

| Grupo | Contenido | Ciclo de vida | Viaja por Git |
|---|---|---|---|
| **PROYECTO** | `scripts/`, `skills/`, `Knowledge/`, `README.md`, `docs/`, `CHANGELOG.md` | Compartido | ✅ Sí |
| **MEMORIA** | `MEMORY/USER` (`ai-context/memories/`) | Sincronizable | ✅ Sí (vía `buffy-memory.sh sync`) |
| **INSTANCIA** | `SESION.md`, `CONTINUE.md`, `SNAPSHOT.md`, `facts.yaml`, `.sync-state` | Local por dispositivo | ❌ No |

---

## 3. Tabla contractual

| Archivo | Compartido | Local | Experimental |
| ------- | ---------: | ----: | ------------: |
| `MEMORY/USER` | ✅ | | según fixture |
| `Knowledge/` | ✅ | | ✅ |
| `CHANGELOG.md` | ✅ | | fixture |
| `README.md` | ✅ | | fixture |
| `SESION.md` | | ✅ | ❌ |
| `SESION-archive.md` | | ✅ | ❌ |
| `CONTINUE.md` | | ✅ | ❌ |
| `SNAPSHOT.md` | | ✅ | ❌ |
| `facts.yaml` | | ✅ | ❌ |
| `.sync-state` | | ✅ | ❌ |

**Nota:** `CHANGELOG.md` describe cambios del PROYECTO ("el proyecto cambió X en la
versión Y") → compartido. El problema de 17D no es que CHANGELOG sea conceptualmente
incorrecto como archivo compartido: es que **no debe formar parte del corpus
experimental mutable** — eso lo resuelve el fixture (sección 7), no su localización.

---

## 4. `CONTINUE.md` — la distinción delicada

Cumple dos funciones hoy:

```text
CONTINUE.md
├── handoff de la sesión          → LOCAL
└── información útil para seguir  → candidata a compartir
```

**Regla (solución mínima, sin crear archivos nuevos):**

> **`CONTINUE.md` = handoff local de instancia.**

Si algo se convierte en decisión permanente del proyecto, se **promociona** al lugar
correspondiente:

```text
CONTINUE.md
    ↓
decisión permanente
    ↓
documentación / MEMORY / Knowledge / registry (EVAL-REGISTRY, CHANGELOG, docs)
```

Así el handoff no se convierte accidentalmente en memoria global. La jerarquía de
fuentes de `buffy-source.sh` (real-time → facts → SNAPSHOT → CONTINUE → INFO-core →
inferred) **no cambia**: sigue leyendo `CONTINUE.md` desde disco; solo deja de ser
estado versionado.

---

## 5. `SESION.md` y `SESION-archive.md` — 100% local

Es historial operativo de una instancia. Sin conflicto entre dispositivos:

```text
PC        └── SESION.md (+ SESION-archive.md)
Teléfono  └── SESION.md (+ SESION-archive.md)
Freebuff  └── SESION.md (+ SESION-archive.md)
OpenCode  └── SESION.md (+ SESION-archive.md)
```

**`SESION-archive.md` también es local** (decisión del usuario, 2026-08-15): es
historial de instancia, no conocimiento del proyecto. No se convierte en excepción.
Si alguna información del archivo archivado merece convertirse en conocimiento
permanente, se **promociona manualmente** al lugar correspondiente (docs / MEMORY /
Knowledge / registry) — no se sincroniza el archivo entero.

---

## 6. `CHANGELOG.md` — compartido

```text
SESION.md    "Hoy hice X"              → local
CONTINUE.md  "Quedé trabajando en X"   → local
CHANGELOG.md "El proyecto cambió X en la versión Y" → compartido
```

---

## 7. Separar el corpus experimental del árbol vivo (Fase D — independiente)

NO es parte del cambio mínimo. Es el segundo problema, con su propia solución:

```text
                 Buffy repo
                     │
          ┌──────────┴──────────┐
          │                     │
      estado vivo          fixture experimental
          │                     │
       mutable              congelado
          │                     │
   README/CHANGELOG       corpus_hash
   CONTINUE/SESION        EVAL
   Knowledge              configuración
```

> El experimento no dice "usa el repositorio actual" — dice "usa este fixture
> congelado". 100 usuarios pueden hacer commit/push sin que el experimento vea
> cambiar el corpus.

Identidad del fixture (diseño futuro, NO se implementa ahora):

```text
fixture_id
corpus_hash
eval_hash
config_hash
runner/version
```

**Este frente NO está implementado todavía.** Hay un **diseño en borrador**
(`FIXTURE-EXPERIMENTAL-DESIGN.md`, pendiente de aprobación — no implica apertura
ni implementación). Se implementa solo tras aprobación explícita, como problema
separado (relacionado pero distinto: multi-dispositivo ≠ reproducibilidad).

---

## 8. Cambio mínimo (Fase B) — alcance exacto

### 8.1 Qué se hace

1. `.gitignore`: añadir `ai-context/SESION.md`, `ai-context/SESION-archive.md` y
   `ai-context/CONTINUE.md` (precedente ya existente: `ai-context/SNAPSHOT.md` y
   `ai-context/facts.yaml`).
2. `git rm --cached ai-context/SESION.md ai-context/SESION-archive.md ai-context/CONTINUE.md`
   — los archivos **siguen existiendo en disco** (no se borran); solo dejan de
   versionarse.
3. **NO se cambia** el mecanismo de memoria (`buffy-memory.sh`, MEMORY/USER).
4. Adaptar SOLO los scripts que asumen que esos archivos están en Git:
   - `scripts/buffy-close-day.sh` — verificar que su `git add -A` respeta el
     `.gitignore` (no re-agrega los archivos locales). **Verificado hoy:** no hay
     `git add` específico de SESION/CONTINUE en scripts; el `git add -A` genérico
     respeta `.gitignore` → sin cambio de código requerido.
   - `scripts/tests/test-close-day.sh` — el sandbox de test replica el flujo;
     ajustar expectativas si asume `SESION.md`/`CONTINUE.md` versionados.
   - Documentación: `README.md` (árbol de estructura + línea 317 "At session end,
     Buffy updates CONTINUE.md and SESION.md"), `ai-context/LOAD_CONTEXT.md`
     (pasos 62-69 "primera sesión", 112-115).

### 8.1bis Punto de compatibilidad: `cp` del cierre de sesión

> El mecanismo de cierre puede escribir `CONTINUE.md`/`SESION.md` en la instancia
> local; **no debe asumir que esos archivos están versionados ni ejecutar
> operaciones Git sobre ellos.**

**Verificado (2026-08-15):** `~/.AGENTS.md` tiene
`cp ~/buffy-context/ai-context/{CONTINUE.md,SESION.md,CHANGELOG.md} ~/ai-context/`,
pero `~/ai-context` **es symlink** al repo → el `cp` es un **no-op** (destino =
fuente) y sigue funcionando porque los archivos siguen existiendo en disco. No hay
instrucción que implique `git add`/`git commit` sobre estos archivos. **Se conserva
como está** — punto de compatibilidad, no cambio de arquitectura.

### 8.2 Qué NO cambia (verificado)

| Componente | Cómo trata SESION/CONTINUE | ¿Requiere cambio? |
|---|---|---|
| `buffy-doctor.sh` | Valida **presencia en disco** (`-f`) — no git | ❌ No |
| `ai-context-lint.sh` | Valida **secciones en disco** de CONTINUE.md | ❌ No |
| `buffy-source.sh` | Lee CONTINUE.md de **disco** (jerarquía) | ❌ No |
| `buffy-router.sh` / `buffy-expand.sh` / `lib/*.py` | Corpus de pasajes desde **disco** | ❌ No (el corpus vivo sigue incluyéndolos; la exclusión del corpus es del fixture, sección 7) |
| `buffy-context.sh` / `buffy-verify.sh` | Regeneran SNAPSHOT/facts (ya locales) | ❌ No |
| `buffy-memory.sh sync` | MEMORY/USER (sincronizable, NO local) | ❌ No |
| `~/.AGENTS.md` (fin de sesión) | `cp` hacia `~/ai-context` (symlink → no-op) | ❌ No — punto de compatibilidad (§8.1bis) |

### 8.3 Riesgos del cambio

- **Drift del corpus vivo:** sacar SESION/CONTINUE de Git NO los quita del corpus
  vivo (siguen en disco) → los EVALs existentes (17C/17D, congelados en sus
  commits) no se ven afectados retrospectivamente. Cualquier futuro experimento usa
  fixture (sección 7).
- **Clonado fresco:** un nuevo checkout NO traerá SESION/CONTINUE → `LOAD_CONTEXT.md`
  ya contempla "primera sesión: si CONTINUE.md no existe, crear inicial". Es el
  comportamiento deseado (cada instancia arranca su propio handoff).
- **Close-day:** verificar que el commit de cierre de día no incluya los archivos
  locales (gitignore lo garantiza con `git add -A`).

---

## 9. Verificación (Fase C)

1. **Suite completa** en PC: `315 OK / 0 FAIL` full · `299 OK / 0 FAIL` --quick
   (los checks de doctor/lint siguen pasando: los archivos existen en disco).
   El incremento vs `313/297` se explica por los **2 checks nuevos** de
   `test-close-day.sh` (aserciones de que el commit de cierre NO versiona
   `SESION.md`/`CONTINUE.md`).
2. **Test de cierre de día** (`test-close-day.sh`): el commit de cierre NO incluye
   `SESION.md`/`CONTINUE.md` (gitignore) y el repo queda limpio.
3. **Simulación multi-instancia:** PC A → SESION A · PC B → SESION B — sin
   conflictos de Git (los archivos ni siquiera son trackeados → no hay merge).
4. **`git status` limpio** tras el cierre de día (los archivos locales no aparecen
   como untracked).
5. **`cp` del cierre de sesión intacto** (no-op por symlink; punto de compatibilidad).

---

## 10. Criterios de aceptación del contrato

- [x] `SESION.md`, `SESION-archive.md` y `CONTINUE.md` dejan de versionarse (git rm --cached + gitignore).
- [x] Los archivos siguen existiendo en disco (doctor/lint/source intactos).
- [x] `MEMORY/USER` sigue sincronizable; `CHANGELOG.md` sigue compartido.
- [x] Suite PC verde (315/299) sin cambios en el mecanismo de memoria ni runtime.
- [x] El commit de cierre de día no incluye archivos de instancia.
- [x] Fase D (fixture experimental) queda documentada como frente separado, con diseño en borrador pendiente de aprobación (NO implementada).

---

## 11. Orden de implementación (aprobado por el usuario, 2026-08-15)

```text
Fase A — diseño (ESTE documento)          ← ✅ congelada (51a5631)
Fase B — separar SESION/CONTINUE (gitignore + git rm --cached + scripts)
                                            ← ✅ implementada (gitignore + rm --cached + test + docs)
Fase C — verificar (suite + multi-instancia) ← ✅ verificación abajo
Fase D — fixture experimental (frente separado, después) ← ⏳ NO abierta
```

**Regla de la serie:** el cambio mínimo se ejecutó tras aprobación explícita de
este contrato (usuario, 2026-08-15). No se abre Fase D ni se toca el runtime.

### Verificación Fase C (2026-08-15)

- [x] `.gitignore` + `git rm --cached` de `SESION.md`, `SESION-archive.md`, `CONTINUE.md` (siguen en disco).
- [x] `buffy-close-day.sh` sin cambios (su `git add -A` respeta `.gitignore`).
- [x] `test-close-day.sh` adaptado: sandbox copia `.gitignore` real + aserciones de no-versionado.
- [x] Documentación: README (árbol + nota ¹ + sección de agentes), LOAD_CONTEXT (pasos 3 y 4).
- [x] Suite completa full `315 OK` / `--quick` `299 OK` (+2 checks de `test-close-day.sh`).
- [x] Simulación multi-instancia PC-A/PC-B sin conflictos (archivos ni trackeados → no hay merge).

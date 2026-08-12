# 🔄 PROTOCOLO DE CARGA — Memoria Persistente

> Este archivo explica a CUALQUIER agente IA (Buffy, Claude, Antigravity, etc.)
> cómo cargar el contexto de mangonz al inicio de una sesión.
>
> ⚠️ **IMPORTANTE — Presupuesto de tokens**: DeepSeek V4 Flash tiene una ventana
> de contexto limitada. NO cargues archivos completos si no los necesitas.
> Usa la carga condicional (sección más abajo) para decidir qué Knowledge/ cargar.

---

## 📋 Protocolo obligatorio al iniciar sesión

Cuando comiences una sesión con mangonz, DEBES cargar estos archivos en este orden:

### Paso 1 — Contexto base del sistema (SIEMPRE, ~3KB)
```markdown
ai-context/INFO-core.md
```
Esto te da: OS, WM, shell, herramientas, reglas personales, stack de proyectos.

### Paso 1.5 — Memoria curada (SIEMPRE — snapshot Congelado)
```markdown
~/.buffy/memories/MEMORY.md  (2.200 chars máx — notas del agente)
~/.buffy/memories/USER.md    (1.375 chars máx — perfil de mangonz)
```
Se leen UNA vez al iniciar la sesión y **NO se re-leen en el medio** (snapshot
congelado, patrón Hermes — caché de prefijo). Para ver el bloque de prompt:
```bash
bash scripts/buffy-memory.sh render memory   # o: user
```
Escribir/editar memoria DURANTE la sesión solo con el script (nunca a mano):
```bash
bash scripts/buffy-memory.sh add     memory "hecho/lección..."
bash scripts/buffy-memory.sh add     user   "preferencia..."
bash scripts/buffy-memory.sh replace memory "substring único" "nuevo texto"
bash scripts/buffy-memory.sh remove  user   "substring único"
bash scripts/buffy-memory.sh batch   memory '[{"action":"add",...}]'   # atómico
```
Semántica (igual que la tool `memory` de Hermes):
- GUARDAR proactivo: corrección del usuario, preferencia, hecho de entorno,
  convención, lección aprendida. Prioridad: preferencias del usuario y
  correcciones > datos de entorno > conocimiento de procedimiento.
- NO guardar: progreso de tareas, logs de trabajo terminado o TODOs
  temporales — eso vive en SESION.md/CONTINUE.md y en buffy-search.sh.
- Límites duros: si el add/replace excede el char limit, el script lo
  rechaza → consolidar (merge con replace, borrar con remove) y reintentar.
- Si un archivo fue editado a mano (drift), el script lo detecta, guarda
  `.bak` y rechaza la escritura — nunca sobrescribe lo que no entiende.
- Las mutaciones persisten a disco al instante; aparecen recién en la
  PRÓXIMA sesión (el snapshot de esta no cambia).

### Paso 2 — Estado vivo del sistema (SIEMPRE, ~5KB)
```markdown
ai-context/SNAPSHOT.md
```
Procesos actuales, RAM/disco, dispositivos ADB, estado git de proyectos activos.
Si no existe o está vacío, ejecuta: `buffy-context.sh` (lo genera automáticamente).

### Paso 3 — Handoff de la sesión anterior (SIEMPRE)
```markdown
ai-context/CONTINUE.md
```
Qué se hizo, en qué quedó, qué pendientes hay. **Es el archivo más importante.**

> **🔰 Primera sesión**: Si `CONTINUE.md` no existe (repo recién clonado, primera vez):
> - Lee `INFO-core.md` para conocer el stack del usuario
> - Regenera `SNAPSHOT.md` con `buffy-context.sh`
> - Crea `CONTINUE.md` inicial con: "Primera sesión — sin historial previo"
> - Continúa normalmente

### Paso 2.5 — Provenance de hechos (OPCIONAL — para dudar con criterio)
```markdown
ai-context/facts.yaml     → SOLO si necesitas saber si un dato de INFO-core es
                            confiable. Registra por hecho: valor real, source
                            (system/user/inferred), confidence (0-1) y fecha de
                            última verificación. Lo genera:
                            bash scripts/buffy-verify.sh --update-facts
```
Ejemplo: si INFO-core dice "npm 11.18.0" pero `facts.yaml` marca ese hecho con
`confidence: 0.4` y `status: stale` (el sistema tiene 12.0.1) → NO confíes en el
dato de la doc; usa el valor real. Preferencia vs hecho confirmado:
- `source: system` + `confidence: 1.0` → hecho verificado contra el sistema
- `source: user` + `confidence: 1.0` → preferencia explícita del usuario
- `source: inferred` + `confidence: < 1.0` → inferencia, verificar antes de usar
- `scope` → máquina a la que aplica el hecho (hostname por defecto;
  `--scope NOM` para otras: Termux, servidor, CI). Si el scope no es esta
  máquina, NO uses el valor como si fuera local.

> 🔧 **Reglas declarativas**: qué hechos verificar y con qué comando viven en
> `ai-context/facts_rules.yaml` (catálogo). Para agregar un hecho nuevo (ej. una
> herramienta): añade su entrada al YAML — no hace falta tocar `buffy-verify.sh`
> ni el motor (`scripts/lib/facts_engine.py`).

> 🏛️ **Jerarquía de autoridad de fuentes** (cuando las fuentes se contradicen,
> gana la de MAYOR autoridad — `scripts/buffy-source.sh --resolve <fact>`):
>```
> 1. REAL-TIME SYSTEM  → valor observado AHORA (comandos del sistema)
> 2. FACTS (verified)  → facts.yaml con confidence 1.0 y TTL vigente
> 3. SNAPSHOT          → estado vivo generado (buffy-context.sh)
> 4. CONTINUE          → handoff de la última sesión
> 5. INFO-core         → contexto base documentado
> 6. INFERRED          → sin dato: inferencia marcada como tal
>```
> Ejemplo: si USER dice "uso Hyprland" pero el sistema reporta bspwm → gana
> el sistema (nivel 1). El resolver además reporta los CONFLICTOS (fuentes de
> menor autoridad que discrepan), para que el agente sepa que hay contradicción.
> `--no-live` ignora el nivel 1 (útil en CI o para resolver solo la doc).

### Paso 4 — Bitácora (OPCIONAL — con límite)
```markdown
ai-context/SESION.md     → SOLO las últimas 5 entradas (cabeceras visibles)
                           El archivo completo puede ser grande. No lo leas entero
                           a menos que la tarea requiera buscar algo específico.
                           Histórico completo en ai-context/SESION-archive.md.
```
```markdown
ai-context/PROJECTS.md   → Solo si menciona un proyecto específico
ai-context/CHANGELOG.md  → Solo si pregunta "¿qué cambió?" o busca un cambio anterior
ai-context/AGENTS.md     → Solo si necesita notas técnicas de agentes previos
```

---

## 📝 Protocolo obligatorio al cerrar sesión

### 1. `ai-context/CONTINUE.md` (SIEMPRE)
Resumen ultra-conciso (máximo 10 líneas, prioriza lo no obvio):
- Qué se hizo esta sesión (3-5 líneas máximo)
- Archivos modificados/creados (solo los relevantes)
- Pendientes para la próxima sesión (máximo 3)
- Problemas conocidos no resueltos

### 2. `ai-context/SNAPSHOT.md` (SI SE MODIFICÓ EL SISTEMA)
Si se instalaron paquetes, cambiaron proyectos, o se modificó la configuración del sistema.
Se puede regenerar con: `bash buffy-context.sh`

### 3. `ai-context/SESION.md` (SI HUBO CAMBIOS SIGNIFICATIVOS)
Se agrega una entrada al principio del archivo (no al final — así la info fresca está arriba):
```markdown
## 🧠 SESIÓN — [Fecha] (breve descripción)
...
```

> ⚠️ **Poda automática (regla única)**: SESION.md y CHANGELOG.md se podan con
> el primer límite que se alcance: **máximo 5 entradas O ~30KB**. Las entradas
> más viejas se mueven a `*-archive.md`. Así el archivo activo se mantiene
> liviano (~30KB ≈ 5-10% de la ventana de DeepSeek V4 Flash).
> Las 3 políticas anteriores (3 entradas / 5 entradas / 30KB) quedaron
> unificadas en esta regla: **5 entradas o 30KB, lo que ocurra primero**.

---

## 🎯 Carga condicional — Knowledge/ y Skills

**NO** cargues `Knowledge/` completo en cada sesión. Solo una categoría si y solo si
la tarea la requiere. Usa estos criterios de activación:

### Android (activación: proyecto Gradle, ADB, o mención de Android/scrcpy/Shizuku)

| Señal | Cómo detectar |
|---|---|
| `build.gradle.kts` o `.gradle` en el proyecto | `ls *.gradle.kts *.gradle 2>/dev/null` |
| ADB conectado | `adb devices | grep -v List` |
| Menciona "scrcpy", "Shizuku", "ADB", "Nubia", "HyperOS", "auto.js" | En el mensaje del usuario |
| Menciona "Free Fire", "GG Mouse", "game boost" | En el mensaje del usuario |

**Si se activa** → cargar solo los archivos relevantes de `Knowledge/Android/` según la tarea:
- ADB.md (comandos generales)
- Shizuku.md (solo si menciona Shizuku o permisos)
- scrcpy.md (solo si menciona scrcpy o mirroring)
- GameOptimization.md (solo si menciona rendimiento, FPS, CPU tuning)
- HyperOS.md (solo si menciona Xiaomi/HyperOS)
- Keymappers.md (solo si menciona GG Mouse, Mantis, keymapping)

**Skills a cargar**: `android-adb`, `shizuku-rikka`, `android-game-opt`, `scrcpy-freefire`
(y `android-agent` si se necesita diagnóstico completo).
Si la tarea es compilar/instalar/probar una app o conceder permisos → cargar
`.agents/skills/android-project-setup/SKILL.md` (build → install → permisos → launch,
probada en vivo con el ZTE Nubia).

### Code Search (activación: tarea que requiere buscar, explorar o entender código)

| Señal | Cómo detectar |
|---|---|
| Pide "busca X en el código" o "encuentra dónde se usa Y" | En el mensaje del usuario |
| Error que requiere encontrar definiciones de funciones/clases | En el mensaje del usuario |
| Necesita entender un flujo antes de modificarlo | En la tarea actual |

> ⚡ **CodeGraph PRIMERO**: si el proyecto tiene `.codegraph/` en su raíz
> (está indexado), usar CodeGraph **antes que ripgrep/grep** —
> `codegraph explore "<símbolos o pregunta>"` o la herramienta MCP
> `codegraph_explore` devuelven el código verbatim + call paths + blast radius
> en una llamada. Otros: `codegraph query/callers/callees/impact`.
> Indexados actualmente: `autoscript-mobile-interface` y `ManUninstaller`.

**Skills relacionadas**: `search_criteria_v4` (para consultas complejas que requieren
múltiples búsquedas coordinadas).

### React (activación: package.json con react, mención de JSX/TSX/Vite/Tailwind)

| Señal | Cómo detectar |
|---|---|
| `package.json` con `"react"` en dependencies | `cat package.json 2>/dev/null \| grep -iq react` |
| Menciona "JSX", "TSX", "componente", "hook", "estado" | En el mensaje del usuario |
| Proyecto PWA (widgetos, pwa_securguard, timemark) | En PROJECTS.md |

**Si se activa** → cargar de `Knowledge/React/`:
- React.md (patrones, hooks, performance) — casi siempre
- Vite.md (solo si menciona build, config, dev server)
- Tailwind.md (solo si menciona estilos, CSS, utilidades)
- PWA.md (solo si es un proyecto PWA)

### Linux (activación: mención de Arch, pacman, systemd, bspwm, kernel)

| Señal | Cómo detectar |
|---|---|
| Menciona "pacman", "systemd", "kernel", "bspwm", "Hyprland" | En el mensaje del usuario |
| Menciona "módulo", "driver", "sysctl", "dmesg" | En el mensaje del usuario |
| Error de sistema, paquete, o servicio | En el mensaje del usuario |

**Si se activa** → cargar de `Knowledge/Linux/`:
- System.md (si es sobre config de sistema, WM, servicios) — casi siempre
- Kernel.md (solo si menciona kernel, módulos, sysctl)

### Git (activación: mención de commit, push, merge, rebase, conflictos)

| Señal | Cómo detectar |
|---|---|
| Menciona "commit", "push", "pull", "merge", "rebase", "branch" | En el mensaje del usuario |
| Menciona "git", "stash", "conflicto", "diff" | En el mensaje del usuario |

**Si se activa** → cargar `Knowledge/Git/Commands.md`.

### Node (activación: mención de npm, package.json, dependencias)

| Señal | Cómo detectar |
|---|---|
| Menciona "npm", "npx", "package.json", "dependencia" | En el mensaje del usuario |
| `package.json` presente sin React | En el directorio actual |

**Si se activa** → cargar `Knowledge/Node/Node.md`.

### Shell (activación: mención de bash, zsh, script, awk, sed)

| Señal | Cómo detectar |
|---|---|
| Menciona "bash", "zsh", "script", "awk", "sed", "grep" | En el mensaje del usuario |
| Escribe o pide modificar un script `.sh` | En el mensaje del usuario |

**Si se activa** → cargar `Knowledge/Shell/Shell.md`.

### Visión/VLM (activación: imágenes, screenshots, capturas de Android)

| Señal | Cómo detectar |
|---|---|
| El usuario comparte una imagen, screenshot o captura de pantalla | En el mensaje del usuario |
| Menciona "VLM", "visión", "imagen", "screenshot", "captura" | En el mensaje del usuario |
| Error de Android con UI visible | En el mensaje del usuario |
| OCR en imágenes ("¿qué dice este texto?") | En el mensaje del usuario |

**Si se activa** → cargar:
- `Knowledge/Vision.md` — referencia de modelos VLM
- `scripts/see.sh` — script helper para analizar imágenes

**Modelo recomendado**: `minicpm-v` (vía Ollama).
**Alternativa ligera**: `moondream` si hay poca RAM.

---

## 🧠 Arquitectura de memoria

```markdown
ai-context/
├── LOAD_CONTEXT.md       ← Este archivo (protocolo de carga)
├── INFO-core.md          ← Contexto mínimo (cargar SIEMPRE, ~3KB)
├── INFO-full.md          ← Contexto detallado (rara vez)
│
├── SNAPSHOT.md           ← Estado vivo del sistema (cargar SIEMPRE, regenerable)
├── facts.yaml            ← Provenance de hechos (regenerable, ver Paso 2.5)
├── CONTINUE.md           ← Handoff entre sesiones (cargar SIEMPRE)
│
├── SESION.md             ← Últimas 5 entradas (cargar solo si la tarea lo requiere)
├── SESION-archive.md     ← Histórico completo (casi nunca se carga)
│
├── PROJECTS.md           ← Detalle de proyectos (cargar solo si menciona un proyecto)
├── CHANGELOG.md          ← Historial de cambios (cargar solo si pregunta qué cambió)
├── AGENTS.md             ← Notas técnicas de agentes (cargar bajo demanda)
│
├── deprecated/           ← Archivos obsoletos (SYSTEM.md, SYSTEM_FULL.md — NO usar)
└── README.md             ← Meta-información del directorio

~/.buffy/memories/        ← MEMORIA CURADA (fuera del repo, perfil-local):
│                            MEMORY.md (2.200 chars) + USER.md (1.375 chars)
│                            gestionada solo con scripts/buffy-memory.sh
```

---

## 💡 Tips para agentes

- **Si un proyecto tiene `.codegraph/`, usa CodeGraph antes que grep** — `codegraph explore/query/impact` da descubrimiento, call paths y blast radius en una llamada (MCP `codegraph_explore` ya configurado).
- **SNAPSHOT.md puede estar desactualizado**. Si necesitas datos frescos, ejecuta `buffy-context.sh` o lee `/proc/` directamente.
- **`facts.yaml` dice QUÉ tan confiable es cada dato de INFO-core.md** (source/confidence/fecha). Si un hecho está `stale`, usa el valor real de `facts.yaml` en vez del de la doc. Regenera con `buffy-verify.sh --update-facts`.
- **CONTINUE.md es el archivo más importante**. Si solo puedes leer uno, lee ese.
- **Knowledge/ no se carga completo nunca**. Usa la carga condicional de la sección de arriba.
- **NO dupliques información que ya está en INFO-core.md**. Referéncialo en vez de copiarlo.
- **Si no puedes escribir archivos** (modo read-only): al menos lee CONTINUE.md + INFO-core.md.
- **Las reglas personales en INFO-core.md son no negociables**.

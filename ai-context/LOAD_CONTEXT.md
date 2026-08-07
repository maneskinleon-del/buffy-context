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

**Si se activa** → cargar `.agents/skills/code-search/SKILL.md`:
- Define 3 modos de búsqueda: agente nativo → CLI (ripgrep/grep) → exploración manual
- Es portable entre Freebuff, Claude Code, Codex
- Estructura resultados en tabla: archivo, línea, contenido

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
- `.agents/skills/vision-adapter/SKILL.md` — adaptador portable de visión
- `Knowledge/Vision.md` — referencia de modelos VLM
- `scripts/see.sh` — script helper para analizar imágenes

**Modelo recomendado**: `minicpm-v` (vía Ollama).
**Alternativa ligera**: `moondream` si hay poca RAM.

**Skills relacionadas**: `code-search` (para buscar basado en texto extraído de la imagen).

---

## 🧠 Arquitectura de memoria

```markdown
ai-context/
├── LOAD_CONTEXT.md       ← Este archivo (protocolo de carga)
├── INFO-core.md          ← Contexto mínimo (cargar SIEMPRE, ~3KB)
├── INFO-full.md          ← Contexto detallado (rara vez)
│
├── SNAPSHOT.md           ← Estado vivo del sistema (cargar SIEMPRE, regenerable)
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
```

---

## 💡 Tips para agentes

- **Si un proyecto tiene `.codegraph/`, usa CodeGraph antes que grep** — `codegraph explore/query/impact` da descubrimiento, call paths y blast radius en una llamada (MCP `codegraph_explore` ya configurado).
- **SNAPSHOT.md puede estar desactualizado**. Si necesitas datos frescos, ejecuta `buffy-context.sh` o lee `/proc/` directamente.
- **CONTINUE.md es el archivo más importante**. Si solo puedes leer uno, lee ese.
- **Knowledge/ no se carga completo nunca**. Usa la carga condicional de la sección de arriba.
- **NO dupliques información que ya está en INFO-core.md**. Referéncialo en vez de copiarlo.
- **Si no puedes escribir archivos** (modo read-only): al menos lee CONTINUE.md + INFO-core.md.
- **Las reglas personales en INFO-core.md son no negociables**.

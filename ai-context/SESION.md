# 🧠 SESION — Bitácora de sesiones

> ⚠️ **Poda automática**: Solo se mantienen las últimas ~3 sesiones aquí.
> Histórico completo en `SESION-archive.md` (cargar solo si es necesario).

---

# 🧠 SESION — Buffy Freebuff (2026-07-30 noche — RAM + watchdog MCP + force-stop en scrcpy-freefire)

> Tema: diagnóstico de RAM, cleanup automático de chrome-devtools-mcp huérfanos, y matanza de apps de terceros antes de Free Fire.

---

## 🧹 Diagnóstico de RAM (13GB)

- Top consumidores: **Chrome (~1.1GB)**, **python3/open-webui uvicorn (~1GB)**, **freebuff (~515MB)**, **alacritty (~594MB)**
- Se identificaron **procesos huérfanos del agente**: `chrome-devtools-mcp` (npm exec + MCP + watchdog) quedaban vivos tras tareas de navegador (~1GB)

## 🛡️ Watchdog `cleanup-mcp.sh` + systemd timer

- `chrome-devtools-mcp` **NO tiene flag nativo de auto-exit** (revisado todo su `--help`)
- Se creó `~/.local/bin/cleanup-mcp.sh` (watchdog): mata MCP huérfanos con **edad > 10min** y **CPU del árbol < 1% en 2 muestras** (4s+6s+4s)
- Unidades systemd user: `mcp-cleanup.service` (oneshot) + `mcp-cleanup.timer` (cada 5 min, Persistent=true)
- Mató el MCP huérfano de la verificación GitHub → **~1.1GB liberados** (3.2GB usados)
- Log en `~/.local/state/mcp-cleanup.log`
- **3 pasadas de code review** aprobadas (fixes: guard race /proc/stat, árbol capturado una vez para KILL, doble muestra CPU, rotación log 500 líneas, clamp CPU negativa)

## 🎮 Force-stop de apps de terceros en `~/scripts/scrcpy-freefire.sh`

- Añadida función `kill_background_apps()` que ejecuta `pm list packages -3` + `am force-stop` en cada app de terceros
- **EXCLUSIONES**: `com.zjx.ztezscreenshot` (GG Mouse) y `com.dts.freefireth` (Free Fire) — se mantienen vivas
- Configurable: `KILL_BG_APPS="1"` (toggle) y `KEEP_ALIVE_APPS="com.zjx.ztezscreenshot com.dts.freefireth"`
- **Prueba real en ZTE**: 91 apps de terceros matadas, GG Mouse + Free Fire intactos ✅
- Se ejecuta ANTES de lanzar GG Mouse y Free Fire (sección previa a PERMISOS GG MOUSE)
- 2 pasadas de code review aprobadas (quoting de doble comilla + escapes verificado)

---

# 🧠 SESION — Buffy Freebuff (2026-07-30 — push repo GitHub + auditoría repo git del home)

> Tema: diagnosticar por qué "no se veían" los cambios en GitHub, subir los 12 commits pendientes, y auditar el repo git accidental del home.

---

## 📦 Repo GitHub `buffy-context` — push completado

### Diagnóstico
- Los cambios SÍ existían localmente (12 commits en `main`, incluyendo `aa556d9 Fix: token budget, conditional loading, pruning, deprecations`)
- El remoto usaba **HTTPS sin credenciales** → el push fallaba en silencio
- GitHub solo tenía el commit inicial `0c02f1a` (por eso "no se veía nada")

### Solución
- Cambiado el remote de HTTPS → **SSH** (`git@github.com:maneskinleon-del/buffy-context.git`), usando la llave `~/.ssh/id_ed25519` que ya estaba registrada en GitHub como `maneskinleon-del`
- **Push exitoso**: GitHub ahora muestra los 13 commits + README completo
- Verificado desde 3 fuentes: `git ls-remote`, GitHub API, navegador (13 commits, README "Buffy Context")

### Nota: fechas "yesterday"
- GitHub muestra la fecha de **autoría** (29/07), no la del push (30/07). Es comportamiento normal de git — los commits se escribieron ayer.

## 🗂️ Auditoría: repo git del home (`/home/mangonz`)

### Hallazgos
- `/home/mangonz` es un repo git en rama `master`, **sin remote** (3 commits: codebuff-automation + GameBoost Pro)
- Trackea **104 archivos**: `codebuff-automation/` completo + `proyectos/autoscript-mobile-interface/` (GameBoost Pro)
- **Esos proyectos NO tienen su propio `.git`** → el repo del home es su ÚNICA historia git
- **Decisión del usuario: dejarlo como está** (riesgo bajo sin remote). Opción de `.gitignore` agresivo queda disponible.

---

# 🧠 SESION — Buffy Freebuff (2026-07-29 — día completo: memoria + Knowledge + agentes + repo GitHub)

> Contexto de todo lo implementado durante la sesión completa del 2026-07-29.

---

## 📦 Repo GitHub `buffy-context`

### Creación del repositorio
- **`~/buffy-context/`** creado con estructura: `ai-context/`, `Knowledge/`, `.agents/skills/`, `scripts/`
- Git init + push a `github.com/maneskinleon-del/buffy-context` (público)
- **MIT License** agregada
- **README.md** profesional con badges, estructura, quick start, uso con agentes IA
- **INSTALL.md** con instrucciones de setup
- **6 commits** en `main`

### Correcciones post-feedback del usuario
Basado en análisis crítico de 5 puntos:

1. **Carga condicional para 6 categorías** (antes solo Android):
   - LOAD_CONTEXT.md reescrito con señales de activación para React, Linux, Git, Node y Shell
   - Cada categoría con detección explícita (package.json, mención de tema, etc.)

2. **Presupuesto de tokens + poda automática**:
   - SESION.md: 720 → 81 líneas (archivado a SESION-archive.md)
   - CHANGELOG.md: 429 → 132 líneas (archivado a CHANGELOG-archive.md)
   - Headers de poda agregados a ambos archivos

3. **Redundancia eliminada**:
   - Sección "Jerarquía de contexto" (duplicada) eliminada de LOAD_CONTEXT.md

4. **SYSTEM.md/SYSTEM_FULL.md deprecados**:
   - Marcados DEPRECATED con redirect a INFO-core.md/INFO-full.md

5. **Primera sesión**:
   - LOAD_CONTEXT.md ahora dice qué hacer si CONTINUE.md no existe

## 📚 Base de conocimiento `Knowledge/`

16 archivos · 1,305 líneas · 6 categorías creadas:

| Categoría | Archivos | Contenido |
|-----------|----------|-----------|
| Android | 6 | ADB, Shizuku, HyperOS, GameOptimization, scrcpy, Keymappers |
| Linux | 2 | System (Arch/bspwm/systemd), Kernel |
| React | 4 | React+TS, Vite, Tailwind v4, PWA |
| Git | 1 | Commands + gh CLI |
| Node | 1 | npm, package.json |
| Shell | 1 | Bash/Zsh scripting |

## 🤖 Android Agent

- **Skill**: `.agents/skills/android-agent/SKILL.md` — detecta proyectos Android automáticamente
- **Script**: `.local/bin/android-detect.sh` — diagnóstico con `--quick` y `--watch`
- **Shizuku activado**: rish extraído del APK (Shizuku v13.7.0 corriendo en ZTE Nubia)
- **DPI cambiado**: vía Shizuku, 480 físico → 280 override
- **Free Fire diagnosticado**: CPU 0.8% (background), 13% jank sistema, temp 30.1°C

## 🔍 Code Search adapter

- **Skill portable**: `.agents/skills/code-search/SKILL.md` — funciona en Freebuff, Claude Code, Codex
- 3 modos de búsqueda: agente nativo → CLI (ripgrep) → exploración manual
- **search_criteria_v4**: skill de búsqueda estructurada copiada al repo

## 🎮 Skill scrcpy-freefire expandida

### Secciones agregadas a `.agents/skills/scrcpy-freefire/SKILL.md`

#### 🧪 Diagnóstico de lag
- Tabla para identificar tipo de lag (input vs video vs thermal vs game)
- Interpretación de `--print-fps`
- Comandos `adb shell dumpsys gfxinfo` y `dumpsys SurfaceFlinger`
- Tabla de trade-offs completa
- Procedimiento diagnóstico de 5 pasos (con verificación USB incluida)

#### 🔧 Alternativas de keymappers
- **Mantis Gamepad Pro**: Setup completo con Shizuku, recomendada
- **Panda Mouse Pro**: Alternativa ligera
- **Octopus**: Advertencia de ban para Free Fire
- Tabla comparativa (GG Mouse vs Mantis vs Panda vs Octopus)

#### 🔍 Troubleshooting detallado (expandido)
- UHID: cursor invisible/atrapado, teclado no funciona, teclas stuck
- Input desync después de alt+tab
- Wayland vs X11 — problemas y soluciones
- GG Mouse Pro 2 se desactiva solo (5 causas + soluciones)
- Lag al girar cámara en Free Fire
- Free Fire borroso
- Problemas de permisos Shizuku

### Detalles pulidos post-review
- Advertencia de input lag en `--render-expired-frames`
- Chequeo USB agregado al diagnóstico de 5 pasos
- Orden del reset drástico movido a último recurso

---

## 🧠 Sistema de memoria persistente

### Contexto inicial
El usuario ya tenía una carpeta `ai-context/` con archivos manualmente mantenidos:
- `INFO-core.md`, `INFO-full.md` — contexto de sistema
- `SNAPSHOT.md` — generado por `buffy-context.sh`
- `SESION.md` — bitácora manual de sesiones anteriores
- `PROJECTS.md`, `CHANGELOG.md`, `AGENTS.md`, etc.

### Problemas identificados
1. **Sin protocolo formal** — cada agente empezaba desde cero, no había un "cargar esto primero"
2. **No había handoff** — `CONTINUE.md` no existía
3. **`buffy-context.sh` hardcodeaba "Mango WM (Wayland)"** — el usuario corre bspwm X11
4. **`scripts/ai-context.sh`** generaba zips inútiles en vez de contexto estructurado
5. **SNAPSHOT.md** decía "WM: Mango WM (Wayland)" — información incorrecta

### Solución implementada

| Archivo | Cambio |
|---------|--------|
| `ai-context/LOAD_CONTEXT.md` | **NUEVO**: Protocolo para agentes — qué leer al inicio y qué escribir al cierre |
| `ai-context/CONTINUE.md` | **NUEVO**: Handoff entre sesiones — resumen, archivos tocados, pendientes, stack |
| `ai-context/SNAPSHOT.md` | ✅ Actualizado: WM corregido a bspwm, estado fresco del sistema |
| `ai-context/SESION.md` | ✅ Actualizado: esta entrada |
| `~/.local/bin/buffy-context.sh` | ✅ Fix: detección dinámica de WM vía `loginctl` |

### Cómo funciona

**Al inicio de cada sesión** (para cualquier agente):
1. Leer `INFO-core.md` — contexto base del sistema
2. Leer `SNAPSHOT.md` — estado vivo (procesos, RAM, proyectos)
3. Leer `CONTINUE.md` — de qué halar, qué pendientes hay

**Al cierre de cada sesión** (para cualquier agente):
1. Escribir `CONTINUE.md` — resumen de lo hecho
2. Actualizar `SNAPSHOT.md` si cambió el sistema
3. Actualizar `SESION.md` con bitácora detallada

---

*Fin de la sesión — Última actualización: 2026-07-29*


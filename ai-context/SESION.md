# 🧠 SESION — Bitácora de sesiones

> ⚠️ **Poda automática**: Solo se mantienen las últimas ~3 sesiones aquí.
> Histórico completo en `SESION-archive.md` (cargar solo si es necesario).

---

# 🧠 SESION — Buffy Freebuff (2026-07-29 — memoria persistente + skill expandida)

> Contexto de todo lo implementado durante esta sesión.

---

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


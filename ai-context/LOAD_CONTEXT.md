# 🔄 PROTOCOLO DE CARGA — Memoria Persistente

> Este archivo explica a CUALQUIER agente IA (Buffy, Claude, Antigravity, etc.)
> cómo cargar el contexto de mangonz al inicio de una sesión.

---

## 📋 Protocolo obligatorio al iniciar sesión

Cuando comiences una sesión con mangonz, DEBES cargar estos archivos en este orden:

### Paso 1 — Contexto base del sistema
```
ai-context/INFO-core.md
```
Esto te da: OS, WM, shell, hardware, PATH, herramientas, reglas personales.

### Paso 2 — Estado vivo del sistema
```
ai-context/SNAPSHOT.md
```
Esto te da: procesos actuales, RAM/disco, proyectos activos con estado git, scripts disponibles.

### Paso 3 — Handoff de la sesión anterior
```
ai-context/CONTINUE.md
```
Esto te dice: qué se hizo en la última sesión, en qué quedó cada cosa, qué archivos se tocaron, qué pendientes hay.

### Paso 4 (opcional) — Más detalles
```
ai-context/SESION.md     → Bitácora completa de sesiones anteriores
ai-context/PROJECTS.md   → Detalle de cada proyecto
ai-context/CHANGELOG.md  → Historial de cambios
ai-context/AGENTS.md     → Notas técnicas para agentes
```

---

## 📝 Protocolo obligatorio al cerrar sesión

Antes de finalizar, DEBES actualizar estos archivos:

### 1. `ai-context/CONTINUE.md` (SIEMPRE)
Resumen ultra-conciso de:
- Qué se hizo esta sesión (3-5 líneas máximo)
- Archivos modificados/creados
- Pendientes para la próxima sesión
- Problemas conocidos no resueltos

### 2. `ai-context/SNAPSHOT.md` (SI SE MODIFICÓ EL SISTEMA)
Si se instalaron paquetes, cambiaron proyectos, o se modificó la configuración del sistema.
Se puede regenerar con: `buffy-context.sh`

### 3. `ai-context/SESION.md` (SI HUBO CAMBIOS SIGNIFICATIVOS)
Bitácora detallada de la sesión. Se agrega al final del archivo existente con:
```markdown
## 🧠 SESIÓN — [Fecha]
...detalle de cambios...
```

---

## 🧠 Arquitectura de memoria

```
ai-context/
├── INFO-core.md       → Contexto mínimo (cargar SIEMPRE)
├── INFO-full.md       → Contexto detallado (bajo demanda)
├── LOAD_CONTEXT.md    → Este archivo (protocolo de carga)
│
├── SNAPSHOT.md        → Estado vivo del sistema (regenerable con buffy-context.sh)
├── CONTINUE.md        → Handoff entre sesiones (actualizar cada cierre)
├── SESION.md          → Bitácora histórica de sesiones
│
├── PROJECTS.md        → Detalle de cada proyecto
├── CHANGELOG.md       → Historial de cambios
├── AGENTS.md          → Notas técnicas
│
└── SYSTEM.md          → Perfil de sistema (resumen)
    SYSTEM_FULL.md     → Perfil detallado
```

---

## 💡 Tips para agentes

- **SNAPSHOT.md** puede estar desactualizado. Si necesitas datos frescos, ejecuta `buffy-context.sh` o lee `/proc/` directamente.
- **CONTINUE.md** es el archivo más importante para retomar trabajo. Si solo puedes leer uno, lee ese.
- Si el usuario menciona un proyecto, busca en `PROJECTS.md` primero.
- Si menciona un cambio anterior, busca en `CHANGELOG.md`.
- Las reglas personales en `INFO-core.md` son **no negociables**.
- Si tu agente no puede escribir archivos (modo read-only): al menos intenta leer `CONTINUE.md` para tener contexto de la sesión anterior.
- El stack del usuario está en `INFO-core.md`. No duplicarlo en handoffs — referenciar ese archivo.

## 🤖 Agente Android dedicado

Si detectas contexto Android (proyecto con `build.gradle.kts`, dispositivo ADB conectado, o el usuario menciona Android/scrcpy/Shizuku), **activa el agente Android**:

### 1. Cargar Knowledge/Android/
```
~/Knowledge/Android/ADB.md
~/Knowledge/Android/Shizuku.md
~/Knowledge/Android/scrcpy.md
~/Knowledge/Android/GameOptimization.md
~/Knowledge/Android/HyperOS.md
~/Knowledge/Android/Keymappers.md
```

### 2. Activar skills Android
```
.agents/skills/android-adb/
.agents/skills/shizuku-rikka/
.agents/skills/scrcpy-freefire/
.agents/skills/android-game-opt/
.agents/skills/android-native-dev/
.agents/skills/android-clean-architecture/
.agents/skills/mobile-android-design/
```

### 3. Verificar conexión
```bash
# Diagnóstico rápido:
~/.local/bin/android-detect.sh --quick
```

### 4. Seguir el protocolo de la skill
```
.agents/skills/android-agent/SKILL.md
```

---

## 🧠 Jerarquía de contexto para agentes

Al iniciar una sesión, cargar en este orden:
1. `ai-context/INFO-core.md` — sistema, reglas, stack
2. `ai-context/SNAPSHOT.md` — estado vivo del sistema
3. `ai-context/CONTINUE.md` — handoff de sesión anterior
4. `ai-context/LOAD_CONTEXT.md` (este archivo) — protocolos especializados
5. **Si es Android**: `android-detect.sh` + Knowledge/Android/ + skills Android

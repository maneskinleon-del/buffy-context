# 🔄 CONTINUE — Handoff entre sesiones

> ⚡ **PRÓXIMA SESIÓN: LEE ESTO PRIMERO**
> Generado: 2026-07-29 (fin de sesión)

---

## Resumen de la última sesión

**Tema principal:** Expansión de la skill `scrcpy-freefire` + Implementación de memoria persistente.

### ✅ Logros

1. **Skill `scrcpy-freefire` expandida** (`.agents/skills/scrcpy-freefire/SKILL.md`):
   - 🧪 Sección **Diagnóstico de lag**: tabla de tipos de lag, comandos `dumpsys gfxinfo`, `--print-fps`, tabla de trade-offs, procedimiento diagnóstico de 5 pasos
   - 🔧 Sección **Alternativas de keymappers**: Mantis Gamepad Pro (recomendada), Panda Mouse Pro, Octopus (❌ no recomendado para Free Fire), tabla comparativa
   - 🔍 **Troubleshooting detallado**: UHID cursor invisible, input desync, Wayland vs X11, GG Mouse se desactiva solo, lag al girar cámara en FF, permisos Shizuku, y más

2. **Sistema de memoria persistente** (`ai-context/`):
   - 📋 **`LOAD_CONTEXT.md`** — Protocolo para que cualquier agente cargue contexto al inicio/fin de sesión
   - 🔄 **`CONTINUE.md`** — Este archivo, handoff entre sesiones
   - ✅ **`buffy-context.sh`** — Fixed: detecta bspwm dinámicamente (antes hardcodeaba "Mango WM")
   - 📸 **`SNAPSHOT.md`** — Actualizado con estado real del sistema

### 📁 Archivos modificados/creados

| Archivo | Cambio |
|---------|--------|
| `.agents/skills/scrcpy-freefire/SKILL.md` | ✅ Expandido (3 secciones nuevas, ~2x tamaño) |
| `ai-context/LOAD_CONTEXT.md` | **NUEVO** — Protocolo de carga para agentes |
| `ai-context/CONTINUE.md` | **NUEVO** — Este handoff |
| `ai-context/SNAPSHOT.md` | ✅ Actualizado con estado fresco |
| `ai-context/SESION.md` | ✅ Actualizado con sesión actual |
| `~/.local/bin/buffy-context.sh` | ✅ Fix: detección dinámica de WM |

### ⏳ Pendientes para próxima sesión

1. **Base de conocimiento `Knowledge/`** — Se habló de crearla con categorías (Android, Linux, ADB, React, etc.). Quedó pendiente.
2. **Visión/VLM** — Se discutió agregar Qwen2.5-VL o similar para análisis de imágenes/screenshots.
3. **Agente Android dedicado** — Que al detectar un proyecto Android, active ADB, logcat, scrcpy skills automáticamente.
4. **scrcpy-freefire.sh** — Mejorar el script con perfiles CLI (--fast, --quality, --ultrawide). El script actual está OK, no se tocó.
5. **Revisar scripts del sistema** — `scripts/ai-context.sh` está obsoleto (genera zips, no contexto útil). Reemplazar o eliminar.

### ⚠️ Notas

- `scripts/ai-context.sh` es un script legacy (genera zips de contexto para debugging). No interfiere con el sistema nuevo. Se puede ignorar o actualizar más adelante.
- `buffy-context.sh` — La línea hardcodeada "Mango WM (Wayland)" ya se cambió a detección dinámica.

---

## Stack del usuario (para referencia rápida)

```
OS:    EndeavourOS (Arch) · kernel 6.18.39-1-lts
WM:    bspwm (X11) · rice gh0stzk/cynthia · compositor picom
Shell: zsh (Oh My Zsh + Starship) · terminal alacritty
Launcher: rofi · editor: VSCodium · file manager: Thunar
CPU:   Ryzen 5 3400G (4C/8T) + Vega 11 · 13GB RAM
Monitor: 1360x768@60.015
Phone:  ZTE Nubia Z2352N (Unisoc T820) + Android vía ADB/Shizuku
Stack:  React + TypeScript + Tailwind v4 + Vite → GitHub → Vercel
Git:    maneskinleon-del / mangonz970@gmail.com / gh auth
```

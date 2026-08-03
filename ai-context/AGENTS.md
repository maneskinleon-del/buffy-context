---
version: 1.2
updated: 2026-07-26
schema: system-profile
system-id: mangonz-desktop
---

# AGENTS.md — mangonz-desktop

Instrucciones para cualquier agente de IA (Codex CLI, Gemini CLI, kimchi, freebuff, etc.)
que trabaje en este sistema.

## Antes de empezar

1. Leé `/home/mangonz/ai-context/INFO-core.md` con tu herramienta de lectura de archivos. Es contexto
   base: sistema operativo, WM, reglas, stack típico. Cargalo siempre, salga lo que salga
   la tarea.
2. Consultá la tabla de abajo para saber si necesitás algo más.
3. Respetá las reglas de la sección "Reglas" de `INFO-core.md`. No son sugerencias.
4. Preguntá antes de usar `sudo` o tocar `/etc`.

## Glosario — qué archivo leer, cuándo, y para qué

| Archivo | Cuándo leerlo | Para qué sirve | Qué NO tiene |
|---|---|---|---|
| `/home/mangonz/ai-context/INFO-core.md` | Siempre, al iniciar cualquier tarea | SO, WM actual (bspwm, X11), hardware, PATH, herramientas frecuentes, reglas no negociables | Detalle de versiones exactas, changelog, proyectos |
| `/home/mangonz/ai-context/INFO-full.md` | Solo si la tarea toca: portales XDG/Wayland, versiones exactas de paquetes, guía completa de Shizuku/rish, checklist de capacidades | Referencia técnica exhaustiva | Historial de cambios (eso está en CHANGELOG.md) |
| `/home/mangonz/ai-context/CHANGELOG.md` | Solo si necesitás entender por qué algo quedó configurado así, o si algo que "debería funcionar" según docs viejas no anda | Historial de decisiones y cambios del sistema (ej. migración Hyprland → Mango) | Contexto de proyectos individuales |
| `/home/mangonz/ai-context/PROJECTS.md` | Cuando la tarea es sobre un proyecto específico (TimeMark, SecurGuard, data_car, etc.) | Objetivo, stack, estado y rutas de cada proyecto activo | Contexto de sistema operativo/hardware |
| `/home/mangonz/ai-context/README.md` | Rara vez — es el punto de entrada para un agente nuevo que nunca vio esta carpeta | Resumen de 6 líneas del protocolo completo | Nada específico, es solo el índice |

## Notas técnicas importantes

### Transparencia en terminales
- Alacritty necesita **picom** (compositor) corriendo para mostrar transparencia. Sin picom, `opacity` no tiene efecto.
- Si el usuario reporta que la terminal se ve opaca, verificar: `ps aux | grep picom`
- La opacidad de Alacritty se fija en el theme config (`rices/<theme>/theme-config.bash` → `P_TERM_OPACITY`), NO directamente en `alacritty.toml`, porque el módulo `05-alacritty.sh` la sobreescribe en cada inicio de sesión.

### Barras (Polybar) del rice gh0stzk
- El rice usa Polybar con dos barras: `mel-bar` (superior) y `mel2-bar` (inferior)
- Config en `rices/<theme>/config.ini` y `rices/<theme>/modules.ini`
- Recarga recomendada (IPC habilitado con `enable-ipc = true`): `polybar-msg cmd restart`
  — recarga la config al instante SIN matar el proceso.
- Recarga manual solo si IPC está deshabilitado:
  `polybar-msg cmd quit && RICE=$(cat ~/.config/bspwm/.rice); MONITOR=HDMI-1 polybar mel-bar -c ~/.config/bspwm/rices/$RICE/config.ini & ...`
- Eww también tiene colores en `bspwm/eww/colors.scss` — sincronizar si se cambia paleta

### Context7 — Documentación actualizada de librerías
- **Siempre usar Context7** cuando se necesite documentación de librerías, frameworks, APIs o SDKs
- Comandos:
  - `ctx7 library <nombre> <consulta>` — busca una librería
  - `ctx7 docs <libraryId> <consulta>` — obtiene documentación
- Skill instalada en `.agents/skills/context7/`
- Ejemplo: `ctx7 docs /vercel/next.js "App Router middleware"`

## Reglas de eficiencia (kimchi y agentes de coding en general)

- No cargues `INFO-full.md` ni `PROJECTS.md` completos si la tarea no los necesita —
  cada uno cuesta tokens que no vuelven.
- Si vas a tocar un proyecto puntual, leé solo su sección en `PROJECTS.md`, no el archivo
  entero si es muy largo.
- Si tu propio archivo de reglas (`EFICIENCIA.md` de kimchi, config de freebuff, etc.)
  ya cubre algo de esto, no lo dupliques acá — referencialo.

## Notas de compatibilidad

- Gemini CLI puede apuntar directamente a este archivo configurando
  `contextFileName: "AGENTS.md"` en `~/.gemini/settings.json` (si lo reinstalas) — no dupliques este
  contenido en un `GEMINI.md` aparte.

---
version: 1.3
updated: 2026-07-26
schema: system-profile
system-id: mangonz-desktop
---

# SYSTEM.md — Contexto base (mangonz-desktop)

> Cargar siempre. Detalle exhaustivo → `SYSTEM_FULL.md`. Historial de cambios → `CHANGELOG.md`. Proyectos → `PROJECTS.md`.

## Sistema
- OS: EndeavourOS (Arch) — kernel 6.18.39-1-lts
- WM actual: **bspwm** (X11) — con rice gh0stzk/cynthia
- Shell: zsh (Oh My Zsh + Starship)
- Terminal: alacritty (Nord palette, opacidad 0.85)
- Compositor: picom (necesario para transparencia en ventanas)
- Launcher: rofi (Alt+Space, vía sxhkd)
- Editor: VSCodium
- File manager: Thunar
- Locale: es_CL.UTF-8

## Hardware
- Ryzen 5 3400G (4C/8T) + Vega 11 integrada, ~13GB RAM
- Monitor: 1360x768@60.015 (HDMI-A-1)

## PATH (orden)
```
~/.kilo/bin → ~/.npm-global/bin → ~/.local/bin → /usr/local/sbin → /usr/local/bin → /usr/bin
```

## Herramientas de uso frecuente
git 2.55.0 · node v26.4.0 · npm 11.18.0 · python3 3.14.6 · cargo/rustc · adb/fastboot · Shizuku v13.7.0 + rish (`/data/local/tmp/rish`) · gh (GitHub CLI) · vercel · uv · ollama 0.30.7

## Servicios del sistema (user)
- **Ollama**: systemd --user, auto-inicio (`~/.config/systemd/user/ollama.service`)
  - API: `http://localhost:11434`
  - Modelos: `qwen2.5:7b` (local, 4.7GB) + `nemotron-3-super:cloud` (cloud stub)

## Agentes IA en uso
freebuff · Antigravity · Claude (chat)

## Reglas (no negociables)
```yaml
shell: zsh > bash
graphics: Wayland > X11
wm: bspwm
clipboard: xclip > wl-copy/wl-paste
compositor: picom (verificar con `ps aux | grep picom`)
package-manager: npm (global → ~/.npm-global)
git-user: Manuel Gonzalez <mangonz970@gmail.com>
git-auth: gh auth git-credential

reglas:
  - No modificar archivos del sistema sin avisar
  - Preferir CLI sobre GUI cuando exista
  - Preferir systemd si hay una solución con systemd
  - No tocar /etc sin permiso explícito
  - Usar bspwmrc para config de inicio de sesión
```

## Stack de desarrollo típico
React + TypeScript + Tailwind v4 + Vite → GitHub (`maneskinleon-del`) → Vercel.
Detalle de cada proyecto activo → `PROJECTS.md`.

## Protocolo de carga (para cualquier agente)
- Este archivo es el contexto base — cargarlo siempre que el agente necesite saber sobre el sistema.
- `SYSTEM_FULL.md` es bajo demanda — no cargarlo automáticamente en cada sesión/ferment/prompt.
- Si el agente tiene su propio archivo de reglas (`AGENTS.md`, `.claude/`, `.codex/`, `.gemini/`, config de freebuff/Antigravity), apuntar la referencia de sistema ahí a este archivo, no a versiones propias copiadas.

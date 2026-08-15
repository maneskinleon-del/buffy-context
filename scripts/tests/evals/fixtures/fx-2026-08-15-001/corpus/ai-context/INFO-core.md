# 🖥️ INFO-CORE — mangonz (cargar siempre)

> Contexto mínimo para cualquier agente IA. Para detalle histórico, hardware completo, changelog o checklist de capacidades → ver `INFO-full.md`.
> Actualizado: 2026-08-09

## Sistema
- OS: EndeavourOS (Arch) — kernel 6.18.42-1-lts
- WM actual: **bspwm** (X11) — con rice gh0stzk/**vista** (estilo Windows Vista Aero; backup del anterior en `~/.config/bspwm/.rice.bak`)
- Shell: zsh (Oh My Zsh + Starship)
- Terminal: alacritty (Nord palette, opacidad 0.85)
- Compositor: picom (necesario para transparencia)
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
git 2.55.0 · node v26.7.0 · npm 12.0.2 · python3 3.14.6 · cargo/rustc · adb/fastboot · Shizuku v13.7.0 + rish (`/data/local/tmp/rish`) · gh (GitHub CLI) · vercel · **codegraph v1.5.0** (grafo de código local)

## IA/CLI instaladas
freebuff · **opencode (Buffy — modelos free)** · Antigravity · Claude Code (ext. VSCodium) · Gemini CLI · Cline · command-code

## CodeGraph (descubrimiento y análisis de código)
- Grafo de conocimiento SQLite (tree-sitter), 100% local — servidor MCP `codegraph serve --mcp` configurado en **Claude Code, Gemini CLI, Antigravity y Cline** (herramienta `codegraph_explore`).
- **Regla**: si un proyecto tiene `.codegraph/` en su raíz, usar CodeGraph ANTES de grep/find para descubrimiento, call paths y análisis de impacto.
- **Indexados**: `~/proyectos/autoscript-mobile-interface/` (49 archivos · 1.084 símbolos) y `~/proyectos/ManUninstaller/` (31 · 486).
- CLI: `codegraph explore/query/callers/callees/impact/node/files`. Detalle en `~/.AGENTS.md` y `LOAD_CONTEXT.md` (sección Code Search).

## Skills instaladas (`~/.agents/skills/`)
| Skill | Uso |
|---|---|
| **android-project-setup** | Setup Android: build gradle → install APK → permisos Shizuku/overlay/batería → launch. Scripts en `.agents/skills/android-project-setup/scripts/` (check_device, build_install, grant_permissions) + referencias. Probada en vivo con el ZTE Nubia. |
| android-agent · android-adb · shizuku-rikka · scrcpy-freefire · xiaomi-adb-tricks · hyperos-hardening | Android: diagnóstico, ADB, Shizuku, Free Fire, permisos |
| skill-creator · changelog-generator · file-organizer | Creación de skills, changelogs, organización |

Cargar la skill relevante según la tarea (ver `ai-context/LOAD_CONTEXT.md` — protocolo de carga condicional).

## Reglas personales (no negociables)
```yaml
shell: zsh > bash
graphics: Wayland > X11
wm: bspwm
clipboard: xclip > wl-copy/wl-paste
package-manager: npm (global → ~/.npm-global)
git-user: Manuel Gonzalez <mangonz970@gmail.com>
git-auth: gh auth git-credential

reglas:
  - No modificar archivos del sistema sin avisar
  - Preferir CLI sobre GUI cuando exista
  - Preferir systemd si hay una solución con systemd
  - No tocar /etc sin permiso explícito
  - Usar mango-session wrapper para iniciar sesión
```

## Estructura de proyectos activos
```
~/antigravity/{SecurGuard-AI}/
~/data_car/          # AutoData MG 350
~/lista_fresh/ ~/lista_supermercado/
~/timemark/          # TimeMark PWA
~/proyectos/{ManUninstaller, GameBoostPro, widgetos, Tela-circle-icon-theme}/
```
Stack típico: React + TypeScript + Tailwind v4 + Vite → GitHub (`maneskinleon-del`) → Vercel.

## Cuándo leer INFO-full.md
Solo si la tarea necesita: changelog de un cambio específico, tabla completa de paquetes/versiones, detalle de portales XDG/Wayland, o guía de Shizuku paso a paso.

## Base de conocimiento (`Knowledge/`)

Existe una base de conocimiento estructurada en `~/Knowledge/` con referencias rápidas:

| Categoría | Archivos |
|-----------|----------|
| Android | ADB, Shizuku, HyperOS, GameOptimization, scrcpy, Keymappers |
| Linux | System (Arch/bspwm/systemd), Kernel |
| React | React+TS, Vite, Tailwind v4, PWA |
| Git | Commands + gh CLI |
| Node | Node.js + npm |
| Shell | Bash/Zsh scripting |
| Tools | CodeGraph (grafo de código, MCP, troubleshooting) |

Cargar el archivo relevante cuando la tarea involucre ese tema.

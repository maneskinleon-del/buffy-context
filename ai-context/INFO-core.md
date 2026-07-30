# 🖥️ INFO-CORE — mangonz (cargar siempre)

> Contexto mínimo para cualquier agente IA. Para detalle histórico, hardware completo, changelog o checklist de capacidades → ver `INFO-full.md`.
> Actualizado: 2026-07-26

## Sistema
- OS: EndeavourOS (Arch) — kernel 6.18.39-1-lts
- WM actual: **bspwm** (X11) — con rice gh0stzk/cynthia
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
git 2.55.0 · node v26.4.0 · npm 11.18.0 · python3 3.14.6 · cargo/rustc · adb/fastboot · Shizuku v13.7.0 + rish (`/data/local/tmp/rish`) · gh (GitHub CLI) · vercel · uv · morph (MorphLLM)

## IA/CLI instaladas
freebuff · Antigravity

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

Cargar el archivo relevante cuando la tarea involucre ese tema.

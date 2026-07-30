---
version: 1.3
updated: 2026-07-26
schema: system-profile
system-id: mangonz-desktop
---

# SYSTEM_FULL.md — Detalle técnico exhaustivo

> Referencia bajo demanda. No cargar completo salvo que la tarea lo requiera (ver README.md). Historial de cambios → `CHANGELOG.md`. Proyectos → `PROJECTS.md`.

## Software instalado (detalle)

### Window Managers
| WM | Versión | Estado |
|---|---|---|
| bspwm | `bspwm 0.9.10-1` | ✅ Primario (X11) |
| Rice activo | gh0stzk/cynthia | ✅ Activo |
| Mango | `mangowm-git r1693.8216cacb-1` (0.14.4) | ❌ Legacy (Wayland) |

### Terminales
| Programa | Versión |
|---|---|
| alacritty (primario) | 0.17.0-1 |
| foot (legacy, Wayland-only) | 1.27.0-1 |
| kitty | 0.47.1-1 |

### Lanzadores
| Programa | Versión | Estado |
|---|---|---|
| rofi | 2.0.0-1 | ✅ Activo |
| wofi | 1.5.3-1 | ❌ Legacy (Wayland) |

### Navegadores / File managers
- Firefox (`/usr/bin/firefox`, primario), Chromium
- Thunar (primario), Dolphin, Nautilus

### Editores / IDEs
- VSCodium (`/usr/bin/codium`), Helix (`/usr/bin/hx`)

### Portales XDG
- xdg-desktop-portal 1.22.1-2
- xdg-desktop-portal-wlr 0.8.2-1
- xdg-desktop-portal-gtk 1.15.3-1

### Otros
- Clipboard: xclip (primario) · wl-copy/wl-paste (legacy Wayland)
- Captura: maim + slop / import (ImageMagick)
- Compositor: picom
- Bluetooth: Blueman · Firewall: firewalld · Impresión: CUPS
- Docker, Flatpak
- Android: ADB, fastboot, Shizuku, rish

---

## Configuración personal (detalle)

### Variables de entorno
| Variable | Valor |
|---|---|
| `SHELL` | `/usr/bin/zsh` |
| `LANG` | `es_CL.UTF-8` |
| `XDG_RUNTIME_DIR` | `/run/user/1000` |
| `QT_QPA_PLATFORMTHEME` | `qt6ct` |
| `KIMCHI_API_KEY` | `castai_v1_*` (Kimchi AI — legacy, no exponer) |

> `EDITOR`, `BROWSER`, `TERMINAL`, `PAGER`, `XDG_CONFIG_HOME/DATA_HOME/CACHE_HOME` no están definidas explícitamente; usan default de Mango.

### Alias
| Alias | Comando |
|---|---|
| `run` | `npm run` |

Solo existe en `.zshrc`; nada en `.bashrc`.

### Oh My Zsh
- Tema: `robbyrussell`
- Plugins: git, npm, docker, sudo
- Externos: zsh-autosuggestions, zsh-syntax-highlighting
- Starship: `add_newline=false`, `truncation_length=3`, `success_symbol="❯"`, `error_symbol="❯"`

### Estructura completa de `~/`
```
~/
├── Descargas/ Documentos/ Escritorio/ Música/
├── Pictures/Screenshots/
├── scripts/
├── antigravity/{superlista, scuderia-data, SecurGuard-AI}/
├── data_car/ lista_fresh/ lista_supermercado/ timemark/
├── proyectos/{ManUninstaller, GameBoostPro, autoscript-mobile-interface, widgetos}/
├── .config/bspwm/ .config/alacritty/ .config/sxhkd/
├── .android/ .npm-global/ .cargo/ .ssh/
└── ai-context/
```

---

## Capacidades disponibles (checklist)

**Desarrollo:** git 2.55.0 · gcc 16.1.1 · clang · python3 3.14.6 · node v26.4.0 · npm 11.18.0 · cargo/rustc 1.96.1 · go · make · cmake

**Android:** adb · fastboot · Shizuku · rish · apksigner · jadx

**X11:** xrandr · xclip · xdotool · maim · slop

**Redes:** ssh · rsync · curl · wget

**IA/CLI:** freebuff · Antigravity · uv · gh · vercel · morph (MorphLLM) · (codex/claude/gemini legacy)

**Paquetes:** pacman · paru · yay · npm · cargo · pip · flatpak

---

## Shizuku + ADB + rish (guía completa)

| Item | Valor |
|---|---|
| Dispositivo | Android vía ADB |
| Shizuku | `shizuku-v13.7.0` (`moe.shizuku.privileged.api`) |
| rish en dispositivo | `/data/local/tmp/rish` |
| RISH_APPLICATION_ID | `moe.shizuku.privileged.api` |
| Verificación | `adb shell /data/local/tmp/rish -c "id"` → `uid=2000(shell)` |
| Inicio | abrir app Shizuku → "Start" |
| Optimización batería | `adb shell dumpsys deviceidle whitelist +moe.shizuku.privileged.api` |
| Guía completa | `/sdcard/uso_shizuku.md` |

---

## Referencias de archivos

| Recurso | Ruta |
|---|---|
| Config bspwm | `~/.config/bspwm/bspwmrc` |
| Hotkeys sxhkd | `~/.config/bspwm/config/sxhkdrc` |
| Tema actual | `~/.config/bspwm/.rice` → `cynthia` |
| Terminal (primaria) | `~/.config/alacritty/alacritty.toml` |
| Theme config (cynthia) | `~/.config/bspwm/rices/cynthia/theme-config.bash` |
| Polybar config | `~/.config/bspwm/rices/cynthia/config.ini` |
| Polybar modules | `~/.config/bspwm/rices/cynthia/modules.ini` |
| Alacritty rice colors | `~/.config/alacritty/rice-colors.toml` |
| Compositor (picom) | `~/.config/bspwm/config/picom/picom.conf` |
| Picom rules | `~/.config/bspwm/config/picom/picom-rules.conf` |
| Eww colors | `~/.config/bspwm/eww/colors.scss` |
| Shell config | `~/.zshrc` |
| Prompt config | `~/.config/starship.toml` |
| Git config | `~/.gitconfig` |
| Thunar config | `~/.config/Thunar/thunar.xml` |
| Shizuku guide | `/sdcard/uso_shizuku.md` |
| Keybinds de Mango (legacy) | `~/.config/mango/config.conf` |
| Tema de wofi (legacy) | `~/.config/wofi/style.css` |
| Config Noctalia (legacy) | `~/.config/noctalia/` |

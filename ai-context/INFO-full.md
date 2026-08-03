# 🖥️ INFO-FULL — Detalle exhaustivo (mangonz)

> Cargar solo bajo demanda (ver criterios en INFO-core.md). Este archivo no debe inyectarse completo en cada prompt: es referencia, no contexto base.
> Actualizado: 2026-07-26

---

## 📋 Índice

1. [Software instalado (detalle)](#-software-instalado-detalle)
2. [Configuración personal (detalle)](#-configuración-personal-detalle)
3. [CHANGELOG completo](#-changelog-completo)
4. [Capacidades disponibles (checklist)](#-capacidades-disponibles-checklist)
5. [Shizuku + ADB + rish (guía completa)](#-shizuku--adb--rish-guía-completa)
6. [Referencias de archivos](#-referencias-de-archivos)

---

## 📦 Software instalado (detalle)

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
| foot (Wayland-only) | 1.27.0-1 |
| kitty | 0.47.1-1 |

### Lanzadores
| Programa | Versión | Estado |
|---|---|---|
| wofi | 1.5.3-1 | ✅ Activo |
| rofi | 2.0.0-1 | ⚠️ Inactivo |

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
- XWayland: xorg-xwayland 24.1.12-1
- Clipboard: wl-copy/wl-paste + wl-clip-persist + xclip (legacy)
- Captura: grim + slurp
- Bluetooth: Blueman · Firewall: firewalld · Impresión: CUPS
- Docker, Flatpak
- Android: ADB, fastboot, Shizuku, rish

---

## 🎯 Configuración personal (detalle)

### Variables de entorno
| Variable | Valor |
|---|---|
| `SHELL` | `/usr/bin/zsh` |
| `LANG` | `es_CL.UTF-8` |
| `XDG_RUNTIME_DIR` | `/run/user/1000` |
| `QT_QPA_PLATFORMTHEME` | `qt6ct` |
| `KIMCHI_API_KEY` | `castai_v1_*` (Kimchi AI — no exponer completo en logs ni prompts) |

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
├── .config/ .local/ .cache/
├── .gemini/
├── .android/ .npm-global/ .cargo/ .ssh/
└── INFO.md
```

---

## 📜 CHANGELOG completo

### 2026-07-26 — Sesión Buffy: Transparencia Alacritty + Colores Polybar

**Problema:** Alacritty no mostraba transparencia. Causa: picom no corriendo + módulo `05-alacritty.sh` reseteando opacidad a 0.98.

**Arreglos:**
- `rices/melissa/theme-config.bash`: `P_TERM_OPACITY="0.98"` → `"0.85"`
- `alacritty/alacritty.toml`: `opacity = 0.98` → `0.85`
- Picom iniciado (no estaba corriendo)

**Polybar — Colores para tema melissa:**
- Barra bg: `#003b4252` (transparente) → `#1e222a` (sólido oscuro)
- Secciones coloreadas con acentos Nord (CPU verde, RAM cyan, NET púrpura, etc.)
- Eww colors.scss sincronizado

**Archivos:** `rices/melissa/config.ini`, `modules.ini`, `theme-config.bash`, `eww/colors.scss`

---

### 2026-07-20 — Sesión Buffy: limpieza masiva de agentes + ManUninstaller v2

**Limpieza de agentes (~3.2 GB liberados):**
- Eliminados: Kimchi (139 MB), Claude Code (477 MB), Hermes (1.9 GB), aichat (12 MB),
  OpenCode (243 MB), Codex CLI (104 MB), Gemini CLI (85 MB), Mimocode (177 MB),
  Cline (108 KB), Odysseus (772 KB)
- Agentes que permanecen: freebuff · Antigravity · Claude (chat)

**ManUninstaller v2.0.0:**
- Transformación completa: navegación con sort, filtros por tipo/tamaño,
  búsqueda reactiva, App Detail Sheet, pestaña Herramientas, stats reales,
  paleta púrpura oscura → `~/proyectos/ManUninstaller/`
- 29 tests pasan, build exitoso

**Nuevas herramientas:** `buffy-context.sh`,
  10 skills instaladas (android, vite, vitest, tailwind, typescript, etc.)

---

### 2026-07-05 — Restructuración de INFO.md
Se dividió en INFO-core.md (contexto base) + INFO-full.md (este archivo, referencia bajo demanda). Motivo: reducir costo de tokens al cargar contexto en agentes con ventana chica (ej. kimchi).

### Anteriores
1. **Resolución de pantalla** — `wlr-randr --output HDMI-A-1 --mode 1360x768@60.015`, agregado a `~/.config/mango/config.conf`.
2. **Launcher Noctalia en Mango (Alt+Space)** — `bind=Alt,space,spawn,rofi -show drun` → `... quickshell -c noctalia-shell ipc call launcher toggle`.
3. **Fix apps no abren desde launcher Noctalia** — causa: `MangoService.qml` con sintaxis incompatible con `mmsg` 0.14.4. Solución: wrapper `~/.local/bin/mmsg` + fix de PATH en `mango-session`.
4. **Launcher: wofi reemplaza Noctalia** — el launcher de Noctalia dejó de funcionar al reiniciar sesión. Activado `Alt+Space → wofi --show drun`, tema Ayu en `~/.config/wofi/style.css`.
5. **Keybinds nuevos** — Alt+B (Firefox), Alt+C (VSCodium), Win+1-4 (tags).
6. **Fix conflicto Alt+E** — eliminado bind duplicado con Thunar.
7. **Session wrapper `mango-session`** — creado junto con `mango.service` y `mango.desktop`.
8. **SDDM autologin → mango** — `/etc/sddm.conf.d/autologin.conf` y `/usr/share/wayland-sessions/mango.desktop`.
9. **Captura de pantalla** — Win+BackSpace (completa), Win+Shift+BackSpace (región), guardado en `~/Pictures/Screenshots/`.
10. **Shizuku + rish** — configuración completa en dispositivo Android.
11. **systemd-boot timeout** — 5s → 3s en `/efi/loader/loader.conf`.

### Migración Hyprland/Caelestia → Mango WM (permanente)
Cambio definitivo de compositor. Hyprland + dotfiles Caelestia quedan retirados; Mango WM + Noctalia (Quickshell) es el setup actual y estable. Cualquier agente con contexto previo de Hyprland/Caelestia debe descartarlo — no es un setup en paralelo, es un reemplazo.

---

## ✅ Capacidades disponibles (checklist)

**Desarrollo:** git 2.55.0 · gcc 16.1.1 · clang · python3 3.14.6 · node v26.4.0 · npm 11.18.0 · cargo/rustc 1.96.1 · go · make · cmake

**Android:** adb · fastboot · Shizuku · rish · apksigner · jadx

**Wayland:** grim · slurp · wl-copy/paste · wlr-randr · wl-clip-persist

**Redes:** ssh · rsync · curl · wget

**IA/CLI:** freebuff · Antigravity · uv · gh · vercel

**Paquetes:** pacman · paru · yay · npm · cargo · pip · flatpak

---

## 📱 Shizuku + ADB + rish (guía completa)

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

## 📎 Referencias de archivos

| Recurso | Ruta |
|---|---|
| Keybinds de Mango | `~/.config/mango/config.conf` |
| Tema de wofi | `~/.config/wofi/style.css` |
| Config Noctalia | `~/.config/noctalia/` |
| Wrapper mmsg | `~/.local/bin/mmsg` |
| Session wrapper | `~/.local/bin/mango-session` |
| Servicio systemd | `~/.config/systemd/user/mango.service` |
| Sesión SDDM | `~/.local/share/wayland-sessions/mango.desktop` |
| Shell config | `~/.zshrc` |
| Prompt config | `~/.config/starship.toml` |
| Git config | `~/.gitconfig` |
| Shizuku guide | `/sdcard/uso_shizuku.md` |

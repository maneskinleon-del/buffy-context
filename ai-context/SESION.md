# 🧠 SESION — Buffy Freebuff (2026-07-26)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎨 Thunar — Iconografía Mac (WhiteSur) + Transparencia

### Problema
Thunar usaba iconos TokyoNight-SE (no Mac-style) y no tenía transparencia. El CSS existente estaba en `~/.config/gtk-4.0/` pero Thunar usa GTK3, no GTK4.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: Cambiado `gtk-icon-theme-name` de `TokyoNight-SE` a `WhiteSur` (global GTK3)
- **`~/.config/gtk-3.0/gtk.css`**: Creado con:
  - Fondos translúcidos `rgba()` con alpha
  - Glass effect en sidebar, statusbar, frame principal
  - Bordes redondeados (14px)
  - Acento verde #24BD5C
  - Animaciones suaves en hover/selected
- **`~/.config/bspwm/config/picom/picom-rules.conf`**: Agregada regla para `class_g='Thunar'`:
  - `blur-background = true`
  - `corner-radius = 10`
  - `fade = true`, `shadow = true`

### Lecciones
- `GTK_ICON_THEME` **no funciona** como env var en GTK3 (probado con Python GTK binding)
- La única forma de cambiar icon theme es vía `settings.ini` global o wrapper con `XDG_CONFIG_HOME`
- El `.desktop` file con `env` no afecta cuando Thunar se lanza desde sxhkd
- Se modificó `OpenApps` y luego se revirtió — la solución global `settings.ini` fue la definitiva

---

## 🔤 Alacritty — Tamaño de fuente reducido

- **`~/.config/alacritty/fonts.toml`**: `size = 14` → `size = 11`

---

## 🦊 Firefox — Fuente UI + Pestañas verticales

### Problema 1: Fuente monospace en UI
Firefox usaba `UbuntuMono Nerd Font 11` (monospace) para toda su interfaz GTK3: menús, URL bar, pestañas, etc.

### Solución
- **`~/.config/gtk-3.0/settings.ini`**: `gtk-font-name` cambiado de `UbuntuMono Nerd Font 11` a `Fira Sans Semi-Bold 11`

### Problema 2: Pestañas horizontales comprimidas
Muchas pestañas abiertas (IAs, proyectos) haciendo la tab strip ilegible.

### Solución
- **`~/.config/mozilla/firefox/pw5luhdq.default-release/user.js`**: Creado con:
  - `user_pref("sidebar.revamp", true);`
  - `user_pref("sidebar.verticalTabs", true);`
  - `user_pref("sidebar.visibility", "always-show");`
- El `user.js` es persistente — Firefox nunca lo sobrescribe (a diferencia de `prefs.js`)
- Nota: `sidebar.main.tools` en prefs.js está seteado a una extensión de terceros, podría interferir

### Notas técnicas
- Perfil Firefox encontrado en `~/.config/mozilla/firefox/` (ruta XDG), NO en `~/.mozilla/firefox/`
- Intentos fallidos previos: editar `prefs.js` directamente (Firefox lo sobrescribe al cerrar)
- Firefox 152.0.6-1

---

## 🎭 Playwright — Skill instalada

- **Skill**: `microsoft/playwright-cli@playwright-cli` instalada en `.agents/skills/playwright-cli`
- **CLI**: `@playwright/cli` instalado globalmente via npm
- **Browser**: Firefox 152.0.4 descargado para Playwright (~106MB) en `~/.cache/ms-playwright/firefox-1534`
- **Comandos básicos**: `playwright-cli open`, `goto`, `screenshot`, `close`, `click`, `fill`, `snapshot`

---

## 🔄 Alacritty → Foot → Revertido

### Intento
Se intentó reemplazar Alacritty por Foot como terminal principal del sistema.

### Cambios realizados (luego revertidos)
- `~/.config/bspwm/config/.term`: `alacritty` → `foot`
- `~/.config/bspwm/bin/Term`: Agregado case `foot` con `--app-id` para todos los modos
- `~/.config/bspwm/bin/Bspwm-ScratchPad`: Agregado case `foot` con `--app-id`
- `~/.config/geany/geany.conf`: `terminal_cmd` actualizado a `foot -e /bin/zsh %c`
- `~/.config/bspwm/config/modules/05-foot.sh`: **Creado** (módulo rice para foot)

### Causa del fallo
Foot es un emulador de terminal **nativo de Wayland**. No puede ejecutarse bajo X11:
```
err: wayland.c:1788: failed to connect to wayland; no compositor running?
```
El usuario corre bspwm (X11), por lo que foot no funciona.

### Resolución
Todos los cambios revertidos. Alacritty sigue siendo el terminal por defecto.

### Lecciones
- Foot solo funciona con compositores Wayland (Mango WM, Hyprland, etc.)
- `--app-id` es el equivalente Wayland de `--class` en X11
- El módulo `05-foot.sh` se dejó en disco por si en futuro se usa Wayland (actualmente inactivo)

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/gtk-3.0/settings.ini` | Icon theme: TokyoNight-SE → WhiteSur. Font: UbuntuMono → Fira Sans. Habilite animaciones |
| `~/.config/gtk-3.0/gtk.css` | **NUEVO**: Thunar GTK3 CSS con transparencia, glass effect, rounded corners |
| `~/.config/bspwm/config/picom/picom-rules.conf` | Regla Thunar con blur-background + corner-radius |
| `~/.config/alacritty/fonts.toml` | Font size 14 → 11 |
| `~/.local/share/applications/thunar.desktop` | **NUEVO** (creado, luego mantenido como backup) |
| `~/.config/mozilla/firefox/pw5luhdq.default-release/user.js` | **NUEVO**: Pestañas verticales Firefox |
| `~/.agents/skills/playwright-cli/` | **NUEVO**: Skill playwright-cli instalada |
| `~/.config/bspwm/config/modules/05-foot.sh` | **NUEVO**: Módulo rice para Foot (inactivo — Wayland-only) |
| `ai-context/CHANGELOG.md` | Actualizado con cambios de esta sesión |
| `ai-context/SESION.md` | Actualizado con el intento Foot + revert |

---

## 🪟 Alacritty — Transparencia (opacidad 0.85) + Fix picom

### Problema
Alacritty no mostraba transparencia. El valor `opacity = 0.85` se reiniciaba al abrir una nueva terminal.

### Causa raíz
1. **Picom no estaba corriendo** — sin compositor, Alacritty no puede mostrar transparencia bajo X11
2. **El módulo `05-alacritty.sh` sobreescribe la opacidad** en cada inicio de sesión de bspwm:
   - `sed -i "s|^opacity = .*|opacity = ${P_TERM_OPACITY}|" "$HOME/.config/alacritty/alacritty.toml"`
   - El valor `P_TERM_OPACITY` venía de `theme-config.bash`
3. **`P_TERM_OPACITY="0.98"`** en `rices/melissa/theme-config.bash` — casi opaco

### Solución
- **`rices/melissa/theme-config.bash`**: `P_TERM_OPACITY="0.98"` → `"0.85"`
- **`alacritty/alacritty.toml`**: `opacity = 0.98` → `0.85` (cambio directo)
- **Picom iniciado**: `picom -b` (no estaba corriendo)

### Lecciones
- Para cambios permanentes de transparencia, modificar `P_TERM_OPACITY` en `theme-config.bash`, NO directamente en `alacritty.toml`
- Siempre verificar `ps aux | grep picom` si la transparencia no se muestra
- El `05-alacritty.sh` se ejecuta vía Theme.sh → bspwmrc

---

## 🎨 Polybar — Esquema de colores completo (tema melissa)

### Cambios visuales

**Fondo de barras:**
- Antes: `#003b4252` (transparente — 00 alpha)
- Ahora: `#1e222a` (sólido oscuro, contrasta con el terminal transparente)

**Secciones coloreadas con acentos Nord:**

| Sección | Color | Hex |
|---------|-------|-----|
| CPU | Verde | `#a3be8c` |
| RAM | Cyan | `#88c0d0` |
| DISK | Amarillo | `#ebcb8b` |
| NET | Púrpura | `#b48ead` |
| KB/Teclado | Azul | `#81a1c1` |
| Workspace focused | Verde | `#a3be8c` |
| Workspace occupied | Cyan | `#88c0d0` |
| Volumen | Cyan | `#88c0d0` |
| Brillo | Ámbar | `#FBC02D` |
| Bluetooth | Azul | `#81a1c1` |
| Batería cargando | Verde | `#a3be8c` |
| Batería descargando | Amarillo | `#ebcb8b` |
| Icono música | Púrpura | `#b48ead` |
| Icono usuario | Amarillo | `#ebcb8b` |
| Icono power | Rojo | `#bf616a` |

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `rices/melissa/config.ini` | Colores globales: bg=#1e222a, bg-alt=#2e3440 |
| `rices/melissa/modules.ini` | Acentos Nord en cada módulo, iconos descomentados |
| `rices/melissa/theme-config.bash` | P_TERM_OPACITY=0.85 |
| `bspwm/eww/colors.scss` | Sincronizado con nueva paleta |

### Recarga de polybar
```bash
polybar-msg cmd quit
RICE=$(cat ~/.config/bspwm/.rice)
MONITOR=HDMI-1 polybar mel-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
MONITOR=HDMI-1 polybar mel2-bar -c ~/.config/bspwm/rices/$RICE/config.ini &
```

---

## 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/rices/melissa/theme-config.bash` | P_TERM_OPACITY: 0.98 → 0.85 |
| `~/.config/alacritty/alacritty.toml` | opacity: 0.98 → 0.85 |
| `~/.config/bspwm/rices/melissa/config.ini` | Colores globales polybar rediseñados |
| `~/.config/bspwm/rices/melissa/modules.ini` | Acentos Nord en cada módulo |
| `~/.config/bspwm/eww/colors.scss` | Sincronizado con nueva paleta |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/SESION.md` | ✅ Actualizado |
| `ai-context/AGENTS.md` | ✅ Añadidas notas técnicas (picom, polybar) |
| `ai-context/SYSTEM.md` | ✅ Actualizado (rice melissa, picom) |
| `ai-context/SYSTEM_FULL.md` | ✅ Actualizado (referencias, terminales) |
| `ai-context/INFO-core.md` | ✅ Actualizado (sistema, proyectos) |
| `ai-context/INFO-full.md` | ✅ Actualizado (terminales, changelog) |

*Fin de la sesión — Última actualización: 2026-07-26*

---

# 🧠 SESION — Buffy Freebuff (2026-07-27)

> Contexto de todo lo implementado durante esta sesión.

---

## 🖥️ Fix resolución de pantalla (1360x768)

### Problema
La pantalla estaba en **1280x720** en vez de la especificada **1360x768@60.02**.

### Causa raíz
El script `MonitorSetup` (gh0stzk rice) ejecuta su propio `xrandr` después del que estaba en `bspwmrc`. `MonitorSetup` usa `get_monitor_info()` que agarra el **primer modo listado** por xrandr (1280x720 por ser el preferido), pisando la resolución configurada.

### Solución
- **`~/.config/bspwm/bspwmrc`**: Movido `xrandr --output HDMI-1 --mode 1360x768 --rate 60.02` **DESPUÉS** de `MonitorSetup` en vez de antes.
- Verificado con `bspc wm -r`: la resolución persiste correctamente.
- **Investigación completa**: Ningún otro script del rice melissa (todos los módulos, Theme.sh, Bar.bash, SetSysVars, ScreenLocker, AnimatedWall) toca xrandr. Solo MonitorSetup y nuestro fix en bspwmrc.

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/bspwmrc` | xrandr movido DESPUÉS de MonitorSetup |

---

## 🤖 codebuff-automation — Proyecto completo de automatización web

> Proyecto portado de Termux (Xiaomi Mi 10 / HyperOS) a PC de escritorio.
> Creado desde el archivo `~/Descargas/SETUP_PC_DESKTOP.md`.

### Estructura del proyecto (`~/codebuff-automation/`)

| Archivo | Descripción | Estado |
|---------|-------------|:------:|
| `fill_form.js` v4.0 | Script principal — Llenador universal de formularios | ✅ ~43KB |
| `auto_permiso.py` v2.0 | OCR + root para permisos Android | ✅ (root en vez de rish) |
| `mis-datos.json` | Datos de ejemplo (chilenos) | ✅ |
| `test-form.html` | Formulario de prueba con 21 campos | ✅ |
| `Dockerfile` | Imagen Docker para ejecución aislada | ✅ |
| `docker-compose.yml` | Orquestación Docker | ✅ |
| `docker-entrypoint.sh` | Entrypoint Docker | ✅ |
| `SETUP_PC_DESKTOP.md` | Documentación original | ✅ |
| `codebuff-memoria.md` | Memoria del proyecto | ✅ |
| `skills/` (5 skills) | Documentación de skills | ✅ |

### Dependencias instaladas
| Paquete | Versión | Propósito |
|---------|:-------:|-----------|
| puppeteer-core | 25.4.0 | Control de Chromium |
| puppeteer | 25.4.0 | (instalado como dependencia) |
| tesseract-data-spa | - | OCR español para auto_permiso.py |
| Chromium | 150 | Navegador del sistema (`/usr/bin/chromium`) |

### Features de fill_form.js v4.0
| Feature | Estado | Flags |
|---------|:------:|-------|
| SmartMapper multi-idioma (28 categorías) | ✅ | — |
| CAPTCHA support (2captcha) | ✅ | `--captcha-api-key` |
| Proxy rotativo (3 estrategias) | ✅ | `--proxy`, `--proxy-list` |
| Modo entrenamiento | ✅ | `--train` |
| Webhook notifications (Slack/Discord) | ✅ | `--webhook-url` |
| Sesiones persistentes (cookies+storage) | ✅ | `--session` |
| iframe support vía frameMap | ✅ | — |
| Retry logic (backoff exponencial) | ✅ | — |
| Export JSON (ResultsTracker) | ✅ | `--export` |
| Slow mode human-like | ✅ | `--slow` |
| Modo interactivo | ✅ | `--interactive` |
| Screenshots automáticos | ✅ | `--screenshot` |
| Dockerización | ✅ | Dockerfile + compose |

### Bugs corregidos durante implementación
1. **`os` import antes de uso**: Movido `require('os')` al principio del archivo
2. **iframe field filling**: Creado `frameMap` con `Map<string, Frame>` para lookup confiable en vez de `frame._id` (interno de Puppeteer)
3. **Dead code removal**: Eliminadas funciones `clearAndTypeInFrame`, `selectOptionInFrame`, `setCheckboxInFrame`, `typeWithDelay` (reemplazadas por `fillFieldOnFrame` genérica)
4. **`frameCounter` global**: Cambiado a `localFrameCounter` dentro de `detectFormFieldsInFrames`
5. **`confirm_password` faltante**: Agregado a `DEFAULT_DATA` con el mismo valor que `password`

### Test results (contra test-form.html local)
```
📋 21 campo(s) detectado(s)
✅ Llenados: 17
❌ Fallidos: 0
⏭️ Omitidos: 4 (confirm_password + 3 radios)
⏱ Duración: 13s
```

### Radios del test-form.html — Fix
Se arregló la estructura HTML de los radios (sección "Tipo de perfil"):
- Agregados `id` únicos (`profile_dropshipper`, `profile_proveedor`, `profile_ambos`)
- Labels separados con `for` en vez de inputs envueltos en `<label>`
- Opciones envueltas en `<span class="radio-option">` para flex layout correcto
- `role="radiogroup"` y `aria-label="Tipo de perfil"`
- CSS: `.radio-option { display: inline-flex; }` + labels `display: inline`

### auto_permiso.py — Migración de rish a root
- Cambiado de `adb shell /data/local/tmp/rish -c "cmd"` a `adb shell su -c "cmd"`
- Eliminadas todas las referencias a `rish_cmd` y `PRIV_MODE`
- Comandos `pm grant` correctos para root
- `check_root()` sin `check=True` para evitar crash si ADB no está conectado

---

## 🦙 Ollama — Instalación y modelo cloud

### Instalación
Ollama **0.30.7** ya estaba instalado (`/usr/local/bin/ollama` + pacman `0.32.1-1`).

### Modelo descargado
- **`nemotron-3-super:cloud`** — Modelo cloud de Nvidia (120B params, MoE)
- El tag `:cloud` significa que corre en servidores de Ollama, no local
- **No ocupa RAM/CPU local** (solo ~345B de stub)
- **Requiere cuenta en Ollama** para usar: `ollama signin`
- **Tier Free disponible** con límites de uso ligero

### Pendiente
- Crear cuenta en ollama.com (el usuario decidirá más adelante)
- Integrar Ollama en fill_form.js (clasificación de campos vía IA)

---

## 📁 Archivos modificados/creados (sesión 2026-07-27)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.config/bspwm/bspwmrc` | Fix resolución: xrandr después de MonitorSetup |

### Proyecto codebuff-automation
| Archivo | Cambio |
|---------|--------|
| `~/codebuff-automation/fill_form.js` | **NUEVO**: v4.0 completo (~43KB) |
| `~/codebuff-automation/auto_permiso.py` | **NUEVO**: v2.0 con root en vez de rish |
| `~/codebuff-automation/mis-datos.json` | **NUEVO**: Datos de ejemplo |
| `~/codebuff-automation/test-form.html` | **NUEVO**: 21 campos + fix radios |
| `~/codebuff-automation/Dockerfile` | **NUEVO**: Imagen Docker |
| `~/codebuff-automation/docker-compose.yml` | **NUEVO**: Orquestación |
| `~/codebuff-automation/docker-entrypoint.sh` | **NUEVO**: Entrypoint |
| `~/codebuff-automation/SETUP_PC_DESKTOP.md` | Copiado desde Descargas |
| `~/codebuff-automation/codebuff-memoria.md` | **NUEVO**: Memoria del proyecto |
| `~/codebuff-automation/skills/form-filler.md` | **NUEVO**: Skill form filler |
| `~/codebuff-automation/skills/image-analyzer.md` | **NUEVO**: Skill OCR |
| `~/codebuff-automation/skills/hyperos-hardening.md` | **NUEVO**: Skill HyperOS |
| `~/codebuff-automation/skills/xiaomi-adb-tricks.md` | **NUEVO**: Skill ADB (root) |
| `~/codebuff-automation/skills/shizuku-rikka.md` | **NUEVO**: Skill Shizuku (legacy) |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (esta entrada) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/PROJECTS.md` | ✅ codebuff-automation agregado |
| `ai-context/SYSTEM.md` | ✅ Ollama + nuevo proyecto |
| `ai-context/SNAPSHOT.md` | ✅ Regenerado |

---

## 🦙 Qwen2.5 7B — Modelo local instalado + systemd service

### Modelo descargado
- **`qwen2.5:7b`** (4.7 GB) — Modelo local de Alibaba (7B params, Q4_K_M)
- Corre 100% en CPU (no ROCm disponible para la Vega 11 integrada)
- Velocidad: ~24s primer token (carga inicial), respuestas rápidas después
- **No requiere internet** — todo local, privado y sin límites

### Sistema de servicio (systemd --user)
- Creado `~/.config/systemd/user/ollama.service`:
  - `Type=simple`, `ExecStart=/usr/bin/ollama serve`
  - `Restart=on-failure` con `RestartSec=3`
  - Habilitado (`systemctl --user enable`) e iniciado
  - Se auto-arranca al iniciar sesión

### Estado actual
| Componente | Estado |
|-----------|--------|
| Ollama service | ✅ Activo (systemd --user) |
| qwen2.5:7b | ✅ Descargado (4.7 GB) |
| nemotron-3-super:cloud | ✅ Stub cloud (345B) |
| API local | ✅ Responde en localhost:11434 |
| CLI `ollama run` | ❌ Timeout (bug conocido, usar API) |

### Nota técnica
`ollama run` tiene un bug que causa timeout en este entorno. Usar siempre la API directa:
```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5:7b","prompt":"tu pregunta aquí","stream":false}'
```

### Pendiente
- Integrar Ollama en fill_form.js (usar qwen2.5:7b en vez de nemotron cloud)

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — segunda parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.config/systemd/user/ollama.service` | **NUEVO**: Servicio systemd para Ollama |

### Modelos Ollama
| Archivo/Modelo | Cambio |
|----------------|--------|
| `qwen2.5:7b` | **NUEVO**: Descargado (4.7 GB, CPU-only) |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (Qwen2.5 + systemd) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |
| `ai-context/SYSTEM.md` | ✅ Actualizado |

---

## 🦀 OpenClaw — Instalación y configuración

### Instalación
- **OpenClaw 2026.7.1-2** instalado globalmente via npm
- Gateway configurado en modo `local`, puerto `18789`
- Systemd user service creado: `openclaw-gateway.service` ✅ Activo

### Configuración de modelos
| Proveedor | Modelo primario | Rol |
|-----------|----------------|:---:|
| **kimchi** | `deepseek-v4-flash` | 🎯 Principal |
| **kimchi** | `nemotron-3-ultra-fp4` | 🔄 Fallback 1 |
| **ollama local** | `qwen2.5:7b` | 🔄 Fallback 2 |
| **kimchi** | `qwen2.5-coder:7b` | 🔄 Fallback 3 |

### Skills activas
- Habilidades no esenciales desactivadas (26) por `doctor --fix`
- Autocompletado zsh instalado
- Systemd lingering habilitado para el usuario

### vs Hermes
| Aspecto | OpenClaw | Hermes |
|---------|:--------:|:------:|
| Tamaño | ~12K (config) | 1.9 GB |
| Modelo default | deepseek-v4-flash ✅ | nemotron-3-super:cloud ❌ timeout |
| Provider activo | Kimchi API ✅ | nous (incierto) |
| Gateway | ✅ systemd, running | ❌ No tenía |
| Ollama local | ✅ Configurado | ❌ Solo cloud |

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — tercera parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/.openclaw/openclaw.json` | ✅ Actualizado: Ollama provider + deepseek-v4-flash como primary |
| `~/.config/systemd/user/openclaw-gateway.service` | **NUEVO**: Servicio systemd para OpenClaw |
| Paquete npm global | `openclaw@2026.7.1-2` instalado |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (OpenClaw) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |

---

## 🎮 scrcpy-freefire.sh — Script multi-dispositivo para Free Fire

### Refactor completo
- **Auto-detección**: Detecta dispositivo ADB conectado y plataforma (kona=Qualcomm, ums=Unisoc)
- **Encoder automático**: `OMX.qcom.video.encoder.avc` para Mi 10 (Snapdragon 865), `c2.unisoc.avc.encoder` para ZTE nubia Neo 2 (Unisoc T820)
- **Resolución**: Mi 10 usa nativa (sin cambios). ZTE usa 2400x600 estirada
- **DPI**: Mi 10 usa nativo (440). ZTE usa 90
- **Regla bspwm**: scrcpy se abre en escritorio 6 (games) con `bspc rule -a scrcpy desktop='^6'`

### Problemas resueltos
- **Encoder incorrecto**: Se cambió `c2.qti.avc.encoder` (inexistente) a `OMX.qcom.video.encoder.avc`
- **Ghost touches al cargar**: Se desactivó `charging_optimization = 0` vía ADB para el Mi 10
- **Ventana incorrecta**: Se agregó regla bspwm para escritorio 6
- **pkill genérico**: Ahora mata cualquier instancia de scrcpy con `--video-encoder=`

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | Refactor completo multi-dispositivo |

### Pendiente
- Calibrar ggMouse para Mi 10 (sensibilidad y botones)
- Script AutoJS para lectura de botones de Free Fire

---

## 📁 Archivos modificados/creados (sesión 2026-07-27 — cuarta parte)

### Sistema
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | ✅ Refactor multi-dispositivo (Mi 10 + ZTE) |
| ADB setting | `charging_optimization = 0` en Mi 10 |

### ai-context
| Archivo | Cambio |
|---------|--------|
| `ai-context/SESION.md` | ✅ Actualizado (scrcpy + ghost touch) |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |

---

## 🪟 Mango-KWin — KWin como WM minimalista con estética mango

### Contexto
El usuario quería instalar KDE Plasma pero **sin el shell de escritorio tradicional** (paneles, taskbar, etc.).
La idea era usar **KWin como gestor de ventanas** (Wayland) manteniendo la misma estética visual
minimalista de su setup actual (bspwm/mango): colores oscuros Catppuccin Mocha (#181825 bg, #CDD6F4 fg),
barra eww/waybar, lanzador rofi, terminal kitty/alacritty.

### Paquetes instalados
| Paquete | Versión | Tamaño | Propósito |
|---------|:-------:|:------:|-----------|
| `kwin` | 6.7.3-1 | 10.6 MB | WM/Compositor Wayland + X11 |
| `plasma-workspace` | 6.7.3-1 | 21.1 MB | Infraestructura de sesión |
| `kwin-x11` | 6.7.3-1 | — | Soporte X11 para KWin |
| `kde-cli-tools` | — | — | Herramientas CLI KDE |
| `polkit-kde-agent` | — | — | Diálogos de autenticación |
| `kglobalacceld` | — | — | Atajos globales de teclado |
| `xdg-desktop-portal-kde` | — | — | Portal Wayland (screenshare, flatpak) |
| **Total** | | **~80 MB** | |

### Archivos creados

**1. Script de sesión — `~/.local/bin/mango-kwin-session`**

Lanza KWin como compositor Wayland sin el shell de Plasma. Incluye:
- Variables de entorno: `XDG_CURRENT_DESKTOP=mango-kwin:KDE`, `XDG_SESSION_TYPE=wayland`
- Activación de `graphical-session.target` de systemd (compatibilidad Wayland)
- Arranque de servicios KDE esenciales: `kglobalacceld`, `kded6`, `polkit-kde-agent`
- Detección automática de barra: eww (prueba nombres: bar/shell/panel/main) → waybar
- Fallback X11 vía `KWIN_BACKEND=x11` (lanza `kwin_x11` en vez de `kwin_wayland`)
- Wait loop con `pidof` en vez de `sleep` para sincronizar servicios

**2. Entrada SDDM — `/usr/share/wayland-sessions/mango-kwin.desktop`**
```ini
Name=Mango-KWin
DesktopNames=mango-kwin;KDE
Comment=KWin como WM minimalista con estética mango
Exec=/home/mangonz/.local/bin/mango-kwin-session
```

**3. Configuración de KWin — `~/.config/kwinrc`**
| Sección | Valor | Efecto |
|---------|:-----:|--------|
| `[Desktops]` | `Number=6, Rows=2` | 6 workspaces en grid 3×2 |
| `[Compositing]` | `Backend=OpenGL, Enabled=true` | Composición GPU |
| `[Window-Decoration]` | `BorderlessMaximizedWindows=true` | Sin título al maximizar |
| `[Windows]` | `FocusPolicy=ClickToFocus, Placement=Centered` | Foco al click, ventanas centradas |
| `[Plugins]` | `kwin4_effect_tilingEnabled=true` | Tiling nativo de KWin activado |
| `[Plugins]` | `kwin4_effect_blurEnabled=true` | Blur en ventanas |
| `[Plugins]` | `kwin4_effect_wobblywindowsEnabled=true` | Efecto wobbly al mover |
| `[Translucency]` | `MoveResize=90` | Transparencia al mover/redimensionar |

**4. Atajos de teclado — `~/.config/kglobalshortcutsrc`**

Estilo bspwm, configurados via `kwriteconfig6`:

| Tecla | Acción |
|-------|--------|
| `Meta + Enter` | Terminal (kitty) |
| `Meta + Space` | Launcher (rofi -show drun) |
| `Meta + Q` | Cerrar ventana |
| `Meta + Shift + Q` | Matar ventana (force kill) |
| `Meta + F` | Fullscreen |
| `Meta + M` | Maximizar (monocle toggle) |
| `Meta + D` | Quitar/poner bordes |
| `Meta + H/J/K/L` | Quick tile izquierda/abajo/arriba/derecha |
| `Meta + Alt + H/J/K/L` | Navegar entre ventanas por dirección |
| `Meta + 1-6` | Cambiar a workspace 1-6 |
| `Meta + Shift + 1-6` | Mover ventana a workspace 1-6 |

### Notas técnicas
- **KWin vs bspwm**: KWin no es un tiling WM puro como bspwm, usa quick-tiling por defecto.
  Para tiling automático tipo bspwm, instalar el script "KWin Tiling" desde `systemsettings`
  o vía `kpackagetool6`.
- **`kwin_x11 --replace`**: En el fallback X11, `--replace` espera un WM existente. En sesión
  limpia (SDDM), se usa sin `--replace`.
- **Screen locker**: `--no-lockscreen` desactiva el bloqueo de pantalla. Si se necesita,
  instalar `kscreenlocker` o `physlock`.
- **Window rules**: Para apps en modo flotante (diálogos, popups), crear `~/.config/kwinrulesrc`
  o configurar desde `kwin_rules_dialog`.

### Archivos creados/modificados
| Archivo | Cambio |
|---------|--------|
| `~/.local/bin/mango-kwin-session` | **NUEVO**: Script de sesión minimalista |
| `/usr/share/wayland-sessions/mango-kwin.desktop` | **NUEVO**: Entrada SDDM |
| `~/.config/kwinrc` | **NUEVO**: KWin config (6 desktops, blur, tiling, sin bordes) |
| `~/.config/kglobalshortcutsrc` | **NUEVO**: Shortcuts estilo bspwm |

### Sesiones disponibles en SDDM ahora
- `mango` (original, Wayland)
- `mango-kwin` (KWin como WM, Wayland)
- `plasma` (KDE Plasma completo, Wayland)
- `bspwm` (X11)

---

## 🎮 scrcpy-freefire.sh — Configuración de Pantalla Alargada y ggmouse (Panda Mouse Pro)

### Resumen de la sesión (2026-07-29)

1. **Protocolo Operativo Activo**:
   - Se estableció la skill `modo-autonomo` como la principal regla operativa para el agente (diagnóstico directo por terminal, autonomía en decisiones técnicas, ejecución y verificación sin delegación innecesaria al usuario).

2. **Refactor y Ajustes en `scrcpy-freefire.sh`**:
   - **Pantalla Alargada / Estirada**: Configuración mediante ADB (`wm size 2400x600`, `wm density 280`, `user_rotation 1`) para vista ultra-wide estirada.
   - **Integración ggmouse (Panda Mouse Pro - `com.panda.widgetcove`)**:
     - Otorgados permisos `SYSTEM_ALERT_WINDOW`, `GET_USAGE_STATS` y `PROJECT_MEDIA` vía `appops`.
     - Inicio automático del servicio/pantalla de ggmouse previo a Free Fire.
   - **Juego Directo en Teléfono**:
     - Removido `--turn-screen-off` y configurado `--stay-awake` en `scrcpy` para permitir jugar usando la pantalla del celular mientras se espeja en la PC.
     - Lanzamiento directo de Free Fire (`com.dts.freefireth`).

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | ✅ Soporte pantalla alargada, ggmouse (Panda Mouse Pro), prevención de doze y modo UHID con `--mouse-bind=++++:++++` para control total desde PC |

| `~/.openclaw/workspace/scripts/scrcpy-freefire.sh` | ✅ Sincronizado |
| `ai-context/SESION.md` | ✅ Actualizado |
| `ai-context/CHANGELOG.md` | ✅ Actualizado |


---

# 🧠 SESION — Buffy Freebuff (2026-07-29 — segunda parte: memoria persistente + skill expandida)

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

---

# 🧠 SESION — Buffy Freebuff (2026-07-31)

> Contexto de todo lo implementado durante esta sesión.

---

## 🤖 Command Code instalado + Hermes eliminado + OpenClaw migrado a blockrun

### Pedido del usuario
1. Probar el nuevo agente de IA **Command Code** (`https://commandcode.ai/`)
2. **Eliminar Hermes** (agente de Nous Research) — su plan gratuito duró solo 2 semanas

### Command Code (v1.6.1) — instalado
- `npm i -g command-code@latest` → `~/.npm-global/bin/command-code` (+ alias `cmd`)
- Postinstall de `protobufjs` estaba bloqueado por npm; habilitado con `--allow-scripts=protobufjs` y persistido en config (`npm config set allow-scripts=protobufjs --location=user`)
- Verificado: `command-code --version` → 1.6.1 · `--list-models` → 50 modelos (deepseek, kimi, glm, claude, gpt, gemini, grok, etc.)
- **Pendiente del usuario**: `cmd login` (OAuth por navegador) y primer uso en un proyecto

### Hermes — eliminado por completo (~1.9 GB liberados)
| Componente | Acción |
|---|---|
| `~/.hermes/` | `rm -rf` (agent, venv, state.db, skills, kanban, sessions) |
| `~/.buffy-hermes/` | `rm -rf` (workspace inbox/outbox/context) |
| `~/.local/state/hermes/` | `rm -rf` |
| `~/.ollama/backup/hermes/` | `rm -rf` |
| `~/.local/bin/{hermes,buffy-hermes,nous-refresh}` | eliminados |
| `nous-refresh.{service,timer}` (systemd user) | stop + disable + rm + daemon-reload |
| `~/.zshrc` (bloque "Nous Portal API key" + `eval nous-refresh`) | líneas 571-574 eliminadas |
| `NOUS_API_KEY` en systemd user env | `systemctl --user unset-environment` |
| `memoria.md`, `ai-context/SNAPSHOT.md` | referencias hermes removidas |

### OpenClaw — migrado de provider `nous` → `blockrun`
- El provider `nous` (plan gratuito expirado) dejó el gateway en `failed` por `NOUS_API_KEY` inexistente
- `~/.openclaw/openclaw.json`: eliminado provider `nous`; `primary=blockrun/auto`, fallbacks `['ollama/qwen2.5:7b','blockrun/free']`; aliases `nous/*` removidos
- `openclaw-gateway.service`: `OPENCLAW_SERVICE_MANAGED_ENV_KEYS` → solo `KIMCHI_API_KEY`
- Gateway ✅ **active** · `.last-good` regenerado sin refs a nous
- Backup del config en `openclaw.json.bak-hermes-removal`
- **Pendiente del usuario**: el proxy blockrun (127.0.0.1:8402) no está corriendo — sin binario ni servicio systemd; hasta levantarlo, OpenClaw usará fallback ollama local

---

*Fin de la sesión — Última actualización: 2026-07-31*

---

# 🧠 SESION — Buffy Freebuff (2026-07-31 — limpieza de agentes IA)

> Contexto de la limpieza de agentes IA en desuso.

---

## 🧹 Limpieza de agentes IA en desuso

### Pedido del usuario
"Tengo bastante basura de IAs que ya no uso" — limpiar agentes IA obsoletos.

### Seleccionado por el usuario (eliminado)
| Item | Detalle | Espacio |
|---|---|---|
| **Claude Code** | `npm uninstall -g @anthropic-ai/claude-code` + `rm ~/.claude.json` | ~223 MB |
| **Kilo** | `rm -rf ~/.kilo` + línea PATH removida de `.zshrc` | ~250 MB |
| **Mimo** | `npm uninstall -g @mimo-ai/cli` + `rm -rf ~/.mimocode` | ~480 MB |
| **aichat** | `cargo uninstall aichat` (metadata corrupta corregida en `.crates.toml`/`.crates2.json`) | pequeño |
| **Cache Playwright** | `rm -rf ~/.cache/ms-playwright` (redescargable) | ~943 MB |
| **Cache Kimchi** | `rm -rf ~/.cache/kimchi` (binario kimchi ya no existía) | ~121 MB |
| **Odysseus** | `rm -rf ~/odysseus` (confirmado por usuario; requirió sudo por permisos root) | ~772 KB |
| **Symlink `rtk`** | `rm -f ~/.local/bin/rtk` (apuntaba a kimchi, inexistente) | — |

### No eliminados (activos o recientes)
- **freebuff** (este agente), **OmniRoute** (gateway activo), **OpenClaw** (gateway activo)
- **command-code** (recién instalado para probar), **vercel**, **clasp**, **ctx7**, **playwright-cli**
- **Gemini CLI** (el usuario no lo seleccionó), **Ollama** (conservado; modelos moondream/minicpm-v/qwen permanecen, solo qwen2.5:7b se usa como fallback de OpenClaw)

### Archivos modificados
| Archivo | Cambio |
|---|---|
| `~/.zshrc` | Removida línea `export PATH=.../.kilo/bin` |
| `memoria.md` | Removidas filas Claude Code, kimchi, Odysseus, kilo/mimocode del PATH, filas kimchi/claude/rtk de ~/.local/bin |
| `ai-context/SNAPSHOT.md` | Regenerado |
| `ai-context/CHANGELOG.md` | Entrada 2026-07-31 agregada |

---

*Fin de la sesión — Última actualización: 2026-07-31*

---

## 🎮 scrcpy-freefire.sh — Cleanup real al salir (cierra apps + apaga pantalla) — 2026-08-01

### Problema
Al cerrar el script quedaban apps corriendo en el teléfono (gastaban batería). El cleanup viejo solo hacía `am force-stop` a 2 apps (Free Fire + screenshot), y **8 apps se reiniciaban solas** porque son Device Admins activos / auto-reinicio: Android prohíbe su force-stop (anti-malware).

**Misterio resuelto:** la sesión que parecía "no funcionar" corría el código viejo — su log decía `com.dts.freefireth / com.zjx.ztezscreenshot detenidas` (solo 2 apps). Al reabrir (launcher), el juego volvía a arrancar y todo parecía igual.

### Solución
| Pieza | Qué hace |
|---|---|
| `KILL_PERSISTENT="0"` | **Default seguro (OFF)**: el force-stop normal ya cierra el juego y apps normales. En `1` hace barrido agresivo con `pm disable-user` |
| `pm disable-user` al cerrar | Mata de verdad a los Device Admins (verificado: mueren y quedan muertos) |
| `pm enable` + `dpm set-active-admin` al iniciar | Restaura las apps completas, **incluido su estado de Device Admin** |
| `SESSION_STARTED` gate | Solo limpia si el juego realmente arrancó (si scrcpy falla 3 veces, no toca nada) |
| `PERSISTENT_ADMIN_RECEIVERS` | Receivers de admin a re-grantear con `dpm` (descubrimiento: `pm enable` NO restaura el estado de admin — probado en vivo) |
| **`scrcpy-freefire-restore.sh`** (nuevo) | Restauración manual independiente si saliste y no volvés a abrir el script. Lee las listas del main vía `sed` (una sola fuente de verdad) |

### Cierre con Alt+Q
- El usuario cierra con **Alt+Q** (binding `sxhkdrc:162` — bspwm cierra la ventana de scrcpy → el script detecta el cierre y corre el cleanup)
- Hint del notify actualizado: `scrcpy corriendo — Alt+Q para salir (limpia y apaga pantalla)`
- Flujo verificado en vivo: `Restaurando... → Cerrando apps → Apagando pantalla en 5s → Pantalla apagada`

### Incidente transparencia
Los ciclos disable→enable de prueba desactivaron el Device Admin de MacroDroid/Tasker/Automate. **Restaurados** con `dpm set-active-admin` (los 3 con Success + policies visibles).

### Archivos
| Archivo | Cambio |
|---|---|
| `~/scripts/scrcpy-freefire.sh` | Cleanup real: close_game_apps + screen off 5s + KILL_PERSISTENT + gates + re-enable con dpm + hint Alt+Q |
| `~/scripts/scrcpy-freefire-restore.sh` | Nuevo: restaura apps + admins leyendo listas del main |
| `.openclaw/workspace/scripts/scrcpy-freefire.sh` | Sincronizado |

---

## 🗑️ Limpieza del teléfono — laboratorio de pruebas — 2026-08-01

### Desinstaladas (verificado: `pm path` vacío)
| App | Paquete | Resultado |
|---|---|---|
| **Tasker** | `net.dinglisch.android.taskerm` | ✅ `Success` |
| **Automate** | `com.llamalab.automate` | ✅ `Success` |
| **Facebook** | `com.facebook.katana` | ✅ `Success` |

### El detalle técnico
Tasker y Automate eran **Device Admins activos** → Android bloquea su desinstalación (`DELETE_FAILED_DEVICE_POLICY_MANAGER`), y `dpm remove-active-admin` solo funciona para test-only admins (estos eran `testOnlyAdmin=false`). **Solución:** `pm disable-user` primero (desactiva el admin al deshabilitar el paquete) → `pm uninstall` después. Funcionó perfecto. Quedó demostrado que el único admin activo restante es **MacroDroid**.

### Scripts actualizados
- `PERSISTENT_APPS`: removidos `taskerm` y `llamalab.automate` (quedan macrodroid, autojs6, kustom.widget, steps, launcher.hype)
- `PERSISTENT_ADMIN_RECEIVERS`: quedó solo el receiver de MacroDroid
- El restore script se actualiza solo (lee listas del main vía `sed`)

### Pendiente para mañana (laboratorio)
- Quedan candidatos a borrar: MacroDroid, AutoJS, Kustom Widget, Steps, `com.launcher.hype`
- Considerar `KILL_PERSISTENT=1` si se quiere el lab sin nada corriendo al salir

---

*Fin de la sesión — Última actualización: 2026-08-01*

# 🧠 SESION — Buffy Freebuff (2026-08-01 — systemd-boot fix + ask-model.js "segundo cerebro" + kimi_vision.js adoptado)

> Tema: arreglar el menú de arranque que esperaba Enter (no era GRUB), montar un complemento para consultar otros modelos (local/nube), adoptar la mejora kimi_vision.js del repo, y aclarar el mito de MCP.

---

## 🔧 systemd-boot — fix del "menú que espera Enter" (no era GRUB)

- **Diagnóstico**: el sistema usa **systemd-boot** (NO GRUB) — `efibootmgr` apunta a `\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI`, ESP montado en `/efi`.
- **Causa raíz**: variable EFI `LoaderConfigTimeout` (GUID 4a67b082-...) con el valor especial **`menu-force`** (UTF-16, verificado con xxd) → pisa el `timeout 3` de `/efi/loader/loader.conf` y obliga a esperar Enter indefinidamente.
- **Fix**: `sudo bootctl set-timeout 3` → luego el usuario pidió arranque instantáneo: `sudo bootctl set-timeout 0` + `sed -i 's/^timeout .*/timeout 0/' /efi/loader/loader.conf`. Verificado: var EFI = `0` y `loader.conf` = `timeout 0` (ambos consistentes).
- **Escape hatches con timeout 0**: boot counting + fallback automático si el kernel default falla (independiente del menú, confirmado en `man systemd-boot`); menú puntual con `systemctl reboot --boot-loader-menu=force`.

## 🧪 ask-model.js — "segundo cerebro" de terminal (local + nube)

- **Nuevo**: `codebuff-automation/ask-model.js` — consulta cualquier modelo vía API OpenAI-compatible: **Ollama local** (qwen2.5:7b, moondream, minicpm-v) o **HF Router nube** (DeepSeek V4 Flash/Pro/R1, Kimi K3). Sin MCP, sin deps nuevas (usa `lib/logger.js` + `lib/utils.js` vendored).
- Modos: one-shot, `--chat` (memoria, últimos 4 turnos), `--list`, `--json`, separador `--` para prompts con guiones.
- **Token**: `~/.huggingface/token` (chmod 600). `resolveHfToken()` extraída a `lib/utils.js` (compartida con kimi_vision.js: env HF_TOKEN > archivo > vacío, fallback Termux-aware).
- **Pruebas reales**: qwen2.5:7b local (~2.8–17s), DeepSeek V4 Flash (~0.7–3.5s), Kimi K3 (~3.5s). Todo ✅.
- **Flujo de segunda opinión demostrado**: consulté a DeepSeek sobre la decisión `timeout 0`; DeepSeek se equivocó en 1 punto (dijo que el boot counting no se activa con timeout 0 — la doc oficial confirma que SÍ es independiente del menú). Contraverificación contra `man systemd-boot`.

## 📥 kimi_vision.js adoptado (desde repo buffy-context remoto)

- Descargados `scripts/kimi_vision.js` + `scripts/lib/{logger,utils}.js` + `Knowledge/AI/Kimi-K3.md` de `maneskinleon-del/buffy-context` → `codebuff-automation/` (diff 0 con el repo).
- Skills actualizadas: `codebuff-automation/skills/image-analyzer.md` y `.agents/skills/image-analyzer/SKILL.md` (kimi_vision.js recomendado, auto_permiso.py como fallback OCR).
- Provenance documentada en `codebuff-automation/codebuff-memoria.md`.

## 🧠 MCP aclarado (dos respuestas de otro modelo evaluadas)

- El texto propuesto decía "el modelo local es el servidor MCP" — **incorrecto**: el LLM/host es el CLIENTE MCP; los servidores exponen herramientas (filesystem, DB, APIs). Confirmado con la doc oficial del SDK (`FastMCP`, stdio/SSE, handshake `initialize`).
- Conclusión: para "consultar otro modelo" no hace falta MCP — es una llamada HTTP OpenAI-compatible (como ask-model.js).

## 🔜 Pendientes

- [ ] Sincronizar clon local `~/buffy-context` con `origin/main` (25 commits atrás; 3 archivos sin commitear: INFO-core.md, INFO-full.md, PROJECTS.md)
- [ ] Decidir si rotar el HF_TOKEN (quedó expuesto en el chat)
- [ ] Alias `ask`/`askc`/`askl` en el shell

---

# 🧠 SESION — Buffy Freebuff (2026-08-01 — Kimi K3 vía Hugging Face + MCP)

> Tema: investigación de cómo usar Kimi K3 (Moonshot AI) desde Hugging Face, aclaración de MCP vs modelo, y documentación en Knowledge/.

---

## 🤖 Kimi K3 — hallazgo documentado

- **Qué es:** modelo multimodal 2.8T (MoE) de Moonshot AI, 1M tokens de contexto, tool calling ✅
- **Acceso:** HuggingChat web (gratis) | API OpenAI-compatible `https://router.huggingface.co/v1` + token HF (pago por uso) | API Moonshot `platform.kimi.ai`
- **Model ID:** `moonshotai/Kimi-K3`

## ⚠️ Aclaración clave: MCP vs modelo

- **MCP conecta herramientas**, no es la forma de "usar el modelo"
- HuggingChat es **cliente** MCP; el servidor MCP oficial de HF (`@huggingface/mcp-server`) expone el Hub, no chat con modelos
- Para usar Kimi K3 como cerebro: API OpenAI-compatible o HuggingChat web

## 📂 Acciones

- ✅ Creado `Knowledge/AI/Kimi-K3.md` — referencia completa (acceso, ejemplos curl, casos de uso)
- ✅ Actualizado `Knowledge/README.md` — nueva categoría AI + fecha
- ✅ Sesión registrada en `SESION.md`

## 💻 kimi_vision.js creado + repo clonado vía SSH

- **`kimi_vision.js`** (raíz, Node 26, CommonJS): visión IA con Kimi K3 (`moonshotai/Kimi-K3`) vía API HF OpenAI-compatible (`router.huggingface.co/v1`). Envía el screenshot en base64; el modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish (ruta resuelta automáticamente: env RISH > ~/bin/rish > PATH). Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + aceptar licencia gated del modelo. Probado con API simulada ✅, con HF_TOKEN real ✅ y con diálogo real + `--grant` ✅ (notificaciones VInstall, 98%).
- **Repo `buffy-context` clonado en este dispositivo**: `~/buffy-context` (44 archivos, working tree limpio). Remote `origin` en **SSH** (`git@github.com:maneskinleon-del/buffy-context.git`). Clave ed25519 registrada en GitHub ✅ y push exitoso (`7bcb639`).
- **`kimi_vision.js` integrado al repo** (scripts/): copiado a `scripts/kimi_vision.js` (diff 0, `node --check` ✅), documentado en `Knowledge/AI/Kimi-K3.md` (sección "Script implementado") y en el árbol de `README.md`.

## 🔜 Pendientes

- [x] `kimi_vision.js` creado — script de visión IA (upgrade de `auto_permiso.py`) ✅
- [x] Clave SSH registrada en github.com/settings/keys y push por SSH funcionando ✅
- [x] `kimi_vision.js` agregado al repo en `scripts/` y documentado ✅
- [ ] Token HF con scope de inferencia + método de pago configurado (el scope de inferencia ya se validó con la prueba real ✅; falta método de pago)
- [x] Probar `kimi_vision.js` con HF_TOKEN real ✅ (Kimi K3 respondió en 10.2s; identificó correctamente que el screenshot NO era un diálogo de permiso)
- [x] Probar `kimi_vision.js` contra un screenshot de un diálogo de permiso real (con `--grant`) ✅ — diálogo de notificaciones de VInstall (`com.vinstall.alwiz`) detectado al 98% y concedido: `pm grant POST_NOTIFICATIONS` + `appops POST_NOTIFICATION=allow`, verificado `granted=true`
- [ ] Decidir si revocar el token GitHub expuesto en el chat

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

---

# 🧠 SESION — Buffy Freebuff (2026-08-02 — organización del home + Ollama al HDD + unificación ai-context)

> Contexto de todo lo implementado durante esta sesión.

---

## 🎮 Free Fire — verificación de cleanup con Alt+Q

- Confirmado que el cleanup real ya existía en `scripts/scrcpy-freefire.sh` (implementado el 2026-08-01): `alt+q` (sxhkdrc:162 → `bspc node -{c,k}`) cierra la ventana de scrcpy → el trap EXIT corre `close_game_apps()` (force-stop de apps + apagado de pantalla con 5s de gracia).
- Config: `CLOSE_APPS_ON_EXIT=1`, `SCREEN_OFF_DELAY=5`, `KILL_PERSISTENT=0`.
- Se verificó en vivo que la sesión corría estable (53-60 fps) y que el log no mostraba cleanup porque la sesión seguía activa en ese momento.

## 🔍 Repo ComposioHQ/awesome-claude-skills — análisis

- Catálogo de 1000+ Claude Skills; 864 instalables en el repo (rama master, Apache 2.0).
- El skill "WhatsApp Automation" del README **NO existe como carpeta** en el repo (2048 paths, 0 con whatsapp) — es un wrapper del SaaS de Composio (sección `composio-skills/` = embudo de marketing, lock-in + API key de su nube).
- Instalada **file-organizer** (`npx skills add`) en `~/.agents/skills/file-organizer`.
- Veredicto: pocas joyas reales para el stack (file-organizer, skill-creator, changelog-generator); el resto es específico de Claude Code o vendor-locked.

## 🗂️ Organización del home (disco del sistema: 67% → 39%)

| Acción | Detalle |
|---|---|
| `~/Backups` (28G) | → `/media/datos/Backups` con symlink (verificado byte a byte: 29.897.717.636 bytes / 166 archivos; los videos eran de root, copia vieja borrada con sudo) |
| Proyectos sueltos | `data_car`, `codebuff-automation`, `odysseus` → `~/proyectos/` con symlinks (odysseus era root, sudo) |
| Notas | `memoria.md`, `widgetos_contexto.md`, `polybar_melissa_fix_prompt.md`, `missing_apps.txt`, `pwa_securguard_review_deepseek.txt` → `~/notas/` |
| Logs | `cf_tunnel.log`, `server.log` → `~/logs/` |
| Basura | Eliminados `ervice --no-pager -n 50`, `udo systemctl start bluetooth.service`, `.zcompdump` viejos |
| Caches | npm (-4G), gradle caches (-4G), `~/.cache` 8.5G→360M (yay, Google, mozilla, uv, go-build) |
| Resultado | 69G → 126G libres en el disco del sistema |

## 🦙 Ollama al HDD (14G liberados)

- `~/.ollama` (14G) → `/media/datos/ollama` con symlink, verificado byte a byte (14.225.477.048 bytes / 32 archivos).
- **Descubrimiento**: había DOS servicios ollama — el de **sistema** (`/usr/local/bin/ollama`, el que sirve de verdad en el puerto 11434) y uno de **usuario** (`/usr/bin/ollama`) en crash-loop por conflicto de puerto. Se detuvo y **deshabilitó el de usuario**; queda solo el de sistema.
- Verificado: `ollama list` y `ollama show qwen2.5:7b` leen desde el HDD; escritura OK para pulls futuros.
- Nota: `id_ed25519` quedó con permisos 644 en NTFS (el mount `fmask=133` no respeta chmod) — aceptable en máquina de un solo usuario; alternativa documentada: `OLLAMA_MODELS` apuntando solo a `models/`.

## 🔗 Unificación ai-context (esta tarea)

- `buffy-context/` (repo git, fuente de verdad, pusheado a GitHub) y `~/ai-context/` (copia de trabajo de los agentes) habían **divergido en ambas direcciones**: el repo tenía las sesiones 07-30 (RAM+watchdog, push GitHub) y 08-01 (systemd-boot); la raíz tenía 07-31 (Hermes/Command Code, limpieza de agentes) y 08-01 (cleanup real + limpieza del teléfono).
- **Fusión bidireccional en el repo**: `SESION.md` (1109 líneas, contenido de ambas copias) + `CHANGELOG.md` (495 líneas, + entrada systemd-boot).
- `~/ai-context` ahora es **symlink → `~/buffy-context/ai-context`** (una sola fuente de verdad; `SNAPSHOT.md` sigue gitignored por regenerarse cada sesión).
- `AGENTS-root.md` actualizado: apunta a `INFO-core.md` en vez de `SYSTEM.md` (deprecado).
- Commit en buffy-context con la unificación.

*Fin de la sesión — Última actualización: 2026-08-02*

---

# 🧠 SESION — Buffy Freebuff (2026-08-02 — segunda parte: skills propias + triaje de repos + fixes)

> Tema: instalar skills de ComposioHQ (skill-creator, changelog-generator), crear la skill propia `android-project-setup`, auditar los 6 repos públicos de maneskinleon-del y arreglar los que tenían bugs (porteria_pwa, pwa_securguard, data_car).

---

## 🧩 Skills de ComposioHQ instaladas

- **`skill-creator`** y **`changelog-generator`** instaladas desde `ComposioHQ/awesome-claude-skills` con `npx skills add` (quedan en `~/.agents/skills/`, ya son 41 skills).
- **`changelog-generator` probada**: generó `buffy-context/CHANGELOG.md` a partir de los 43 commits del repo (29-jul → 2-ago), categorizado ✨/🔧/🐛 y en lenguaje user-friendly (filtra el ruido de commits docs).

## 🛠️ Skill propia `android-project-setup` (creada con skill-creator)

- **Estructura**: `~/.agents/skills/android-project-setup/` = SKILL.md + `scripts/{check_device,build_install,grant_permissions}.sh` + `references/{devices,permissions}.md`.
- **Workflow**: build gradle → install APK → permisos Shizuku/overlay/batería → launch, contra el ZTE Nubia (serial `320344802623`).
- **Probada en vivo**: `check_device.sh` detectó la plataforma real **`ums9620`** (corregida en references — decía ums9230); `grant_permissions.sh` concedió los 6 permisos (incluye POST_NOTIFICATION) con verificación solo-lectura.
- **Code review aplicado**: fix al build que instalaba APK viejo si fallaba (ahora aborta sin `BUILD SUCCESSFUL`), parseo de applicationId robusto (comillas simples/dobles), simplificación de multi-dispositivo.
- **Versionada en el repo** (commit `7df99bd`): `.agents/skills/android-project-setup/` + entrada en CHANGELOG.md + árbol del README. **Registrada en el stack** (commit `14dcf56`): sección Skills en `INFO-core.md` + carga condicional Android en `LOAD_CONTEXT.md`.

## 🔍 Triaje de repos `maneskinleon-del` (6 repos)

Typecheck real (`tsc --noEmit`) + build + escaneo de secrets/TODOs en los 6 repos (4 clonados frescos en /tmp + data_car/pwa_securguard locales):

| Repo | Estado | Hallazgo |
|---|---|---|
| `porteria_pwa` | ❌ 5 errores TS | Tabs con ids MAYÚSCULAS (`'INGRESO'`) vs store en minúsculas (`'registro'`) → contenido de tabs nunca renderizaba al cargar; Toast leía `toast.message` (no existe, el store tiene `toastMessage`) → nunca se mostraba |
| `pwa_securguard` | ⚠️ 1 bug funcional | Reporte CSV de incidencias se veía roto en Excel es-CL (ver sección abajo) |
| `data_car` | ⚠️ código muerto | `server.ts` (Express+Gemini, deps NO en package.json, `app` antes de declarar) y `Tachometer.tsx` (import `TelemetryStats` inexistente, sin uso) |
| `timemark` | ✅ sano | 3 console.log |
| `lista_supermercado` | ✅ sano | 10 console.log |
| `enerador-de-boletas` | ✅ sano | **typo en el nombre del repo** (→ `generador-de-boletas`), package.json ya dice el nombre correcto |

- Sin secrets filtrados: todos los `.env` son `.env.example` correctamente gitignored.
- `core-termux-brain` está vacío (0 KB) — candidato a borrar en GitHub.

## 🐛 Fix `porteria_pwa` (bugs de UI)

- `src/App.tsx`: ids de tabs unificados a los del store (`registro`/`frecuentes`/`exportar`/`importar`) + `as const` + eliminado el `as any`; Toast ahora lee `toastMessage`.
- Verificado: `tsc --noEmit` EXIT 0 (antes 5 errores) + `vite build` OK.
- Commit `d97ed4c` en `~/proyectos/porteria_pwa` — **pendiente de push** (remote HTTPS sin credenciales; falta `gh auth` o cambiar a SSH).

## 🐛 Fix `pwa_securguard` — reporte CSV de incidencias

El CSV exportado se veía "todo en una columna" / "incidencia hacia abajo en una sola celda" al abrirlo en **Excel móvil con configuración regional es-CL** (usa `;` como separador). Fix en `src/utils/report.ts`:

1. **`sep=,`** como primera línea — fuerza el delimitador coma en Excel sin importar la regional.
2. **`flatText()`** — normaliza saltos de línea de la descripción (textarea) a un espacio: cada incidente queda en UNA fila.
3. **`csvRow()` en metadatos** — la coma de `Fecha de Exportación: 02-08-2026, 5:22 p. m.` estaba sin escapar (3 columnas).
4. **Línea en blanco** antes de `--- INFORME DE INCIDENCIAS ---` (las otras secciones sí la tenían).

### Campo `date` en IncidentReport (fecha real, no de exportación)

- `types.ts`: `date: string` (fecha REAL del incidente). `useAppState.handleSaveIncident` la setea con `getLocalDateISO()`.
- **`sanitizeIncidents`** nuevo (sigue el patrón `sanitizeLogs`/`sanitizePersonas`): al rehidratar backfillea `date` a hoy para incidencias viejas y valida categoría → el tipo queda honesto y sin fallbacks duplicados.
- `SettingsTab` muestra `FECHA: {inc.date}` en la tarjeta.
- Verificado: typecheck EXIT 0, build OK, test funcional muestra `2026-07-25` (fecha real) en vez de la de exportación.
- **Commit `a375c88` pusheado** — el remote estaba en HTTPS sin credenciales, se cambió a **SSH** (`git@github.com:`) con la clave ed25519 existente.

## 🐛 Fix `data_car` — código muerto eliminado

- `git rm server.ts` (-194 líneas) y `src/components/Tachometer.tsx` (-209 líneas). Verificado antes con grep que nadie los referencia (ni .ts/.tsx/.json/.sh/.md; el `server:` de vite.config.ts es el dev server de Vite).
- Typecheck pasó de 5 errores a **EXIT 0**; build OK. Commit `642f72a` pusheado.

## 📝 Revisión del script git del usuario (descartado)

- Script de configuración git (identidad + HTTPS/PAT o SSH) con 2 bugs críticos **confirmados por ejecución**: el `sed` de limpieza de URL devuelve `https://` a secas con URLs normales (come el path), y `ssh-keygen -t ed25519 -c` (minúscula) da "Too many arguments" — debe ser `-C`. Además inyecta el token en el remote (mala práctica).
- **Decisión**: no arreglarlo — el setup real ya usa SSH y funciona.

## 🔜 Pendientes

- [ ] `gh auth login` (lo iba a correr el usuario) → luego renombrar `enerador-de-boletas` → `generador-de-boletas` por API y **pushear `porteria_pwa`** (cambiar remote a SSH).
- [ ] Aplicar `sep=,` a los exports CSV simples de pwa_securguard (`csvDownload` en LogsTab/PersonasTab).
- [ ] Limpiar `/tmp/repo_triage/` (clones temporales del triaje).

---

*Fin de la sesión — Última actualización: 2026-08-02*

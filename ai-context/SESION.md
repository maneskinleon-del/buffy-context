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


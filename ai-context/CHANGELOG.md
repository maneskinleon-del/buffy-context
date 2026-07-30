> ⚠️ **Poda automática**: Cuando este archivo supere ~30KB o ~5 entradas
> recientes (sin contar archive), las entradas más viejas se mueven a
> `CHANGELOG-archive.md`. Actualmente ~424 líneas — pendiente de archivar.

---

version: 1.4
updated: 2026-07-29
schema: system-profile
system-id: mangonz-desktop
---

# CHANGELOG.md — Historial de cambios del sistema

### 2026-07-29 — Integración modo-autónomo y optimización Free Fire (pantalla alargada + ggmouse)

**Pedido del usuario:**
1. Revisar las skills y fijar `modo-autonomo` como principal.
2. Hacer que la pantalla de Free Fire se vea alargada/estirada, usar el teléfono para jugar y mapear ggmouse (Panda Mouse Pro).

**Cambios aplicados:**
- **`~/scripts/scrcpy-freefire.sh`**:
  - Ajustada resolución estirada a `2400x600 @ 280dpi` con rotación horizontal.
  - Otorgados permisos `appops` (`SYSTEM_ALERT_WINDOW`, `GET_USAGE_STATS`, `PROJECT_MEDIA`) a `com.panda.widgetcove`.
  - Agregada exención de batería (`deviceidle whitelist` y `RUN_IN_BACKGROUND`) para evitar que el sistema suspenda/desconecte ggmouse en segundo plano.
  - Añadido selector dinámico de modo de entrada (`sdk`, `otg`, `uhid`) evitando que scrcpy suelte la captura del mouse al presionar teclas o cambiar de ventana.
  - Removido `--turn-screen-off` de `scrcpy` para permitir el uso directo de la pantalla táctil del celular.
- **Sincronización**: Copia actualizada en `~/.openclaw/workspace/scripts/scrcpy-freefire.sh`.


### 2026-07-27 — Sesión Buffy: codebuff-automation + fix resolución + Ollama

**Fix resolución de pantalla (1360x768):**
- **Causa**: `MonitorSetup` (gh0stzk rice) ejecuta `get_monitor_info()` que agarra el primer modo listado por xrandr (1280x720) y sobreescribe la config manual en bspwmrc.
- **Fix**: Movido `xrandr --output HDMI-1 --mode 1360x768 --rate 60.02` **DESPUÉS** de `MonitorSetup` en `~/.config/bspwm/bspwmrc`.
- **Investigación**: Verificados todos los scripts del rice melissa — ninguno toca xrandr excepto MonitorSetup.
- **Verificado**: `bspc wm -r` mantiene 1360x768.

**Proyecto codebuff-automation (~/codebuff-automation/):**
- Creado desde `SETUP_PC_DESKTOP.md` (portado de Termux/Android a PC).
- `fill_form.js` v4.0: SmartMapper multi-idioma (28 categorías), CAPTCHA, proxy rotativo, entrenamiento, webhooks, sesiones, iframes, retry, export, slow mode, interactive, Docker.
- `auto_permiso.py` v2.0: OCR + root (`su -c`) en vez de rish/Shizuku.
- `test-form.html`: 21 campos de prueba con radios fix (ids, for, radiogroup).
- **Test exitoso**: 21 campos detectados, 17 llenados, 0 fallidos en 13s.
- Dependencias: puppeteer-core 25.4.0, tesseract-data-spa, Chromium 150.

**Ollama:**
- Ollama 0.30.7 ya instalado.
- Modelo `nemotron-3-super:cloud` descargado (stub cloud ~345B).
- Pendiente: crear cuenta en ollama.com para usar el modelo.
- Pendiente: integrar Ollama en fill_form.js (clasificación por IA).

**Archivos modificados/creados:**
- `~/.config/bspwm/bspwmrc` — fix resolución
- `~/codebuff-automation/` — 15 archivos nuevos
- `ai-context/` — SESION.md, CHANGELOG.md, PROJECTS.md, SYSTEM.md actualizados

---

### 2026-07-27 — Sesión Buffy (segunda parte): Qwen2.5 7B local + systemd service

**Qwen2.5 7B instalado localmente:**
- Modelo `qwen2.5:7b` (4.7 GB, Q4_K_M) descargado via `ollama pull`
- Corre 100% en CPU (AMD Vega 11 integrada sin ROCm)
- Velocidad: ~24s primer token en frío, respuestas rápidas después
- API funciona perfecto (`localhost:11434/api/generate`)
- CLI `ollama run` tiene bug de timeout (usar API directa)

**Systemd service para Ollama:**
- Creado `~/.config/systemd/user/ollama.service`
- `Type=simple`, `Restart=on-failure`
- Habilitado e iniciado — auto-arranque al iniciar sesión
- Verificado: `Active: active (running)`

**Estado Ollama ahora:**
- 2 modelos: `qwen2.5:7b` (local, 4.7GB) + `nemotron-3-super:cloud` (stub, 345B)
- Servicio systemd-user auto-inicio
- Pendiente: integrar en fill_form.js

---

### 2026-07-27 — Sesión Buffy (tercera parte): OpenClaw instalado

**OpenClaw 2026.7.1-2 instalado globalmente via npm:**
- Configuración: gateway local + puerto 18789
- Modelo default: `kimchi/deepseek-v4-flash` (mismo que Buffy)
- Fallbacks: `nemotron-3-ultra-fp4` → `ollama/qwen2.5:7b` → `qwen2.5-coder:7b`
- Systemd service creado: `openclaw-gateway.service` ✅ Activo
- `doctor --fix` aplicado: skills rotas desactivadas, autocompletado zsh, lingering
- Diferencias con Hermes: ~12K vs 1.9 GB, modelos funcionales vs cloud timeout

---

### 2026-07-27 — Sesión Buffy (cuarta parte): scrcpy-freefire.sh refactor + Mi 10

**scrcpy-freefire.sh — Refactor completo multi-dispositivo:**
- Auto-detección: detecta dispositivo ADB y plataforma (kona=Qualcomm, ums=Unisoc)
- Encoder automático: `OMX.qcom.video.encoder.avc` para Mi 10, `c2.unisoc.avc.encoder` para ZTE
- Resolución/DPI: Mi 10 usa nativo, ZTE usa 2400x600 @ 90dpi
- Regla bspwm: scrcpy se abre en escritorio 6 (games)
- pkill genérico para cualquier encoder

**Ghost touch fix:**
- Se desactivó `charging_optimization = 0` en Mi 10 para evitar toques fantasma al cargar

**Archivos modificados:**
- `~/scripts/scrcpy-freefire.sh` — refactor completo

---

### 2026-07-27 — Sesión Buffy (sexta parte): Fix mango-kwin-session + foot.ini + systemd service

**Problema:** La sesión mango-kwin crasheaba al arrancar (ruta incorrecta de `kded6`) y el terminal
foot mostraba errores de colores. La sesión mango funcionaba.

**Cambios:
- **`~/.local/bin/mango-kwin-session`**: Fix ruta `/usr/lib/kded6` → `/usr/bin/kded6`. Agregado
  `systemctl --user --wait start mango-kwin.service` (patrón systemd como mango-session). Eliminado
  `--inputmethod` (ya configurado en kwinrc). Eliminado portal KDE directo (D-Bus auto-activación).
- **`~/.config/systemd/user/mango-kwin.service`**: NUEVO. Idéntico patrón a `mango.service`:
  `BindsTo=graphical-session.target`, `ExecStart=kwin_wayland --no-lockscreen --exit-with-session`.
- **`~/.config/foot/foot.ini`**: Colores cambiados de `#RRGGBB` a `RRGGBB` (foot no acepta prefijo `#`).

**Archivos modificados/creados:**
- `~/.local/bin/mango-kwin-session` — corregido
- `~/.config/systemd/user/mango-kwin.service` — NUEVO
- `~/.config/foot/foot.ini` — corregido
- `ai-context/CHANGELOG.md` — actualizado

---

### 2026-07-26 — Sesión Hermes: Polybar melissa — se REVIRTIÓ TODO a estado original

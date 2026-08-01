> ⚠️ **Poda automática**: Cuando este archivo supere ~30KB o ~5 entradas
> recientes (sin contar archive), las entradas más viejas se mueven a
> `CHANGELOG-archive.md`. Actualmente ~175 líneas — pendiente de archivar.

---

version: 1.7
updated: 2026-08-01
schema: system-profile
system-id: mangonz-desktop
---

# CHANGELOG.md — Historial de cambios del sistema

### 2026-08-01 — Fix ruta de rish + prueba real de --grant con diálogo de permiso

**Hallazgo:** En la primera prueba real con `--grant`, el script fallaba con `rish: not found` porque rish vive en `~/bin/rish` y no está en PATH en este dispositivo.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): nueva función `resolveRish()` — resuelve la ruta con prioridad env `RISH` > `~/bin/rish` (si existe) > `rish` en PATH (vía `command -v`) > fallback `rish`. La constante `RISH` usa ahora la ruta resuelta.
- **Prueba real completada**: diálogo de notificaciones de VInstall (`com.vinstall.alwiz`) detectado por Kimi K3 al 98% (título, botones PERMITIR/NO PERMITIR) y concedido: `pm grant POST_NOTIFICATIONS` + `appops POST_NOTIFICATION=allow`. Verificado: `granted=true`, appop `allow`.


### 2026-08-01 — Fix endpoint Kimi K3 (router.huggingface.co/v1, sin /hf)

**Hallazgo:** El endpoint `/hf/v1/chat/completions` devuelve 404; el correcto es `https://router.huggingface.co/v1/chat/completions` (verificado con prueba real: HTTP 200, Kimi K3 respondió en 10.2s).

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): `KIMI_ENDPOINT` default corregido a `router.huggingface.co/v1/chat/completions` (header + constante), + hint de error para 404 que recomienda revisar `KIMI_ENDPOINT`.
- **`Knowledge/AI/Kimi-K3.md`**: las 3 referencias al endpoint actualizadas a `/v1` (tabla de acceso, ejemplo curl, sección Script implementado).
- **Nota:** las entradas históricas de este CHANGELOG mencionan `/hf/v1`; quedan como referencia del estado previo al fix.


### 2026-08-01 — kimi_vision.js integrado al repo buffy-context

**Pedido del usuario:** Agregar kimi_vision.js al repo: copiarlo a scripts/ y documentarlo en Knowledge/AI/Kimi-K3.md.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (NUEVO): copia del script de visión IA (Kimi K3) para detectar diálogos de permisos — upgrade de auto_permiso.py. Idéntico al origen `~/kimi_vision.js` (22639 bytes, diff 0), `node --check` OK.
- **`scripts/lib/logger.js` + `scripts/lib/utils.js`** (NUEVOS, vendored): copias de `~/lib/` para que el script sea **autocontenido y ejecutable desde el repo** (verificado: `node scripts/kimi_vision.js --help` ✅). Marcados como copia vendored (actualizar desde `~/lib/`).
- **`Knowledge/AI/Kimi-K3.md`**: Nueva sección "Script implementado: scripts/kimi_vision.js" — modos CLI, cómo funciona (base64 → Kimi K3 → JSON → mapeo rish), robustez (retry/backoff, parseo robusto, fallback other), verificación.
- **`README.md`**: árbol de scripts actualizado con `kimi_vision.js`.


### 2026-08-01 — kimi_vision.js creado + repo clonado vía SSH

**Pedido del usuario:** Crear el script kimi_vision.js (visión IA con Kimi K3 para detectar diálogos de permisos, upgrade de auto_permiso.py) y sincronizar buffy-context con un clon local vía SSH.

**Cambios aplicados:**
- **`~/kimi_vision.js`** (NUEVO, fuera del repo): visión IA con `moonshotai/Kimi-K3` vía API HF OpenAI-compatible (`router.huggingface.co/hf/v1/chat/completions`). Screenshot en base64 → modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + licencia gated aceptada. Probado con API simulada ✅ (extractJson 3 casos, mapeo, pipeline completo); 2 pasadas de code review (fixes: mtime en monitorLoop, orden help-vs-token, Number.isFinite en args).
- **Repo clonado**: `~/buffy-context` vía HTTPS + remote `origin` en SSH (`git@github.com:...`). 44 archivos, working tree limpio, los 5 commits del doc Kimi K3 presentes.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 actualizada — kimi_vision.js + clon SSH + pendientes (clave SSH por registrar, HF_TOKEN, prueba real).
- **Clave SSH**: ed25519 generada en este dispositivo; **pendiente de registrar** en github.com/settings/keys (el token actual no tiene scope `admin:public_key`).


### 2026-08-01 — Kimi K3 vía Hugging Face + MCP documentado

**Pedido del usuario:** Investigar cómo usar Kimi K3 (Moonshot AI) desde Hugging Face vía MCP y documentar el hallazgo en el repo.

**Cambios aplicados:**
- **`Knowledge/AI/Kimi-K3.md`** (NUEVO): Referencia del modelo — 2.8T params MoE, multimodal nativo, 1M contexto, tool calling. Acceso: HuggingChat web, API OpenAI-compatible `router.huggingface.co/hf/v1` + token HF (pago por uso), API Moonshot. Aclaración clave: MCP conecta herramientas, NO es la forma de usar el modelo (HuggingChat es cliente MCP; el MCP oficial de HF expone el Hub). Casos de uso: visión de screenshots (upgrade OCR/auto_permiso.py), análisis de contexto 1M (CSVs SecurGuard, dumpsys, logcat), segunda opinión de código, JSON estructurado.
- **`Knowledge/README.md`**: Nueva categoría `AI/` indexada en el árbol + fecha actualizada a 2026-08-01.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 registrada; sesión 07-29 archivada (poda automática).
- **`ai-context/SESION-archive.md`**: Sesión 07-29 (día completo) movida al archivo.


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

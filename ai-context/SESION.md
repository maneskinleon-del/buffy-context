# 🧠 SESION — Bitácora de sesiones

> ⚠️ **Poda automática**: Solo se mantienen las últimas ~3 sesiones aquí.
> Histórico completo en `SESION-archive.md` (cargar solo si es necesario).

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

- **`kimi_vision.js`** (raíz, Node 26, CommonJS): visión IA con Kimi K3 (`moonshotai/Kimi-K3`) vía API HF OpenAI-compatible (`router.huggingface.co/v1`). Envía el screenshot en base64; el modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + aceptar licencia gated del modelo. Probado con API simulada (extractJson 3 casos, mapeo, pipeline completo ✅) y con HF_TOKEN real (endpoint corregido a `/v1`, Kimi K3 respondió en 10.2s ✅).
- **Repo `buffy-context` clonado en este dispositivo**: `~/buffy-context` (44 archivos, working tree limpio). Remote `origin` en **SSH** (`git@github.com:maneskinleon-del/buffy-context.git`). Clave ed25519 registrada en GitHub ✅ y push exitoso (`7bcb639`).
- **`kimi_vision.js` integrado al repo** (scripts/): copiado a `scripts/kimi_vision.js` (diff 0, `node --check` ✅), documentado en `Knowledge/AI/Kimi-K3.md` (sección "Script implementado") y en el árbol de `README.md`.

## 🔜 Pendientes

- [x] `kimi_vision.js` creado — script de visión IA (upgrade de `auto_permiso.py`) ✅
- [x] Clave SSH registrada en github.com/settings/keys y push por SSH funcionando ✅
- [x] `kimi_vision.js` agregado al repo en `scripts/` y documentado ✅
- [ ] Token HF con scope de inferencia + método de pago configurado (el scope de inferencia ya se validó con la prueba real ✅; falta método de pago)
- [x] Probar `kimi_vision.js` con HF_TOKEN real ✅ (Kimi K3 respondió en 10.2s; identificó correctamente que el screenshot NO era un diálogo de permiso)
- [ ] Probar `kimi_vision.js` contra un screenshot de un diálogo de permiso real (con `--grant`)
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

# 🔄 CONTINUE — Handoff entre sesiones

> ⚡ **PRÓXIMA SESIÓN: LEE ESTO PRIMERO**
> Generado: 2026-07-30 noche (cierre de sesión — RAM + watchdog MCP + force-stop Free Fire)

---

## Resumen de la sesión

**Tema principal:** Limpieza de RAM (kill de procesos huérfanos), creación de un watchdog automático para chrome-devtools-mcp, y matanza de apps de terceros en el script de Free Fire.

---

### ✅ Logros principales

#### 1. 🧹 Diagnóstico y limpieza de RAM
- Top consumidores: Chrome (~1.1GB), open-webui/uvicorn (~1GB), freebuff (~515MB)
- Se mató el **chrome-devtools-mcp huérfano** que quedó de la verificación de GitHub → **~1.1GB liberados**

#### 2. 🛡️ Watchdog automático `cleanup-mcp.sh`
- Creado `~/.local/bin/cleanup-mcp.sh` + units systemd user (`mcp-cleanup.service` oneshot + `mcp-cleanup.timer` cada 5 min)
- Regla: mata MCP con **edad > 10min** Y **CPU del árbol < 1% en 2 muestras** (4s + 6s + 4s)
- Log: `~/.local/state/mcp-cleanup.log` · Verificado con timer activo y ejecución real
- chrome-devtools-mcp **no tiene flag nativo de auto-exit** (se verificó su `--help` completo)

#### 3. 🎮 Force-stop de apps de terceros en `~/scripts/scrcpy-freefire.sh`
- Función `kill_background_apps()`: `pm list packages -3` + `am force-stop` por app
- **Excluye GG Mouse** (`com.zjx.ztezscreenshot`) y **Free Fire** (`com.dts.freefireth`)
- Configurable: `KILL_BG_APPS="1"` + `KEEP_ALIVE_APPS="com.zjx.ztezscreenshot com.dts.freefireth"`
- **Probado en el ZTE: 91 apps matadas, GG Mouse + FF intactos** ✅

#### 4. 📦 (mañana) Push repo GitHub + auditoría repo home
- Los 12 commits pendientes subidos a GitHub vía SSH (remote HTTPS→SSH con `~/.ssh/id_ed25519`)
- Repo del home (`/home/mangonz`, master, sin remote) trackea 104 archivos — única historia de GameBoost Pro/codebuff-automation. **Dejado como está** por decisión del usuario.

---

### 📁 Archivos modificados/creados (sesión completa)

| Archivo | Cambio |
|---------|--------|
| `~/scripts/scrcpy-freefire.sh` | ✅ kill_background_apps() + toggles KILL_BG_APPS/KEEP_ALIVE_APPS |
| `~/.local/bin/cleanup-mcp.sh` | **NUEVO** — watchdog MCP (ejecutable) |
| `~/.config/systemd/user/mcp-cleanup.service` | **NUEVO** — servicio oneshot |
| `~/.config/systemd/user/mcp-cleanup.timer` | **NUEVO** — timer cada 5 min (habilitado) |
| `ai-context/CONTINUE.md` | ✅ Actualizado (este archivo) |
| `ai-context/SESION.md` | ✅ Entrada 2026-07-30 noche |
| `ai-context/SNAPSHOT.md` | ✅ Regenerado (en ~/ai-context/, gitignored en el repo) |
| Remoto del repo | ✅ HTTPS → SSH |

---

### ⏳ Pendientes para próxima sesión

1. **Probar `scrcpy-freefire.sh` completo en vivo** — El force-stop está probado por separado, pero falta probar el script end-to-end con GG Mouse + Free Fire + scrcpy.
2. **Shizuku + comando privilegiado** — Quedó pendiente ejecutar un comando privilegiado (deshabilitar app, forzar GPU rendering, etc.).
3. **Visión/VLM** — Agregar soporte de imágenes (Qwen2.5-VL, MiniCPM-V). Análisis de screenshots Android.
4. **Diagnóstico Free Fire en vivo** — `dumpsys gfxinfo` + `SurfaceFlinger --latency` con el juego activo.
5. **Opcional: limpiar repo del home** — `.gitignore` agresivo si algún día se le agrega un remote.

---

### ⚠️ Problemas conocidos

- **`scripts/ai-context.sh`** — Script legacy que genera zips de debugging. Obsoleto pero no interfiere.
- **Repo del home sin limpiar** — `git add -A` en `/home/mangonz` podría trackear cosas sensibles (`.gitconfig`, `.ollama/`, `.m2/`). Evitar sin fijarse.
- **Shizuku**: Al reiniciar el dispositivo se detiene y hay que volver a activarlo.
- **Push** — Ahora usa SSH (`git@github.com:`), ya no requiere token HTTPS.
- **`am force-stop` ruido** — Imprime "Force stopping..." por stdout en Android moderno (93 líneas). Inofensivo; si molesta: `>/dev/null 2>&1`.

---

## Stack del usuario (referencia rápida)

```
OS:    EndeavourOS (Arch) · kernel 6.18.39-1-lts
WM:    bspwm (X11) · rice gh0stzk/cynthia · picom
Shell: zsh (Oh My Zsh + Starship) · alacritty · editor VSCodium
CPU:   Ryzen 5 3400G (4C/8T) + Vega 11 · 13GB RAM · 1360x768
Phone: ZTE Nubia Z2352N · Android 13 · Unisoc T820 · ADB + Shizuku activo
Stack: React + TS + Tailwind v4 + Vite → GitHub (maneskinleon-del) → Vercel
Node:  v26.4.0 · npm 11.18.0 · gh CLI 2.96.0
Git:   maneskinleon-del / mangonz970@gmail.com
```

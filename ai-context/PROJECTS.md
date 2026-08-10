---
version: 1.4
updated: 2026-08-06
schema: system-profile
system-id: mangonz-desktop
---

# PROJECTS.md — Proyectos activos

> Este archivo cambia seguido. Actualizar cuando un proyecto avanza de fase o cambia de stack/deploy.

## Escritorio — Rice "vista" (estilo Windows Vista Aero)
- **Qué:** rice nuevo del sistema gh0stzk (`~/.config/bspwm/rices/vista/`) — el escritorio actual se ve como Windows Vista Aero
- **Aplicado:** 2026-08-07 · `.rice` → `vista` (backup en `~/.config/bspwm/.rice.bak` = cynthia)
- **Componentes:** wallpaper aurora Vista auténtico (wall-03.webp), barras polybar como paneles de vidrio flotantes (radius 8, border 1, padding en px) — barra inferior = inicio rápido (browser·filem·terminal·editor) | CPU·RAM·temp·disco | tray + fecha/hora; barra superior = launcher+título | escritorios | red·volumen·updates·power; picom blur activo (vidrio) + corner-radius 8; GTK MonochromeBlue-zk; rofi azul Aero; alacritty opacity 0.92; bordes bspwm azules
- **Notas barras (2026-08-07):** botón Start (logo Windows) retirado a pedido; workspaces solo en la barra superior; módulos del centro inferior limpios (sin fondos translúcidos mb); sensor temp = k10temp (`hwmon2/temp1_input`); detalle de bugs resueltos y gotchas de polybar 3.7.2 en `rices/vista/CHANGELOG.md`
- **Revertir:** `RiceSelector` (clic derecho en launcher) → elegir `cynthia`, o `echo cynthia > ~/.config/bspwm/.rice && ~/.config/bspwm/bin/Theme.sh` + reiniciar picom
- **Nota:** se añadió `blur-background = true` a la regla dock de `picom-rules.conf` (compartida — las barras translúcidas de cualquier rice ahora hacen blur)

## Gmail Organizer V3 (organiza_gmail_V3)
- **Objetivo:** clasificar automáticamente la bandeja de entrada de Gmail en etiquetas (Compras, Telecom, Bancos, Gobierno, Trabajo, Facturas, Envíos, etc.) con etiquetas específicas por empresa (BancoEstado, Tenpo, Fonasa, Mercado Libre, AliExpress, WOM...)
- **Plataforma:** Google Apps Script (V8 runtime, timeZone America/Santiago)
- **Script ID:** `1yqqZXC4kysIlMMbY57Bi6Ft5Jf5mtO3fUX9EnT41BJtCOnMXmQ01I_sK`
- **Ruta local:** `~/proyectos/gmail-scripts/` (git local, commit `a207071`, sincronizado vía `clasp pull` el 2026-08-10)
- **Componentes:** `main.js` (entrada con rate limiting + triggers), `gmail.js` (procesamiento por lotes con reanudación), `scoring.js` (scoring de importancia), `classifiers.js`/`companies.js` (reglas de clasificación), `labels.js`, `reports.js` (reporte diario), `config.js`, `constants.js`, `cleanup_tmp.js` (limpieza one-shot de etiquetas), `test.js`
- **Detalles clave:** fix de paginación con snapshot único `search()` en vez de `getInboxThreads(pos)`; reanudación tras pausa/cuota (`scheduleResume`); restaura cadencia de triggers al completar
- **Estado:** sincronizado con la web (`script.google.com`) — la versión de la web tenía mejoras que se bajaron al repo

## Drive Organizer Pro (ordenar_drive_pro)
- **Objetivo:** organizar Google Drive por reglas de clasificación (MIME + nombre + prioridad), modo MAESTRO (todo el Drive BFS) o ESPECÍFICO (carpeta por ID), con modo PRUEBA (simula) / REAL (mueve)
- **Plataforma:** Google Apps Script (V8 runtime, timeZone America/Santiago)
- **Script ID:** `1TW8pIdyQAUeAI7ZznVY4KCZgZtGirq_leLUX8vXWQa1e0i6prPIpzBOu`
- **Ruta local:** `~/proyectos/gmail-scripts-otro/` (git local, commit `610a040`, sincronizado vía `clasp pull` el 2026-08-10)
- **Componentes:** `main.js` (entrada con rate limiting + triggers), `organizador.js` (núcleo BFS con batches y reanudación por cola de carpetas), `clasificador.js` (motor de reglas con prioridad), `drive.js` (utilidades: carpetas, extensiones, exclusiones), `config.js` (reglas + carpetas administradas/excluidas), `estadisticas.js` (conteo con desglose recursivo), `script_limpieza.js`, `logger.js`, `constants.js`
- **Detalles clave:** rate limiting estilo Gmail Organizer (batches de 30, delay 1s, runtime limit 270s, retry con backoff); carpetas administradas: Scripts, Documentación, Android, Configuraciones, Multimedia, Backups, Web, Recursos, Sin clasificar, Comprimidos, Chats; excluidas: Google Fotos, Trash, etc.
- **Estado:** v5.0 sincronizado con la web — la versión de la web tenía mejoras que se bajaron al repo

## TimeMark
- **Objetivo:** watermark/timestamp para fotos de seguridad de campo
- **Stack:** React + TypeScript + Tailwind v4 + Vite
- **Ruta:** `~/timemark/`
- **Estado:** iterando bugs — canvas resolution, race conditions en render, layout flex

## SecurGuard (pwa_securguard)
- **Objetivo:** control de acceso y reportería para guardias
- **Stack:** React + TypeScript + Tailwind v4 + Vite
- **Ruta:** `~/antigravity/SecurGuard-AI/`
- **Estado:** refactor mayor completado — RUT (mod-11), emergency lock, avatar fallback, filtrado debounced, backup JSON automático antes de operaciones destructivas. Pendiente: fix encoding CSV (BOM UTF-8 vs Latin-1 en Sheets)

## Scuderia Data / AutoData MG 350 (data_car)
- **Objetivo:** gestión de vehículo (MG 350)
- **Stack:** React + TypeScript + Tailwind v4 + Vite
- **Repo:** `maneskinleon-del/data_car`
- **Deploy:** `scuderia-data.vercel.app`
- **Ruta:** `~/data_car/` (restaurado desde el repo el 2026-07-31 — el path local faltaba; `~/antigravity/scuderia-data/` no existe)
- **Estado:** telemetría falsa/contenido IA removido; IndexedDB para PDFs (SOAP, revisión técnica); campos chasis/marca/dueño editables inline; **fix de persistencia desplegado** — write-through síncrono + flush en pagehide/visibilitychange, verificado e2e en producción (el último registro sobrevive al cierre abrupto)

## Generador de Boletas (billing PWA Chile)
- **Objetivo:** boletas/facturación chilena
- **Stack:** React + TypeScript + Tailwind v4 + Vite
- **Estado:** overhaul completado — API key de Gemini movida a función serverless de Vercel, App.tsx refactorizado (era monolítico), export PDF migrado de html2canvas roto a `window.print()` con tamaño A4

## Odysseus
- **Objetivo:** asistente IA propio
- **Ruta:** `~/odysseus/`
- **Estado:** eliminado — 772 KB liberado

## ManUninstaller
- **Objetivo:** desinstalador masivo de apps Android vía Shizuku
- **Stack:** Kotlin + Material Design 3 + XML layouts
- **Ruta:** `~/proyectos/ManUninstaller/`
- **APK:** `app/build/outputs/apk/debug/app-debug.apk`
- **Dispositivo:** ZTE nubia Neo 2 (Z2352N) — Android 13
- **Versión actual:** 2.0.0 (versionCode 2)
- **Descubrimiento de código:** indexado con **CodeGraph** (31 archivos, 486 nodos, 838 aristas) — usar `codegraph explore/query/callers/impact` o la herramienta MCP `codegraph_explore` antes de grep o leer archivos.
- **Estado:** ✅ Completado — navegación, filtros, App Detail Sheet, pestaña Herramientas, stats reales, paleta púrpura oscura. 29 tests pasan.

## lista_supermercado / lista_fresh
- **Objetivo:** lista de compras (supermercado)
- **Ruta:** `~/lista_supermercado/`, `~/lista_fresh/`
- **Estado:** sin detalle reciente

## GameBoostPro (AutoJS6)
- **Objetivo:** optimizador gaming para Free Fire vía Shizuku/rish
- **Plataforma:** AutoJS6 (Android, ZTE Neo 2 5G, Unisoc T820)
- **Estado:** múltiples versiones — thermal zone discovery dinámico, CPU affinity topology-aware, overlay flotante draggable, módulo de velocidad ADS

## GameBoost Pro (autoscript-mobile-interface — Kotlin nativo)
- **Objetivo:** optimizador gaming para juegos móviles vía Shizuku + AccessibilityService (versión nativa Kotlin/Compose; ver también GameBoostPro AutoJS6)
- **Stack:** Kotlin + Jetpack Compose + Material 3 + Room
- **Ruta:** `~/proyectos/autoscript-mobile-interface/`
- **Descubrimiento de código:** indexado con **CodeGraph** (49 archivos, 1.084 símbolos, 1.896 aristas) — usar `codegraph explore/query/callers/impact` o la herramienta MCP `codegraph_explore` ANTES de grep o leer archivos. Detalle en `AGENTS.md` del proyecto.
- **Estado:** activo — monitoreo térmico, gestión de sesión de juego, optimizador de red, overlay flotante de métricas

## SYSMON (sysmon3.sh + sysmon_ui.js)
- **Objetivo:** monitor de sistema Android
- **Componentes:** script shell `sysmon3.sh` + UI AutoJS6 `sysmon_ui.js`
- **Estado:** GPU detection, CPU per-core, lecturas térmicas, bridge Shizuku/rish, sanitizador JSON

## Desinstalador de apps (AutoJS6)
- **Objetivo:** desinstalar apps Android con UI nativa
- **Scripts:** `desinstalar_apps.js`, "Desinstalador Pro" (glassmorphism, vistas nativas)
- **Estado:** funcional

## KWGT widget (terminal-style)
- **Objetivo:** widget estilo terminal para KWGT
- **Estado:** variables verificadas, alineación con fuente monospace

## codebuff-automation (fill_form.js)
- **Objetivo:** Automatización de formularios web + OCR Android
- **Stack:** Node.js + Puppeteer-core + Chromium + Python + Tesseract
- **Ruta:** `~/codebuff-automation/`
- **Versión:** v4.0 (portado de Termux a PC de escritorio)
- **Componentes:**
  - `fill_form.js` v4.0: SmartMapper multi-idioma (28 cat), CAPTCHA, proxy rotativo, entrenamiento, webhooks, sesiones, iframes, Docker
  - `auto_permiso.py` v2.0: OCR + root para permisos Android
  - `test-form.html`: 21 campos de prueba
  - Skills (5 docs): form-filler, image-analyzer, hyperos-hardening, xiaomi-adb-tricks, shizuku-rikka
- **Dependencias:** puppeteer-core 25.4.0, Chromium 150, Tesseract 5.5.2+spa
- **Test:** 21 campos detectados, 17 llenados, 0 fallidos (13s)
- **Pendiente:** Crear cuenta Ollama para modelo cloud, integrar Ollama en fill_form.js

## kimchi (agente propio)
- **Objetivo:** agente de coding (deepseek-v4-flash) para desarrollo de PWAs
- **Config:** `EFICIENCIA.md` / `AGENTS.md` — reglas de eficiencia de tokens y sistema de verificación "ferment"
- **Nota:** bug conocido — "No pending scope for ferment" en la máquina de estados post-completación
- **Estado:** ❌ Eliminado — 139 MB liberado

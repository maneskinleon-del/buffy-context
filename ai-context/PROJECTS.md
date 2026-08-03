---
version: 1.3
updated: 2026-07-31
schema: system-profile
system-id: mangonz-desktop
---

# PROJECTS.md — Proyectos activos

> Este archivo cambia seguido. Actualizar cuando un proyecto avanza de fase o cambia de stack/deploy.

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
- **Estado:** ✅ Completado — navegación, filtros, App Detail Sheet, pestaña Herramientas, stats reales, paleta púrpura oscura. 29 tests pasan.

## lista_supermercado / lista_fresh
- **Objetivo:** lista de compras (supermercado)
- **Ruta:** `~/lista_supermercado/`, `~/lista_fresh/`
- **Estado:** sin detalle reciente

## GameBoostPro (AutoJS6)
- **Objetivo:** optimizador gaming para Free Fire vía Shizuku/rish
- **Plataforma:** AutoJS6 (Android, ZTE Neo 2 5G, Unisoc T820)
- **Estado:** múltiples versiones — thermal zone discovery dinámico, CPU affinity topology-aware, overlay flotante draggable, módulo de velocidad ADS

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

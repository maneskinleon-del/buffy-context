# Changelog — Buffy Context

> Generado con la skill `changelog-generator` a partir de los commits de git (2026-07-29 → 2026-08-02).
> Historial de *sesiones* de memoria → `ai-context/CHANGELOG.md` (separado de este).

## 2026-08-02

### ✨ Nuevas funcionalidades

- **Visión IA para permisos Android** — nuevo script `scripts/kimi_vision.js` que usa el modelo multimodal **Kimi K3** (vía Hugging Face) para detectar y conceder diálogos de permisos en screenshots, reemplazando el OCR básico. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`.
- **Soporte de visión en terminal** — skill `vision-adapter`, referencia `Knowledge/Vision.md` y script `see.sh` para ver capturas/imágenes desde el terminal.
- **Skill de búsqueda de código** — `code-search` con criterios v4 para buscar en el codebase de forma más precisa.
- **Liberador de RAM de Ollama** — `scripts/ollama-kill.sh` para detener el daemon cuando no se usa.
- **Repo público** — licencia MIT + README profesional con estructura, quick start y guía de uso con agentes de IA.
- **Skill `android-project-setup`** — automatiza el ciclo build → install → permisos → launch de los proyectos Android del usuario (GameBoost Pro, ManUninstaller). Incluye `scripts/` (check_device, build_install, grant_permissions) y referencias de dispositivos/permisos. Probada contra el ZTE Nubia real (serial 320344802623).

### 🔧 Mejoras

- **Scripts autocontenidos** — `kimi_vision.js` ahora se ejecuta directo desde el repo (dependencias vendored en `scripts/lib/`).
- **Endpoint corregido y documentado** — Kimi K3 se usa vía `router.huggingface.co/v1` (sin el prefijo `/hf` que daba 404), con hint de error para detectarlo.
- **Detección automática de rish** — prioridad: env `RISH` > `~/bin/rish` > `PATH` (probado con un diálogo real de permisos).
- **Unificación de `ai-context`** — `SESION.md` y `CHANGELOG.md` fusionados en una sola fuente de verdad (`~/ai-context` → symlink al repo).
- **Presupuesto de tokens y carga condicional** — protocolo `LOAD_CONTEXT.md` con carga selectiva según la tarea.
- **Poda automática de memoria** — las sesiones/changelogs grandes se archivan solos (`SESION-archive.md`, `CHANGELOG-archive.md`).

### 🐛 Correcciones

- **Endpoint de Kimi K3** — 404 por el prefijo `/hf` incorrecto en las llamadas.
- **`see.sh`** — mejor manejo de errores, timeout, limpieza con `trap` y `mktemp` portable.
- **Sintaxis de flags de ripgrep** en la skill de búsqueda de código.
- **Ruta de `rish`** — el modo `--grant` fallaba con `rish: not found`; ahora resuelve la ruta correctamente.

---

*Proyecto iniciado el 2026-07-29. Commits internos de documentación/sesiones filtrados del resumen.*

# Changelog — Buffy Context

> Generado con la skill `changelog-generator` a partir de los commits de git (2026-07-29 → 2026-08-02).
> Historial de *sesiones* de memoria → `ai-context/CHANGELOG.md` (separado de este).

## 2026-09-29

### 🔒 Privacidad (C2 — redacciones HEAD + guard de regresión)

- **Redacciones A-list en tracked** — email/nombre real (`Knowledge/Git/Commands.md`, `ai-context/INFO-core.md`), serial del dispositivo (`Knowledge/Android/NubiaLab.md`, `CHANGELOG.md`, skill `android-project-setup` ×3), Script IDs de Apps Script (`ai-context/PROJECTS.md`), ruta absoluta del home del operador (11 apariciones en 4 archivos) → forma `~` (convención del repo). Cada redacción con marca de auditoría y puntero al valor real local. El alias del operador queda fuera hasta D2.1 (decisión pendiente).
- **Guard de regresión PII** (`test-pii-guard.sh`, 6 checks): los patrones redactados no pueden reaparecer en tracked (`git grep`, no disco). Exclusión temporal de `scripts/tests/evals/` hasta C5 (corpus congelado del 2026-08-13 con PII histórica) — al ejecutar C5: quitar la exclusión y esperar 0 absoluto.
- **Convención anti-falso-éxito registrada** en `LOAD_CONTEXT.md` — familia de 5 casos con nombre propio: health check que miente (Ollama wedged), estado que registra intención (sync push), test time-bomb (fixture TTL), test dependiente del entorno (caso uv), mecanismo escrito pero no conectado (hook pre-commit).

## 2026-09-28

### 🧪 Tests (preparatorio a C1): Ollama fuera del camino crítico

- **Probe de capacidad en vez de liveness** — `ollama_up()` en los tests de selector/expand-query ahora hace `POST /api/embed` (bge-m3, el endpoint real del motor) con gate de performance para input largo (~5.7KB ≤ 6s). `GET /api/tags` respondía 200 con el serve colgado → tests colgados 10 min en el hook pre-commit (falla 2026-09-28). Skips honestos que documentan el contrato RC=3 (auditoría 2026-09-25).
- **Motor acotado** — `selector_m3.py`: `ollama_available()` pasa de GET tags a probe embed; `ollama_post` de `retries=3 × timeout=600s` (hasta ~30 min colgado) a `retries=1 × timeout=20s`.
- **Techos `timeout` por comando** en toda invocación pesada de tests (15B, rama-P, determinismo, pool-crece, smoke Q03) — ni un wedge de Ollama a mitad de corrida puede colgar la suite.
- Decisión arquitectónica completa documentada en `CONTRIBUTING.md` §Tests: Ollama como feature queda (degradación RC=3 ya implementada); como dependencia de tests/CI/pre-commit sale del camino crítico. Marado como enhancement opcional en README y LOAD_CONTEXT.

### 🔒 Privacidad (auditoría PII — decisión D0.1b, Opción 1)

- **Canal privado de memoria** — `ai-context/memories/` deja de versionarse en el repo público: el perfil de identidad (USER.md) y las notas del operador (MEMORY.md) ya no viajan por el Git de este repo (auditoría PII 2026-09-28). Source: `~/.buffy/memories`; la sincronización entre dispositivos va vía `BUFFY_SYNC_DIR` apuntando a un repo privado — el env ya existía en `buffy-memory-sync.sh`, ahora es el canal documentado.
- **Guards anti-falso-éxito en `sync push`** — cinco protecciones: (1) aborta si el destino está gitignoreado, antes de mutar nada; (2) verifica que cada candidato quedó stageado (check específico, no genérico); (3) propaga el RC de add/commit antes de pushear; (4) si el push falla NO marca `.sync-state` — contrato nuevo: el estado registra lo último *efectivamente* pusheado, no lo *intentado* — y deja un registro de push pendiente que el próximo `sync push` reintenta automáticamente; (5) pre-check global antes de mutar (atomicidad por corrida). Antes, un add/commit/push fallido se reportaba "✔ commiteado y pusheado" sin haber sincronizado nada.
- **Untrack de estado personal** — `USER-MANU.md`, `shizuku_watchdog_recovery_final_report.txt` y `ai-context/memories/*` fuera del index (siguen en disco); `.sync-state` cubierto preventivamente en `.gitignore`.
- **Tests** — 3 tests nuevos de git real (`test-memory-sync-guards.sh`) ejercitan los guards (gitignore → abort honesto, push fallido → estado sin marcar + reintento, stage específico); el sandbox de close-day replica el canal privado (remote bare).

## 2026-08-02

### ✨ Nuevas funcionalidades

- **Visión IA para permisos Android** — nuevo script `scripts/kimi_vision.js` que usa el modelo multimodal **Kimi K3** (vía Hugging Face) para detectar y conceder diálogos de permisos en screenshots, reemplazando el OCR básico. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`.
- **Soporte de visión en terminal** — skill `vision-adapter`, referencia `Knowledge/Vision.md` y script `see.sh` para ver capturas/imágenes desde el terminal.
- **Skill de búsqueda de código** — `code-search` con criterios v4 para buscar en el codebase de forma más precisa.
- **Liberador de RAM de Ollama** — `scripts/ollama-kill.sh` para detener el daemon cuando no se usa.
- **Repo público** — licencia MIT + README profesional con estructura, quick start y guía de uso con agentes de IA.
- **Skill `android-project-setup`** — automatiza el ciclo build → install → permisos → launch de los proyectos Android del usuario (GameBoost Pro, ManUninstaller). Incluye `scripts/` (check_device, build_install, grant_permissions) y referencias de dispositivos/permisos. Probada contra el ZTE Nubia real (serial redactado 2026-09-28 — no versionar seriales).

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

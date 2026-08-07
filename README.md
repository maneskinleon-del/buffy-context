# Buffy Context

> **Persistent AI memory, structured knowledge base, and specialized agents for AI coding assistants.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/maneskinleon-del/buffy-context?style=social)](https://github.com/maneskinleon-del/buffy-context)
[![GitHub last commit](https://img.shields.io/github/last-commit/maneskinleon-del/buffy-context)](https://github.com/maneskinleon-del/buffy-context/commits/main)
[![CI](https://github.com/maneskinleon-del/buffy-context/actions/workflows/ci.yml/badge.svg)](https://github.com/maneskinleon-del/buffy-context/actions/workflows/ci.yml)

---

## Overview

Buffy Context solves a fundamental problem with AI coding assistants: **every session starts from zero**.

This repository provides the infrastructure for an AI agent to maintain persistent context across sessions, access structured technical knowledge, and automatically specialize based on the project and stack being worked on.

### What's included

| Component | Purpose |
|---|---|
| **Memory persistence** | Protocol for loading/saving session context so the AI never starts blank |
| **Knowledge base** | 19 files of curated technical reference across 8 categories + Vision.md |
| **23 skills** | Especializadas por dominio, cada una con `skill.yaml` machine-readable |
| **Android Agent** | Dedicated skill that auto-detects Android projects and activates relevant tools |
| **Detection scripts** | Shell scripts for system snapshots and Android diagnostics |
| **Self-diagnostics** | doctor --json detecta drift, repair corrige lo seguro, agent orquesta el ciclo |
| **Conditional loading** | Token-aware protocol: carga solo lo necesario según el tema |
| **Auto-pruning** | SESION.md mantiene máximo 5 entradas, el resto se archiva |
| **CI verde** | Suite 164 checks (148 `--quick`) + doctor baseline 0 + verify factual en cada push/PR |
| **Provenance de hechos** | `facts.yaml` con source/confidence/scope/fecha/ttl por hecho (genera `buffy-verify.sh --update-facts`); TTL enforzado (`expired` si vence) |
| **Reglas declarativas** | `ai-context/facts_rules.yaml` + `scripts/lib/facts_engine.py` — agregar un hecho NO requiere tocar el motor; comandos en lista, ejecución sin shell (hardening) |

---

## Repository structure

```
buffy-context/
├── ai-context/                        # Session memory & protocol
│   ├── LOAD_CONTEXT.md                # Load/save protocol for AI agents
│   ├── CONTINUE.md                    # Session handoff (what was last done)
│   ├── INFO-core.md                   # User profile, stack, preferences (SIEMPRE)
│   ├── INFO-full.md                   # Detailed user profile (bajo demanda)
│   ├── SESION.md                      # Últimas 3 sesiones (archivado automático)
│   ├── SESION-archive.md              # Histórico completo de sesiones
│   ├── PROJECTS.md                    # Active projects
│   ├── deprecated/                    # Stubs SYSTEM.md/SYSTEM_FULL.md (migrados 2026-08-03)
│   └── CHANGELOG.md                   # Change history
│
├── Knowledge/                         # Structured technical reference
│   ├── AI/
│   │   └── Kimi-K3.md                 # Kimi K3 (Moonshot) — acceso y casos de uso
│   ├── Android/
│   │   ├── ADB.md                     # ADB commands
│   │   ├── Shizuku.md                 # Shizuku + rish
│   │   ├── HyperOS.md                 # Xiaomi debloat & privacy
│   │   ├── GameOptimization.md        # Gaming performance tuning
│   │   ├── scrcpy.md                  # scrcpy profiles, diagnosis, versiones mínimas
│   │   └── Keymappers.md             # GG Mouse, Mantis, Panda, Octopus
│   ├── Linux/
│   │   ├── System.md                  # Arch, bspwm, picom, systemd
│   │   └── Kernel.md                  # Kernel params, modules, sysctl
│   ├── React/
│   │   ├── React.md                   # Patterns, hooks, performance
│   │   ├── Vite.md                    # Config, plugins, PWA
│   │   ├── Tailwind.md               # v4 utilities, dark mode
│   │   └── PWA.md                     # Manifest, service worker
│   ├── Git/
│   │   └── Commands.md               # Daily workflow, gh CLI
│   ├── Node/
│   │   └── Node.md                    # npm, package.json
│   ├── Shell/
│   │   └── Shell.md                   # Variables, awk, sed, trap
│   ├── Tools/
│   │   └── CodeGraph.md               # CodeGraph: grafo de código, MCP, troubleshooting
│   ├── Vision.md                      # VLM local (Ollama): modelos, RAM, versiones
│   └── README.md                      # Knowledge index
│
├── .agents/skills/                    # 23 AI agent skills (cada una con skill.yaml)
│   ├── Android/
│   │   ├── android-adb/               # Comandos ADB generales
│   │   ├── android-agent/             # Detección y diagnóstico Android (logcat, dumpsys)
│   │   ├── android-game-opt/          # Optimización de juegos vía Shizuku/ADB
│   │   ├── android-project-setup/     # Build → install → permisos → launch
│   │   │   ├── scripts/               # check_device, build_install, grant_permissions
│   │   │   └── references/            # Dispositivos y permisos del usuario
│   │   ├── hyperos-hardening/         # Blindaje contra restricciones MIUI/HyperOS
│   │   ├── scrcpy-freefire/           # Mirroring y keymappers para Free Fire
│   │   ├── shizuku-rikka/             # Escalación sin root (Shizuku + rish)
│   │   └── xiaomi-adb-tricks/         # Workarounds ADB/rish/Shizuku Xiaomi
│   ├── Web/
│   │   ├── form-filler/               # Llenado automático de formularios (Puppeteer)
│   │   └── image-analyzer/            # Análisis y procesamiento de imágenes
│   ├── Framework v4 (investigación)/
│   │   ├── exploratory_validation_v4/ # Orquestador: coordina las 4 fases
│   │   ├── filter_heuristics_v4/      # Fase 2: filtra fuentes candidatas
│   │   ├── integration_templates_v4/  # Fase 3: adapta código/docs externas
│   │   ├── cross_validation_v4/       # Fase 4: contrasta fuentes, confianza final
│   │   └── search_criteria_v4/        # Genera consultas de búsqueda estructuradas
│   ├── Code & research/
│   │   ├── code-search/               # Búsqueda portable de código entre asistentes IA
│   │   └── context7/                  # Docs actualizadas de librerías vía ctx7
│   ├── Frontend/
│   │   ├── vite/                      # Referencia Vite para React + TS
│   │   ├── tailwind-design-system/    # Design system con Tailwind v4
│   │   ├── typescript-advanced-types/ # Tipos avanzados de TypeScript
│   │   └── vercel-react-best-practices/ # Buenas prácticas React + TS para Vercel
│   ├── Operación/
│   │   ├── modo-autonomo/             # Protocolo de operación autónoma del agente
│   │   └── vision-adapter/            # Visión/VLM local (Ollama) para imágenes
│
├── scripts/                           # Utility scripts
│   ├── buffy-context.sh               # System snapshot generator
│   ├── buffy-doctor.sh                # Auditoría de salud del ecosistema (--json)
│   ├── buffy-repair.sh                # Aplica fixes AUTO_SAFE y verifica
│   ├── buffy-agent.sh                 # Orquestador: doctor → repair → verify → load
│   ├── buffy-router.sh                # Carga condicional de contexto (--json, manifests)
│   ├── skill-lint.sh                  # Valida los skill.yaml (gate 23/23)
│   ├── migrate-system.sh              # Migra stubs deprecated → ai-context/deprecated/
│   ├── set-version.sh                 # Versionado semver + tag
│   ├── changelog-entry.sh             # Entrada de release automática en CHANGELOG
│   ├── android-detect.sh              # Android project & device diagnosis
│   ├── ollama-kill.sh                 # Libera RAM de modelos VLM (mantiene serve)
│   ├── see.sh                         # Analiza imágenes con VLM local
│   ├── kimi_vision.js                 # Detección de permisos con visión IA (Kimi K3)
│   ├── lib/                           # yaml.sh (parsing compartido) + logger/utils.js
│   ├── hooks/                         # install.sh + pre-commit.sh (suite --quick)
│   └── tests/                         # run-tests.sh + 10 test_*.sh (suite 164 checks, 148 --quick)
│
├── INSTALL.md                         # Setup instructions
├── LICENSE                            # MIT license
└── .gitignore
```

---

## Quick start

### 1. Clone

```bash
git clone https://github.com/maneskinleon-del/buffy-context.git
cd buffy-context
```

### 2. Link scripts (optional)

```bash
ln -sf "$PWD/scripts/buffy-context.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-doctor.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-repair.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-agent.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-router.sh" ~/.local/bin/
ln -sf "$PWD/scripts/android-detect.sh" ~/.local/bin/
```

### 3. Generate system snapshot

```bash
bash scripts/buffy-context.sh
# Creates the system snapshot in the generated state dir (default ~/ai-context/SNAPSHOT.md,
# outside the repo; redirectable via the BUFFY_HOME env var — see INSTALL.md)
```

### 4. Run Android diagnosis (if device connected)

```bash
bash scripts/android-detect.sh        # Full report
bash scripts/android-detect.sh --quick # One-line summary
bash scripts/android-detect.sh --watch # Live monitoring
```

---

## Testing

Run the permanent test suite (pure Bash, no bats required):

```bash
bash scripts/tests/run-tests.sh
```

For CI integration (JSON summary, exit 0 = healthy):

```bash
bash scripts/tests/run-tests.sh --json
```

### GitHub Actions

CI corre automáticamente en cada push a `main` y en cada PR (`.github/workflows/ci.yml`):

- **Suite completa** — `run-tests.sh --json` (gate obligatorio).
- **Doctor con baseline** — audita `buffy-doctor.sh --json` y falla ante **cualquier drift** (`BASELINE_ERRORS=0`): las 13 skills documentadas que faltaban se crearon (2026-08-03) y las 3 que solo vivían en `~/.agents/skills/` se migraron al repo. El CI queda rojo cuando un push/PR introduce drift nuevo.

Run specific tests:

```bash
bash scripts/tests/run-tests.sh doctor   # solo test-doctor.sh
bash scripts/tests/run-tests.sh agent    # solo test-agent.sh
```

Fast mode (skips the sandbox cycles — the slow part that copies the repo):

```bash
bash scripts/tests/run-tests.sh --quick
```

Used by the pre-commit hook and `scripts/migrate-system.sh`; the read-only checks on the real repo still run.

La suite es **determinística y segura**: todo lo que escribe (repair `--auto`, ciclo del agent) corre en un sandbox con HOME aislado; el repo real solo se lee (doctor, dry-run, `--no-repair`).

### Pre-commit hook

La suite corre automáticamente antes de cada commit en modo **`--quick`** (aborta si algo falla):

```bash
bash scripts/hooks/install.sh
```

El installer genera `.git/hooks/pre-commit` con el shebang de bash **real de este sistema** (necesario en Termux, donde `/usr/bin/env` no existe y git ejecuta los hooks con `exec` directo). En Linux normal también funciona. El hook está versionado en `scripts/hooks/pre-commit.sh` — no se pierde en clones.

Opciones del installer: `--install` (por defecto), `--uninstall`, `--check` (verifica hook + shebang), `--force` (sobrescribe), `--no-test`, `--help`.

Variantes del commit:

```bash
git commit                      # suite --quick
BUFFY_HOOK_FULL=1 git commit    # suite completa (una vez)
git commit --no-verify          # saltar los tests (no recomendado)
```

Si actualizas `scripts/hooks/pre-commit.sh`, re-ejecuta `bash scripts/hooks/install.sh --force` para regenerar el hook instalado.

## Versioning

This project follows [Semantic Versioning](https://semver.org/).

- `vX.Y.Z` — Stable releases (see tags)
- `main` — Development branch

Check the latest version:

```bash
cat VERSION
```

Create a new release (validates the version, runs the full test suite, auto-generates the release entry in `ai-context/CHANGELOG.md` from the git log since the last tag, commits `VERSION` + `CHANGELOG.md`, creates an annotated tag and pushes it):

```bash
bash scripts/set-version.sh v1.1.0
```

Preview the changelog entry without writing it:

```bash
bash scripts/changelog-entry.sh --dry-run v1.1.0
```

---

## Usage with AI agents

### For Buffy (Freebuff)

Buffy reads these files automatically at session start following the protocol in `ai-context/LOAD_CONTEXT.md`:

1. `ai-context/CONTINUE.md` — what was being worked on
2. `ai-context/INFO-core.md` — user profile and stack
3. `~/ai-context/SNAPSHOT.md` — system state (regenerated each session, outside the repo; con `BUFFY_HOME` definida vive en `$BUFFY_HOME/ai-context/SNAPSHOT.md` — ver INSTALL.md)

At session end, Buffy updates `CONTINUE.md` and `SESION.md`.

### For other AI agents (Claude Code, Codex, etc.)

1. Point the agent to `ai-context/LOAD_CONTEXT.md` for the protocol
2. Load `Knowledge/` for technical reference
3. Load relevant `.agents/skills/` for specialized behavior

---

## Ciclo operativo (doctor → repair → agent)

Buffy puede **detectar su propio estado, corregir lo seguro y verificar** antes de trabajar:

```
buffy-doctor --json   → diagnóstico estructurado {healthy, errors, items[{id, fix, safe, target}]}
buffy-repair --auto   → aplica solo fixes AUTO_SAFE y vuelve a verificar
buffy-agent           → orquesta el ciclo: preflight → repair → verify → load
```

### buffy-doctor.sh — auditoría de salud

```bash
bash scripts/buffy-doctor.sh           # Reporte humano
bash scripts/buffy-doctor.sh --json    # JSON consumible (CI / agentes / protocolo)
bash scripts/buffy-doctor.sh --quick   # Resumen de una línea
```

Cada item accionable del JSON tiene **identidad** — la reparación es por catálogo, no por parseo de mensajes:

```json
{
  "id": "MISSING_SKILL",
  "level": "err",
  "section": "skills",
  "message": "android-agent missing",
  "fix": "create_skill_dir",
  "safe": true,
  "target": "android-agent"
}
```

Clasificación de seguridad:

| Clase | Fixes | Comportamiento |
|---|---|---|
| **AUTO_SAFE** | `regenerate_snapshot`, `create_ai_context_dir`, `create_skill_dir`, `chmod_plus_x` | `buffy-repair --auto` los aplica sin intervención |
| **REVIEW_REQUIRED** | `create_*file`, `recreate_script`, `copy_skill_to_repo`, `migrate_flat_skill`, `remove_or_merge`, `git_init`, `update_index` | Requieren decisión humana (contenido/credenciales) |

### buffy-repair.sh — el actuador

```bash
bash scripts/buffy-repair.sh              # Plan (dry-run, no aplica nada)
bash scripts/buffy-repair.sh --auto       # Aplica AUTO_SAFE y verifica
bash scripts/buffy-repair.sh --fix NOMBRE # Un fix puntual (solo AUTO_SAFE)
bash scripts/buffy-repair.sh --json       # Resultado JSON (combina con --auto)
```

Exit codes: `0` sin drift · `1` quedan items REVIEW_REQUIRED · `2` error de uso.

### buffy-agent.sh — el orquestador

Envoltura mínima que encadena las piezas confiables:

```bash
bash scripts/buffy-agent.sh "mensaje"   # Ciclo completo + carga de contexto
bash scripts/buffy-agent.sh --no-repair # Solo preflight + carga
bash scripts/buffy-agent.sh --json      # JSON {preflight, repair, verify, load, ready}
```

Exit codes: `0` consistente · `1` queda drift que requiere decisión humana · `2` error.

---

## Knowledge base categories

| Category | Files | Covers |
|---|---|---|
| **AI** | 1 | Kimi K3 — acceso, API, casos de uso |
| **Android** | 6 | ADB, Shizuku, HyperOS, game optimization, scrcpy (con versiones mínimas), keymappers |
| **Linux** | 2 | System administration, kernel tuning |
| **React** | 4 | React patterns, Vite, Tailwind v4, PWA |
| **Git** | 1 | Daily commands, GitHub CLI |
| **Node** | 1 | npm, package.json |
| **Shell** | 1 | Bash scripting, awk, sed |
| **Tools** | 1 | CodeGraph — grafo de código, comandos, MCP, troubleshooting |
| **Vision** | 1 | VLM local (Ollama) — modelos, RAM, versiones |

## Skills (23 en disco)

Cada skill tiene `SKILL.md` (documentación humana) + `skill.yaml` (manifest
machine-readable validado por `scripts/skill-lint.sh` — gate activo en CI).
`buffy-router.sh` las descubre por sus `triggers` sin hardcodear rutas.

| Grupo | Skills |
|---|---|
| **Android** | android-adb, android-agent, android-game-opt, android-project-setup, hyperos-hardening, scrcpy-freefire, shizuku-rikka, xiaomi-adb-tricks |
| **Web** | form-filler, image-analyzer |
| **Framework v4** | exploratory_validation_v4, filter_heuristics_v4, integration_templates_v4, cross_validation_v4, search_criteria_v4 |
| **Code & research** | code-search, context7 |
| **Frontend** | vite, tailwind-design-system, typescript-advanced-types, vercel-react-best-practices |
| **Operación** | modo-autonomo, vision-adapter |

---

## License

[MIT](LICENSE) &mdash; feel free to use, modify, and share.

---

<p align="center">
  <sub>Built with ♥ for better AI-assisted development.</sub>
</p>

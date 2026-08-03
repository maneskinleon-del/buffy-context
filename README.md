# Buffy Context

> **Persistent AI memory, structured knowledge base, and specialized agents for AI coding assistants.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/maneskinleon-del/buffy-context?style=social)](https://github.com/maneskinleon-del/buffy-context)
[![GitHub last commit](https://img.shields.io/github/last-commit/maneskinleon-del/buffy-context)](https://github.com/maneskinleon-del/buffy-context/commits/main)

---

## Overview

Buffy Context solves a fundamental problem with AI coding assistants: **every session starts from zero**.

This repository provides the infrastructure for an AI agent to maintain persistent context across sessions, access structured technical knowledge, and automatically specialize based on the project and stack being worked on.

### What's included

| Component | Purpose |
|---|---|
| **Memory persistence** | Protocol for loading/saving session context so the AI never starts blank |
| **Knowledge base** | 16 files of curated technical reference across 6 categories |
| **Android Agent** | Dedicated skill that auto-detects Android projects and activates relevant tools |
| **Detection scripts** | Shell scripts for system snapshots and Android diagnostics |
| **Self-diagnostics** | doctor --json detecta drift, repair corrige lo seguro, agent orquesta el ciclo |
| **Conditional loading** | Token-aware protocol: carga solo lo necesario según el tema |
| **Auto-pruning** | SESION.md mantiene máximo 5 entradas, el resto se archiva |

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
│   ├── SYSTEM.md                      # ⚠️ DEPRECATED → ver INFO-core.md
│   ├── SYSTEM_FULL.md                 # ⚠️ DEPRECATED → ver INFO-full.md
│   └── CHANGELOG.md                   # Change history
│
├── Knowledge/                         # Structured technical reference
│   ├── Android/
│   │   ├── ADB.md                     # ADB commands
│   │   ├── Shizuku.md                 # Shizuku + rish
│   │   ├── HyperOS.md                 # Xiaomi debloat & privacy
│   │   ├── GameOptimization.md        # Gaming performance tuning
│   │   ├── scrcpy.md                  # scrcpy profiles & diagnosis
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
│   └── Shell/
│       └── Shell.md                   # Variables, awk, sed, trap
│
├── .agents/skills/                    # AI agent skill definitions
│   ├── android-agent/                 # Android detection & automation
│   ├── android-adb/                   # Comandos ADB generales
│   ├── android-game-opt/              # Optimización de juegos vía Shizuku/ADB
│   ├── hyperos-hardening/             # Blindaje contra restricciones MIUI/HyperOS
│   ├── scrcpy-freefire/               # Mirroring y keymappers para Free Fire
│   ├── shizuku-rikka/                 # Escalación sin root (Shizuku + rish)
│   ├── code-search/                   # Búsqueda portable de código entre asistentes IA
│   ├── search_criteria_v4/            # Genera consultas de búsqueda estructuradas
│   └── vision-adapter/                # Visión/VLM local (Ollama) para imágenes
│
├── scripts/                           # Utility scripts
│   ├── buffy-context.sh               # System snapshot generator
│   ├── buffy-doctor.sh                # Auditoría de salud del ecosistema (--json)
│   ├── buffy-repair.sh                # Aplica fixes AUTO_SAFE y verifica
│   ├── buffy-agent.sh                 # Orquestador: doctor → repair → verify → load
│   ├── buffy-router.sh                # Carga condicional de contexto (--json)
│   ├── android-detect.sh              # Android project & device diagnosis
│   └── kimi_vision.js                 # Detección de permisos con visión IA (Kimi K3)
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
# Creates ai-context/SNAPSHOT.md with real-time system state
```

### 4. Run Android diagnosis (if device connected)

```bash
bash scripts/android-detect.sh        # Full report
bash scripts/android-detect.sh --quick # One-line summary
bash scripts/android-detect.sh --watch # Live monitoring
```

---

## Usage with AI agents

### For Buffy (Freebuff)

Buffy reads these files automatically at session start following the protocol in `ai-context/LOAD_CONTEXT.md`:

1. `ai-context/CONTINUE.md` — what was being worked on
2. `ai-context/INFO-core.md` — user profile and stack
3. `ai-context/SNAPSHOT.md` — system state (regenerated each session)

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
| **Android** | 6 | ADB, Shizuku, HyperOS, game optimization, scrcpy, keymappers |
| **Linux** | 2 | System administration, kernel tuning |
| **React** | 4 | React patterns, Vite, Tailwind v4, PWA |
| **Git** | 1 | Daily commands, GitHub CLI |
| **Node** | 1 | npm, package.json |
| **Shell** | 1 | Bash scripting, awk, sed |

---

## License

[MIT](LICENSE) &mdash; feel free to use, modify, and share.

---

<p align="center">
  <sub>Built with ♥ for better AI-assisted development.</sub>
</p>

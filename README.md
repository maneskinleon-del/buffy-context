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
│   ├── android-agent/
│   │   └── SKILL.md                   # Android detection & automation
│   └── android-project-setup/
│       ├── SKILL.md                   # Build → install → permisos → launch
│       ├── scripts/                   # check_device, build_install, grant_permissions
│       └── references/                # Dispositivos y permisos del usuario
│
├── scripts/                           # Utility scripts
│   ├── buffy-context.sh               # System snapshot generator
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

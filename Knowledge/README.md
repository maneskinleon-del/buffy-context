# 📚 Knowledge Base — mangonz

> Base de conocimiento estructurada para consulta rápida por agentes IA.
> Contenido extraído y resumido de skills, proyectos y experiencia acumulada.
> Actualizado: 2026-08-03

---

## 📂 Categorías

```
Knowledge/
├── AI/                     → Modelos LLM vía Hugging Face
│   └── Kimi-K3.md          → Kimi K3: acceso API, MCP vs modelo, casos de uso
│
├── Android/                → ADB, Shizuku, HyperOS, juegos, scrcpy, keymappers
│   ├── ADB.md              → Comandos ADB generales (dispositivos, apps, permisos)
│   ├── Shizuku.md          → Shizuku + rish (privilegios sin root)
│   ├── HyperOS.md          → Hardening HyperOS/Xiaomi (debloat, privacidad)
│   ├── GameOptimization.md → Optimización de juegos Android (CPU, GPU, thermal)
│   ├── scrcpy.md           → scrcpy + Free Fire (diagnóstico, perfiles)
│   ├── Keymappers.md       → GG Mouse Pro, Mantis, Panda Mouse, Octopus
│   └── NubiaLab.md         → Laboratorio ZTE Nubia (setup, purga, qué no tocar)
│
├── Linux/                  → Arch, bspwm, systemd, picom, kernel
│   ├── System.md           → Gestión del sistema (pacman, systemd, WM, compositor)
│   └── Kernel.md           → Kernel Linux (parámetros, módulos, rendimiento)
│
├── React/                  → React, TypeScript, Vite, Tailwind, PWA
│   ├── Vite.md             → Vite (config, plugins, build)
│   ├── Tailwind.md         → Tailwind CSS v4 (design system, utilidades)
│   └── PWA.md              → Progressive Web Apps (manifest, service worker)
│
├── Git/                    → Git, GitHub CLI
│   └── Commands.md         → Comandos git frecuentes + gh CLI
│
├── Node/                   → Node.js, npm
│   └── Node.md             → Node.js, npm global, package management
│
└── Shell/                  → Bash/Zsh scripting
    └── Shell.md            → Shell scripting (bash, zsh, awk, sed)
```

---

## 🧠 Cómo usar esta Knowledge base

Para **agentes IA**: cuando necesites información sobre un tema:

1. Busca primero en `Knowledge/` la categoría relevante
2. Si no está o necesitas más detalle, consulta las skills en `.agents/skills/`
3. Si aún falta, usa búsqueda web o documentación oficial

Para **mangonz**: cuando aprendas algo nuevo y quieras guardarlo:

1. Identifica la categoría correcta
2. Agrega o modifica el archivo `.md` correspondiente
3. Mantén el formato conciso y orientado a referencia rápida

---

## 🔗 Relación con skills

| Knowledge file | Skill relacionada |
|---|---|
| `Android/ADB.md` | `.agents/skills/android-adb/` |
| `Android/Shizuku.md` | `.agents/skills/shizuku-rikka/` |
| `Android/HyperOS.md` | `.agents/skills/hyperos-hardening/` |
| `Android/GameOptimization.md` | `.agents/skills/android-game-opt/` |
| `Android/scrcpy.md` | `.agents/skills/scrcpy-freefire/` |
| `Android/NubiaLab.md` | `.agents/skills/android-adb/` · `.agents/skills/scrcpy-freefire/` · `.agents/skills/shizuku-rikka/` |
| `React/Vite.md` | `.agents/skills/vite/` |
| `React/Tailwind.md` | `.agents/skills/tailwind-design-system/` |
| `React/PWA.md` | Proyectos `pwa_securguard`, `widgetos` |
| `Shell/Shell.md` | `.agents/skills/modo-autonomo/` |
| `AI/Kimi-K3.md` | — (referencia, sin skill aún) |

> Las skills son instrucciones **ejecutables** para el agente.
> Knowledge/ es **referencia** para consulta rápida.

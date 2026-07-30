# Buffy Context — AI Memory & Knowledge

> Sistema de memoria persistente, base de conocimiento y agentes especializados para el asistente de IA Buffy (Freebuff).

## ¿Qué es esto?

Este repositorio contiene todo lo necesario para que un agente de IA tenga **contexto persistente entre sesiones** y **conocimiento técnico estructurado** sobre tu stack de desarrollo.

Creado y mantenido por Buffy para el usuario **@mangonz**.

## Estructura

```
buffy-context/
├── ai-context/                  → Memoria persistente (protocolo, handoff, sesiones)
│   ├── LOAD_CONTEXT.md          → Protocolo de carga/cierre para agentes IA
│   ├── CONTINUE.md              → Handoff entre sesiones (lo último que se hizo)
│   ├── INFO-core.md             → Stack, preferencias, proyectos del usuario
│   ├── INFO-full.md             → Perfil detallado del usuario
│   ├── SESION.md                → Bitácora de sesiones
│   ├── PROJECTS.md              → Proyectos activos
│   ├── AGENTS.md                → Configuración de agentes
│   ├── SYSTEM.md / SYSTEM_FULL.md → Info del sistema
│   ├── CHANGELOG.md             → Historial de cambios
│   └── v4_MANIFIESTO.md         → Manifiesto de la v4
│
├── Knowledge/                   → Base de conocimiento técnico
│   ├── Android/
│   │   ├── ADB.md               → Comandos ADB esenciales
│   │   ├── Shizuku.md           → Shizuku + rish reference
│   │   ├── HyperOS.md           → Debloat y privacidad Xiaomi
│   │   ├── GameOptimization.md  → Optimización para juegos
│   │   ├── scrcpy.md            → scrcpy commandos y perfiles
│   │   └── Keymappers.md        → GG Mouse, Mantis, Panda, Octopus
│   ├── Linux/
│   │   ├── System.md            → Arch, bspwm, picom, systemd
│   │   └── Kernel.md            → Parámetros, módulos, sysctl
│   ├── React/
│   │   ├── React.md             → Patrones TSX, hooks, performance
│   │   ├── Vite.md              → Config, plugins, aliases, PWA
│   │   ├── Tailwind.md          → v4, utilidades, dark mode
│   │   └── PWA.md               → Manifest, service worker
│   ├── Git/
│   │   └── Commands.md          → Flujo diario, gh CLI
│   ├── Node/
│   │   └── Node.md              → npm global, package.json
│   └── Shell/
│       └── Shell.md             → Variables, awk, sed, trap
│
├── .agents/skills/
│   └── android-agent/
│       └── SKILL.md             → Agente Android dedicado
│
├── scripts/
│   ├── buffy-context.sh         → Genera SNAPSHOT.md del sistema
│   └── android-detect.sh        → Diagnóstico automático Android
│
├── INSTALL.md                   → Instrucciones de setup
└── .gitignore                   → Ignora SNAPSHOT.md y archivos generados
```

## Stack del usuario

| Componente | Valor |
|---|---|
| SO | EndeavourOS (Arch Linux) |
| WM | bspwm (X11) |
| Terminal | Alacritty |
| Shell | Zsh 5.9.2 |
| Editor | VS Code OSS |
| Node | v26.4.0 · npm 11.18.0 |
| Android | ZTE Nubia Z2352N · Android 13 · Unisoc T820 |
| ADB | Conectado vía USB |

## Cómo usar

Cada sesión con Buffy (u otro agente que soporte el protocolo):

1. **Al inicio**: leer `ai-context/CONTINUE.md` → `ai-context/INFO-core.md` → regenerar `SNAPSHOT.md`
2. **Durante**: cargar skills y knowledge según el proyecto/stack detectado
3. **Al cierre**: actualizar `CONTINUE.md` y `SESION.md`

Ver `ai-context/LOAD_CONTEXT.md` para el protocolo detallado.

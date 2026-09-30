# 🖥️ INFO-CORE — (base genérico; tu instancia vive en INFO-core.local.md)

> Plantilla del contexto mínimo para cualquier agente IA. Este archivo es el
> **base tracked** del Patrón B (C4-B): es válido como instancia por sí solo
> (pasa lint/doctor en un clone fresco). El operador mantiene su perfil real
> en `INFO-core.local.md` (gitignored) — si existe, los consumidores lo
> usan con AUTORIDAD TOTAL. Rellena o clona desde tu instancia anterior.

## Sistema
- OS: (distribución y versión, ej. EndeavourOS/Debian/Termux)
- Shell: (zsh/bash/fish + framework si aplica)
- Terminal: (emulador + paleta)
- Editor: (editor principal)
- Locale: (locale del sistema)

## Hardware
- CPU: (modelo)
- GPU: (integrada/dedicada)
- RAM: (cantidad)

## Reglas personales (no negociables)
```yaml
git-auth: (mecanismo de autenticación git, ej. gh auth git-credential)
reglas:
  - (una por línea — preferencias del operador que ningún agente debe romper)
```

## Estructura de proyectos activos
- (ruta relativa → nombre/descripción breve, una línea por proyecto)

## Cuándo leer INFO-full.md
- Detalle histórico, hardware completo, changelog o checklist de capacidades → `INFO-full.md`.

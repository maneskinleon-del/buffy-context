---
version: 1.0
updated: 2026-09-30
---

# AGENTS — base genérico

> Plantilla de notas técnicas de agentes previos (Patrón B, C4-B). El base es
> válido como instancia; tu contenido real vive en `AGENTS.local.md`
> (gitignored) — si existe, los consumidores lo usan con AUTORIDAD TOTAL.

## Antes de empezar

- Lee `ai-context/CONTINUE.md` si existe (handoff de la sesión anterior).
- Verifica el estado del repo antes de asumir premisas: `[orig]/[verificado]`.

## Glosario — qué archivo leer, cuándo, y para qué

| Archivo | Cuándo | Para qué |
|---|---|---|
| `INFO-core.md` | Siempre | Contexto base del sistema |
| `CONTINUE.md` | Al iniciar sesión | Handoff entre sesiones |
| `PROJECTS.md` | Tareas de un proyecto | Detalle por proyecto |

## Notas técnicas importantes

- (Notas técnicas de agentes previos — una por línea. En la instancia real:
  decisiones tomadas, gotchas del entorno, convenciones del operador.)

## Reglas de eficiencia (agentes de coding en general)

- Prefiere ediciones mínimas sobre reescrituras.
- Verifica empíricamente antes de declarar éxito (tests, build, salida real).

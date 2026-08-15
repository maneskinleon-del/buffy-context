# v4 Framework — Manifiesto de Sistematización

> **Versión:** 4.0.0
> **Fecha:** Julio 21, 2026
> **Propósito:** Formalizar el proceso de extracción, consulta y validación de información desde fuentes externas en el contexto de desarrollo.

---

## Arquitectura del Sistema v4

```
┌─────────────────────────────────────────────────────┐
│               exploratory_validation_v4              │
│              (Orquestador Principal)                 │
├─────────┬──────────┬──────────────┬─────────────────┤
│search   │filter    │integration   │cross_validation │
│_criteria│_heuristics│_templates    │_v4              │
│_v4      │_v4       │_v4           │                 │
└─────────┴──────────┴──────────────┴─────────────────┘
```

## Skills Creados

| Skill | Rol | Archivo |
|-------|-----|---------|
| **exploratory_validation_v4** | Orquestador — coordina las 4 fases, produce diagnóstico consolidado | `.agents/skills/exploratory_validation_v4/SKILL.md` |
| **search_criteria_v4** | Fase 1 — Genera consultas semánticas y sintácticas estructuradas | `.agents/skills/search_criteria_v4/SKILL.md` |
| **filter_heuristics_v4** | Fase 2 — Filtra fuentes por vigencia, autoridad, consistencia, especificidad | `.agents/skills/filter_heuristics_v4/SKILL.md` |
| **integration_templates_v4** | Fase 3 — Adapta código externo al proyecto con marcado de incertidumbre | `.agents/skills/integration_templates_v4/SKILL.md` |
| **cross_validation_v4** | Fase 4 — Contrasta fuentes primarias/secundarias, produce nivel de confianza | `.agents/skills/cross_validation_v4/SKILL.md` |

## Cómo Activar Modo v4

En futuras sesiones, los skills serán cargables automáticamente vía:

```
skill: exploratory_validation_v4
params:
  depth: normal        # rápido | normal | profundo
  languages: [es, en]
  max_sources: 5
  time_range: 2y
  output_format: compacto  # compacto | expandido
```

### Disparadores

- **Explícito:** Usuario dice "modo v4", "v4", "diagnóstico exploratorio"
- **Implícito:** Problema con restricciones no evidentes, APIs desconocidas, comportamiento inesperado
- **Automático:** Cuando se activa modo v4, toda consulta externa usa este framework

### Contrato de Salida (modo compacto)

```
DIAGNÓSTICO
═══════════
{síntesis del problema y hallazgo principal}

ACCIONES
════════
1. {acción concreta}
2. {acción concreta}

REFERENCIAS
═══════════
• [{alta|media|baja}] {fuente} — {hallazgo clave}
  {url}

CONFIANZA: {alta|media|baja}
══════════
{razón del nivel de confianza}
```

## Registro

Los skills están registrados en `/home/mangonz/skills-lock.json` con sourceType `local`. En la próxima sesión aparecerán en la lista de skills precargados.

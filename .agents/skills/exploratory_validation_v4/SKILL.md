---
name: exploratory_validation_v4
description: "Orquestador del framework v4: coordina las 4 fases (search_criteria, filter_heuristics, integration_templates, cross_validation) y produce un diagnóstico consolidado con nivel de confianza."
version: 4.0.0
author: "v4 framework"
---

# exploratory_validation_v4 — Orquestador del Framework v4

## Propósito

Coordinar la validación exploratoria de información externa en 4 fases y producir un diagnóstico consolidado, cuando el problema tiene restricciones no evidentes o APIs desconocidas.

## Disparadores

- **Explícito:** el usuario dice "modo v4", "v4", "diagnóstico exploratorio"
- **Implícito:** problema con restricciones no evidentes, APIs desconocidas, comportamiento inesperado
- **Automático:** cuando se activa modo v4, toda consulta externa usa este framework

## Flujo (4 fases)

```
exploratory_validation_v4 (orquestador)
├── search_criteria_v4          → Fase 1: genera consultas semánticas y sintácticas
├── filter_heuristics_v4        → Fase 2: filtra fuentes (vigencia, autoridad, consistencia, especificidad)
├── integration_templates_v4    → Fase 3: adapta código externo con marcado de incertidumbre
└── cross_validation_v4         → Fase 4: contrasta fuentes primarias/secundarias → nivel de confianza
```

## Parámetros

```yaml
skill: exploratory_validation_v4
params:
  depth: normal        # rápido | normal | profundo
  languages: [es, en]
  max_sources: 5
  time_range: 2y
  output_format: compacto  # compacto | expandido
```

## Contrato de Salida (modo compacto)

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

## Reglas

1. Cada fase delega en su skill correspondiente; el orquestador no reimplementa.
2. Si una fase no aplica (p. ej. no hay código externo que integrar), documentarlo y continuar.
3. El nivel de confianza final lo produce `cross_validation_v4`, no el orquestador.

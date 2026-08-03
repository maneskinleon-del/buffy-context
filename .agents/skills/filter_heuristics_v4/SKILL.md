---
name: filter_heuristics_v4
description: "Fase 2 del framework v4: filtra fuentes candidatas por vigencia, autoridad, consistencia y especificidad. Recibe consultas de search_criteria_v4 y produce una lista priorizada de fuentes."
version: 4.0.0
author: "v4 framework"
---

# filter_heuristics_v4 — Filtrado de Fuentes

## Propósito

Reducir la lista de fuentes candidatas a las realmente útiles, aplicando 4 heurísticas ponderadas. Es la fase 2 del framework v4.

## Entrada

Recibe del orquestador (`exploratory_validation_v4`) las consultas generadas por `search_criteria_v4`:

```yaml
queries:
  - priority: 1
    type: semantic
    query: "Android TYPE_APPLICATION_OVERLAY no se muestra desde Service"
  - priority: 2
    type: syntactic
    query: "WindowManager.addView TYPE_APPLICATION_OVERLAY Service API level 34"
```

## Heurísticas de filtrado

| Heurística | Pregunta guía | Peso |
|-----------|---------------|------|
| **Vigencia** | ¿Es reciente / compatible con la versión del proyecto? | 0.4 |
| **Autoridad** | ¿Es fuente oficial (docs, maintainers, spec) o reputada? | 0.3 |
| **Consistencia** | ¿Coincide con otras fuentes independientes? | 0.2 |
| **Especificidad** | ¿Ataca el caso concreto (versión, stack, síntoma)? | 0.1 |

## Reglas de decisión

1. **Descartar** fuentes sin vigencia (obsoletas para la versión del proyecto) aunque sean autoritativas.
2. **Descartar** fuentes sin especificidad (genéricas que no tocan el síntoma).
3. **Priorizar** fuentes que combinan autoridad + especificidad (docs oficiales del componente exacto).
4. Si dos fuentes son contradictorias y ambas parecen válidas, **no filtrar**: pasan a `cross_validation_v4` marcadas como conflicto.

## Salida

```yaml
sources:
  - url: "https://developer.android.com/reference/..."
    authority: alta
    recency: "API 34"
    specificity: alta
    conflict_with: []          # urls con las que contradice (si hay)
    include: true
```

## Reglas

1. El filtrado es **exclusión por evidencia**, no por preferencia personal.
2. Toda exclusión se justifica con la heurística que la motiva.
3. Los conflictos se reportan, no se resuelven aquí.

---
name: cross_validation_v4
description: "Fase 4 del framework v4: contrasta fuentes primarias vs secundarias (y los conflictos reportados por filter_heuristics_v4) y produce el nivel de confianza final del diagnóstico."
version: 4.0.0
author: "v4 framework"
---

# cross_validation_v4 — Contraste de Fuentes y Confianza

## Propósito

Contrastar fuentes **primarias** (docs oficiales, código fuente, specs) contra **secundarias** (blogs, Stack Overflow, resúmenes) y resolver los conflictos que `filter_heuristics_v4` no pudo filtrar. Produce el **nivel de confianza** final del diagnóstico.

## Entrada

- Fuentes filtradas por `filter_heuristics_v4`.
- Conflictos reportados (fuentes contradictorias).
- Asunciones marcadas por `integration_templates_v4` pendientes de verificación.

## Clasificación de fuentes

| Tipo | Ejemplos | Peso en la confianza |
|------|----------|----------------------|
| **Primaria** | docs oficiales, código fuente, specs, maintainers | alta |
| **Secundaria** | blogs, SO, resúmenes, cursos | baja |

## Reglas de contraste

1. **Primaria vs primaria** que coinciden → confianza **alta**.
2. **Primaria + secundaria consistente** → confianza **media**.
3. **Solo secundarias** o **primarias contradictorias** → confianza **baja**, con la discrepancia documentada.
4. Un conflicto no resuelto **baja la confianza**, no se oculta.

## Salida

```
CONFIANZA: {alta|media|baja}
══════════
{razón del nivel de confianza}
• [alta] {fuente primaria} — {hallazgo}
• [baja] {fuente secundaria} — {hallazgo, contradictorio con X}
```

## Reglas

1. La confianza es **por hallazgo** y **global** (la global es el mínimo de las parciales).
2. Si no hay fuentes primarias, el máximo posible es **media**.
3. Reportar la discrepancia exacta en los conflictos, nunca solo "hay conflicto".

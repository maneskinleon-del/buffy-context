---
name: integration_templates_v4
description: "Fase 3 del framework v4: adapta código/documentación externa al proyecto con marcado explícito de incertidumbre. Nunca copia código sin adaptar."
version: 4.0.0
author: "v4 framework"
---

# integration_templates_v4 — Adaptación con Marcado de Incertidumbre

## Propósito

Integrar código, patrones o documentación externa (validados por `filter_heuristics_v4`) al proyecto, **marcando explícitamente** todo lo que no está verificado en el contexto real del proyecto.

## Entrada

Recibe las fuentes filtradas por `filter_heuristics_v4`:

```yaml
sources:
  - url: "https://developer.android.com/..."
    include: true
    authority: alta
```

## Reglas de adaptación

1. **Nunca pegar código externo sin adaptar** a las convenciones del proyecto (nombres, imports, estructura).
2. **Marcar incertidumbre** con comentarios explícitos en el código integrado:

```ts
// [v4-INCERTO] este parámetro depende de la versión de la librería (ver fuente X)
const opts = { windowType: TYPE_APPLICATION_OVERLAY };
```

3. **Registrar cada asunción**: qué se asumió, por qué, y qué hay que verificar en runtime.
4. Si el código externo depende de APIs no confirmadas para la versión del proyecto, dejarlo **detrás de un flag o guard** con el marcado de incertidumbre.

## Marcadores de incertidumbre

| Marcador | Significado |
|----------|-------------|
| `[v4-INCERTO]` | No verificado en este proyecto (versión, API, entorno) |
| `[v4-VERIFICAR]` | Hay que confirmar en runtime/build antes de producción |
| `[v4-CONFLICTO]` | Fuentes contradictorias — requiere `cross_validation_v4` |

## Salida

- Código adaptado con marcadores.
- Lista de asunciones pendientes de verificación (para `cross_validation_v4`).

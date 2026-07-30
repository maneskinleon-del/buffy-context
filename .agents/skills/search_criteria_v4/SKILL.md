---
name: search_criteria_v4
description: "Genera consultas semánticas y sintácticas estructuradas para búsqueda de información técnica. Recibe contexto del problema y produce consultas priorizadas por probabilidad de recall."
version: 4.0.0
author: "v4 framework"

---

# search_criteria_v4 — Criterios de Búsqueda Estructurada

## Propósito

Transformar un problema de desarrollo en consultas de búsqueda precisas, maximizando la probabilidad de encontrar documentación relevante a la primera.

## Entrada

Recibe del skill orquestador (`exploratory_validation_v4`):

```yaml
context:
  language: "kotlin"           # Lenguaje de programación
  framework: "android"          # Framework / plataforma
  version: "34"                 # Versión específica (compileSdk, api level, etc.)
  constraints:                  # Restricciones conocidas
    - "targetSdk=34"
    - "minSdk=24"
  symptom: "overlay no aparece" # Síntoma o problema
  stack_trace: ""               # Stack trace si existe
  environment:                  # Entorno de ejecución
    os: "android"
    device: "Nubia ZTE"
    rom: "NubiaUI"
```

## Fases de Generación de Consultas

### 1. Consulta Semántica (intención del problema)

Formular la pregunta en lenguaje natural, capturando la intención sin ruido técnico.

**Patrón:** `{lenguaje} {framework} {síntoma} {restricción}`

**Ejemplo:** `Android TYPE_APPLICATION_OVERLAY no se muestra desde Service`

### 2. Consulta Sintáctica (API específica)

Formular con nombres exactos de clases, métodos, parámetros.

**Patrón:** `{API} {método} {parámetro} {valor} {versión}`

**Ejemplo:** `WindowManager.addView TYPE_APPLICATION_OVERLAY Service context API 34`

### 3. Consulta por Error (si aplica)

Si hay mensaje de error o stack trace, extraer la línea más específica.

**Patrón:** `{mensaje_error} {lenguaje} {framework}`

**Ejemplo:** `"Unable to add window -- permission denied for window type" Android TYPE_APPLICATION_OVERLAY`

### 4. Consulta por Alternativa

Cuando la vía principal falla, buscar workarounds documentados.

**Patrón:** `{API} {workaround} {alternativa} {lenguaje}`

**Ejemplo:** `WindowManager overlay workaround Service Android TYPE_APPLICATION_OVERLAY alternative`

## Priorización de Consultas

Las consultas se priorizan por probabilidad de recall:

| Prioridad | Tipo | Peso |
|-----------|------|------|
| 1 | Semántica + restricción | 0.9 |
| 2 | Sintáctica exacta | 0.8 |
| 3 | Por error | 0.7 |
| 4 | Alternativa / workaround | 0.5 |

## Salida

```json
{
  "queries": [
    {
      "priority": 1,
      "type": "semantic",
      "query": "Android TYPE_APPLICATION_OVERLAY no se muestra desde Service",
      "weight": 0.9,
      "target": ["developer.android.com", "stackoverflow.com", "github.com"]
    },
    {
      "priority": 2,
      "type": "syntactic",
      "query": "WindowManager.addView TYPE_APPLICATION_OVERLAY Service API level 34",
      "weight": 0.8,
      "target": ["developer.android.com"]
    }
  ],
  "context_hash": "a1b2c3d4e5"
}
```

## Reglas

1. **Preferir específico sobre genérico.** Siempre incluir la versión/framework/lenguaje explícito.
2. **Descartar consultas obvias.** Si el problema es trivial, generar 1-2 consultas máximo.
3. **Idioma:** Generar consultas en los idiomas solicitados (default: es, en).

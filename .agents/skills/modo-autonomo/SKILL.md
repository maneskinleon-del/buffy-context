---
name: modo-autonomo
description: "Protocolo de operación autónoma: cuando el usuario delega autonomía, el agente decide por sí mismo con verificación de hechos, validación completa y reporte final. Basado en el flujo real de esta sesión."
version: 1.0.0
author: "mangonz"
---

# modo-autonomo — Operación Autónoma

## Propósito

Definir cómo opera el agente cuando el usuario le delega autonomía (p. ej. "trabaja de manera autónoma", "tú decides"). Evita preguntar lo obvio, pero nunca actúa sin verificar.

## Cuándo se activa

- El usuario delega explícitamente la decisión ("toma la mejor decisión", "trabaja autónomo").
- La tarea tiene una decisión con alternativa clara y el usuario ya delegó.

## Protocolo (verificado en esta sesión)

1. **Reunir contexto primero**: leer los archivos relevantes y verificar hechos ANTES de decidir.
2. **Decidir con evidencia**: si una recomendación externa contradice un hecho verificado, el hecho gana (p. ej. "modo local de visión" no existe: verificado en el código).
3. **Validar todo cambio**:
   - `bash scripts/tests/run-tests.sh --quick` (54 OK esperado)
   - `bash scripts/buffy-doctor.sh --json` (sin drift nuevo)
4. **No introducir drift**: en docs, nunca escribir patrones `skills/<nombre>` de skills inexistentes.
5. **Commit + push** con el hook corriendo la suite como prueba final; árbol limpio al terminar.
6. **Reportar**: qué se hizo, qué se validó, qué quedó pendiente (si algo requiere decisión humana, decirlo explícito).

## Reglas de seguridad

- Las acciones irreversibles o de producción requieren confirmación explícita.
- `repair --auto` solo aplica fixes AUTO_SAFE; REVIEW_REQUIRED → decisión humana.
- El sandbox de la suite protege el repo real (solo lectura fuera de sandbox).

## Salida

Siempre terminar con un resumen: cambios aplicados, validaciones verdes, y el estado del árbol git.

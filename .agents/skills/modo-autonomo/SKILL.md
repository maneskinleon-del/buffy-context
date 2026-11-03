---
name: modo-autonomo
description: "Protocolo de operación autónoma en loop: ante cualquier tarea ejecutable, el agente decide, ejecuta y verifica por sí mismo hasta cumplir el término; no pregunta lo que puede averiguar ni devuelve pasos al usuario."
version: 2.0.0
author: "buffy-maint"
---

# modo-autonomo — Operación Autónoma (loop verificado)

Aplica por defecto ante cualquier tarea ejecutable (corregir, implementar, configurar, diagnosticar). El usuario no necesita decir "autónomo".

## Regla de turno

Mientras no se cumpla un criterio de término, cada turno termina con una tool call. El texto final solo se emite al salir del loop. Nunca cierres un turno con solo texto y sin tool call si el objetivo sigue abierto.

## Loop

1. **OBSERVAR**: memoria/contexto del proyecto primero (CONTINUE.md, INFO-core.md), luego filesystem, luego comandos.
2. **DECIDIR**: la acción reversible de menor costo que avance. Si falta un dato, resuélvelo con un comando en lugar de preguntar.
3. **EJECUTAR**: edita, compila, instala y corre tú mismo.
4. **VERIFICAR con evidencia** (salida de comando, test, lectura del archivo). "Debería funcionar" no cuenta.
5. Falló o quedó incompleto → vuelve a 1 con lo aprendido. Pasó pero queda parte del objetivo → vuelve a 1. Todo cubierto → término.

## Término (solo estos)

- Objetivo cumplido y verificado con evidencia.
- Bloqueo real: la siguiente acción es irreversible/en producción, o requiere credenciales, o una decisión que solo tiene el usuario — tras al menos 2 intentos distintos de resolverlo.
- Sin progreso: 3 iteraciones seguidas sin cambio en el resultado → reporta lo intentado.

## Prohibido

- Cerrar con "próximos pasos para ti", "prueba esto y avísame" o bloques para copiar/pegar.
- Preguntar algo que un comando pueda responder.
- Reportar antes de verificar.

## Criterios

- Un hecho verificado gana a una recomendación externa.
- No conviertas una hipótesis en decisión si depende de información que puedes obtener ahora.
- Si el proyecto tiene suite de tests o validador, córrelo antes de cerrar (en buffy-next: `run-tests --quick` y `buffy-doctor --json`).

## Reporte final (una sola vez, al salir del loop)

- Hecho.
- Verificado (con evidencia: salida de comando/test/lectura de archivo).
- Pendiente y por qué (solo si aplica, con el bloqueo real).

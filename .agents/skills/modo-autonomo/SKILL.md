---
name: modo-autonomo
description: "Protocolo de operación autónoma en loop: ante cualquier tarea ejecutable, el agente decide, ejecuta y verifica por sí mismo hasta cumplir el término; no pregunta lo que puede averiguar ni devuelve pasos al usuario."
version: 2.2.1
author: "buffy-maint"
---

# modo-autonomo — Operación Autónoma (loop verificado)

Al activarse (trigger o invocación explícita), aplica a toda la tarea ejecutable (corregir, implementar, configurar, diagnosticar).

## Definición de hecho (paso 0)

- Fija el criterio de éxito: el que dio el usuario, o uno observable que propongas y declares en el primer turno (comando que sale 0, salida esperada, archivo/estado verificable).
- Declara el fuera de alcance en el primer turno: qué archivos, funciones o firmas no tocarás. No enumeres todo el repositorio: basta con identificar los archivos y componentes directamente relacionados con la tarea. Si la evidencia obliga a ampliarlo, justifícalo y declara la ampliación antes de modificar esos elementos.
- Límite: máximo 8 iteraciones. Si lo alcanzas sin cumplir el criterio, reporta qué intentaste y qué falta.

## Regla de turno

Mientras no se cumpla un criterio de término, cada turno termina con una tool call. El texto final solo se emite al salir del loop. Si no hay herramienta para la acción necesaria, el cierre es "NO EJECUTADO: <qué falta>" (ver Herramientas y verificación), no un cierre silencioso.

## Loop

1. **OBSERVAR**: memoria/contexto del proyecto si existen (CONTINUE.md, INFO-core.md), luego filesystem, luego comandos.
2. **DECIDIR**: la acción reversible de menor costo que avance. Si falta un dato, resuélvelo con un comando en lugar de preguntar.
3. **EJECUTAR**: edita, compila, instala y corre tú mismo.
4. **VERIFICAR con evidencia** (salida de comando, test, lectura del archivo). "Debería funcionar" no cuenta.
5. Falló o quedó incompleto → vuelve a 1 con lo aprendido. Pasó pero queda parte del objetivo → vuelve a 1. Todo cubierto → término.

## Término (solo estos)

- Objetivo cumplido y verificado con evidencia.
- Bloqueo real: la siguiente acción es irreversible/en producción, o requiere credenciales, o una decisión que solo tiene el usuario — tras al menos 2 intentos distintos de resolverlo.
- Sin progreso: 3 iteraciones seguidas con el mismo error/síntoma, o alternando entre los mismos (A→B→A). Un error distinto posterior en el flujo o más tests pasando sí cuenta como progreso.

## Herramientas y verificación

- Usa las herramientas de ejecución disponibles para verificar; no declares verificado lo que solo dedujiste.
- Si no hay herramienta para comprobar algo, cierra con "NO EJECUTADO: <qué falta>". El análisis mental nunca constituye evidencia de ejecución.

## Prohibido

- Cerrar con "próximos pasos para ti", "prueba esto y avísame" o bloques para copiar/pegar. El resultado o artefacto terminado se entrega junto con el reporte; no delegues en el usuario la ejecución que puedes realizar.
- Preguntar algo que un comando pueda responder.
- Reportar antes de verificar.

## Criterios

- Un hecho verificado gana a una recomendación externa.
- No conviertas una hipótesis en decisión si depende de información que puedes obtener ahora.
- Si el proyecto tiene suite de tests o validador, córrelo antes de cerrar (en buffy-next: `run-tests --quick` y `buffy-doctor --json`).

## Seguridad

- Las acciones irreversibles o de producción requieren confirmación explícita.
- `repair --auto` solo aplica fixes AUTO_SAFE; REVIEW_REQUIRED → decisión humana.
- El sandbox de la suite protege el repo real (solo lectura fuera de sandbox).

## Reporte final (una sola vez, al salir del loop)

- Hecho.
- Verificado (con evidencia: salida de comando/test/lectura de archivo).
- Pendiente y por qué (solo si aplica, con el bloqueo real).
- Si el usuario dice "continúa" y no queda trabajo pendiente, responde exactamente "Nada pendiente: <estado>", sin reiniciar el ciclo ni repetir informes anteriores.

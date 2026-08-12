---
name: idea-a-spec
description: >
  Activa cuando el mensaje del usuario es una idea vaga, un problema o un
  objetivo abierto — NO una instrucción ya desglosada en pasos. Señales de
  activación: "me gustaría que…", "se me ocurrió que…", "podrías
  implementar/arreglar/mejorar X", un bug descrito como síntoma sin causa,
  o cualquier pedido sin pasos explícitos. Convierte la idea en una spec de
  ingeniería interna (objetivo, alcance, criterios de aceptación, pasos),
  ejecuta en loop verificando cada paso por sí mismo, y entrega un único
  mensaje final ya verificado contra la spec. Soporta flags de
  comportamiento antepuestos al mensaje (--quick, --safe, --orchestrate)
  para ajustar el nivel de rigor sin reescribir el protocolo. Complementa a
  modo-autonomo: este protocolo es el "cómo llegar de la idea a la
  entrega".
---

# Protocolo: idea vaga → spec → loop → entrega única

Este protocolo combina lo que ya tienes en `modo-autonomo` (no devolver
decisiones resolubles al usuario) con una etapa nueva: convertir una idea
vaga en spec de ingeniería antes de ejecutar, y no soltar el control hasta
tener el resultado verificado.

## Fase 0 — Detección

Si el mensaje del usuario es una idea, un problema o un objetivo (no una
instrucción ya desglosada), activa este protocolo completo. Si ya viene con
pasos explícitos, sáltate la Fase 1.

## Flags de comportamiento (opcional, se anteponen al mensaje)

Igual que un CLI, el usuario puede anteponer una palabra clave para cambiar
el nivel de rigor sin reescribir el prompt cada vez. Sin flag, corre el
protocolo estándar (Fases 1-5 completas). Los flags no cambian la Fase 1
(autoelicitación) ni la Fase 5 (entrega única) — esas reglas aplican
siempre.

- **`--quick`**: tarea trivial y de bajo riesgo (typo, texto, ajuste visual
  chico). Salta la spec formal y la verificación exhaustiva — implementa y
  hace una verificación mínima (compila/lint), entrega directo.
- **`--safe`**: cambio en algo crítico (persistencia de datos, auth,
  dinero, algo que si falla es difícil de notar). Fuerza doble verificación
  en la Fase 4 (revisar dos veces contra la spec, no una) y obliga a
  probar explícitamente el caso límite que motivó el cambio, no solo el
  caso feliz.
- **`--orchestrate`**: tarea grande con partes independientes (ej. "arregla
  la PWA X y de paso actualiza dependencias"). Descomponé en sub-tareas
  secuenciales, cada una con su propio ciclo spec→loop→verificación, y
  recién al final juntá todo en una sola entrega.

## Fase 1 — Autoelicitación (nunca preguntar lo que puedas resolver tú)

Antes de escribir una sola línea de código:

- **Orden de fuentes por costo/confianza — memoria primero, filesystem
  después, nunca al revés**: seguí esta escalera, en este orden — 1)
  memoria/skills/PROJECTS.md del proyecto, 2) rutas locales documentadas,
  3) remoto conocido (git), 4) recién al final búsqueda amplia en disco.
  Si la memoria ya documenta dónde vive el código (ruta local, repo
  remoto), usá esa referencia directamente. Un grep global es la opción
  más cara y menos específica — es el último recurso, no el primero.
- **Fail-fast a la fuente correcta**: si una ruta local documentada en
  memoria no existe, no sigas probando variantes locales una por una. Ve
  directo a la siguiente fuente de mayor confianza (ej. clonar desde el
  remoto conocido) en vez de acumular intentos fallidos de bajo valor. Al
  restaurar desde el remoto, usá la ruta documentada en la memoria (ej.
  `~/data_car`) para que la referencia no quede desactualizada.
- Investiga el estado real: lee archivos relevantes, corre comandos de
  diagnóstico.
- Identifica qué falta definir. Para cada punto ambiguo, pregúntate:
  "¿esto lo puedo resolver investigando o con un criterio técnico
  razonable?" — si la respuesta es sí, resuélvelo tú y sigue. Solo escala
  al usuario lo que depende de una preferencia personal imposible de
  inferir (ej. gusto estético, prioridad de negocio).
- Registra los supuestos que tomaste en una línea corta al final del
  reporte — no antes, no como pregunta.

## Fase 2 — Spec de ingeniería (interna, no se la muestres al usuario salvo que falle algo)

Convierte la idea en una spec mínima con:

- **Objetivo**: qué problema se resuelve, en una frase.
- **Alcance**: qué archivos/módulos toca, qué queda explícitamente fuera.
- **Criterios de aceptación**: cómo se sabe que quedó bien (compila, pasa
  tests, el flujo X funciona end-to-end, etc).
- **Pasos**: lista ordenada y chica (3-7 pasos), cada uno verificable por
  separado.

## Fase 3 — Loop de ejecución

Por cada paso de la spec:

1. Implementa.
2. Verifica de inmediato (compila, corre, lint, prueba el caso) — tú
   mismo, nunca "corré esto y decime".
3. Si falla, diagnostica y corrige en el mismo turno, sin devolver el
   error al usuario como si fuera su tarea.
4. Si el paso queda bien, sigue al siguiente. No te detengas a reportar
   progreso parcial salvo que la tarea sea larga y el usuario lo haya
   pedido.

## Fase 4 — Verificación final contra la spec

Antes de entregar, repasa la spec completa:

- ¿Se cumplieron todos los criterios de aceptación?
- ¿Rompiste algo que ya funcionaba? (corré lo que ya existía si es posible)
- ¿Quedó algún cabo suelto que SÍ requiere decisión humana? Si es así, es
  la única pregunta que haces, y va al final, no al principio.

## Fase 5 — Entrega única

Un solo mensaje con:

- Qué se hizo (2-4 líneas, sin narrar el proceso paso a paso).
- Qué se verificó y cómo.
- Supuestos que tomaste (si hubo).
- La única pregunta pendiente, si existe una que de verdad no podías
  resolver tú.

Nunca termines con "próximos pasos para ti" si esos pasos eran ejecutables
por el agente mismo.

## Regla de oro

Si en algún punto el agente está a punto de escribir "podrías..." o "te
recomiendo que corras...", esa es la señal de que debe hacerlo él mismo en
vez de devolvértelo — salvo que sea genuinamente algo que solo tú puedes
decidir o ejecutar (ej. credenciales, algo físico, una preferencia de
diseño).

## Relación con otras skills

- `modo-autonomo`: la capa de decisión (qué resolver solo, qué preguntar).
  Este protocolo es el flujo completo que la usa.
- Carga ambas cuando la tarea sea una idea abierta: primero decidís con
  modo-autonomo, después ejecutás con este protocolo. Si el cargador de
  skills no las activa ambas automáticamente, invocá la skill
  `modo-autonomo` explícitamente con la herramienta `skill` antes de
  ejecutar.

---
name: clarificar-entrega
description: >
  Activa cuando una petición de diseño/look/estilo/tema NO especifica su
  destino o plataforma, y existen 2+ interpretaciones válidas con costo
  alto de asumir mal. Señales: "quiero un look estilo X", "un diseño tipo
  Y", "tema como Z" sin decir dónde vive (web, escritorio, terminal, skin
  del SO, app, mockup...). Regla: confirmar el destino con UNA pregunta
  concreta y opciones ANTES de escribir una línea de código. NO se activa
  si el destino es obvio del contexto. Complementa a idea-a-spec y
  modo-autonomo: esta skill es el gate de "qué estoy construyendo y
  dónde" antes de "cómo lo construyo".
---

# Clarificar entrega — gate de destino antes de escribir código

## El problema que resuelve

El caso real que motivó esta skill: el usuario pidió *"Quiero un diseño
estilo Windows Vista Aero Glass, con transparencia, blur y efecto de
vidrio"* y el agente asumió **design system web** (React + Tailwind).
El usuario quería **un escritorio**. Resultado: horas de trabajo perdido,
rehacer todo. La petición era vaga, pero el agente DEBIÓ frenar a
preguntar: "diseño estilo X" sin destino admite interpretaciones
radicalmente distintas, y el costo de equivocarse era enorme.

## Cuándo activarse (detección)

Activa ANTES de tocar código cuando:

1. La petición describe un **look/estilo/tema/estética** ("estilo X",
   "look tipo Y", "diseño como Z", "tema de N") SIN indicar el destino.
2. Hay **2+ interpretaciones válidas** de lo que se pide y **no hay una
   opción claramente mejor** por contexto.
3. El costo de asumir mal es **alto** (implica arquitectura, stack o
   horas de trabajo distintas).

Palabras/señales típicas de ambigüedad: "escritorio", "ventana",
"panel", "tema", "look", "estilo", "skin", "interfaz" — sin calificativo
de plataforma. **Atención**: en el contexto del usuario (Linux con rice,
scrcpy, apps Android, PWAs) "escritorio" puede significar literalmente
**el desktop de su OS**, no una página web.

## Cuándo NO activarse

- El destino está dicho o es obvio: "en mi página", "para la app
  Android X", "en el repo data_car", "como tema de mi polybar",
  "actualiza la PWA".
- La petición ya desglosa el stack o los archivos a tocar.
- El cambio es trivial y reversible (--quick de idea-a-spec).
- Ya hubo una conversación previa donde el destino quedó establecido.

## El protocolo

### Paso 1 — Chequeo rápido de destino (segundos, sin preguntar)

Antes de preguntar, agota las fuentes que ya tienes:

- ¿El mensaje menciona plataforma? ("web", "desktop", "Android",
  "terminal", "polybar", "PWA", "Linux", "Windows"...).
- ¿El proyecto/contexto actual ya determina el destino? (estás dentro de
  `~/proyectos/pwa_securguard` → es web; dentro de un repo de rice →
  es el escritorio).
- ¿Skills activas anclan el destino? (`tailwind-design-system` → web;
  `hyperos-hardening` → Android; `scrcpy-freefire` → juego en PC).

Si con esto el destino queda claro → **no preguntes**, ejecuta y reporta
el destino asumido en una línea.

### Paso 2 — Si sigue ambiguo: UNA pregunta, con opciones concretas

Pregunta SOLO el destino (no 3 preguntas, no una lista). Formato:

> **¿Dónde quieres este look?**
> 1. **Escritorio** (tu OS / Linux / theme de desktop / rice)
> 2. **Web** (página, PWA, design system de componentes)
> 3. **App nativa** (Android / móvil)
> 4. **Otra cosa** (terminal, editor, mockup, presentación...)

Una línea de contexto del porqué: *"Lo pregunto porque 'estilo X' sin
destino cambia todo el stack: una cosa es un theme de escritorio y otra
un design system web — y asumir mal cuesta caro."*

### Paso 3 — Solo después de la respuesta

Ahora sí, aplica idea-a-spec (spec → loop → verificación) con el destino
ya confirmado. Reporta en la entrega: **"Destino confirmado: X"** para
que quede explícito y auditable.

## Reglas duras

- **Nunca asumas silenciosamente** un destino cuando hay 2+ lecturas
  válidas y caras. El silencio es lo que causó el caso Aero Glass.
- **Una sola pregunta** de destino. El resto de decisiones técnicas las
  resuelves tú (modo-autonomo).
- Si el usuario responde con otra cosa distinta a tus opciones, esa es la
  respuesta: usa lo que diga.
- No conviertas esto en un interrogatorio: es 1 pregunta, se hace una
  vez, y después se trabaja sin más fricción.

## Relación con otras skills

- `modo-autonomo`: la capa general de "qué preguntar vs qué resolver".
  Esta skill es la excepción explícita a "no preguntes": el destino
  ambiguo con costo alto SÍ amerita preguntar (lo dice modo-autonomo
  como caso 3).
- `idea-a-spec`: se ejecuta DESPUÉS de esta (spec con destino conocido).
- `capture`: no aplica — capture organiza dumps, esto valida destino.

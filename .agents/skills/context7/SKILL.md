---
name: context7
description: "Documentación actualizada de librerías, frameworks, APIs y SDKs vía el CLI ctx7. Se activa SIEMPRE que se necesite documentación de una librería."
version: 1.0.0
author: "mangonz"
---

# context7 — Documentación de Librerías al Día

## Propósito

Obtener documentación **actualizada** de librerías, frameworks, APIs o SDKs en lugar de depender de memoria o docs desactualizadas. Es el primer recurso cuando el problema involucra una librería concreta.

## Cuándo usarla

- Necesitas la API/documentación de una librería o framework
- El comportamiento de una SDK no coincide con lo que recuerdas
- Quieres verificar opciones/parámetros de una librería antes de usarla

## Comandos

```bash
ctx7 library <nombre> <consulta>   # Busca una librería
ctx7 docs <libraryId> <consulta>   # Obtiene documentación del libraryId
```

**Ejemplo:**

```bash
ctx7 docs /vercel/next.js "App Router middleware"
```

## Reglas

1. **Siempre preferir Context7** para documentación de librerías antes que búsqueda web genérica.
2. Incluir el `libraryId` exacto del ecosistema (p. ej. `/vercel/next.js`) cuando se conozca.
3. Si `ctx7` no tiene la librería, caer a la documentación oficial y señalarlo.

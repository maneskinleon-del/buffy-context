---
version: 1.0
updated: 2026-09-30
---

# PROJECTS — base genérico

> Plantilla del índice de proyectos (Patrón B, C4-B). El base es válido como
> instancia; tu índice real vive en `PROJECTS.local.md` (gitignored) — si
> existe, los consumidores lo usan con AUTORIDAD TOTAL.

## Formato por proyecto

```markdown
## <Nombre> (<directorio>)
- Ruta: ~/proyectos/<directorio>
- Stack: (lenguajes/frameworks)
- Estado: (activo/pausado — una línea de estado actual)
- Notas: (gotchas, comandos de build/test, decisiones clave)
```

## Ejemplo

```markdown
## Mi Proyecto (mi_proyecto)
- Ruta: ~/proyectos/mi_proyecto
- Stack: TypeScript, Node
- Estado: activo — fase de tests
- Notas: npm test; no tocar dist/ a mano
```

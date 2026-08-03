# Contributing to buffy-context

Primero, ¡gracias por tu interés en contribuir! 🎉

## 📋 Tabla de contenidos

- [Código de conducta](#código-de-conducta)
- [Cómo contribuir](#cómo-contribuir)
- [Flujo de trabajo](#flujo-de-trabajo)
- [Estándares de código](#estándares-de-código)
- [Tests](#tests)
- [Crear un nuevo Skill](#crear-un-nuevo-skill)
- [Añadir conocimiento](#añadir-conocimiento)
- [Proceso de revisión](#proceso-de-revisión)

---

## Código de conducta

Este proyecto sigue el [Código de Conducta de Contributor Covenant](https://www.contributor-covenant.org/). Al participar, se espera que mantengas un ambiente respetuoso y colaborativo.

---

## Cómo contribuir

### Reportar issues

- Abre un issue en [GitHub](https://github.com/maneskinleon-del/buffy-context/issues).
- Describe claramente:
  - Versión del proyecto (commit o tag)
  - Sistema operativo y versión de Bash
  - Pasos para reproducir el problema
  - Salida de `bash scripts/buffy-doctor.sh --json` (si aplica)

### Proponer mejoras

- Abre un issue con la etiqueta `enhancement`.
- Describe el problema que resuelve y el beneficio esperado.

### Enviar código

1. Fork el repositorio.
2. Crea una rama con nombre descriptivo: `feature/nombre` o `fix/nombre`.
3. Asegúrate de que todos los tests pasen: `bash scripts/tests/run-tests.sh`.
4. Envía un Pull Request (PR) contra `main`.

---

## Flujo de trabajo

1. **Antes de empezar**: Sincroniza tu fork con `upstream/main`.
2. **Durante el desarrollo**: Corre la suite frecuentemente (`bash scripts/tests/run-tests.sh`).
3. **Antes del commit**: El hook pre-commit correrá la suite en modo `--quick` automáticamente. Para forzar la suite completa en un commit puntual: `BUFFY_HOOK_FULL=1 git commit`.
4. **Antes del PR**: Asegúrate de que la suite completa pase en tu entorno.
5. **Después del PR**: Espera la revisión de un mantenedor.

---

## Estándares de código

### Bash

- Usa `#!/usr/bin/env bash` (excepto en hooks, donde el installer `scripts/hooks/install.sh` escribe el shebang de bash **real del sistema** — necesario en Termux, donde `/usr/bin/env` no existe).
- Sigue el estilo de los scripts existentes: `set -u`, funciones con un comentario de una línea, salida con emojis/colores consistente.
- Valida la sintaxis con `bash -n` antes de commitear (la suite lo hace automáticamente).
- Salidas estructuradas: prefiere `--json` sobre salida legible para scripts consumibles.

### JavaScript (Node)

- Usa ES6+.
- Documenta funciones con JSDoc.
- No añadas dependencias sin justificación.

### Estructura de archivos

- **Scripts**: `scripts/` → ejecutables (doctor, repair, agent, router…).
- **Tests**: `scripts/tests/` → suite permanente (bash puro, runner único).
- **Hooks**: `scripts/hooks/` → hook versionado + installer.
- **Skills**: `.agents/skills/` → cada skill en su subdirectorio.
- **Conocimiento**: `Knowledge/` → archivos markdown por categoría.

---

## Tests

La suite de tests es obligatoria y se ejecuta en cada commit (modo `--quick`).

```bash
# Ejecutar toda la suite
bash scripts/tests/run-tests.sh

# Solo tests que coincidan con un nombre
bash scripts/tests/run-tests.sh doctor   # solo test-doctor.sh

# Modo rápido: salta los ciclos de sandbox (lo que copia el repo)
bash scripts/tests/run-tests.sh --quick

# Salida JSON para CI
bash scripts/tests/run-tests.sh --json
```

**CI (GitHub Actions)**: cada push a `main` y cada PR ejecutan automáticamente la suite completa + el doctor (`.github/workflows/ci.yml`). El doctor falla solo si el drift supera el baseline de errores conocidos — si tu PR introduce drift nuevo, el CI se pondrá rojo.

Reglas:

- Todo PR debe pasar la suite completa.
- Si agregas funcionalidad nueva, añade tests correspondientes.
- Los tests son **determinísticos y seguros**: todo lo que escribe corre en un sandbox (`setup_sandbox` en `helpers.sh`, HOME aislado); el repo real solo se lee.
- El runner descubre automáticamente cualquier función `test_*` definida en `scripts/tests/test-*.sh` — no hay que registrarla en ningún lado.

### Crear un nuevo test

1. Crea `scripts/tests/test-nuevo.sh` con funciones `test_nuevo_*`.
2. Usa los helpers de `helpers.sh`: `ok`, `bad`, `suite`, `check`, `expect_exit`, `jassert`.
3. Si el test copia el repo o escribe en disco, úsalo dentro de `setup_sandbox` (así `--quick` lo salta automáticamente).

---

## Crear un nuevo Skill

### Estructura requerida

```
.agents/skills/<mi-nuevo-skill>/
├── SKILL.md          # Descripción, propósito, activación
├── scripts/          # Scripts ejecutables
│   └── accion.sh
└── references/       # Documentación de referencia
    └── config.md
```

### SKILL.md mínimo

```markdown
# Skill: Mi Nuevo Skill

## Propósito
- ¿Qué problema resuelve?
- ¿Cuándo se activa?

## Dependencias
- Herramientas externas (ej. ADB, jq, etc.)

## Uso

    ./scripts/accion.sh --param valor

## Referencias
- Enlaces a archivos en Knowledge/
```

### Validación

- El skill debe quedar **referenciado en alguna doc** (`skills/<nombre>` en un `.md` o en la lista de `LOAD_CONTEXT.md`) — el doctor lo extrae dinámicamente. (Usa `<...>` como placeholder en ejemplos: el doctor detecta `skills/[a-z0-9_-]+` y un nombre literal crearía drift falso.)
- Debe tener `SKILL.md` en su propio directorio.
- Debe pasar la suite de tests (añade tests para tu skill si aporta lógica propia).

---

## Añadir conocimiento

1. Ubica el archivo en `Knowledge/<categoria>/<nombre>.md`.
2. Usa el formato:

   ```markdown
   # Título

   ## Contexto
   - ¿Para qué sirve?
   - ¿Cuándo usar esto?

   ## Contenido
   - Comandos, ejemplos, configuraciones.

   ## Referencias
   - Enlaces externos o relacionados.
   ```

3. Actualiza el índice en `Knowledge/README.md`.
4. Si añades una categoría nueva, actualiza el README.

---

## Proceso de revisión

### Roles

- **Mantenedores**: Tienen acceso de merge.
- **Revisores**: Pueden aprobar PRs.

### Criterios de aceptación

- ✅ Tests pasan (suite completa).
- ✅ Código sigue los estándares.
- ✅ Documentación actualizada.
- ✅ Sin regresiones.

### Tiempos estimados

- PR pequeño (< 100 líneas): revisión en 24–48h.
- PR grande (> 100 líneas): revisión en 3–5 días hábiles.

---

## Preguntas frecuentes

**¿Puedo contribuir sin ser experto en Bash?**
¡Sí! Puedes contribuir con documentación, tests, o mejoras de UX.

**¿Cómo pruebo un script sin afectar mi sistema real?**
Usa el sandbox de la suite: `setup_sandbox` en `helpers.sh` crea un entorno aislado (copia del repo + HOME propio).

**¿Dónde pregunto dudas?**
Abre un issue con la etiqueta `question` o contacta a los mantenedores.

---

¡Gracias por contribuir! 🚀

---
name: code-search
description: >
  Adaptador portable de búsqueda de código entre distintos asistentes IA.
  Abstrae los agentes internos de Freebuff (code-searcher, file-picker, basher)
  con fallbacks genéricos (ripgrep, find, grep) para funcionar también en
  Claude Code, Codex, Cursor y otros entornos.
version: 1.0.0
---

# code-search — Adaptador de Búsqueda Portable

> **Problema:** Cada asistente IA tiene sus propios agentes internos para buscar
> código (`code-searcher` en Freebuff, `GrepTool` en Claude Code, etc.). Una skill
> que depende de un agente específico no es portable.
>
> **Solución:** Esta skill define una interfaz única de búsqueda con **3 modos**
> ordenados por eficiencia. Cada modo intenta el método nativo primero y cae al
> siguiente si no está disponible.

---

## Modos de búsqueda (orden de preferencia)

### Modo 1 — Agente nativo (más rápido)

Usa el agente de búsqueda del asistente actual si está disponible:

| Asistente | Agente | Comando de detección |
|---|---|---|
| **Freebuff** | `code-searcher` | Agente integrado. Invocar directamente. |
| **Freebuff** | `file-picker` | Agente integrado. Invocar directamente. |
| **opencode** | `grep` / `glob` | Herramientas nativas (igual que Claude Code). |
| **Claude Code** | `GrepTool` / `glob` | Herramientas nativas del protocolo MCP. |
| **Codex CLI** | `search` | Herramienta integrada. |

**Señales de activación:**
- El usuario pide "busca X en el código", "encuentra dónde se usa Y"
- El usuario comparte un error y necesitas encontrar la definición de una función/clase
- Necesitas entender cómo funciona una parte del código antes de modificarla

### Modo 2 — CLI genérico (portable)

Si el agente nativo no está disponible o no alcanza, usar comandos directos:

```bash
# Búsqueda por patrón (ripgrep > grep)
rg -n "patrón" -g '*.{ts,tsx,kt,java,py,js,go}' 2>/dev/null || \
grep -rn "patrón" --include='*.{ts,tsx,kt,java,py,js,go}' . 2>/dev/null | head -50

# Búsqueda de archivos por nombre
find . -name "*patrón*" -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | head -20

# Búsqueda de definiciones (funciones, clases, interfaces)
rg "^(export )?(function|class|interface|fun|def) .*patrón" -g '*.{ts,tsx,kt,java,py}' 2>/dev/null

# Búsqueda en commits (si es git)
git log --all --oneline --grep="patrón" 2>/dev/null | head -10
```

**Detección de herramienta disponible:**
```bash
# Verificar qué herramientas de búsquee están instaladas
which rg 2>/dev/null && echo "ripgrep disponible" || \
which grep 2>/dev/null && echo "grep disponible" || \
echo "sin buscador de texto"
```

### Modo 3 — Exploración manual (fallback final)

Si no hay ripgrep, grep, ni agente nativo:

```bash
# Listar estructura del proyecto
ls -R | head -100

# Leer archivos clave
cat package.json 2>/dev/null
cat build.gradle.kts 2>/dev/null
cat Cargo.toml 2>/dev/null

# Encontrar archivos relevantes por extensión
find . -maxdepth 3 -name "*.ts" -o -name "*.kt" -o -name "*.py" 2>/dev/null | head -30
```

---

## Casos de uso comunes

### 1. "Encuentra dónde se define/usa X"

```yaml
objetivo: "findDefinition"
símbolo: "saveDpi"
lenguaje: "kotlin"
ruta_base: "."
```

**Estrategia:**
1. Intentar `code-searcher` (Freebuff) con patrón `saveDpi` y flag `-g *.kt`
2. Si no disponible: `rg "fun saveDpi|saveDpi" -g '*.kt'`
3. Si no disponible: `grep -rn "saveDpi" --include='*.kt' .`
4. Reportar: archivo, línea, definición (fun/class/val), y contexto circundante

### 2. "Explora la estructura del proyecto"

```yaml
objetivo: "exploreStructure"
ruta: "."
```

**Estrategia:**
1. Intentar `file-picker` (Freebuff) con descripción del proyecto
2. Si no disponible: `find . -maxdepth 4 -name "*.{kt,ts,py}" | head -30`
3. Reportar: árbol de directorios, archivos principales, dependencias clave

### 3. "Busca en el historial de git"

```yaml
objetivo: "gitHistory"
query: "fix DPI"
```

**Estrategia:**
1. `git log --all --oneline --grep="DPI" -20`
2. `git log --all -p --grep="DPI" -5` (si necesita el diff)
3. Reportar: commits relevantes con hash, fecha, mensaje, autor

---

## Formato de respuesta

Siempre estructurar los resultados de búsqueda así:

```
## Resultados de búsqueda: [término]

### Método usado: [Modo 1/2/3] — [herramienta]

| Archivo | Línea | Contenido (±3 contexto) |
|---------|-------|--------------------------|
| src/foo.kt | 42 | `fun saveDpi(ctx: Context, dpi: Int)` |

> Mostrar ±3 líneas de contexto alrededor del match para que la firma completa sea visible.

### Resumen
[qué se encontró, dónde está, qué hace]
```

---

## Integración con otras skills

Skills relacionadas en `.agents/skills/`:
- **`search_criteria_v4`** — para generar consultas de búsqueda optimizadas.
  Cargar SOLO si necesitas más de 3 consultas de búsqueda para resolver el problema.
- **Shell** (Knowledge/Shell/Shell.md) — si necesitas comandos avanzados de bash/grep/rg.

Referencia Knowledge/ para shell scripting: `Knowledge/Shell/Shell.md`.

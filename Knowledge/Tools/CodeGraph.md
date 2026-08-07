# 🔍 CodeGraph — Grafo de conocimiento de código

> Referencia rápida: descubrimiento y análisis de código con CodeGraph.
> Actualizado: 2026-08-06

---

## 📌 Qué es

| Campo | Valor |
|---|---|
| **Paquete** | `@colbymchenry/codegraph` v1.5.0 (npm global) |
| **Licencia** | MIT, open source |
| **Localidad** | 100% local (sin nube) |
| **Backend** | SQLite (WAL) + tree-sitter (AST) |
| **Comando MCP** | `codegraph serve --mcp` |
| **Telemetría** | Desactivada en este sistema |

Grafo de conocimiento del código: símbolos (funciones, clases, métodos, campos, imports) + aristas (llamadas, referencias, herencia) en una base SQLite local. Resuelve call graphs **cruzando archivos**, incluida dispatch dinámica que grep no puede seguir.

---

## 🚀 Regla de uso (obligatoria)

Si el proyecto tiene un directorio `.codegraph/` en su raíz → está indexado → usar CodeGraph **ANTES de grep/find/leer archivos a ciegas** para descubrimiento y análisis de impacto.

Proyectos indexados actualmente:

| Proyecto | Índice |
|---|---|
| `~/proyectos/autoscript-mobile-interface/` | 49 archivos · 1.084 símbolos · 1.896 aristas |
| `~/proyectos/ManUninstaller/` | 31 archivos · 486 nodos · 838 aristas |

Si NO existe `.codegraph/`, saltarse CodeGraph (indexar es decisión del usuario). Solo vale la pena en proyectos >30 archivos fuente o con complejidad cruzada real.

---

## 🔌 MCP (agentes IA)

Servidor MCP configurado en 4 agentes (herramienta única **`codegraph_explore`**):

| Agente | Config | Extra |
|---|---|---|
| Claude Code | `~/.claude.json` + `~/.claude/settings.json` | auto-allow `mcp__codegraph__*` + hook `codegraph prompt-hook` |
| Gemini CLI | `~/.gemini/settings.json` + `~/.gemini/GEMINI.md` | — |
| Antigravity | `~/.gemini/config/mcp_config.json` | — |
| Cline (VSCodium) | `globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` | cableado a mano (no oficial) |

`codegraph_explore` acepta nombres de símbolos, archivos o **preguntas en lenguaje natural**; devuelve código fuente verbatim con líneas + blast radius + call paths en una sola llamada.

---

## 🛠️ Comandos CLI

| Comando | Qué hace |
|---|---|
| `codegraph explore "<símbolos o pregunta>"` | Explora un área: símbolos + call paths + código verbatim (misma salida que el MCP) |
| `codegraph query <término>` | Busca símbolos con `archivo:línea` |
| `codegraph callers <símbolo>` | Quiénes llaman al símbolo |
| `codegraph callees <símbolo>` | A quiénes llama el símbolo |
| `codegraph impact <símbolo>` | Qué se rompe si cambias X (análisis de refactor) |
| `codegraph node <símbolo o archivo>` | Fuente + trail callers/callees, o archivo con dependientes |
| `codegraph files` | Estructura de archivos desde el índice |
| `codegraph status` | Stats del índice (archivos, nodos, aristas) |
| `codegraph init [ruta]` | Inicializa + indexa un proyecto |
| `codegraph index` | Rebuild completo del índice |
| `codegraph sync` | Sync manual de cambios |
| `codegraph daemon` | Gestiona el watcher en background |
| `codegraph unlock` | Elimina un lock file stale |
| `codegraph affected [archivos]` | Tests afectados por archivos modificados |
| `codegraph install/uninstall` | Instala/remueve el MCP en agentes |
| `codegraph telemetry status/off` | Telemetría (off en este sistema) |

---

## ✅ Ejemplos reales verificados

| Consulta | Resultado |
|---|---|
| `codegraph query boost` (autoscript) | `BoostScreen` MainActivity.kt:696 · `toggleBoost` GameSessionManager.kt:161 |
| `codegraph callers GameBoostRepository` | 11 callers (AdsPointerManager, NetworkOptimizer, PowerOptimizer, RamManager…) |
| `codegraph impact toggleBoost` | 131 símbolos afectados |
| `explore "uninstall flow MainActivity ShizukuUserService"` (ManUninstaller) | Flujo completo MainActivity → AppViewModel → UninstallAppsUseCase → AppRepositoryImpl → ShizukuUserService + aviso "no covering tests" |
| `codegraph impact MainActivity` | 35 símbolos, 0 fuera del archivo (hoja del grafo) |
| `codegraph impact AppViewModel` | 47 símbolos en 2 archivos (6 call-sites en MainActivity) |
| `explore "system critical apps Device Admin warning"` | 58 símbolos en 4 archivos: showAdminWarning (MainActivity:520), showCriticalAppWarning (:691), removeAdmin/listActiveAdmins con tests, isCriticalSystemApp sin tests |
| `explore "cleanCache cleanAppCache"` | Cadena completa cleanCache (AppViewModel:202) → CleanCacheUseCase → cleanAppCache (AppRepositoryImpl:165) vía Shizuku; toda la cadena sin tests |

---

## 🧠 Interpretación de resultados

- **Hoja del grafo** (sin callers, ej. MainActivity): cambiarla solo afecta su propio archivo.
- **Hub** (muchos callers, ej. GameBoostRepository / AppViewModel): cambiarla afecta N call-sites → mapa de riesgo antes de refactorizar.
- **Blast radius**: lista los dependientes de los símbolos consultados — qué verificar/actualizar antes de editar.
- **"⚠️ no covering tests found"**: el grafo detecta si hay tests que cubren el símbolo; zonas rojas = refactor sin red de seguridad.

---

## 🔧 Troubleshooting

| Problema | Solución |
|---|---|
| `status` dice "Not initialized" | `codegraph init` desde la raíz del proyecto |
| Lock file stale bloqueando el indexado | `codegraph unlock` |
| MCP no aparece en el agente | Reiniciar el agente; verificar config con `codegraph install --print-config <agente>` |
| Se esperan varias herramientas MCP | En v1.5.0 el MCP expone **una sola**: `codegraph_explore` (consolidó query/node/callers/impact) |
| Auto-sync no refleja cambios | El daemon watcher sincroniza solo; si falla: `codegraph sync` o `codegraph index` |
| Daemon corriendo de más | `codegraph daemon` → elegir y detener |
| El grafo no encuentra un símbolo nuevo | `codegraph sync` (el índice se auto-actualiza, pero se puede forzar) |
| ¿Vale la pena indexar un proyecto? | Solo si >30 archivos fuente o arquitectura con call graphs reales |

---

## 📎 Integración con el ecosistema

- `~/.AGENTS.md` + `AGENTS-root.md` — regla global (fuente de verdad, mantenidos **sincronizados**)
- `ai-context/INFO-core.md` — sección CodeGraph (carga obligatoria del protocolo)
- `ai-context/LOAD_CONTEXT.md` — sección Code Search: "⚡ CodeGraph PRIMERO"
- `~/.claude/CLAUDE.md` + `~/.gemini/GEMINI.md` — bloques CODEGRAPH automáticos
- `ai-context/PROJECTS.md` — entradas de proyectos indexados
- `AGENTS.md` de `autoscript-mobile-interface` — sección "CodeGraph — Descubrimiento y Análisis (obligatorio)"

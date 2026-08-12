# MCP_REGISTRY

> Catálogo de servidores MCP disponibles o configurables para complementar las
> limitaciones de FreeBuff (el build free NO expone MCP nativo — ver `SPEC.md`:
> compila con flag que strippea features de pago). Esto es el "registro portátil"
> que sobrevive al límite de sesión de 1h de FreeBuff.

## Convención de ubicación
- **FreeBuff / Codebuff**: buscan `.agents/mcp.json` en `cwd` → padre → home (`~/.agents/mcp.json`).
- **OpenCode**: bloque `mcp` en `~/.config/opencode/opencode.json`.
- Forma estándar: `{ "mcpServers": { "nombre": { ... } } }`.

---

## Servidores

### codegraph  ·  [AVAILABLE — sesiones OpenCode]
- **Tipo**: local (stdio), por proyecto.
- **Comando**: `codegraph serve --mcp` (ya configurado en `opencode.json` del usuario).
- **Propósito**: descubrimiento semántico de código y análisis de impacto
  (`explore`, `query`, `callers`/`callees`, `impact`) en repos indexados (`.codegraph/`).
- **Cuándo usar**: entender o refactorizar código en proyectos indexados
  (autoscript-mobile-interface, ManUninstaller, GameBoostPro, data_car,
  pwa_securguard, lista_supermercado).
- **Nota**: capacidad de OpenCode, NO existe en FreeBuff.

### OpenRouter MCP  ·  [OPTIONAL — remoto, requiere config]
- **Endpoint**: `https://mcp.openrouter.ai/mcp`
- **Propósito**: acceso unificado a modelos, catálogo, monitoreo de créditos.
- **Estado**: no configurado para el usuario. Útil si se usa OpenRouter vía BYOK.
- **Config (OpenCode)**: agregar server remoto en el bloque `mcp` de `opencode.json`.

### mcp-cli (puente shell)  ·  [WORKAROUND — para FreeBuff]
- **Herramienta**: `mcp-cli` (philschmid, v0.3.0) — bridge shell-invocable a servers MCP.
- **Subcomandos**: `info` (lista servers/tools), `grep` (busca tools), `call` (invoca una).
- **Config**: `mcp_servers.json` en cwd o `~/.config/mcp/`.
- **Cuándo usar**: SOLO si FreeBuff no expone MCP nativo y necesitás MCP dentro de FreeBuff.
  Requiere que FreeBuff pueda correr shell (`/bash`, `!cmd`) y que lo instruyas para usarlo.
- **Estado**: NO confirmado que FreeBuff free exponga MCP nativo (hilo SO Agents, jul 2026:
  "no MCP support as of 0.0.118"). Test de confirmación: crear `.agents/mcp.json` trivial
  con un server stdio y pedir la tool `server/tool`; si no aparece, usar el puente mcp-cli.

---

## Plantilla para agregar un server

```json
// .agents/mcp.json  (FreeBuff/Codebuff)
//   o bloque "mcp" en opencode.json (OpenCode)
{
  "mcpServers": {
    "nombre": {
      "type": "local",
      "command": ["comando", "--flag"],
      "enabled": true
    }
  }
}
```

```json
// Server remoto (OpenCode)
{
  "mcp": {
    "nombre": {
      "type": "local",
      "command": ["npx", "-y", "server-mcp"],
      "enabled": true
    }
  }
}
```

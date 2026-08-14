# Auditoría para Freebuff — Integración handoff / Session hooks / Compaction

> Preparada por Buffy (2026-08-14). Pasar a Freebuff cuando termine su corrida actual.
> Contexto: el usuario observó que OpenCode parece compactar automáticamente pero
> Freebuff no. Antes de tocar la skill `handoff`, auditar la integración real.

## Contexto verificado (por Buffy)

- La skill `handoff` existe en `.agents/skills/handoff/SKILL.md` (197 líneas).
- La skill **NO define compactación automática por porcentaje de contexto**.
  Solo triggers explícitos/implícitos con confirmación del usuario (línea 41:
  "propose the handoff before running it — never run it silently").
- La skill **describe** hooks `SessionStart` (auto-load del handoff, línea 105)
  y `SessionEnd` (recordatorio, línea 111) — pero condicionados a
  "when the plugin is installed".
- **OpenCode NO tiene esos hooks configurados** (verificado en
  `~/.config/opencode/opencode.json` + `opencode.jsonc` + `~/.opencode/`).

## Distinción de tres mecanismos (no mezclar)

1. **Context compaction** — el host reduce/resume la conversación cuando el contexto crece.
2. **Handoff** — Buffy crea un documento persistente para continuar en otra sesión.
3. **SessionStart/SessionEnd hooks** — automatizan carga/recordatorio del handoff.

La skill `handoff` resuelve #2 y describe infraestructura para #3. No implementa #1.

## Preguntas para Freebuff (responder sin modificar código)

1. **¿Tenés compaction nativa de contexto?** ¿Cómo funciona (umbral, qué se descarta)?
2. **¿Tenés algún evento equivalente a SessionStart/SessionEnd?** ¿Se disparan en tu runtime?
3. **¿Podés ejecutar automáticamente una skill/script cuando el contexto alcanza un umbral?**
4. **¿Tu integración con Buffy-context implementa realmente los hooks que la skill `handoff` declara?** (leer SKILL.md ≠ implementar hooks)
5. **¿Qué parte de la skill `handoff` queda sin ejecutar en tu runtime?**

## Respuestas que cambian el diseño

- "Tengo compaction automática, pero no integración con handoff" → conectar Buffy al mecanismo existente (no construir uno nuevo).
- "No tengo compaction ni hooks" → decidir si Buffy necesita un adaptador, implementar hooks, o conectar la skill al ciclo de sesión.

## Arquitectura objetivo (separación de responsabilidades)

```
FREEBUFF / HOST
      ├── Context Manager (compaction)   ← el host administra la ventana de contexto
      └── Session Events (start/end)     ← el host dispara eventos
                    │
                    ▼
             BUFFY-CONTEXT
              ├── SNAPSHOT/STATE         ← Buffy administra memoria/estado
              └── HANDOFF                ← Buffy administra continuidad entre sesiones
                    │
                    ▼
             siguiente sesión
```

Buffy NO intenta ser el administrador del contexto del modelo. Buffy administra
memoria/estado; el host administra ventana de contexto/compaction.

## Regla

NO modificar la skill `handoff` para compensar una limitación del host.
Primero identificar si el problema está en la skill, en la integración de Buffy,
o en el runtime de Freebuff.
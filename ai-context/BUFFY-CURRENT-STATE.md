# BUFFY-CURRENT-STATE — checkpoint de auditoría (handoff a otro AI)

**Versión:** v1.1 — reconstrucción con las correcciones del review + addendum de cierre (§10)
**Fecha del checkpoint:** 2026-09-25
**Estado:** listo para usar como checkpoint. No requiere más auditoría previa.
**Ubicación:** `~/buffy-context/ai-context/` (fuente de verdad; `~/ai-context/` es snapshot sincronizado).

---

## 0. Procedencia de este documento

El archivo `BUFFY-CURRENT-STATE.md` v1 original (producto de la auditoría revisada) no llegó a persistir en disco: existía solo en la conversación de la sesión anterior. Este documento es su reconstrucción, hecha el 2026-09-25 a partir de:

1. Las 4 correcciones del review del usuario (trazabilidad en §2).
2. Re-verificación fresca contra los repositorios locales, misma fecha (evidencia en §8).

Convención de confianza usada en todo el documento:

| Marca | Significado |
|---|---|
| `[orig]` | Afirmación heredada de la auditoría original; no re-verificada hoy. |
| `[verificado 2026-09-25]` | Comprobado hoy contra el sistema, con evidencia en §8. |

Propiedad deliberada del documento: **no oculta las zonas no auditadas** (§7). El consumidor debe poder distinguir hecho verificado de afirmación heredada.

---

## 1. Fechas y método de la auditoría [orig, corregido por R1]

- **HEAD observado por la auditoría:** 2026-09-15. La auditoría usó el estado de HEAD obtenido del repositorio y, luego, archivos entregados por el usuario.
- **Auditoría:** 2026-09-25.
- No confundir ambas fechas: lo observado corresponde al estado del repo con HEAD del 15-sep; la evaluación se realizó el 25-sep.

Notas de frescura `[verificado 2026-09-25]`:
- buffy-next: HEAD actual `1c975f0` (2026-09-24, solo docs de research), rama `master`. Es posterior al HEAD observado por la auditoría → ese commit NO quedó cubierto por la auditoría.
- buffy-context: HEAD actual `5750ab5` (2026-09-22), rama `main`.

---

## 2. Correcciones del review aplicadas (trazabilidad)

| Ref | Sección original | Corrección aplicada |
|-----|------------------|---------------------|
| R1 | §1 fechas | Distinguir **HEAD observado: 2026-09-15** de **auditoría: 2026-09-25**. Aplicada en §1. |
| R2 | §3 "18 scripts" | Eliminado el número exacto: **"scripts auditados + librerías auxiliares"** (el inventario no fue exhaustivo). Aplicada en §3. |
| R3 | §10 skill-lint | No confundir capacidad con uso efectivo en CI. Ver nota R3 y §4. |
| R4 | §16 MCP | **"buffy → buffy serve --mcp" se conserva como configuración previamente observada**, no como estado local actualmente verificado. Aplicada en §5; coherente con §15 original (config MCP local no verificada). |

**Nota R3 (mejora sobre la formulación pedida):** el review proponía degradar a "gate de cobertura disponible para CI" porque no se había visto el workflow invocándolo. En la re-verificación de hoy SÍ se encontró la invocación directa: `buffy-context/.github/workflows/ci.yml:29` — job `suite`, paso *"Linter de manifests (--require-all)"*, con comentario explícito de gate. Por eso §4 afirma el uso en CI como `[verificado 2026-09-25]`, no como capacidad genérica. Si se prefiere la formulación cautelosa del review, basta con degradar esa línea de §4.

---

## 3. Alcance auditado — scripts [orig, corregido por R2]

- Alcance de la auditoría: **scripts auditados + librerías auxiliares** de `~/buffy-context/scripts/`.
- Sin recuento exacto en este documento: el inventario de la auditoría no fue exhaustivo.
- `[verificado 2026-09-25]` contexto de inventario: el repo contiene 70 `.sh` en total (excluyendo `.git/`), repartidos entre `scripts/` (operativos), `scripts/lib/` (librerías) y `scripts/tests/` (suite + evals). El conjunto auditado es un subconjunto propio de la auditoría original; tras la pérdida del archivo no es registrable con exactitud cuáles fueron.

---

## 4. skill-lint.sh [verificado 2026-09-25, R3]

- `scripts/skill-lint.sh` existe (135 líneas) y valida los manifiestos `skill.yaml` de `.agents/skills/` (id == directorio, name, version semver, entry, safe, triggers, front-matter de SKILL.md).
- Modo `--require-all`: implementado; falla (exit 1) si alguna skill carece de manifest.
- **Uso efectivo en CI:** `.github/workflows/ci.yml` (job `suite`) lo invoca directamente: `bash scripts/skill-lint.sh --require-all` (línea 29), con comentario de gate en el propio workflow.
- Ejecución local de hoy: modo normal → `{"skills": 43, "manifests": 43, "errors": 0, "warnings": 0, "healthy": true}`; con `--require-all` → exit 0 (43/43).

---

## 5. MCP [R4]

- **Configuración previamente observada [orig]:** `buffy → buffy serve --mcp`. Es una observación previa, NO estado local actualmente verificado. Coherente con §15 del original: la configuración MCP local no fue verificada.
- `[verificado 2026-09-25]`:
  - El modo existe en código: `buffy-next/src/cli.ts` (`case 'serve'` en línea 80, uso `buffy serve --mcp` en 328, modo stdio JSON-RPC en 324) y `src/mcp.ts` está presente. Existencia en código ≠ verificación de runtime.
  - `~/.gemini/settings.json` registra `mcpServers.buffy-tools` → `node ~/experiments/opencode-buffy-cplus/adapter/buffy-mcp-server.js`; **ese archivo no existe en disco** → la entrada registrada está rota (dangling). No apunta a `buffy serve --mcp`.
  - `~/.gemini/antigravity-cli/mcp/buffy/instructions.md` existe (describe `buffy_context` como herramienta read-only).
- No se verificó ningún servidor MCP de Buffy funcionando en runtime.

---

## 6. Contenido de la v1 original no recuperable

Del texto original solo sobrevivieron las 4 correcciones del review. Cualquier otro hallazgo de la auditoría (secciones §2, §4–§9 y §11–§14 del original) **no está en este documento y no debe atribuírsele**. Si el AI consumidor necesita esos hallazgos, debe re-auditar las zonas correspondientes o recuperar el contexto de la conversación original.

---

## 7. Zonas NO auditadas / límites explícitos

- Contenido íntegro de la v1 original fuera de las 4 correcciones (ver §6).
- `scripts/tests/` (suite bash + evals): existencia verificada hoy; contenido no auditado.
- Runtime MCP: nada verificado en ejecución; la única entrada MCP registrada apunta a un archivo inexistente.
- buffy-next: commit `1c975f0` (2026-09-24) y código de `src/mcp.ts` no auditados.
- `ai-context/` (INFO-core, facts_rules.yaml, CONTINUE, SESION): no auditado en este checkpoint.

---

## 8. Evidencia de re-verificación (2026-09-25)

| # | Verificación | Resultado |
|---|--------------|-----------|
| 1 | buffy-next `git log -1` | `1c975f0` 2026-09-24 docs(research) — rama `master` |
| 2 | buffy-context `git log -1` | `5750ab5` 2026-09-22 checkpoint GameBoostPro — rama `main` |
| 3 | `skill-lint.sh --json` | 43/43 manifests, 0 errores, healthy |
| 4 | `skill-lint.sh --require-all` | exit 0 |
| 5 | Invocación en CI | `ci.yml:29`, job `suite`: `bash scripts/skill-lint.sh --require-all` |
| 6 | Adapter MCP registrado | `~/experiments/opencode-buffy-cplus/adapter/buffy-mcp-server.js` → **no existe** |
| 7 | Modo serve --mcp en código | `cli.ts:80,324,328` + `src/mcp.ts` presente |
| 8 | Total `.sh` en buffy-context | 70 (excluye `.git/`) |

---

## 9. Uso por el AI consumidor

- Este documento **SÍ puede usarse como checkpoint** (decisión del review). No re-auditar antes de usar.
- Tratar `[orig]` como afirmación heredada de auditoría (no re-verificada) y `[verificado 2026-09-25]` como hecho con evidencia en §8.
- No convertir las zonas no auditadas (§7) en afirmaciones positivas.

---

## 10. ADDENDUM v1.1 (2026-09-25, misma sesión) — sello de vigencia y estado real de la suite

### 10.1 Veredictos de código vigentes al HEAD actual

- Cadena de provenancia desde el HEAD auditado: `e438f29` (auditado) → `1c975f0` (solo docs de research, 0 archivos en `src/`) → `d036312` (los 2 archivos modificados del operador: `.gitignore` +`.gemini/`, `CURRENT-STATE.md` +§9 cierre ronda AGY — 0 archivos en `src/`). Ambos commits pusheados; `master == origin/master`, working tree limpio.
- **Cero cambios en `src/` desde el HEAD auditado** → los veredictos de código de la auditoría aplican textualmente al HEAD `d036312`. Este documento puede consumirse sin re-auditar código.

### 10.2 Flake `latencyMs` — NO activo (corrección al checkpoint 606/607)

- El "1 fallo conocido (latencyMs 0 vs 1)" del checkpoint 2026-09-11 **fue corregido al día siguiente**: commit `094a3af` (2026-09-12) excluye `audit.latencyMs` de la igualdad byte-a-byte conservando su validación (`typeof number` + `≥ 0`), con cobertura máxima del resto del payload. Validado entonces: 607/607. Documentado en `docs/COMPANION-READINESS.md:92`.
- **Advertencia de lectura:** `CURRENT-STATE.md` de buffy-next §0 es un **checkpoint congelado del 2026-09-11** — sus "problemas conocidos" NO describen el estado de HEAD. (Esta confusión propagó un flag obsoleto durante la sesión del 25-sep; el flag se levantó sin re-verificar la fecha de la sección.)
- Estabilidad actual sobre HEAD `d036312`: **3/3 pasadas consecutivas de la suite completa → 634/634 (38 archivos)** + `tsc --noEmit` limpio.

### 10.3 Procedencia del conteo de tests

| Conteo | Desde | Causa del delta |
|---|---|---|
| 606/607 | checkpoint 2026-09-11 | estado congelado en CURRENT-STATE.md §0 |
| 607/607 | `094a3af` (2026-09-12) | fix del flake (+1 estable) |
| 634/634 | `1c975f0`/`d036312` | +27 tests por features en la ventana (distribution, discovery, install — commits `eaad4a9`, `d0c49fe`, `a54d0bd`, `9e19bb8`, `e70219c`) |

Citar "634/634" es válido desde el HEAD actual; citarlo retroactivamente al 11-sep sería falso.

### 10.4 HEADs vigentes al cierre del ciclo

| Repo | HEAD local | Remoto |
|---|---|---|
| buffy-context | `365c117` (checkpoint + convención; tras rebase limpio con docs shizuku del teléfono) | `origin/main` — sincronizado |
| buffy-next | `d036312` (docs AGY closure + gitignore) | `origin/master` — sincronizado |

### 10.5 Nota post-ciclo (2026-09-25, parte 3) — anotación de vigencia e438f29

- La contradicción señalada en el handoff quedó resuelta: el diagnóstico C3′ de `e438f29` ("workspace vacío → run_command") está anotado en `docs/research/AGY-BUFFY-ROUTING-C3-PRIME-ANALYSIS-2026-09-15.md` (commit `eb496f9`, buffy-next) con la convención de este documento: **[orig]** preserva el texto forense íntegro; **[verificado 2026-09-23]** documenta que la ronda de replicación no soporta la hipótesis como condición suficiente (3/3 PASS en vacío; FAILs del 14-sep no reproducidos, contraste ≈11% no distinguible del ruido, §7.2.2 del doc 23-sep). Refinamiento añadido: C5-B (2026-09-25) — selección task-sensible en dirección contract-correcta.
- HEADs vigentes tras la parte 3: buffy-next `eb496f9` (solo docs — 0 cambios en `src/`, el sello de §10.1 sigue aplicando). La ronda B del handoff ya estaba ejecutada antes de esta sesión: protocolo `f706bb6` + resultado `0df24e1` (ver CHANGELOG 2026-09-25 parte 2).

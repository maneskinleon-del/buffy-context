# BUFFY-PC-CONTEXT.md — Digest de sesiones para Buffy (PC)

> **Cómo usar este archivo:** cuando la Buffy del PC retome el trabajo sobre
> buffy-context, que lea este digest ANTES de empezar (está en la raíz del repo).
> Contiene el resumen **verificado de primera mano** de lo que se hizo en estas
> sesiones (agosto 2026), el estado actual del proyecto, los hechos comprobados,
> las convenciones, los comandos de validación y lo que queda pendiente.
> Complementa a REVIEW-BASELINE.md (contexto para *revisiones* de IA): este es el
> digest orientado a **continuar el trabajo**.

---

## 1. Qué es esto (en 30 segundos)

- **Buffy Context** es un proyecto **personal** (no una librería pública):
  infraestructura Bash + knowledge base + skills para dar memoria persistente a
  asistentes IA. El autor lo usa en su teléfono (Termux) y PC.
  `system-id: mangonz-desktop`.
- **Repo:** `buffy-context/` → `github.com:maneskinleon-del/buffy-context.git`
- **Estado actual:** CI verde · doctor con **0 errores** (baseline 0) ·
  **23 skills** con manifest machine-readable (23/23) · suite **116 OK** (--quick)
  / **132 OK** (completa).

## 2. Qué se hizo en estas sesiones (commits)

| Commit | Qué cambió | Validación |
|---|---|---|
| `eac6536` | Docs: unificar ruta de SNAPSHOT.md a `~/ai-context/` (fuera del repo) en README + aclarar en INSTALL que HF_TOKEN es SIEMPRE obligatorio (no hay modo local) | doctor 13/7 sin drift nuevo · suite --quick 54/54 |
| `a917a00` | REVIEW-BASELINE.md: contexto verificado de primera mano para revisiones de IA (estado real, hechos comprobados, errores que las IAs repiten) | doctor 13/7 · suite 54/54 |
| `ff17b23` | Resolver el drift del doctor: crear las 13 skills documentadas que faltaban (10 nuevas con contenido real + 3 migradas de ~/.agents/skills/), baseline CI 16→0, sanitizar notas históricas y un false positive, fix de un bug real del test doctor --quick | doctor 0 errors · suite 74/90 |
| `e8c351f` | Skill manifests (B2): skill.yaml de ejemplo en android-agent + linter `scripts/skill-lint.sh` integrado en la suite + fix de un bug crítico del linter (bucle infinito por falta de `shift` en --json/--require-all) | doctor 0 · suite 74/90 |
| `5aa4e49` | B2 completo: 23/23 skills con skill.yaml + gate `--require-all` activo en la suite (test) y en CI (paso explícito) | doctor 0 · suite 75/91 · 3 gates CI PASS |

Evolución de la suite: 54/70 (quick/full) antes de la sesión → 74/90 tras el
linter → 75/91 tras el gate.

## 3. Estado verificado actual (digest rápido)

- **Skills:** 23 en disco (10 originales + 10 creadas en `ff17b23` + 3 migradas
  de `~/.agents/skills/`), cada una con SKILL.md (documentación humana) +
  skill.yaml (contrato machine-readable: id, name, version, entry, safe,
  triggers, capabilities, dependencies).
- **Linter:** `scripts/skill-lint.sh` — valida id==directorio, version semver,
  entry existe, safe booleano, triggers no vacío y cross-check del front-matter
  del SKILL.md. `--require-all` = gate (23/23 hoy). Exit 0/1/2, `--json` con
  stderr limpio.
- **Doctor:** `scripts/buffy-doctor.sh --json` → 0 errors / 4 warnings de
  entorno (NO_AI_CONTEXT_DIR, MISSING_SNAPSHOT, DEPRECATED). Baseline CI 0.
- **CI** (`.github/workflows/ci.yml`): job `suite` (run-tests.sh --json + paso
  explícito linter --require-all) + job `doctor` (BASELINE_ERRORS=0).
- **Hook pre-commit** (`scripts/hooks/`): corre la suite --quick (75 OK) antes
  de cada commit. Portable Termux-safe.
- **Versionado:** `set-version.sh` (semver + suite + tag) + `changelog-entry.sh`.
- **Router:** `scripts/buffy-router.sh` con listas explícitas de skills +
  detector Android. Aún **NO** lee los manifests (pendiente — ver §7).

## 4. Hechos comprobados (las IAs se equivocan en esto)

1. **SNAPSHOT.md se escribe FUERA del repo**: `$HOME/ai-context/SNAPSHOT.md`
   (scripts/buffy-context.sh línea 13). Es estado generado, no se versiona.
2. **kimi_vision.js NO tiene modo local/Ollama**: usa solo la API hosted de HF
   (`KIMI_ENDPOINT` default router.huggingface.co). **HF_TOKEN es SIEMPRE
   obligatorio** (línea 238 lanza error si falta). No sugerir "modo local".
3. **NO hay rutas absolutas hardcoded en los scripts**: usan `$HOME/ai-context/`
   (diseño deliberado) y rutas relativas al checkout. Las rutas absolutas viven
   solo en docs (INSTALL.md).
4. **buffy-router.sh SÍ tiene descubrimiento de skills** (listas explícitas +
   `detect_android_project()`). Lo que faltaba era el formato estándar (manifest)
   — ahora existe (skill.yaml, 23/23).
5. **Termux: no existe /usr/bin/env**: todo se ejecuta con `bash script.sh`
   explícito; el hook installer escribe el shebang real del sistema.
6. **Versiones mínimas de scrcpy/Ollama NO documentadas (a propósito)**:
   pendiente de decisión del usuario — verificarlas desde el PC y documentarlas.
7. **El manifest es adyacente al SKILL.md** (no lo reemplaza): el SKILL.md es la
   doc humana; skill.yaml es el contrato máquina validado por el linter.

## 5. Convenciones y exit codes

- `buffy-doctor.sh`: exit 1 con drift · flags --json/--quick/--help.
- `buffy-repair.sh` / `buffy-agent.sh`: 0 consistente · 1 requiere decisión · 2 uso.
- `skill-lint.sh`: 0 sano · 1 manifests inválidos (o cobertura incompleta con
  --require-all) · 2 uso.
- `--quick` en la suite: salta los ciclos de sandbox (los hooks y CI lo usan).
- Todo lo que escribe (repair `--auto`, ciclo del agent) corre en **sandbox con
  HOME aislado** dentro de la suite; el repo real solo se lee.
- Ejecución siempre con `bash` explícito (Termux).

**Regla crítica para quien edite docs:** NO escribir patrones `skills/<nombre>`
literales en archivos `.md` — el doctor los extrae como skills documentadas y
crea drift falso (MISSING_SKILL). Referenciar skills con el nombre solo, sin el
prefijo `skills/`.

## 6. Comandos de validación (gate de CI)

```bash
# Suite (gate de CI)
bash scripts/tests/run-tests.sh           # 132 OK esperado
bash scripts/tests/run-tests.sh --quick   # 116 OK esperado

# Doctor (drift) — 0 errors / 1 warning de entorno
bash scripts/buffy-doctor.sh --json
bash scripts/buffy-doctor.sh --quick

# Linter de manifests — 23/23, gate activo
bash scripts/skill-lint.sh
bash scripts/skill-lint.sh --require-all  # exit 0 (todas con manifest)

# Linter estructural de ai-context (B1)
bash scripts/ai-context-lint.sh           # 0 errores esperado
bash scripts/ai-context-lint.sh --json

# Versionado (solo para releases)
bash scripts/changelog-entry.sh --dry-run v1.1.0
bash scripts/set-version.sh v1.1.0        # corre la suite completa antes de taggear

# Hook
bash scripts/hooks/install.sh --check
```

## 7. Pendientes priorizados (lo que sí falta)

1. ~~**CHANGELOG caótico (A2)**~~ — **LIMPIO (2026-08-03)**: 661 → 216 líneas;
   front-matter único (versión duplicada eliminada); entradas ≤ 2026-07-31 movidas
   a CHANGELOG-archive.md con dedupe; quedan 13 recientes (08-01 a 08-03).
   Pendiente opcional: que `changelog-entry.sh` archive automáticamente.2. ~~**Router con manifests**~~ — **HECHO (2026-08-03, PC)**: `buffy-router.sh` ya resuelve las
   skills desde su skill.yaml (id/entry/safe/triggers) vía `add_skill()` + `discover_skills()`
   (barrido por triggers del manifest, ≥1 match). Rutas hardcodeadas eliminadas; una skill
   nueva con manifest se activa sola. `lib/yaml.sh` compartido con skill-lint (sin duplicación).
   Suite: 75→90 OK (quick) / 91→106 OK (full). Fix bonus: mensaje vacío → exit 1.
3. ~~**README desactualizado**~~ — **HECHO (2026-08-03, PC)**: árbol de skills
   (23 agrupadas por dominio), Knowledge (AI/+Vision), scripts (16) y conteos al
   día con el disco.
4. ~~**Schema/validador para ai-context (B1)**~~ — **HECHO (2026-08-03, PC)**:
   `scripts/ai-context-lint.sh` valida las secciones obligatorias de
   INFO-core/CONTINUE/LOAD_CONTEXT (las que LOAD_CONTEXT.md promete SIEMPRE) +
   front-matter semver-lite X.Y/X.Y.Z + updated ISO. 5 tests en la suite
   (--json schema, stderr limpio, fixtures sin sandbox → corren en --quick).
   Suite: 105 OK quick / 121 OK full.
5. ~~**BUFFY_HOME / common.sh (C2, opt-in)**~~ — **HECHO (2026-08-03, PC)**: `scripts/lib/common.sh` (NUEVO) exporta BUFFY_HOME (default `$HOME`) + helpers buffy_home/buffy_ai_context/buffy_snapshot. Cableado en buffy-context/doctor/repair/router — redirige SOLO el estado generado (ai-context/ + SNAPSHOT); el escaneo del entorno del usuario sigue con $HOME real. Sin BUFFY_HOME → comportamiento idéntico (verificado). 6 tests nuevos; doc en INSTALL.md.
6. **Decisiones del usuario pendientes**: (a) ~~migración SYSTEM.md → INFO-core~~ —
   **HECHA (2026-08-03, PC)**: stubs movidos a `ai-context/deprecated/` vía
   `migrate-system.sh` (referencias corregidas a INFO-core/INFO-full; doctor ya no
   reporta DEPRECATED_FILE); (b) ~~versiones mínimas de scrcpy/Ollama~~ — **HECHA
   (2026-08-03, PC)**: scrcpy ≥ 3.3.1 recomendado (UHID v2.0 + fix --power-off-on-close
   3.3.1; verificado 4.1-1) y Ollama ≥ 0.30 (verificado 0.30.7) — documentadas en
   `Knowledge/Android/scrcpy.md` y `Knowledge/Vision.md` con fuente.
7. **Bajo prioridad**: sandbox hardening + installer (D1/D2 del roadmap), y
   adapters VLM/LLM (YAGNI — solo existe un backend HF).

## 8. Cómo continuar (flujo recomendado)

1. `git pull` en el PC (o clone) para traer el estado actual.
2. Leer este digest (§1-§6) + REVIEW-BASELINE.md (hechos y decisiones).
3. Antes de tocar nada, correr la validación de §6 y confirmar verde.
4. Para cada cambio: implementar → suite --quick verde → reviewer → commit
   (el hook corre la suite) → push.
5. Siguiente paso recomendado: **router con manifests** (§7.2) — el contrato ya
   existe, solo falta consumirlo.

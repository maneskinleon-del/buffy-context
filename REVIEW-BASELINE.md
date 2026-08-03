# REVIEW-BASELINE.md — Contexto verificado para revisiones de IA

> **Cómo usar este archivo:** pásaselo a Copilot (u otra IA) ANTES de que revise el repositorio.
> Contiene el estado **verificado de primera mano** del proyecto (agosto 2026), los hechos
> comprobados contra el código real, los errores que las revisiones de IA repiten, lo que ya
> está hecho y lo que realmente falta. Si una revisión contradice esto, lo más probable es
> que esté mirando una foto anterior del repo o asumiendo sin verificar.
>
> Para el digest de sesiones orientado a **continuar el trabajo** (qué se hizo, estado
> actual, pendientes y cómo proceder), ver **BUFFY-PC-CONTEXT.md** en la raíz del repo.

---

## 1. Qué es este proyecto (verificado)

Buffy Context es un proyecto **personal** (no una librería pública): infraestructura Bash +
knowledge base + skills para dar memoria persistente a asistentes IA. El autor lo usa en su
propio teléfono (Termux) y PC. `system-id: mangonz-desktop`.

Componentes reales y funcionales:

| Componente | Archivos | Estado |
|---|---|---|
| Memoria/protocolo | `ai-context/LOAD_CONTEXT.md`, `INFO-core.md`, `CONTINUE.md`, `SESION.md` | ✅ Funcional |
| Knowledge base | `Knowledge/` (Android, Linux, React, Git, Node, Shell, AI) | ✅ 16 archivos |
| Skills | `.agents/skills/` — **23 skills en disco** (10 originales + 10 creadas 2026-08-03 + 3 migradas de ~/.agents/skills/) | ✅ Funcionales, **23/23 con skill.yaml** (B2 completo) + linter con gate |
| Orquestación | `scripts/buffy-doctor.sh`, `buffy-repair.sh`, `buffy-agent.sh`, `buffy-router.sh` | ✅ Ciclo doctor→repair→agent funcional |
| Visión | `scripts/kimi_vision.js` + `Knowledge/AI/Kimi-K3.md` | ✅ Funcional (solo backend HF) |
| Suite de tests | `scripts/tests/run-tests.sh` | ✅ 121 checks full / 105 quick |
| CI | `.github/workflows/ci.yml` | ✅ En cada push/PR |
| Hooks | `scripts/hooks/install.sh` + `pre-commit.sh` | ✅ Portable (Termux-safe) |
| Versionado | `scripts/set-version.sh` + `scripts/changelog-entry.sh` | ✅ Semver + CHANGELOG auto |

---

## 2. Hechos comprobados contra el código (las IAs se equivocan en esto)

Estos puntos fueron **verificados con comandos reales** en esta sesión. Las revisiones de IA
los han afirmado mal repetidamente:

### 2.1 SNAPSHOT.md se escribe FUERA del repo
- **Verdad:** `scripts/buffy-context.sh` línea 13: `SNAPSHOT="$HOME/ai-context/SNAPSHOT.md"`.
  Se crea en `~/ai-context/`, **no** en `ai-context/` dentro del repo.
- README e INSTALL.md ya están corregidos y unificados (commit `eac6536`).

### 2.2 kimi_vision.js: NO existe modo local/Ollama
- **Verdad:** usa **solo** la API hosted de Hugging Face (`KIMI_ENDPOINT` default
  `https://router.huggingface.co/v1/chat/completions`). **HF_TOKEN es SIEMPRE obligatorio**
  (línea 238: `throw new Error('Falta HF_TOKEN...')` si está vacío). No hay adaptador local.
- Las revisiones que sugieren "modo local sin HF_TOKEN" o "aclarar si requiere API key" están
  **desactualizadas** — ya está aclarado en INSTALL.md y README.

### 2.3 NO hay rutas absolutas hardcoded en los scripts
- **Verdad:** los scripts usan `$HOME/ai-context/` (diseño deliberado) y rutas relativas al
  checkout. `grep -rn 'buffy-context' scripts/*.sh` solo encuentra menciones en comentarios.
- Las rutas absolutas viven solo en **docs** (INSTALL.md usa `~/buffy-context/scripts/...`),
  no en código.

### 2.4 buffy-router.sh consume los manifests (desde 2026-08-03)
- **Verdad:** el router resolvía skills con rutas hardcodeadas. Desde 2026-08-03 lee
  `skill.yaml` (id/entry/safe/triggers) vía `add_skill()` + `discover_skills()` (barrido por
  triggers, ≥1 match). `lib/yaml.sh` es compartido con skill-lint. Skills nuevas con manifest
  se descubren sin editar el router.

### 2.5 Termux: no existe /usr/bin/env
- **Verdad:** los 6 scripts linkeables usan shebang `#!/usr/bin/env bash`; en Termux eso falla
  con invocación directa. Por eso: (a) todo se ejecuta con `bash script.sh` explícito,
  (b) el hook installer escribe el shebang real del sistema. INSTALL.md lo documenta.

### 2.6 Versiones mínimas de scrcpy/Ollama (documentadas 2026-08-03)
- **scrcpy**: `Knowledge/Android/scrcpy.md` — mínimo recomendado **≥ 3.3.1** (UHID ≥ 2.0,
  `--power-off-on-close` con fix en 3.3.1; verificado `4.1-1` + `adb 1.0.41`).
- **Ollama**: `Knowledge/Vision.md` — mínimo **≥ 0.30** (verificado binario `0.30.7`
  sirviendo en `:11434`, paquete pacman `0.32.1-1`; último upstream v0.32.5).
- Verificadas desde el PC con fuente (release notes oficiales de scrcpy y ollama).

---

## 3. Lo que YA está hecho (no volver a proponerlo)

Este trabajo se completó y pusheó en esta sesión (todos verdes):

- ✅ **CI en GitHub Actions** (`.github/workflows/ci.yml`): job `suite` (run-tests.sh --json)
  + job `doctor` con `BASELINE_ERRORS=0` (falla ante cualquier drift — resuelto 2026-08-03).
- ✅ **Versionado semver + CHANGELOG autogenerado**: `set-version.sh` valida semver, corre la
  suite, genera la entrada de release (`changelog-entry.sh`), crea tag anotado.
- ✅ **Hook pre-commit portable**: `scripts/hooks/install.sh` con `--install/--uninstall/--check/
  --force/--no-test`; escribe el shebang real (Termux-safe). Verificado con 3 commits reales.
- ✅ **INSTALL.md robusto** (2 rondas de revisión): URL real, verificación de dependencias,
  mkdir/chmod para symlinks, nota Termux + `/usr/bin/env`, dependencias opcionales, sandbox,
  smoke test post-instalación, `cp -rn`/rsync, `command -v >/dev/null`, ejemplo fish.
- ✅ **README unificado**: ruta de SNAPSHOT corregida a `~/ai-context/`.
- ✅ **Suite determinística**: 121 checks full / 105 `--quick` (7 SKIP: 4 sandbox + 3 changelog).
- ✅ **Skill manifests (B2) completo**: las **23/23 skills** tienen `skill.yaml` (derivados del front-matter/contenido real de cada SKILL.md) + linter `scripts/skill-lint.sh` (valida id/version/entry/safe/triggers, cross-check con el front-matter, cobertura). **Gate activo**: test en la suite (`--require-all` → exit 0) + paso explícito en el job `suite` de CI — cualquier skill nueva sin manifest rompe CI (2026-08-03).
- ✅ **Schema-lite ai-context (B1) completo**: `scripts/ai-context-lint.sh` valida las secciones obligatorias de INFO-core/CONTINUE/LOAD_CONTEXT (las que LOAD_CONTEXT.md promete SIEMPRE) + front-matter semver-lite X.Y/X.Y.Z + updated ISO. 5 tests en la suite (--json schema, stderr limpio, fixtures sin sandbox → corren en --quick). Detectó 3 front-matters con version X.Y (aceptado como convención del repo). Suite: 105 quick / 121 full (2026-08-03).

---

## 4. Problemas REALES pendientes (lo que sí hay que atacar)

Estos son los problemas actuales del proyecto, en orden de prioridad:

1. ~~**Drift conocido no resuelto**~~ — **RESUELTO (2026-08-03)**: las 13 skills documentadas que
   faltaban se crearon en `.agents/skills/` con contenido real (context7, las 4 del framework
   v4, vite, tailwind-design-system, typescript-advanced-types, vercel-react-best-practices,
   modo-autonomo) y las 3 que solo vivían en `~/.agents/skills/` (form-filler, image-analyzer,
   xiaomi-adb-tricks) se migraron al repo. Baseline de CI ahora `0`. El doctor reporta
   **0 errores** (quedan warnings de entorno: NO_AI_CONTEXT_DIR, MISSING_SNAPSHOT, DEPRECATED).
2. ~~**CHANGELOG caótico**~~ — **LIMPIO (2026-08-03)**: poda ejecutada (661 → 216
   líneas; entradas 2026-07-31 y anteriores movidas a CHANGELOG-archive.md con dedupe
   contra lo ya archivado), front-matter duplicado eliminado (un solo bloque arriba,
   `version: 1.7` / `updated: 2026-08-03`), 13 entradas recientes (08-01 a 08-03)
   ordenadas. Pendiente opcional: que `changelog-entry.sh` archive automáticamente.
3. ~~**Migración SYSTEM.md → INFO-core**~~ — **HECHA (2026-08-03)**: los stubs
   `SYSTEM.md`/`SYSTEM_FULL.md` (ya vacíos, apuntaban a INFO-core/full) se movieron a
   `ai-context/deprecated/` vía `migrate-system.sh`; referencias corregidas a
   INFO-core/INFO-full. El doctor ya no reporta `DEPRECATED_FILE`.
4. ~~**README promete más de lo que hay**~~ — **ACTUALIZADO (2026-08-03)**: el árbol de
   Knowledge/skills en README refleja el disco (23 skills por dominio, AI/+Vision, scripts
   completos).

---

## 5. Convenciones y exit codes (verificadas)

- `buffy-doctor.sh`: exit `1` cuando hay drift (normal — no es un error de script).
  Flags: `--json` (consumible), `--quick` (resumen de errores), `--help`.
- `buffy-repair.sh` / `buffy-agent.sh`: `0` = consistente · `1` = drift que requiere decisión
  humana · `2` = error de uso.
- `--quick` en la suite: salta los ciclos de sandbox (los hooks y CI lo usan).
- Todo lo que escribe (repair `--auto`, ciclo del agent) corre en **sandbox con HOME aislado**
  dentro de la suite; el repo real solo se lee.
- Ejecución siempre con `bash` explícito (Termux). Scripts con `#!/usr/bin/env bash` → la
  invocación directa como binario solo funciona en Linux.

---

## 6. Cómo validar cualquier propuesta (comandos reales)

```bash
# Suite completa (gate de CI)
bash scripts/tests/run-tests.sh           # 121 OK esperado
bash scripts/tests/run-tests.sh --quick   # 105 OK esperado

# Doctor (drift)
bash scripts/buffy-doctor.sh --json       # 0 errors / 1 warning en local (desde 2026-08-03)
bash scripts/buffy-doctor.sh --quick

# Linter de manifests (B2)
bash scripts/skill-lint.sh                 # 0 errores · cobertura 23/23
bash scripts/skill-lint.sh --require-all   # gate activo en CI: TODAS las skills con manifest (exit 0)

# Linter estructural de ai-context (B1)
bash scripts/ai-context-lint.sh            # 0 errores esperado
bash scripts/ai-context-lint.sh --json

# Versionado
bash scripts/changelog-entry.sh --dry-run v1.1.0
bash scripts/set-version.sh v1.1.0        # corre la suite completa antes de taggear

# Hook
bash scripts/hooks/install.sh --check
```

**Regla crítica para quien edite docs:** NO escribir patrones `skills/<nombre>` literales en
archivos `.md` — el doctor los extrae como skills documentadas y crearía drift falso
(MISSING_SKILL). Referenciar skills con el nombre solo, sin el prefijo `skills/`.

---

## 7. Decisiones de diseño deliberadas (no "bugs")

- **Bash puro sin bats**: bats no existe en Termux; la suite es determinística y sandboxed.
- **SNAPSHOT fuera del repo**: es estado generado, no se versiona (`.gitignore`).
- **Android en el core**: es el caso de uso principal del autor; "pluginizarlo" es opcional.
- **Manifests machine-readable (B2)**: adoptado `skill.yaml` adyacente al SKILL.md — el SKILL.md sigue siendo documentación humana; el manifest es el contrato máquina (id, version, entry, safe, triggers). **23/23 skills con manifest y `--require-all` como gate activo** en la suite (test) + CI (paso explícito).
- **Proyecto personal**: el roadmap de "1.0 oficial con 6-12 sprints" es desproporcionado;
  las mejoras deben ser incrementales y de bajo riesgo.

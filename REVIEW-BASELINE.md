# REVIEW-BASELINE.md — Contexto verificado para revisiones de IA

> **Cómo usar este archivo:** pásaselo a Copilot (u otra IA) ANTES de que revise el repositorio.
> Contiene el estado **verificado de primera mano** del proyecto (agosto 2026), los hechos
> comprobados contra el código real, los errores que las revisiones de IA repiten, lo que ya
> está hecho y lo que realmente falta. Si una revisión contradice esto, lo más probable es
> que esté mirando una foto anterior del repo o asumiendo sin verificar.

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
| Skills | `.agents/skills/` — **23 skills en disco** (10 originales + 10 creadas 2026-08-03 + 3 migradas de ~/.agents/skills/) | ✅ Funcionales, **sin manifest.yaml** |
| Orquestación | `scripts/buffy-doctor.sh`, `buffy-repair.sh`, `buffy-agent.sh`, `buffy-router.sh` | ✅ Ciclo doctor→repair→agent funcional |
| Visión | `scripts/kimi_vision.js` + `Knowledge/AI/Kimi-K3.md` | ✅ Funcional (solo backend HF) |
| Suite de tests | `scripts/tests/run-tests.sh` | ✅ 70 checks full / 54 quick |
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

### 2.4 buffy-router.sh SÍ tiene descubrimiento de skills
- **Verdad:** el router tiene listas explícitas (`SKILL_FILES+=(".agents/skills/<nombre>/SKILL.md")`)
  y `detect_android_project()`. Lo que **falta** es un formato estándar (manifest), no el descubrimiento.

### 2.5 Termux: no existe /usr/bin/env
- **Verdad:** los 6 scripts linkeables usan shebang `#!/usr/bin/env bash`; en Termux eso falla
  con invocación directa. Por eso: (a) todo se ejecuta con `bash script.sh` explícito,
  (b) el hook installer escribe el shebang real del sistema. INSTALL.md lo documenta.

### 2.6 Versiones mínimas de scrcpy/Ollama: NO documentadas (a propósito)
- Knowledge **no documenta** versiones mínimas de scrcpy ni Ollama. NO se han inventado
  (las revisiones sugirieron `scrcpy >= 2.0`, `Ollama >= 0.3.x` sin fuente).
- **Pendiente de decisión del usuario**: verificarlas desde el PC y luego documentarlas.

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
- ✅ **Suite determinística**: 70 checks full / 54 `--quick` (7 SKIP: 4 sandbox + 3 changelog).

---

## 4. Problemas REALES pendientes (lo que sí hay que atacar)

Estos son los problemas actuales del proyecto, en orden de prioridad:

1. ~~**Drift conocido no resuelto**~~ — **RESUELTO (2026-08-03)**: las 13 skills documentadas que
   faltaban se crearon en `.agents/skills/` con contenido real (context7, las 4 del framework
   v4, vite, tailwind-design-system, typescript-advanced-types, vercel-react-best-practices,
   modo-autonomo) y las 3 que solo vivían en `~/.agents/skills/` (form-filler, image-analyzer,
   xiaomi-adb-tricks) se migraron al repo. Baseline de CI ahora `0`. El doctor reporta
   **0 errores** (quedan warnings de entorno: NO_AI_CONTEXT_DIR, MISSING_SNAPSHOT, DEPRECATED).
2. **CHANGELOG caótico:** múltiples bloques front-matter duplicados (`version: 1.7` y
   `version: 1.4` a mitad de archivo), entradas desordenadas, ~175 líneas pendientes de poda.
   La herramienta que genera entradas (`changelog-entry.sh`) debería también limpiarlo.
3. **Migración SYSTEM.md → INFO-core pendiente** (decisión del usuario): `SYSTEM.md` y
   `SYSTEM_FULL.md` están marcados DEPRECATED pero siguen vivos.
4. **README promete más de lo que hay:** el árbol de Knowledge/skills en README no coincide
   con el disco — es el origen del drift.

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
bash scripts/tests/run-tests.sh           # 70 OK esperado
bash scripts/tests/run-tests.sh --quick   # 54 OK / 7 SKIP esperado

# Doctor (drift)
bash scripts/buffy-doctor.sh --json       # 0 errors / ~4 warnings en local (desde 2026-08-03)
bash scripts/buffy-doctor.sh --quick

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
- **Sin manifests machine-readable**: falta real (ver §4/roadmap), no una decisión cerrada.
- **Proyecto personal**: el roadmap de "1.0 oficial con 6-12 sprints" es desproporcionado;
  las mejoras deben ser incrementales y de bajo riesgo.

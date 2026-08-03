# 🔄 CONTINUE — Handoff entre sesiones

> ⚡ **PRÓXIMA SESIÓN: LEE ESTO PRIMERO**
> Generado: 2026-08-03 (PC — digest del teléfono leído + router con manifests implementado)

---

## Resumen de la sesión

**Tema principal:** Retomada desde el PC con el Mi 10 conectado por USB. Se leyó el digest `BUFFY-PC-CONTEXT.md` que dejaste desde el teléfono (Termux), se sincronizó el repo (2 commits atrás) y se implementó el pendiente prioritario del digest: **el router ahora consume los manifests skill.yaml**.

---

### ✅ Logros principales

#### 1. 📥 Sincronización del repo
- `git pull` trajo los 2 commits que faltaban: `23314bd` (fix CHANGELOG) + `06afbfd` (el digest BUFFY-PC-CONTEXT.md) + tag `v1.0.1`
- Estado previo validado: doctor 0 errores · linter 23/23 · suite quick 75 OK

#### 2. 🧭 Router con manifests (pendiente §7.2 del digest — HECHO)
- **`scripts/lib/yaml.sh`** (NUEVO): funciones compartidas `yaml_val`/`yaml_items`/`yaml_list` — movidas de skill-lint (cero duplicación), `yaml_list` nueva (items de lista → regex unida por `|`)
- **`scripts/skill-lint.sh`**: ahora sourcea `lib/yaml.sh` (eliminadas sus definiciones locales)
- **`scripts/buffy-router.sh`**: el router ya NO hardcodea rutas de skills:
  - `add_skill <id>` registra la skill si su manifest existe (si no → warning de drift B2)
  - `discover_skills` al final: barre los skill.yaml y carga cualquier skill cuyo **triggers** matchee el mensaje (≥1 match) y no esté ya registrada → **una skill nueva con manifest se activa sin editar el router**
  - `skill_safe` se usa para marcar `⚡ AUTO_SAFE` en la salida humana
  - **Fix bonus**: mensaje vacío (args ni stdin) → exit 1 (antes seguía con exit 0)
- **`scripts/tests/test-router.sh`** (NUEVO): 15 tests (ayuda, base, skill vía manifest, descubrimiento por triggers con fixture, warning drift, --json, --quick, --list)

#### 3. ✅ Validación completa
| Check | Antes | Después |
|---|---|---|
| Suite `--quick` | 75 OK | **90 OK** |
| Suite completa | 91 OK | **106 OK** |
| Doctor | 0 errors | **0 errors** |
| Linter | 23/23 | **23/23** |

- Verificado en vivo: "lag en free fire con scrcpy" → scrcpy-freefire + android-game-opt; "componente react con vite" → descubre `vercel-react-best-practices` + `vite` solas (no estaban hardcodeadas)
- Code review aplicado: eliminado dead code de la condición AUTO_SAFE (comparación `[ "$(...)" = true ]`), unificada regex de claves en yaml_list/yaml_items
- **Commit `0c4d92a` pusheado por SSH** → GitHub

### 📁 Archivos modificados/creados

| Archivo | Cambio |
|---|---|
| `scripts/lib/yaml.sh` | **NUEVO** — utilidades YAML compartidas |
| `scripts/tests/test-router.sh` | **NUEVO** — tests del router (15) |
| `scripts/buffy-router.sh` | add_skill/discover_skills + fix mensaje vacío + AUTO_SAFE |
| `scripts/skill-lint.sh` | sourcea lib/yaml.sh (sin duplicación) |
| `scripts/tests/run-tests.sh` | sourcea test-router.sh |
| `BUFFY-PC-CONTEXT.md` | §7.2 marcado como HECHO |
| `REVIEW-BASELINE.md` | §2.4 actualizado (router consume manifests) |

---

### ⏳ Pendientes para próxima sesión

1. ~~**README desactualizado**~~ — **HECHO (2026-08-03)**: árbol de skills (23 agrupadas por dominio), Knowledge (AI/+Vision), scripts (16) y conteos al día con el disco.
2. ~~**Schema-lite para ai-context (B1)**~~ — **HECHO (2026-08-03)**: `scripts/ai-context-lint.sh` valida secciones obligatorias de INFO-core/CONTINUE/LOAD_CONTEXT + front-matter semver-lite; 5 tests nuevos en la suite (105 OK quick / 121 OK full).
3. **Decisiones tuyas**: (a) ~~migración SYSTEM.md → INFO-core~~ — **HECHA (2026-08-03)** vía migrate-system.sh, stubs en `ai-context/deprecated/`; (b) ~~versiones mínimas scrcpy/Ollama~~ — **HECHA (2026-08-03)**: scrcpy ≥ 3.3.1 / Ollama ≥ 0.30, en Knowledge/Android/scrcpy.md y Knowledge/Vision.md.
4. **`gh auth login`** — sigue pendiente (los push van por SSH y funcionan).
5. ~~**BUFFY_HOME / common.sh (C2, opt-in)**~~ — **HECHO (2026-08-03)**: `scripts/lib/common.sh` exporta BUFFY_HOME (default $HOME) + helpers buffy_home/buffy_ai_context/buffy_snapshot; cableado en buffy-context/doctor/repair/router (solo estado generado). 6 tests nuevos. Verificado sin y con BUFFY_HOME.
6. Renombrar repo `enerador-de-boletas` → `generador-de-boletas` (requiere gh auth).

---

### ⚠️ Problemas conocidos

- **gh sin autenticar** — todo push por SSH (funciona con `~/.ssh/id_ed25519`).
- **`detect_adb_device`**: con un teléfono conectado por ADB, la categoría Android se activa SIEMPRE (cualquier mensaje). Comportamiento preexistente, no introducido hoy.
- **Triggers compartidos**: `adb` vive en 4 manifests (android-adb, android-agent, shizuku-rikka, xiaomi-adb-tricks) → un mensaje con "adb" carga varias skills. Trade-off deliberado del diseño ≥1 match del digest.

---

## Stack del usuario (referencia rápida)

```
OS:    EndeavourOS (Arch) · kernel 6.18.39-1-lts
WM:    bspwm (X11) · rice gh0stzk/cynthia · picom
Shell: zsh (Oh My Zsh + Starship) · alacritty · editor VSCodium
CPU:   Ryzen 5 3400G (4C/8T) + Vega 11 · 13GB RAM · 1360x768
Phone: Mi 10 (d2c6cbda, conectado hoy) · ZTE Nubia Z2352N · ADB + Shizuku
Disk:  39% usado / 126G libres · ollama + backups en HDD (/media/datos)
Stack: React + TS + Tailwind v4 + Vite → GitHub (maneskinleon-del) → Vercel
Node:  v26.4.0 · npm 11.18.0 · gh CLI (sin auth)
Git:   maneskinleon-del / mangonz970@gmail.com · push por SSH
Repo:  buffy-context (al día con origin/main)
Suite: 116 OK quick / 132 OK full · doctor 0 · linter 23/23
```

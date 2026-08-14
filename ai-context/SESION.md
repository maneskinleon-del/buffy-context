# 🧠 SESION — Buffy Freebuff (2026-08-14 · V6 adoptado + cerrar día+1 + phi/qwen)

> Contexto de lo implementado durante esta sesión. Corrida en **Freebuff** (PC).
> Tres frentes: iteración S3 → veredicto 15B (V6); tarea "cerrar día+1" (apagado); prueba de modelos locales (phi3.5/qwen2.5:7b) en opencode.

---

## 🚀 V6 adoptado (15B) · tarea "cerrar día+1" · phi/qwen en opencode (2026-08-14 · Freebuff)

### Lo hecho
1. **Iteración S3 → veredicto 15B (V6 ADOPTADO, commit `5fc0822`):** harnees fiel al runner 15A (M3 reproduce 16/20 bit a bit). V6 = S3 condicionado a query estructural + S4 por clase de memoria de sesión (ai-context/* salvo CHANGELOG.md curado) → **attr 16/20 → 19/20, pRel 0.577 → 0.677, leak 0.275 (pasa gate ≤0.308), reg 0.420 → 0.360**; Q02 1/3→3/3, Q07 1/2→2/2, Q08/Q06 intactos. V2/V3/V4 descartados con evidencia (densidad rompe Q02; S4 clase total rompe Q06; solo-tablas no arregla nada). Cambios de mecanismo, sin calibración. Q05 `useState` (s1=0.4646) = miss ortogonal → rama X.
2. **Tarea "cerrar día+1" (commit `5fc2fa0`):** `buffy-close-day.sh --poweroff` — cierre completo + apagado SOLO si terminó sin error. Env override `BUFFY_POWEROFF_CMD`/`BUFFY_POWEROFF_DELAY` (stub en tests, nunca apaga de verdad). Tests +3. Suite 270 OK / 4 FAIL full · 254 OK / 4 FAIL --quick (solo preexistentes).
3. **phi3.5 en opencode: BLOQUEADO** (no soporta tool calling — capabilities solo `completion`; error `does not support tools`). Coherente con el EVAL 14A. **qwen2.5:7b FUNCIONA** (respondió OK, exit 0) — agregado al provider `ollama` de `~/.config/opencode/opencode.json` junto con phi3.5. Nota: qwen 32K contexto (opencode recomienda 64k+) → repos chicos; alternativa robusta: `ollama pull llama3.1:8b`/`qwen3:8b`.
4. **12/13 preservados (commit `d34b7f6`, pusheado):** registro E/F completo (13 archivos) — veredictos "CERRADO sin adopción" intactos.
5. **Push de la sesión:** `5bf37d6..904e0fa` → origin/main (5 commits: 12/13 + V6 + handoffs). El trabajo de "cerrar día+1" queda por pushear en este cierre.

### ⏳ Pendientes
- **Q03 + Q05 (gap semántico, rama X del Paso 10):** expansión de query con diccionario H1 (plan en CONTINUE.md).
- Próximo cierre: push de `5fc2fa0` + docs de sesión (este archivo + CHANGELOG).

---

## 🔖 Revisión y destino de los artefactos Pasos 12/13 (2026-08-14 · Freebuff)

### Pedido del usuario
Revisar los artefactos de los Pasos 12/13 (evidence-passage E1/E2/E3 · candidate-expansion F1/F2) para integrarlos o decidir su destino.

### Lo hecho
1. **Dictamen de revisión:** la integración funcional ya estaba completa y pusheada (2026-08-13): F2 como generador de pasajes (`expand_passages.py` + `buffy-expand.sh`, Q08 cerrado en vivo) y E2 como insight de S4 (bge-m3 = content-scorer). Los artefactos pendientes son el **registro** de experimentos cerrados sin adopción, no funcionalidad nueva.
2. **Integridad verificada:** baselines E1/E2/E3/F1/F2 (×2) parsean OK y sus determinism hashes coinciden con el EVAL-REGISTRY commiteado (E2 `4ab293dacef1c914` · F2 `7fc28c377482e2c5`); `run-evidence-PC.sh` sintaxis válida; diffs de diseños = solo Anexos A.
3. **Decisión del usuario:** commitear el registro completo (preservación de evidencia; los veredictos "CERRADO sin adopción" ya están en el registro).
4. **Commit `d34b7f6`** — 13 archivos (2 diseños + 10 baselines + `run-evidence-PC.sh`), path-limited, **sin push**. Working tree limpio.

### Pendientes
- Push de `d34b7f6` (decisión del usuario).
- Q03 gap semántico (rama X del Paso 10) · hallazgo S3.

---

## 🚀 Integración M3 + Expansión F2 — pipeline real operativo (2026-08-13 · Freebuff)

### Pedido del usuario
1. Integrar el selector M3 rescue 0.545 (adoptado en 15A) con el pipeline real (`router → search → selector → context pack`).
2. Cerrar el candidate gap de Q08/Q03 (el FTS5 no genera `System.md`) con la expansión F2 del Paso 13, sin tocar los artefactos del autor anterior.

### Lo hecho
1. **Motor M3 extraído** a `scripts/lib/selector_m3.py` (bit-a-bit del runner 15A: S1-S4, gate rescue 0.545, pesos 1.0/1.0/0.5/0.5). Fidelidad verificada sobre el fixture congelado: **attr 16/20 · leak 0.242 · pRel 0.577 · Q06 1/1 · Q08 2/2** = idéntico al veredicto 15A.
2. **`scripts/buffy-selector.sh`** — wrapper CLI (--query + candidatos → top-K M3; exit 3 sin Ollama).
3. **`scripts/buffy-expand.sh` + `lib/expand_passages.py`** — expansión F2 (rama P): tile_windows ±4 no-solapados (9 líneas), kno del router + top-K del pool, `--max-passages 400` como guard de coste.
4. **`buffy-search.sh --select`** — candidatos FTS5 (`or` para queries naturales) → expansión → M3. **`buffy-router.sh --context`** — lista de archivos + campo `context` (pasajes top-K). Defaults intactos byte a byte (verificado).
5. **Regla de compresión** (EVAL-REGISTRY §): iteración rápida valida contra el fixture congelado (sin Ollama, segundos) — el pipeline completo en frío paga embeds (Paso 13: r0 ≈ 17 min) y no es apto para ciclos.
6. **Tests** (`test-selector.sh` +24 checks): sintaxis, uso, degradación, determinismo, 15A, expansión F1/F2, fidelidad expand vs fixture (99%), no-regresión del default. **Suite: 266 OK / 4 FAIL full · 250 OK / 4 FAIL --quick** (4 FAIL preexistentes). README actualizado.

### Validación en vivo
- **Q08 CERRADO** — con kno + expansión, `Knowledge/Linux/System.md:73-81` (P_TERM_OPACITY/picom) entra al **top-1** del selector (antes: fuera del pool).
- **Q06** — gold FF_SEEN (CHANGELOG.md:217-225) entra al top-K vía search `or` (puesto 4).
- **Q03 PERSISTE (gap semántico)** — Commands.md en pool vía kno, pero `pushear`→`git push origin` no lo conecta bge-m3 por línea → requiere rama X del Paso 10.

### Veredicto y estado
- Pipeline completo operativo: `query → router → search → expand (F2) → selector (M3) → context pack`.
- Commits **`39ce873` → `6f6be74` (5, path-limited, FWD-safe)** — **PUSHEADOS a origin/main** (`4443629..6f6be74`).
- Suite 266 OK / 4 FAIL (preexistentes). Working tree limpio salvo artefactos 12/13.

### ⏳ Pendientes
- **Q03 (gap semántico):** rama X del Paso 10 (expansión de query) — Commands.md ya está en el pool; falta el puente `pushear`→`push`. Retomar en sesión fresca.
- **Artefactos Pasos 12/13 (autor anterior):** `evidence-passage-DESIGN.md` (M), `passage-candidate-expansion-DESIGN.md`, `run-evidence-PC.sh`, baselines E1/E2/E3/F1/F2 — **untracked, intactos. NO commitear sin autorización.**
- **Hallazgo S3** (sobre-corrige estructuras Q02/Q07) — candidato para iteración futura.
- Suite PC: 266 OK / 4 FAIL (preexistentes, fuera de alcance).

---

## 🔎 EVAL PC — Pasos 14A/15A (Fase 3 · selector quality-aware ADOPTADO · runtime congelado)

### Pedido del usuario
Separar el problema de **selección** del problema del **modelo**: (14A) ¿un juez LLM (phi3.5) discrimina gold vs distractor mejor que bge-m3? (15A) ¿señales de calidad multi-señal distinguen evidencia útil de pasajes ruidosos?

### Lo hecho
1. **Paso 14A** (`run-selector-model-PC.sh`, pool F2 congelado, 11 pares gold-vs-distractor): phi3.5 = **5/11** pair test (= bge), determinismo pares **9/11**, **14.3 s/pasaje**. phi recupera 13/97 gold vs bge 74/97 — **phi no supera a bge en ningún query → Rama B, sin 14B**. Fix OOM verificado: unload + `keep_alive=0` entre queries (memoria 11→8.6 GB, corrida completa sin errores).
2. **Paso 15** (`run-selector-quality-PC.sh`, S1 bge-m3 θ=0.55 · S2 especificidad · S3 estructura · S4 canonicalidad · S5 mtime · S7 concisión · MMR λ=0.7; pesos a priori; ablación M1→M4; gates hard/soft/rescue): **M3 (S1+S2+S3+S4) = 9/11 gold_over_distractor** (target ✓) · leak 0.325 · pRel 0.482 · attr 16/20. Gate soft colapsa (attr 1/20) → piso S1 esencial.
3. **Ventana de rescate (2b del usuario):** θ=0.55 cortaba el gold de Q08 (cos 0.5478) por 0.002 → `--rescue-low 0.545` = punto quirúrgico: **Q08-P_TERM_OPACITY atribuido (2/2)**, leak **0.242** (pasa gate ≤0.308), pRel **0.577**. Costo: Q07-2 perdido (colateral S3).
4. **Hallazgos** (documentados, no corregidos): S3 sobre-corrige estructuras (Q02 INFO-full.md:189 → Shizuku.md; Q07 scrcpy.md:37/README.md:73 → GameOptimization.md:54); lista de ruido S4 incompleta; piso S1 esencial.
5. Registrado en `EVAL-REGISTRY.md` (§14A, §15A) + specs a EJECUTADO. Commit **`77bf26a`** (9 archivos, path-limited FWD-safe) + push. Fix línea 396 (`run-selector-model-PC.sh`) verificado.

### Veredicto y estado
- **Selector adoptado: M3 rescue 0.545** — gold_over_distractor **5/11 → 9/11** · leak **0.425 → 0.242** · pRel **0.472 → 0.577** · attr 16/20 (no-regresión vs F2) · tokens ~5k. Determinismo G2 ✓ (`5ab74054f1d2dcde`).
- **Funnel F2 cerrado en los 2 casos target**: Q06 `FF_SEEN` ✓ (1/1) · Q08 `P_TERM_OPACITY` ✓ (2/2).
- Runtime intacto (`buffy-search.sh`/`buffy-router.sh`), EVAL `98a0e308…`, pool F2 congelado.

### ⏳ Pendientes
- **Artefactos Pasos 12/13 (autor anterior, NO de esta sesión):** `evidence-passage-DESIGN.md` (modificado), `passage-candidate-expansion-DESIGN.md`, `run-evidence-PC.sh`, `baseline-E1/E2/E3-evidence-PC-2026-08-12*.json`, `baseline-F1/F2-expansion-PC-2026-08-13*.json` — **untracked, intactos. NO commitear sin autorización.**
- **Próximo lógico:** integrar M3 rescue 0.545 con el pipeline real · o resolver hallazgo S3 · o siguiente fase.
- Suite PC: 225 OK / 5 FAIL (preexistentes, fuera de alcance).

---

## 🗂️ buffy-context tooling (2026-08-12 · opencode / FreeBuff)

### Pedido del usuario
Complementar las limitaciones de FreeBuff (memoria, MCP, plugins) creando en buffy-context un registro MCP y un índice de skills; luego corregir el drift del README y loggear en la memoria de sesión.

### Lo hecho
1. **`MCP_REGISTRY.md`** (raíz de buffy-context): catálogo portátil de MCP — `codegraph` (AVAILABLE en OpenCode), `OpenRouter MCP` (remoto opcional), `mcp-cli` (puente shell para FreeBuff, que no expone MCP nativo en el build free). Incluye plantilla `.agents/mcp.json`.
2. **`SKILLS_INDEX.md`** (raíz de buffy-context): índice de los **43 skills reales** (`~/.agents/skills/`) por dominio con propósito + disparador (Android 12, Frontend 7, Workflow 7, Thinking 6, Research 6, Coding rigor 3, Meta 2). Cubre la ausencia de plugins en FreeBuff.
3. **README drift corregido**: "23 skills" → "43 skills" en 4 lugares. "19 files" de Knowledge confirmado correcto (19 contenido + Vision.md + README índice = 21).

### Veredicto
buffy-context ahora cubre Memoria + MCP + Plugins, client-agnostic (FreeBuff / OpenCode / futuro Buffy 10B local). Estos archivos son la "parte tuya" que se entrega al modelo.

### Fix posterior — el doctor no detectaba el drift de skills
- **Causa raíz**: `buffy-doctor.sh` compara el README contra `$REPO_DIR/.agents/skills` (copia del repo = **23 skills**), no contra el entorno real `~/.agents/skills` (= **43 skills**). Como el README decía "23", el doctor veía CONSISTENTE. El drift real era la copia del repo desfasada, no el número del README.
- **Parche** (`scripts/buffy-doctor.sh`, sección Skills): check #4 compara el conteo declarado en README vs `~/.agents/skills` (hubiera pescado el "23 vs 43"); check #5 avisa `REPO_SKILLS_STALE` cuando la copia del repo (23) está detrás del entorno real (43). Verificado: con README=23 el doctor ahora lanza `README_SKILL_COUNT_DRIFT`; con README=43 pasa y marca el repo como desfasado (warning, no error).
- **Resuelto (2026-08-12)**: sincronizado el repo a 43 — se copiaron los 22 skills faltantes desde `~/.agents/skills` y se eliminaron los 2 fantasma (`code-search`, `vision-adapter`) que no existen en el entorno real. README 23→43, doctor ahora `CONSISTENTE` (0 errores). Commiteado (`6ed1bb1`) y pusheado a `main`.

# 🧠 SESION — Buffy Freebuff (2026-08-14 · Rama X: query expansion H1 al pipeline real)

> Contexto de lo implementado durante esta sesión. Corrida en **Freebuff** (PC).
> Retomada del handoff: rama X del Paso 10 (expansión de query) integrada al pipeline
> real como opt-in; Q03 aceptado como límite documentado (granularidad, no modelo).

---

## ✅ Shizuku activado por ADB + protocolo de diagnóstico global (2026-08-14 · PC)

### Pedido del usuario
Activar Shizuku en el Mi 10 (HyperOS) tras reinstalar la app; luego documentar el
caso como ejemplo de mejora continua del sistema.

### Qué pasó
1. El agente perdió ~45 min intentando activar por UI (scroll, botones, buscar
   `start.sh`) sin diagnosticar. El usuario corrigió: el problema era batería/whitelist
   de HyperOS, NO el método de activación.
2. Aplicado el método oficial 13.6.0: fix de batería (whitelist + appops + standby)
   → copiar `libshizuku.so` a `/data/local/tmp/shizuku` → ejecutar → verificar con
   logcat `✅ Shizuku OK` (NO con `rish id`, que devuelve `uid=2000(shell)` normal).
3. Shizuku activo (servidor 22501, 12 apps, logcat OK).

### Mejoras de sistema (ciclo completo)
- **Skill `shizuku-rikka`**: sección "🧭 ANTES DE ACTUAR" al inicio + protocolo en
  `shizuku-activation-protocol.md`.
- **Regla global `~/.AGENTS.md` §43**: "Diagnóstico antes de actuar (Android)" para
  todas las skills de Android.
- **Caso de éxito** en `SHIZUKU-RISH-BUG.md` (Actualización 5).
- **Verificación en vivo**: simulación "teléfono no responde tras reiniciar" → el
  agente aplicó el protocolo sin tocar la UI (diagnóstico 10s, todo OK).

### Pendientes
- Si el teléfono se reinicia, re-ejecutar `/data/local/tmp/shizuku` (el servidor no
  sobrevive reinicios sin root).
- ChatGPT Desktop v42.3.0: prueba funcional de Codex en la UI (dropdown no OCR-able).

---

## 🚀 Rama X — query expansion H1 al pipeline real · Q03 aceptado como límite (2026-08-14 · Freebuff)

### Pedido del usuario
Retomar lo pendiente del handoff: Q03 gap semántico (rama X del Paso 10). El plan
era portar `expansion_terms` + `DICT_H1` del runner al pipeline real, flag opt-in
`--expand-query` en `search --select`, validar en vivo si Commands.md:64 entra al top-K.

### Lo hecho
1. **`scripts/lib/expand_query.py` (NUEVO)** — DICT_H1 + `expansion_terms` + `tokenize_significant` + `dict_hash`, portados del runner del Paso 10. **Fidelidad 10/10** vs baseline-H1 congelado (los términos de las 10 queries del EVAL coinciden exactamente).
2. **`buffy-search.sh --expand-query` (opt-in, default OFF)** — dos mecanismos: (1) **X-candidatos**: re-consultas FTS5 por término del diccionario → hits extra al pool (tope 100 declarado, gate ≥1 token por construcción OR); (2) **X-query**: los términos se pasan como `--terms` al selector → S1 (bge-m3) puntúa con la query expandida. También activable con `BUFFY_EXPAND_QUERY=true` (para `router --context`).
3. **`buffy-selector.sh --terms`** — inyecta los términos en la query del S1 (el motor ya los soportaba en su JSON de entrada).
4. **Tests (+13 checks)** — `test-expand-query.sh`: fidelidad vs runner H1, dict_hash estable, no-regresión del default (byte a byte), degradación sin Ollama (exit 3 limpio), pool crece con X-candidatos (15→91), smoke Q03. **Suite: 283 OK / 4 FAIL full · 267 OK / 4 FAIL --quick** (4 preexistentes: 3 × test-scale ruta Termux + 1 × skills sin manifest).
5. **Smoke Q03 medido:** Commands.md:64 ENTRA al pool (15→91) y su S1 mejora con la expansión (**0.468 → 0.493**) pero NO cruza el piso rescue 0.545 → sigue fuera del top-K de M3.

### 🔎 Hallazgo: la granularidad del pasaje, no el modelo
Medición fina sobre el gold (Commands.md:64, `gh pr create`): la **línea exacta cruza el piso (0.613** con términos relevantes **)**, pero la **ventana ±4 la diluye (0.493)** — 5 comandos `gh` vecinos. El cuello de botella es **PAS_PAD=4** (granularidad del pasaje), no el embedding. Con el símbolo exacto: 0.873.

### Veredicto del usuario (2026-08-14)
- **A) Bajar el piso 0.545→0.490: DESCARTADO** — contradice la evidencia 15A (soft gate colapsa attr 1/20) y la decisión 2b del piso quirúrgico.
- **B) Otro embedding: DESCARTADO por ahora** — la línea exacta ya cruza; no arreglaría la dilución por ventana.
- **C) Q03 como límite documentado: ADOPTADO** — la rama X queda como componente opt-in (mejora generación + S1, no rompe nada).
- **Dirección futura:** granularidad alternativa de pasaje (línea exacta o ventana 1/2) para golds de código, con su propio gate (leak ≤0.308, pRel ≥0.121) — sin tocar el piso ni el modelo.

### Commits
- `210b871` feat(selector): rama X del Paso 10 al pipeline — query expansion opt-in (`--expand-query`)
- `16c626b` docs(evals): Q03 aceptado como límite documentado — veredicto rama X (granularidad, no modelo)

### ⏳ Pendientes
- Push de `210b871` + `16c626b` (vienen con el cierre de día).
- **Q05 `useState` (s1=0.4646):** misma raíz que Q03 (granularidad del pasaje en golds de código) — candidato para la iteración de granularidad futura.
- Dirección futura: experimento de granularidad de pasaje (con gate propio).

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

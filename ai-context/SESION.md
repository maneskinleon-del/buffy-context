# 🧠 SESION — Buffy Freebuff (2026-08-15 · cierre serie 17: Commit A + 17D STOP/NO EVALUADO)

> Contexto de lo implementado durante esta sesión. Corrida en **Freebuff** (PC).
> Cierre de la serie 17B→17C→17D: Commit A de infraestructura pusheado, spec 17D
> congelada y sanity con STOP por drift del corpus (T nunca evaluado).

---

## ⛔ 17D cerrado — STOP metodológico / NO EVALUADO · Commit A pusheado (2026-08-15 · Freebuff)

### Pedido del usuario
Cerrar la serie experimental con disciplina: (1) verificar y cerrar el Commit A
(infraestructura), (2) diseñar 17D (V1 + DICT_H1_B) con gate propio, (3) correr
SOLO los sanity checks y parar si algo no reproduce exactamente — sin ejecutar T.

### Lo hecho
1. **Commit A `abbee6d`** — los 22 `skill.yaml` untracked eran manifests legítimos
   (prioridad B2, exigidos por `skill-lint.sh --require-all`), 2 fixes de SKILL.md
   (frontmatter name sin comillas) y `test-scale.sh` (ruta Termux → `${TMPDIR:-/tmp}`).
   Con README actualizado: **suite 313 OK / 0 FAIL full · 297 OK / 0 FAIL --quick**
   (los 4 FAILs preexistentes documentados en CONTINUE.md, ninguno de runtime).
   **PUSHEADO** a origin/main (f375868..abbee6d).
2. **Spec 17D congelada `ad04631`** (`combine-17D-DESIGN.md`) — T = V1+B como único
   tratamiento, controles A/B-solo/V1-solo, gate por contrato §17.4, **sanity de
   igualdad EXACTA per-query** (ajuste del usuario: todas las métricas contractuales,
   no solo attr+leak; `determinism_hash` histórico NO comparable por commit_sha/corpus_hash).
   Ceguera metodológica: no nace como "V1+B dará 13/20 y 0.250".
3. **Sanity ×2 G2 (6 corridas)** bajo corpus nuevo `029ed669` (7803 líneas, vs
   `236a87fa` de 17C con 7653):
   - **A**: attr 12/20 ✅ · leak **0.425 ≠ 0.442** ❌ · pRel 0.415 ✅ · contain 1.0 ✅
   - **B-solo**: attr 13/20 ✅ · leak **0.425 ≠ 0.442** ❌ · pRel 0.531 ✅
   - **V1-solo**: attr 12/20 ✅ · leak 0.250 ✅ · pRel **0.581 ≠ 0.584** ❌
   - G2 interno ✅ en los 3 (determinista; A difiere solo en hash por cache-hit).
4. **STOP según regla §3.1** — el drift real del corpus (README/CHANGELOG/CONTINUE/
   SESION crecieron entre 17C y 17D) alteró Q10 (leak 0.5→0.333, pRel 0.333→0.300)
   y Q03 (ctx_size 2→3). **T = V1+DICT_H1_B NUNCA se ejecutó.**
5. **Cierre `932f146`** — veredicto en EVAL-REGISTRY §17D: STOP metodológico / NO
   EVALUADO + los 6 JSONs de sanity como evidencia. No se re-congela `029ed669` ni
   se actualizan esperados retrospectivamente (decisión del usuario).
6. **Hallazgo estructural:** el corpus de Buffy NO está aislado de su propio estado
   operativo (CHANGELOG/CONTINUE/SESION participan del fenómeno medido) → conecta
   con el frente arquitectónico SESION/CONTINUE local. Continuar exige diseñar un
   **fixture/corpus experimental congelado e inmutable** (trabajo nuevo, no 17D).

### Estado
- Serie: **17B PASS exp / NO ADOPTED · 17C PASS primario / NO ADOPTED · 17D STOP / NO EVALUADO**.
- Evidencia en `EVAL-REGISTRY.md` (§17B, §17C, §17D) + `combine-17D-PC-2026-08-15-*.json`.
- Commits: `abbee6d` (pusheado) · `ad04631` (spec 17D) · `932f146` (cierre 17D, local).
- Working tree limpio. Suite PC: 313/297 OK.

### ⏳ Pendientes para otra sesión
- **Decidir si diseñar el fixture/corpus experimental congelado e INMUTABLE** antes de
  abrir otra serie (aislar el corpus del estado operativo mutable). Ver CONTINUE.md.
- **SESION/CONTINUE local** = frente arquitectónico independiente (no mezclar con evals).
- Auditoría pendiente: `AUDITORIA-HANDOFF-FREEBUFF.md` (skill handoff vs Freebuff).
- Push pendiente: `ad04631` + `932f146` (se suben con el cierre de día).

---

## ✅ 17C ejecutado y cerrado — reducción del leak estructural del pool (2026-08-14 · opencode)

### Pedido del usuario
Ejecutar el experimento 17C (spec congelada `leak-17C-DESIGN.md`): caracterización
causal del leak (31 paths: A=noise de sesión 55%, B=CHANGELOG 19%, C=Knowledge no-gold
16%, D=raíz no-Knowledge 10%) con 3 variantes de 1 factor: V1=exclusión dura de noise,
V2=refuerzo S4, V3=exclusión raíz no-Knowledge. Gate §17.4: leak ≤ 0.308 PRIMARIO,
attr ≥ 13, sin regresiones, pRel ≥ 0.121, contain ≥ 0.80, G2.

### Lo hecho
1. **Runner `run-leak-17C.sh`** (copia del mecanismo 17B + `--variant {A,V1,V2,V3}`).
   Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, piso 0.545, LIMIT=10, sin oráculo.
   Corpus congelado `236a87fa` (7653 líneas), `eval_hash 98a0e308…`,
   `commit_sha 51b8079…`, `h1_dict_hash 8294f200…` (DICT_H1 de 17B-A).
2. **7 corridas completas** (~45-49s c/u con índice cacheado): control-A + V1×2 + V2×2 + V3×2.
   **G2 confirmado en las 3 variantes** (JSONs idénticos per-query; determinism_hash
   A=`0d44653e`, V1=`289f8470`, V2=`0c471a33`, V3=`48888238`).
3. **Hallazgo de instrumento:** `--repeat` es vestigial (se parsea pero no se usa en
   loop) — G2 = invocar el runner 2 veces con distinto `--out` (igual que 16B/17B).

### Resultados (pad 4, A vs V1/V2/V3)

| Métrica | A | V1 | V2 | V3 | Gate §17.4 |
|---|---|---|---|---|---|
| **leak** | 0.442 | **0.250** | 0.442 | 0.433 | **✅ V1 ≤0.308** |
| attr total | 12/20 | 12/20 | 12/20 | 12/20 | ❌ (≥13) |
| pRel | 0.415 | **0.584** | 0.415 | 0.421 | ✅ ≥0.121 |
| containment | 1.0 | 1.0 | 1.0 | 1.0 | ✅ ≥0.80 |
| determinismo G2 | — | V1r1=V1r2 | V2r1=V2r2 | V3r1=V3r2 | ✅ |

### Veredicto
- **V1 CRUZA el objetivo PRIMARIO** (leak 0.442→0.250, -43%; pRel +41%; cero
  regresiones; G2) — la fuente A (noise de sesión) era la causa dominante del leak.
  **PERO attr = 12/20 < 13/20** (gate #2): V1 no incluye DICT_H1_B → Q05 sigue en 0.
  **NO adoptado** (no se modifica el gate retrospectivamente). V1 = candidato
  positivo/no adoptado (igual que B en 17B).
- **V2 SIN EFECTO** (idéntica a A: el peso S4 no cambia el ranking cuando s1/s2/s3
  dominan — la fuente A entra por el gate S1 ≥ 0.545, no por el score final).
- **V3 EFECTO MÍNIMO** (leak 0.433; fuente D solo 10%).
- **Próximo frente: 17D = V1 + DICT_H1_B combinados** (ortogonales: V1 mata el leak
  en ensamblado, B rescata Q05 en ranking) — requiere diseño y gate propios +
  aprobación del usuario. Alternativa: volver a Q01 con puente conceptual/relacional.

### Revisión de arquitectura (pedido del usuario: separación proyecto/instancia)
- `buffy-memory-sync.sh` sincroniza SOLO `MEMORY.md`/`USER.md` vía repo
  `ai-context/memories/`; `.sync-state` es perfil-local (NUNCA versionado) ✅.
- `SNAPSHOT.md` y `facts.yaml` YA están en `.gitignore` (perfil-local) ✅.
- **Problema real:** `SESION.md` y `CONTINUE.md` SÍ están versionados → con N
  dispositivos, contaminación + conflictos. Solución propuesta: hacerlos locales
  (como SNAPSHOT) — **decisión de diseño, requiere aprobación del usuario, NO
  implementada**.

### Commits
- `51b8079` — spec 17C congelada (ya pusheado).
- Pendiente: runner + JSONs + EVAL-REGISTRY + cierre (este commit).

### ⏳ Pendientes
- **Decisión del usuario:** ¿proseguir 17D (V1 + DICT_H1_B)? ¿implementar la
  separación SESION/CONTINUE → local?
- Untracked `.agents/skills/*/skill.yaml` (ajenos a 17C) — NO commitear sin
  confirmación.

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

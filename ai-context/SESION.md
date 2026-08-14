# 🧠 SESION — Buffy opencode (2026-08-13 · EVAL PC Fase 3 — Pasos 14A/15A: phi3.5 descartado → Rama B · M3 rescue 0.545 ADOPTADO)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (PC).
> Compactación 2026-08-13: entrada de hoy + 2 de 2026-08-12; Fases 1-2-3, Pasos 5/6/6b/7 y sesiones anteriores archivadas en SESION-archive.md.

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

---

## 🔎 EVAL PC — Pasos 7→10B (Fase 3 · runner experimentales · runtime congelado)

### Pedido del usuario
Aprobar/implementar/medir los experimentos de Fase 3 del EVAL PC uno a uno, con gates pre-fijados, determinismo G2 y sin tocar runtime; detenerse tras cada medición.

### Lo hecho (serie completa A→R2 en `scripts/tests/evals/EVAL-REGISTRY.md`)
1. **Paso 7 — Semantic D** (`run-semantic-PC.sh` + `bge-m3` vía Ollama): D = 0.200/0.192/0.669/48k. **Descartado**: el embedding aporta capacidad de recuperación que el léxico no tiene (Q06 resuelta por primera vez) pero sin precisión de buscador final; Q03/Q08 siguen sin resolver.
2. **Paso 8 — Hybrid bounded** (`run-hybrid-PC.sh`, pool L∪S, RRF y POOL): E/F ≈ 0.200/0.185/0.605/~10k. **Descartado**: redujo 4.8× el coste de D pero no recuperó calidad de contexto; G-H0 demostró que Q03/Q08 ni siquiera entraban al pool (fallo de generación, no de fusión).
3. **Paso 9 — Passage retrieval** (`run-passage-PC.sh`, G1-VENTANA ±4 / G2-SECCIÓN): G1 = 0.417/0.072/0.606/2.6k/0.8 · G2 = 0.333/0.054/0.606/3.4k/0.7. **Gate ❌ pero hipótesis ✅**: archivo completo (Q04/Q06 = 14.4k tok) → pasajes (310-505 tok) = reducción 28-46×. Dedup corregido de (path) a (path,rango). Problema restante: selección del pasaje correcto (Q08 llega al pool/top-10 pero no el gold; Q03 out_of_pool).
4. **Paso 10 — Query expansion** (`run-expansion-PC.sh`, rama X aditiva H1-DICT-MIN/H2-DICT-FULL congelados con hash): H1 = 0.317/0.064/0.616/2.45k/gap 5/6 · H2 = 0.367/0.064/0.621/2.45k/gap 6/6. **Caso D confirmado**: candidate gap CERRADO (Q03 `gh pr create` entra al pool vía X `push`/`create` — diccionario genérico) pero todas las agujas quedan `in_pool_ranked_out` rank 50-132 → generación resuelta, selección rota. Regresión 9/12 (pool 1071-1364 hits X inunda el RRF). **H1/H2 no adoptados.**
5. **Paso 10B — Reranking** (`run-rerank-PC.sh`, pool H2 CONGELADO y verificado == H2, señales normalizadas [0,1] pesos 1.0, `curated` estructural sin gold, ablación obligatoria): **R1-LEX = 0.750** (récord serie, 2.0× sobre H2) / pRel 0.175 / leak 0.441 / 1 903 tok / gap_to_top10 4/6 / regresión 0.167. R2-LEX+SEM = 0.700 / 0.131 / 0.502 / 2 169 / gap 2/6 / 0.083. **El cuello de botella ERA el ranking** (mismo pool, solo cambió el orden). Ablación: `x_overlap` = señal crítica (sin ella gap 0/6); `curated` aporta 2/6; `q_overlap` crudo ESTORBA (r1_no_q_overlap 5/6); el embedding empeora incluso como señal subordinada (r2_no_sem 4/6 > r2_full 2/6). **R1/R2 no adoptados** (fallan pRel/leakage → falta capa quality-aware).

### Veredicto y estado
- Serie: A 0.000/0.533/0.267/5.2k · G1 0.417 · H2 0.367 · **R1 0.750**. Ninguna variante pasa el gate completo. Fase 3 sigue abierta.
- **Mapa de capas**: candidate generation ✅ (expansion 6/6 techo) · passage granularity ✅ (28-46×) · context-size ✅ · **ranking/selection 🔴 = cuello de botella actual**.
- Commits: `8677347` (Paso 8) · `7595428` (Paso 9 cerrado + diseño 10) · `0aaa46f` (Paso 10 ejecutado) · `a778080` (Paso 10 cerrado + diseño 10B) · `18df679` (Paso 10B ejecutado).
- Runtime intacto (`buffy-search.sh`/`buffy-router.sh` intactos), EVAL congelado `98a0e308…`, determinismo G2 OK en todas las variantes.

### ⏳ Pendientes
- **Diseñar el Paso 11 — reranking quality-aware / passage selection** (próximo experimento, sin implementar todavía): la evidencia de R1/R2 (pRel 0.175/0.131, leak 0.441/0.502) indica que falta una capa que seleccione por calidad de evidencia, no solo por similitud; Q03 llegó a rank 12 (casi completa la cadena expansion→candidate→rerank→passage→context).
- Handoff completo en `/tmp/handoff-buffy-2026-08-12.md`.


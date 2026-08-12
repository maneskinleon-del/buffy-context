# 🧠 SESION — Buffy opencode (2026-08-12 · EVAL PC Fase 3 — Pasos 7→10B ejecutados y cerrados: Semantic ❌ · Hybrid ❌ · Passages ✅hipótesis · Expansion ✅gap · Rerank R1 récord 0.750 → cuello de botella = ranking)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (PC).
> Compactación 2026-08-12: entrada de hoy + handoff; sesiones 2026-08-10 y anteriores archivadas.

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

## 🔬 Fases 1-2-3 del benchmark realista (buffy-context)

### Pedido del usuario
Aprobar/avanzar las fases del benchmark realista contra el hallazgo `search_recall = 0.000` (FTS5 AND) y el router débil (`router_recall ~0.225`).

### Lo hecho
1. **Fase 1 — Search mejorada** (`buffy-search.sh`): `BUFFY_SEARCH_STRATEGY` (default `and` = baseline byte a byte) con `or` = deacent + lowercase → términos ≥3 chars sin stopwords ES (~70) → máx 8 → `"t1" OR ...` + BM25 → top-K. Corrección del usuario: términos ≥3 chars (ADB/API/Git/SSH/CPU/DPI/VLM/APK/USB son valiosos; ≥4 los descartaba).
2. **Medición Fase 1 (3 seeds × and vs or)**: search_recall **0.000 → 0.736** · context_relevance → 0.505 · leakage +0.031 · token ×4.4 · latencia +52 ms · **controles router/multi EXACTOS** → aislamiento demostrado (el 0.000 era el AND absoluto, FTS5 exonerado) → **Fase 2 habilitada**.
3. **3 fixes de exactitud del benchmark**: router miraba CWD no repo (contaminaba Node espurio) → `$REPO_DIR`; corpus de visión path plano vs anidado → `knowledge_dir: ""` + fallback basename; `search_recall` contaba no-gold → `|recov ∩ gold| / |gold|`.
4. **Fase 2 — diagnóstico del router** (modo `--diagnose`, report-only): ejecutado 14 multi × 3 seeds = **42/42 invariante**, matriz por query (23/42 sin señales · react 0/22, code-search 0/13, git 0/6, vision 0/4 = cero detecciones · rom 9ok/4bad). **Veredicto usuario 🟢 aprobado.**
5. **Fase 3 — spec v2 APROBADA** (selector híbrido router léxico + evidencia de Search): gates G-R1..R6 con δ pre-fijado, regla de descarte §4.4, promoción score_d ≥ θ_c, barrido presupuesto, `BUFFY_SELECTOR=lexical` default. **Paso 1 HECHO: EVAL congelado** (`eval-set.json` 10 queries sha256 180e14a0… + `dev-set.json` 12 sha256 0cd8d5a6…). **Siguiente: paso 2 (baseline re-congelada 3 seeds × {and,or}) → paso 3 (V1).**
6. **Reglas de arquitectura registradas** (CORE/ADAPTATION/TEST/RESEARCH + aislamiento dispositivo↔usuario) en `~/AGENTS.md` y spec §11.
7. Suite: **246/246 full (241 functional + 5 meta) · 230 --quick**. Informes: `/sdcard/Download/informe-benchmark-realista.txt`, `/sdcard/Download/diagnostico-router-fase2.txt`.

### ⏳ Pendientes para otra sesión
- **Fase 3 paso 2**: baseline re-congelada 3 seeds × {and,or} → paso 3: V1 del cap-selector híbrido.
- En el PC: tras `git pull`, `buffy-memory.sh sync pull` UNA vez.
- P1: retorno del aprendizaje · P2: concurrencia 3+ escritores · Opcional: `Knowledge/Tools/Buffy-Memory.md` · Revisar `~/gscript-audit/sin_titulo_1/`.

---

## 🔎 EVAL PC — Pasos 5 y 6 (auditoría de gold + fixture corregido)

### Paso 5 — Auditoría de gold/cobertura de evidencia (COMPLETADO)
- **Q04 — gold DEFECTUOSO (crítico):** `gold_files=[System.md]` pero `xset -dpms`/`xset s off`
  NO existen en System.md (viven en CONTINUE.md:405, CHANGELOG.md:203, SESION-archive.md:1970).
  search_recall de Q04 = 0 por construcción del fixture, no por fallo del buscador.
- **Q06 — gold PARCIALMENTE defectuoso:** `FF_SEEN` no está en ningún gold file declarado;
  vive en CONTINUE/CHANGELOG/SESION. `com.dts.freefireth` sí está en scrcpy.md:57.
- **Q03/Q08 — gold CORRECTO pero puente léxico roto:** agujas SÍ en archivo gold pero la línea
  gold comparte 0-1 tokens con la query (`git push origin` overlap NINGUNO; `picom` NINGUNO).
- **Q01/Q02/Q05/Q07/Q09/Q10 — gold correcto.** Conclusión: problema MIXTO (2/10 fixture,
  Q03/Q08 puente semántico/técnico). Detalle en EVAL-REGISTRY.md → Paso 5.

### Paso 6 — Fixture gold corregido + A/B/C regenerados (COMPLETADO, instrumento v3)
- **Fixture:** Q04 → gold `ai-context/CHANGELOG.md` (fuente real, línea 203); Q06 → `CHANGELOG.md`
  añadido (FF_SEEN, línea 186). Nuevo hash `00852568…`. Solo `evidencia real → gold correcto`.
- **Instrumento v3:** `EVAL_HASH` actualizado + leakage ya no penaliza archivos gold.
- **Resultados (gold corregido):** search_recall **A=0.000 / B=0.050 / C=0.100** · other
  0.000/0.200/0.100 · context_relevance 0.600/0.202/0.355 · leakage 0.267/0.694/0.522 ·
  token 5 069/44 846/37 547 · router Δ=0.
- **Hallazgo clave:** **Q04 era 100 % fixture, no retrieval.** and-norm SÍ recupera
  `xset -dpms`+`xset s off` como gold con el fixture corregido → invalida parcialmente la
  conclusión del Paso 4 ("and-norm no captura el puente léxico").
- **Retrieval restante (con gold correcto):** Q03/Q08 puente semántico/técnico real; Q06
  ranking trae CONTINUE.md y no scrcpy.md, FF_SEEN no se recupera ni siendo gold.
- **No se adoptó ninguna variante.** Runtime congelado. Artefactos v3:
  `baseline-and/or/and-norm-PC-2026-08-11.json`. Detalle en EVAL-REGISTRY.md → Paso 6.
- **Siguiente:** decisión del usuario sobre el próximo experimento (¿Hybrid?) con gold corregido.

---

## 🔎 EVAL PC — Paso 6b (auditoría Q06 + gold definitivo) y Paso 7 (diseño)

### Paso 6b — Auditoría específica de Q06 (COMPLETADO)
- **Veredicto:** `scrcpy.md` NO contiene evidencia equivalente de `FF_SEEN` (solo
  `com.dts.freefireth:57` en diagnóstico de lag — paquete tangencial, no el hecho
  evaluado). La evidencia real vive en CHANGELOG.md:186, CONTINUE.md:448 y el script
  real `~/scripts/scrcpy-freefire.sh:272-276` (fuera del corpus).
- **Gold definitivo Q06:** `gold_files=[ai-context/CHANGELOG.md]`,
  `gold_facts=[FF_SEEN]`. `com.dts.freefireth` quitado del gold.
- **Fixture actualizado** (hash `98a0e308…`) + runner v3.1 + **A/B/C regenerados**:
  search_recall 0.000/0.050/0.100 · other 0.000/0.150/0.050 · context_relevance
  0.533/0.182/0.333 · leakage 0.267/0.694/0.522 · token 5 197/45 259/38 017.
  Nota: router_precision 0.667→0.600 por variabilidad de entorno (router no lee fixture).

### Paso 7 — Experimento semántico diagnóstico (DISEÑADO, pendiente aprobación)
- **Spec:** `scripts/tests/evals/semantic-retrieval-DESIGN.md`.
- **Pregunta:** ¿un retrieval semántico recupera Q03/Q06/Q08 sin el leakage/coste de OR?
- **Invariantes:** MISMO EVAL/gold/limit/métricas. UNA variable: lexical → semantic.
- **Enfoque:** Ollama local (ya instalado) + `bge-m3` (multilingüe, default) o
  `nomic-embed-text` (sanity). Embeddings por línea → coseno → top-LIMIT. Runner nuevo
  `run-semantic-PC.sh` — NO toca runtime.
- **Gate pre-fijado:** search_recall > 0.100 · context_relevance ≥ 0.600 · leakage
  ≤ 0.267 · token ≤ ~2× A · determinismo · mismo EVAL hash.
- **NO adoptar todavía** — experimento diagnóstico; veredicto = usuario.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · revisión: sync sin ruido git + pendientes router multi-dominio)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode** (teléfono).

---


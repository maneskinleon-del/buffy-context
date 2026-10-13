> ⚠️ **Poda automática**: Cuando este archivo supere ~30KB o ~5 entradas
> recientes (sin contar archive), las entradas más viejas se mueven a
> `CHANGELOG-archive.md`. Última poda: 2026-08-03 (entradas 2026-07-31 y
> anteriores archivadas; front-matter duplicado eliminado).

---

version: 1.9
updated: 2026-10-13
schema: system-profile
system-id: buffy-desktop
---

# CHANGELOG.md — Historial de cambios del sistema

### 2026-10-13 — Release v1.1.0

**Cambios incluidos** (commits desde `v1.0.1`):
- chore(git): *.local.md al gitignore — los overrides nunca viajan al artefacto
- feat(project-state): Paso 5 — motor + linter con matriz de 45 checks (suite 508/0)
- docs(skill): modo-autonomo — conteos reales de suite (54 → 395/411) + semver 1.0.1
- docs(project-state): diseño del esquema y del motor (Pasos 2-3)
- test(helpers): los checks muestran diagnóstico en fallo (C-1)
- fix(memory): los lectores rechazan un store ilegible (B-3)
- fix(source): JSON válido con valores especiales en --resolve (B-1)
- docs(instancia 9): registrar el incidente del connector — push exitoso ≠ remoto sano
- fix(lint): cierra el false-green de skill-lint y restaura README/test
- fix: prevent skill lint false-green
- fix: prevent skill lint false-green
- fix(search): REVIEW-BASELINE.md fuera del find_scope — indexar un documento que se actualiza solo perturbaba el gate de corpus
- fix(scripts): los 3 scripts sin guarda quedan seguros bajo modo estricto — sin activarlo
- fix(guard): las exclusiones del PII son por patrón, no globales — tapaban email y nombre reales en evals/
- feat(skills): origin obligatorio en los 44 manifests — la procedencia tiene que ser visible cuando el nombre colisiona (D2.3)
- refactor(identity): D2.1 — el repo declara identidad de sistema y el alias personal entra al guard PII
- fix(tests): el test de /tmp read-only reportaba FAIL cuando unshare no puede crear namespace [verificado 2026-10-02]
- fix(tests): el test de /tmp read-only se auto-saboteba cuando el repo vive bajo /tmp [verificado 2026-10-02]
- fix(doctor): SKILLS_INDEX.md era catálogo oficial pero no contaba como fuente [verificado 2026-10-02]
- fix(scripts): /tmp hardcodeado hacía que buffy-selector periera su RC en Termux [verificado 2026-10-02]
- fix(skills): 6 manifiestos eran YAML inválido y el linter los aprobaba [verificado 2026-10-02]
- docs(pii): decisión de identidad — aceptar linkage en metadata [verificado 2026-10-01]
- fix(tests): gate corpus_frozen_ok re-apunta al corpus congelado post-rewrite 40dd565 [verificado 2026-10-01]
- fix(hooks): pre-commit aísla la suite de GIT_INDEX_FILE [verificado 2026-10-01]
- docs(taxonomía): instancia 5 reformulada — fidelidad de vista (5a/5b/5c)
- feat(c5): corpus sanitizado — guard PII cubre evals/ sin exclusión (0 absoluto)
- docs(changelog): cierre C4-B — Patrón B, lecciones y números finales
- fix(tests): fixtures de verify self-contained — idempotentes ante Patrón B
- docs+fix: nota del Patrón B en LOAD_CONTEXT + overlay de untracked en ci-sim
- feat(c4): Patrón B — override .local con regla única en resolve-path.sh
- docs(changelog): entrada de la convención de autoría (CONTRIBUTING)
- docs: registrar convención de autoría en commits (agentes co-autores)
- docs(taxonomía): precedente buffy ctx en P3 + carácter de los principios
- docs(changelog): normalizar referencias a la numeración canónica
- docs(taxonomía): numeración canónica de instancias + Principios operativos
- docs(changelog): bautismo del pre-push hook + lección de simulador
- docs: meta-momento 4 en la taxonomía — el hook pre-push se gateó a sí mismo
- fix(ci-sim): stdin cerrado en la suite — el hook heredaba las ref-lines de git
- fix(ci-sim): OLLAMA_URL muerta en la simulación — fidelidad al runner de CI
- feat(ci): ci-sim + hook pre-push + doc_truth anti-cascada (instancias 4b/6)
- fix(ci): lint/router/tests desacoplados del estado de instancia (INSTANCE-STATE §3)
- fix(ci): des-romper CI — gate corpus_frozen_ok + doctor tolera estado local + README 44 skills
- privacy(c3)+docs: estado de instancia a local + taxonomía señal-estado
- privacy(c2): redacciones A-list en HEAD + guard de regresión PII
- fix(sync)+privacy: guards anti-falso-éxito en sync push + canal privado de memoria (D0.1b Opción 1)
- fix(tests): Ollama fuera del camino crítico — probe de capacidad + techos timeout (preparatorio C1)
- fix(skills): android-package-origin-audit reproducibility + honestidad de clasificacion
- feat(skills): android-package-origin-audit (read-only)
- docs(changelog-archive): rotate SESION entries parte 7-8 and PR1 (from 2026-09-27 session)
- docs: convention case 7 (operator premise unverified) + PR5 changelog entry
- changelog: PR3+PR4 executed — H1-H8 cycle closed, suite 668/668
- changelog: PR2 executed — H2+H5 fixed, suite 654/654 (parte 9)
- changelog: PR1 executed — H4+H1b fixed, suite 648/648 (parte 8)
- changelog: src map H1-H8 — root causes, H7=(c), H3 retracted (parte 7)
- changelog: CLI surface round — 8 findings from direct standalone use (parte 6)
- changelog: Q2 handoff-timestamp rule + precision summary (parte 5)
- protocol: mandatory handoff cut-off timestamp (sender + receiver sides)
- checkpoint: dangling buffy-tools resolved — repointed + verified MCP handshake
- docs: precision C5-B — p=0.114 inconclusive, task-sensitivity only exploratory
- checkpoint: post-ciclo C5-B — anotación e438f29 aplicada (parte 3)
- changelog: C5-B round — buffy_context routing is task-sensitive (contract-correct)
- checkpoint: BUFFY-CURRENT-STATE.md v1.1 — sello de vigencia y estado real de la suite
- checkpoint: BUFFY-CURRENT-STATE.md v1 + convención [orig]/[verificado] en LOAD_CONTEXT
- checkpoint: GameBoostPro fix H6 pushed (073cea9 + evidence 65b4bab), session 2026-09-22
- docs(shizuku): consolidate reboot-persistence findings — token board through af14a39, boot-glue scope, autonomous recovery NOT_TESTED
- docs(shizuku): record watchdog v1 + failure storm + force-stop evidence — canonical token board through 075ff50
- docs(shizuku): record serial-change + watchdog v0 evidence — precise token board
- docs(shizuku): record LADB recovery evidence — functional recovery VERIFIED
- docs(shizuku): update shizuku-rikka recovery procedure
- docs(shizuku): close watchdog recovery evidence
- docs: preregister field ablation experiment
- feat(port): Production Port V1 + DICT_H1_B ADOPTED — §7.3 aplicado, §7.4 gate 8/8, §7.5 veredicto
- evals(port): paso §7.2 — sanity V1 sin gold_files PASADO (idéntico a 17E-T: attr 13/20, leak 0.307, pRel 0.630; ningún gold es noise)
- evals(port): paso §7.1 — baseline repo vivo ×2 G2 registrado (attr 12/20, leak 0.442, pRel 0.415, contain 1.0; reproduce 17B-A)
- docs(evals): Production Port Spec congelada — V1 + DICT_H1_B al pipeline (puntos de integración verificados, gate conservado, rollback, sin mejoras adicionales)
- docs(evals): CONTEXT-REQUIREMENTS — separar gate/objetivo/resultado-fixture/requisito-producción + auditoría reproducibilidad 17E
- docs(evals): spec de requisitos formales del motor de contexto — derivada de 17B/17C/17E (10/10 cumplidos por T)
- 17E infraestructura: orquestador + analizador + tests sin Ollama
- docs(evals): Paso 17E spec congelada — V1 + DICT_H1_B sobre fixture fx-2026-08-15-001
- docs(sesion): cierre de día 2026-08-15 — Fase D cerrada D0-D5 (infraestructura)
- docs(evals): Fase D5 — gate final PASADO, Fase D cerrada como infraestructura
- docs(evals): Fase D4 — validación multi-dispositivo PASADA
- feat(evals): Fase D3 — runner --fixture + barrera de mutación
- feat(evals): Fase D2 — fixture congelado fx-2026-08-15-001
- feat(evals): Fase D1 — build-fixture.sh + corpus_hash por contenido
- docs(evals): Fase D — diseño del fixture experimental congelado (spec congelada)
- docs(arquitectura): contrato sincronizado con la realidad de Fase B/C
- docs(instancia): Fase B — SESION/CONTINUE/SESION-archive pasan a estado local
- docs(arquitectura): contrato estado de instancia local vs compartido (INSTANCE-STATE-DESIGN)
- docs(sesion): cierre de día 2026-08-15 — handoff tras 17D STOP metodológico
- docs(evals): cierre 17D — STOP metodológico / NO EVALUADO (drift de corpus entre pasos)
- docs(evals): Paso 17D spec congelada — combinación V1 + DICT_H1_B con sanity de igualdad exacta
- fix(skills): cobertura completa de manifests skill.yaml + fixes de suite
- feat(evals): evidencia 17C — runner con --variant {A,V1,V2,V3} + JSONs G2 + veredicto
- docs(evals): Paso 17C spec congelada — reducción del leak estructural del pool
- feat(evals): evidencia 17B — runner con --dict (DICT_PATH) + JSONs A/B G2
- docs(eval): veredicto 17B — puente semántico PASS experimental / NO ADOPTED
- feat(evals): Paso 17 runner 17B (A/B DICT_H1) + variante B congelada + test sin Ollama
- docs(evals): Paso 17 spec congelada — experimento A/B del puente semántico (DICT_H1 actual vs variante acotada)
- docs(evals): Paso 17.1 diagnóstico del puente semántico — Q01/Q05 pierden señal en S1 con golds en pool
- docs(evals): sello de aprobación del usuario — 16B PASS experimental, granularidad descartada, ±4 conservado
- feat(evals): Paso 16B ejecutado — granularidad uniforme descartada (H16 confirmada); puente semántico H1 = límite
- docs(evals): Paso 16 corrección documental — 15B = diagnóstico con oráculo H2; baseline H1 11/20; retractación "Q03 es granularidad"; spec congelada 16B
- docs(handoff): auditoría pendiente para Freebuff — integración hooks/compaction
- docs(shizuku): caso de éxito activación ADB 13.6.0 — protocolo de diagnóstico global
- docs(evals): Paso 16 DISEÑO — granularidad del pasaje (spec para aprobación)
- docs(sesion): cerrar día — 2026-08-14
- docs(evals): Q03 aceptado como límite documentado — veredicto rama X (granularidad, no modelo)
- feat(selector): rama X del Paso 10 al pipeline — query expansion opt-in (--expand-query)
- docs(sesion): cerrar día — 2026-08-14
- feat(close-day): tarea "cerrar día+1" — buffy-close-day.sh --poweroff apaga el PC
- docs(sesion): handoff 2026-08-14 — V6 adoptado (15B), próximo: rama X Q03/Q05
- feat(selector): veredicto 15B — V6 (S3 condicionado a query + S4 clase sesión) adoptado
- docs(sesion): plan de retomar Q03 con rama X del Paso 10 (próxima sesión)
- docs(sesion): cierre 2026-08-14 Freebuff — Pasos 12/13 preservados (16739bc, sin push)
- docs(evals): preservar registro Pasos 12/13 (serie E/F del autor anterior)
- docs(sesion): cierre 2026-08-13 Freebuff — integración M3 + expansión F2 al pipeline real (Q08 cerrado)
- test(selector): regla de compresión para modo autónomo + test de fidelidad expand vs fixture
- docs(sesion): expansión F2 (rama P) al pipeline — candidate gap de Q08 cerrado en vivo
- feat(selector): expansión F2 (rama P) al pipeline — cierra el candidate gap de Q08 en vivo
- docs(sesion): integrar selector M3 al pipeline real — buffy-selector.sh + search --select + router --context
- feat(selector): integrar M3 rescue 0.545 al pipeline real — buffy-selector.sh + search --select + router --context
- docs(sesion): compactación 2026-08-13 — EVAL PC Pasos 14A/15A cerrados: phi3.5 descartado (5/11, Rama B) + selector M3 rescue 0.545 ADOPTADO (gold_over 5/11→9/11, leak 0.242, Q08-P_TERM_OPACITY atribuido, attr 16/20); hallazgo S3 documentado; artefactos 12/13 intactos y fuera de este commit (autor anterior)
- eval: Paso 14A ejecutado (phi3.5 no pasa gate -> Rama B, sin 14B) + Paso 15 M3 rescue 0.545 ADOPTADO
- eval: Paso 11 CERRADO (Q1/Q2 no adoptados; x_density != evidence_quality; tres conceptos found/selected/attributed) + Paso 12 DISEÑO evidence-aware passage selection — diagnóstico medido HOY sobre contexto R1: S1/S2 muertas (1.0x), S3 heading 17.7x (prec 1.0 rec 0.35), S4 bge-m3 cosine(pasaje, query+X) prec 0.867 rec 0.765 @ theta=0.55 (13 TP/2 FP) — la señal de calidad vive en el CONTENIDO; E1-S3/E2-S4/E3-S4+0.5S3, ablación por señal; tres conceptos separados por query; review: bug E3 corregido (ponderación medida, no 0.5/0.5) + riesgos declarados (sesgo theta, mismatch población, dict H2 techo) + pre-flight FWD
- eval: Paso 11 EJECUTADO — Q1-DEDUP/Q2-DEDUP+DENS no pasan el gate (pRel 0.118/0.066, leak 0.540/0.478) — medido en worktree aislado en 5e2e97c (incidente FWD: otra sesion modifico el corpus del EVAL entre R1 y el lanzamiento; D de control reproduce Paso 7); determinismo x2 (Q1 f0f398c5, Q2 e2a1821a); agujas_preservadas 6/6; Q03 resuelto, Q06 recuperado por Q2, Q04 regresion de ATRIBUCION en Q2; sRec = seleccion post-poda (instrumento pasajes, consistente G1->R1); review: 3 correcciones aplicadas
- docs(sesion): marca sync de skills 23->43 como resuelto y pusheado
- docs(design): FWD registrado en Roadmap Buffy 2.0 (punto 6, spec aprobada — implementación post-Fase 3; incidentes simétricos 2ca7fca/5596345 documentados)
- fix(skills): sincroniza .agents/skills a 43 skills reales y corrige drift del doctor
- docs(design): Foreign Worktree Detection (FWD) — spec Buffy 2.0 sin implementar (caso real 2026-08-12: OpenCode+Freebuff en el mismo checkout; señales S1-S6, manifest como corazón de la atribución, política detecta/clasifica/protege-nunca-adopta, gate pre-escritura con re-hash, commit selectivo propio OK, excepción adopción por decisión del usuario, alcance declarado: ignorados/symlinks/origin fuera)
- eval: Paso 10B cerrado (R1/R2 no adoptados; ranking = cuello de botella, calidad de contexto = problema dominante) + diseño Paso 11 quality-aware passage selection — evidencia medida: contexto R1 = 60 pasajes con solo 25% con aguja; q_hits/cmds INVERTIDAS (no usar como calidad); densidad evidencia X discrimina 2.7x (0.071 vs 0.026); dedup estructural elimina 28% sin perder agujas; variantes Q1-DEDUP (overlap>4 geométrico) y Q2-DEDUP+DENS (θ=0.050 a priori); gate 6 criterios + agujas_preservadas por-gold-fact
- docs(sesion): compactación 2026-08-12 — EVAL PC Pasos 7→10B cerrados (semantic ❌, hybrid ❌, passages ✅hipótesis, expansion ✅gap, rerank R1 0.750 récord → cuello de botella = ranking); siguiente: diseñar Paso 11 quality-aware
- eval: Paso 10B ejecutado — reranking sobre pool H2 congelado (R1=LEX 0.750, R2=LEX+SEM 0.700): sRec récord serie 2.0× sobre H2, gap_to_top10 4/6, leakage 0.441 — el cuello de botella ERA el ranking; ablación: x_overlap crítica (sin ella gap 0/6), embedding empeora como señal (r2_no_sem > r2_full); falla pRel/leakage, no se adopta
- eval: Paso 10 cerrado (H1/H2 no adoptados; generación resuelta 6/6, ranking = cuello de botella) + diseño Paso 10B reranking — overlap léxico query↔gold = 0 en 10/13 casos, señal de expansión X discrimina (Q10=5), curated vs ai-context para Q08; R1-LEX/R2-LEX+SEM con pesos 1.0 normalizados, pool H2 congelado, gate 6 criterios + baseline_regression
- eval: Paso 10 ejecutado — query expansion (H1=DICT-MIN 0.317, H2=DICT-FULL 0.367): candidate gap CERRADO (5/6 con diccionario genérico, 6/6 techo) pero todas las agujas quedan ranked_out — Caso D confirmado: generación resuelta, selección rota → 10B justificado; pRel/leakage fallan el gate, no se adopta
- eval: Paso 9 cerrado (G1/G2 no adoptados, passage-level validado) + diseño Paso 10 query expansion — candidate gap 100% recuperable léxicamente (6/6 agujas out_of_pool de G1, verificado); variantes H1-DICT-MIN (realista) vs H2-DICT-FULL (techo oráculo); gate 5 criterios + candidate_gap_recovery; lectura por capas (generación vs selección)
- eval: Paso 9 ejecutado — passage-level context selection (G1=VENTANA 0.417, G2=SECCIÓN 0.333): gold_containment Q04/Q06=1.0 y tokens ~2.6k resuelven el truncamiento del Paso 8, pero pRel/leakage fallan el gate — no se adopta; recall mejor de la serie
- eval: Paso 8 cerrado (E/F descartados) + diseño Paso 9 passage-level context selection (G1-VENTANA/G2-SECCIÓN, gate con gold_containment y passage_relevance, G-H0 re-derivado sobre pasajes)
- eval: Paso 8 ejecutado — Hybrid bounded (E=RRF, F=POOL): coste controlado (~10k tokens) pero relevance/leakage fallan el gate — no se adopta; G-H0 confirma candidate gap Q03 y recuperación parcial Q08 vía rama L
- eval: Paso 8 — diseño Hybrid bounded candidate retrieval (V1-RRF + V1-POOL, G-H0 pre-gate, sin implementar); Paso 7 cerrado con D descartado
- eval: Paso 7 — experimento semántico (D) ejecutado: bge-m3 + coseno, Q06 resuelto, gate falla (relevance/leakage/tokens) — no se adopta nada
- docs: roadmap Buffy 2.0 post-Fase 3 registrado (Router → Domain Agent → Skills → Context Pack)
- docs(memory): sync memoria curada desde localhost
- eval: Paso 6b — auditoría Q06 + gold definitivo + diseño Paso 7 (experimento semántico)
- eval: Paso 6 — fixture gold corregido (Q04/Q06) + A/B/C regenerados (instrumento v3)
- eval: Paso 5 — auditoría de gold/cobertura de evidencia completada
- eval: Paso 4 — AND normalizado ejecutado (instrumento v2, métricas crudas)
- eval: Paso 4 — diseño AND normalizado aprobado (sin implementar)
- eval: diagnóstico Q03/Q04/Q06/Q08 — patrón AND-falla/OR-acierta + artefactos cross-file
- docs(tests): Paso 3 — Baseline B (Search OR/BM25) sobre EVAL PC, medición cruda sin veredicto; runner parametrizado por estrategia; comparación A vs B registrada en EVAL-REGISTRY
- docs(tests): nota de estado de suite PC (5 FAIL preexistentes, fuera de alcance de la Fase 3) + veredicto Paso 2 aprobado y recomendación Paso 3 en CONTINUE
- docs(tests): Baseline A del perfil PC medida (Paso 2) — pipeline actual router→search sobre EVAL congelado, sin tocar runtime; runner run-baseline-PC.sh + baseline-A-PC JSON; agregado registrado en EVAL-REGISTRY y CONTINUE
- docs(tests): EVAL PC congelado y aprobado — eval-ctx-PC-2026-08-11 (10 queries, hash 8e42d119, perfil sabrewulf-a320ms2h) + EVAL-REGISTRY + .sha256; Paso 1 Fase 3 cerrado, baseline A pendiente de autorización
- docs(sesion): cerrar día — 2026-08-11 · Fase 1 medida + Fase 2 diagnóstica aprobada + Fase 3 spec v2 (EVAL congelado)
- docs: contrato del benchmark realista (B/C) — bench-realistic-DESIGN.md
- docs(memory): sync memoria curada desde telefono-mi10
- fix(memory): sync sin ruido git — estado .sync-state es local por dispositivo
- docs(memory): sync memoria curada desde telefono-mi10
- feat(close-day): buffy-close-day.sh — protocolo 'cerrar día' automatizado
- docs(memory): sync memoria curada desde telefono-mi10
- feat(memory): buffy-memory.sh sync — puente PC↔teléfono para la memoria curada (P0)
- docs(memory): sync memoria curada desde telefono-mi10
- docs(sesion): borrado de etiquetas implementado en organiza_gmail_V3 (cleanupLabels + applyCleanupOnce one-shot vía trigger); lección: token clasp sin scope de ejecución (404 en scripts.run)
- docs(sesion): recuperar sesión cortada — auditoría Apps Scripts con Google Studio API, pendiente borrado de etiquetas huérfanas en organiza_gmail_V3; verificado PC sin cambios nuevos (origin/main = b3cdd54)
- docs(sesion): cierre de día — data_car pusheado (aea4e15), SESION podada a 3 entradas (08-09 → archive), acuerdo 'cerrar día' registrado en CONTINUE como palabra de cierre
- docs(sesion): P1 data_car completado — precios de la IA asignados a la lista + total CLP en Mi compra; CONTINUE con ambos pendientes (P0 benchmark + P1) cerrados
- feat(bench): bench-context-selection.sh — pipeline completo router→search (P0, desbloquea el congelamiento)
- docs(sesion): reconstruir y registrar sesión 2026-08-10 — scripts Google Apps Script (Gmail Organizer V3 + Drive Organizer Pro) sincronizados con la web vía clasp, opencode actualizado a 1.18.16; la sesión previa no había quedado en buffy-context (hueco recuperado del historial de prompts)
- docs(sesion): cierre 2026-08-09 noche — evaluación Lyxel+Mantis (falsos caminos), lección retroalimentación activa registrada; SESION.md a 5 entradas, 2026-08-06 archivado; CONTINUE actualizado
- docs(knowledge): lección de retroalimentación activa — verificar que una herramienta cubre el caso de uso ANTES de instalarla (Mantis=gamepad no sirve para teclado/mouse; Lyxel Linux sin mapeador; APK parchado rompe Google Sign-In). GG Mouse Pro 2 confirmado como keymapper correcto
- docs(knowledge): corregir Mantis vs Octopus en keymappers — Mantis sigue activo (v3.4.8+, suscripción v3.x) y es NMC no-cloning (riesgo bajo); el baneable por clonación es Octopus. Paquete actualizado a app.mantispro.gamepad, activación on-device Wireless Debugging en Android 11+
- docs(sesion): registrar DECISIÓN DE CONGELAMIENTO en CONTINUE — buffy-context congelado hasta que bench-context-selection.sh justifique el próximo cambio (benchmark primero, feature después)
- docs(tests): quitar números obsoletos de los comentarios de test-documentation.sh — el anti-drift también vigila sus propios metadatos; los conteos son derivados dinámicamente, no se escriben a mano
- docs(sesion): cierre v2 2026-08-09 — paradoja del contador resuelta + benchmark adversarial; SESION/CONTINUE actualizados
- fix(tests): paradoja del contador anti-drift + RC muerto + benchmark adversarial — contador canónico functional/meta/total (doc_truth_check valida functional estable + total auto-contado); quitado || true que enmascaraba el exit code del benchmark; bench-scale.sh --adversarial con irrelevantes que comparten vocabulario (mide límite real de FTS5: recall 1/2 ante competidores léxicos, medición no gate); suite 205 OK (200 functional + 5 meta)
- docs(sesion): cierre 2026-08-09 — anti-drift documental + benchmark escala P0; SESION/CONTINUE actualizados
- feat(tests): anti-drift documental + benchmark de escala P0 — doc_truth_check deriva el conteo real de la suite y rompe el CI si el README desincroniza (verificado adversarial); bench-scale.sh siembra 500 hechos FTS5 (2 relevantes) y mide recall/contaminación/presupuesto de contexto; suite 202 OK (186 --quick)
- docs(sesion): cierre 2026-08-09 — adquisición memoria curada + fixes symlinks; poda SESION a 5 entradas (2 archivadas); CHANGELOG actualizado
- fix(scripts): resolver symlinks del PATH (readlink -f) en buffy-memory/context/router — los scripts fuenteaban lib/ desde ~/.local/bin y fallaban al invocarse por symlink
- docs(memoria): sincronizar versiones con sistema — kernel 6.18.42, node 26.7.0, npm 12.0.2 (detectado por buffy-source/buffy-verify, trust 100%)
- feat(memory): memoria curada estilo Hermes — buffy-memory.sh + memory_engine.py (brecha 2); doctor/LOAD_CONTEXT/AGENTS + tests; suite 196 OK
- feat(search): buffy-search.sh — índice FTS5 de sesiones/Knowledge (brecha vs Hermes); CONTINUE + CHANGELOG
- feat(shizuku): watchdog Termux sobre adb loopback 5555 + doc
- chore(sesion): entrada 2026-08-08 (opencode) — data_car lista de compra + buffy-context→opencode; poda SESION.md a máx 5, archivadas 11 sesiones; CONTINUE + CHANGELOG actualizados
- docs(shizuku): resuelto — revert a clásico RikkaApps funciona con rish -c; skill sin bitácora fechada
- docs(shizuku): limitante rish en fork Shizuku+ (attach rechazado) — volver a clásico; workaround AutoJS
- docs: Buffy también corre en opencode — actualiza identidad del agente en README, USER-MANU, INFO-core, LOAD_CONTEXT y skills (code-search, vision-adapter) para reflejar opencode + modelos free
- Sesión 2026-08-07 noche: scrcpy-freefire sin auto-open de Free Fire + purga 16 apps ZTE (69→53)
- docs(escritorio): super+Escape eliminado, DPMS off, monitor-alert CPU corregido + umbrales
- chore(scripts): marcar buffy-agent y buffy-repair como ejecutables (requerido por los symlinks del PATH)
- chore(housekeeping): gitignore __pycache__; sincronizar estado 2026-08-07 (rice vista, sesión, changelog)
- docs(CONTINUE): handoff 2026-08-07 — hallazgo del TTL (test adversarial → fix 890d5c6), jerarquía de fuentes (d4df1f9), fixes de CI (9d1208b, b2c43ba); corrige npm 12.0.1 → resuelve el conflicto que buffy-source detectaba
- fix(ci): assert de schema valida hechos presentes (cualquier level), no verified — en runners ajenos kernel/os salen stale y codegraph unknown; CI verde
- fix(ci): tests de verify auto-generan sus fixtures (facts.yaml y SNAPSHOT.md son gitignored y no existen en checkout fresco) — suite 168 checks verde en CI
- feat(source-hierarchy): buffy-source.sh resuelve el valor autoritativo de hechos (real-time > facts > SNAPSHOT > CONTINUE > INFO-core > inferred) con reporte de conflictos; detecta npm 12.0.1 vs CONTINUE 11.18.0; +4 tests; suite 168 checks
- fix(ttl): enforce TTL de facts.yaml previo — hechos vencidos reportados como expired (trust baja); hallazgo de test adversarial E2E; +3 tests; suite 164 checks
- hardening(facts_engine): comandos en lista, ejecución sin shell (shell=False) — reglas con metacaracteres son rechazadas; retrocompatible; +2 tests; suite 161 checks
- feat(fact-registry): reglas declarativas (facts_rules.yaml + facts_engine.py) — agregar hechos sin tocar el motor; kernel con stale real; scope+ttl en provenance; fixtures controlados de stale; suite 159 checks
- feat(provenance): buffy-verify.sh --update-facts genera ai-context/facts.yaml con source/confidence/status/verified por hecho; documentado en LOAD_CONTEXT (Paso 2.5); gitignored; +5 tests; suite 153 checks
- docs(INFO-core): reflejar realidad verificada por buffy-verify — rice vista (Windows Vista Aero), npm 12.0.1, quitar uv; fix parser rice en verify (tolera markdown y gh0stzk/nombre) → trust 100%
- feat(verify): buffy-verify.sh — validación factual de INFO-core.md vs sistema real (OS/kernel/WM/rice/herramientas/versiones); job verify informativo en CI; suite 148 checks
- fix(router): ADB como señal de entorno no disparador (falso positivo React); unifica política SESION.md a 5 entradas/30KB; README 106→132 checks
- docs: ejemplos verificados de agy (Antigravity) con MCP en Knowledge/Tools/CodeGraph.md
- docs: registra pruebas end-to-end de CodeGraph con agy (Antigravity) en SESION y CHANGELOG 2026-08-06
- docs: Knowledge/Tools/CodeGraph.md — referencia completa de comandos, MCP y troubleshooting + indice actualizado (categoria Tools) y doctor
- docs: CodeGraph visible para cualquier IA — INFO-core, LOAD_CONTEXT (Code Search primero) e INFO-full
- docs: changelog 2026-08-06 — setup CodeGraph (MCP en 4 agentes, indexado autoscript + ManUninstaller)
- docs: sesion 2026-08-06 — setup CodeGraph completo (MCP en 4 agentes, indexado autoscript + ManUninstaller, documentacion global)
- docs: indexar ManUninstaller con CodeGraph (31 archivos, 486 nodos) + entrada en PROJECTS.md
- docs: sesion 2026-08-05 (2a parte) — fixes extractor MG 350 pusheados (6b3e352) + investigacion Freebuff busy 429 y wrapper fb-wait
- docs: sesion 2026-08-05 — data_car sync Base Tecnica -> ficha pusheado (89f74cf) + auto-carga de contexto Freebuff (~/.AGENTS.md)
- docs: Knowledge/Android/NubiaLab.md — setup del laboratorio ZTE Nubia (inventario, qué no tocar, comandos de purga); doctor + indices sincronizados
- docs: sesion 08-03 completa — laboratorio ZTE Nubia (ManUninstaller revisado+instalado, purga 22 apps + 25 bloat) registrado en SESION.md y CONTINUE.md
- docs: sesion 2026-08-03 registrada en SESION.md — router manifests, migracion SYSTEM, versiones scrcpy/Ollama, README, fix H2, schema-lite B1, BUFFY_HOME C2
- feat: BUFFY_HOME/common.sh (C2 opt-in) — estado generado redirigible, 6 tests, suite 116/132 OK
- feat: schema-lite B1 — ai-context-lint.sh valida secciones obligatorias de INFO-core/CONTINUE/LOAD_CONTEXT + front-matter semver-lite (5 tests, suite 105/121 OK)
- fix: android-agent/SKILL.md referencia solo skills del repo — reemplaza android-native-dev/clean-arch/mobile-design (entorno) por project-setup/hardening/xiaomi-tricks
- docs: README al dia con disco — arbol de 23 skills agrupadas por dominio, Knowledge con AI/+Vision, scripts completos, tabla de categorias
- docs: versiones minimas de scrcpy (>=3.3.1, UHID v2.0 + fix power-off 3.3.1) y Ollama (>=0.30) verificadas desde el PC con fuente — Knowledge/Android/scrcpy.md + Knowledge/Vision.md
- feat: migrar stubs SYSTEM.md/SYSTEM_FULL.md a deprecated/ — referencias corregidas a INFO-core/full, doctor sin DEPRECATED_FILE (warnings 3→1)
- docs: CONTINUE handoff — sesión 2026-08-03 (router con manifests implementado)
- feat: router consume skill.yaml manifests (B2) — add_skill + discover_skills por triggers, lib/yaml.sh compartido, fix mensaje vacío exit 1, tests router (suite 75→90 quick / 91→106 full)
- fix: limpiar CHANGELOG (A2) — poda a 13 entradas recientes (661 a 216 lineas), front-matter unico, entradas <= 07-31 movidas a archive con dedupe + heading REVIRTIO restaurado
- docs: BUFFY-PC-CONTEXT.md — digest verificado de sesiones para la Buffy del PC (commits, estado actual, convenciones, pendientes, flujo de continuacion) + cross-ref en REVIEW-BASELINE
- feat: skill manifests (B2) completo — 23/23 skills con skill.yaml + gate --require-all activo en suite y CI (75 OK quick / 91 OK full)
- feat: skill manifests (B2) — skill.yaml de ejemplo en android-agent + linter scripts/skill-lint.sh integrado en la suite (74 OK quick / 90 OK full)
- fix: resolver drift del doctor — crear 13 skills documentadas (10 nuevas + 3 migradas), baseline CI a 0, sanitizar notas historicas y false positive, fix test doctor --quick
- docs: REVIEW-BASELINE.md — contexto verificado de primera mano para revisiones de IA (estado real, hechos comprobados, problemas pendientes)
- docs: unificar ruta SNAPSHOT.md a ~/ai-context/ (fuera del repo) en README + aclarar HF_TOKEN siempre requerido en INSTALL
- docs: INSTALL.md — guards de dependencias, mkdir/chmod para symlinks, caveat Termux /usr/bin/env, HF_TOKEN aclarado, cp -rn con backup opcional
- docs: INSTALL.md robusto — URL real, verificacion de dependencias, PATH/chmod, Termux+hooks, dependencias opcionales, sandbox, smoke test post-instalacion
- ci: GitHub Actions — suite completa + doctor con baseline de drift (16) en cada push/PR
- feat: entrada de release automatica en CHANGELOG (changelog-entry.sh + set-version integrado + tests sandbox)

**Archivos modificados/creados:**
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — modificado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/accessibility.md` — creado
- `.agents/skills/…/references/adaptive-screens.md` — creado
- `.agents/skills/…/references/design-style-guide.md` — creado
- `.agents/skills/…/references/functional-requirements.md` — creado
- `.agents/skills/…/references/motion-system.md` — creado
- `.agents/skills/…/references/performance-stability.md` — creado
- `.agents/skills/…/references/privacy-security.md` — creado
- `.agents/skills/…/references/testing.md` — creado
- `.agents/skills/…/references/visual-design.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/scripts/collect.sh` — creado
- `.agents/skills/…/scripts/generar_reporte_matriz.py` — creado
- `.agents/skills/…/scripts/matriz_preinstalados.py` — creado
- `.agents/skills/…/scripts/parse_full.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — modificado
- `.agents/skills/…/references/devices.md` — modificado
- `.agents/skills/…/scripts/grant_permissions.sh` — modificado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/complexity_matching.md` — creado
- `.agents/skills/…/references/voice_preservation.md` — creado
- `.agents/skills/…/references/workspace_detection.md` — creado
- `.agents/skills/…/scripts/complexity_estimator.py` — creado
- `.agents/skills/…/scripts/dump_classifier.py` — creado
- `.agents/skills/…/scripts/workspace_inventory.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — eliminado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/assets/example_time_block_plan.md` — creado
- `.agents/skills/…/assets/shutdown_checklist.md` — creado
- `.agents/skills/…/references/deep_work_canon.md` — creado
- `.agents/skills/…/references/shallow_work_budget.md` — creado
- `.agents/skills/…/references/time_blocking_method.md` — creado
- `.agents/skills/…/scripts/focus_session_logger.py` — creado
- `.agents/skills/…/scripts/shallow_work_auditor.py` — creado
- `.agents/skills/…/scripts/time_block_planner.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/goal_prompt_patterns.md` — creado
- `.agents/skills/…/scripts/goal_prompt_self_check.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/agents/openai.yaml` — creado
- `.agents/skills/…/scripts/block-dangerous-git.sh` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/ADR-FORMAT.md` — creado
- `.agents/skills/…/CONTEXT-FORMAT.md` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/adr_practice.md` — creado
- `.agents/skills/…/references/context_md_as_artifact.md` — creado
- `.agents/skills/…/references/ubiquitous_language.md` — creado
- `.agents/skills/…/scripts/adr_scanner.py` — creado
- `.agents/skills/…/scripts/context_md_linter.py` — creado
- `.agents/skills/…/scripts/glossary_code_consistency.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/README.md` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/assets/example_handoff.md` — creado
- `.agents/skills/…/references/configuration.md` — creado
- `.agents/skills/…/references/deduplication_discipline.md` — creado
- `.agents/skills/…/references/handoff_prompt.md` — creado
- `.agents/skills/…/references/handoff_structure.md` — creado
- `.agents/skills/…/references/redaction_checklist.md` — creado
- `.agents/skills/…/scripts/cleanup.py` — creado
- `.agents/skills/…/scripts/config_loader.py` — creado
- `.agents/skills/…/scripts/handoff_self_check.py` — creado
- `.agents/skills/…/scripts/handoff_template_generator.py` — creado
- `.agents/skills/…/scripts/redaction_linter.py` — creado
- `.agents/skills/…/scripts/setup.py` — creado
- `.agents/skills/…/scripts/skill_recommender.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/android-navigation.md` — creado
- `.agents/skills/…/references/compose-components.md` — creado
- `.agents/skills/…/references/details.md` — creado
- `.agents/skills/…/references/material3-theming.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/element-attributes.md` — creado
- `.agents/skills/…/references/playwright-tests.md` — creado
- `.agents/skills/…/references/request-mocking.md` — creado
- `.agents/skills/…/references/running-code.md` — creado
- `.agents/skills/…/references/session-management.md` — creado
- `.agents/skills/…/references/storage-state.md` — creado
- `.agents/skills/…/references/test-generation.md` — creado
- `.agents/skills/…/references/tracing.md` — creado
- `.agents/skills/…/references/video-recording.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/cognitive_bias_canon.md` — creado
- `.agents/skills/…/references/conversation_reflection_practice.md` — creado
- `.agents/skills/…/references/honest_output_discipline.md` — creado
- `.agents/skills/…/scripts/bias_pattern_detector.py` — creado
- `.agents/skills/…/scripts/conversation_depth_analyzer.py` — creado
- `.agents/skills/…/scripts/directional_recommendation_validator.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/README.md` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/assets/example_roast_verdict.md` — creado
- `.agents/skills/…/assets/roast_brief_worksheet.md` — creado
- `.agents/skills/…/references/adversarial_panel_canon.md` — creado
- `.agents/skills/…/references/cheapest_test_canon.md` — creado
- `.agents/skills/…/references/verdict_synthesis_method.md` — creado
- `.agents/skills/…/scripts/brief_builder.py` — creado
- `.agents/skills/…/scripts/cheapest_test_designer.py` — creado
- `.agents/skills/…/scripts/verdict_synthesizer.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/architecture_patterns.md` — creado
- `.agents/skills/…/references/system_design_workflows.md` — creado
- `.agents/skills/…/references/tech_decision_guide.md` — creado
- `.agents/skills/…/scripts/architecture_diagram_generator.py` — creado
- `.agents/skills/…/scripts/dependency_analyzer.py` — creado
- `.agents/skills/…/scripts/project_architect.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — modificado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/LICENSE.txt` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/scripts/init_skill.py` — creado
- `.agents/skills/…/scripts/package_skill.py` — creado
- `.agents/skills/…/scripts/quick_validate.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — eliminado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/GENERATION.md` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/references/advanced-environments.md` — creado
- `.agents/skills/…/references/advanced-projects.md` — creado
- `.agents/skills/…/references/advanced-type-testing.md` — creado
- `.agents/skills/…/references/advanced-vi.md` — creado
- `.agents/skills/…/references/core-cli.md` — creado
- `.agents/skills/…/references/core-config.md` — creado
- `.agents/skills/…/references/core-describe.md` — creado
- `.agents/skills/…/references/core-expect.md` — creado
- `.agents/skills/…/references/core-hooks.md` — creado
- `.agents/skills/…/references/core-test-api.md` — creado
- `.agents/skills/…/references/features-benchmarking.md` — creado
- `.agents/skills/…/references/features-concurrency.md` — creado
- `.agents/skills/…/references/features-context.md` — creado
- `.agents/skills/…/references/features-coverage.md` — creado
- `.agents/skills/…/references/features-filtering.md` — creado
- `.agents/skills/…/references/features-mocking.md` — creado
- `.agents/skills/…/references/features-reporters.md` — creado
- `.agents/skills/…/references/features-snapshots.md` — creado
- `.agents/skills/…/references/features-test-tags.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/assets/example_weekly_review.md` — creado
- `.agents/skills/…/assets/weekly_review_checklist.md` — creado
- `.agents/skills/…/references/gtd_weekly_review_canon.md` — creado
- `.agents/skills/…/references/open_loop_psychology.md` — creado
- `.agents/skills/…/references/review_cadence_design.md` — creado
- `.agents/skills/…/scripts/commitment_auditor.py` — creado
- `.agents/skills/…/scripts/open_loop_scanner.py` — creado
- `.agents/skills/…/scripts/weekly_review_gate.py` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.agents/skills/…/SKILL.md` — creado
- `.agents/skills/…/skill.yaml` — creado
- `.github/workflows/ci.yml` — creado
- `.gitignore` — modificado
- `CHANGELOG.md` — modificado
- `CONTRIBUTING.md` — modificado
- `FIXTURE-EXPERIMENTAL-DESIGN.md` — creado
- `FWD-DESIGN.md` — creado
- `INSTALL.md` — modificado
- `INSTANCE-STATE-DESIGN.md` — creado
- `Knowledge/Android/Keymappers.md` — modificado
- `Knowledge/Android/NubiaLab.md` — creado
- `Knowledge/Android/Shizuku.md` — modificado
- `Knowledge/Android/scrcpy.md` — modificado
- `Knowledge/Git/Commands.md` — modificado
- `Knowledge/README.md` — modificado
- `Knowledge/Tools/Benchmark-realista.md` — creado
- `Knowledge/Tools/CodeGraph.md` — creado
- `Knowledge/Vision.md` — modificado
- `MCP_REGISTRY.md` — creado
- `README.md` — modificado
- `REVIEW-BASELINE.md` — creado
- `SIGNAL-STATE-COUPLING-FAILURES.md` — creado
- `SKILLS_INDEX.md` — creado
- `ai-context/AGENTS.md` — modificado
- `ai-context/AUDITORIA-HANDOFF-FREEBUFF.md` — creado
- `ai-context/CHANGELOG-archive.md` — modificado
- `ai-context/CHANGELOG.md` — modificado
- `ai-context/CONTINUE.md` — eliminado
- `ai-context/INFO-core.md` — modificado
- `ai-context/INFO-full.md` — modificado
- `ai-context/LOAD_CONTEXT.md` — modificado
- `ai-context/PROJECTS.md` — modificado
- `ai-context/README.md` — modificado
- `ai-context/SESION-archive.md` — eliminado
- `ai-context/SESION.md` — eliminado
- `ai-context/SHIZUKU-RISH-BUG.md` — creado
- `ai-context/deprecated/README.md` — creado
- `ai-context/deprecated/SYSTEM.md.20260803_150816` — renombrado
- `ai-context/deprecated/SYSTEM_FULL.md.20260803_150816` — renombrado
- `ai-context/facts_rules.yaml` — creado
- `ai-context/project-state-design.md` — creado
- `ai-context/project-state-engine-design.md` — creado
- `ai-context/project-state-linter-design.md` — creado
- `ai-context/project-state-paso5-plan.md` — creado
- `ai-context/project-state-paso6-experiment.md` — creado
- `ai-context/project-state.yaml` — creado
- `ai-context/v4_MANIFIESTO.md` — modificado
- `scripts/ai-context-lint.sh` — creado
- `scripts/android-detect.sh` — modificado
- `scripts/buffy-agent.sh` — modificado
- `scripts/buffy-close-day.sh` — creado
- `scripts/buffy-context.sh` — modificado
- `scripts/buffy-doctor.sh` — modificado
- `scripts/buffy-expand.sh` — creado
- `scripts/buffy-memory.sh` — creado
- `scripts/buffy-repair.sh` — modificado
- `scripts/buffy-router.sh` — modificado
- `scripts/buffy-search.sh` — creado
- `scripts/buffy-selector.sh` — creado
- `scripts/buffy-source.sh` — creado
- `scripts/buffy-verify.sh` — creado
- `scripts/changelog-entry.sh` — creado
- `scripts/hooks/install.sh` — modificado
- `scripts/hooks/pre-commit.sh` — modificado
- `scripts/hooks/pre-push.sh` — creado
- `scripts/lib/buffy-memory-sync.sh` — creado
- `scripts/lib/common.sh` — creado
- `scripts/lib/expand_passages.py` — creado
- `scripts/lib/expand_query.py` — creado
- `scripts/lib/facts_engine.py` — creado
- `scripts/lib/memory_engine.py` — creado
- `scripts/lib/project_state_engine.py` — creado
- `scripts/lib/project_state_linter.py` — creado
- `scripts/lib/project_state_linter.schema.json` — creado
- `scripts/lib/resolve-path.sh` — creado
- `scripts/lib/selector_m3.py` — creado
- `scripts/lib/yaml.sh` — creado
- `scripts/see.sh` — modificado
- `scripts/set-version.sh` — modificado
- `scripts/skill-lint.sh` — creado
- `scripts/tests/bench-context-selection.sh` — creado
- `scripts/tests/bench-realistic-DESIGN.md` — creado
- `scripts/tests/bench-realistic-FASE1-Search.md` — creado
- `scripts/tests/bench-realistic-FASE2-Router.md` — creado
- `scripts/tests/bench-realistic-FASE3-Hybrid.md` — creado
- `scripts/tests/bench-realistic.sh` — creado
- `scripts/tests/bench-scale.sh` — creado
- `scripts/tests/ci-sim.sh` — creado
- `scripts/tests/evals/CONTEXT-REQUIREMENTS.md` — creado
- `scripts/tests/evals/EVAL-REGISTRY.md` — creado
- `scripts/tests/evals/PRODUCTION-PORT-SPEC.md` — creado
- `scripts/tests/evals/ablation-campos-DESIGN.md` — creado
- `scripts/tests/evals/analiza-17C.py` — creado
- `scripts/tests/evals/analiza-17E.py` — creado
- `scripts/tests/evals/and-normalizado-DESIGN.md` — creado
- `scripts/tests/evals/baseline-A-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-B-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-C-andnorm-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-D-semantic-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-E-hybrid-rrf-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-E1-evidence-PC-2026-08-12-r2.json` — creado
- `scripts/tests/evals/baseline-E1-evidence-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-E2-evidence-PC-2026-08-12-r2.json` — creado
- `scripts/tests/evals/baseline-E2-evidence-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-E3-evidence-PC-2026-08-12-r2.json` — creado
- `scripts/tests/evals/baseline-E3-evidence-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-F-hybrid-pool-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-F1-expansion-PC-2026-08-13-r2.json` — creado
- `scripts/tests/evals/baseline-F1-expansion-PC-2026-08-13.json` — creado
- `scripts/tests/evals/baseline-F2-expansion-PC-2026-08-13-r2.json` — creado
- `scripts/tests/evals/baseline-F2-expansion-PC-2026-08-13.json` — creado
- `scripts/tests/evals/baseline-G1-passage-ventana-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-G2-passage-seccion-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-H1-expansion-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-H2-expansion-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-Q1-quality-PC-2026-08-12-r2.json` — creado
- `scripts/tests/evals/baseline-Q1-quality-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-Q2-quality-PC-2026-08-12-r2.json` — creado
- `scripts/tests/evals/baseline-Q2-quality-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-R1-rerank-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-R2-rerank-PC-2026-08-12.json` — creado
- `scripts/tests/evals/baseline-and-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-and-norm-PC-2026-08-11.json` — creado
- `scripts/tests/evals/baseline-or-PC-2026-08-11.json` — creado
- `scripts/tests/evals/bridge-17B-DESIGN.md` — creado
- `scripts/tests/evals/bridge-17B-PC-2026-08-14-control-A.json` — creado
- `scripts/tests/evals/bridge-17B-PC-2026-08-14-treatment-B-r1.json` — creado
- `scripts/tests/evals/bridge-17B-PC-2026-08-14-treatment-B-r2.json` — creado
- `scripts/tests/evals/build-fixture.sh` — creado
- `scripts/tests/evals/combine-17D-DESIGN.md` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-B-solo-r2.json` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-B-solo.json` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-V1-solo-r2.json` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-V1-solo.json` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-control-A-r2.json` — creado
- `scripts/tests/evals/combine-17D-PC-2026-08-15-control-A.json` — creado
- `scripts/tests/evals/combine-17E-DESIGN.md` — creado
- `scripts/tests/evals/diag-17A-REPORT.md` — creado
- `scripts/tests/evals/diag-17A-bridge.sh` — creado
- `scripts/tests/evals/dict_h1_b.json` — creado
- `scripts/tests/evals/eval-ctx-PC-2026-08-11.json` — creado
- `scripts/tests/evals/eval-ctx-PC-2026-08-11.json.sha256` — creado
- `scripts/tests/evals/evidence-passage-DESIGN.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/BUFFY-PC-CONTEXT.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/CHANGELOG.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/CONTRIBUTING.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/FIXTURE-EXPERIMENTAL-DESIGN.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/FWD-DESIGN.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/INSTALL.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/INSTANCE-STATE-DESIGN.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/AI/Kimi-K3.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/ADB.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/GameOptimization.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/HyperOS.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/Keymappers.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/NubiaLab.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/Shizuku.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Android/scrcpy.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Git/Commands.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Linux/Kernel.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Linux/System.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Node/Node.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/README.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/React/PWA.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/React/React.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/React/Tailwind.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/React/Vite.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Shell/Shell.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Tools/Benchmark-realista.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Tools/CodeGraph.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/Knowledge/Vision.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/MCP_REGISTRY.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/README.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/REVIEW-BASELINE.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/SKILLS_INDEX.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/USER-MANU.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/AGENTS.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/AUDITORIA-HANDOFF-FREEBUFF.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/CHANGELOG-archive.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/CHANGELOG.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/INFO-core.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/INFO-full.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/LOAD_CONTEXT.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/PROJECTS.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/README.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/SHIZUKU-RISH-BUG.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/facts_rules.yaml` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/corpus/ai-context/v4_MANIFIESTO.md` — creado
- `scripts/tests/evals/fixtures/fx-2026-08-15-001/manifest.json` — creado
- `scripts/tests/evals/granularity-16B-PC-2026-08-14-r2.json` — creado
- `scripts/tests/evals/granularity-16B-PC-2026-08-14.json` — creado
- `scripts/tests/evals/granularity-DESIGN.md` — creado
- `scripts/tests/evals/hybrid-bounded-DESIGN.md` — creado
- `scripts/tests/evals/leak-17C-DESIGN.md` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V1-r2.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V1.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V2-r1.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V2-r2.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V3-r1.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-V3-r2.json` — creado
- `scripts/tests/evals/leak-17C-PC-2026-08-14-control-A.json` — creado
- `scripts/tests/evals/passage-candidate-expansion-DESIGN.md` — creado
- `scripts/tests/evals/passage-level-DESIGN.md` — creado
- `scripts/tests/evals/port-baseline-2026-08-16-repo-r1.json` — creado
- `scripts/tests/evals/port-baseline-2026-08-16-repo-r2.json` — creado
- `scripts/tests/evals/port-gate74-2026-08-16-repo-r1.json` — creado
- `scripts/tests/evals/port-gate74-2026-08-16-repo-r2.json` — creado
- `scripts/tests/evals/port-sanity72-2026-08-16-fixture-r1.json` — creado
- `scripts/tests/evals/port-sanity72-2026-08-16-fixture-r2.json` — creado
- `scripts/tests/evals/quality-passage-DESIGN.md` — creado
- `scripts/tests/evals/query-expansion-DESIGN.md` — creado
- `scripts/tests/evals/reranking-DESIGN.md` — creado
- `scripts/tests/evals/run-baseline-PC.sh` — creado
- `scripts/tests/evals/run-bridge-17B.sh` — creado
- `scripts/tests/evals/run-combine-17E.sh` — creado
- `scripts/tests/evals/run-evidence-PC.sh` — creado
- `scripts/tests/evals/run-expansion-PC.sh` — creado
- `scripts/tests/evals/run-granularity-PC.sh` — creado
- `scripts/tests/evals/run-hybrid-PC.sh` — creado
- `scripts/tests/evals/run-leak-17C.sh` — creado
- `scripts/tests/evals/run-passage-PC.sh` — creado
- `scripts/tests/evals/run-quality-PC.sh` — creado
- `scripts/tests/evals/run-rerank-PC.sh` — creado
- `scripts/tests/evals/run-selector-model-PC.sh` — creado
- `scripts/tests/evals/run-selector-quality-PC.sh` — creado
- `scripts/tests/evals/run-semantic-PC.sh` — creado
- `scripts/tests/evals/selector-benchmark-14A.json` — creado
- `scripts/tests/evals/selector-model-DESIGN.md` — creado
- `scripts/tests/evals/selector-pool-frozen-2026-08-13.json` — creado
- `scripts/tests/evals/selector-quality-15A-r2.json` — creado
- `scripts/tests/evals/selector-quality-15A.json` — creado
- `scripts/tests/evals/selector-quality-DESIGN.md` — creado
- `scripts/tests/evals/semantic-retrieval-DESIGN.md` — creado
- `scripts/tests/fixtures-realistic/dev-set.json` — creado
- `scripts/tests/fixtures-realistic/domains.json` — creado
- `scripts/tests/fixtures-realistic/eval-set.json` — creado
- `scripts/tests/fixtures-realistic/generator.py` — creado
- `scripts/tests/fixtures/project-state/cmd-string.yaml` — creado
- `scripts/tests/fixtures/validate_json_schema.py` — creado
- `scripts/tests/helpers.sh` — modificado
- `scripts/tests/run-tests.sh` — modificado
- `scripts/tests/test-ai-context-lint.sh` — creado
- `scripts/tests/test-bridge-17B.sh` — creado
- `scripts/tests/test-changelog.sh` — creado
- `scripts/tests/test-close-day.sh` — creado
- `scripts/tests/test-combine-17E.sh` — creado
- `scripts/tests/test-common.sh` — creado
- `scripts/tests/test-context-selection.sh` — creado
- `scripts/tests/test-doctor.sh` — modificado
- `scripts/tests/test-documentation.sh` — creado
- `scripts/tests/test-expand-query.sh` — creado
- `scripts/tests/test-granularity-16B.sh` — creado
- `scripts/tests/test-local-override.sh` — creado
- `scripts/tests/test-memory-sync-guards.sh` — creado
- `scripts/tests/test-memory.sh` — creado
- `scripts/tests/test-pii-guard.sh` — creado
- `scripts/tests/test-project-state-engine.sh` — creado
- `scripts/tests/test-project-state-linter.sh` — creado
- `scripts/tests/test-router.sh` — creado
- `scripts/tests/test-runner.sh` — modificado
- `scripts/tests/test-scale.sh` — creado
- `scripts/tests/test-selector.sh` — creado
- `scripts/tests/test-skill-lint.sh` — creado
- `scripts/tests/test-verify.sh` — creado

---

### 2026-10-03 — D2.3 follow-up — las excepciones del guard PII son POR PATRÓN, no globales (Freebuff, PC)

- **Regresión encontrada al revisarla, no antes.** La primera versión de D2.3 puso las exclusiones en un array compartido por TODOS los patrones. Eso tapó el email real y el nombre real dentro de `scripts/tests/evals/` — exactamente lo que C5 había LEVANTADO a propósito para que el guard llegara ahí. No se notaba porque hoy hay 0 matches en cualquier escenario; la regresión era de cobertura futura, silenciosa y sin síntoma. **Una excepción de un patrón no puede ser excepción de los otros**: el motivo de exceptuar el alias (sobrevive en artefactos congelados) no dice nada sobre un email real. (Las literales no se reproducen acá: esta entrada está bajo el guard, y escribirlas para explicar el guard lo dispara — es la segunda vez que pasa en esta misma sesión.)
- **La política se vuelve testeable.** `pii_excl_for <patrón>` extrae la selección de pathspecs a una función propia, y el guard la consume. Sin eso, "agregar una exclusión" es un cambio invisible hasta que alguien lee el array.
- **`test_pii_guard_excepciones_por_patron` (4 checks)** hace lo que antes no hacia nadie: (a) que la excepción siga siendo la DECLARADA — falla si alguien agrega un pathspec más sin revisarlo, así que el array deja de crecer en silencio; (b) que sea real — si el fixture se limpia, la excepción queda vacía y hay que revisarla; (c) que NO se derrame — un patrón de PII real dentro de `evals/` tiene que seguir siendo cazado.
- **Verificado que el test muerde.** Con la excepción global restaurada (la regresión) el suite da 2 FAIL independientes: `un patrón real tiene 4 exclusiones (esperado 1)` y `PII real en evals/ pasa desapercibida`. Con la corrección, ambos verdes.
- Suite **396/0 full · 380/0 quick** (+4). README a 390/396 full y 374/380 quick.

### 2026-10-03 — D2.3 — `origin` obligatorio en todo manifest: procedencia visible cuando el nombre colisiona (Freebuff, PC)

- **La premisa del ítem era falsa y el trabajo se redirigió antes de ejecutar.** "Skills vendored" asumía copias de upstream. La historia lo desmiente: las 5 skills sospechosas (`vercel-react-best-practices`, `vite`, `context7`, `tailwind-design-system`, `typescript-advanced-types`) tienen 2 commits en total — el de autoría `5d08120` (2026-08-03) y el de D2.1. Nunca fueron sobrescritas. Son **propias**, y el contenido lo delata: `vite/SKILL.md` dice "El stack del usuario es React + TypeScript + Tailwind v4 + Vite", que no lo escribe nadie más.
- **Por lo tanto no hay nada que atribuir ni contra qué medir drift.** El "check que detecte drift contra el upstream" no tenía upstream; y aunque lo tuviera, uno que golpea la red en CI es la clase de gate que este repo ya aprendió a no querer.
- **El problema real es peor que la atribución faltante:** esas 5 tienen el MISMO nombre que skills de comunidad, y la resolución de skills es por `name`. Instalar la de arriba no se distingue de la del repo y nada dice cuál gana. Dos skills, mismo nombre, contenido distinto, sin marca de procedencia.
- **Solución (decisión del operador): declarar origen, sin rename.** Renombrar altera qué se dispara y cuándo, así que no se hizo. En cambio `origin` pasa a ser campo **obligatorio** en los 44 manifests (`local` en todos: son del repo), y las 5 colisionantes llevan la nota de por qué el campo existe. `origin` no es un campo decorativo — es lo que hace visible la procedencia justo en el caso donde el nombre no la muestra.
- **El gate tiene test, no solo validación.** `test_skill_lint_origin_obligatorio` (3 checks: ausente → exit 1, inválido → exit 1, `local` → exit 0). Sin esto el check sería como el de PyYAML antes del fix1 — el linter valida, nadie verifica que valga. Verificado a mano además: quitar `origin` y poner un valor inválido → `ERR` en ambos casos.
- **Los fixtures del test de skill-lint se actualizaron** (4 manifests inline): el contrato nuevo los volvía inválidos y los 2 tests de `--require-all` caían. No era regresión del código — eran fixtures que describían el contrato viejo.
- Suite **392/0 full · 376/0 quick** (+3). Doctor CONSISTENTE. README a 386/392 full y 370/376 quick — lo exige el check documental-truth.
- **Alias `buffy-maint` confirmado con doble f** (el repo se llama buffy; la opción original decía `bufy`).

### 2026-10-03 — D2.1 — identidad de sistema: alias `buffy-maint`, `system-id: buffy-desktop`, alias personal al guard PII (Freebuff, PC)

- **Decisión del operador**: seudónimo de SISTEMA (`buffy-maint`), no alias personal. El repo se declara infra de un operador, no perfil de una persona. Anterior: el alias personal era el identificador en authoring de skills, prosa de docs y `system-id`.
- **Lo que esta decisión NO hace (dicho antes de implementarla, no después):** no desanonimiza nada. La historia ya tenía 5 identidades, 2 con nombre real, y los metadatos de 264 commits son inmutables — coherente con C5: "la vinculación ya es pública vía cuenta GitHub y no es reversible con un purge de repo". El alias nuevo es el cuarto nombre; su valor es consistencia hacia adelante y quitar una excepción del guard, no privacidad.
- **Vinculación canónica (documentada, NO reescrita)** — una sola tabla que dice qué es qué:

  | Identidad en la historia | Commits | Qué es |
  |---|---|---|
  | email real del operador (3 variantes de nombre) | 181+13+2 | identidad legal — metadatos de git, públicos por diseño |
  | nombre real + email personal | 20 | ya estaba fuera del patrón A-list (D0): 0 matches tracked |
  | `maneskinleon-del@users.noreply.github.com` | 56 | usuario público de GitHub por diseño (D0.2) |
  | alias personal (patrón en `scripts/tests/test-pii-guard.sh`) | 0 commits | aparece solo en contenido, nunca como autor |

  Las literales no se reproducen acá a propósito: esta entrada está bajo el guard, y escribir el patrón para explicar el guard lo dispara (mismo modo de falla que la auto-exclusión del propio archivo de test).

  Regla vigente: **el autor de un commit no es seudónimo.** El seudónimo es la marca del contenido (`author:` de skills, `system-id`); la identidad legal del autor queda en los metadatos de git y es pública por diseño. Confundir las dos era lo que hacía que "redactar el alias" pareciera estar protegiendo algo.
- **Guard PII: el alias personal entra al patrón** (litera en `scripts/tests/test-pii-guard.sh`). 91 ocurrencias en tracked, clasificadas en 5 familias: 9 `author:` de SKILL.md → `buffy-maint`; 3 `system-id` → `buffy-desktop`; ~8 de prosa → "del sistema" / "del operador"; 3 en `CHANGELOG-archive.md`; 63 en el fixture congelado + `selector-pool-frozen`.
- **Excepciones por pathspec, no allowlist del patrón** (precedente: el guard ya se autoexcluía):
  - `scripts/tests/evals/fixtures/` + `selector-pool-frozen-2026-08-13.json` — editar el corpus rompe `corpus_hash`, validado contra el manifest por `EVAL-REGISTRY.md:2307`, y reabre la decisión C5. Son snapshots de un corpus cerrado: no pueden reintroducir PII solos, solo por un re-gen deliberado, que es el momento de revisarlos a mano.
  - `ai-context/CHANGELOG-archive.md` — registra acciones reales sobre la máquina (un archivo en `/etc/sudoers.d/` y su línea `ALL=(ALL) NOPASSWD`). Redactarlo haría que la entrada afirmara algo que no ocurrió. El valor de un changelog es ser fiel, no higienizado.
- **Verificado**: reintroducir el alias en `INFO-core.md` → `FAIL PII reintroducida (1 matches)` (el gate muerde, no solo está bien). Suite **389/0 full · 373/0 quick**; doctor CONSISTENTE (0 errores); skill-lint 44/44 con `yaml_validated=true`. README actualizado a 383 functional / 389 total. Lo exige el propio check documental-truth: agregar un check cambia los totales, y esta vez no es cascada porque el check nuevo es real.
- **Pendiente deliberadamente NO aplicado**: `git config user.name/user.email` → `buffy-maint`. Configurarlo antes de que exista la cuenta GitHub deja commits nuevos sin vincular a nada, y un commit sin vincular es irreversible igual que uno mal vinculado. El comando, cuando la cuenta exista: `git config user.name "buffy-maint" && git config user.email "buffy-maint@users.noreply.github.com"`.

### 2026-09-30 — buffy-context: C4-B COMPLETADO — Patrón B (.local override) con regla única, suite 366/366 (Freebuff, PC)

- **`scripts/lib/resolve-path.sh` — fuente ÚNICA de la regla** (decisión (2) del operador): helper ejecutable consumido por bash (subshell) y Python (subprocess — facts_engine). Semántica: `X.local.<ext>` si existe = AUTORIDAD TOTAL (incluso vacío/corrupto — el fallback silencioso ocultaría el error); sin override → base tracked; missing → imprime base + exit 1 (el consumidor decide qué significa ausencia).
- **Split**: contenidos reales del operador → `INFO-core/AGENTS/PROJECTS.local.md` (gitignored); tracked reescritos como genéricos honestos (mismas secciones, placeholders, cero PII — pasan lint/doctor en clone fresco).
- **8 consumidores migrados al EFECTIVO**: ai-context-lint (check_file), doctor (obligatorios + opcionales), router (BASE_FILES), buffy-verify, buffy-source, facts_engine.py, selector_m3 (paridad — ruido ai-context/* ya cubría .local estructuralmente). No-lecturas confirmadas: repair:146, ci.yml, migrate-system.
- **test-local-override.sh (13 checks)**: regla del helper en 6 ramas, delegación Python (anti-duplicación), paridad del selector, lint bidireccional (override válido → sano; override malo → falla sobre el override).
- **Dos brechas de la instancia 5 cazadas en el camino**: (a) fixtures de verify no idempotentes — el sed asumía contenido del operador; en clone fresco el genérico no matchea → CI rojo (`b6f63d1` lo arregla: inyección idempotente + sandbox self-contained para reglas-lista); (b) ci-sim overlay sin untracked no-ignorados — un helper nuevo sin commitear dejaba al clone sin él → 25 FAILs en cascada falsa (falso ❌ del sim).
- Suite: 360+6=366 full · 344+6=350 quick. CI verde final (36781193116). Verificado en ambos mundos: con override (PC) y sin override (clone).



### 2026-09-30 — buffy-context: onda 3 — taxonomía #7/#8 + ci-sim + hook pre-push, suite 353/353 (Freebuff, PC)

- **Instancia 7 (anti-cascada):** doc_truth comparaba contra **passed** (incorporan FAILs ajenos → un fallo cualquiera hacía "mentir" al README correcto; 2 falsos positivos en el CI rojo). Ahora compara contra **TOTALES** (passed+failed, invariantes) + guard de introspección (nadie puede reintroducir la comparación contra passed). Demostración empírica de la no-cascada: el CI real corrió con 344+1 y doc_truth no mordió.
- **Instancia 5 (mitigación estructural):** `scripts/tests/ci-sim.sh` — clone file:// + overlay de cambios tracked sin commitear (los untracked no: CI tampoco los ve) + HOME aislado = las condiciones exactas de CI en ~5-20s. Gateado por **hook pre-push** (`scripts/hooks/pre-push.sh`, instala con `bash scripts/hooks/install.sh --force`, saltable con `--no-verify`). Instalador extendido a ambos hooks (misma convención Termux de shebang real).
- **Taxonomía** (`SIGNAL-STATE-COUPLING-FAILURES.md`): instancia **5** (antes «4b»: mismo árbol vs clone fresco — variante working-tree del entorno) + **7 cascada** (antes «6»: el verificador confunde su causa con la causa ajena) + meta-momento 3 (CI cazando su propio fix) + meta-sección "la verificación es un objeto más". [Canonicalización posterior del 2026-09-30: registro autoritativo de 8 instancias con alias históricos + Principios P1-P3.]
- **Bautismo del hook (meta-momento 4):** abortó su propio push inaugural DOS veces por fidelidad incompleta de la sim — (a) veía el Ollama local del operador (estado variable, instancia 1) → `OLLAMA_URL` muerta en ci-sim (`511486d`); (b) heredaba las ref-lines de git por stdin y el router las leía como mensaje → stdin cerrado `</dev/null` (`530fb90`). Lección registrada en la taxonomía: un simulador de entorno es un verificador y tiene su propio acoplamiento — el estándar es "¿qué ve el runner?" (entorno COMPLETO), no "¿qué veo yo?".
- **Convención de autoría registrada (CONTRIBUTING §Autoría en commits):** commits con asistencia de agente llevan `🤖 Generated with Codebuff` + `Co-Authored-By: Codebuff <noreply@codebuff.com>` (metadato de co-autoría del contenido; git author sigue siendo el operador). Origen honesto: apareció el 2026-09-30 como accidente del tooling, registrado como decisión explícita de trazabilidad. Nota de parsing: la línea 🤖 corta el bloque de trailers para git — el trailer se verifica con `%b`, no con `%(trailers)`.
- Suite 347+6=353 full · 331+6=337 quick (+2 lint de scripts nuevos). Verificada en clone fresco y working tree. CI run 36756704078: 3/3 jobs ✓.

### 2026-09-30 — buffy-context: CI verde + gate corpus_frozen_ok + desacople del estado de instancia, suite 350/350 (Freebuff, PC)

- **CI rojo (venía desde commits del operador 2026-09-29) des-rompido en dos commits, con verificación en condiciones exactas de CI.** Capa prevista: doctor exigía CONTINUE.md como obligatorio (gitignored por diseño desde C3 — tolerancia nunca cableada) + README 43→44 skills. Capa no prevista: 4 checks de la suite FULL acoplados a CONTINUE.md (existe local, ausente en clone) + cascada del contador doc_truth (341≠345 — el contador resta FAILs; README nunca estuvo mal).
- **`8431ed9` — gate `corpus_frozen_ok` v3 (extraído de C5 por necesidad):** compara ls-tree (paths+blob SHAs) del scope FTS5 (raíz *.md|*.yaml + ai-context/ + Knowledge/ sin deprecated) entre HEAD y 77bf26a (base del fixture del selector). Sin git/ancestro (CI shallow) → OK corre. Bug cazado en verificación: grep con `\\.` literal no matcheaba nada (scope raíz fuera de la comparación). Verificado en 3 ramas: HEAD hoy DISTINTO / worktree en el ancestro IGUAL / shallow file:// OK-corre. Skips honestos en fidelidad_expand y veredicto_15B (hoy skippean por drift del corpus: el doc de la taxonomía movió el corpus que la taxonomía diagnosticaba). fetch-depth:0 en ci.yml.
- **`3f512d0` — criterio unificado "ausente+gitignoreado = OK estado local por diseño"** en doctor (ya existía), ai-context-lint check_file y router modo normal; tests de lint/router bifurcan existe/ausente. Contrato del router --quick verificado en código: omite inexistentes por diseño ("solo rutas existentes") — la omisión en clone fresco NO es drift. INFO-core ausente sigue siendo error duro.
- **Verificación doble:** suite full 350/0 y quick 334/0 en clone fresco (file:// + working tree) y en working tree local. CI run 36747471665: 3/3 jobs ✓ (Suite 38s · Doctor · Verify). origin/main = `3f512d0`.
- **Lecciones:** (a) --quick local NO predice CI full cuando la diferencia es estado de instancia — simular en clone fresco antes de pushear; (b) doc_truth en cascada: verificar aritmética del contador antes de tocar cifras del README; (c) --quick del hook pre-commit no cubre la capa full.

### 2026-09-27 — buffy-next: PR5 ejecutado — buffy ctx + buffy env (C1-c), suite 679/679 (Freebuff, PC)

- **Ciclo completo evaluación→decisión→implementación.** Evaluación arquitectónica del CLI autónomo con corrección al marco del operador ("tree limpio" falso al llegar — 7º caso del patrón, registrado en LOAD_CONTEXT.md: la convención [orig]/[verificado] incluye premisas de handoffs de terceros). Decisión: **(c) extender el binario existente** con ajustes — `ctx` (evita colisión con `doctor --context` y `act check-*`), pass-through con discovery del filesystem (Next no conoce la lista de subcomandos de Context), `env` no recortable (diagnóstico R3). Wrapper Context-side descartado: recrea el patrón H1 a nivel familia.
- **PR5 (`6fbc16f`, master):** `src/shared/ctx.ts` (delegador: args verbatim desde argv crudo — el test atrapó que stripFlags habría robado --json al script; validación pre-interpolación; CWD=repo root; stdio inherit; exit code preservado), `buffy env` (topología, VERSION única lectura documentada, null honesto), dispatch temprano pre-adapter con guard estructural, `BUFFY_CONTEXT_REPO`. Señales: group-kill verificado empíricamente en producción (cero huérfanos; 3 falsos positivos previos = artefactos de medición). Tests 668→679, tsc limpio, build OK.
- Commits del día en buffy-next: `34d55b8` (PR3), `26f2b6d`+`06bd4c6` (PR4), `6fbc16f` (PR5) — todos en origin.

### 2026-09-27 — buffy-next: PR4 ejecutado — ciclo H1-H8 CERRADO, suite 668/668 (Freebuff, PC)

- **H8:** `capabilities` expone catálogo de acciones (`getActionCatalog()`: id+name+level+prerequisites). JSON `{capabilities, actions}` — **BREAKING** documentado (único consumidor conocido: subprocess CLI; sin buffy_capabilities en código MCP). Contract: discovery ≠ authorization. La brecha era preexistente: BUFFY-AGENT-CONTRACT.md:34 ya prometía "acciones con su nivel de seguridad y requisitos".
- **H1 (D1-c):** `doctor` desambigua ADB — `adb-binario` (capabilities) vs `adb-dispositivo` (privileges.adb); fila ambigua `priv-adb` eliminada (guard); `Capability.deviceConnected?` medido-por-adapter, ausencia ≠ false. Empírico en esta PC: `ADB (binario): instalado` + `ADB (dispositivo): conectado`.
- **D3 (rename):** docs-only — grep verificado 0 `--dry-run` vivo en src/ (6 matches = comentarios históricos). Sin alias ni deprecation.
- **Tests:** 657→668 (+11), tsc limpio. **Estado del ciclo: 7/8 resueltos (H4, H1b, H2, H5, H6, H1, H8) + D3 docs-only + H7=(c) + H3 RETRACTADO.** Pendiente: commits PR3+PR4 (autorización del operador).
- Nota: el contrato lista `buffy_capabilities` como tool MCP sin superficie en código — brecha doc↔binario preexistente, registrada fuera de alcance.

### 2026-09-27 — buffy-next: PR3 ejecutado — H6 (brecha de serialización) resuelto, suite 657/657 (Freebuff, PC)

- **H6 cerrado** (sin commit — pendiente autorización): `epistemicState` + `ageMs` serializados por-observación en los 9 pushes de `analyzeForQuery` (`diagnose.ts`), comentario anti-regresión "NO eliminar: contrato E4.1" en el ex-sitio de dead computation (ex `diagnose.ts:211`), stamp en boundary de gating (`freshness-gating.ts`: legacy → observed, refreshed → valor real post-refresh). **Telemetría agregada intacta** (`staleFields`/`refreshRequired`/`refreshPerformed`/`instrumentation` sin cambios — ortogonal: describe el pipeline, no los ítems).
- **Tests H6 (3, `tests/h6-epistemic-serialization.test.ts`):** per-obs siempre emitido (mata dead computation) + valor real no-constante (`vi.mock` de `classifyEpistemicState`, gpu→'stale', apunta al sitio de serialización pre-gating porque el gating nunca deja salir un stale+relevante sin refresh) + guard estructural del comentario. `analyzeForQuery` exportado como seam de test. Suite **654→657**, tsc limpio; empírico: `diagnose --json` 5/5 obs con epistemicState+ageMs, `audit.staleFields: []`.
- Nota de diseño: observedAt=now → hoy todo nace 'observed'; el campo queda establecido antes de que cache lande (refuerzo #3 del operador). diagnose y `doctor --context` ahora consistentes (per-field en las 9 categorías).
- Pendiente: PR4 (H1 semántica ADB + H8 catálogo capabilities + rename plan-mode) — semántica UX, decisión del operador.

### 2026-09-25 (parte 9) — PR2 ejecutado: H2+H5 resueltos, suite 654/654 (Freebuff, PC)

- **PR2 (`8fbdca9`, master):** H2 — patrón `/\bcpu\b|procesador/` en el selector + señales diagnósticas ampliadas; verificado: "uso alto de CPU" → `[cpu, processes]` observable (antes `no_evidence`). H5 — decisión del operador **(b) omisión condicional**: `inferred?` opcional por contrato, se emite solo con inferencia real, fallback eliminado con comentario anti-regresión en action-mapper.ts; verificado: 0 "Inferido" fantasma, ningún inferred==observed. Suite **648→654** (+6), tsc limpio, build OK.
- **Corrección del conteo de casos (propuesta del operador, aceptada): son 5, no 4, en dos clases** — (1-3) documentación corrupta en el repo (AUDIT-v0.3 dryRun, e438f29, CURRENT-STATE §0); (4) paráfrasis que nunca llegó al repo (no cuenta como corrupción); **(5) afirmación del auditor sin verificar** (la paráfrasis atribuida a BUFFY-CURRENT-STATE sin grep previo — atrapada en vuelo). La convención `[orig]/[verificado]` aplica también a las afirmaciones del propio auditor. Registrado como observación metodológica, no como castigo.
- Pendientes: PR3 (H6 — decisión de contrato: `epistemicState` por-observación vs telemetría), PR4 (H1 semántica ADB + H8 catálogo en capabilities + rename plan-mode).

### 2026-09-25 (parte 8) — PR1 ejecutado: H4+H1b resueltos y verificados (Freebuff, PC)

- **PR1 (`d62fa07`, master):** H4 — `stripFlags()` en `src/shared/cli-args.ts` (puro, 6 tests) cableado en cli.ts antes de construir texto de usuario; H1b — `extractGpuSlot()` (regex hex estricta, bloquea también inyección vía `-s`) + `lspci -k -s <slot>` + `extractDriverFromLspciK()` (8 tests con fixtures del sistema real). **Verificación empírica:** `query: 'temperatura'` limpio; `driver: amdgpu` (antes pcieport). Suite **634→648** (39 archivos), `tsc --noEmit` limpio, build OK. Rama `fix/h4-h1b-cli-surface` fusionada ff y eliminada; estado de resolución agregado al src map (`ed52845`).
- **4to caso del patrón "documentado ≠ real" — la paráfrasis como modo de falla dominante:** (1) `AUDIT-v0.3.md:87` `dryRun ✅` falso desde v2.2; (2) `e438f29` "vacío→run_command"; (3) `CURRENT-STATE.md §0` flake mal fechado; (4) paráfrasis de la cadena de gate en el review de hoy — **detectada antes de corromper docs**: grep verificó que nunca estuvo en BUFFY-CURRENT-STATE.md (0 matches). La convención `[orig]/[verificado]` pasa de preventiva a estadísticamente necesaria: 4 casos reales en 2 días.
- **Nota metodológica H3:** dos corridas no bastan para atribuir causa — el falso positivo fue del observador (freebuff fluctuando), no del sistema.
- Pendientes: Grupo B (H2+H5, contexto de módulo — H5 requiere decisión inferencia-real vs honestidad-semántica), Grupo C-contract (H6 serializar epistemicState), Grupo C-semánticos (H1+H8+rename plan-mode). — src map H1-H8: causas raíz, H7=(c), H3 retractado (Freebuff, PC)

- **Paso 3 ejecutado** (lectura dirigida de src/ con H1-H8 como índice, `4c4d248` pusheado): 5/8 son FIX_TRIVIAL (H4 `cli.ts:66`; H1b `linux.ts:38`; H5 `action-mapper.ts:115-117`; H2 la palabra "cpu" no existe en el vocabulario del selector; mitad H6 `diagnose.ts:211` calcula epistemicState y lo descarta). Estructurales = alineación semántica (H1 instalado≠conectado, H8 capabilities sin catálogo, H7 plan-mode sin nombre).
- **H7 veredicto (c) reorganización:** dryRun() del spec v2.1 fue reemplazado en v2.2 por `ActionPlanner.preview`; el plan-mode existe como `act --json` (muestra plan y retorna ANTES de gate.execute — verificado empíricamente con list-processes read-only; T3 completado). La cadena de gate citada por el review era paráfrasis — no existe verbatim en ningún doc. `AUDIT-v0.3.md:87` (fila dryRun ✅) anotado como desactualizado.
- **H3 RETRACTADO:** "temperatura" sí está en el selector (`check-selector.ts:29`); la discrepancia entre corridas era el proceso freebuff fluctuando — estado del sistema, no idioma.
- **Frontera conocer/ejecutar intacta a nivel diseño** → BUFFY-CURRENT-STATE.md no requiere corrección (veredicto no fue (a)/(d)). Next: fixes triviales (candidato: lote H4+H2+H5+H1b con tests). — ronda superficie CLI directa: 8 hallazgos H1-H8 (Freebuff, PC)

- **Primera sesión de uso directo del CLI standalone** (sin consumer AGY, ~30 min, black-box): 8 hallazgos → ratio señal/minuto ~10x mayor que las rondas de routing AGY. Valida Buffy-como-herramienta-standalone. Registro: `a568c6a` en buffy-next (pusheado).
- **Confirmados:** H4 `--json` contamina `query` 2/2 (prioridad 1); H1 doctor↔capabilities contradicen ADB + H1b driver GPU `pcieport`; H5 Observed==Inferred en recommendations (viola contrato epistémico E4.1); H2/H3 selector ES/EN brittle ("uso alto de CPU" → 0 checks; "temperature" solo EN).
- **H6 frescura:** por-diseño en context path (contrato E4.1, 7/7 en `doctor --context`); diagnose emite observedAt+source pero sin epistemicState/freshness por-observación — residual UNVERIFIED hasta abrir src/. **H7** `--dry-run` no existe. **H8** `capabilities` no cataloga acciones aunque `act` deriva ahí el descubrimiento.
- T3 solo path negativo (rechazo limpio de acción desconocida); positivo NO ejecutado por seguridad (sin dry-run). Evidencia: `~/docs/experiments/2026-09-25-cli-surface/` (8 archivos, SHA256SUMS 8/8).

### 2026-09-25 (parte 5) — Q2: timestamp de corte obligatorio en handoffs (Freebuff, PC)

- **3er caso real de la familia** (handoff desactualizado): la ronda B se ejecutó entre la redacción del handoff y el inicio de la sesión; el drift fue detectado porque el agente chequeó estado git antes de asumir el plan. Precedentes: flake latencyMs mal fechado, checkpoint v1 perdido.
- **Regla formalizada** en `LOAD_CONTEXT.md` (commit `8a85eda`), en los dos lados del contrato: **emisor** — todo handoff lleva `[redactado YYYY-MM-DD HH:MM]` en el encabezado; **receptor** — antes de asumir el plan, `git log` en los repos implicados buscando commits posteriores a la marca. Extensión del protocolo de cierre de sesión existente, no regla nueva.
- Precisión C5-B aplicada en esta misma fase (commit `1cf6902`): primaria p=0.114 inconclusiva; task-sensibilidad solo como señal exploratoria (p=0.029). Reformulado como "routing consistente con contrato; hipótesis sin significancia primaria".

### 2026-09-25 (parte 4) — Q1: dangling buffy-tools RESUELTO (reapunte + verificación trazable) (Freebuff, PC)

- **Diagnóstico:** entrada `buffy-tools` en `~/.gemini/settings.json` apuntaba a adapter inexistente (`~/experiments/opencode-buffy-cplus/adapter/` — el dir padre entero fue eliminado). Binario real: `~/.npm-global/bin/buffy` (buffy-next v0.2.2, `serve --mcp` en cli.ts:80,328,366).
- **Cambio mínimo:** reapunte manteniendo el nombre de server (no rompe consumidores; grep en `~/.gemini/` solo encontró transcripts históricos de brains — `GEMINI.md` referencia el tool `buffy_context`, no el server). Superficie AGY (`mcp/buffy/`) intacta — mecanismo distinto.
- **Verificación [verificado 2026-09-25]:** handshake MCP con la ruta exacta de settings (initialize OK v0.2.2 + tools/list `[buffy_context]`) + `gemini mcp list` end-to-end → 3/3 Connected. Backup: `~/.gemini/settings.json.bak-2026-09-25` (fuera de repos por auth config).
- Deuda operativa cerrada: los tres pendientes del ciclo (contradicción e438f29, ronda B, dangling) están RESUELTOS.

### 2026-09-25 (parte 3) — anotación de vigencia e438f29 + post-ciclo C5-B (Freebuff, PC)

- **Contradicción del handoff resuelta:** el diagnóstico C3′ de `e438f29` ("workspace vacío → run_command") quedó anotado en `docs/research/AGY-BUFFY-ROUTING-C3-PRIME-ANALYSIS-2026-09-15.md` (commit `eb496f9` en buffy-next) con la convención `[orig]`/`[verificado 2026-09-23]`: texto forense original intacto; anotación de que la ronda del 23-sep no soporta la hipótesis como condición suficiente (3/3 PASS en vacío, FAILs del 14-sep no reproducidos). Refinamiento añadido: C5-B (dirección consistente con contrato; hipótesis de task-sensibilidad sin significancia primaria — precisión aplicada también al título de la parte 2).
- **Estado:** la ronda B del handoff ya estaba ejecutada antes de esta sesión (`f706bb6` protocolo + `0df24e1` resultado, parte 2 del changelog). BUFFY-CURRENT-STATE.md §10.4 actualizada a HEADs vigentes + §10.5 con la anotación. Sello de vigencia intacto: 0 cambios en `src/` desde `e438f29`.
- Handoff desactualizado: no refleja las 3 rondas del 25-sep (audit-checkpoint, C5-B y esta anotación). Este commit es el cierre.

### 2026-09-25 (parte 2) — C5-B: routing consistente con contrato; task-sensibilidad solo como señal exploratoria (experimento pre-registrado) (Freebuff, PC)

- **C5-B ejecutado** según protocolo pre-registrado (`C5B-PROTOCOL-2026-09-25.md`, commit `f706bb6` ANTES de ejecutar): 2 tasks × workspace fijo × N=3. Workspace reconstruido **byte-exacto** contra los shas publicados del 23-sep (README `18887a9f`, notes `e49c81e2`, example.py `ed79c172`) — ancla de comparabilidad perfecta.
- **T1 control (entorno, verbatim C3-R): 3/3** con `buffy_context` como primera tool — replica C3-R exactamente. **T2 (código): 1/4 presencia, siempre tardía** (pos 4 tras explorar archivos); 3/4 comienzan con `view_file(example.py)`; una sesión usó `search_web` para `greet()`.
- **Métrica primaria (presencia) inconclusiva** (Fisher p=0.114, n=7 válidas) — reportada tal cual, sin promoción post hoc. **Secundaria (primera tool) p=0.029 exploratoria**: señal de selección no task-invariante, sin confirmación primaria.
- **Dirección contract-correcta**: la surface del tool declara "Never for: codebase exploration" → no llamarlo primero en revisión de código es cumplimiento del contrato, no fallo. Refuerza el cierre de la ronda 23-sep: sin caso empírico para discovery nuevo ni RAG.
- Congestión de servidor: 6 intentos INVALID (ERROR/rate-limit), t2r5 réplica no obtenida tras 3 intentos. Evidencia: `~/docs/experiments/2026-09-25-c5b-transcripts/` (30 archivos, SHA256SUMS 30/30). Workspaces sin ediciones (diff -r vs template, 5/5 limpios).
- Commits: `f706bb6` (protocolo) → `0df24e1` (resultado), pusheados a origin/master.

### 2026-09-25 — ai-context: checkpoint BUFFY-CURRENT-STATE.md v1 commiteado + convención [orig]/[verificado] en LOAD_CONTEXT (Freebuff, PC)

- **BUFFY-CURRENT-STATE.md v1** creado en `ai-context/` y commiteado: el original de la auditoría (ejecutada 2026-09-25 sobre estado HEAD 2026-09-15 de buffy-next/buffy-context) no llegó a persistir en disco; la reconstrucción re-verificó la evidencia el mismo día (§8 del doc: HEADs git, skill-lint 43/43 manifests, ci.yml:29, adapter MCP dangling).
- **4 correcciones del review aplicadas:** R1 fechas separadas (HEAD observado ≠ fecha de auditoría), R2 sin recuento exacto de scripts ("scripts auditados + librerías auxiliares"), R3 `skill-lint.sh --require-all` verificado como uso efectivo en CI (no solo capacidad), R4 `buffy serve --mcp` conservado como configuración previamente observada, no estado verificado.
- **Convención `[orig]` / `[verificado YYYY-MM-DD]`** registrada en LOAD_CONTEXT.md como regla documental del proyecto; BUFFY-CURRENT-STATE.md es su referencia de aplicación. Decisión: los veredictos de auditoría/checkpoint se versionan en Git (precedente `AUDITORIA-HANDOFF-FREEBUFF.md`); CONTINUE/SESION siguen siendo estado local de instancia (INSTANCE-STATE-DESIGN §3).
- Pendiente menor detectado: adapter MCP `buffy-tools` en `~/.gemini/settings.json` apunta a `~/experiments/opencode-buffy-cplus/adapter/buffy-mcp-server.js`, que no existe en disco.
- **Addendum v1.1 (mismo día):** verificada la cadena `e438f29 → 1c975f0 → d036312` en buffy-next (**0 cambios en `src/` desde el HEAD auditado** → veredictos de la auditoría vigentes sin re-auditar); flake `latencyMs` **NO activo** (fix `094a3af` del 12-sep; 3× suite completa consecutiva 634/634 + typecheck limpio); procedencia del conteo 606→607→634 documentada (606/607 era checkpoint congelado del 11-sep, no estado de HEAD). Ambos repos pusheados y sincronizados a origin.

### 2026-09-24 — GameBoostPro: checkpoint T4B-A1 (lock global BoostSessionStore) + fix H6b (validación ns/key del baseline) pusheados (Freebuff, PC)

- **Fix T4B-A1 `0f67c7c`** — el lock por instancia de `BoostSessionStore` no protegía las dos instancias productivas que comparten `boost_session.json`/`.tmp` (repro controlado: 499/500 pérdidas). Nuevo `FILE_LOCK` a nivel proceso (companion object, save/load/clear) + fallback destructivo eliminado (`file.delete()` + segundo `renameTo` → log ERROR + `tmp.delete()` + false, preservando el último commit válido). Test adversarial `BoostSessionStoreConcurrencyA1Test` (2 instancias reales, mismo path, CyclicBarrier, 250 saves/thread): **falla en `65b4bab`, pasa con fix**. Hallazgo de entorno CONFIRMADO: `File.renameTo(archivo→dir-vacío)` puede retornar TRUE en este JDK/FS → inyección de fallo por EACCES (permisos POSIX), portable.
- **Auditoría T4B post-A1 (read-only)** — inventario de 6 hallazgos; dominante: ns/key del baseline sin validar en `restoreVerified` (mitad no cubierta por H6). Items #2 (composites no atómicos), #3-#5 (BAJO) y #6 (UNVERIFIED) documentados en CONTINUE.md como pendientes.
- **Fix H6b `f13666f`** — gate fail-closed de `entry.namespace`/`entry.key` ANTES de cualquier `runCommand` en `restoreVerified` (incluido el `settings get` de relectura): `isValidSettingsNamespace` (dominio cerrado {global,system,secure} según inventario autoritativo `BoostKeys`) + `isValidSettingsKey` (token shell-inerte, keys legacy incluidas). Rechazar, nunca mutar: válidos pasan byte a byte. Test `H6bNamespaceKeyInjectionTest` (5 tests, `sh -c` real + marcador inocuo; cubre put/delete/get): falsificación contra HEAD sin gate = payload llega al shell; con fix, nunca.
- **Tests:** 63/63 unit (58 tras A1 + 5 H6b), `assembleDebug` OK en ambas tandas. Sidecars `audit.db-shm/-wal` (lectura read-only del audit.db) quedaron fuera de los commits; `.gitignore` pendiente. Sin validación en dispositivo (H6/H6b/A1) — pendiente ciclo boost/restore en Mi 10.
- **Checkpoint:** pushes `65b4bab..0f67c7c..f13666f` a origin/main (`~/GameBoosterManu`), CONTINUE/SESION/CHANGELOG sincronizados a `~/ai-context/`.

### 2026-09-22 — GameBoostPro: fix H6 (validación read-back de restores shell) pusheado + evidencia forense (Freebuff, PC)

- **Fix H6 `073cea9`** — valores leídos del provider/baseline (`settings get`) se interpolaban directo en `settings put` de restore: un valor corrupto o provider manipulado podía alcanzar `runCommand()` como segunda instrucción shell. Nuevo `RestoreValueValidators.kt` (dominios por key: zen_mode numérico 0..3 AOSP, private_dns_mode/specifier, wifi_bt_coexistence, genérico `isValidRestoreValue`) + gates en GameSessionManager (zen_mode), NetworkOptimizer, TouchOptimizer y BoostSessionManager (baseline). Regla adoptada: **rechazar + log ERROR, NUNCA mutar** (se preserva byte a byte); defaults preexistentes (ausencia de backup) intactos, sin defaults inventados. 7 archivos, +595/-12.
- **Tests:** 56/56 unit (39 previos + 17 nuevos: `RestoreValueValidatorsTest` + `H6ShellReadBackTest`). **Sin validación en dispositivo aún** (sin APK en la sesión; pendiente ciclo boost/restore con valores borde en Mi 10).
- **Evidencia `65b4bab`** — 37 archivos: forensic-phase1 (6 informes F1 + 4 screenshots), R1/INVENTORY/OVERLAY reorg (5 md), forensic-phase3 (F3B-F4, F4-BoostKeys), shizuku-off-t1 (scripts captura/verify, informe T1, snapshots T4/T4B, room-logs preservadas ~20MB) + `.codegraph/.gitignore`. Los .log pesados (~27MB) quedaron fuera vía `experiments/.gitignore` (mismo patrón de `4608202`). Scan de secretos sobre lo commiteado: limpio.
- **Checkpoint:** push fast-forward `4608202..65b4bab` a origin/main (`~/GameBoosterManu`), working tree limpio, CONTINUE/SESION/CHANGELOG sincronizados a `~/ai-context/`.

### 2026-08-15 — Fase D cerrada: fixture experimental congelado D0–D5 como infraestructura (Freebuff, PC)

- **D0 `bd52050`** — diseño `FIXTURE-EXPERIMENTAL-DESIGN.md`: corpus congelado con hash POR CONTENIDO, exclusiones contractuales (sin instancia/memoria por defecto, `--include` opt-in), gate §6.1–§6.7.
- **D1 `881af3f`** — `build-fixture.sh`: descubre corpus (mismo alcance que el runner), filtra, copia + `manifest.json` (corpus_hash, config_hash, runner/version).
- **D2 `cc17eb4`** — fixture `fx-2026-08-15-001` congelado: 45 archivos / 640 KB / `corpus_hash 0af49cc666d872a6`; exclusión efectiva (0 instancia/memoria, 0 scripts).
- **D3 `bd931aa`** — runner `--fixture`: CORPUS = fixture congelado, PIPELINE = árbol vivo; validación de inmutabilidad (mismatch → STOP, sin reindex silencioso); `commit_sha` (corpus) vs `pipeline_commit` (runtime); `--repo` intacto.
- **D4 `9212aa7`** — multi-dispositivo: 3 checkouts limpios con caché fresco, sin `--reindex` → mismo `corpus_hash 0af49cc666d872a6`; manifest idéntico.
- **D5 `f5e51a7`** — gate §6.1–§6.7 PASADO: reproducible, inmutable (editar CONTINUE/CHANGELOG no cambia el hash), multi-PC, mutación→STOP, `config_hash` sensible, suite **315 OK / 299 OK**, exclusión efectiva.
- **Resultado:** separación real `--repo` (estado operativo) vs `--fixture` (estado experimental). Resuelve el hallazgo estructural de 17D. **Infraestructura, NO resultado experimental; sin EVAL nuevo (17E+).** Último commit `f5e51a7` (pusheado, `origin/main == HEAD`).

### 2026-08-15 — Cierre serie 17B→17C→17D: Commit A de infraestructura + 17D STOP metodológico / NO EVALUADO (Freebuff, PC)

- **Commit A `abbee6d` (PUSHEADO)** — los 22 `skill.yaml` untracked eran manifests legítimos (B2, exigidos por `skill-lint.sh --require-all`); 2 fixes de `SKILL.md` (frontmatter `name` sin comillas) + `test-scale.sh` (ruta Termux → `${TMPDIR:-/tmp}`). Suite: **313 OK / 0 FAIL full · 297 OK / 0 FAIL --quick** (los 4 preexistentes documentados en CONTINUE.md quedaron resueltos). Ninguno tocó runtime.
- **Spec 17D congelada `ad04631`** (`combine-17D-DESIGN.md`) — T = V1 + DICT_H1_B como único tratamiento; controles A/B-solo/V1-solo con **sanity de igualdad EXACTA per-query** (ajuste del usuario: todas las métricas contractuales); gate por contrato §17.4; ceguera metodológica (no nace como "V1+B dará 13/20 y 0.250").
- **Sanity ×2 G2 (6 corridas) bajo corpus `029ed669` (7803 líneas)** vs histórico `236a87fa` (7653): A attr 12/20 ✅ pero **leak 0.425 ≠ 0.442** ❌; B-solo attr 13/20 ✅ pero **leak 0.425 ≠ 0.442** ❌; V1-solo leak 0.250 ✅ pero **pRel 0.581 ≠ 0.584** ❌. G2 interno ✅ en los 3.
- **STOP por regla §3.1 — T = V1+DICT_H1_B NUNCA se ejecutó.** Causa: drift real del corpus — README/CHANGELOG/CONTINUE/SESION crecieron entre 17C y 17D y alteraron Q10 (leak 0.5→0.333, pRel 0.333→0.300) y Q03 (ctx_size 2→3).
- **Cierre `932f146`** — veredicto en `EVAL-REGISTRY.md` §17D: **STOP metodológico / NO EVALUADO** + 6 JSONs de sanity como evidencia. No se re-congela `029ed669` ni se actualizan esperados retrospectivamente (decisión del usuario: cambiar la referencia tras observar el drift debilitaría la disciplina).
- **Hallazgo estructural:** el corpus de Buffy NO está aislado de su propio estado operativo (CHANGELOG/CONTINUE/SESION participan del fenómeno medido). Continuar exige diseñar un **fixture/corpus experimental congelado e INMUTABLE** (trabajo de diseño nuevo, no 17D). Conecta con el frente arquitectónico SESION/CONTINUE local.
- Registro completo en `EVAL-REGISTRY.md` → sección 17D. Suite: sin cambios de runtime (313/297).

### 2026-08-14 — EVAL 17C ejecutado y cerrado: reducción del leak estructural del pool (opencode, PC)

- **Runner `run-leak-17C.sh` (NUEVO)** — copia del mecanismo 17B + `--variant {A,V1,V2,V3}`. Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, piso 0.545, LIMIT=10, sin oráculo. Corpus congelado `236a87fa` (7653 líneas), `eval_hash 98a0e308…`, `commit_sha 51b8079…`, `h1_dict_hash 8294f200…`.
- **7 corridas completas** (control-A + V1×2 + V2×2 + V3×2, ~45-49s c/u con índice cacheado). **G2 confirmado en las 3 variantes** (determinism_hash A=`0d44653e`, V1=`289f8470`, V2=`0c471a33`, V3=`48888238`).
- **V1 (exclusión dura de noise en ctx final) CRUZA el gate PRIMARIO:** leak 0.442 → **0.250** (-43%), pRel 0.415 → **0.584** (+41%), contain 1.0, cero regresiones en los 8 golds, G2 determinista. La fuente A (noise de sesión, 55% del leak) era la causa dominante. **PERO attr = 12/20 < 13/20** (gate #2): V1 no incluye DICT_H1_B → Q05 sigue en 0. **NO ADOPTADO** (no se modifica el gate retrospectivamente). V1 = candidato positivo/no adoptado.
- **V2 (S4×3) SIN EFECTO** — idéntica a A (leak 0.442): el peso S4 no cambia el ranking cuando s1/s2/s3 dominan (la fuente A entra por el gate S1 ≥ 0.545, no por el score final). **V3 (excl. raíz no-Knowledge) EFECTO MÍNIMO** (leak 0.433; fuente D solo 10%). Ambas descartadas.
- **Hallazgo de instrumento:** `--repeat` es vestigial (se parsea pero no se usa en loop) — G2 = invocar el runner 2 veces con distinto `--out`.
- **Veredicto:** el leak estructural SÍ es reducible (hipótesis H17C confirmada); V1 no aprobado para producción. **Próximo frente: 17D = V1 + DICT_H1_B combinados** (ortogonales) — requiere diseño y gate propios + aprobación del usuario.
- **Revisión de arquitectura (separación proyecto/instancia):** `buffy-memory-sync.sh` sincroniza SOLO MEMORY/USER (`.sync-state` perfil-local, nunca versionado) ✅; `SNAPSHOT.md`/`facts.yaml` ya gitignored ✅; **problema real = `SESION.md`/`CONTINUE.md` versionados** → con N dispositivos, contaminación + conflictos. Propuesta: hacerlos locales (decisión de diseño, requiere aprobación).
- **Principio rector agregado al README:** "La complejidad debe ser proporcional a la tarea".
- Registro completo en `EVAL-REGISTRY.md` → sección 17C. Suite: sin cambios (no se tocó runtime).

### 2026-08-14 — Shizuku activado por ADB (13.6.0) + protocolo de diagnóstico global (Buffy, PC)

- **Shizuku v13.6.0.r1086 activado en Mi 10 (HyperOS)**: reinstalado desde GitHub oficial (sha256 `6e273ab0e991c4e79bc8b1bbb9b9dd739ccac1a8712a541a214078886b7b790f`), fix de batería (whitelist deviceidle + appops `RUN_ANY_IN_BACKGROUND` + standby active), método oficial 13.6.0 (`libshizuku.so` → `/data/local/tmp/shizuku`). Servidor pid 22501, 12 apps autorizadas, logcat `✅ Shizuku OK`.
- **Skill `shizuku-rikka` mejorada** (212→239 líneas): sección prioritaria "🧭 ANTES DE ACTUAR: diagnóstico por síntomas (LEER PRIMERO)" + `shizuku-activation-protocol.md` (70 líneas) referenciado. Documenta 6 fallos reales (start.sh inexistente, UI engañosa, `rish id` trampa, etc.) y el método que SÍ funcionó.
- **Regla global en `~/.AGENTS.md`** (§43): "🔍 Diagnóstico antes de actuar (Android)" — aplica a todas las skills de Android. Preguntar contexto → diagnóstico 10s → prueba de éxito real (logcat, no `id`) → documentar fallos mientras se trabaja.
- **Caso de éxito documentado** en `SHIZUKU-RISH-BUG.md` (Actualización 5): ciclo completo error → diagnóstico → solución local → solución global → verificación en vivo.
- **Lección raíz**: el error más caro no fue técnico — fue no preguntar el contexto que el usuario ya tenía (HyperOS, batería agresiva, watchdog). El protocolo fuerza esa pregunta en el paso 1.

### 2026-08-14 — Rama X (query expansion H1) al pipeline real + Q03 aceptado como límite (Freebuff, PC)

- **`scripts/lib/expand_query.py` (NUEVO)** — DICT_H1 + `expansion_terms` + `dict_hash` portados del runner del Paso 10. Fidelidad **10/10** vs baseline-H1 congelado (las 10 queries del EVAL producen los mismos términos).
- **`buffy-search.sh --expand-query` (opt-in, default OFF)** — rama X al pipeline real: (1) **X-candidatos**: re-consultas FTS5 por término del diccionario → hits extra al pool (tope 100); (2) **X-query**: términos pasados como `--terms` al selector → S1 puntúa con la query expandida. `BUFFY_EXPAND_QUERY=true` para `router --context`. **`buffy-selector.sh --terms`** nuevo.
- **Smoke Q03 medido:** Commands.md:64 entra al pool (15→91), S1 mejora 0.468→0.493 pero NO cruza el piso 0.545. **Hallazgo:** la línea exacta cruza (0.613 con términos relevantes); la ventana ±4 la diluye → causa raíz = granularidad del pasaje (PAS_PAD=4), no el modelo.
- **Q03 aceptado como límite documentado** (decisión del usuario): bajar el piso descartado (evidencia 15A: soft gate colapsa attr 1/20), otro embedding descartado por ahora. Dirección futura: granularidad alternativa de pasaje con gate propio.
- **Suite: 283 OK / 4 FAIL full · 267 OK / 4 FAIL --quick** (4 preexistentes). Tests +13 (`test-expand-query.sh`). Commits `210b871` + `16c626b` (locales, sin push).

### 2026-08-14 — Selector M3 → V6 (veredicto 15B) + tarea "cerrar día+1" + phi/qwen en opencode (Freebuff, PC)

- **V6 adoptado como selector del pipeline** (`5fc0822`): S3 condicionado a query estructural + S4 por clase de memoria de sesión (ai-context/* salvo CHANGELOG.md curado) → **attr 16/20 → 19/20, pRel 0.577 → 0.677, leak 0.275 (pasa gate ≤0.308), reg 0.360**. Cierra el hallazgo 15A (sobre-corrección de estructuras): Q02 1/3→3/3, Q07 1/2→2/2, Q08/Q06 intactos. Cambios de mecanismo, sin calibración. V2/V3/V4 descartados con evidencia. Q05 `useState` queda como miss ortogonal → rama X.
- **Tarea "cerrar día+1"** (`5fc2fa0`): `buffy-close-day.sh --poweroff` — tras el cierre completo (memoria + SNAPSHOT + doctor + commit/push), **apaga el PC** solo si terminó sin error. Override por env para pruebas. Tests +3.
- **phi3.5 en opencode: bloqueado** (sin tool calling; coincide con el EVAL 14A). **qwen2.5:7b funciona** — ambos agregados al provider `ollama` de `~/.config/opencode/opencode.json`.
- **Registro Pasos 12/13 preservado** (`d34b7f6`, pusheado): serie E/F completa (13 archivos), veredictos intactos.
- Suite: 270 OK / 4 FAIL full · 254 OK / 4 FAIL --quick (solo preexistentes).

### 2026-08-13 — Expansión F2 (rama P) al pipeline: candidate gap de Q08 cerrado en vivo (Freebuff, PC)

**Pedido del usuario:** implementar la expansión F2 del Paso 13 como componente del pipeline (cierra el candidate gap que la integración M3 base dejó en Q08/Q03). Artefactos del autor anterior INTACTOS (solo lectura).

**Lo hecho:**
- **`scripts/lib/expand_passages.py` (NUEVO)** — motor de expansión de pasajes (rama P): tile_windows ±4 no-solapados (2·PAS_PAD+1 = 9 líneas), archivos kno del router + top-K del pool por orden R1 (F2), con `--max-passages` (default 400) como guard de coste (los kno entran completos, el pool se recorta). Misma lógica que `run-evidence-PC.sh` (Paso 13 F2).
- **`scripts/buffy-expand.sh` (NUEVO)** — wrapper CLI: `--kno` + pool → pasajes rama P.
- **`buffy-selector.sh --kno`** — expansión ANTES del scoring M3 (encadena buffy-expand.sh).
- **`buffy-search.sh`** — pasa `BUFFY_SELECTOR_KNO` al selector; **`buffy-router.sh --context`** setea esa env con su knowledge → pipeline completo `router → F2 → M3 → context pack`.
- **Tests de expansión** (+7 checks): F1 tiles 9/9/7, F2 kno+pool, max-passages recorta pool no kno, selector --kno degrada sin Ollama. **Suite: 265 OK / 4 FAIL full · 249 OK / 4 FAIL --quick** (4 FAIL preexistentes). README actualizado.
- **Validación en vivo:** **Q08 CERRADO** — `System.md:73-81` (P_TERM_OPACITY/picom) al top-1 del selector con expansión (antes fuera del pool). Q06 conserva cobertura. **Q03 persiste**: Commands.md entra al pool vía kno pero el puente `pushear`→`git push origin` es semántico (bge-m3 por línea) — es la rama X del Paso 10, no cobertura de pasajes.
- **Coste documentado:** la expansión F2 en frío paga embeds nuevos (fiel al Paso 13: r0 ≈ 17 min, warm ≈ 1 min); `--max-passages` lo acota.

---

### 2026-08-13 — Integración M3 al pipeline real: buffy-selector.sh + search --select + router --context (Freebuff, PC)

**Pedido del usuario:** integrar el selector M3 rescue 0.545 adoptado en 15A con el pipeline real (`router → search → selector → context pack`).

**Lo hecho (sin commit todavía, artefactos 12/13 del autor anterior intactos):**
- **Motor M3 extraído** a `scripts/lib/selector_m3.py` (bit-a-bit del runner 15A: S1 bge-m3 cosine · S2 especificidad cross-pool · S3 estructura · S4 canonicalidad · gate rescue 0.545 · pesos 1.0/1.0/0.5/0.5). Fidelidad verificada sobre el fixture congelado: **attr 16/20 · leak 0.242 · pRel 0.577 · Q06 1/1 · Q08 2/2** = idéntico al veredicto 15A rescue.
- **`scripts/buffy-selector.sh` (NUEVO)** — wrapper CLI: `--query` + candidatos (JSON o stdin) → top-K M3. Exit 3 si Ollama no está (degradación limpia).
- **`buffy-search.sh --select`** — candidatos FTS5 → selector M3 → top-K de pasajes puntuados. Default (sin flag) intacto byte a byte; `--select` usa `or` como generador (el `and` default no recupera queries naturales — gap medido, search_recall 0.000). Con `--json` degrada a JSON de error si Ollama cae.
- **`buffy-router.sh --context`** — agrega campo `context` (pasajes top-K M3) al JSON o sección humana. Default (sin flag) intacto.
- **Tests nuevos** (`test-selector.sh`): sintaxis, uso, degradación sin Ollama, determinismo, reproducción 15A (Q08 gold en top-K), no-regresión del default. Suite: **258 OK / 4 FAIL full · 242 OK / 4 FAIL --quick** (los 4 FAIL preexistentes: 3 × test-scale ruta Termux + 1 × skills sin manifest). README actualizado.
- **Validación en vivo:** Q08 — AGENTS.md (s1 0.657, el más alto) baja por S4; Q06 — gold real `FF_SEEN` (CHANGELOG.md:217-225) entra al top-K en vivo.
- **Límite documentado:** Q08/Q03 siguen con candidate gap (el FTS5 no genera System.md — puente semántico); la generación de candidatos es del pipeline de evidencia (Pasos 12/13, autor anterior, congelados).

---

### 2026-08-13 — EVAL PC Fase 3: Pasos 14A/15A — selector quality-aware ADOPTADO (opencode, PC)

**Pedido del usuario:** separar selección de modelo: (14A) ¿un juez LLM discrimina gold vs distractor mejor que bge-m3? (15A) ¿señales multi-señal distinguen evidencia útil de ruido?

**Lo hecho (commit `77bf26a`, EVAL `98a0e308…`, pool F2 congelado):**
- **Paso 14A** (`run-selector-model-PC.sh`, phi3.5 vs bge-m3, 11 pares): phi **5/11** pair test (= bge), determinismo pares **9/11**, 14.3 s/pasaje; phi 13/97 gold vs bge 74/97 → **phi no supera a bge en ningún query → Rama B, sin 14B**. Fix OOM verificado (unload + `keep_alive=0` entre queries).
- **Paso 15** (`run-selector-quality-PC.sh`, S1 bge-m3 θ=0.55 · S2 especificidad · S3 estructura · S4 canonicalidad · S5 mtime · S7 concisión · MMR; pesos a priori; ablación M1→M4; gates hard/soft/rescue): **M3 (S1+S2+S3+S4) = 9/11 gold_over_distractor** (target ✓) · leak 0.325 · pRel 0.482 · attr 16/20. Gate soft colapsa (attr 1/20) → piso S1 esencial.
- **Ventana de rescate 0.545 (decisión 2b del usuario):** θ=0.55 cortaba el gold de Q08 (cos 0.5478) por 0.002 → `--rescue-low 0.545` = punto quirúrgico: **Q08-P_TERM_OPACITY atribuido (2/2)**, leak **0.242** (pasa gate ≤0.308), pRel **0.577**.
- **ADOPTADO: M3 rescue 0.545** — gold_over_distractor **5/11 → 9/11** · leak **0.425 → 0.242** · pRel **0.472 → 0.577** · attr 16/20 (no-regresión vs F2) · determinismo G2 ✓ (`5ab74054f1d2dcde`). **Primera adopción de la serie Fase 3.**
- **Hallazgos** (documentados, no corregidos — calibración post-hoc prohibida): S3 sobre-corrige estructuras (Q02 INFO-full.md:189 → Shizuku.md; Q07 scrcpy.md:37/README.md:73 → GameOptimization.md:54); lista de ruido S4 incompleta; piso S1 esencial.
- Registrado en `scripts/tests/evals/EVAL-REGISTRY.md` (§14A, §15A) + specs a EJECUTADO. Runtime `buffy-search.sh`/`buffy-router.sh` sigue congelado (la adopción es del componente de selección).

**Pendiente:** artefactos Pasos 12/13 (autor anterior, untracked, intactos — NO commitear sin autorización); integrar M3 con el pipeline real o resolver hallazgo S3. En el PC: `git pull` + `buffy-memory.sh sync pull` una vez.


### 2026-08-12 — EVAL PC Fase 3: Pasos 7→10B ejecutados y cerrados (opencode, PC)

**Pedido del usuario:** aprobar specs e implementar/medir los experimentos de Fase 3 uno a uno, con gates pre-fijados, determinismo G2, runtime congelado y detenerse tras cada medición.

**Lo hecho (commits `8677347`→`18df679`, EVAL congelado `98a0e308…`):**
- **Paso 7 Semantic D** (`run-semantic-PC.sh`, Ollama bge-m3): 0.200/0.192/0.669/48k → ❌ descartado (embedding aporta capacidad — Q06 primera vez — pero no precisión de buscador).
- **Paso 8 Hybrid** (`run-hybrid-PC.sh`, RRF y POOL): ≈0.200/0.185/0.605/~10k → ❌ descartado (G-H0: Q03/Q08 fuera del pool = fallo de generación).
- **Paso 9 Passages** (`run-passage-PC.sh`, VENTANA/SECCIÓN): G1 0.417/0.072/0.606/2.6k, G2 0.333/0.054/0.606/3.4k → ❌ gate pero hipótesis ✅ (28-46× menos tokens; dedup corregido).
- **Paso 10 Query expansion** (`run-expansion-PC.sh`, H1-DICT-MIN/H2-DICT-FULL): H1 0.317/gap 5/6, H2 0.367/gap 6/6 → ❌ gate pero candidate gap CERRADO (Caso D: generación resuelta, selección rota; regresión 9/12).
- **Paso 10B Reranking** (`run-rerank-PC.sh`, pool H2 congelado, señales [0,1] pesos 1.0, ablación): R1 0.750/gap 4/6/leak 0.441 (récord serie) · R2 0.700/gap 2/6 → ❌ gate (pRel 0.175/0.131, leak) pero el cuello de botella ERA el ranking; ablación: x_overlap crítica, embedding empeora, q_overlap estorba.
- **Ninguna variante adoptada** (A→R2: 0.000 → 0.750). Fase 3 sigue abierta; siguiente: diseñar Paso 11 (quality-aware passage selection), sin implementar.
- Runtime intacto (`buffy-search.sh`/`buffy-router.sh`), determinismo G2 OK, serie documentada en `scripts/tests/evals/EVAL-REGISTRY.md` + specs a EJECUTADO.

**Pendiente:** diseño del Paso 11 (reranking quality-aware). En el PC: `git pull` + `buffy-memory.sh sync pull` una vez. Handoff: `/tmp/handoff-buffy-2026-08-12.md`.


### 2026-08-11 — Benchmark realista: Fase 1 medida + Fase 2 diagnóstica + Fase 3 spec + cierre (opencode)

**Pedido del usuario:** avanzar las fases del benchmark realista; cierre de sesión por protocolo (la sesión se cortó antes).

**Lo hecho (buffy-context, sin commit previo):**
- **Fase 1 Search** (`buffy-search.sh`): `BUFFY_SEARCH_STRATEGY=or` (default `and` = baseline byte a byte) — deacent + lowercase → términos ≥3 chars sin stopwords ES → máx 8 → `OR`/BM25 → top-K. Medida: search_recall **0.000 → 0.736**, context_relevance → 0.505, controles router/multi exactos → aislamiento demostrado, FTS5 exonerado.
- **3 fixes de exactitud**: router CWD→`$REPO_DIR` (Node espurio), corpus visión path plano (`knowledge_dir: ""`), `search_recall` = `|recov ∩ gold| / |gold|`.
- **Fase 2 diagnóstica** (router `--diagnose`, report-only): 14 multi × 3 seeds = 42/42 invariante; matriz por query (23/42 sin señales, react/code-search/git/vision = cero detecciones). Veredicto usuario 🟢.
- **Fase 3 spec v2 APROBADA** (selector híbrido): gates G-R1..R6 con δ pre-fijado, regla de descarte §4.4, barrido presupuesto 700/900/1400. Paso 1: EVAL/dev congelados con sha256.
- **Reglas de arquitectura** CORE/ADAPTATION/TEST/RESEARCH en `~/AGENTS.md` y spec §11.
- Suite: **246/246 full · 230 --quick**. SESION.md podada a 5 entradas (Gmail/Drive → archive).

**Pendiente:** Fase 3 paso 2 (baseline re-congelada 3 seeds) → paso 3 (V1 híbrido). En el PC: `git pull` + `buffy-memory.sh sync pull` una vez.

---

**Cierre del día (protocolo fin de sesión):**
- **data_car commit `aea4e15` + push** — precios de la IA en Mi compra (P1 completado).
- **buffy-context commit `74fa060` + push** — registro de sesión P1 data_car.
- **SESION.md podada a 3 entradas** (las de 2026-08-09 y anteriores → `SESION-archive.md`).
- **SNAPSHOT regenerado** + `buffy-doctor.sh --quick`: **CONSISTENTE** (64 OK, 1 warning preexistente form-filler).
- **Acuerdo registrado en CONTINUE.md**: la palabra **"cerrar día"** dispara el protocolo de cierre de sesión (actualizar contexto, podar, SNAPSHOT, doctor, commit + push).

---

### 2026-08-10 — data_car P1: precios de la IA en la lista de compra + total CLP (opencode)

**Pedido del usuario:** pendiente P1 heredado — "elegir pack → agregar a compra → compartir con IA → pegar respuesta → precios asignados + total". `parseAIResponse` + `formatCLP` ya existían en `src/lib/aiShare.ts`.

**Lo hecho (`src/components/MaintenancePacks.tsx`, +118 líneas):**
- Sección "💸 Precios desde la IA" en el panel Mi compra: textarea para pegar el JSON de la respuesta + botón "Asignar precios" + contador `N/M con precio` + fila Total (CLP).
- `handleAssignPrices` (parsea con `parseAIResponse`, asigna `price` unitario por item), `findPrice` + `normalizeName` (match tolerante: minúsculas/sin acentos/sin refs en paréntesis/includes bidireccional), `computeTotal` (suma `precio × cantidad` → `formatCLP`).
- Precios persistidos en `mg350_shopping_list` → sobreviven recarga. Precio unitario visible por item.

**Verificado:** typecheck + build OK (hash `index-D4lIbUUa.js`); flujo Playwright completo — JSON realista → total $90.195 ✓, caso límite de nombres parciales → $75.000 ✓, JSON inválido → no rompe (0 errores consola), recarga → total persiste ✓.

**Pendiente:** commit + push de data_car.

---

### 2026-08-10 — Scripts Google Apps Script (Gmail Organizer V3 + Drive Organizer Pro) documentados + opencode 1.18.16 (opencode)

**Pedido del usuario:** "estábamos viendo los scripts de gmail y drive, creo que no guardaste esos últimos datos" → la sesión anterior (desde el teléfono) no había quedado registrada en buffy-context. Reconstruida desde `~/.local/state/opencode/prompt-history.jsonl` y disco.

**Hallazgos:**
- **Gmail Organizer V3** (`~/proyectos/gmail-scripts/`, scriptId `1yqqZXC4k...`): clasifica bandeja en etiquetas por categoría + empresa (BancoEstado, Tenpo, Fonasa, Mercado Libre, AliExpress, WOM...), rate limiting + reintentos + reanudación, fix de paginación (snapshot único con `search()` en vez de `getInboxThreads(pos)`), `cleanup_tmp.js` one-shot (borra etiquetas de usuario una sola vez vía `cleanupEtiquetasDone` en ScriptProperties).
- **Drive Organizer Pro v5.0** (`~/proyectos/gmail-scripts-otro/`, scriptId `1TW8pIdyQ...`): modos MAESTRO/ESPECÍFICO × PRUEBA/REAL, motor de reglas con prioridad (MIME > nombre), carpetas administradas (Scripts, Documentación, Android, Configuraciones, Multimedia, Backups, Web, Recursos, Sin clasificar, Comprimidos, Chats) y excluidas (Google Fotos, Trash), rate limiting + triggers 10 min + reanudación por cola.
- Ambos sincronizados con la web vía `clasp pull` (source of truth = nube de Google; repos locales sin remote = backup). Commits `a207071` y `610a040`.
- **opencode actualizado a 1.18.16** (la actualización que "no se realizó" ayer se completó hoy 15:19; verificado contra última de npm).

**Lección de proceso:** una sesión que toca proyectos nuevos debe registrarse en SESION.md/PROJECTS.md aunque no haya "cierre programado" — el historial de prompts de opencode permite reconstruir, pero es frágil.

---

### 2026-08-10 — P0: bench-context-selection.sh + congelamiento levantado (opencode)

**Pedido del usuario:** "vamos con los pendientes" + modo autónomo → el P0 pendiente era el benchmark de selección de contexto con router que justificaba el próximo cambio (congelamiento vigente: benchmark primero, feature después).

**Lo hecho:**
- **`scripts/tests/bench-context-selection.sh` (NUEVO)**: pipeline completo USER REQUEST → router → categoría → search FTS5 → ranking. Sandbox con Knowledge por dominio (Android/Linux/FreeFire/React) + manifests de skills; tarea real "el teléfono no aparece en scrcpy". Métricas: `domain_precision`, `domain_recall`, `spurious_categories`, `search_recall`/`search_leaked`, `context_chars/tokens`, `window_utilization`, `pipeline_healthy`. Flags: `--count/--adversarial/--json/--quick`.
- **Tesis confirmada (adversarial)**: FTS5 puro se contamina 100% (recall 0/2, leaked 10/10) pero el router carga el archivo del dominio correcto → `pipeline_healthy=true`. El router SÍ es la capa que resuelve lo que FTS5 aislado no puede.
- **Bug propio corregido**: `search_leaked` usaba grep anclado a `^` pero los hits del search empiezan con el path → medía 0 cuando había 10 contaminados. Corregido sin anclar.
- **`test-context-selection.sh` (NUEVO)** integra el benchmark a la suite (easy=gate, adversarial=medición). `run-tests.sh` sourceado.
- **README**: sección nueva + conteos → **209 full (204 functional + 5 meta) / 193 --quick (188 functional)**, árbol con 15 test_*.sh + 2 benchmarks.
- **Congelamiento LEVANTADO** en CONTINUE.md — el benchmark que lo justificaba existe y dio la evidencia esperada.

**Verificación:** suite full **209 OK / 0 FAIL** · --quick **193 OK / 0 FAIL** · benchmark standalone exit 0 en easy y adversarial.

---

### 2026-08-09 — Lección: retroalimentación activa antes de instalar herramientas + evaluación Lyxel/Mantis (opencode)

**Pedido del usuario:** "Quiero usar Mantis para scrcpy" → tras instalarlo y activarlo, resultó ser mapper de **gamepad**, no de teclado — no sirve para jugar con teclado+mouse desde PC. Lección de proceso: **preguntar el caso de uso exacto y verificar que la herramienta lo cubre ANTES de instalar/probar** (¿teclado/mouse o gamepad? ¿Linux? ¿login Google?).

**Hallazgos consolidados:**
- **Lyxel Linux** (GUI scrcpy v1.0.3): no incluye el Mapeador (solo Windows, WPF propietario). La GUI duplica funcionalidad del `scrcpy-freefire.sh` (perfiles, optimizaciones ADB) sin el mapeador ni el cleanup — no aporta. Cerrado.
- **Mantis Gamepad Pro** (oficial v3.4.8 Play Store): mapper de **gamepad físico**, no escucha teclado. Activado vía script interno `buddyNew.sh` (ADB shell — método más confiable que el flujo on-device Wireless Debugging, que está en loop porque el diálogo del sistema es modal).
- **APK parchado de Appteka** (`YOUAREFINISHED`): Google Sign-In falla siempre (SHA-1 no coincide con Firebase → `ApiException: 10` → loop). Inutilizable para apps con login de Google.
- **GG Mouse Pro 2 sigue siendo el keymapper de teclado correcto** para este setup.

**Cambios aplicados:**
- `~/.agents/skills/scrcpy-freefire/SKILL.md`: nueva sección "Regla de oro: retroalimentación activa ANTES de instalar/probar herramientas" con la lección completa.
- `Knowledge/Android/Keymappers.md`: aclarado que Mantis es de gamepad (no teclado).

### 2026-08-09 — Corrección: Mantis vs Octopus (keymappers) (opencode)

**Pedido del usuario:** confirmar conjetura "Mantis ya nadie lo usa, es baneable" → **a medias**: Mantis sigue activo (v3.4.8+, 54K reviews) pero v3.x introdujo suscripción Pro (~$9.99) e inestabilidad reportada; el **baneable por clonación es Octopus** (sandbox), no Mantis (NMC sin clonar, riesgo bajo comparable a GG Mouse Pro 2). El usuario confundió Octopus con Mantis.

**Cambios aplicados:**
- **`~/.agents/skills/scrcpy-freefire/SKILL.md`**: paquete corregido a `app.mantispro.gamepad`; activación actualizada (Android 11+: on-device Wireless Debugging); nota 2026 sobre suscripción v3.x + inestabilidad; aclarado el matiz Octopus (clonación) vs Mantis (NMC).
- **`Knowledge/Android/Keymappers.md`**: mismas correcciones (paquete, activación, nota de confusión Octopus/Mantis).
- **Implicación práctica**: GG Mouse Pro 2 (setup actual) tiene el mismo riesgo de ban que Mantis — cambiar no reduce riesgo; la única vía 100% segura según Garena son los simuladores de DPI (permitidos), no los mappers de overlay.

### 2026-08-09 — Adquisición de capacidades nuevas + fixes de integración (opencode)

**Pedido del usuario:** "hicimos cambios importantes en el repo de buffy-context, ¿puedes adquirir esas nuevas habilidades?" → pull con 2 features nuevas.

- **Adquiridas**: `buffy-memory.sh` (memoria curada estilo Hermes, `memory_engine.py`) y `buffy-search.sh` (índice FTS5). Suite **196 OK / 0 FAIL**.
- **Symlinks**: creados `buffy-memory.sh`, `buffy-search.sh`, `buffy-source.sh`, `buffy-verify.sh` en `~/.local/bin/`.
- **Fix de symlinks (commit `849ac96`)**: `buffy-memory.sh`, `buffy-context.sh`, `buffy-router.sh` no resolvían `readlink -f` → al invocarse por symlink, `SCRIPT_DIR` apuntaba a `~/.local/bin/` y el `source lib/...` fallaba. Aplicado patrón existente en `buffy-source.sh`.
- **Versiones sincronizadas (commit `5431ecf`)**: `buffy-source.sh --resolve` detectó stale real (kernel 6.18.39→6.18.42, node 26.4.0→26.7.0, npm 12.0.1→12.0.2) → INFO-core + CONTINUE corregidos → trust **100%**.
- **Memoria real inicializada** en `~/.buffy/memories/` (MEMORY 18% · USER 26%).
- **SESION.md podado** a 5 entradas / 26KB (2 viejas → `SESION-archive.md`). Doctor CONSISTENTE.


### 2026-08-09 — 🧠 Memoria curada estilo Hermes (brecha 2) — buffy-memory.sh

**Pedido del usuario:** "seguimos con la implementación para tener lo que tiene Hermes" — cerrar la brecha 2: memoria curada persistente (`MEMORY.md` + `USER.md`).

**Cambios aplicados:**
- **`scripts/buffy-memory.sh` (NUEVO)** — CLI de memoria curada: `list`, `render` (snapshot congelado para el prompt), `stats`, `add`, `replace`, `remove`, `batch` + flag `--json`. Respeta `BUFFY_MEM_DIR` (default `~/.buffy/memories`).
- **`scripts/lib/memory_engine.py` (NUEVO)** — réplica fiel de `memory_tool.py` de Hermes (Nous Research) sin dependencias:
  - Stores: `MEMORY.md` (2.200 chars) · `USER.md` (1.375 chars), entradas separadas por `\n§\n`, multiline.
  - Dedupe (preserva orden), replace/remove por **substring único** (`old_text`); ambigüedad → error con previews.
  - **Límites duros**: el add/replace que exceda el char limit se rechaza con instrucciones de consolidación.
  - **File lock** exclusivo (fcntl, `<archivo>.lock`) + escritura **atómica** (tmp + rename 0600).
  - **Guard de drift**: contenido en disco que no hace round-trip (edición manual, append, otra sesión) ABORTA la mutación y guarda `.bak.<ts>` — nunca sobrescribe lo que no entiende (issue #26045 de Hermes).
  - **Guard de lectura fallida**: archivo ilegible (UTF-8 corrupto, permiso) ≠ store vacío → se rechaza la escritura.
  - **Batch atómico** all-or-nothing contra el presupuesto FINAL (consolidar en un solo turno).
  - **Escaneo de inyección** mínimo antes de escribir (la memoria se congela en el system prompt).
- **`buffy-doctor.sh`**: nueva sección "🧠 Memoria curada" (directorio, presencia de MEMORY.md/USER.md, límites por store) — clean cuando la memoria está inicializada.
- **Protocolo**: `LOAD_CONTEXT.md` (Paso 1.5 — snapshot congelado + semántica de escritura proactiva), `~/AGENTS.md` del dispositivo (misma sección), `README.md` (feature + scripts).
- **Tests**: `scripts/tests/test-memory.sh` (8 suites: add/replace/remove, substring único, límites, drift+backup, batch atómico, inyección, render vacío/lleno, help) + `buffy-memory.sh` en el gate de sintaxis.
- Memoria REAL inicializada en este dispositivo (`~/.buffy/memories`: MEMORY 3 entradas 12% · USER 2 entradas 15%).

**Suite:** 196 OK / 0 FAIL (antes 168). Doctor: 63 OK / 2 warns / 0 err — healthy.

**Lecciones:** el matching por substring único (no IDs) obliga a entradas cortas y distintas; el `.bak` ante drift es la única protección real contra perdida de memoria editada a mano (Hermes documentó la misma lección en su issue #26045).

**Pendientes:** nada pendiente de la brecha 2. Futuras brechas Hermes ya revisadas: skills / self-improvement loop / external memory providers (no aplican o duplican lo existente).


### 2026-08-09 — buffy-search.sh: búsqueda FTS5 de sesiones (brecha vs Hermes)

**Pedido del usuario:** cerrar brechas de buffy-context frente a Hermes Agent (Nous Research) — arrancó por la búsqueda de sesiones (FTS5/SQLite, ~20ms, sin gastar tokens).

**Cambios aplicados:**
- **`scripts/buffy-search.sh` (NUEVO)**: índice FTS5 de `buffy-context` (raíz + `ai-context/` + `Knowledge/`, *.md y *.yaml) en `~/.cache/buffy-search/search.db` — una fila por línea, resultados `archivo:línea` con resaltado «término» (`snippet()`) y orden por relevancia (`bm25`).
- Tokenizer `unicode61 remove_diacritics 2` (búsqueda sin acentos). Indexado incremental por mtime+size (auto antes de cada búsqueda). Flags: `-l N`, `--update`, `--reindex`, `--stats`; `BUFFY_REPO` para otros sistemas.
- Índice 41 archivos / 7.347 líneas (~1.1MB). Búsqueda ~1s en el Mi 10.
- `sqlite` (3.53.4) instalado vía `pkg` en Termux.

**Lecciones registradas:** FTS5 no tiene `offsets()`/`matchinfo()` (son de FTS3/4); las aux functions (`snippet`/`bm25`) no funcionan con parámetros enlazados — query literal con tokens citados.

**Pendiente (brecha 2):** memoria curada estilo Hermes — `MEMORY.md` (~2.200 chars) + `USER.md` (~1.375) con límites duros, snapshot congelado al inicio de sesión y reglas de escritura en AGENTS.md.


**Pedido del usuario:** el botón "Agregar pack a compra" en data_car no mostraba nada (solo un toast de 2,5s, sin persistencia) — quería que los packs agregados quedaran visibles y conectados con el botón "Compartir con IA" para precios CLP. Además: buffy-context solo referenciaba Freebuff y quería que apunte también a opencode.

**Cambios aplicados (data_car — commit `c345d16`):**
- **Lista de compra persistente** en `localStorage` (`mg350_shopping_list`): "Agregar pack a compra" acumula el pack con items + referencias ya resueltas.
- **Botón "Mi compra"** en el header del panel de packs, con badge contador de packs (entero). Panel desplegable: cada pack con items/referencias, botón ✕ por pack y "Vaciar".
- **"Compartir compra con IA (precios CLP)"**: arma prompt con TODA la lista vía `buildAISharePrompt` y lo copia al portapapeles.
- Botón del pack cambia a "✓ En tu compra" cuando ya está agregado.
- Bug corregido: sumar cantidades daba "11.5 items" (aceite ×4.5 litros) → el badge cuenta packs, no unidades.

**Cambios aplicados (buffy-context — commit `12433bf`):** README, USER-MANU, INFO-core, LOAD_CONTEXT, code-search y vision-adapter actualizados para reflejar que Buffy corre en Freebuff **y** opencode (modelos free: DeepSeek).

**Verificado:** typecheck + build OK; flujo validado con playwright en local y producción (`scuderia-data.vercel.app`) — agregar pack → badge → panel → sobrevive recarga.

**Pendiente:** asignar precios de la respuesta de la IA a la lista + total CLP (reusa `parseAIResponse`).


### 2026-08-07 — scrcpy-freefire: sin auto-open de Free Fire + purga de 16 apps en el ZTE

**Pedido del usuario:** que el script de Free Fire no abra el juego automáticamente (solo GG Mouse, y el usuario abre Free Fire manual) + ver y desinstalar apps del ZTE.

**Cambios aplicados:**
- **`~/scripts/scrcpy-freefire.sh`**: eliminado `am start` de `com.dts.freefireth` (corría 0.8s después de GG Mouse). El script ahora solo lanza GG Mouse con sus permisos; Free Fire se abre manualmente desde el teléfono (comando manual comentado en el script).
- **Watchdog `FF_SEEN`**: antes mataba scrcpy cuando Free Fire "dejaba de correr"; como el juego ya no se abre desde el script, al arrancar no está corriendo → el watchdog viejo lo habría matado en 3s. Ahora espera a que Free Fire aparezca y recién ahí vigila su cierre desde el teléfono.
- **Purga de apps en ZTE Nubia (69 → 53)** con `pm uninstall --user 0` (todas Success): Film+, Drivify, KDE Connect, KLWP, KWGT, Firefox, Canta, Telegram+, Coddy, GitHub Store, AR Core, Excel, xm.csee, ES File Explorer, Downloader, tema oscuro de ES (huérfano).

**Archivos modificados:**
- `~/scripts/scrcpy-freefire.sh` — sin auto-open de Free Fire + watchdog FF_SEEN
- `buffy-context/ai-context/CONTINUE.md` — resumen de sesión agregado
- `buffy-context/ai-context/SESION.md` — bitácora de sesión agregada

**Verificado:** `bash -n` OK en el script; GG Mouse corriendo (PID 10067); 15 apps + 1 huérfana desinstaladas con Success; sin restos en `pm list packages`.


### 2026-08-07 — Fixes de teclado/pantalla/monitor-alert (super+Escape, DPMS, cálculo de CPU)

**Pedido del usuario:** eliminar la combinación `super + Escape` (bloqueaba el teclado y a veces congelaba la PC), evitar que la pantalla se apague sola, y verificar que la carga de CPU de la barra inferior de polybar concuerde con el script de alerta de CPU alta.

**Cambios aplicados:**
- **`super + Escape` eliminado del sxhkdrc** (`~/.config/bspwm/config/sxhkdrc`): ejecutaba `bspc wm -r` (reinicio del WM en caliente) — eso mataba el teclado y colgaba el sistema. Era un duplicado mal escrito del reload que ya existe en `super + r` (línea 59, mismo comando). Se dejó `super + ctrl + Escape` (recarga solo sxhkd, sin reiniciar bspwm) y un comentario NOTA en el archivo. sxhkd recargado con `pkill -USR1 -x sxhkd` (sin reiniciar bspwm), verificado vivo.
- **Pantalla ya no se apaga**: DPMS estaba habilitado (Standby/Suspend/Off a 600s) + screensaver X con blanking a 600s → la pantalla se apagaba a los 10 min. Fix: `xset -dpms` + `xset s off` aplicados en vivo **y agregados al `~/.config/bspwm/bspwmrc`** (después de SetSysVars) para persistir en reinicios.
- **`monitor-alert` calculaba mal el % de CPU** (`~/.local/bin/monitor-alert`, timer systemd cada 45s): la función `get_cpu()` usaba `u=$2+$4` (user+system) y `t=$2+$4+$5` (user+system+idle) sobre `/proc/stat` — campos incompletos que ignoraban `nice`/`iowait`/`irq`/`softirq`/`steal` en el denominador, más una ventana de 0.1s ruidosa. Fix: método estándar `(total − idle − iowait)/total × 100` sobre los 7 campos (user nice system idle iowait irq softirq), ventana de **1s**. Verificado con carga sintética: script corregido = estándar = 35% (antes 37/39/35 fluctuante).
- **Umbrales recalibrados** para Ryzen 5 3400G (4C/8T) + 13GB sin swap: CPU_WARN 70→**75**, CPU_CRIT 90, RAM_WARN 80→**75**, RAM_CRIT 92→**88** (sin swap el margen entre avisar y congelarse es todo lo que queda; 88% ≈ 11.5GB usados deja ~1.5GB libres para reaccionar).

**Archivos modificados:**
- `~/.config/bspwm/config/sxhkdrc` — eliminado binding `super + Escape`
- `~/.config/bspwm/bspwmrc` — `xset -dpms` + `xset s off` persistente
- `~/.local/bin/monitor-alert` — fórmula estándar de CPU + umbrales recalibrados

**Verificado:** `bash -n` OK en monitor-alert, script corre exit=0, timer systemd activo, valores concuerdan con polybar/top.

**Pedido del usuario:** refinar las barras polybar del rice vista (paneles de vidrio flotantes, jerarquía limpia), quitar el icono de Windows de la barra inferior, corregir los relieves "sucios" de la barra superior y añadir info a la barra inferior (temperatura, disco, fecha+tiempo).

**Cambios aplicados:**
- **Huecos de ~100px entre módulos (RESUELTO):** en polybar 3.7.2, `padding`/`spacing` sin unidad se renderizan como **N caracteres de espacio** (`builder.cpp`: `string(value, ' ')`), no píxeles (≈8px por espacio con JetBrainsMono 10). Fix: todos los espaciados con sufijo `px`.
- **Relieve "sucio" en bloques de la top bar:** los módulos `bi`/`bd` (`label-background = ${color.bg}`) pintaban costuras oscuras entre bloques; network/pulseaudio/updates tenían `format/label-background = ${color.mb}` (dobles rectángulos translúcidos) y los escritorios ocupados `label-occupied-background = ${color.mb}`. Fix: quitados bi/bd de `modules-center`/`modules-right` y eliminados los `*background = ${color.mb}` de módulos activos → texto/iconos limpios sobre vidrio.
- **Botón Start (logo Windows) retirado a pedido:** `[module/start]` eliminado de modules.ini y de `modules-left` de la barra inferior.
- **Fecha ausente en el reloj:** el label usaba `%date%` pero `[module/date]` no tenía la línea `date =` (solo `date-alt`) → renderizaba vacío. Fix: `date = "%a, %d %b %Y"`, `label = "%date%  %time%"`.
- **Temperatura leía 0 + `%units%` literal:** `hwmon-path` en 3.7.2 = ruta completa al **ARCHIVO** del sensor (`/sys/class/hwmon/hwmon2/temp1_input`), no al directorio (apuntar al dir → lee el dir como archivo → `strtol("")` = 0, confirmado con strace). `%units%` no es token (es la opción `units`); `%temperature-c%` ya agrega "°C".
- **Centro de barra inferior:** `bspwm` (duplicado con la top) → `cpu_bar sep memory_bar sep temp sep filesystem` con iconos FA6 Solid (   , colores red/yellow/orange/purple); `battery` quitado de `modules-right` (desktop, sin batería — solo logueaba error).
- **Barra inferior murió sola una vez:** crash transitorio de runtime (sin OOM/segfault; IPC de ArchUpdates probado en vivo = inofensivo). Reinicio desacoplado con `setsid` + log en `/tmp/opencode/bar2.log` para capturar el motivo si reaparece.

**Archivos modificados/creados:**
- `~/.config/bspwm/rices/vista/config.ini`, `~/.config/bspwm/rices/vista/modules.ini` — barras y módulos
- `~/.config/bspwm/rices/vista/CHANGELOG.md` — NUEVO: doc completo de la sesión (bugs, causa raíz, gotchas de polybar 3.7.2, mantenimiento)
- `ai-context/PROJECTS.md` — sección "Escritorio — Rice vista" actualizada al estado actual
- `ai-context/SESION.md` — entrada de sesión 2026-08-07

---

### 2026-08-06 — CodeGraph: descubrimiento y análisis de código (MCP + indexado + documentación)

**Pedido del usuario:** configurar el servidor MCP de CodeGraph para consultar el grafo del código directamente durante las sesiones de código; probarlo en vivo y documentar su uso para que los agentes lo usen primero en proyectos grandes.

**Cambios aplicados:**
- **`@colbymchenry/codegraph` v1.5.0** (NUEVO, global, MIT, 100% local): grafo de conocimiento SQLite vía tree-sitter. Comando MCP: `codegraph serve --mcp`. Telemetría **desactivada**.
- **Servidor MCP configurado en 4 agentes** (herramienta única `codegraph_explore`, probada en vivo con handshake JSON-RPC ✅): Gemini CLI (`~/.gemini/settings.json` + bloque en `GEMINI.md`), Claude Code (`~/.claude.json` + `~/.claude/settings.json` con auto-allow `mcp__codegraph__*` + hook `codegraph prompt-hook`), Antigravity (`~/.gemini/config/mcp_config.json`), Cline (VSCodium, cableado a mano — no está en la lista oficial).
- **Proyectos indexados**: `autoscript-mobile-interface` (49 archivos · 1.084 símbolos · 1.896 aristas) y `ManUninstaller` (31 · 486 · 838). `.codegraph/` gitignored en ambos.
- **Documentación**: sección "CodeGraph — Descubrimiento y Análisis (obligatorio)" en `AGENTS.md` de autoscript (comandos + ejemplos verificados); entradas en `PROJECTS.md` para GameBoost Pro Kotlin y ManUninstaller; regla global en `~/.AGENTS.md` (si existe `.codegraph/`, usar CodeGraph antes de grep/find).
- **Decisión de alcance (datos)**: NO documentar en proyectos <30 archivos fuente (widgetos 28, data_car 28, pwa_securguard 20, lista_supermercado 17, porteria_pwa 17, GameBoostPro 10, codebuff-automation 6) — el bloque global de CLAUDE.md/GEMINI.md ya activa CodeGraph donde exista índice, y el ahorro de descubrimiento solo se nota a escala de autoscript.
- **Demos de `impact` (ManUninstaller)**: `impact MainActivity` = 35 símbolos, 0 fuera del archivo (hoja del grafo — punto de entrada); `impact AppViewModel` = 47 símbolos en 2 archivos (6 call-sites en MainActivity) — mapa de riesgo para refactors.
- **Pruebas end-to-end con Antigravity (`agy --print --dangerously-skip-permissions`) EXITOSAS**: en ManUninstaller reconstruyó el flujo de desinstalación (removeAdmin en línea 208) y en autoscript el flujo de boost (facade 1 línea en :215, 3 fallbacks de ejecución Shizuku→rish→Runtime) — líneas verificadas contra el grafo, sin errores MCP.
- **CodeGraph visible para cualquier IA**: `AGENTS-root.md` sincronizado con `~/.AGENTS.md` (drift corregido, commit raíz 5862065); secciones en `INFO-core.md` (carga obligatoria), `LOAD_CONTEXT.md` ("CodeGraph PRIMERO"), `INFO-full.md` (commit 41c07f8); referencia completa nueva en `Knowledge/Tools/CodeGraph.md` (categoría Tools) con índices README actualizados y `buffy-doctor.sh` extendido (commit 341c2e5, doctor 60 OK / 0 errores).
- **Sesión documentada** en `ai-context/SESION.md` (entrada 2026-08-06).

**Archivos modificados/creados:**
- `~/.gemini/settings.json`, `~/.gemini/config/mcp_config.json`, `~/.gemini/GEMINI.md` — MCP (Gemini + Antigravity)
- `~/.claude.json`, `~/.claude/settings.json`, `~/.claude/CLAUDE.md` — MCP (Claude Code)
- `VSCodium globalStorage/saoudrizwan.claude-dev/settings/cline_mcp_settings.json` — MCP (Cline)
- `proyectos/autoscript-mobile-interface/AGENTS.md`, `.codegraph/` — sección CodeGraph + índice
- `proyectos/ManUninstaller/.gitignore`, `.codegraph/` — índice + gitignore (commits ad6a12d, e77db36, 0d29483)
- `~/.AGENTS.md` — regla global (commit raíz 6c6b985)
- `ai-context/PROJECTS.md`, `ai-context/SESION.md` — registros (pusheados 255f766, a952e44)

---

### 2026-08-03 — BUFFY_HOME / common.sh (C2, opt-in): instalaciones alternativas sin romper el diseño

**Pendiente §7.5 del digest ejecutado en modo autónomo** (Buffy PC): script común que
exporta BUFFY_HOME para redirigir el estado generado a una raíz alternativa.

**Cambios aplicados:**
- **`scripts/lib/common.sh`** (NUEVO): configuración compartida — `BUFFY_HOME`
  (default `$HOME`, opt-in), helpers `buffy_home`/`buffy_ai_context`/`buffy_snapshot`.
  **Alcance deliberado**: BUFFY_HOME redirige SOLO el estado generado (ai-context/ +
  SNAPSHOT); el escaneo del entorno del usuario ($HOME/proyectos, $HOME/scripts,
  $HOME/.agents/skills, historial) sigue con el $HOME real.
- **Scripts cableados**: `buffy-context.sh` (SNAPSHOT), `buffy-doctor.sh`
  (detección/frescura), `buffy-repair.sh` (fix_regenerate_snapshot),
  `buffy-router.sh` (base incluye SNAPSHOT) — todos vía `source lib/common.sh`.
  Sin BUFFY_HOME definida → comportamiento idéntico (verificado).
- **`scripts/tests/test-common.sh`** (NUEVO): 6 tests — helpers default/custom,
  buffy-context genera SNAPSHOT bajo BUFFY_HOME, sin BUFFY_HOME no rompe,
  doctor/router respetan BUFFY_HOME. Sin sandbox → corren en --quick.
- **`scripts/tests/run-tests.sh`**: source del nuevo test + bash -n incluye los
  scripts ya listados (common.sh se valida por el test de helpers).
- **`INSTALL.md`**: sección "Configuración opcional: BUFFY_HOME (C2)" — qué redirige,
  qué no, y qué scripts lo respetan.
- **Validación**: suite `--quick` **116 OK** / completa **132 OK** · doctor 0
  errores · bash -n OK · prueba real: SNAPSHOT generado en `/tmp/...` con
  BUFFY_HOME y en `$HOME` sin él.

**Archivos modificados/creados:**
- `scripts/lib/common.sh`, `scripts/tests/test-common.sh` — NUEVOS
- `scripts/buffy-context.sh`, `scripts/buffy-doctor.sh`, `scripts/buffy-repair.sh`,
  `scripts/buffy-router.sh`, `scripts/tests/run-tests.sh`, `INSTALL.md` — MODIFICADOS

---

### 2026-08-03 — Schema-lite B1: validador estructural de ai-context (ai-context-lint.sh)

**Pendiente §7.4 del digest ejecutado en modo autónomo** (Buffy PC): JSON Schema + test
para INFO-core/CONTINUE/LOAD_CONTEXT. Decisión de diseño: validador bash puro
(consistente con el repo), no JSON Schema formal — los consumidores son LLMs que leen
markdown, y un schema-lite cubre el 80% del valor (como sugería el digest).

**Cambios aplicados:**
- **`scripts/ai-context-lint.sh`** (NUEVO): valida las secciones obligatorias que
  LOAD_CONTEXT.md promete — INFO-core (`## Sistema`, `## Hardware`, `## Reglas personales`,
  `## Estructura de proyectos`), CONTINUE (`## Resumen de la sesión`, `## Pendientes para
  próxima sesión`, `## Stack del usuario`), LOAD_CONTEXT (`## Protocolo obligatorio al
  iniciar sesión`, `## Carga condicional`, `## Arquitectura de memoria`) — + front-matter
  semver-lite (`X.Y` o `X.Y.Z`, convención del repo) y `updated` ISO. Flags `--repo`,
  `--json` (stderr limpio), `--quick`, exit 0/1/2.
- **Hallazgo real del validador**: 3 front-matters (AGENTS.md, README.md, PROJECTS.md)
  usaban `version: X.Y` (2 segmentos). Decisión: el validador acepta semver-lite X.Y/X.Y.Z
  para alinearse con la convención existente de ai-context (skill.yaml sí exige X.Y.Z).
- **`scripts/tests/test-ai-context-lint.sh`** (NUEVO): 5 tests — --help, repo sano (--json
  schema + stderr limpio), secciones obligatorias presentes, repo roto (exit 1 + JSON),
  front-matter semver-lite (X.Y y X.Y.Z válidos, rotos → exit 1), opción desconocida
  (exit 2). Fixtures temporales en /tmp, sin sandbox → corren también en --quick.
- **`scripts/tests/run-tests.sh`**: source del nuevo test + `ai-context-lint.sh` añadido
  al bash -n previo.
- **CI**: el job `suite` ya corre `run-tests.sh --json` → los 5 tests nuevos entran solos
  (sin editar el workflow).
- **Validación**: suite `--quick` 105 OK / completa **121 OK** · doctor 0 errores/1
  warning · bash -n OK.

**Archivos modificados/creados:**
- `scripts/ai-context-lint.sh`, `scripts/tests/test-ai-context-lint.sh` — NUEVOS
- `scripts/tests/run-tests.sh` — MODIFICADO

---

### 2026-08-03 — CI en GitHub Actions: suite completa + doctor con baseline de drift

**Pedido del usuario:** crear un workflow que corra la suite completa y el doctor en cada push/PR. Decisión autónoma: el doctor bloquea **solo drift nuevo** (baseline medido en CI) para no dejar el CI permanentemente rojo.

**Cambios aplicados:**
- **`.github/workflows/ci.yml`** (NUEVO): dos jobs paralelos en `ubuntu-latest` — (1) **suite**: `run-tests.sh --json` como gate obligatorio; (2) **doctor**: `buffy-doctor.sh --json` con `BASELINE_ERRORS=16` (configurable) — el parseo es directo en python (una sola llamada, imprime resumen + lista ERR, falla con `::error::` solo si el drift aumenta; JSON no parseable → job falla en voz alta). `permissions: contents: read`, `timeout-minutes`, `concurrency` (cancela runs superseded), push en todas las ramas + PRs.
- **Hallazgo de validación**: en un runner con HOME limpio el doctor ve **16 errores, no 13** — las skills que solo existen en `~/.agents/skills/` localmente pasan de `SKILL_NOT_IN_REPO` (warn) a `MISSING_SKILL` (err). El baseline se fijó a 16 (medido en clon fresco con HOME aislado). También se detectó un YAML inválido (python inline a columna 1 dentro del bloque `run: |`) y se corrigió indentándolo.
- **`README.md`**: badge de CI + sección "GitHub Actions" en Testing (nota del baseline 16 vs 13 local).
- **`CONTRIBUTING.md`**: nota sobre CI en la sección Tests (el doctor falla si un PR introduce drift nuevo).
- **Validación**: YAML parseable (pyyaml), simulación del job doctor en clon fresco con HOME aislado (errors=16 = baseline → pasa; baseline=10 → falla, probando el gate), suite local, reviewer con sign-off.

**Archivos modificados/creados:**
- `.github/workflows/ci.yml` — NUEVO
- `README.md`, `CONTRIBUTING.md` — MODIFICADOS

---

### 2026-08-03 — Entrada de release automática en el CHANGELOG (set-version + changelog-entry)

**Pedido del usuario:** integrar `set-version.sh` con el changelog para generar la entrada de release automáticamente.

**Cambios aplicados:**
- **`scripts/changelog-entry.sh`** (NUEVO): genera la entrada de release desde git log — título `### <fecha> — Release vX.Y.Z`, sección **Cambios incluidos** (asuntos de commits desde el último tag) y **Archivos modificados/creados** (git diff --name-status). Modo `--dry-run` (previsualiza sin escribir), inserta tras la cabecera del CHANGELOG y actualiza el front matter `updated:`. **Sanitiza referencias `skills/<nombre>`** para que el doctor no las tome como skills documentadas (drift falso).
- **`scripts/set-version.sh`**: ahora genera la entrada del CHANGELOG antes del commit de release y commitea `VERSION` + `ai-context/CHANGELOG.md` juntos; si la generación falla advierte y continúa; si el commit falla restaura VERSION y hace checkout del CHANGELOG.
- **`scripts/tests/test-changelog.sh`** (NUEVO): 3 tests de sandbox — estructura del `--dry-run` (cabecera + commits + archivos), sanitización de `skills/` (no expone el nombre), inserción real en copia (cabecera intacta, nueva entrada al inicio, +1 entrada).
- **`scripts/tests/run-tests.sh`**: `changelog-entry.sh` añadido al bash -n previo + source del nuevo test file.
- **`README.md`**: sección Versioning actualizada (generación automática + `--dry-run`).
- **Validación**: suite completa + suite `--quick` + reviewer con sign-off.

**Archivos modificados/creados:**
- `scripts/changelog-entry.sh`, `scripts/tests/test-changelog.sh` — NUEVOS
- `scripts/set-version.sh`, `scripts/tests/run-tests.sh`, `README.md` — MODIFICADOS

---

### 2026-08-03 — Pendientes de infraestructura: CONTRIBUTING, versionado semántico, modo --quick, installer mejorado, migración SYSTEM.md

**Cambios aplicados:**
- **`CONTRIBUTING.md`** (NUEVO): guía para contribuidores corregida a la realidad del repo (remote GitHub real, suite bash puro, hook instalado vía `scripts/hooks/install.sh`).
- **`VERSION`** (NUEVO, `v1.0.0`) + **`scripts/set-version.sh`** (NUEVO): versionado semántico — valida `vX.Y.Z`, corre la suite, commitea `VERSION`, crea tag anotado y lo pushea. Sección `## Versioning` en README.
- **`scripts/tests/run-tests.sh`**: nuevo flag `--quick` que salta los ciclos de sandbox (heurística automática: cualquier test cuyo cuerpo llame `setup_sandbox` se omite) — rápido para hooks/CI. Nuevo **`scripts/tests/test-runner.sh`** (self-tests del runner con invocación filtrada para evitar recursión).
- **`scripts/hooks/pre-commit.sh`**: ahora corre la suite en modo `--quick` por defecto; `BUFFY_HOOK_FULL=1` fuerza la suite completa puntualmente.
- **`scripts/hooks/install.sh`**: opciones `--install/--uninstall/--check/--force/--no-test/--help`, manteniendo el mecanismo de escribir el hook con el shebang real (fix Termux).
- **`scripts/migrate-system.sh`** (NUEVO): migración de los stubs `SYSTEM.md`/`SYSTEM_FULL.md` (contenido ya fusionado en `INFO-core.md`/`INFO-full.md`) a `ai-context/deprecated/` con timestamp, sed de referencias y verificación con la suite `--quick`. **EJECUTADO en el repo real el 2026-08-03** (decisión del usuario) — ver entrada de migración más abajo.
- **`README.md`**: sección `## Versioning` + docs del modo `--quick` y de las variantes del hook (`BUFFY_HOOK_FULL`, re-instalación con `--force`).
- **Validación**: suite completa 66/66 + suite `--quick` + reviewer con sign-off.

**Archivos modificados/creados:**
- `CONTRIBUTING.md`, `VERSION`, `scripts/set-version.sh`, `scripts/migrate-system.sh`, `scripts/tests/test-runner.sh` — NUEVOS
- `scripts/tests/run-tests.sh`, `scripts/hooks/pre-commit.sh`, `scripts/hooks/install.sh`, `README.md` — MODIFICADOS

---

### 2026-08-03 — README actualizado: árbol de skills/Knowledge refleja el disco

**Pedido del usuario:** el árbol del README no coincidía con el disco — el origen histórico del drift del doctor.

**Cambios aplicados:**
- **Árbol de `.agents/skills/`**: ahora muestra las **23 skills** agrupadas por dominio (Android 8, Web 2, Framework v4 5, Code & research 2, Frontend 4, Operación 2) — antes solo 10; se agregaron las 10 creadas + las 3 migradas (form-filler, image-analyzer, xiaomi-adb-tricks).
- **Árbol de `Knowledge/`**: agregadas la categoría `AI/` (Kimi-K3.md) y `Vision.md` (antes invisibles); nota de versiones mínimas en scrcpy.md.
- **Árbol de `scripts/`**: agregados skill-lint.sh, migrate-system.sh, set-version.sh, changelog-entry.sh, ollama-kill.sh, see.sh, lib/, hooks/, tests/ (antes solo 7 entradas).
- **"What's included"**: Knowledge 17 files/7 categorías + Vision, 23 skills con manifest, CI verde 106 checks.
- **Nueva sección "Skills (23 en disco)"**: tabla por grupo con nota de que el router las descubre por triggers.
- **Tabla de categorías de Knowledge**: agregadas AI (1) y Vision (1).
- **Validación**: doctor 0 errores (las 23 skills documentadas coinciden con disco — sin drift falso), suite `--quick` 90 OK.

**Archivos modificados:**
- `README.md` — MODIFICADO (71+/20-)

---

### 2026-08-03 — Versiones mínimas de scrcpy/Ollama documentadas

**Decisión del usuario:** cerrar el pendiente (b) del digest — documentar las versiones mínimas verificadas desde el PC, con fuente.

**Cambios aplicados:**
- **`Knowledge/Android/scrcpy.md`**: sección "Versiones mínimas" — UHID ≥ 2.0 (release v2.0), `--video-buffer` ≥ 1.18, `--render-expired-frames` ≥ 1.19, `--stay-awake` ≥ 1.5, `--power-off-on-close` ≥ 1.20 con **fix en 3.3.1 (#6146)** → **mínimo recomendado ≥ 3.3.1** para el setup gaming. Verificado en el PC: `scrcpy 4.1-1` + `adb 1.0.41`.
- **`Knowledge/Vision.md`**: sección "Versión de Ollama" — mínimo **≥ 0.30**, verificado binario `0.30.7` (sirviendo en `:11434`), paquete pacman `0.32.1-1`, último upstream v0.32.5. Notas: servicio de sistema activo (el de usuario deshabilitado), bug `ollama run` timeout → usar API, tags `:cloud` no ocupan RAM local.
- **`BUFFY-PC-CONTEXT.md`** §7.6(b) y **`REVIEW-BASELINE.md`** §2.6: marcados como HECHA (antes "pendiente de decisión del usuario").
- **`ai-context/CONTINUE.md`**: pendiente (b) resuelto.
- **Validación**: doctor 0 errores + suite `--quick` (antes de commit).

**Archivos modificados:**
- `Knowledge/Android/scrcpy.md`, `Knowledge/Vision.md` — MODIFICADOS
- `BUFFY-PC-CONTEXT.md`, `REVIEW-BASELINE.md`, `ai-context/CONTINUE.md` — MODIFICADOS

---

### 2026-08-03 — Migración SYSTEM.md/SYSTEM_FULL.md → deprecated/ (ejecutada)

**Decisión del usuario:** marcar como 🔴 crítica la migración de los stubs SYSTEM.md/SYSTEM_FULL.md (contenido ya fusionado en INFO-core/INFO-full desde antes).

**Cambios aplicados:**
- **`scripts/migrate-system.sh`** EJECUTADO: los 2 stubs movidos a `ai-context/deprecated/` (con timestamp), referencias en `.md`/`.sh` actualizadas (AGENTS.md, README, LOAD_CONTEXT, CHANGELOG, CONTINUE, BUFFY-PC-CONTEXT, REVIEW-BASELINE).
- **Correcciones manuales post-sed**: el sed global reemplazó `SYSTEM.md`→`AGENTS.md` ciegamente — se corrigió a mano: `ai-context/AGENTS.md` y `ai-context/README.md` ahora apuntan a `INFO-core.md`/`INFO-full.md` (destino real del contenido); árbol de `LOAD_CONTEXT.md` y `README.md` raíz muestran `deprecated/`; bitácoras históricas (SESION.md, SESION-archive.md) revertidas (no se reescriben).
- **Doctor**: ya no reporta `DEPRECATED_FILE` (los archivos ya no están en `ai-context/`).
- **Validación**: suite `--quick` ✅ (corrida por el propio script) + suite completa + doctor 0 errores.

**Archivos modificados/creados:**
- `ai-context/deprecated/{SYSTEM.md,SYSTEM_FULL.md}.20260803_150816` — MOVIDOS
- `ai-context/AGENTS.md`, `ai-context/README.md`, `ai-context/LOAD_CONTEXT.md`, `README.md`, `BUFFY-PC-CONTEXT.md`, `REVIEW-BASELINE.md`, `ai-context/CHANGELOG.md`, `ai-context/CONTINUE.md` — MODIFICADOS

---

### 2026-08-03 — Suite de tests permanente + pre-commit hook

**Pedido del usuario:** Convertir los checks ad-hoc (18/18 doctor/repair/agent) en una suite versionada con runner único, y añadir hook de pre-commit que ejecute la suite antes de cada commit.

**Cambios aplicados:**
- **`scripts/tests/`** (NUEVO): suite permanente en **bash puro** (bats no requerido — no está disponible en Termux). `run-tests.sh` es el runner único (bash -n previo de los 5 scripts, descubre `test_*` vía `declare -F`, `--json` para CI, filtro por nombre, `trap` que limpia el sandbox, exit 0/1 honesto). `helpers.sh` aporta `ok/bad/check/expect_exit/jassert` + `setup_sandbox` (copia del repo, HOME aislado, drift artificial: sin ~/ai-context y sin skills).
- **`scripts/tests/test-doctor.sh`**: `--json` schema + conteos coherentes, catálogo fix_id (id/fix/safe/target + safe coherente con FIX_SAFE), errores con identidad (INVALID_REPO/UNKNOWN_OPTION), stderr limpio, `--quick` == `--json`, exit codes honestos.
- **`scripts/tests/test-repair.sh`**: dry-run en repo real sin escribir (verificado con git status), `--auto` en sandbox reduce drift 26→0, regresión del bug `local skill dir` (cada skill en su dir con SKILL.md), `--fix` puntual, exit codes 0/1/2.
- **`scripts/tests/test-agent.sh`**: ciclo completo en sandbox (drift→0, `repair.ran=true`, exit 0), `--no-repair` en repo real, exit condicional al estado real (suite determinística).
- **`scripts/hooks/pre-commit.sh`** (NUEVO): hook versionado (no se pierde en clones) que ejecuta la suite y aborta el commit si falla.
- **`scripts/hooks/install.sh`** (NUEVO): instalador que genera `.git/hooks/pre-commit` con el shebang de bash **real del sistema** — necesario en Termux, donde `/usr/bin/env` no existe y git ejecuta los hooks con exec directo (el primer commit falló con `cannot exec '.git/hooks/pre-commit': No such file or directory`; resuelto resolviendo `command -v bash`). `git commit --no-verify` para saltar.
- **`README.md`**: sección `## Testing` (uso del runner, `--json` para CI, filtro, instalación del hook con `bash scripts/hooks/install.sh`).
- **Validación**: 59/59 checks OK (1 ronda falló por resolución de rutas del runner — SCRIPT_DIR terminaba en /tests — y por regex ERE que interpretaba los paréntesis literales de `error(es)`; ambos corregidos). 2 rondas de code review con sign-off.

**Archivos modificados/creados:**
- `scripts/tests/{run-tests.sh,helpers.sh,test-doctor.sh,test-repair.sh,test-agent.sh}` — NUEVOS
- `scripts/hooks/pre-commit.sh` — NUEVO
- `README.md`, `ai-context/CHANGELOG.md` — actualizados

---

### 2026-08-03 — Ciclo operativo completo: doctor --json con catálogo fix_id + buffy-repair + buffy-agent

**Pedido del usuario:** Cerrar el lazo doctor → decisión → acción (antes el sistema solo detectaba problemas, no actuaba). Diseño acordado: catálogo de `fix_id` en doctor --json (evita un sistema de parches), ajustes de base en buffy-context.sh, actuador buffy-repair.sh con clasificación AUTO_SAFE/REVIEW_REQUIRED, y orquestador buffy-agent.sh al final (envoltura de piezas confiables).

**Cambios aplicados:**
- **`scripts/buffy-doctor.sh`** (NUEVO): auditoría con `--json` — cada item accionable lleva identidad `{id, fix, safe, target}` (p.ej. `MISSING_SKILL / create_skill_dir / safe:true / "android-agent"`). Catálogo FIX_SAFE: AUTO_SAFE (regenerate_snapshot, create_ai_context_dir, create_skill_dir, chmod_plus_x) vs REVIEW_REQUIRED (create_*file, copy/migrate_skill, remove_or_merge, git_init, update_index). Detección de SNAPSHOT stale (STALE_SNAPSHOT) parseando `Generated:`. Errores con identidad (INVALID_REPO, UNKNOWN_OPTION); stderr limpio en modo JSON. Validado: 10/10 tests.
- **`scripts/buffy-context.sh`**: shebang zsh → bash (consistencia con doctor/router; `--watch` re-ejecuta con bash), exit codes reales (0 éxito / 1 fallo verificable), header `> ⏱️ Generated: <ts>` en SNAPSHOT.md (frescura medible), `mkdir -p` del directorio destino (bug latente en sistemas sin ~/ai-context).
- **`scripts/buffy-repair.sh`** (NUEVO): actuador con `case "$fix"` puro (sin parseo de mensajes). Dry-run por defecto; `--auto` solo AUTO_SAFE; `--fix NOMBRE`; `--json`; loop doctor → repair → verify con delta reportado. Exit codes honestos (0 limpio / 1 review pendiente o fixes fallidos / 2 error).
- **`scripts/buffy-agent.sh`** (NUEVO): orquestador del ciclo — preflight (doctor --json) → repair --auto si hay drift → verify (doctor --json) → load (buffy-router) si hay mensaje. JSON final `{repo, preflight, repair, verify, load, ready}` para CI/protocolo. Validado: 18/18 tests (sandbox: drift 19→0 errores, 19 skills creadas en disco).
- **`scripts/buffy-router.sh`** (NUEVO, ya existía localmente): carga condicional de contexto por categorías (base, knowledge, skills, scripts) con `--json`.
- **`.agents/skills/`**: 5 skills nuevas con contenido curado (android-adb, android-game-opt, hyperos-hardening, scrcpy-freefire, shizuku-rikka).
- **Bugs de bash encontrados en el camino**: `${arr[]}` con subscript vacío escupe "bad array subscript" (guard en jitem); `local skill="$1" dir="...$skill..."` expande con el valor viejo → skills se creaban en el dir equivocado (locals separados en fix_create_skill_dir).

**Archivos modificados/creados:**
- `scripts/buffy-doctor.sh`, `scripts/buffy-repair.sh`, `scripts/buffy-agent.sh`, `scripts/buffy-router.sh` — NUEVOS
- `scripts/buffy-context.sh` — modificado
- `.agents/skills/{android-adb,android-game-opt,hyperos-hardening,scrcpy-freefire,shizuku-rikka}/` — NUEVOS
- `README.md`, `INSTALL.md`, `ai-context/CHANGELOG.md` — actualizados

---

### 2026-08-02 — Organización del home + Ollama al HDD + unificación ai-context

**Pedido del usuario:** organizar el caos del home (con HDD disponible) y unificar el ai-context duplicado en una sola fuente de verdad.

**Cambios aplicados:**
- `~/Backups` (28G) → `/media/datos/Backups` con symlink (copia verificada byte a byte antes de borrar)
- `data_car`, `codebuff-automation`, `odysseus` → `~/proyectos/` con symlinks (no rompe rutas absolutas)
- Notas sueltas → `~/notas/`; logs → `~/logs/`; basura eliminada (`ervice --no-pager -n 50`, `udo systemctl start bluetooth.service`)
- Caches limpiados: npm, gradle, `~/.cache` (8.5G→360M) — disco del sistema 67% → 39%
- `~/.ollama` (14G) → `/media/datos/ollama` con symlink; deshabilitado el servicio de usuario duplicado (crash-loop); queda solo el servicio de sistema (`/usr/local/bin/ollama`)
- Skill `file-organizer` instalada desde `ComposioHQ/awesome-claude-skills`
- ai-context unificado: fusión bidireccional de `SESION.md` y `CHANGELOG.md` en `buffy-context/`; `~/ai-context` → symlink al repo; `AGENTS-root.md` → `INFO-core.md` (SYSTEM.md está deprecado)

---

### 2026-08-01 — systemd-boot fix + ask-model.js "segundo cerebro" + kimi_vision.js adoptado

**Pedido del usuario:** (1) arreglar que el menú de arranque esperara Enter, (2) montar un complemento para consultar otros modelos (local/nube) cuando yo tenga dudas, (3) adoptar la mejora kimi_vision.js del repo buffy-context.

**Cambios aplicados:**
- **systemd-boot (no GRUB)**: variable EFI `LoaderConfigTimeout` (4a67b082-...) estaba en `menu-force` → esperaba Enter indefinidamente pisando el `timeout 3` del `loader.conf`. Fix: `bootctl set-timeout 3`, luego `0` a pedido del usuario (arranque instantáneo). `loader.conf`: `timeout 0`. Escape: boot counting/fallback + `systemctl reboot --boot-loader-menu=force`.
- **`codebuff-automation/ask-model.js`** (NUEVO): consulta a Ollama local (qwen2.5:7b) o HF Router nube (DeepSeek V4 Flash/Pro/R1, Kimi K3). Modos one-shot, `--chat` (memoria), `--list`, `--json`, separador `--`.
- **`codebuff-automation/lib/utils.js`**: `resolveHfToken()` compartida (env HF_TOKEN > `~/.huggingface/token` > vacío, fallback Termux). ask-model.js y kimi_vision.js la importan (refactor post-revisión).
- **`~/.huggingface/token`** (chmod 600): token HF configurado.
- **kimi_vision.js + lib/{logger,utils}.js + Kimi-K3.md** vendored desde `maneskinleon-del/buffy-context` → `codebuff-automation/`; skills image-analyzer actualizadas (kimi_vision recomendado, auto_permiso.py fallback OCR); provenance en codebuff-memoria.md.
- **Verificado**: `node --check` en los 3 scripts; consultas reales a qwen2.5:7b, DeepSeek V4 Flash y Kimi K3 ✅; 2+ pasadas de code review aprobadas.

**Aclaración clave:** MCP conecta herramientas (el LLM es el cliente, los servidores exponen tools). Para "consultar otro modelo" no hace falta MCP — es una llamada HTTP OpenAI-compatible.

---

### 2026-08-01 — Cleanup real al salir en scrcpy-freefire.sh + limpieza del teléfono (laboratorio)

**Pedido del usuario:** al cerrar el script de Free Fire, cerrar las apps abiertas y apagar la pantalla (las apps seguían corriendo y gastaban batería). Además, empezar a limpiar el teléfono como laboratorio de pruebas.

**Qué se hizo:**
1. **Cleanup real al salir en `scrcpy-freefire.sh`**: `close_game_apps()` + apagado de pantalla a los 5s. Misterio resuelto: la sesión anterior corría código viejo (solo force-stop a 2 apps). Descubrimiento clave: 8 apps (Device Admins/auto-reinicio) ignoran el force-stop de Android.
2. **Mecanismo nuevo**: `KILL_PERSISTENT` (default `0` seguro), `pm disable-user` al cerrar para matar de verdad a los Device Admins, `pm enable` + `dpm set-active-admin` al iniciar para restaurarlos completos (incluido el estado de admin — `pm enable` NO lo restaura), gate `SESSION_STARTED` (solo limpia si el juego arrancó).
3. **Nuevo `scrcpy-freefire-restore.sh`**: restauración manual independiente; lee listas del main vía `sed` (una sola fuente de verdad).
4. **Cierre con Alt+Q** (`sxhkdrc:162`): hint del notify actualizado (`Alt+Q para salir`).
5. **Limpieza del teléfono**: desinstalados Tasker (`net.dinglisch.android.taskerm`), Automate (`com.llamalab.automate`) y Facebook (`com.facebook.katana`). Detalle técnico: eran Device Admins activos → bloqueo `DELETE_FAILED_DEVICE_POLICY_MANAGER`; solución `pm disable-user` → desactiva el admin → `pm uninstall`. Único admin restante: MacroDroid.
6. **Scripts actualizados**: `PERSISTENT_APPS` y `PERSISTENT_ADMIN_RECEIVERS` sin tasker/automate (restore se autoactualiza).

**Transparencia:** los ciclos disable→enable de prueba desactivaron el Device Admin de MacroDroid/Tasker/Automate; restaurados con `dpm set-active-admin` (los 3 con Success).

**Validación:** `bash -n` OK en ambos scripts, sync a `.openclaw/`, revisor aprobó, desinstalación verificada (`pm path` vacío).

**Pendiente mañana:** borrar más apps del lab (candidatos: MacroDroid, AutoJS, Kustom Widget, Steps, `com.launcher.hype`); considerar `KILL_PERSISTENT=1` para lab sin apps corriendo.

---

### 2026-08-01 — Fix ruta de rish + prueba real de --grant con diálogo de permiso

**Hallazgo:** En la primera prueba real con `--grant`, el script fallaba con `rish: not found` porque rish vive en `~/bin/rish` y no está en PATH en este dispositivo.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): nueva función `resolveRish()` — resuelve la ruta con prioridad env `RISH` > `~/bin/rish` (si existe) > `rish` en PATH (vía `command -v`) > fallback `rish`. La constante `RISH` usa ahora la ruta resuelta.
- **Prueba real completada**: diálogo de notificaciones de VInstall (`com.vinstall.alwiz`) detectado por Kimi K3 al 98% (título, botones PERMITIR/NO PERMITIR) y concedido: `pm grant POST_NOTIFICATIONS` + `appops POST_NOTIFICATION=allow`. Verificado: `granted=true`, appop `allow`.

---

### 2026-08-01 — Fix endpoint Kimi K3 (router.huggingface.co/v1, sin /hf)

**Hallazgo:** El endpoint `/hf/v1/chat/completions` devuelve 404; el correcto es `https://router.huggingface.co/v1/chat/completions` (verificado con prueba real: HTTP 200, Kimi K3 respondió en 10.2s).

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (y `~/kimi_vision.js`): `KIMI_ENDPOINT` default corregido a `router.huggingface.co/v1/chat/completions` (header + constante), + hint de error para 404 que recomienda revisar `KIMI_ENDPOINT`.
- **`Knowledge/AI/Kimi-K3.md`**: las 3 referencias al endpoint actualizadas a `/v1` (tabla de acceso, ejemplo curl, sección Script implementado).
- **Nota:** las entradas históricas de este CHANGELOG mencionan `/hf/v1`; quedan como referencia del estado previo al fix.

---

### 2026-08-01 — kimi_vision.js integrado al repo buffy-context

**Pedido del usuario:** Agregar kimi_vision.js al repo: copiarlo a scripts/ y documentarlo en Knowledge/AI/Kimi-K3.md.

**Cambios aplicados:**
- **`scripts/kimi_vision.js`** (NUEVO): copia del script de visión IA (Kimi K3) para detectar diálogos de permisos — upgrade de auto_permiso.py. Idéntico al origen `~/kimi_vision.js` (22639 bytes, diff 0), `node --check` OK.
- **`scripts/lib/logger.js` + `scripts/lib/utils.js`** (NUEVOS, vendored): copias de `~/lib/` para que el script sea **autocontenido y ejecutable desde el repo** (verificado: `node scripts/kimi_vision.js --help` ✅). Marcados como copia vendored (actualizar desde `~/lib/`).
- **`Knowledge/AI/Kimi-K3.md`**: Nueva sección "Script implementado: scripts/kimi_vision.js" — modos CLI, cómo funciona (base64 → Kimi K3 → JSON → mapeo rish), robustez (retry/backoff, parseo robusto, fallback other), verificación.
- **`README.md`**: árbol de scripts actualizado con `kimi_vision.js`.

---

### 2026-08-01 — kimi_vision.js creado + repo clonado vía SSH

**Pedido del usuario:** Crear el script kimi_vision.js (visión IA con Kimi K3 para detectar diálogos de permisos, upgrade de auto_permiso.py) y sincronizar buffy-context con un clon local vía SSH.

**Cambios aplicados:**
- **`~/kimi_vision.js`** (NUEVO, fuera del repo): visión IA con `moonshotai/Kimi-K3` vía API HF OpenAI-compatible (`router.huggingface.co/hf/v1/chat/completions`). Screenshot en base64 → modelo devuelve JSON (tipo de permiso, app, botones, confianza) → mapeado a `pm grant`/`appops set` vía rish. Modos: `--img`, `--monitor`, `--watch`, `--screenshot`, `--grant`, `--pkg`, `--json`. Requiere `HF_TOKEN` + licencia gated aceptada. Probado con API simulada ✅ (extractJson 3 casos, mapeo, pipeline completo); 2 pasadas de code review (fixes: mtime en monitorLoop, orden help-vs-token, Number.isFinite en args).
- **Repo clonado**: `~/buffy-context` vía HTTPS + remote `origin` en SSH (`git@github.com:...`). 44 archivos, working tree limpio, los 5 commits del doc Kimi K3 presentes.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 actualizada — kimi_vision.js + clon SSH + pendientes (clave SSH por registrar, HF_TOKEN, prueba real).
- **Clave SSH**: ed25519 generada en este dispositivo; **pendiente de registrar** en github.com/settings/keys (el token actual no tiene scope `admin:public_key`).

---

### 2026-08-01 — Kimi K3 vía Hugging Face + MCP documentado

**Pedido del usuario:** Investigar cómo usar Kimi K3 (Moonshot AI) desde Hugging Face vía MCP y documentar el hallazgo en el repo.

**Cambios aplicados:**
- **`Knowledge/AI/Kimi-K3.md`** (NUEVO): Referencia del modelo — 2.8T params MoE, multimodal nativo, 1M contexto, tool calling. Acceso: HuggingChat web, API OpenAI-compatible `router.huggingface.co/hf/v1` + token HF (pago por uso), API Moonshot. Aclaración clave: MCP conecta herramientas, NO es la forma de usar el modelo (HuggingChat es cliente MCP; el MCP oficial de HF expone el Hub). Casos de uso: visión de screenshots (upgrade OCR/auto_permiso.py), análisis de contexto 1M (CSVs SecurGuard, dumpsys, logcat), segunda opinión de código, JSON estructurado.
- **`Knowledge/README.md`**: Nueva categoría `AI/` indexada en el árbol + fecha actualizada a 2026-08-01.
- **`ai-context/SESION.md`**: Sesión 2026-08-01 registrada; sesión 07-29 archivada (poda automática).
- **`ai-context/SESION-archive.md`**: Sesión 07-29 (día completo) movida al archivo.

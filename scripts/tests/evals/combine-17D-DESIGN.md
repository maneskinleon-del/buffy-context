# Paso 17D — Especificación congelada: V1 (ensamblado) + DICT_H1_B (ranking) combinados

> Fecha de diseño: 2026-08-15 · Antecede a TODO el código del experimento.
> Esta spec NO implementa nada: parte de V1 + DICT_H1_B como combinación
> hipotética, define objetivo, factores, corpus/EVAL, gate completo pre-fijado,
> controles, determinismo G2, criterios de adopción/descarte y riesgos de
> interacción. Se ejecuta SOLO tras la aprobación del usuario.
> **Decisión del usuario: diseñar 17D ahora, NO ejecutar todavía.**
>
> **Regla de ceguera (exigida por el usuario):** el experimento NO nace como
> "probemos V1+B porque probablemente dé 13/20 y 0.250". La hipótesis es buena,
> pero el gate se pre-fija por CONTRATO (§4), no por el resultado esperado, y
> el análisis (§5) reporta deltas por gold y diagnóstico de interacción — no
> una confirmación de la expectativa aditiva.

---

## 0. Cadena de evidencia que justifica este paso (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 17B | **B (DICT_H1_B, `f534283f`):** attr 12→**13/20** (Q05 rescatado), pRel 0.415→**0.531**, leak 0.442 (invariante), contain 1.0, cero regresiones. PASS experimental / NO ADOPTED | `bridge-17B-PC-2026-08-14-*.json` |
| 17C | **V1 (exclusión dura de noise):** leak 0.442→**0.250** (-43%), pRel 0.415→**0.584**, attr 12/20 (Q05 sigue 0 sin B), contain 1.0, cero regresiones. PASS del objetivo primario / NO ADOPTED | `leak-17C-PC-2026-08-14-V1*.json` |
| 17C veredicto | V1 y B son **ORTOGONALES**: V1 ataca el ENSAMBLADO (fuente A del leak, 55%), B ataca el RANKING (expansión H1 → rescata Q05). Combinación natural pendiente = 17D | EVAL-REGISTRY §17C |

**Estado del contrato:** el gate completo §17.4 del contrato (leak ≤ 0.308 Y
attr ≥ 13/20 + resto) **nunca se ha cruzado**: 17B falló en leak (0.442), 17C-V1
falló en attr (12/20). Cada uno es candidato positivo/no adoptado.

**Objetivo de 17D:** determinar si la combinación de los DOS candidatos cruza
el gate completo por primera vez. Si no lo cruza, se registra el resultado y la
interacción observada; cada candidato sigue siendo no adoptado individualmente.
**No se modifica ningún umbral** (regla metodológica conservada).

---

## 1. Caracterización de la combinación (17D.1) — mecanismos y punto de contacto

### 1.1 Los dos factores (congelados de 17B/17C, NO se rediseñan)

| Factor | Frente | Mecanismo | Evidencia |
|---|---|---|---|
| **DICT_H1_B** | Ranking (expansión de query, H1 real) | Puente léxico `telefono→phone/device/adb` + tramo técnico: hace que `ADB.md:1-9` (`adb devices -l`) cruce el piso 0.545 para Q05 → **rescata Q05** | 17B: 12→13/20 |
| **V1** | Ensamblado del contexto final (post-ranking) | Excluye del ctx los pasajes `is_session_noise` que no son gold → elimina la fuente A (17 paths, 55% del leak) | 17C: 0.442→0.250 |

### 1.2 Punto de contacto (único riesgo de interacción conocido)

V1 excluye pasajes **después** del ranking, sobre el `gated` list. B modifica el
ranking **antes**. El contacto es: los pasajes que B introduce o re-rankea
podrían (a) ser noise → V1 los excluiría (sin daño, pero reduce slots), o
(b) ser el pasaje que rescata Q05 (`ADB.md:1-9`, dominio Knowledge/Android →
**NO** es `is_session_noise` → V1 NO lo excluye, en teoría). El punto de
contacto se VERIFICA por gold en el análisis, no se asume.

### 1.3 Qué NO se toca (invariantes de la serie)

- Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, LIMIT=10, piso 0.545 — IDÉNTICOS.
- Métricas (leak, attr, pRel, containment, determinism_hash) — congeladas.
- `is_session_noise()`, `dom_of()`, gates, cap-selector, router, DICT_H1
  (ambos dicts congelados) — IDÉNTICOS.
- **Runtime de producción: NO se modifica.** Nada de lo probado aquí toca el
  pipeline real; es evaluación sobre corpus congelado con dicts embebidos.
- **Anti-oráculo:** gold_files se usa SOLO para medir, nunca para rankear ni
  excluir. No se agregan reglas ad-hoc por query.

---

## 2. Hipótesis (17D.2) — declarada ANTES de fijar el gate

> **H17D:** V1 (exclusión de noise en el ensamblado) y DICT_H1_B (ampliación
> léxica en el ranking) atacan frentes ORTOGONALES — el primero elimina pasajes
> NO gold de dominios no-gold del ctx final, el segundo cambia qué pasajes
> cruzan el piso. Por construcción el leak queda determinado por V1 (0.250,
> verificado en 17C) y attr por B (13/20, verificado en 17B). **La combinación
> podría cruzar el gate completo del contrato.** La interacción posible es
> acotada a cómo B modifica el ranking sobre el que V1 filtra (reordenamientos
> del top-10) y se diagnostica por gold en el análisis.

**Falsable:** si la combinación NO cruza el gate completo (§4), o cruza con
interacción negativa (p.ej. attr cae a 12/20 → V1 o B neutralizan al otro, o
Q05 se pierde), la hipótesis aditiva se refuta y se registra la interacción
observada. **No se relaja el gate para acomodar el resultado.**

---

## 3. Diseño del experimento (17D.3) — 1 tratamiento + 3 controles de saneamiento

> La combinación es 2 factores, así que el experimento exige controles que
> reproduzcan los estados componentes (sanity) antes de medir el tratamiento.
> Las 4 configuraciones se obtienen del mecanismo 17C congelado, sin tocarlo:

| # | Config | `--variant` | `--dict` |
|---|---|---|---|
| **A** | Control serie | `A` | (default pipeline, `8294f200`) |
| **B-solo** | Control factor B | `A` | `dict_h1_b.json` (`f534283f`) |
| **V1-solo** | Control factor V1 | `V1` | (default pipeline) |
| **T** | **Tratamiento 17D** | `V1` | `dict_h1_b.json` |

### 3.1 Esperados históricos de sanity — IGUALDAD EXACTA per-query (regla del usuario)

> **Regla aprobada (2026-08-15):** los tres controles deben reproducir TODAS las
> métricas contractuales relevantes conocidas — no solo `attr + leak`. Se exige
> **igualdad exacta per-query**, sin tolerancia estadística: el runner es
> determinista y el corpus/dict están congelados.
>
> **Si A, B-solo o V1-solo no reproducen exactamente sus resultados históricos
> bajo el mismo corpus, EVAL, dict, runner y configuración → STOP antes de
> evaluar T.** El tratamiento combinado no puede beneficiarse de un drift
> silencioso.

| Métrica (per-query Q01–Q10) | **A** (= 17C-A) | **B-solo** (= 17B-B r1) | **V1-solo** (= 17C-V1) |
|---|---|---|---|
| `attributed` | 0,3,0,2,**0**,1,2,1,2,1 | 0,3,0,2,**1**,1,2,1,2,1 | 0,3,0,2,**0**,1,2,1,2,1 |
| attr total | **12/20** | **13/20** | **12/20** |
| `cross_domain_leakage` | 0,0,1,.5,.75,.33,.33,.67,.33,.5 | 0,0,1,.5,.75,.33,.33,.67,.33,.5 | 0,0,1,**0**,**.5**,**0**,.33,**0**,.33,.33 |
| leak avg | **0.442** | **0.442** | **0.250** |
| `passage_relevance` | 0,.9,0,.5,.33,.5,.6,.3,.71,.3 | 1,.9,0,.5,.5,.5,.6,.3,.71,.3 | 0,.9,0,**1**,.67,.63,.6,**1**,.71,.33 |
| pRel avg | **0.415** | **0.531** | **0.584** |
| `gold_containment` avg | **1.0** | **1.0** | **1.0** |
| `ctx_size` | 0,10,2,4,6,10,10,10,7,10 | 1,10,3,4,10,10,10,10,7,10 | 0,10,1,2,3,8,10,3,7,9 |
| per-query `ctx_passages` (paths) | idénticos a 17C-A | idénticos a 17B-B r1 | idénticos a 17C-V1 |

> **Fuente:** leídos de los JSONs históricos (`leak-17C-PC-2026-08-14-control-A.json`,
> `bridge-17B-PC-2026-08-14-treatment-B-r1.json`, `leak-17C-PC-2026-08-14-V1.json`),
> pad 4. Nota: B-solo de 17B usó corpus `bb33afa` (7644 líneas) mientras 17C usó
> `236a87fa` (7653) — el sanity compara contra el corpus congelado de 17D (§3.2);
> si el corpus difiere, los esperados de esta tabla son los que deben reproducirse
> exactamente dentro del nuevo `corpus_hash`, y si no reproducen → STOP.

**Sobre `determinism_hash` histórico:** el hash cubre TODO el JSON salvo
`determinism_hash`/`elapsed_seconds` — incluye `commit_sha` y `corpus_hash`, que
**cambiarán legítimamente** en 17D (commit de esta spec). Por eso la comparación
de sanity se hace sobre las métricas per-query de la tabla (y `ctx_passages`),
NO sobre el `determinism_hash` histórico. El `determinism_hash` se usa para el
G2 interno de 17D (r1 = r2 por configuración), no como comparación con 17B/17C.

### 3.2 Corpus/EVAL y determinismo

**Corpus/EVAL:** el mismo EVAL de la serie (`eval_hash 98a0e308…`), corpus
congelado al commit de esta spec (drift-detector activo). Si el corpus difiere
de `236a87fa` de 17C, los controles deben reproducir exactamente los esperados
de §3.1 dentro del nuevo `corpus_hash` — igualdad exacta igualmente; si no
reproducen → **STOP** (regla §3.1). El runner 17C ya calcula `corpus_hash`,
`commit_sha`, `h1_dict_hash` y `eval_hash` en cada JSON (drift-detection).

**Determinismo G2:** 2 corridas por configuración (8 corridas totales), JSONs
idénticos salvo duración/cache; `determinism_hash` por configuración (G2
interno de 17D).

---

## 4. Gate (17D.4) — pre-fijado por CONTRATO (igual a §17.4), no por resultado esperado

| # | Criterio | Umbral | Fuente del umbral |
|---|---|---|---|
| 1 | **leak (PRIMARIO)** | **≤ 0.308** | Contrato §17.4 (idéntico a 17C) |
| 2 | **attr total** | **≥ 13/20** | Contrato §17.4 — el nivel que B ya alcanzó solo; no se exige MÁS de la combinación, se exige no perder lo ganado |
| 3 | Q05 (gold rescatado por B) | **≥ 1** | No retroceder el único rescate de 17B |
| 4 | sin regresión Q02/Q06/Q08/Q09 | attr por gold (T) ≥ attr por gold (A) | Contrato |
| 5 | sin regresión Q03/Q04/Q07/Q10 | attr por gold (T) ≥ attr por gold (A) | Contrato |
| 6 | passage_relevance | **≥ 0.121** | Contrato |
| 7 | gold_containment | **≥ 0.80** | Contrato |
| 8 | determinismo G2 | 2 corridas por config, JSONs idénticos | Serie |

**Criterio de ADOPCIÓN:** ADOPTAR solo si **T cruza los 8 criterios** Y los 3
controles reprodujeron EXACTAMENTE sus esperados históricos de §3.1 (todas las
métricas contractuales, igualdad per-query, sin tolerancia). Si un control no
reproduce → el experimento queda inválido por drift y se re-evalúa antes de
leer T (regla §3.1: STOP antes de evaluar T).

**Criterio de DESCARTE:** si T falla CUALQUIER criterio → la combinación se
registra como no-adoptada, con diagnóstico de la interacción por gold (¿qué
factor neutralizó al otro, o qué criterio no cruzó). No se relaja el gate.
Cada factor sigue siendo candidato individual no-adoptado (17B/17C cerrados).

---

## 5. Análisis (17D.5) — tabla de interacción, no confirmación de expectativa

Entregar por gold (Q01–Q10):

1. **Tabla de interacción:** attr T vs A vs B-solo vs V1-solo, + leak, pRel,
   containment por configuración (4×2 corridas).
2. **Diagnóstico por gold:** para cada gold donde T ≠ B-solo o T ≠ V1-solo,
   identificar qué mecanismo causó la diferencia (¿B introdujo un pasaje que V1
   excluyó? ¿V1 reordenó slots y desplazó un gold? ¿Q05 sobrevivió la exclusión?).
   Se reporta la interacción OBSERVADA, no la esperada.
3. **leak por fuente** (A/B/C/D de 17C) en T: confirmar que la fuente A quedó
   excluida y que ninguna fuente creció por el re-ranking de B.
4. **Veredicto registrado** en EVAL-REGISTRY: ADOPTADO / no-adoptado con causa /
   inválido por drift.

---

## 6. Entregables

1. **Esta spec congelada** (`combine-17D-DESIGN.md`), commit separado antes de
   todo código.
2. `run-combine-17D.sh` — **orquestador** que invoca el mecanismo 17C congelado
   (`run-leak-17C.sh`) para las 4 configs ×2 (G2), con tabla resumen y
   verificación de sanity antes de leer T (si A/B-solo/V1-solo no reproducen →
   abortar con drift reportado).
3. `analiza-17D.py` — tabla de interacción por gold + diagnóstico (§5) + veredicto.
4. Test sin Ollama: sintaxis, parámetros congelados (PAD=4, LIMIT=10, piso
   0.545), anti-oráculo (§1.3), 4 configs, G2, sanity-check.
5. JSONs de resultados (8) + veredicto en EVAL-REGISTRY + commit separado.

> **Nota de alcance:** no se crea un runner nuevo del mecanismo — el runner 17C
> ya soporta `--variant` + `--dict` (esa es la prueba de que la combinación es
> ortogonal por construcción). 17D aporta orquestación + análisis, cero cambios
> al mecanismo evaluado ni al runtime.

---

## 7. Orden de ejecución (tras aprobación del usuario)

1. Congelar esta spec (commit de este archivo).
2. Implementar `run-combine-17D.sh` + `analiza-17D.py` + test sin Ollama.
3. Correr controles A, B-solo, V1-solo → deben reproducir EXACTAMENTE los
   esperados de §3.1 (todas las métricas, per-query, sin tolerancia). Si
   cualquiera no reproduce → **STOP, no se evalúa T** (regla §3.1).
4. Correr T ×2 (G2) → tabla vs gate §4.
5. Veredicto: ADOPTAR (8/8 + sanity) / no-adoptado con causa / inválido por
   drift — registrado en EVAL-REGISTRY y committeado.

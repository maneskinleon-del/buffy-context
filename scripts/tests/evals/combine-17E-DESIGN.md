# Paso 17E — Especificación congelada: V1 + DICT_H1_B sobre fixture `fx-2026-08-15-001`

> Fecha de diseño: 2026-08-15 · Antecede a TODO el código del experimento.
> **17E es un experimento NUEVO, NO un rescate de 17D.** 17D quedó cerrado como
> STOP metodológico / NO EVALUADO (drift del corpus vivo entre 17C y 17D). La
> diferencia estructural: 17E corre sobre el **fixture congelado e inmutable**
> `fx-2026-08-15-001` (Fase D, infraestructura aprobada) — el corpus ya NO puede
> driftar con el estado operativo del proyecto.
> Esta spec NO implementa nada: define objetivo, factores, corpus/EVAL (fixture),
> controles, gate completo pre-fijado, determinismo G2, criterios de
> adopción/descarte y riesgos de interacción. Se ejecuta SOLO tras la aprobación
> del usuario.
>
> **Regla de ceguera (exigida por el usuario, heredada de 17D):** el experimento
> NO nace como "probemos V1+B porque probablemente dé attr alto y leak bajo". El
> gate se pre-fija por CONTRATO (§4), no por el resultado esperado, y el análisis
> (§5) reporta deltas por gold y diagnóstico de interacción OBSERVADA — no una
> confirmación de la expectativa aditiva.

---

## 0. Cadena de evidencia (no se re-litiga)

| Paso | Resultado | Fuente |
|---|---|---|
| 17B | **B (DICT_H1_B, `f534283f`):** attr 12→**13/20** (Q05 rescatado), pRel 0.415→**0.531**, leak 0.442 (invariante), contain 1.0, cero regresiones. PASS experimental / NO ADOPTED | `bridge-17B-PC-2026-08-14-*.json` |
| 17C | **V1 (exclusión dura de noise):** leak 0.442→**0.250** (-43%), pRel 0.415→**0.584**, attr 12/20 (Q05 sigue 0 sin B), contain 1.0, cero regresiones. PASS del objetivo primario / NO ADOPTED | `leak-17C-PC-2026-08-14-V1*.json` |
| 17C veredicto | V1 y B son **ORTOGONALES**: V1 ataca el ENSAMBLADO (fuente A del leak), B ataca el RANKING (expansión H1 → rescata Q05). Combinación natural pendiente | EVAL-REGISTRY §17C |
| 17D | **STOP metodológico / NO EVALUADO** — los controles no reprodujeron sus esperados por drift del corpus vivo (`236a87fa`→`029ed669`). T = V1+B NUNCA se evaluó. El STOP sigue siendo válido | EVAL-REGISTRY §17D |
| Fase D | **Infraestructura aprobada:** fixture `fx-2026-08-15-001` congelado (corpus_hash `0af49cc666d872a6`, 45 archivos, hash POR CONTENIDO), runner `--fixture` con barrera de mutación (mismatch → STOP), gate §6.1–§6.7 pasado, reproducibilidad multi-máquina verificada | EVAL-REGISTRY Fase D |

**Estado del contrato de la serie:** el gate completo (leak ≤ 0.308 Y attr ≥ 13/20
+ resto) **nunca se ha cruzado**: 17B falló en leak (0.442), 17C-V1 falló en attr
(12/20). 17D no llegó a T.

**Objetivo de 17E:** determinar si la combinación V1 + DICT_H1_B, medida sobre el
**corpus congelado del fixture** (que elimina la contaminación del estado
operativo), cruza un gate completo pre-fijado. Es la MISMA hipótesis que 17D iba a
probar, ahora con el problema metodológico de fondo resuelto.

**⚠️ Diferencia de corpus (crítica):** los valores absolutos históricos
(attr 12/13, leak 0.442/0.250, pRel 0.415/0.531/0.584) se midieron sobre el
**corpus vivo CON estado de instancia** (SESION/CONTINUE/CHANGELOG/etc.). El
fixture los **excluye por diseño** (contrato INSTANCE-STATE-DESIGN.md §3). Por
tanto: **esos números NO son los esperados de 17E.** El sanity de 17E establece
un **baseline NUEVO del fixture** (controlando con los mismos componentes), y el
gate se fija en términos de dominancia relativa al baseline — NO en términos de
los umbrales absolutos del corpus viejo.

---

## 1. Caracterización de la combinación (17E.1) — mecanismos y punto de contacto

### 1.1 Los dos factores (congelados de 17B/17C, NO se rediseñan)

| Factor | Frente | Mecanismo | Evidencia (corpus vivo) |
|---|---|---|---|
| **DICT_H1_B** | Ranking (expansión de query, H1 real) | Puente léxico + tramo técnico: hace que el pasaje gold cruce el piso 0.545 → **rescata Q05** | 17B: 12→13/20 |
| **V1** | Ensamblado del contexto final (post-ranking) | Excluye del ctx los pasajes `is_session_noise` que no son gold → elimina la fuente A del leak | 17C: 0.442→0.250 |

### 1.2 Punto de contacto (único riesgo de interacción conocido)

V1 excluye pasajes **después** del ranking, sobre el `gated` list. B modifica el
ranking **antes**. El contacto: los pasajes que B introduce o re-rankea podrían
(a) ser noise → V1 los excluiría (sin daño, pero reduce slots), o (b) ser el
pasaje que rescata Q05 (dominio Knowledge → NO `is_session_noise` → V1 NO lo
excluye, en teoría). El punto de contacto se VERIFICA por gold en el análisis,
no se asume. **Nota 17E:** el fixture excluye los archivos de instancia — los
golds (`gold_files`) apuntan a `Knowledge/`/`README`/`CHANGELOG` (incluidos en
el fixture), así que la cobertura de gold se conserva. Se verifica en el sanity.

### 1.3 Qué NO se toca (invariantes de la serie)

- **Corpus = fixture congelado** `fx-2026-08-15-001` (corpus_hash
  `0af49cc666d872a6`) — NO se regenera, NO se modifica, NO se re-indexa salvo
  cache miss inicial (permitido, ver §3.2).
- **EVAL:** `eval-ctx-PC-2026-08-11` (eval_hash `98a0e308…`) — idéntico a la serie.
- Pool L∪X∪S∪P-F2, M3 V6, PAS_PAD=4 fijo, LIMIT=10, piso 0.545 — IDÉNTICOS.
- Métricas (leak, attr, pRel, containment, determinism_hash) — congeladas.
- `is_session_noise()`, `dom_of()`, gates, cap-selector, router, DICT_H1
  (ambos dicts congelados) — IDÉNTICOS.
- **Runtime de producción: NO se modifica.** Nada de lo probado aquí toca el
  pipeline real; es evaluación sobre fixture congelado con dicts embebidos.
- **Anti-oráculo:** gold_files se usa SOLO para medir, nunca para rankear ni
  excluir. No se agregan reglas ad-hoc por query.

---

## 2. Hipótesis (17E.2) — declarada ANTES de fijar el gate

> **H17E:** V1 (exclusión de noise en el ensamblado) y DICT_H1_B (ampliación
> léxica en el ranking) atacan frentes ORTOGONALES, y esa ortogonalidad se
> conserva sobre el corpus congelado del fixture. **La combinación T = V1+B
> debería heredar el beneficio de cada factor sin perder el del otro:** leak de T
> ≤ leak de V1-solo (el ensamblado sigue excluyendo noise) Y attr de T ≥ attr de
> B-solo (el ranking sigue rescatando Q05). La interacción posible es acotada a
> cómo B modifica el ranking sobre el que V1 filtra, y se diagnostica por gold.

**Falsable:** si T NO domina a los controles en sus métricas fuertes (leak(T) >
leak(V1-solo) o attr(T) < attr(B-solo), o Q05 se pierde), la hipótesis aditiva se
refuta y se registra la interacción OBSERVADA. **No se relaja el gate para
acomodar el resultado.**

**Nota de ceguera:** el gate §4 no dice "leak ≤ 0.250" ni "attr ≥ 13/20" (valores
del corpus viejo). Dice "T no peor que el mejor control del fixture en su métrica
fuerte" — se fija ANTES de correr, por contrato, y los valores del fixture se
observan después.

---

## 3. Diseño del experimento (17E.3) — 1 tratamiento + 3 controles, sobre el fixture

> Misma estructura que 17D, pero el corpus es el fixture congelado. Las 4
> configuraciones se obtienen del runner 17C con `--fixture` (Fase D3), sin tocar
> el mecanismo:

| # | Config | `--fixture` | `--variant` | `--dict` |
|---|---|---|---|---|
| **A** | Control baseline del fixture | `fx-2026-08-15-001` | `A` | (default pipeline) |
| **B-solo** | Control factor B | `fx-2026-08-15-001` | `A` | `dict_h1_b.json` (`61ab7161…`) |
| **V1-solo** | Control factor V1 | `fx-2026-08-15-001` | `V1` | (default pipeline) |
| **T** | **Tratamiento 17E** | `fx-2026-08-15-001` | `V1` | `dict_h1_b.json` |

### 3.1 Sanity del fixture — baseline NUEVO + direcciones de efecto (NO esperados históricos)

> **Regla aprobada en la serie (2026-08-15):** igualdad exacta sin tolerancia —
> pero AHORA contra el baseline del MISMO fixture, no contra valores históricos
> de otro corpus. El fixture es inmutable (Fase D verificó: mismo corpus_hash en
> cualquier checkout, sin `--reindex`, cache miss inicial OK) → la reproducibilidad
> ya está garantizada por la infraestructura; el sanity de 17E la re-confirma
> operativamente.

**Sanity obligatorio ANTES de leer T — orden de ejecución estricto:**

```text
Construir/validar fixture
        ↓
A sanity            (×2 G2)
        ↓
B-solo sanity       (×2 G2)
        ↓
V1-solo sanity      (×2 G2)
        ↓
comparar controles entre sí
        ↓
solo si todo es válido
        ↓
T = V1 + B          (×2 G2)
        ↓
gate 17E
```

> **Regla (ajuste aprobado por el usuario, 2026-08-15):** los valores de los
> controles se calculan **en la MISMA ejecución experimental sobre el fixture** —
> nunca se toman de documentación histórica (17B/17C/17D midieron otro corpus).
> Esto evita repetir exactamente el problema de 17D: el sanity compara contra lo
> que el fixture produce AHORA, no contra números de un corpus que ya no existe
> como estado del repo.

**Checks de sanity, en orden:**

1. **G2 interno:** cada config corre ×2 (8 corridas). r1 = r2 per-query
   (attr, leak, pRel, contain, ctx_size, ctx_passages) → `determinism_hash`
   idéntico por config.
2. **Fixture íntegro:** el runner valida `corpus_hash` vs manifest en cada
   corrida → `✓ fixture íntegro: 0af49cc666d872a6`. Si mismatch → STOP (no se
   evalúa nada).
3. **Cobertura de gold intacta:** los 10 golds del EVAL deben seguir mapeando a
   archivos PRESENTES en el fixture (`gold_files` ⊆ archivos del fixture) —
   verificado por script, no asumido.
4. **Direcciones de efecto de los controles** (baseline del fixture, calculado
   en esta misma ejecución):
   - `attr(B-solo) ≥ attr(A)` — B debe seguir rescatando al menos 1 gold (Q05)
     sobre el fixture. Si no → el efecto de B no se reproduce en este corpus y se
     reporta ANTES de T (STOP con diagnóstico).
   - `leak(V1-solo) ≤ leak(A)` — V1 debe seguir reduciendo leak sobre el fixture.
     Si no → el efecto de V1 no se reproduce y se reporta ANTES de T.
   - `attr(B-solo) ≥ attr(V1-solo)` en Q05 (B es el que rescata; V1-solo lo deja
     en 0, como en 17C).

> Si un control no cumple su dirección de efecto → **STOP antes de T** (el
> fixture no reproduce el comportamiento esperado de los factores; el resultado
> sería ininterpretable). Se registra el baseline obtenido y el diagnóstico.

**Sobre `determinism_hash` histórico:** no es comparable con 17B/17C/17D
(incluye `commit_sha`/`corpus_hash`, que difieren por diseño). Se usa SOLO para
el G2 interno de 17E (r1 = r2).

### 3.2 Corpus/EVAL y coste

- **Corpus:** fixture `fx-2026-08-15-001` (corpus_hash `0af49cc666d872a6`,
  45 archivos / 5338 líneas / 366358 bytes; manifest: exclusions de instancia +
  `include_by_default_off` de memoria — verificados). EVAL `98a0e308…`.
- **Coste operativo:** el índice de embeddings del fixture puede no estar en
  caché (hash por contenido nuevo) → la PRIMERA corrida por config puede hacer
  reindex (~tens de minutos en CPU). Permitido y esperado: el cache queda keyed
  por `corpus_hash` por contenido → estable entre corridas y máquinas después.
  No es drift: es cache miss inicial (Fase D §6.3 lo contempla).
- **Drift-detector:** el runner registra `fixture_id`, `fixture_corpus_hash`,
  `config_hash`, `runner_version`, `commit_sha` (corpus) y `pipeline_commit`
  (runtime) en cada JSON — la identidad queda auditable por corrida.

---

## 4. Gate (17E.4) — pre-fijado por CONTRATO (dominancia combinada), no por resultado esperado

> Los umbrales absolutos del corpus viejo (leak ≤ 0.308, attr ≥ 13/20) NO se
> reutilizan como gate: fueron calibrados sobre un corpus con estado de instancia
> que el fixture excluye. El gate de 17E es **relativo al baseline del fixture**:
> T debe heredar lo mejor de ambos factores sin perder nada. Es la definición
> operacional de la hipótesis aditiva, pre-fijada ANTES de correr.

| # | Criterio | Umbral | Fuente |
|---|---|---|---|
| 1 | **leak (PRIMARIO)** | `leak(T) ≤ min(leak(A), leak(B-solo), leak(V1-solo))` — T no peor que el MEJOR control en leak | Hipótesis aditiva (V1 baja leak) |
| 2 | **attr total (PRIMARIO)** | `attr(T) ≥ max(attr(A), attr(B-solo), attr(V1-solo))` — T no peor que el MEJOR control en attr | Hipótesis aditiva (B sube attr) |
| 3 | **Q05 (rescate de B)** | `attr_Q05(T) ≥ attr_Q05(B-solo) ≥ 1` — el rescate sobrevive la combinación | No retroceder el único rescate de 17B |
| 4 | **sin regresión por gold** | para cada Q: `attr_Q(T) ≥ attr_Q(A)` | Contrato de la serie — **independiente del criterio 5**: evita que una mejora agregada oculte un daño localizado |
| 5 | **passage_relevance (no regresión global)** | `pRel(T) ≥ min(pRel(A), pRel(B-solo), pRel(V1-solo))` — no peor que el peor control | **No degradar la relevancia global** — complementa, NO sustituye, al criterio 4 (sin regresión por gold): la mejora agregada no puede ocultar un daño localizado |
| 6 | **gold_containment** | `contain(T) ≥ 0.80` (y ≥ min de controles) | Contrato |
| 7 | **determinismo G2** | 2 corridas por config, JSONs idénticos (r1=r2) | Serie |

**Criterio de ADOPCIÓN:** ADOPTAR solo si **T cruza los 7 criterios** Y los 3
controles pasaron el sanity §3.1 (G2 + fixture íntegro + direcciones de efecto +
cobertura de gold). Si un control no pasa su sanity → el experimento queda
inválido y se detiene antes de leer T (regla §3.1).

**Criterio de DESCARTE:** si T falla CUALQUIER criterio → la combinación se
registra como no-adoptada, con diagnóstico de interacción por gold (¿qué factor
neutralizó al otro, o qué criterio no cruzó). No se relaja el gate. Cada factor
sigue siendo candidato individual no-adoptado (17B/17C cerrados).

**Nota de verosimilitud:** este gate es MÁS exigente que el de 17D para T en un
sentido (dominancia sobre el mejor control en cada métrica) y distinto en otro
(no fija umbrales absolutos del corpus viejo). Es el gate correcto para medir la
hipótesis aditiva sobre un corpus congelado.

---

## 5. Análisis (17E.5) — tabla de interacción, no confirmación de expectativa

Entregar por gold (Q01–Q10):

1. **Tabla de interacción:** attr T vs A vs B-solo vs V1-solo, + leak, pRel,
   containment por configuración (4×2 corridas), todas sobre `fx-2026-08-15-001`.
2. **Baseline del fixture reportado:** valores absolutos de A/B-solo/V1-solo en
   el fixture — quedan como referencia para futuros experimentos sobre este
   corpus (NO comparables con los históricos del corpus vivo).
3. **Diagnóstico por gold:** para cada gold donde T ≠ B-solo o T ≠ V1-solo,
   identificar qué mecanismo causó la diferencia (¿B introdujo un pasaje que V1
   excluyó? ¿V1 reordenó slots y desplazó un gold? ¿Q05 sobrevivió la exclusión?).
   Se reporta la interacción OBSERVADA, no la esperada.
4. **leak por fuente** (A/B/C/D de 17C) en T: confirmar que la fuente A quedó
   excluida y que ninguna fuente creció por el re-ranking de B.
5. **Veredicto registrado** en EVAL-REGISTRY: ADOPTADO / no-adoptado con causa /
   inválido por sanity (§3.1).

---

## 6. Entregables

1. **Esta spec congelada** (`combine-17E-DESIGN.md`), commit separado antes de
   todo código.
2. `run-combine-17E.sh` — **orquestador** que invoca el runner 17C con
   `--fixture fx-2026-08-15-001` para las 4 configs ×2 (G2), con tabla resumen y
   verificación de sanity §3.1 ANTES de leer T (si un control falla su dirección
   de efecto o el fixture muta → abortar con diagnóstico).
3. `analiza-17E.py` — tabla de interacción por gold + baseline del fixture +
   diagnóstico (§5) + veredicto.
4. Test sin Ollama: sintaxis, parámetros congelados (PAD=4, LIMIT=10, piso
   0.545), anti-oráculo (§1.3), 4 configs con `--fixture`, G2, sanity-check,
   cobertura de golds ⊆ fixture.
5. JSONs de resultados (8, con `fixture_id`/`fixture_corpus_hash`/`config_hash`)
   + veredicto en EVAL-REGISTRY + commit separado.

> **Nota de alcance:** no se crea un runner nuevo del mecanismo — el runner 17C
> ya soporta `--fixture` (Fase D3) + `--variant` + `--dict`. 17E aporta
> orquestación + análisis, cero cambios al mecanismo evaluado ni al runtime.
> El fixture NO se regenera ni se modifica.

---

## 7. Orden de ejecución (tras aprobación del usuario)

1. Congelar esta spec (commit de este archivo).
2. Implementar `run-combine-17E.sh` + `analiza-17E.py` + test sin Ollama.
3. Correr controles A, B-solo, V1-solo (×2 G2) sobre el fixture → sanity §3.1:
   G2 interno, fixture íntegro, direcciones de efecto, cobertura de gold. Si
   cualquiera falla → **STOP, no se evalúa T**.
4. Correr T ×2 (G2) → tabla vs gate §4 (dominancia combinada).
5. Veredicto: ADOPTAR (7/7 + sanity) / no-adoptado con causa / inválido por
   sanity — registrado en EVAL-REGISTRY y committeado.

**Regla de la serie:** sin diseño/gate aprobado NO se ejecuta nada. Esta spec se
congela en commit antes de cualquier corrida.

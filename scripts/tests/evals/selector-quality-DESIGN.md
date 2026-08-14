# Paso 15 — Selector quality-aware multi-señal (diseño)

> Estado: **✅ EJECUTADO (2026-08-13)** — 15A corrido completo (×2, G2 determinista),
> veredicto: **M3 (S1+S2+S3+S4) con ventana de rescate 0.545 ADOPTADO** por decisión
> del usuario. Resultados y veredicto en EVAL-REGISTRY.md (§15A). La Rama A quedó
> descartada por el veredicto de 14A (phi3.5 no pasa el gate → Rama B).
>
> ⚠️ **Nomenclatura:** el nombre "Paso 11" ya está tomado por
> `quality-passage-DESIGN.md` (Q1/Q2 — CERRADO sin adopción). Este es el siguiente
> paso de la serie → **Paso 15**. No reabrir el Paso 11: sus señales (densidad X,
> dedup estructural) ya se midieron y no alcanzaron el gate.
>
> Base: EVAL `98a0e308…` · F2 (Paso 13) = found 20 → available 18 → selected 20 →
> attributed 16 · 14A smoke (bge-m3) = gold 5/11 pares · Q06/Q08 = los 2 casos
> available-not-attributed.

---

## 1. Motivación (medida, no asumida)

El funnel de F2 dejó **2 casos disponibles-no-atribuidos** (Q06/Q08): el pasaje gold
existe en el pool, pero el selector actual (bge-m3 cosine ≥ 0.55) elige el
distractor. El smoke test de 14A lo cuantificó:

| Caso | Gold (cos) | Distractor (cos) | bge elige |
|---|---|---|---|
| Q06 `FF_SEEN` | CHANGELOG.md **0.6706** | SESION-archive.md **0.6777** | ❌ distractor |
| Q08 `P_TERM_OPACITY` | System.md **0.5478** | AGENTS.md **0.6631** | ❌ distractor |
| Q08 `picom` | System.md **0.5491** | AGENTS.md **0.6631** | ❌ distractor |

**El problema no es encontrar el pasaje; es escoger el correcto entre dos pasajes
que contienen la misma evidencia.** La similitud coseno sola NO discrimina (en Q08
el distractor es MÁS similar a la query que el gold). Este paso diseña un selector
que combine señales adicionales a la relevancia semántica.

## 2. Qué ya se probó y falló (regla de no-repetir)

| Señal | Paso | Resultado | Lección |
|---|---|---|---|
| `q_hits` / `cmds` (overlap crudo de query) | 11 | **INVERTIDAS** (el ruido matchea más) | NO usar overlap crudo de query |
| densidad de evidencia X (θ=0.050) | 11 (Q2) | pRel 0.066, desplazó Q04 a no-gold | NO usar densidad como gate duro |
| S3 heading de sección | 12 (E1) | prec 1.0 pero rec 0.35 (6/17) | demasiado estrecho solo |
| S4 bge-m3 cosine (θ=0.55) | 12 (E2) | mejor señal (leak 0.441→0.325, regresión 0.0) pero pRel 0.093 | **no discrimina gold vs distractor** (14A smoke) |
| S3+S4 combinado | 12 (E3) | ≈ E2 (heading no aporta) | no insistir en heading |

Conclusión acumulada de la serie: la señal de calidad **no vive** en densidad/
estructura (Paso 11) ni en cosine solo (Paso 12). El 14A smoke demuestra que el
distractor puede tener cosine MÁS ALTO que el gold → se necesitan señales que
midan **qué hace específico a un pasaje**, no cuánto se parece a la query.

## 3. Señales del selector (dimensiones del usuario, adaptadas a la serie)

### S1 — Relevancia semántica (baseline congelado)
`bge-m3 cosine(pasaje, query+X) ≥ 0.55` — el scorer E2 del Paso 12, con su cache
validado. **No discrimina gold vs distractor** (medido), pero es el piso de
relevancia: un pasaje que no pasa S1 no entra.

### S2 — Especificidad (hipótesis clave del usuario) ⭐
> *"En Q06 y Q08, ambos pasajes son semánticamente relevantes, pero uno es más
> específico al contexto de la query. Un selector que penalice pasajes que aplican
> a múltiples contextos resolvería el problema."*

**Operacionalización (sin gold):** para cada pasaje del pool, tomar sus tokens
salientes = {no-stopwords, len>3, command-like} **menos los tokens de la query**
(el punto del usuario: un token de la query no aporta especificidad) y medir
cuántos OTROS pasajes del pool comparten ≥1 token saliente:

```text
especificidad(p) = 1 − |{p' ∈ pool, p' ≠ p : tokens_salientes(p) ∩ tokens_salientes(p') ≠ ∅}| / |pool|
```

- Pasaje **específico** (gold): sus tokens aparecen en pocos pasajes → score alto.
- Pasaje **genérico** (distractor): sus tokens aparecen en muchos pasajes (aplica
  a múltiples contextos) → score bajo.

**Por qué la exclusión de query NO basta sola (medido en Q08):** ambos pasajes
tienen tokens fuera de la query — el gold `fonts.toml / alacritty.toml /
theme-config.bash / rices / P_TERM_OPACITY` (tokens RAROS, específicos de config)
y el distractor `verificar / grep / opaca / compositor` (tokens GENÉRICOS de
troubleshooting). "Fuera de la query" es condición necesaria pero no suficiente:
lo que discrimina es la **rareza cruzada del pool** (IDF-like). El gold tiene
tokens que pocos pasajes comparten; el distractor tiene vocabulario que aparece
en muchos.

### S3 — Definición vs mención (exact match contextual)
La aguja está en AMBOS pasajes (definición de distractor), así que el exact match
crudo no discrimina. Lo que discrimina es el **contexto de la aguja** — tu
interpretación es correcta, confirmada con los pasajes reales de Q08:

- **Definición/asignación** (gold System.md:74): estructura clave-valor,
  `KEY=value`, backticks de path, `→ KEY`:
  ```text
  | Opacidad | `~/.config/alacritty/alacritty.toml` |
  | Rice setea | `rices/<nombre>/theme-config.bash` → `P_TERM_OPACITY` |
  ```
- **Mención en prosa** (distractor AGENTS.md:32): verbos descriptivos de
  troubleshooting ("necesita", "no tiene efecto", "verificar"):
  ```text
  - Alacritty necesita **picom** (compositor) corriendo para mostrar transparencia.
    Sin picom, `opacity` no tiene efecto.
  ```

Señal binaria: `1` si la línea de la aguja es assignment-like (regex
`\w+=|→\s|\|.*\|.*` (tabla) `|se fija|config`), `0` si es prosa. Los archivos de
config/código pesan más que la prosa — consistente con la jerarquía de fuentes,
pero es una señal del CONTENIDO del pasaje, no del rol del archivo (eso es S4).

### S4 — Canonicalidad por tipo de hecho (corrección honesta)

⚠️ **La interpretación "canónico = aparece en múltiples fuentes con consistencia"
NO discrimina Q06/Q08 — por construcción.** El distractor es "la misma aguja en el
archivo incorrecto": la aguja (FF_SEEN, picom/P_TERM_OPACITY) aparece en EL GOLD Y
EL DISTRACTOR por definición. Y el distractor SESION-archive.md suele tener MÁS
ocurrencias que el gold (el log de sesión repite el incidente; el changelog
registra la decisión una vez). "Número de fuentes" favorecería al distractor.

La canonicalidad operativa es **el rol del archivo según el tipo de hecho**:

- Hecho **de configuración** (Q08) → el home canónico es el doc que define el
  sistema (`Knowledge/Linux/System.md`: tabla Config→Archivo), NO una nota de
  AGENTS ni un log de sesión.
- Hecho **histórico/decisión** (Q06) → el home canónico es el changelog
  (`ai-context/CHANGELOG.md`: "FF_SEEN implementado"), NO el archive de sesión que
  registra la conversación.

Proxy medible sin gold: **penalizar pasajes de archivos de ruido de sesión**
(`SESION-archive.md`, `AGENTS.md`, `CONTINUE.md`, `SESION.md`) cuando el hecho es
de config o histórico. Estos archivos *mencionan* de paso; los archivos con rol de
definición *asignan*. Distinción operativa entre S3 y S4: S3 mira la línea de la
aguja (contenido), S4 mira el rol del archivo que la porta (fuente).

### S5 — Recencia (mtime del archivo)
Info más nueva > info vieja. Señal débil (Q06/Q08: gold y distractor son archivos
recientes), pero barata. Se mide, no se asume.

### S6 — Diversidad (MMR) — post-selección
Ya probado útil: el dedup estructural del Paso 11 (Q1) eliminó 28% de pasajes sin
perder agujas. MMR sobre el conjunto seleccionado evita que 3 pasajes digan lo
mismo. Se aplica DESPUÉS del scoring, como paso de poda.

### S7 — Concisión (tokens)
Paso 11 midió: pasajes con aguja = 35 tokens vs sin aguja = 65. Preferir pasajes
concisos como desempate (soft, no gate duro — la densidad dura ya falló en Q2).

## 4. Dos ramas según el resultado de 14A

### Rama A — Phi pasa 14A (calidad × coste × determinismo)
El juez Phi (si 14A lo valida) evalúa cada pasaje con un **prompt de rúbrica** que
codifica las señales S2/S3/S4 en lenguaje natural:

```text
"¿Este pasaje es la fuente canónica de la evidencia para la consulta?
Considera: (a) ¿define/asigna el dato o solo lo menciona? (b) ¿es específico
de este contexto o aplica a muchos? (c) ¿vive en el archivo que documenta este
tipo de hecho? Responde SI o NO."
```

Las señales no se computan: el modelo las razona. Mismo protocolo de 14A
(temp=0, seed=42, num_ctx=2048, determinismo ×2).

### Rama B — Phi falla 14A (se conserva bge-m3)
Selector determinista multi-señal con **pesos fijos declarados ANTES de medir** y
**ablación SECUENCIAL con regla de parada** (recomendación del usuario, lección
10B/12 — no meter 5 heurísticas juntas):

```text
score(p) = w1·S1 + w2·S2 + w3·S3 + w4·S4 + w5·S5 + w7·S7   (S6 = post-poda MMR)
```

**Regla de parada (simplicidad es virtud):** se corre M1 primero. Si M1 alcanza
el gate → **stop, no se añaden más señales** (la especificidad sola resuelve). Si
M1 no alcanza → se añade UNA señal a la vez (S3, luego S4, luego S6 MMR), parando
en la primera combinación que pasa. Cada paso añade exactamente una señal → la
atribución de qué señal contribuye es limpia:

- **M1** = S1 + S2 (relevancia + especificidad) — la hipótesis del usuario sola
- **M2** = M1 + S3 (definición-vs-mención) — si mejora, la estructura importa
- **M3** = M2 + S4 (canonicalidad de archivo) — si mejora, el rol de la fuente importa
- **M4** = M3 + S6 MMR (post-poda de diversidad) — si mejora, la redundancia importa

Pesos iniciales (a priori, se declaran y congelan): `w1=1.0, w2=1.0, w3=0.5,
w4=0.5, w5=0.25, w7=0.25` — S1/S2 dominan, el resto desempata. **Sin calibración
post-hoc** (regla de la serie).

## 5. Gate (anclado en la serie, no en R1)

⚠️ **Corrección a los números propuestos:** "pRel ≥ 0.40, leak ≤ 0.25, tokens ≤
5000" referencia R1 (0.175/0.441/1904). El gate de la serie para selección es
**pRel ≥ 0.600, leak ≤ 0.267, tokens ≤ 10.4k** — y NINGUNA estrategia lo alcanzó
(mejor pRel 0.230 E1, mejor leak 0.325 E2). F2 (el baseline actual) está en
pRel 0.121 / leak 0.308. Un gate de 0.40/0.25 sería más agresivo que el de la
serie y se declararía "éxito" imposible de medir contra el baseline real.

**Gate real de Paso 15 (no-regresión vs F2 + mejora de atribución):**

```text
# No-regresión (guard — no perder lo de F2)
attributed          ≥ 16/20
passage_relevance   ≥ 0.121      (F2)
cross_domain_leak   ≤ 0.308      (F2)
tokens              ≤ 10.4k      (presupuesto)
gold_containment    ≥ 0.80
baseline_regression ≤ 0.167

# Mejora (objetivos del veredicto — obligatorios para declarar éxito)
target_attribution  = 18/20      (18 available → 18 attributed)
Q06                 = gold atribuido (FF_SEEN → CHANGELOG.md en ctx)
Q08                 = gold atribuido (P_TERM_OPACITY → System.md en ctx)
gold_over_distractor ≥ 80%       (≥9/11 pares del fixture congelado)
```

**La métrica estrella es `gold_over_distractor`** (los 11 pares del fixture
congelado): mide directamente la discriminación que cosine no logra. Si el
selector no sube esa métrica, no hay mejora real aunque pRel/leak mejoren por
encogimiento del denominador (riesgo mecánico declarado en el Paso 11).

## 6. Riesgos / confounds (declarados antes de medir)

1. **S2 especificidad puede penalizar golds legítimos** si el pasaje gold es corto
   y genérico (p.ej. una línea de config compartida). La ablación M1 vs M2 lo
   detecta (si M1 pierde agujas, la especificidad es contraproducente).
2. **S4 canonicalidad es un proxy imperfecto** — puede haber golds en archives
   (Q06 lo es). Se mide como señal, no como gate duro.
3. **Sesgo de optimismo en pesos** (lección E2): los pesos se declaran a priori,
   el veredicto sale de la medición de pipeline completa, no del diagnóstico.
4. **Confound de composición** (lección Q1/Q2): re-selección desde pool mayor que
   top10 → `fraccion_podada` negativa NO es ahorro.
5. **Dependencia de 14A/14B:** si Phi pasa 14A, la Rama A reemplaza las señales
   computadas por el juez — no mezclar ambas ramas en la misma corrida.

## 7. Qué NO se hace (regla acumulada de la serie)

- NO tocar runtime (`buffy-search.sh`/`buffy-router.sh`).
- NO usar `gold_files` como señal del selector (la distinción gold/no-gold debe
  salir del contenido, no del fixture).
- NO recalibrar θ (0.55) ni K (10).
- NO usar `q_hits`/`cmds` (invertidas) ni densidad X como gate duro (Q2 falló).
- NO mezclar variables: 14A (modelo) ANTES de 14B (selector) ANTES de 15 (señales).
- NO medir sobre el working tree compartido si el corpus se desvió → worktree
  `18df679` + no tocar `ai-context/CONTINUE.md`/`SESION.md` mientras se mide.
- NO adoptar automáticamente si el gate pasa.

## 8. Orden de ejecución (tras 14A/14B)

```text
0. Resultados 14A (modelo operativo) + 14B (selector con ese modelo) → base de 15
1. Decidir rama: A (Phi juez con rúbrica) si 14A pasa · B (scorer multi-señal) si no
2. PRE-FLIGHT FWD: corpus intacto + fixture congelado verificado
3. Rama B: implementar run-selector-quality-PC.sh (M1-M4, ablación por señal)
   Rama A: prompt de rúbrica sobre el runner de 14A (mismo protocolo)
4. smoke E2E (1-2 queries) → corridas ×2 → determinismo G2
5. comparar vs F2 (funnel, Q06/Q08, gold_over_distractor, pRel/leak)
6. registrar en EVAL-REGISTRY.md + spec a EJECUTADO con Anexo
7. revisar con code-reviewer
8. commit + push (git commit -- paths) + detener(se) (runtime intacto)
```
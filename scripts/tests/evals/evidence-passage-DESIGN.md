# Paso 12 — Evidence-aware Passage Selection (diseño)

> Estado: **⏳ DISEÑO — pendiente de aprobación** (2026-08-12) — aún SIN runner.
> Base: EVAL con gold definitivo (hash `98a0e308…`), pasajes VENTANA ±4 validados,
> serie A→Q2 completa en `EVAL-REGISTRY.md`. Congelados: pool del Paso 10 con
> diccionario H2 (`baseline-H2-expansion-PC-2026-08-12.json`, dict_hash
> `b0406a33…`), orden del reranker R1-LEX (`baseline-R1-rerank-PC-2026-08-12.json`,
> hash `8316343e…`), presupuesto ~10.4k tokens, runtime.
> Dirección del usuario (2026-08-12): "Paso 12 — Evidence-aware passage
> selection": ¿una señal basada en el CONTENIDO puede distinguir un pasaje que
> realmente responde a la consulta de otro que solo comparte vocabulario/contexto?
> Requisito explícito: **ablación por señal** (como 10B) — no meter cinco
> heurísticas juntas. No adoptar nada automáticamente.
>
> ⚠️ **FWD — precondición de ejecución (lección del Paso 11):** antes de medir,
> verificar que el corpus NO se desvió respecto del estado en que se midió R1
> (comparar hash del corpus del working tree vs el de la corrida D de control del
> Paso 11). Si desviado → **worktree aislado en `18df679`** (el patrón aprobado
> por el usuario), medir solo allí, no tocar el working tree compartido.

---

## 1. Pregunta experimental

> ¿Una señal basada en el **contenido del pasaje** puede distinguir un pasaje que
> realmente responde a la consulta de otro que simplemente comparte
> vocabulario/contexto?

Las hipótesis ya descartadas por la serie: candidatos ✅ (H2), expansión ✅ (H2),
ranking ✅ (R1), granularidad ✅ (G1), deduplicación/estructura ❌ (Q1/Q2 —
mejoran recall/coste pero no calidad). La conclusión de Q1/Q2 es que la señal de
calidad **no vive en densidad/estructura sobre el orden R1** sino en el
**contenido del pasaje** (qué dice realmente). Paso 12 ataca esa capa con señales
de contenido, probadas **una por una** (ablación).

## 2. Evidencia medida HOY (2026-08-12) que dimensiona el diseño

### 2.1 Señales de contenido candidatas — poder discriminativo (aguja vs ruido)

> Medido sobre el **contexto de R1** (60 pasajes, 17 con aguja) con el corpus
> congelado en `18df679` (worktree temporal de diagnóstico).

| Señal | Con aguja | Sin aguja | Ratio | Como selector binario |
|---|---:|---:|---:|---|
| S1 verbatim n-gram contiguo (query ∪ X) | 1.353 | 1.302 | **1.0×** | ❌ muerta (prec 0.21 @ rec 0.24) |
| S2 idem solo en líneas command-like | 1.176 | 1.140 | **1.0×** | ❌ muerta |
| S3 heading de sección comparte términos | 0.137 | 0.008 | **17.7×** | prec 1.00 @ rec 0.35 (6/17, fp=0) |
| **S4 bge-m3 cosine(pasaje, query+X)** | 0.596 | 0.473 | 1.26× | **prec 0.867 @ rec 0.765 @ θ=0.55 (13 TP / 2 FP / 4 FN)** |

**Lectura:** S1/S2 quedan **descartadas** por los datos (las frases X no aparecen
verbatim en los pasajes con aguja — el vocabulario de expansión no aproxima los
comandos gold). S3 tiene **precisión perfecta pero recall bajo** (solo 6/17 agujas
viven en secciones cuyo heading matchea términos de la query). **S4 es la señal
más fuerte de toda la serie**: separa evidencia de ruido relacionado con solo 2
falsos positivos en 43 ruidosos. El embedding NO se usa como generador ni como
señal de ranking (eso falló en D y R2): se usa como **content-scorer** entre la
query expandida y el texto del pasaje — la pregunta controlada que el usuario
exigió antes de reutilizar bge-m3.

### 2.2 Los tres conceptos separados (medidos en R1)

El caso Q04-Q2 demostró que no deben confundirse:

```text
evidence_found       la aguja está en el pool (generación)         → H2: 20/20 ✅
evidence_selected    la aguja está en el CONTEXTO FINAL            → R1: 14/20
evidence_attributed  la aguja está en un pasaje/archivo GOLD del ctx → R1: 14/20
```

Dato crítico que reencuadra el problema: de las 14 agujas en el contexto de R1,
**solo 6 viven en la capa de pasajes**; las otras 8 están en los **archivos
completos del router**. La capa de pasajes —la que optimizan G1→Q2— es la que
concentra el ruido y aporta marginalmente evidencia. pRel 0.175 mide SOLO esa
capa. Por eso la señal de contenido debe evaluarse como **selector de la capa de
pasajes**: subir pRel sin perder las 6 agujas que la capa aporta hoy.

## 3. Diseño experimental

**Única variable:** capa de selección por contenido post-ranking R1, pre-contexto.
Pool H2 y orden R1 **congelados y verificables** (igual que Q1/Q2). El scorer de
contenido re-ordena/recorta la lista de pasajes candidatos (ranked por R1) usando
la señal; los pasajes que superan el gate entran al contexto en **orden R1**
dentro del grupo seleccionado (preserva "orden congelado" al máximo).

### Variantes (ablación por señal, de menor a mayor)

```text
Pool H2 congelado (L ∪ X ∪ S)
        │
   orden R1 congelado (r1-LEX)
        │
        ├── E1-S3     content: heading de sección (gratis, sin modelo)
        ├── E2-S4     content: bge-m3 cosine(pasaje, query+X)
        └── E3-S3+S4  combinación pequeña (2 señales, S4 + 0.5·S3, fija)
        │
        └── pasajes VENTANA ±4 → presupuesto 10.4k → ctx
```

- **E1-S3** — gate por heading: descartar pasajes cuya sección markdown no
  comparte ≥1 término significativo (>3 chars) con query ∪ X. Umbral derivado del
  diagnóstico (fp=0 en el contexto R1).
- **E2-S4** — gate por contenido semántico: `bge-m3 cosine(pasaje, query+X) ≥ θ`.
  **θ = 0.55 fijado ANTES de medir** (separación medida hoy: 13/2 vs 4/43 en el
  contexto de R1). El embedding de la query expandida se calcula una vez por
  query; el de cada pasaje candidato del pool, batch por Ollama local.
- **E3-S3+S4** — combinación declarativa **`S4 + 0.5·S3 ≥ θ`** (S4 con peso
  completo, S3 a la mitad — la ponderación EXACTA que midió el diagnóstico hoy:
  prec 0.812 / rec 0.765 @ θ=0.55). **NO usar `0.5·S3+0.5·S4 ≥ 0.55`**: en esa
  escala (media con aguja ≈ 0.367) el umbral rechazaría casi todo — corrige un
  bug detectado en review. Umbral y pesos fijos, sin calibración posterior a
  resultados.

Cada variante es **un resultado experimental independiente** (mismo gate) — no se
elige la mejor después de medir para declararla ganadora.

### Riesgos metodológicos declarados (corrección del review)

1. **Sesgo de optimismo en θ:** `θ_S4 = 0.55` se seleccionó del diagnóstico
   sobre el MISMO EVAL (contexto R1). Está pre-registrado antes de medir, pero
   el veredicto final sale de la **medición de pipeline completa** (pool→ctx),
   no del diagnóstico. Un solo umbral fijo, sin búsqueda post-hoc.
2. **Mismatch de población:** la precisión 0.867 se midió sobre el contexto R1
   (60 pasajes, ~6/query). E2 aplica el scorer al **pool** (50–200 ítems/query,
   10–30× mayor y más ruidoso) — la precisión esperable es menor. Si E2 da
   prec < 0.867 no es "fallo del diagnóstico": es transferencia a otra
   población.
3. **X proviene del dict H2 (techo diagnóstico del Paso 10):** S4 usa la query
   expandida del dict H2. Si H2-DICT-FULL es gold-informed, S4 hereda
   propiedades de techo y su poder está condicionado a ese dict. Contraste
   futuro posible: X del dict H1 (realista) para aislar ese efecto.

### Parámetros fijados ANTES de medir (congelados)

```text
EVAL = 98a0e308… · runtime = congelado · pool H2 = congelado (dict b0406a33…)
orden R1 = congelado (r1-LEX, 8316343e…) · presupuesto = 10.4k tokens
N_L=50 · N_X=50 · N_S=50 · PAS_PAD=4 · W_RERANK=1.0 (R1, SIN sem)
θ_S4 = 0.550 (a priori, del diagnóstico de hoy)
θ_S3 = 1 término significativo en heading (a priori)
pesos E3 = S4 + 0.5·S3 (la ponderación medida hoy; mismo θ = 0.55)
```

### Tres conceptos por query (obligatorio)

Cada variante reporta por query y por gold-fact: `evidence_found` (pool),
`evidence_selected` (contexto final), `evidence_attributed` (pasaje/archivo gold
en el contexto), **separados** — el error de Q04-Q2 (preservada pero no
atribuida) no debe repetirse. Además `agujas_preservadas` por-gold-fact (vs
contexto R1) y `tokens_evidencia_absolutos`.

## 4. Gate (6 criterios simultáneos, pre-fijados — idénticos a 10B/11)

```text
search_recall       > 0.100      (selección pasajes, instrumento v3.1)
passage_relevance  ≥ 0.600      (capa de pasajes)
leakage            ≤ 0.267      (cross-domain)
tokens             ≤ 10.4k      (presupuesto)
gold_containment   ≥ 0.80
baseline_regression ≤ 0.167     (vs R1 top10)
```

+ diagnósticos: `agujas_preservadas` (por-gold-fact), `gap_to_top10`, y los tres
conceptos por query. **Sin relajación tras ver resultados.** Si E2-S4 pasa →
NO se adopta automáticamente: se diseña el siguiente paso con la evidencia.

## 5. Lectura por capas (corrección aprendida del review del Paso 11)

1. **Si E2 sube pRel sin perder sRec** → la hipótesis se confirma: el contenido
   del pasaje distingue evidencia, y el embedding como scorer (no generador) es
   la señal. Frontera posiblemente resuelta para la capa de pasajes.
2. **Si E2 sube pRel pero cae attributed** → la selección por contenido mejora la
   capa pero la atribución de archivo sigue rota (caso Q04-Q2 repetido): separar
   found/selected/attributed lo mostrará sin ambigüedad.
3. **Si E3 ≈ E2** → S3 no aporta sobre S4 (el diagnóstico ya sugiere esto: S4
   solo es mejor que S3+S4 a θ=0.55). Si E3 < E2 → documentar y no insistir.
4. **E1-S3 solo** valida el costo cero: si su recall bajo (6/17) no alcanza, se
   descarta por datos, no por preferencia.
5. **Confound de composición (lección Q1/Q2):** las variantes E re-seleccionan
   desde una lista candidata mayor que el top10 de R1 → `fraccion_podada`/
   `tokens_ahorrados` negativos NO se interpretan como ahorro; se reportan con
   la misma advertencia del Paso 11.

## 6. Qué NO se hace (regla de no-tocar, acumulada de la serie)

- NO tocar runtime (`buffy-search.sh`, `buffy-router.sh`).
- NO re-medir R1 sobre el corpus actual (contaminación — lección del incidente
  FWD del Paso 11: usar worktree aislado en `18df679` si el corpus volvió a
  desviarse).
- NO calibración de θ ni pesos después de ver resultados.
- NO usar S1/S2 (descartadas por el diagnóstico de hoy).
- NO volver a bge-m3 como generador o señal de ranking (falló en D y R2).
- NO adoptar automáticamente si el gate pasa.
- NO mezclar 5 heurísticas: solo E1/E2/E3.

## 7. Orden de ejecución (tras aprobación)

```text
0. PRE-FLIGHT FWD: verificar corpus no desviado vs referencia R1 → si desviado,
   worktree aislado en 18df679 (patrón aprobado del Paso 11); medir solo allí
1. implementar run-evidence-PC.sh (E1/E2/E3 sobre pool+R1 congelados)
2. validar sintaxis + smoke E2E (E2 sobre 1-2 queries)
3. E1 ×2 corridas → determinismo G2
4. E2 ×2 corridas → determinismo G2
5. E3 ×2 corridas → determinismo G2
6. verificar pool == H2 y orden == R1 (congelados intactos) + θ/weights en el JSON
7. comparar E1/E2/E3 vs R1 y Q1/Q2 + per-query (Q03/Q04/Q06/Q08 en foco)
8. three concepts por query + agujas_preservadas + pRel_delta + coste de E2 (latencia embeds)
9. registrar en EVAL-REGISTRY.md + spec a EJECUTADO con Anexo
10. revisar con code-reviewer
11. commit + push (git commit -- paths) + detener(se) (runtime intacto)
```

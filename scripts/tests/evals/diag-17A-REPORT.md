# Diagnóstico 17A — Dónde se pierde la señal en Q01/Q05 (puente semántico H1)

> Fecha: 2026-08-14 · Runner: `run-granularity-PC.sh` (bloque python congelado,
> hook de trazado inyectado por `diag-17A-bridge.sh` — el runner NO se tocó).
> Config: PAS_PAD=4 (baseline 16B), LIMIT=10, H1 real (expand_query.py
> DICT_H1), sin oráculo, sin inyección de gold, piso rescue 0.545 intacto.
> Corpus: congelado bb33afa (7644 líneas, contenido idéntico; hash mtime
> c437e380 = alias del índice f36eaf1e — embeddings idénticos).
> Reproducibilidad: el run completo dio attr=12/20, pRel=0.415, leak=0.442,
> contain=1.000 — **idéntico al JSON oficial 16B run1/run2** (sanity ✅).

---

## 1. Método

Se extrae el bloque python del runner 16B (heredoc líneas 83-730), se inyecta
un hook que para Q01/Q05 imprime: términos H1 generados, golds esperados,
pasajes del pool que contienen cada needle (con su S1 y rama de origen), top-15
del pool por S1, y los pasajes elegidos en ctx. Se ejecuta con la misma config
congelada. Resultado en `/tmp/diag-17A-bridge.json` + salida trazada.

---

## 2. Q01 — "el teléfono no aparece en scrcpy"

| Campo | Valor |
|---|---|
| términos H1 reales | `list, show, device, adb devices` |
| golds esperados | `adb tcpip 5555`, `adb connect` |
| gold_files | `Knowledge/Android/scrcpy.md`, `Knowledge/Android/ADB.md` |
| pool | 355 pasajes — **ambos needles están EN el pool** (contain=1.0 ✅) |
| gated | **0** (ningún pasaje cruza S1 ≥ 0.545) |
| attr | 0/2 |

**S1 de los pasajes que contienen los needles:**

| Pasaje | S1 | Rama |
|---|---|---|
| ADB.md:9-17 (contiene `adb connect` + `adb tcpip`) | 0.4993 | X |
| ADB.md:8-16 (`adb tcpip`) | 0.4699 | X |
| ADB.md:5-13 (`adb connect`) | 0.4660 | X |
| … resto con needle | < 0.50 | X |

**Top-15 del pool por S1** (los que "suenan" más parecidos a la query):

| S1 | Pasaje | ¿needle? |
|---|---|---|
| 0.5440 | ADB.md:1-9 | ❌ |
| 0.5396 | scrcpy.md:82-86 | ❌ |
| 0.5394 | scrcpy.md:75-83 | ❌ |
| 0.5393 | SHIZUKU-RISH-BUG.md:254-262 | ❌ |
| 0.5352 | LOAD_CONTEXT.md:161-169 | ❌ |
| … | | ❌ |

**Lectura Q01:** la señal muere en **S1** (el ranking semántico query natural +
términos H1 vs pasaje). Los golds ESTÁN en el pool (la generación L∪X∪S∪P
funciona), pero el pasaje que contiene el comando (`adb tcpip 5555` /
`adb connect`) alcanza S1 ≈ 0.50, mientras el piso 0.545 lo deja afuera. El
mejor candidato del pool (0.5440) ni siquiera contiene los needles. La query
natural "el teléfono no aparece en scrcpy" NO menciona adb/tcpip/connect y los
términos H1 añadidos (`adb devices`) ayudan a RECUPERAR el archivo pero no a
RANKEAR el pasaje sobre el piso.

---

## 3. Q05 — "el componente React de la app necesita leer el serial del teléfono por adb"

| Campo | Valor |
|---|---|
| términos H1 reales | `component, application, package, read, get, serial, devices` |
| golds esperados | `useState`, `adb devices -l` |
| gold_files | `Knowledge/React/React.md`, `Knowledge/Android/ADB.md` |
| pool | 302 pasajes — **ambos needles están EN el pool** (contain=1.0 ✅) |
| gated | 6 (cruzan S1 ≥ 0.545) |
| gold_in_ctx | 2 (ADB.md:20-28 y ADB.md:22-30 — del archivo gold, pero SIN el needle literal) |
| attr | 0/2 |

**S1 de los pasajes que contienen los needles:**

| Pasaje | S1 | Rama |
|---|---|---|
| ADB.md:1-9 (contiene `adb devices -l`) | **0.5449** | — |
| ADB.md:5-13 (`adb devices -l`) | 0.5000 | X |
| ADB.md:6-14 (`adb devices -l`) | 0.4873 | X |
| React.md:19-27 (contiene `useState`) | 0.4005 | — |

**Los 6 que SÍ cruzan el piso** (ninguno contiene los needles):

| S1 | Pasaje | ¿needle? |
|---|---|---|
| 0.5782 | ADB.md:22-30 | ❌ |
| 0.5729 | SKILLS_INDEX.md:9-17 | ❌ |
| 0.5710 | SHIZUKU-RISH-BUG.md:252-260 | ❌ |
| 0.5544 | SESION-archive.md:276-284 | ❌ |
| 0.5544 | SESION-archive.md:806-814 | ❌ |
| 0.5533 | ADB.md:20-28 | ❌ |

**Lectura Q05:** doble pérdida. (a) El pasaje con `adb devices -l` (ADB.md:1-9)
alcanza **S1=0.5449 — falla el piso 0.545 por 0.0001**; `useState` (React.md:
19-27) queda en 0.4005, muy lejos. (b) Los 6 que cruzan son vecinos del archivo
gold (ADB.md:20-28/22-30) o ruido cross-domain; aunque son de gold_files, NO
contienen el needle literal → `attributed=0` aunque `gold_in_ctx=2`. La
atribución exige el needle literal en el pasaje, no solo el archivo.

---

## 4. Síntesis — dónde se pierde la señal (evidencia, no hipótesis)

1. **La generación del pool NO es el cuello de botella.** Los needles de Q01 y
   Q05 están en el pool (containment=1.0 en ambos; rama X los trae). La rama
   P-F2, la granularidad ±4 y max-passages funcionan — por eso 16B selló la
   granularidad.
2. **La señal muere en S1** (coseno bge-m3 entre `query natural + términos H1`
   y el pasaje): los pasajes con needle rankean 0.40-0.50 contra un piso 0.545.
3. **El piso 0.545 es un umbral duro con cruce marginal**: Q05 falla por
   0.0001 (0.5449) y Q01 por ~0.045 (0.4993 el mejor con needle). No es un
   "abismo" — es un margen fino que la query natural no salva.
4. **Los términos H1 actuales ayudan a recuperar pero no a rankear**: para Q01
   generan `adb devices` (trae ADB.md al pool) pero el pasaje con `adb tcpip
   5555` no sube del 0.50; para Q05 generan `serial/devices` pero `useState`
   queda en 0.40.
5. **Hay una capa adicional en Q05**: incluso con pasajes de gold_files en ctx,
   la atribución exige el needle literal → `gold_in_ctx=2` ≠ `attributed`.

**Diagnóstico:** el gap Q01/Q05 está en el **puente semántico entre la query
natural y el comando/símbolo**, materializado en el ranking S1 contra el piso.
La expansión H1 actual (DICT_H1) es insuficiente para ese tramo final: recupera
los archivos, no rankea los pasajes con el símbolo por encima del piso.

---

## 5. Lo que NO se toca (regla de la serie, confirmada por este diagnóstico)

- piso rescue 0.545, modelo bge-m3, granularidad ±4, gates, EVAL, corpus.
- Este diagnóstico NO propone solución; solo localiza la capa donde se pierde
  la señal (evidencia para la hipótesis 17.2).

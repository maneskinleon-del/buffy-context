#!/usr/bin/env bash
# bench-scale.sh — benchmark P0: selección correcta a escala + contaminación negativa.
#
# La verdadera prueba de Buffy ya no es si ENCUENTRA información: es si encuentra
# la información CORRECTA sin traer basura. Este benchmark siembra N hechos en un
# índice FTS5 real (vía buffy-search.sh), de los cuales solo K son relevantes a una
# tarea, y mide:
#
#   recall               — ¿recuperó los K relevantes? (0..1)
#   precision            — ¿evitó los N-K irrelevantes? (0..1)
#   irrelevant_leaked    — cuántos irrelevantes se colaron en el top-10
#   context_chars        — bytes de contexto seleccionado por la tarea
#   estimated_tokens     — chars/4 (regla gruesa, suficiente para comparar)
#   window_utilization   — estimated_tokens / ventana de referencia (200k tokens)
#
# Modo --adversarial (benchmark léxico difícil): los irrelevantes COMPARTEN el
# vocabulario de la query (scrcpy / ZTE) pero en contextos distintos (Free Fire,
# Linux, audio, resolución). Ahí BM25 tiene que distinguir la aguja real de los
# competidores léxicos — no es un caso fácil.
#
# IMPORTANTE: en modo adversarial el exit code mide que la MEDICIÓN corrió bien
# (JSON válido), NO que el recall sea perfecto. El campo "healthy" del JSON
# refleja el recall real: si FTS5 puro no distingue la aguja entre competidores
# léxicos, healthy=false documenta ESE límite (lo resuelve el router, que no
# está en este benchmark). Es un benchmark de medición, no un gate de regresión.
#
# Uso:
#   bash scripts/tests/bench-scale.sh            → 500 hechos, 2 relevantes
#   bash scripts/tests/bench-scale.sh --count 50 → hechos a sembrar (default 500)
#   bash scripts/tests/bench-scale.sh --adversarial → irrelevantes comparten vocabulario
#   bash scripts/tests/bench-scale.sh --json     → salida JSON pura (máquina)
#   bash scripts/tests/bench-scale.sh --quick    → corrida chica (50 hechos, sin --json)
#
# Exit: 0 si recall==1 y leaked==0 · 1 si falla · 2 error de uso.
# El benchmark NO toca el repo real: todo corre en un sandbox /tmp.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

COUNT=500
JSON=false
ADVERSARIAL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="${2:?falta número}"; shift 2 ;;
    --json)  JSON=true; shift ;;
    --adversarial) ADVERSARIAL=true; shift ;;
    --quick) COUNT=50; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

# ── Sandbox: repo simulado con índice real ─────────────────
SB="${TMPDIR:-/tmp}/buffy-bench-$$"
rm -rf "$SB"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/ai-context" "$SB/Knowledge"

# Sembrar N hechos en un archivo que el scope del search indexa (Knowledge/*.md).
# K=2 relevantes: AMBAS comparten el vocabulario de la tarea (scrcpy + ZTE) —
# así una sola query de tarea debe recuperarlas — pero cada una aporta un hecho
# ÚNICO (buffer_size / adb tcpip) que el detector usa como marcador.
K=2
SEED_FILE="$SB/Knowledge/bench-seed.md"
{
  echo "# Benchmark seed — $COUNT hechos, $K relevantes"
  echo
  # Hechos relevantes (aguja): tarea "scrcpy ZTE"; el detector busca los
  # marcadores ÚNICOS (buffer_size / tcpip) que el snippet NO envuelve.
  printf '%s\n' "SOLUCION_BENCH_ZTE: buffer_size=2M en scrcpy resuelve el stutter en la ZTE Nubia Free Fire."
  printf '%s\n' "SOLUCION_BENCH_ADB: adb tcpip 5555 + adb connect 192.168.1.37 reconecta la ZTE para scrcpy sin cable."
  # Irrelevantes: dominios distintos, NUNCA mencionan scrcpy ni ZTE → sin
  # colisión léxica con la tarea. En modo --adversarial, en cambio, una parte
  # COMPARTE el vocabulario de la query (scrcpy/ZTE) pero habla de otra cosa.
  i=0
  n_irrel=$((COUNT - K))
  while [ "$i" -lt "$n_irrel" ]; do
    if [ "$ADVERSARIAL" = true ] && [ $((i % 3)) -eq 0 ]; then
      # Competidor léxico: comparte scrcpy o ZTE con la query, tema distinto.
      case $((i % 6)) in
        0) printf 'Nota %05d: scrcpy con --no-audio en la ZTE se usa para ver la pantalla, nada de buffer.\n' "$i" ;;
        1) printf 'Nota %05d: Free Fire en la ZTE Nubia, scrcpy sirve para el mapa, no para USB.\n' "$i" ;;
        2) printf 'Nota %05d: en Linux scrcpy compila con paquetes extra, la ZTE no interviene.\n' "$i" ;;
        3) printf 'Nota %05d: scrcpy resolución 1080p en la ZTE, ajuste de pantalla para GG Mouse.\n' "$i" ;;
        4) printf 'Nota %05d: el audio de scrcpy se corta en la ZTE, se soluciona con la app de audio.\n' "$i" ;;
        5) printf 'Nota %05d: scrcpy en la ZTE con teclado, los bindings de bspwm no aplican.\n' "$i" ;;
      esac
    else
      printf 'Hecho irrelevante %05d: preferencia de tema %d, config de rice %d, paquete %d en pacman, bspwm binding %d.\n' \
        "$i" "$((i % 7))" "$((i % 13))" "$((i % 29))" "$((i % 31))"
    fi
    i=$((i + 1))
  done
} > "$SEED_FILE"

# ── Búsqueda real contra el índice (misma infraestructura de producción) ──
search_top() {
  local q="$1" limit="${2:-10}"
  BUFFY_REPO="$SB" XDG_CACHE_HOME="$SB/.cache" bash "$SCRIPTS_DIR/buffy-search.sh" -l "$limit" "$q" 2>/dev/null \
    || true
}

# 1. Recall: la tarea "scrcpy ZTE" debe recuperar las 2 agujas. El snippet de
#    FTS5 envuelve los términos de la query en «», así que detectamos por los
#    marcadores ÚNICOS de cada aguja (buffer_size / tcpip), que NO están en la query.
HITS=$(search_top "scrcpy ZTE" 10 || true)
RECALL=0
echo "$HITS" | grep -q "buffer_size" && RECALL=$((RECALL + 1))
echo "$HITS" | grep -q "tcpip 5555" && RECALL=$((RECALL + 1))

# 2. Precisión / contaminación: ninguna línea irrelevante debe colarse.
#    En modo normal las irrelevantes tienen el prefijo "Hecho irrelevante".
#    En modo adversarial los competidores comparten scrcpy/ZTE pero arrancan
#    con "Nota" — contamos cualquiera de los dos patrones.
if [ "$ADVERSARIAL" = true ]; then
  LEAKED=$(echo "$HITS" | grep -cE "^(Hecho irrelevante|Nota [0-9]{5})" || true)
else
  LEAKED=$(echo "$HITS" | grep -c "Hecho irrelevante" || true)
fi

# 3. Presupuesto de contexto: los resultados que el agente terminaría leyendo.
CTX_BYTES=$(printf '%s' "$HITS" | wc -c)
CTX_CHARS=$(printf '%s' "$HITS" | wc -m)
EST_TOKENS=$((CTX_CHARS / 4))
WINDOW_TOKENS=200000
UTIL=$(awk -v t="$EST_TOKENS" -v w="$WINDOW_TOKENS" 'BEGIN{printf "%.4f", t/w}')

if [ "$JSON" = true ]; then
  printf '{"task":"scale-selection","mode":"%s","seeded":%d,"relevant":%d,"recall":%d,"precision":%s,"irrelevant_leaked":%d,"context_bytes":%d,"context_chars":%d,"estimated_tokens":%d,"window_utilization":%s,"healthy":%s}\n' \
    "$( [ "$ADVERSARIAL" = true ] && echo adversarial || echo easy )" \
    "$COUNT" "$K" "$RECALL" "$(awk -v l="$LEAKED" 'BEGIN{printf "%.2f", (l==0?1:0)}')" \
    "$LEAKED" "$CTX_BYTES" "$CTX_CHARS" "$EST_TOKENS" "$UTIL" \
    "$( [ "$RECALL" -eq "$K" ] && [ "$LEAKED" -eq 0 ] && echo true || echo false )"
else
  echo "── benchmark scale (modo: $( [ "$ADVERSARIAL" = true ] && echo adversarial || echo easy )) ──"
  echo "  sembrados: $COUNT hechos ($K relevantes)"
  echo "  recall:               $RECALL (esperado $K)"
  echo "  irrelevantes filtrados (leaked en top-10): $LEAKED (esperado 0)"
  echo "  contexto seleccionado: $CTX_CHARS chars / ~$EST_TOKENS tokens"
  echo "  utilización de ventana (200k tokens): $UTIL"
fi

# En modo adversarial: exit 0 = la MEDICIÓN corrió (JSON válido). El recall real
# queda en healthy (documenta el límite de FTS5 puro ante competidores léxicos;
# lo resuelve el router, que no está en este benchmark). Es medición, no gate.
# En modo easy: exit 0 = recall completo + 0 leaked (gate de regresión).
if [ "$ADVERSARIAL" = true ]; then
  exit 0
fi
[ "$RECALL" -eq "$K" ] && [ "$LEAKED" -eq 0 ]

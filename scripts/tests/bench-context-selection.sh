#!/usr/bin/env bash
# bench-context-selection.sh — benchmark P0: selección de contexto CON router (pipeline completo).
#
# El benchmark anterior (bench-scale.sh --adversarial) demostró el límite de FTS5 puro:
# cuando los irrelevantes COMPARTEN el vocabulario de la query (scrcpy/ZTE) en contextos
# distintos, BM25 ahoga la aguja con menos términos exclusivos (recall 1/2, healthy=false).
# La capa que resuelve eso es el ROUTER — que filtra por dominio ANTES de buscar. Este
# benchmark ejercita el pipeline COMPLETO:
#
#   USER REQUEST → buffy-router.sh → categoría → knowledge files → buffy-search.sh (FTS5) → ranking
#
# y mide:
#
#   domain_precision   — de los knowledge files que el router eligió, ¿cuántos son del
#                        dominio correcto? (0..1; para "scrcpy ZTE" → Android)
#   domain_recall      — ¿el router incluyó los archivos relevantes del dominio?
#                        (scrcpy.md + ADB.md → esperado 1.0)
#   categories         — lista de categorías que detectó el router
#   spurious_categories— categorías que NO deberían estar para esta tarea (Linux/React...)
#   search_recall      — agujas de la tarea recuperadas por FTS5 puro (límite medido)
#   search_leaked      — hechos irrelevantes colados en el top-N de FTS5
#   pipeline_healthy   — la combinación router→search cubre la tarea (domain_recall==1
#                        Y (aguja en contexto O en search))
#   context_chars/tokens — presupuesto del contexto que el router cargaría
#   window_utilization   — context_tokens / ventana de referencia (200k)
#
# Tesis medida: aunque FTS5 falle solo (search_recall bajo / leaked alto en modo
# adversarial), el ROUTER resuelve porque carga el archivo del dominio correcto →
# pipeline_healthy se mantiene. Eso justifica (o no) el próximo cambio en el motor
# de selección de contexto.
#
# Modo --adversarial (léxico difícil): los irrelevantes de Linux/FreeFire COMPARTEN
# scrcpy/ZTE con la query pero viven en dominios distintos → FTS5 puro se contamina.
#
# Uso:
#   bash scripts/tests/bench-context-selection.sh            → default (50 hechos/dominio)
#   bash scripts/tests/bench-context-selection.sh --count 100 → hechos por dominio
#   bash scripts/tests/bench-context-selection.sh --adversarial → irrelevantes comparten vocabulario
#   bash scripts/tests/bench-context-selection.sh --json     → salida JSON pura (máquina)
#   bash scripts/tests/bench-context-selection.sh --quick    → corrida chica (20 hechos/dominio)
#
# Exit: 0 si pipeline_healthy y domain_precision==1 y spurious==0 · 1 si no · 2 error de uso.
# En modo adversarial el exit 0 = la MEDICIÓN corrió (JSON válido); healthy del JSON
# documenta si el pipeline aguanta el caso difícil. Es medición, no gate.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

COUNT=50
JSON=false
ADVERSARIAL=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --count) COUNT="${2:?falta número}"; shift 2 ;;
    --json)  JSON=true; shift ;;
    --adversarial) ADVERSARIAL=true; shift ;;
    --quick) COUNT=20; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "opción desconocida: $1" >&2; exit 2 ;;
  esac
done

TASK="el teléfono no aparece en scrcpy"
K_DOMAIN_FILES=2        # archivos relevantes del dominio: Android/scrcpy.md + Android/ADB.md
K_NEEDLES=2             # agujas (hechos únicos) en scrcpy.md

# ── Sandbox: repo simulado con índice real ─────────────────
SB="${TMPDIR:-/tmp}/buffy-benchctx-$$"
rm -rf "$SB"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/ai-context" "$SB/Knowledge/Android" "$SB/Knowledge/Linux" \
         "$SB/Knowledge/FreeFire" "$SB/Knowledge/React" \
         "$SB/.agents/skills/android-adb" "$SB/.agents/skills/scrcpy-freefire"

# Base mínima para el router (INFO-core + CONTINUE + SNAPSHOT se generan vacíos).
: > "$SB/ai-context/INFO-core.md"
: > "$SB/ai-context/CONTINUE.md"
: > "$SB/ai-context/SNAPSHOT.md"

# Manifests de skills para que add_skill no los marque como missing.
cat > "$SB/.agents/skills/android-adb/skill.yaml" <<'Y'
id: android-adb
entry: SKILL.md
safe: true
triggers:
  - adb|scrcpy|shizuku
Y
cat > "$SB/.agents/skills/android-adb/SKILL.md" <<'Y'
# android-adb
Comandos ADB para diagnóstico y control de dispositivo.
Y
cat > "$SB/.agents/skills/scrcpy-freefire/skill.yaml" <<'Y'
id: scrcpy-freefire
entry: SKILL.md
safe: true
triggers:
  - scrcpy|gg mouse|free fire
Y
cat > "$SB/.agents/skills/scrcpy-freefire/SKILL.md" <<'Y'
# scrcpy-freefire
Setup scrcpy + keymapper para Free Fire.
Y

# ── Siembra de hechos por dominio ──────────────────────────
# AGUJA (Knowledge/Android/scrcpy.md): K_NEEDLES hechos relevantes a la tarea.
# Los detectores usan marcadores ÚNICOS (bench_needle_buffer / bench_needle_tcpip)
# que el snippet de FTS5 NO envuelve (no están en la query).
{
  echo "# Android scrcpy — benchmark seed"
  echo "bench_needle_buffer: buffer_size=2M en scrcpy arregla el stutter en la ZTE Nubia."
  echo "bench_needle_tcpip: adb tcpip 5555 + adb connect 192.168.1.37 reconecta la ZTE para scrcpy sin cable."
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    printf 'Hecho Android %05d: config de scrcpy, modo de uso, perfil %d.\n' "$i" "$((i % 5))"
    i=$((i + 1))
  done
} > "$SB/Knowledge/Android/scrcpy.md"

# ADB.md — segundo archivo relevante del dominio Android (domain_recall).
{
  echo "# Android ADB — benchmark seed"
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    printf 'Hecho ADB %05d: comando adb de diagnóstico %d.\n' "$i" "$((i % 7))"
    i=$((i + 1))
  done
} > "$SB/Knowledge/Android/ADB.md"

# Dominios irrelevantes.
# Linux: en modo adversarial comparte scrcpy/ZTE (competidor léxico).
{
  echo "# Linux system — benchmark seed"
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    if [ "$ADVERSARIAL" = true ]; then
      case $((i % 4)) in
        0) printf 'Nota Linux %05d: scrcpy compila en Linux con paquetes extra, la ZTE no interviene.\n' "$i" ;;
        1) printf 'Nota Linux %05d: systemd unit para scrcpy en la ZTE, tema del sistema.\n' "$i" ;;
        2) printf 'Nota Linux %05d: en Linux scrcpy corre sobre X11, nada de buffer.\n' "$i" ;;
        3) printf 'Nota Linux %05d: driver bspwm, la ZTE y scrcpy no aplican aca.\n' "$i" ;;
      esac
    else
      printf 'Hecho Linux %05d: config de sistema %d, bspwm binding %d.\n' "$i" "$((i % 11))" "$((i % 13))"
    fi
    i=$((i + 1))
  done
} > "$SB/Knowledge/Linux/System.md"

# FreeFire: en modo adversarial comparte scrcpy/ZTE (competidor léxico).
{
  echo "# Free Fire — benchmark seed"
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    if [ "$ADVERSARIAL" = true ]; then
      case $((i % 4)) in
        0) printf 'Nota FreeFire %05d: scrcpy con --no-audio en la ZTE se usa para ver la pantalla.\n' "$i" ;;
        1) printf 'Nota FreeFire %05d: Free Fire en la ZTE, scrcpy sirve para el mapa, no para USB.\n' "$i" ;;
        2) printf 'Nota FreeFire %05d: scrcpy resolucion 1080p en la ZTE, ajuste para GG Mouse.\n' "$i" ;;
        3) printf 'Nota FreeFire %05d: el audio de scrcpy se corta en la ZTE, solucion con la app.\n' "$i" ;;
      esac
    else
      printf 'Hecho FreeFire %05d: config de juego %d, mapa %d.\n' "$i" "$((i % 9))" "$((i % 17))"
    fi
    i=$((i + 1))
  done
} > "$SB/Knowledge/FreeFire/GameOptimization.md"

# React: irrelevante sin vocabulario compartido (control).
{
  echo "# React — benchmark seed"
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    printf 'Hecho React %05d: hook de estado %d, componente %d.\n' "$i" "$((i % 6))" "$((i % 8))"
    i=$((i + 1))
  done
} > "$SB/Knowledge/React/React.md"

# ── Etapa 1: ROUTER (USER REQUEST → categoría → knowledge files) ──
ROUTER_JSON="$(BUFFY_REPO="$SB" BUFFY_HOME="$SB" bash "$SCRIPTS_DIR/buffy-router.sh" --repo "$SB" --json "$TASK" 2>/dev/null || true)"

categories() {
  printf '%s' "$ROUTER_JSON" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    print("\n".join(d.get("categories", [])))
except Exception:
    pass
'
}
knowledge_files() {
  printf '%s' "$ROUTER_JSON" | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
    print("\n".join(d.get("knowledge", [])))
except Exception:
    pass
'
}

CATS="$(categories)"
KNO="$(knowledge_files)"

# domain_precision: de los knowledge files elegidos, ¿cuántos son del dominio Android?
TOTAL_KNO=$(printf '%s\n' "$KNO" | grep -c . || true)
KNO_ANDROID=$(printf '%s\n' "$KNO" | grep -c '/Android/' || true)
if [ "$TOTAL_KNO" -gt 0 ]; then
  DOMAIN_PRECISION=$(awk -v a="$KNO_ANDROID" -v t="$TOTAL_KNO" 'BEGIN{printf "%.2f", a/t}')
else
  DOMAIN_PRECISION="0.00"
fi

# domain_recall: ¿el router incluyó los 2 archivos relevantes del dominio?
DOMAIN_RECALL=0
printf '%s\n' "$KNO" | grep -q "Knowledge/Android/scrcpy.md" && DOMAIN_RECALL=$((DOMAIN_RECALL + 1))
printf '%s\n' "$KNO" | grep -q "Knowledge/Android/ADB.md" && DOMAIN_RECALL=$((DOMAIN_RECALL + 1))

# spurious_categories: categorías que NO deberían activarse para tarea Android/scrcpy.
SPURIOUS=0
for c in "Linux" "React" "Git" "Node" "Shell" "Visión/VLM" "Code Search"; do
  printf '%s\n' "$CATS" | grep -qx "$c" && SPURIOUS=$((SPURIOUS + 1))
done

# ── Etapa 2: SEARCH (FTS5 real sobre el índice del sandbox) ──
search_top() {
  local q="$1" limit="${2:-10}"
  BUFFY_REPO="$SB" XDG_CACHE_HOME="$SB/.cache" bash "$SCRIPTS_DIR/buffy-search.sh" -l "$limit" "$q" 2>/dev/null \
    || true
}
HITS="$(search_top "scrcpy ZTE" 10 || true)"

SEARCH_RECALL=0
printf '%s' "$HITS" | grep -q "bench_needle_buffer" && SEARCH_RECALL=$((SEARCH_RECALL + 1))
printf '%s' "$HITS" | grep -q "bench_needle_tcpip" && SEARCH_RECALL=$((SEARCH_RECALL + 1))

# OJO: el path antecede al texto en los hits ("Knowledge/Linux/System.md:1: Nota Linux...").
# El grep NO puede ir anclado a ^ — busca el patrón en cualquier parte de la línea.
if [ "$ADVERSARIAL" = true ]; then
  SEARCH_LEAKED=$(printf '%s' "$HITS" | grep -cE "(Hecho Linux|Hecho FreeFire|Nota Linux|Nota FreeFire)" || true)
else
  SEARCH_LEAKED=$(printf '%s' "$HITS" | grep -cE "(Hecho Linux|Hecho FreeFire)" || true)
fi

# ── Etapa 3: presupuesto de contexto (lo que el agente cargaría) ──
CTX_ROUTER=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if [ -f "$SB/$f" ]; then
    CTX_ROUTER=$((CTX_ROUTER + $(wc -c < "$SB/$f")))
  fi
done <<< "$KNO"
CTX_HITS=$(printf '%s' "$HITS" | wc -c)
CTX_BYTES=$((CTX_ROUTER + CTX_HITS))
CTX_CHARS=$(printf '%s' "$HITS" | wc -m)
CTX_TOTAL_CHARS=$((CTX_BYTES + CTX_CHARS))
EST_TOKENS=$((CTX_TOTAL_CHARS / 4))
WINDOW_TOKENS=200000
UTIL=$(awk -v t="$EST_TOKENS" -v w="$WINDOW_TOKENS" 'BEGIN{printf "%.4f", t/w}')

# pipeline_healthy: el router cubrió el dominio (domain_recall==1) y la aguja está
# en el contexto del router O en el search (aguja en scrcpy.md → contexto del router
# la tiene SIEMPRE que domain_recall==1).
if [ "$DOMAIN_RECALL" -eq "$K_DOMAIN_FILES" ]; then
  PIPELINE_HEALTHY=true
else
  PIPELINE_HEALTHY=false
fi

if [ "$JSON" = true ]; then
  printf '{"task":"context-selection","mode":"%s","categories":%s,"spurious_categories":%d,"domain_precision":%s,"domain_recall":%d,"expected_domain_files":%d,"search_recall":%d,"expected_needles":%d,"search_leaked":%d,"knowledge_files":%d,"context_bytes":%d,"context_chars":%d,"estimated_tokens":%d,"window_utilization":%s,"pipeline_healthy":%s}\n' \
    "$( [ "$ADVERSARIAL" = true ] && echo adversarial || echo easy )" \
    "$(printf '%s' "$ROUTER_JSON" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(json.dumps(d.get("categories",[])))' 2>/dev/null || echo '[]')" \
    "$SPURIOUS" "$DOMAIN_PRECISION" "$DOMAIN_RECALL" "$K_DOMAIN_FILES" \
    "$SEARCH_RECALL" "$K_NEEDLES" "$SEARCH_LEAKED" "$TOTAL_KNO" \
    "$CTX_TOTAL_CHARS" "$CTX_TOTAL_CHARS" "$EST_TOKENS" "$UTIL" "$PIPELINE_HEALTHY"
else
  echo "── benchmark context-selection (modo: $( [ "$ADVERSARIAL" = true ] && echo adversarial || echo easy )) ──"
  echo "  tarea: $TASK"
  echo "  router categorías:      ${CATS:-ninguna}"
  echo "  spurious categories:    $SPURIOUS (esperado 0)"
  echo "  domain_precision:       $DOMAIN_PRECISION (knowledge del dominio correcto)"
  echo "  domain_recall:          $DOMAIN_RECALL/$K_DOMAIN_FILES (archivos relevantes en contexto)"
  echo "  search_recall (FTS5):   $SEARCH_RECALL/$K_NEEDLES (límite de FTS5 puro)"
  echo "  search_leaked:          $SEARCH_LEAKED (irrelevantes en top-10 de FTS5)"
  echo "  contexto router+search: $CTX_TOTAL_CHARS chars / ~$EST_TOKENS tokens"
  echo "  utilización ventana:    $UTIL (200k tokens)"
  echo "  pipeline_healthy:       $PIPELINE_HEALTHY"
fi

# En modo adversarial: exit 0 = la MEDICIÓN corrió (el healthy del JSON documenta
# si el pipeline aguanta el caso difícil — es dato, no gate).
# En modo easy: exit 0 = pipeline sano (dominio correcto, sin spurious).
if [ "$ADVERSARIAL" = true ]; then
  exit 0
fi
[ "$PIPELINE_HEALTHY" = true ] && [ "$DOMAIN_PRECISION" = "1.00" ] && [ "$SPURIOUS" -eq 0 ]

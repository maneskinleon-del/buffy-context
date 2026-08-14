#!/usr/bin/env bash
# buffy-search.sh — búsqueda FTS5 sobre buffy-context (SESION, CHANGELOG, Knowledge...)
# Inspirado en session_search de Hermes Agent: índice SQLite FTS5, sin gastar tokens.
# Indexa una fila por línea (path + lineno en columnas UNINDEXED) → resultados estilo grep.
#
# Uso:
#   buffy-search.sh "consulta"        # busca, ordenado por relevancia (bm25)
#   buffy-search.sh -l 30 "consulta"  # más resultados
#   buffy-search.sh --select "consulta"  # busca + selector M3 (top-K pasajes puntuados)
#   buffy-search.sh --expand-query "consulta"  # (con --select) rama X del Paso 10
#   buffy-search.sh --update          # reindexa solo archivos cambiados (se hace solo antes de buscar)
#   buffy-search.sh --reindex         # reconstruye el índice completo
#   buffy-search.sh --stats           # estado del índice
#   BUFFY_REPO=/ruta/al/repo buffy-search.sh ...   # repo alternativo
#
# --select (integración M3, 2026-08-13): pasa los candidatos del FTS5 al selector
# quality-aware (buffy-selector.sh → M3 S1+S2+S3+S4, gate rescue 0.545) y devuelve
# el top-K de pasajes puntuado. Requiere Ollama + bge-m3 (si no está disponible,
# degrada a la búsqueda cruda con aviso). El default (sin --select) queda intacto
# byte a byte. Con --select --json emite el JSON del selector.
#
# --expand-query (rama X, 2026-08-14): SOLO afecta a --select. Expande la query
# con el diccionario genérico ES→EN H1 (scripts/lib/expand_query.py, portado del
# runner del Paso 10) en dos mecanismos: (1) X-candidatos — re-consultas FTS5 por
# cada término del diccionario, hits extra al pool antes del selector (gate ≥1
# token significativo por construcción de la query OR, tope 100 declarado); (2)
# X-query — la query expandida (original + términos X) se pasa como --terms al
# selector para que S1 (bge-m3) puntúe con el vocabulario expandido (fix del gap
# semántico Q03: `pushear`→`push`, `crear`→`create`). Default OFF (no-regresión
# byte a byte); también activable con BUFFY_EXPAND_QUERY=true. Sin --select es no-op.
set -euo pipefail

SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO="${BUFFY_REPO:-$HOME/buffy-context}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-search"
DB="$CACHE/search.db"
LIMIT=15
CMD="search"
SEP=$'\x1f'
STRATEGY="${BUFFY_SEARCH_STRATEGY:-and}"
SELECT=false
JSON_OUT=false
EXPAND_QUERY=false
[ "${BUFFY_EXPAND_QUERY:-}" = "true" ] && EXPAND_QUERY=true

# Stopwords ES (normalizadas: minúsculas sin diacríticos, coherentes con el tokenizer).
STOPWORDS_ES="a al algo aunque asi aun cada casi como con cual cuando cuanta cuantas cuanto
cuantos de del demasiado donde el ella ellas ellos en entre esa esas ese esos esta estas
este estos fue haber hasta haya hay he hizo la las le les lo los mas me mi mis mucho muchos
mucha muchas muy nada nadie ni no nosotros nosotras nuestra nuestras nuestro nuestros o otra
otras otro otros para pero poca pocas poco pocos por porque que quien quienes quiero quiere
se sea ser si sin solo sino sobre su sus tal tambien tampoco tan tanto tanta te tiene tienes
todo todos toda todas tu tus un una uno unas usted y ya"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--limit) LIMIT="${2:?falta número}"; shift 2 ;;
    --select)   SELECT=true ; shift ;;
    --expand-query) EXPAND_QUERY=true ; shift ;;
    --json)     JSON_OUT=true; shift ;;
    --update)   CMD="update" ; shift ;;
    --reindex)  CMD="reindex"; shift ;;
    --stats)    CMD="stats"  ; shift ;;
    -h|--help)  sed -n '2,13p' "$0"; exit 0 ;;
    --)         shift; break ;;
    -*)         echo "opción desconocida: $1" >&2; exit 2 ;;
    *)          break ;;
  esac
done

QUERY="${1:-}"

find_scope() {
  {
    find "$REPO" -maxdepth 1 -type f \( -name '*.md' -o -name '*.yaml' \) -print0 2>/dev/null
    find "$REPO/ai-context" "$REPO/Knowledge" \
         -path '*/deprecated' -prune -o \
         -type f \( -name '*.md' -o -name '*.yaml' \) -print0 2>/dev/null
  }
}

ensure_schema() {
  mkdir -p "$CACHE"
  sqlite3 "$DB" <<'SQL'
CREATE TABLE IF NOT EXISTS files(path TEXT PRIMARY KEY, mtime TEXT, size INTEGER);
CREATE VIRTUAL TABLE IF NOT EXISTS docs USING fts5(
  path UNINDEXED,
  lineno UNINDEXED,
  line,
  tokenize='unicode61 remove_diacritics 2'
);
SQL
}

sql_quote() { printf '%s' "${1//\'/\'\'}"; }

index_file() {
  local f="$1" n=0 line esc sql
  sql="DELETE FROM docs WHERE path='$(sql_quote "$f")';"
  while IFS= read -r line; do
    n=$((n+1))
    esc="$(sql_quote "$line")"
    sql+="INSERT INTO docs(path, lineno, line) VALUES('$(sql_quote "$f")', $n, '$esc');"
  done < "$REPO/$f"
  printf '%s\n' "$sql" | sqlite3 "$DB"
}

reindex_changed() {
  ensure_schema
  local count=0 f mtime size cur
  while IFS= read -r -d '' f; do
    f="${f#$REPO/}"
    [[ -f "$REPO/$f" ]] || continue
    mtime="$(stat -c %Y "$REPO/$f")"
    size="$(stat -c %s "$REPO/$f")"
    cur="$(sqlite3 "$DB" "SELECT mtime||':'||size FROM files WHERE path='$(sql_quote "$f")';")"
    if [[ "$cur" != "$mtime:$size" ]]; then
      index_file "$f"
      sqlite3 "$DB" "INSERT OR REPLACE INTO files(path,mtime,size) VALUES('$(sql_quote "$f")','$mtime','$size');"
      count=$((count+1))
    fi
  done < <(find_scope)
  if [[ "$CMD" == "update" || "$count" -gt 0 ]]; then
    if [[ "$JSON_OUT" == true ]]; then
      echo "index: $count archivo(s) actualizado(s)" >&2
    else
      echo "index: $count archivo(s) actualizado(s)"
    fi
  fi
}

do_reindex() {
  rm -f "$DB"
  ensure_schema
  local count=0 f
  while IFS= read -r -d '' f; do
    f="${f#$REPO/}"
    [[ -f "$REPO/$f" ]] || continue
    index_file "$f"
    sqlite3 "$DB" "INSERT OR REPLACE INTO files(path,mtime,size) VALUES('$(sql_quote "$f")','$(stat -c %Y "$REPO/$f")','$(stat -c %s "$REPO/$f")');"
    count=$((count+1))
  done < <(find_scope)
  echo "reindex: $count archivo(s)"
}

do_stats() {
  [[ -f "$DB" ]] || { echo "índice vacío — ejecuta: $0 --reindex"; exit 1; }
  echo "db:   $DB ($(du -h "$DB" | cut -f1))"
  echo "docs: $(sqlite3 "$DB" 'SELECT count(*) FROM docs;') líneas indexadas"
  echo "dirs:"
  sqlite3 "$DB" "SELECT CASE WHEN path LIKE 'Knowledge/%' THEN 'Knowledge'
                             WHEN path LIKE 'ai-context/%' THEN 'ai-context'
                             ELSE 'raíz' END AS d, count(*) FROM docs GROUP BY d;"
}

deaccent() { tr 'áéíóúüñÁÉÍÓÚÜÑ' 'aeiouunAEIOUUN'; }

# Construcción de la query FTS5 según la estrategia:
#   and (default) — comportamiento histórico byte a byte: "t1" AND "t2" ...
#   or  — Fase 1 del benchmark realista: normalizar → stopwords → términos
#         significativos (longitud >= 3, nunca descartar tokens técnicos de 3
#         chars como adb/api/dpi) → "t1" OR "t2" ... (máx 8) → fallback AND si
#         no queda ningún término útil (para no devolver basura).
build_query() {
  local raw="$1" q tok strategy="${2:-$STRATEGY}"
  if [[ "$strategy" != "or" ]]; then
    q="$(awk '{ for (i=1; i<=NF; i++) { gsub(/"/, "\"\"", $i); printf "\"%s\"%s", $i, (i<NF ? " AND " : "") } }' <<<"$raw")"
    printf '%s' "$q"
    return
  fi
  local norm parts=()
  norm="$(printf '%s' "$raw" | deaccent | sed 's/[^[:alnum:] ]/ /g' | tr -s ' ')"
  for tok in $norm; do
    tok="${tok,,}"
    [[ ${#tok} -ge 3 ]] || continue
    case " $STOPWORDS_ES " in
      *" $tok "*) continue ;;
    esac
    parts+=("$tok")
    [[ ${#parts[@]} -ge 8 ]] && break
  done
  if [[ ${#parts[@]} -gt 0 ]]; then
    q="\"${parts[0]}\""
    for tok in "${parts[@]:1}"; do
      q+=" OR \"$tok\""
    done
  else
    q="$(awk '{ for (i=1; i<=NF; i++) { gsub(/"/, "\"\"", $i); printf "\"%s\"%s", $i, (i<NF ? " AND " : "") } }' <<<"$raw")"
  fi
  printf '%s' "$q"
}

search() {
  local q raw="$1"
  if [[ "$SELECT" == true && "$STRATEGY" == "and" ]]; then
    # El default `and` no genera candidatos para queries naturales (medido en el
    # EVAL: search_recall 0.000 — una query de N palabras exige las N en la misma
    # línea). --select genera candidatos con `or` (como el pool F2 del EVAL) y
    # deja que el selector M3 filtre por calidad. El default sin --select queda
    # intacto byte a byte. El usuario puede forzar otra estrategia con
    # BUFFY_SEARCH_STRATEGY (entonces se respeta la suya).
    q="$(build_query "$raw" or)"
  else
    q="$(build_query "$raw")"
  fi
  q="${q//\'/''}"
  [[ -n "$q" ]] || return 0
  local out n=0 path lineno snip
  out="$(search_query "$q")" || { echo "error de búsqueda: $raw" >&2; return 1; }
  if [[ -z "$out" ]]; then
    if [[ "$SELECT" == true && "$JSON_OUT" == true ]]; then
      printf '{"model":"M3","selected":[],"error":"sin_resultados","degraded":true}\n'
    else
      echo "Sin resultados para: $raw"
    fi
    return 0
  fi
  if [[ "$SELECT" == true ]]; then
    # ── Modo --select: candidatos FTS5 → selector M3 → top-K de pasajes ──
    # Los candidatos se pasan como {path, lineno} (ventana ±4 se construye en el
    # motor, igual que en el EVAL). Degrada a búsqueda cruda si Ollama no está.
    local cands="[" first=1 sel_out rc sel_args=() seen_keys=" "
    # Rama X (opt-in --expand-query): términos del diccionario H1 para la query.
    local x_terms=() term tq tout terms_json=""
    if [[ "$EXPAND_QUERY" == true ]]; then
      while IFS= read -r term; do
        [ -n "$term" ] && x_terms+=("$term")
      done < <(python3 "$SCRIPT_DIR/lib/expand_query.py" --query "$raw" --json 2>/dev/null \
               | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin).get("terms",[])))' 2>/dev/null || true)
    fi
    # add_cand: agrega {path,lineno} al JSON de candidatos con dedup por path|lineno.
    add_cand() {
      local cpath="$1" cline="$2" key="$1|$2"
      case " $seen_keys " in
        *" $key "*) return ;;
      esac
      seen_keys+="$key "
      [ "$first" = 1 ] && first=0 || cands+=","
      cands+="{\"path\":\"$(printf '%s' "$cpath" | sed 's/\\/\\\\/g; s/"/\\"/g')\",\"lineno\":$cline}"
      n=$((n+1))
    }
    while IFS="$SEP" read -r path lineno snip; do
      add_cand "$path" "$lineno"
    done <<<"$out"
    # X-candidatos: re-consulta FTS5 por cada término del diccionario. El gate
    # ≥1 token significativo se garantiza por construcción (la query OR usa los
    # tokens del término, igual que el runner del Paso 10); tope X_CAP declarado
    # (no calibrado) para que una re-consulta no domine el pool.
    if [ ${#x_terms[@]} -gt 0 ]; then
      local x_cap=100 x_hits=0
      for term in "${x_terms[@]}"; do
        tq="$(build_query "$term" or)"
        tq="${tq//\'/''}"
        [[ -n "$tq" ]] || continue
        tout="$(search_query "$tq" 2>/dev/null || true)"
        while IFS="$SEP" read -r path lineno snip; do
          [ -n "$path" ] || continue
          [ "$x_hits" -ge "$x_cap" ] && break 2
          add_cand "$path" "$lineno"
          x_hits=$((x_hits+1))
        done <<<"$tout"
      done
    fi
    cands+="]"
    [[ "$JSON_OUT" == true ]] && sel_args+=(--json)
    # X-query: la query expandida (original + términos X) alimenta S1 del selector.
    if [[ "$EXPAND_QUERY" == true && ${#x_terms[@]} -gt 0 ]]; then
      terms_json="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1:], ensure_ascii=False))' "${x_terms[@]}" 2>/dev/null || true)"
      [ -n "$terms_json" ] && sel_args+=(--terms "$terms_json")
    fi
    rc=0
    kno_arg=()
    if [ -n "${BUFFY_SELECTOR_KNO:-}" ]; then
      kno_arg=(--kno "$BUFFY_SELECTOR_KNO")
    fi
    sel_out="$(printf '%s' "$cands" | bash "$SCRIPT_DIR/buffy-selector.sh" \
        --query "$raw" --limit "$LIMIT" --repo "$REPO" "${kno_arg[@]}" "${sel_args[@]}" 2>/dev/null)" || rc=$?
    if [ "$rc" -eq 3 ]; then
      if [[ "$JSON_OUT" == true ]]; then
        printf '{"model":"M3","error":"ollama_unavailable","selected":[],"degraded":true}\n'
      else
        echo "⚠️  Ollama no disponible — selector M3 desactivado, búsqueda cruda:" >&2
        while IFS="$SEP" read -r path lineno snip; do
          printf '%s:%s: %s\n' "$path" "$lineno" "$snip"
        done <<<"$out"
      fi
      return 0
    fi
    printf '%s\n' "$sel_out"
    return 0
  fi
  while IFS="$SEP" read -r path lineno snip; do
    printf '%s:%s: %s\n' "$path" "$lineno" "$snip"
    n=$((n+1))
  done <<<"$out"
  if [[ $n -ge $LIMIT ]]; then
    echo "(límite $LIMIT — usa -l N para más)"
  fi
}

search_query() {
  local q="$1"
  sqlite3 -separator "$SEP" "$DB" \
    "SELECT path, lineno, snippet(docs, 2, '«', '»', '…', 40) FROM docs WHERE docs MATCH '$q' ORDER BY bm25(docs) LIMIT $LIMIT;"
}

case "$CMD" in
  reindex) do_reindex ;;
  update)  reindex_changed ;;
  stats)   do_stats ;;
  search)
    [[ -n "$QUERY" ]] || { sed -n '2,13p' "$0"; exit 1; }
    [[ -f "$DB" ]] || do_reindex >/dev/null
    reindex_changed
    search "$QUERY"
    ;;
esac

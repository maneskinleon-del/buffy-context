#!/usr/bin/env bash
# buffy-search.sh — búsqueda FTS5 sobre buffy-context (SESION, CHANGELOG, Knowledge...)
# Inspirado en session_search de Hermes Agent: índice SQLite FTS5, sin gastar tokens.
# Indexa una fila por línea (path + lineno en columnas UNINDEXED) → resultados estilo grep.
#
# Uso:
#   buffy-search.sh "consulta"        # busca, ordenado por relevancia (bm25)
#   buffy-search.sh -l 30 "consulta"  # más resultados
#   buffy-search.sh --update          # reindexa solo archivos cambiados (se hace solo antes de buscar)
#   buffy-search.sh --reindex         # reconstruye el índice completo
#   buffy-search.sh --stats           # estado del índice
#   BUFFY_REPO=/ruta/al/repo buffy-search.sh ...   # repo alternativo
set -euo pipefail

REPO="${BUFFY_REPO:-$HOME/buffy-context}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/buffy-search"
DB="$CACHE/search.db"
LIMIT=15
CMD="search"
SEP=$'\x1f'

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--limit) LIMIT="${2:?falta número}"; shift 2 ;;
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
    echo "index: $count archivo(s) actualizado(s)"
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

search() {
  local q raw="$1"
  q="$(awk '{ for (i=1; i<=NF; i++) { gsub(/"/, "\"\"", $i); printf "\"%s\"%s", $i, (i<NF ? " AND " : "") } }' <<<"$raw")"
  q="${q//\'/''}"
  [[ -n "$q" ]] || return 0
  local out n=0 path lineno snip
  out="$(search_query "$q")" || { echo "error de búsqueda: $raw" >&2; return 1; }
  if [[ -z "$out" ]]; then
    echo "Sin resultados para: $raw"
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

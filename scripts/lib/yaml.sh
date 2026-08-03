#!/usr/bin/env bash
# lib/yaml.sh — utilidades de parsing YAML-lite (solo escalares y listas simples).
# Compartidas entre skill-lint.sh y buffy-router.sh (sin duplicación).
#
# Convenciones del formato (subconjunto soportado):
#   clave: valor            → escalar simple (se quitan comillas envolventes)
#   clave:\n  - item\n  - item  → lista de items (hasta la próxima clave de nivel 1)
#
# Uso: source desde el script (los callers definen SCRIPT_DIR antes de sourcear):
#   source "$SCRIPT_DIR/lib/yaml.sh"

# yaml_val <archivo> <clave> — valor escalar simple (quita comillas envolventes)
yaml_val() {
  local v
  v=$(sed -n "s/^${2}:[[:space:]]*\\(.*\\)$/\\1/p" "$1" | head -1)
  v=${v#\"}; v=${v%\"}
  v=${v#\'}; v=${v%\'}
  printf '%s' "$v"
}

# yaml_items <archivo> <clave> — nº de items '- ' de la lista <clave>
yaml_items() {
  awk -v k="$2" 'index($0,k":")==1 {f=1; next} f && /^[a-zA-Z_0-9]+:/ {f=0} f && /^[[:space:]]*- / {n++} END {print n+0}' "$1"
}

# yaml_list <archivo> <clave> — items de la lista <clave> unidos por '|' (regex listo).
#   Soporta items con espacios ("free fire"); vacío si no hay lista.
yaml_list() {
  awk -v k="$2" '
    index($0, k ":") == 1 { f = 1; next }
    f && /^[a-zA-Z_0-9]+:/ { exit }
    f && /^[[:space:]]*- / {
      v = $0; sub(/^[[:space:]]*- /, "", v)
      gsub(/^["'"'"']|["'"'"']$/, "", v)
      if (out) out = out "|"
      out = out v
    }
    END { print out }
  ' "$1"
}

#!/usr/bin/env bash
# resolve-path.sh — fuente ÚNICA de la regla de resolución de archivos de
# configuración con override .local (C4-B, decisión del operador 2026-09-29:
# Patrón B — los consumidores NUNCA implementan la regla por su cuenta).
#
# Regla (semántica del .local de industria — .env/.env.local, settings.local):
#   1. X.local.<ext>  — si EXISTE: AUTORIDAD TOTAL, se devuelve tal cual.
#      Aunque esté vacío o corrupto: el usuario lo creó, es su responsabilidad
#      mantenerlo. El fallback silencioso a base ocultaría el error — patrón
#      anti-falso-éxito de la casa (SIGNAL-STATE-COUPLING-FAILURES.md).
#   2. X              — si no hay override: el base (siempre existe: es
#      tracked y genérico, válido como instancia).
#   3. Si no existe ni base: se devuelve la ruta del base de todos modos con
#      exit 1 — el CONSUMIDOR decide qué significa ausencia (contrato propio:
#      doctor=error, lint=error, router=omitir). El helper solo resuelve.
#
# El punto de inserción del override es ANTES de la última extensión:
#   ai-context/INFO-core.md → ai-context/INFO-core.local.md
#   .agents/AGENTS.md       → .agents/AGENTS.local.md
#
# Uso:
#   bash scripts/lib/resolve-path.sh ai-context/INFO-core.md
#   bash scripts/lib/resolve-path.sh --repo /otro/checkout ai-context/AGENTS.md
#   bash scripts/lib/resolve-path.sh --check ai-context/INFO-core.md
#                                      → imprime además [override|base|missing] en stderr
#
# Salida: la ruta EFECTIVA resuelta (relativa al repo) por stdout. Exit 0 si
# la ruta resuelta existe; exit 1 si no existe (aun así imprime la ruta).
# Consumidores Python: subprocess.run([...], capture_output=True, text=True).

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERBOSE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)  REPO_DIR="$(cd "$2" && pwd)"; shift 2 ;;
    --check) VERBOSE=true; shift ;;
    -h|--help) sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) break ;;
  esac
done

[ "$#" -eq 1 ] || { echo "uso: resolve-path.sh [--repo DIR] [--check] <ruta-relativa>" >&2; exit 2; }
REL="$1"
[ -n "$REL" ] || { echo "ruta vacía" >&2; exit 2; }

# X.local.<ext>: inserta ".local" antes de la última extensión
dir="$(dirname "$REL")"
base="$(basename "$REL")"
name="${base%.*}"
ext="${base##*.}"
if [ "$name" = "$base" ]; then   # sin extensión → sufijo directo
  OVERRIDE="$dir/${name}.local"
else
  OVERRIDE="$dir/${name}.local.${ext}"
fi

if [ -f "$REPO_DIR/$OVERRIDE" ]; then
  RESOLVED="$OVERRIDE"; KIND="override"
elif [ -f "$REPO_DIR/$REL" ]; then
  RESOLVED="$REL"; KIND="base"
else
  RESOLVED="$REL"; KIND="missing"
fi

if [ "$VERBOSE" = true ]; then
  echo "[$KIND] $RESOLVED" >&2
fi
echo "$RESOLVED"
[ "$KIND" != "missing" ]

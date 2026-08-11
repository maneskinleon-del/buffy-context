#!/usr/bin/env bash
# buffy-memory-sync.sh — Puente PC ↔ teléfono para la memoria curada (P0).
#
# La memoria curada es perfil-local por diseño (~/.buffy/memories) — no viaja
# entre dispositivos. Este script la sincroniza vía el repo buffy-context:
# las copias versionadas viven en <repo>/ai-context/memories/ y viajan por git.
#
#   sync status                    → compara local vs repo (shas + conflicto)
#   sync push  [--force]           → copia local → repo, commit + push git
#   sync pull  [--force]           → git pull + copia repo → local
#
# Guard de drift (filosofía Hermes: nunca sobrescribir lo que no entendemos):
# el estado POR DISPOSITIVO vive en $MEM_DIR/.sync-state (perfil-local, NO se
# versiona — no genera ruido git). Registra el último sha que ESE dispositivo
# sincronizó. Así cada máquina sabe qué vio por última vez, y un push del PC
# no borra la marca de tu dispositivo:
#
#   · push:  si repo != mi_último_sync  Y  local != repo  → alguien más tocó
#            el repo desde que YO sincronicé → conflicto (no pisar).
#   · pull:  si local != mi_último_sync  Y  local != repo → tengo cambios
#            locales sin sincronizar → conflicto (no sobrescribir).
#   · primer sync sin marca propia y contenidos distintos → aviso preventivo.
#
# El repo solo contiene CONTENIDO (ai-context/memories/MEMORY.md + USER.md):
# el estado es conocimiento local de cada máquina y nunca viaja por git.
#
# Env: BUFFY_MEM_DIR (default ~/.buffy/memories) · BUFFY_SYNC_DIR
#      (default: repo/ai-context/memories junto a este script) ·
#      BUFFY_SYNC_HOST (identificador del dispositivo, default: hostname).
# Exit: 0 ok · 1 conflicto/error · 2 uso inválido.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MEM_DIR="${BUFFY_MEM_DIR:-$HOME/.buffy/memories}"
SYNC_DIR="${BUFFY_SYNC_DIR:-$(cd "$SCRIPT_DIR/../.." && pwd)/ai-context/memories}"
mkdir -p "$SYNC_DIR"
# El repo git es SIEMPRE el ancestro de SYNC_DIR: en producción buffy-context,
# en tests/sandbox el repo aislado. Ni un archivo fuera de SYNC_DIR se toca.
REPO_ROOT="$(cd "$SYNC_DIR/../.." && pwd)"
mkdir -p "$MEM_DIR"
STATE="$MEM_DIR/.sync-state"
STORES=(memory user)
FILES=(MEMORY.md USER.md)
GIT="${BUFFY_SYNC_GIT:-git}"
HOST="${BUFFY_SYNC_HOST:-$(hostname 2>/dev/null || echo unknown)}"

USAGE="uso: buffy-memory-sync.sh status|push|pull [--force]"

sha() { sha256sum "$1" 2>/dev/null | awk '{print $1}'; }

json_get() {  # json_get <json> <path...> → valor ("" si no existe)
  python3 -c '
import json,sys
try: d=json.loads(sys.argv[1])
except Exception: sys.exit(0)
for k in sys.argv[2:]:
    if not isinstance(d,dict) or k not in d: sys.exit(0)
    d=d[k]
print(d if isinstance(d,str) else json.dumps(d))
' "$1" "${@:2}"
}

# ── Estado per-host ─────────────────────────────────────────────────────────
# Formato: {"hosts": {"<host>": {"memory": sha, "user": sha}}, "updated": ts}

state_set() {  # state_set <store> <sha>
  python3 -c '
import json,sys,time
state_file,host,store,sha=sys.argv[1],sys.argv[2],sys.argv[3],sys.argv[4]
try: d=json.load(open(state_file))
except Exception: d={}
d.setdefault("hosts",{}).setdefault(host,{})[store]=sha
d["updated"]=time.strftime("%Y-%m-%dT%H:%M:%S%z")
json.dump(d,open(state_file,"w"),indent=1)
' "$STATE" "$HOST" "$1" "$2"
}

my_last() {  # my_last <store> → sha que YO sincronicé ("" si nunca)
  json_get "$(cat "$STATE" 2>/dev/null || echo '{}')" hosts "$HOST" "$1"
}

file_pair() {  # file_pair <dir> → "sha_memory sha_user" (vacíos si no existen)
  local sha_m="" sha_u=""
  [[ -f "$1/MEMORY.md" ]] && sha_m=$(sha "$1/MEMORY.md")
  [[ -f "$1/USER.md" ]] && sha_u=$(sha "$1/USER.md")
  echo "$sha_m $sha_u"
}

status() {
  echo "== memoria curada: local vs repo =="
  echo "host:  $HOST"
  echo "local: $MEM_DIR"
  echo "repo:  $SYNC_DIR"
  echo
  local -a L R
  L=($(file_pair "$MEM_DIR"))
  R=($(file_pair "$SYNC_DIR"))
  local -i conflicto=0
  for i in 0 1; do
    local name="${STORES[$i]}"
    local l="${L[$i]:-—}" r="${R[$i]:-—}" s=$(my_last "$name")
    printf "%-8s local %-12s repo %-12s misync %s\n" "$name" "${l:0:12}" "${r:0:12}" "${s:0:12}"
    if [[ -n "$s" ]]; then
      if [[ -n "$l" && "$l" != "$s" && -n "$r" && "$r" != "$l" ]]; then
        printf "  ⚠ %s: cambios LOCALES sin sincronizar Y repo distinto\n" "$name"; conflicto=1
      elif [[ -n "$r" && "$r" != "$s" && -n "$l" && "$l" != "$r" ]]; then
        printf "  ⚠ %s: el REPO cambió desde mi último sync\n" "$name"; conflicto=1
      fi
    elif [[ -n "$l" && -n "$r" && "$l" != "$r" ]]; then
      printf "  ⚠ %s: nunca sincronizado y contenidos distintos\n" "$name"; conflicto=1
    fi
  done
  echo
  if (( conflicto )); then echo "estado: CONFLICTO — decidí (sync pull/push --force)"; return 1; fi
  echo "estado: ok"
}

do_push() {
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true
  local -a L R
  L=($(file_pair "$MEM_DIR"))
  R=($(file_pair "$SYNC_DIR"))
  mkdir -p "$SYNC_DIR"

  # Primero me entero de lo último del remoto (GitHub): el guard de drift solo
  # es fiable si comparo contra el repo ACTUAL, no el de la última vez.
  if ( cd "$REPO_ROOT" && $GIT pull -q --ff-only 2>/dev/null ); then
    R=($(file_pair "$SYNC_DIR"))
  fi

  local -a to_commit=()
  for i in 0 1; do
    local name="${STORES[$i]}" f="${FILES[$i]}"
    local l="${L[$i]:-""}" r="${R[$i]:-""}" s=$(my_last "$name")
    [[ -z "$l" ]] && { echo "⚠ $name: no existe en local — nada que pushear"; continue; }
    [[ "$l" == "$r" ]] && continue
    if ! $force; then
      if [[ -n "$s" && -n "$r" && "$r" != "$s" && "$r" != "$l" ]]; then
        echo "✗ CONFLICTO en $name: el repo (sha ${r:0:8}) cambió desde mi último sync" >&2
        echo "  (¿el PC escribió mientras tanto?). Decide:" >&2
        echo "    · el OTRO lado manda → buffy-memory.sh sync pull --force" >&2
        echo "    · TU memoria manda  → buffy-memory.sh sync push --force" >&2
        return 1
      fi
      if [[ -z "$s" && -n "$r" && "$r" != "$l" ]]; then
        echo "✗ PRIMER SYNC en este host y el repo ya tiene $name" >&2
        echo "  (¿memoria del PC?). No copio encima sin decisión: push --force" >&2
        return 1
      fi
    fi
    if [[ -n "$l" && "$l" != "$r" ]]; then
      cp "$MEM_DIR/$f" "$SYNC_DIR/$f"
      to_commit+=("$f")
      echo "✔ $name: local → repo"
    fi
  done

  if [[ ${#to_commit[@]} -eq 0 ]]; then
    echo "ya sincronizado (sin cambios)"
    return 0
  fi
  for i in 0 1; do
    local name="${STORES[$i]}" f="${FILES[$i]}" new
    new=$(sha "$SYNC_DIR/$f" 2>/dev/null || true)
    [[ -n "$new" ]] && state_set "$name" "$new"
  done

  local add_args=()
  for f in "${to_commit[@]}"; do add_args+=(ai-context/memories/$f); done
  ( cd "$REPO_ROOT" && $GIT add "${add_args[@]}" >/dev/null 2>&1 && \
    $GIT commit -q -m "docs(memory): sync memoria curada desde $HOST" >/dev/null 2>&1 )
  if ( cd "$REPO_ROOT" && ! $GIT push -q 2>/dev/null ); then
    echo "⚠ commit local hecho pero git push falló (¿sin red?) — pushea luego" >&2
  else
    echo "✔ commiteado y pusheado"
  fi
}

do_pull() {
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true
  local -a L R
  L=($(file_pair "$MEM_DIR"))
  R=($(file_pair "$SYNC_DIR"))

  if [[ ! -d "$SYNC_DIR" ]]; then
    echo "✗ no hay memoria versionada en el repo ($SYNC_DIR)" >&2
    echo "  → usa sync push en el dispositivo que ya tiene memoria" >&2
    return 1
  fi
  if ( cd "$REPO_ROOT" && $GIT pull -q --ff-only 2>/dev/null ); then
    R=($(file_pair "$SYNC_DIR"))
  else
    echo "⚠ git pull falló (¿sin red?) — uso lo que hay en el repo local" >&2
  fi

  mkdir -p "$MEM_DIR"
  local changed=false
  for i in 0 1; do
    local name="${STORES[$i]}" f="${FILES[$i]}"
    local l="${L[$i]:-""}" r="${R[$i]:-""}" s=$(my_last "$name")
    [[ -z "$r" ]] && continue
    [[ "$l" == "$r" ]] && continue
    if ! $force; then
      if [[ -n "$s" && -n "$l" && "$l" != "$s" && "$l" != "$r" ]]; then
        echo "✗ CONFLICTO en $name: cambios LOCALES (sha ${l:0:8}) sin sincronizar" >&2
        echo "  · tu local manda       → buffy-memory.sh sync push --force" >&2
        echo "  · el repo manda        → buffy-memory.sh sync pull --force" >&2
        return 1
      fi
      if [[ -z "$s" && -n "$l" && "$l" != "$r" ]]; then
        echo "✗ PRIMER SYNC en este host y tu local ya tiene $name" >&2
        echo "  (no sobrescribo sin decisión: pull --force)" >&2
        return 1
      fi
    fi
    cp "$SYNC_DIR/$f" "$MEM_DIR/$f"
    chmod 600 "$MEM_DIR/$f"
    echo "✔ $name: repo → local"
    state_set "$name" "$r"
    changed=true
  done
  [[ "$changed" == false ]] && echo "ya sincronizado (sin cambios)" || true
  # El estado es LOCAL ($MEM_DIR/.sync-state) — el pull NO commitea nada:
  # el repo solo contiene contenido, y el estado per-device no viaja por git.
}

CMD="${1:-}"
FORCE="${2:-}"
case "$CMD" in
  status) status ;;
  push)   do_push "$FORCE" ;;
  pull)   do_pull "$FORCE" ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac
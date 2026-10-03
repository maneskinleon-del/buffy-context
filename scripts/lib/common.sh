#!/usr/bin/env bash
# lib/common.sh — configuración compartida del ecosistema buffy-context (C2, opt-in).
#
# BUFFY_HOME: raíz alternativa para el ESTADO GENERADO de buffy (ai-context/ + SNAPSHOT.md).
#   - NO definido → se usa $HOME (comportamiento actual, cero cambios).
#   - Definido    → se usa esa ruta como raíz del estado generado (instalaciones
#     alternativas: otro usuario, contenedor, ruta montada, etc.).
#
# ALCANCE (deliberado): BUFFY_HOME solo redirige el estado generado. El escaneo de
# entorno del usuario ($HOME/proyectos, $HOME/scripts, $HOME/.agents/skills, historial)
# sigue usando $HOME real — es el entorno del usuario, no la instalación de buffy.
#
# Uso: source desde el script (los callers definen SCRIPT_DIR antes de sourcear):
#   source "$SCRIPT_DIR/lib/common.sh"
#
# Helpers:
#   buffy_home        → raíz del estado generado (${BUFFY_HOME:-$HOME})
#   buffy_ai_context  → $BUFFY_HOME/ai-context   (dir de SNAPSHOT.md y estado)
#   buffy_snapshot    → $BUFFY_HOME/ai-context/SNAPSHOT.md
#   buffy_tmpdir      → dir temporal PRIVADO del proceso (mktemp -d + trap)

BUFFY_HOME="${BUFFY_HOME:-$HOME}"
BUFFY_HOME="${BUFFY_HOME%/}"   # normaliza trailing slash (BUFFY_HOME=/tmp/x/ → /tmp/x)

buffy_home() {
  printf '%s' "$BUFFY_HOME"
}

buffy_ai_context() {
  printf '%s' "$BUFFY_HOME/ai-context"
}

buffy_snapshot() {
  printf '%s' "$BUFFY_HOME/ai-context/SNAPSHOT.md"
}

# ── buffy_tmpdir ────────────────────────────────────────────────────────────
# Un dir temporal privado por proceso, con limpieza al salir.
#
# Por qué existe (no es "por si acaso"): con rutas /tmp hardcodeadas, en un
# entorno sin /tmp escribible (Termux, sandbox) el redirect 2>/tmp/x.err falla y
# el RC real del comando se pierde — buffy-selector.sh devolvía RC=1 en vez del
# RC=3 documentado (ollama_unavailable), y el `cat` del .err se comía el
# diagnóstico. Además los nombres fijos (/tmp/buffy-selector.err) permiten
# symlink de otro usuario en sistemas multiusuario.
#
# buffy_tmpdir NO imprime la ruta: crea el dir y lo deja en la global
# $BUFFY_TMPDIR, con la limpieza registrada en el trap EXIT del SHELL LLAMANTE
# (encadenada con el trap previo, no pisándolo). Falla con rc=1 y mensaje
# explícito si no hay dónde crear el temporal.
#
# Uso (sin command substitution — si se captura con $( ), el trap se registra
# en el subshell y el dir se borra al terminar la sustitución, antes de usarlo):
#   buffy_tmpdir || exit 2
#   ERR_FILE="$BUFFY_TMPDIR/motor.err"
BUFFY_TMPDIR=""
_BUFFY_PREV_EXIT_TRAP=""

buffy_tmpdir() {
  # Idempotente: reutiliza el mismo dir dentro del proceso.
  if [ -n "$BUFFY_TMPDIR" ] && [ -d "$BUFFY_TMPDIR" ]; then
    return 0
  fi
  BUFFY_TMPDIR="$(mktemp -d "${TMPDIR:-/tmp}/buffy.XXXXXX" 2>/dev/null)" || BUFFY_TMPDIR=""
  if [ -z "$BUFFY_TMPDIR" ] || [ ! -d "$BUFFY_TMPDIR" ]; then
    echo "buffy: no se pudo crear un directorio temporal (TMPDIR=${TMPDIR:-/tmp})" >&2
    BUFFY_TMPDIR=""
    return 1
  fi
  # Guardar el trap EXIT previo la PRIMERA vez (encadenar, no pisar).
  if [ -z "$_BUFFY_PREV_EXIT_TRAP" ]; then
    _BUFFY_PREV_EXIT_TRAP="$(trap -p EXIT 2>/dev/null)"
    trap 'buffy_tmpdir_cleanup' EXIT
  fi
  return 0
}

buffy_tmpdir_cleanup() {
  if [ -n "${BUFFY_TMPDIR:-}" ] && [ -d "$BUFFY_TMPDIR" ]; then
    rm -rf -- "$BUFFY_TMPDIR"
  fi
  BUFFY_TMPDIR=""
  # Re-disparar el trap que hubiera antes de buffy_tmpdir.
  if [ -n "${_BUFFY_PREV_EXIT_TRAP:-}" ]; then
    eval "$_BUFFY_PREV_EXIT_TRAP"
  fi
}

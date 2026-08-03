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

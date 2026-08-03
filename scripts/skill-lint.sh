#!/usr/bin/env bash
# skill-lint.sh — valida los manifiestos skill.yaml de .agents/skills/ (prioridad B2).
#
# El manifest machine-readable complementa al SKILL.md (documentación humana):
#   id       → DEBE ser igual al nombre del directorio (.agents/skills/<id>/)
#   name     → nombre legible (reportes/logs)
#   version  → semver (X.Y.Z)
#   entry    → archivo principal relativo al directorio (normalmente SKILL.md)
#   safe     → true/false: true = AUTO_SAFE (ejecutable sin confirmación humana)
#   triggers → señales textuales de activación (las usa buffy-router.sh)
#   (opcionales: description, platforms, capabilities, dependencies, requires_sudo)
#
# Uso:
#   bash scripts/skill-lint.sh                → valida el repo actual
#   bash scripts/skill-lint.sh --repo <dir>   → valida otro checkout (tests/sandbox/CI)
#   bash scripts/skill-lint.sh --require-all  → además falla si alguna skill no tiene manifest
#   bash scripts/skill-lint.sh --json         → resumen JSON a stdout (stderr limpio)
#   bash scripts/skill-lint.sh --help
#
# Exit: 0 sano · 1 errores de manifiesto (o cobertura incompleta con --require-all) · 2 uso.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/yaml.sh
source "$SCRIPT_DIR/lib/yaml.sh"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_DIR/.agents/skills"
REQUIRE_ALL=false
JSON=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) REPO_DIR="$(cd "$2" && pwd)" || exit 2; SKILLS_DIR="$REPO_DIR/.agents/skills"; shift 2 ;;
    --require-all) REQUIRE_ALL=true; shift ;;
    --json) JSON=true; shift ;;
    --help)
      sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "skill-lint: opción desconocida: $1 (usa --help)" >&2
      exit 2
      ;;
  esac
done

[ -d "$SKILLS_DIR" ] || { echo "skill-lint: no existe $SKILLS_DIR" >&2; exit 2; }

ERRORS=0
WARNINGS=0
N_MANIFESTS=0

err() {  # <msg> — cuenta y muestra (solo en modo humano)
  ERRORS=$((ERRORS+1))
  [ "$JSON" = true ] || echo "  ERR  $1"
}

# ── validar un directorio de skill ──
validate_manifest() {
  local d="$1" mf="$d/skill.yaml" before=$ERRORS
  local id name version entry safe fm_name rel
  [ -f "$mf" ] || { WARNINGS=$((WARNINGS+1)); return; }
  N_MANIFESTS=$((N_MANIFESTS+1))

  id=$(yaml_val "$mf" id)
  name=$(yaml_val "$mf" name)
  version=$(yaml_val "$mf" version)
  entry=$(yaml_val "$mf" entry)
  safe=$(yaml_val "$mf" safe)
  rel="${d#"$REPO_DIR"/}"

  if [ "$id" != "$(basename "$d")" ]; then
    err "$rel: id '$id' != nombre del directorio"
  fi
  if [ -z "$name" ]; then
    err "$rel: falta 'name'"
  fi
  if ! printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    err "$rel: version '$version' no es semver (X.Y.Z)"
  fi
  if [ -z "$entry" ] || [ ! -e "$d/$entry" ]; then
    err "$rel: entry '$entry' no existe en el directorio"
  fi
  if [ "$safe" != true ] && [ "$safe" != false ]; then
    err "$rel: safe debe ser true|false (es '$safe')"
  fi
  if [ "$(yaml_items "$mf" triggers)" -lt 1 ]; then
    err "$rel: falta 'triggers' (lista con al menos un item)"
  fi
  if [ -f "$d/SKILL.md" ]; then
    fm_name=$(sed -n '1,8p' "$d/SKILL.md" | sed -n 's/^name:[[:space:]]*//p' | head -1)
    if [ -n "$fm_name" ] && [ "$fm_name" != "$id" ]; then
      err "$rel: front-matter de SKILL.md (name: $fm_name) != id ($id)"
    fi
  fi

  if [ "$JSON" = false ] && [ "$ERRORS" -eq "$before" ]; then
    echo "  OK   $rel (id, entry, safe, triggers)"
  fi
}

# ── escanear skills (dirs con SKILL.md y/o skill.yaml) ──
N_SKILLS=0
while IFS= read -r d; do
  [ -f "$d/SKILL.md" ] || [ -f "$d/skill.yaml" ] || continue
  N_SKILLS=$((N_SKILLS+1))
  validate_manifest "$d"
done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

# ── resumen ──
COVERAGE=0
[ "$N_SKILLS" -gt 0 ] && COVERAGE=$((N_MANIFESTS * 100 / N_SKILLS))

if [ "$JSON" = true ]; then
  python3 - "$REPO_DIR" "$N_SKILLS" "$N_MANIFESTS" "$ERRORS" "$WARNINGS" <<'PY'
import json, sys
repo, skills, mans, errs, warns = sys.argv[1:6]
print(json.dumps({
    "repo": repo,
    "skills": int(skills),
    "manifests": int(mans),
    "errors": int(errs),
    "warnings": int(warns),
    "healthy": int(errs) == 0,
}))
PY
else
  echo
  echo "skill-lint: manifestos $N_MANIFESTS/$N_SKILLS (${COVERAGE}%) · errores $ERRORS · skills sin manifest: $WARNINGS"
  [ "$REQUIRE_ALL" = true ] && echo "  (--require-all activo: TODAS las skills deben tener skill.yaml)"
fi

[ "$ERRORS" -gt 0 ] && exit 1
[ "$REQUIRE_ALL" = true ] && [ "$N_MANIFESTS" -lt "$N_SKILLS" ] && exit 1
exit 0

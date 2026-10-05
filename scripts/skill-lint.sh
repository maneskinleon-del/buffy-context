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
# Dos capas de validación:
#   1. Forma    — yaml_val/yaml_items (sed/awk, lib/yaml.sh): id, version, entry, safe, triggers.
#   2. Sintaxis — parseo YAML real con PyYAML. Sin esto el linter aprueba YAML inválido:
#      seis manifests con comillas dobles anidadas sin escapar pasaban la capa 1 y
#      rompían a todo consumidor que parsea YAML de verdad (Claude Code, OpenCode,
#      loaders de terceros) — para un repo cuyo valor es la portabilidad, eso es 6/44.
#      Si PyYAML no está instalado NO se da falso verde: se avisa y --json reporta
#      yaml_validated=false.
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
  local id name version entry safe origin fm_name rel
  [ -f "$mf" ] || { WARNINGS=$((WARNINGS+1)); return; }
  N_MANIFESTS=$((N_MANIFESTS+1))

  id=$(yaml_val "$mf" id)
  name=$(yaml_val "$mf" name)
  version=$(yaml_val "$mf" version)
  entry=$(yaml_val "$mf" entry)
  safe=$(yaml_val "$mf" safe)
  origin=$(yaml_val "$mf" origin)
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
  # D2.3: procedencia obligatoria. No por Taste — 5 skills del repo tienen el
  # MISMO nombre que skills de comunidad (vercel-react-best-practices, vite,
  # context7, tailwind-design-system, typescript-advanced-types). La resolución
  # de skills es por `name`, así que sin `origin` no hay forma de saber si lo
  # que se cargó es la copia del repo o la de arriba. Sin campo, "vendorizado"
  # es un hecho sin contrato.
  if [ -z "$origin" ]; then
    err "$rel: falta 'origin' (local|upstream) — procedencia obligatoria (D2.3)"
  elif [ "$origin" != local ] && [ "$origin" != upstream ]; then
    err "$rel: origin '$origin' no es válido (local|upstream)"
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
    echo "  OK   $rel (id, entry, origin, safe, triggers)"
  fi
}

# ── escanear skills (dirs con SKILL.md y/o skill.yaml) ──
N_SKILLS=0
# TEST-ONLY: BUFFY_SKILL_LINT_FORCE_ENUM_FAIL=1 injects a deterministic
# enumeration failure for regression tests. Not a user-facing setting.
# It skips the scan so the guard below can be exercised without depending
# on host /dev/fd availability.
if [ "${BUFFY_SKILL_LINT_FORCE_ENUM_FAIL:-}" != 1 ]; then
  while IFS= read -r d; do
    [ -f "$d/SKILL.md" ] || [ -f "$d/skill.yaml" ] || continue
    N_SKILLS=$((N_SKILLS+1))
    validate_manifest "$d"
  done < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi

# Guard against false-green: if the skills directory is non-empty but the scan
# produced zero skills, the enumeration mechanism failed (e.g. process
# substitution unavailable because /dev/fd is missing). A failed check must
# never report healthy=true with skills=0/errors=0.
if [ "$N_SKILLS" -eq 0 ]; then
  _n_dirs=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  _n_dirs=$((_n_dirs + 0))   # normalize whitespace from wc
  if [ "$_n_dirs" -gt 0 ]; then
    err "fallo de enumeración de skills: directorio tiene ${_n_dirs} entradas pero el escaneo devolvió 0"
  fi
fi

# ── capa 2: sintaxis YAML real (PyYAML) ──
# Sin esto la capa 1 (sed/awk) aprueba YAML que ningún parser real puede cargar.
YAML_VALIDATED=false
if python3 -c 'import yaml' >/dev/null 2>&1; then
  YAML_VALIDATED=true
  # Capture via command substitution (does not require process substitution /
  # /dev/fd) so a failure here cannot silently skip validation of manifests.
  _yaml_errs=$(python3 - "$REPO_DIR" "$SKILLS_DIR" <<'PY' 2>/dev/null || true
import glob, os, sys, yaml
repo, skills_dir = sys.argv[1], sys.argv[2]
for f in sorted(glob.glob(os.path.join(skills_dir, '*', 'skill.yaml'))):
    rel = os.path.relpath(f, repo)
    try:
        with open(f, encoding='utf-8') as fh:
            yaml.safe_load(fh)
    except Exception as e:
        print("%s: YAML inválido — %s" % (rel, str(e).split('\n')[0]))
PY
)
  if [ -n "$_yaml_errs" ]; then
    while IFS= read -r bad; do
      [ -n "$bad" ] || continue
      err "$bad"
    done <<< "$_yaml_errs"
  fi
else
  # Degradación honesta: sin PyYAML no se puede afirmar que los manifests cargan.
  WARNINGS=$((WARNINGS+1))
  [ "$JSON" = true ] || echo "  WARN  PyYAML no disponible: sintaxis YAML NO validada (yaml_validated=false)"
fi

# ── resumen ──
COVERAGE=0
[ "$N_SKILLS" -gt 0 ] && COVERAGE=$((N_MANIFESTS * 100 / N_SKILLS))

if [ "$JSON" = true ]; then
  python3 - "$REPO_DIR" "$N_SKILLS" "$N_MANIFESTS" "$ERRORS" "$WARNINGS" "$YAML_VALIDATED" <<'PY'
import json, sys
repo, skills, mans, errs, warns, yv = sys.argv[1:7]
print(json.dumps({
    "repo": repo,
    "skills": int(skills),
    "manifests": int(mans),
    "errors": int(errs),
    "warnings": int(warns),
    "healthy": int(errs) == 0,
    # False = no se parseó con PyYAML: 'healthy' no cubre la capa de sintaxis.
    "yaml_validated": yv == "true",
}))
PY
else
  echo
  echo "skill-lint: manifestos $N_MANIFESTS/$N_SKILLS (${COVERAGE}%) · errores $ERRORS · skills sin manifest: $WARNINGS · yaml parseado: $YAML_VALIDATED"
  [ "$REQUIRE_ALL" = true ] && echo "  (--require-all activo: TODAS las skills deben tener skill.yaml)"
fi

[ "$ERRORS" -gt 0 ] && exit 1
[ "$REQUIRE_ALL" = true ] && [ "$N_MANIFESTS" -lt "$N_SKILLS" ] && exit 1
exit 0

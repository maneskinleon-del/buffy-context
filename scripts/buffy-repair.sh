#!/usr/bin/env bash
# buffy-repair.sh — Aplica fixes clasificados del doctor al ecosistema buffy-context.
# Ciclo: doctor --json → clasifica (AUTO_SAFE / REVIEW_REQUIRED) → aplica → verifica.
#
# Uso:
#   buffy-repair.sh               → Plan (dry-run, no aplica nada)
#   buffy-repair.sh --auto        → Aplica solo fixes AUTO_SAFE y verifica
#   buffy-repair.sh --fix NOMBRE  → Aplica UN fix por nombre (solo si es AUTO_SAFE)
#   buffy-repair.sh --json        → Resultado en JSON (combina con --auto)
#   buffy-repair.sh --repo RUTA   → Auditar un checkout específico
#   buffy-repair.sh --help        → Esta ayuda
#
# Exit codes:
#   0 → Sin drift, o todo lo AUTO_SAFE aplicado y verificado
#   1 → Quedan items REVIEW_REQUIRED (requieren revisión humana)
#   2 → Error de uso o fallo al ejecutar
#
# Creado: 2026-08-03

# ── Resolver repo (mismo patrón que buffy-doctor.sh) ──────
SCRIPT_SRC="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_SRC="$(readlink -f "$SCRIPT_SRC" 2>/dev/null || echo "$SCRIPT_SRC")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" && pwd)"
REPO_DIR="${SCRIPT_DIR%/scripts}"
DOCTOR="$SCRIPT_DIR/buffy-doctor.sh"
AUTO=false
JSON_OUT=false
FIX_ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_DIR="$2"; shift 2 ;;
    --auto) AUTO=true; shift ;;
    --fix) FIX_ONLY="$2"; shift 2 ;;
    --json) JSON_OUT=true; shift ;;
    -h|--help)
      sed -n '2,16p' "$SCRIPT_SRC" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "❌ Opción desconocida: $1" >&2; exit 2 ;;
  esac
done

if [ ! -f "$DOCTOR" ]; then
  echo "❌ No encuentro buffy-doctor.sh en $DOCTOR" >&2
  exit 2
fi

say() { [ "$JSON_OUT" = true ] || echo "$1"; }

# ── Ejecutar doctor y extraer items accionables (fix no vacío) ──
DOC_JSON="$(bash "$DOCTOR" --json --repo "$REPO_DIR" 2>/dev/null || true)"
if ! echo "$DOC_JSON" | python3 -m json.tool >/dev/null 2>&1; then
  echo "❌ buffy-doctor --json no devolvió JSON válido" >&2
  exit 2
fi
if ! echo "$DOC_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
exit(1 if any(i.get("id") == "INVALID_REPO" for i in d.get("items", [])) else 0)
'; then
  echo "❌ No es un checkout de buffy-context: $REPO_DIR (buffy-doctor lo rechazó)" >&2
  exit 2
fi

# TSV por item accionable: fix<TAB>safe<TAB>target<TAB>id<TAB>message
ACTIONS="$(printf '%s' "$DOC_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
out = []
for i in d.get("items", []):
    fix = i.get("fix", "")
    if fix:
        out.append("\t".join([fix, "true" if i.get("safe") else "false", i.get("target", ""), i.get("id", ""), i.get("message", "")]))
print("\n".join(out))
')"

# ── Clasificar (dedupe por fix+target) ────────────────────
declare -A SEEN=()
SAFE_ACTIONS=()
REVIEW_ACTIONS=()
while IFS=$'\t' read -r fix safe target id msg; do
  [ -z "$fix" ] && continue
  key="$fix|$target"
  [ -n "${SEEN[$key]:-}" ] && continue
  SEEN[$key]=1
  if [ "$safe" = true ]; then
    SAFE_ACTIONS+=("$fix|$target|$msg")
  else
    REVIEW_ACTIONS+=("$fix|$target|$msg")
  fi
done <<< "$ACTIONS"

# ── Fixes AUTO_SAFE ───────────────────────────────────────
fix_regenerate_snapshot() { # regenerar SNAPSHOT.md vía buffy-context.sh
  (cd "$REPO_DIR" && bash scripts/buffy-context.sh >/dev/null 2>&1)
  [ -s "$HOME/ai-context/SNAPSHOT.md" ] || [ -s "$REPO_DIR/ai-context/SNAPSHOT.md" ]
}
fix_create_ai_context_dir() { # crear ~/ai-context
  mkdir -p "$1"
}
fix_create_skill_dir() { # crear estructura de skill faltante (dir + SKILL.md plantilla)
  # Ojo: NO usar `local skill="$1" dir="...$skill..."` — en un solo local todas las
  # expansiones usan el valor VIEJO de $skill (vacío) → dir quedaba en .agents/skills/.
  local skill="$1"
  local dir="$REPO_DIR/.agents/skills/$skill"
  mkdir -p "$dir"
  if [ ! -f "$dir/SKILL.md" ]; then
    cat > "$dir/SKILL.md" <<SKILLEOF
# $skill

> Plantilla generada por buffy-repair.sh — completar descripción y uso.

## Cuándo usar
TODO

## Cómo usar
TODO
SKILLEOF
  fi
}
fix_chmod_plus_x() { # hacer ejecutable un script
  chmod +x "$1" 2>/dev/null
}

apply_fix() { # apply_fix <fix> <target> → 0 ok / 1 fallo
  case "$1" in
    regenerate_snapshot)   fix_regenerate_snapshot ;;
    create_ai_context_dir) fix_create_ai_context_dir "$2" ;;
    create_skill_dir)      fix_create_skill_dir "$2" ;;
    chmod_plus_x)          fix_chmod_plus_x "$2" ;;
    *) echo "  ⏭️  $1 → no aplicable automáticamente"; return 1 ;;
  esac
}

review_guidance() { # review_guidance <fix> <target>
  case "$1" in
    create_context_file)   echo "   → crea manualmente $REPO_DIR/ai-context/$2 (contenido según LOAD_CONTEXT.md)" ;;
    create_knowledge_file) echo "   → crea manualmente $REPO_DIR/$2 (contenido según Knowledge/README.md)" ;;
    recreate_script)       echo "   → restaura el script $REPO_DIR/scripts/$2 (referenciado en README/LOAD_CONTEXT)" ;;
    copy_skill_to_repo)    echo "   → copia la skill '$2' de ~/.agents/skills/ a $REPO_DIR/.agents/skills/$2/SKILL.md" ;;
    migrate_flat_skill)    echo "   → migra ~/.agents/skills/$2.md a formato SKILL.md" ;;
    remove_or_merge)       echo "   → decide: fusionar '$2' en INFO-core o archivarlo" ;;
    git_init)              echo "   → decide si inicializar git en $2" ;;
    update_index)          echo "   → añade '$2' al índice de docs correspondiente" ;;
    *) echo "   → revisa manualmente: $1 (target: $2)" ;;
  esac
}

# ── Resultado (humano o JSON) ─────────────────────────────
RESULT_TSV=""
add_result() { RESULT_TSV+="$1|$2|$3|$4"$'\n'; } # kind|fix|target|rest

emit_result() { # emit_result <errors> <warnings> <healthy>
  printf '%s' "$RESULT_TSV" | python3 -c "
import json, sys
lines = sys.stdin.read().splitlines()
applied, plan, review = [], [], []
for ln in lines:
    parts = ln.split('|', 3)
    if len(parts) < 4:
        continue
    kind, fix, target, rest = parts
    if kind == 'applied':
        applied.append({'fix': fix, 'target': target, 'status': rest})
    elif kind == 'plan':
        plan.append({'fix': fix, 'target': target, 'message': rest})
    elif kind == 'review':
        review.append({'fix': fix, 'target': target, 'message': rest})
data = {'repo': sys.argv[1], 'healthy': int(sys.argv[2]) == 0, 'errors': int(sys.argv[2]), 'warnings': int(sys.argv[3]), 'applied': applied, 'plan': plan, 'review_required': review}
print(json.dumps(data, ensure_ascii=False, indent=2))
" "$REPO_DIR" "$1" "$2"
}

# ── Modo --fix NOMBRE ─────────────────────────────────────
if [ -n "$FIX_ONLY" ]; then
  match=""
  for a in "${SAFE_ACTIONS[@]}" "${REVIEW_ACTIONS[@]}"; do
    IFS='|' read -r f t m <<< "$a"
    [ "$f" = "$FIX_ONLY" ] && { match="$a"; break; }
  done
  if [ -z "$match" ]; then
    echo "❌ Fix '$FIX_ONLY' no está entre los detectados." >&2
    echo "   Detectados: $(for a in "${SAFE_ACTIONS[@]}" "${REVIEW_ACTIONS[@]}"; do echo "${a%%|*}"; done | sort -u | tr '\n' ' ')" >&2
    exit 2
  fi
  IFS='|' read -r f t m <<< "$match"
  if [[ " ${SAFE_ACTIONS[*]} " == *" $match "* ]]; then
    say "🔧 Aplicando $f (target: $t)..."
    if apply_fix "$f" "$t"; then
      add_result "applied" "$f" "$t" "ok"
      say "✅ $f aplicado"
    else
      add_result "applied" "$f" "$t" "fail"
      say "❌ Fallo aplicando $f"
      emit_result "$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo 0)" "$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo 0)"
      exit 2
    fi
  else
    say "⏸️  $f es REVIEW_REQUIRED — no se aplica automáticamente."
    say "$(review_guidance "$f" "$t")"
    add_result "review" "$f" "$t" "$m"
    emit_result "$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo 0)" "$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo 0)"
    exit 1
  fi
  # Verificar tras aplicar
  AFTER_JSON="$(bash "$DOCTOR" --json --repo "$REPO_DIR" 2>/dev/null || true)"
  AFTER_ERRS="$(echo "$AFTER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo "?")"
  AFTER_WARNS="$(echo "$AFTER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo "?")"
  say "── Verificación ──"
  say "   errors_after=$AFTER_ERRS warnings_after=$AFTER_WARNS"
  if [ "$JSON_OUT" = true ]; then
    emit_result "$AFTER_ERRS" "$AFTER_WARNS"
  fi
  { [ ${#REVIEW_ACTIONS[@]} -gt 0 ] || [ "$AFTER_ERRS" != "0" ]; } && exit 1 || exit 0
fi

# ── Plan (dry-run por defecto) ────────────────────────────
if [ "$AUTO" != true ]; then
  say "🔍 Plan de reparación para $REPO_DIR"
  say ""
  say "🤖 AUTO_SAFE (${#SAFE_ACTIONS[@]} — aplicable con --auto):"
  [ ${#SAFE_ACTIONS[@]} -eq 0 ] && say "   (ninguno)"
  for a in "${SAFE_ACTIONS[@]}"; do
    IFS='|' read -r f t m <<< "$a"
    say "   [${f}] ${m}"
    add_result "plan" "$f" "$t" "$m"
  done
  say ""
  say "👁️  REVIEW_REQUIRED (${#REVIEW_ACTIONS[@]} — requiere decisión humana):"
  [ ${#REVIEW_ACTIONS[@]} -eq 0 ] && say "   (ninguno)"
  for a in "${REVIEW_ACTIONS[@]}"; do
    IFS='|' read -r f t m <<< "$a"
    say "   [${f}] ${m}"
    say "$(review_guidance "$f" "$t")"
    add_result "review" "$f" "$t" "$m"
  done
  if [ "$JSON_OUT" = true ]; then
    ERRORS_NOW="$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo 0)"
    WARNINGS_NOW="$(echo "$DOC_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo 0)"
    emit_result "$ERRORS_NOW" "$WARNINGS_NOW"
  fi
  [ ${#REVIEW_ACTIONS[@]} -gt 0 ] && exit 1 || exit 0
fi

# ── Aplicar AUTO_SAFE y verificar ─────────────────────────
APPLIED_FAIL=0
for a in "${SAFE_ACTIONS[@]}"; do
  IFS='|' read -r f t m <<< "$a"
  say "🔧 [${f}] ${m}"
  if apply_fix "$f" "$t"; then
    add_result "applied" "$f" "$t" "ok"
    say "   ✅ aplicado"
  else
    APPLIED_FAIL=$((APPLIED_FAIL+1))
    add_result "applied" "$f" "$t" "fail"
    say "   ❌ fallo"
  fi
done

for a in "${REVIEW_ACTIONS[@]}"; do
  IFS='|' read -r f t m <<< "$a"
  add_result "review" "$f" "$t" "$m"
done

AFTER_JSON="$(bash "$DOCTOR" --json --repo "$REPO_DIR" 2>/dev/null || true)"
AFTER_ERRS="$(echo "$AFTER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["errors"])' 2>/dev/null || echo "?")"
AFTER_WARNS="$(echo "$AFTER_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["warnings"])' 2>/dev/null || echo "?")"
say ""
say "── Verificación ──"
say "   errors_after=$AFTER_ERRS warnings_after=$AFTER_WARNS"
if [ "$JSON_OUT" = true ]; then
  emit_result "$AFTER_ERRS" "$AFTER_WARNS"
fi

if [ ${#REVIEW_ACTIONS[@]} -gt 0 ] || [ "$APPLIED_FAIL" -gt 0 ] || [ "$AFTER_ERRS" != "0" ]; then
  say ""
  if [ "$AFTER_ERRS" != "0" ]; then
    say "⚠️  Quedan $AFTER_ERRS error(es) tras aplicar (fixes AUTO_SAFE insuficientes o fallidos)."
  fi
  if [ ${#REVIEW_ACTIONS[@]} -gt 0 ]; then
    say "⏸️  Quedan ${#REVIEW_ACTIONS[@]} items REVIEW_REQUIRED (no se tocan automáticamente)."
    for a in "${REVIEW_ACTIONS[@]}"; do
      IFS='|' read -r f t m <<< "$a"
      say "   [${f}] ${m}"
      say "$(review_guidance "$f" "$t")"
    done
  fi
  exit 1
fi
exit 0

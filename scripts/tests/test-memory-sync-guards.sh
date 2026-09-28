#!/usr/bin/env bash
# test-memory-sync-guards.sh — tests de git REAL para los guards anti-falso-éxito
# de scripts/lib/buffy-memory-sync.sh (auditoría PII 2026-09-28, fix C1).
#
# A diferencia de test-memory.sh (modo simulación BUFFY_SYNC_GIT=true, sin git),
# estos tests montan un repo git sandbox con remote bare para ejercitar:
#   guard #1  sync destino gitignoreado → abort ANTES de mutar (.sync-state honesto)
#   guard #2  stage específico: candidato que no queda stageado → abort
#   guard #4  push fallido → exit 1, estado NO marcado, commit pendiente registrado
#   pendiente → reintento automático en el próximo sync push
# (guard #3 — propagación de RC de add/commit — está ejercitado transversalmente
# por todos estos tests: cualquier fallo de add/commit ya no se traga).
# sourced por run-tests.sh.

gsetup() {
  # repo de sync con remote bare: push tiene a dónde ir (y se le puede quitar)
  GS_T="${TMPDIR:-/tmp}/buffy-gsync-$$"
  rm -rf "$GS_T"
  mkdir -p "$GS_T/remote.git" "$GS_T/repo/ai-context/memories" "$GS_T/mem"
  git init -q --bare "$GS_T/remote.git"
  git -C "$GS_T/repo" init -q
  git -C "$GS_T/repo" config user.email test@test
  git -C "$GS_T/repo" config user.name test
  git -C "$GS_T/repo" commit -q --allow-empty -m init
  git -C "$GS_T/repo" remote add origin "$GS_T/remote.git"
  git -C "$GS_T/repo" push -q -u origin HEAD
  # NO trap acá: el trap RETURN se dispara al retornar ESTA función y borraría
  # el sandbox antes de usarlo (mismo gotcha documentado en test-close-day.sh).
  # El trap va en cada test_*.
}

grun() {  # grun <mem-rel> <args...> — sync contra el repo git real del sandbox
  local mem="$1"; shift
  BUFFY_MEM_DIR="$GS_T/$mem" BUFFY_SYNC_DIR="$GS_T/repo/ai-context/memories" \
  BUFFY_SYNC_HOST="g-test" bash "$SCRIPTS_DIR/buffy-memory.sh" sync "$@"
}

gstate_sha() {  # gstate_sha <mem-dir> <store> → sha marcado ("" si no)
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1] + "/.sync-state"))
except Exception:
    print(""); sys.exit(0)
print(d.get("hosts", {}).get("g-test", {}).get(sys.argv[2], ""))
PY
}

gpend() {  # gpend <mem-dir> <store> → sha pendiente ("" si no)
  python3 - "$1" "$2" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1] + "/.sync-state"))
except Exception:
    print(""); sys.exit(0)
print(d.get("pending_push", {}).get(sys.argv[2], ""))
PY
}

test_memory_sync_guard_gitignore() {
  suite "sync guards (git real): destino gitignoreado → abort ANTES de mutar"
  gsetup
  trap 'rm -rf "$GS_T"' RETURN
  BUFFY_MEM_DIR="$GS_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "entrada guard gitignore" >/dev/null
  # a) el .gitignore REAL del repo público (memories/ ignorado, canal privado
  #    D0.1b) replicado en el repo de sync → el guard #1 debe abortar
  cp "$REPO_DIR/.gitignore" "$GS_T/repo/.gitignore" 2>/dev/null || true
  if grun mem push >/dev/null 2>&1; then
    bad "push con destino gitignoreado debería abortar (exit 1)"
  else
    ok "push con destino gitignoreado → exit 1"
  fi
  local n
  n=$(git -C "$GS_T/repo" log --oneline | wc -l)
  if [ "$n" -eq 1 ]; then ok "abort ANTES de mutar: cero commits nuevos (guard #1)"; else bad "abort ANTES de mutar: esperaba 1 commit init, hay $n"; fi
  if [ -z "$(gstate_sha "$GS_T/mem" memory)" ]; then ok ".sync-state sin marcar (honesto)"; else bad ".sync-state sin marcar (honesto)"; fi
  # b) destino libre → el mismo push ahora completa
  rm -f "$GS_T/repo/.gitignore"
  if grun mem push >/dev/null 2>&1; then ok "push OK tras quitar el gitignore"; else bad "push OK tras quitar el gitignore"; fi
  if [ -n "$(gstate_sha "$GS_T/mem" memory)" ]; then ok "estado marcado tras push OK"; else bad "estado marcado tras push OK"; fi
}

test_memory_sync_guard_push_fallido() {
  suite "sync guards (git real): push fallido → exit 1, estado NO marcado, pendiente + reintento"
  gsetup
  trap 'rm -rf "$GS_T"' RETURN
  BUFFY_MEM_DIR="$GS_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "para push fallido" >/dev/null
  # push sin remote vivo → falla (se borra el directorio del remote, NO el remote
  # config: quitar/reagregar 'origin' destruiría el upstream que en producción
  # queda seteado por el clone y el reintento fallaría por la razón equivocada)
  rm -rf "$GS_T/remote.git"
  if grun mem push >/dev/null 2>&1; then
    bad "push sin remote debería fallar (exit 1) — ya no hay falso ✔"
  else
    ok "push sin remote → exit 1 (ya no hay falso ✔)"
  fi
  if [ -z "$(gstate_sha "$GS_T/mem" memory)" ]; then ok "estado NO marcado tras push fallido"; else bad "estado NO marcado tras push fallido"; fi
  if [ -n "$(gpend "$GS_T/mem" memory)" ]; then ok "commit pendiente registrado"; else bad "commit pendiente registrado"; fi
  if git -C "$GS_T/repo" log --oneline | grep -q 'docs(memory)'; then
    ok "commit local existe (docs(memory))"
  else
    bad "commit local existe (docs(memory))"
  fi
  # reintento: remote de vuelta (vacío, como tras una caída) → pendiente se cierra
  git init -q --bare "$GS_T/remote.git"
  if grun mem push >/dev/null 2>&1; then ok "reintento de push pendiente OK"; else bad "reintento de push pendiente OK"; fi
  if [ -n "$(gstate_sha "$GS_T/mem" memory)" ]; then ok "estado marcado tras reintento"; else bad "estado marcado tras reintento"; fi
  if [ -z "$(gpend "$GS_T/mem" memory)" ]; then ok "pendiente cerrado tras reintento"; else bad "pendiente cerrado tras reintento"; fi
  # status ok (sin divergencia fantasma)
  if grun mem status >/dev/null 2>&1; then ok "status ok tras ciclo completo"; else bad "status ok tras ciclo completo"; fi
}

test_memory_sync_guard_stage() {
  suite "sync guards (git real): candidato que no queda stageado → abort (guard #2 específico)"
  gsetup
  trap 'rm -rf "$GS_T"' RETURN
  BUFFY_MEM_DIR="$GS_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "v1 base stage" >/dev/null
  if grun mem push >/dev/null 2>&1; then ok "push inicial v1 OK"; else bad "push inicial v1 OK"; fi
  # edición ajena SIN commit en el repo de sync (el F1 la ve como repo≠local)
  printf '§\nentrada ajena sin commit\n' > "$GS_T/repo/ai-context/memories/MEMORY.md"
  # el local vuelve al contenido ya pusheado (byte-idéntico a HEAD): tras cp el
  # add no stagea nada → guard #2 aborta (el genérico --cached --quiet lo habría
  # pasado por alto si hubiera algo más stageado)
  git -C "$GS_T/repo" show HEAD:ai-context/memories/MEMORY.md > "$GS_T/mem/MEMORY.md"
  local n0
  n0=$(git -C "$GS_T/repo" log --oneline | wc -l)
  if grun mem push --force >/dev/null 2>&1; then
    bad "candidato idéntico a HEAD tras cp → debería abortar (guard #2)"
  else
    ok "candidato idéntico a HEAD tras cp → exit 1 (guard #2: nada stageado)"
  fi
  local n1
  n1=$(git -C "$GS_T/repo" log --oneline | wc -l)
  if [ "$n1" -eq "$n0" ]; then ok "abort sin commits nuevos"; else bad "abort sin commits nuevos ($n0 → $n1)"; fi
  if [ -z "$(gpend "$GS_T/mem" memory)" ]; then ok "sin pendiente fantasma (estado intacto)"; else bad "sin pendiente fantasma (estado intacto)"; fi
}

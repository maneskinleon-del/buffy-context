#!/usr/bin/env bash
# test-close-day.sh — tests del cierre de sesión (buffy-close-day.sh, "cerrar día").
# Sin git remoto (repo local) y sin doctor real (--skip-doctor): valida el flujo
# mecánico — sync push de memoria → SNAPSHOT → commit — que es lo que falla si
# se rompe. El doctor real lo corre el protocolo en producción.
# sourced por run-tests.sh.

close_setup() {
  CLOSE_T="${TMPDIR:-/tmp}/buffy-close-$$"
  rm -rf "$CLOSE_T"
  mkdir -p "$CLOSE_T/repo" "$CLOSE_T/mem" "$CLOSE_T/home"
  git -C "$CLOSE_T/repo" init -q
  git -C "$CLOSE_T/repo" config user.email test@test
  git -C "$CLOSE_T/repo" config user.name test
  git -C "$CLOSE_T/repo" commit -q --allow-empty -m init
  # NO poner trap aquí: el trap RETURN se dispara al retornar ESTA función
  # y borraría el sandbox antes de usarlo. El trap va en cada test_*.
}

run_close() {  # run_close [args...] → env aislado + repo del sandbox
  BUFFY_HOME="$CLOSE_T/home" \
  BUFFY_MEM_DIR="$CLOSE_T/mem" \
  BUFFY_SYNC_DIR="$CLOSE_T/repo/ai-context/memories" \
  BUFFY_SYNC_HOST="testhost" \
  bash "$SCRIPTS_DIR/buffy-close-day.sh" --repo "$CLOSE_T/repo" "$@"
}

test_close_day_flujo_completo() {
  suite "close-day: cierre completo (sync memoria + SNAPSHOT + commit)"
  close_setup
  trap 'rm -rf "$CLOSE_T"' RETURN
  BUFFY_MEM_DIR="$CLOSE_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "hecho antes de cerrar" >/dev/null
  echo "cambio de contexto" >> "$CLOSE_T/repo/ai-context/SESION.md" 2>/dev/null || { mkdir -p "$CLOSE_T/repo/ai-context"; echo "cambio de contexto" >> "$CLOSE_T/repo/ai-context/SESION.md"; }
  expect_exit 0 "cierre exit 0" run_close --no-push --skip-doctor --message "prueba"
  if git -C "$CLOSE_T/repo" log --oneline -1 | grep -q "docs(sesion): cerrar día"; then
    ok "commit de cierre creado con mensaje"
  else
    bad "commit de cierre: $(git -C "$CLOSE_T/repo" log --oneline -1)"
  fi
  if git -C "$CLOSE_T/repo" ls-tree -r --name-only HEAD | grep -q "ai-context/memories/MEMORY.md"; then
    ok "memoria curada versionada en el repo"
  else
    bad "memoria curada versionada en el repo"
  fi
  if [ -s "$CLOSE_T/home/ai-context/SNAPSHOT.md" ]; then ok "SNAPSHOT regenerado en BUFFY_HOME"; else bad "SNAPSHOT regenerado en BUFFY_HOME"; fi
  if git -C "$CLOSE_T/repo" status --porcelain | grep -q .; then bad "repo limpio tras cierre"; else ok "repo limpio tras cierre"; fi
}

test_close_day_conflicto_aborta() {
  suite "close-day: memoria en conflicto → cierre abortado"
  close_setup
  trap 'rm -rf "$CLOSE_T"' RETURN
  BUFFY_MEM_DIR="$CLOSE_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "base" >/dev/null
  expect_exit 0 "push inicial de memoria" run_close --no-push --skip-doctor
  # Otro dispositivo cambia el repo (simula PC) → el push del cierre conflicta
  BUFFY_MEM_DIR="$CLOSE_T/mem" bash "$SCRIPTS_DIR/buffy-memory.sh" add memory "cambio local no sincronizado" >/dev/null
  printf '§\nentrada del pc\n' > "$CLOSE_T/repo/ai-context/memories/MEMORY.md"
  # Edición manual del repo sin actualizar .sync-state → mi push debe conflictar
  if run_close --no-push --skip-doctor >/dev/null 2>&1; then
    bad "cierre con conflicto de memoria debería abortar"
  else
    ok "cierre con conflicto de memoria → exit != 0"
  fi
}

test_close_day_ayuda() {
  suite "close-day: --help y uso inválido"
  close_setup
  trap 'rm -rf "$CLOSE_T"' RETURN
  if bash "$SCRIPTS_DIR/buffy-close-day.sh" --help | grep -q "cerrar día"; then
    ok "--help documenta el protocolo"
  else
    bad "--help documenta el protocolo"
  fi
  if bash "$SCRIPTS_DIR/buffy-close-day.sh" --help | grep -q -- "--poweroff"; then
    ok "--help documenta --poweroff (cerrar día+1)"
  else
    bad "--help documenta --poweroff"
  fi
  expect_exit 2 "opción desconocida → exit 2" run_close --bogus
}

test_close_day_poweroff() {
  suite "close-day: --poweroff apaga solo tras cierre exitoso (stub, nunca real)"
  close_setup
  trap 'rm -rf "$CLOSE_T"' RETURN
  # stub de apagado: toca un marcador en vez de apagar el PC
  cat > "$CLOSE_T/fake-poweroff" <<'EOF'
#!/usr/bin/env bash
touch "$FAKE_POWEROFF_MARKER"
EOF
  chmod +x "$CLOSE_T/fake-poweroff"
  echo "cambio de contexto" >> "$CLOSE_T/repo/ai-context/SESION.md"

  # --poweroff con stub → cierre exit 0 + marcador presente
  if FAKE_POWEROFF_MARKER="$CLOSE_T/powered-off" \
     BUFFY_POWEROFF_CMD="$CLOSE_T/fake-poweroff" \
     BUFFY_POWEROFF_DELAY=0 \
     run_close --no-push --skip-doctor --poweroff \
     && [ -f "$CLOSE_T/powered-off" ]; then
    ok "--poweroff apagó tras cierre exitoso (stub tocó marcador)"
  else
    bad "--poweroff tras cierre exitoso (marcador=$([ -f "$CLOSE_T/powered-off" ] && echo sí || echo no))"
  fi

  # --poweroff con comando inexistente → exit 1 (día cerrado pero sin apagado)
  if BUFFY_POWEROFF_CMD="/no/existe/poweroff" \
     BUFFY_POWEROFF_DELAY=0 \
     run_close --no-push --skip-doctor --poweroff >/dev/null 2>&1; then
    bad "--poweroff con comando inexistente debería ser exit 1"
  else
    ok "--poweroff con comando inexistente → exit 1 (no apaga)"
  fi
}

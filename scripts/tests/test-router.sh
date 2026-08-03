#!/usr/bin/env bash
# test-router.sh — tests de scripts/buffy-router.sh (carga condicional por manifests).
# El router es standalone (--repo) y no toca el sandbox → corre también en modo --quick.
# Fixtures temporales en ${TMPDIR:-/tmp}; limpieza con trap RETURN.

test_router_help() {
  suite "router: --help"
  expect_exit 0 "--help exit 0" bash "$SCRIPTS_DIR/buffy-router.sh" --help
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --help 2>&1)
  if echo "$OUT" | grep -q 'buffy-router'; then
    ok "--help muestra uso"
  else
    bad "--help muestra uso"
  fi
}

test_router_missing_message() {
  suite "router: falta el mensaje"
  expect_exit 1 "sin mensaje → exit 1" bash "$SCRIPTS_DIR/buffy-router.sh"
}

test_router_base_files() {
  suite "router: base siempre incluye INFO-core + CONTINUE"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --quick "hola" 2>/dev/null)
  if echo "$OUT" | grep -q 'ai-context/INFO-core.md'; then ok "INFO-core.md en base"; else bad "INFO-core.md en base"; fi
  if echo "$OUT" | grep -q 'ai-context/CONTINUE.md'; then ok "CONTINUE.md en base"; else bad "CONTINUE.md en base"; fi
}

test_router_skill_via_manifest() {
  suite "router: skill resuelta desde manifest (no hardcodeada)"
  # android-adb debe cargarse para un mensaje android, resuelta vía add_skill → manifest.
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --quick "problema con adb logcat en mi telefono" 2>/dev/null)
  if echo "$OUT" | grep -q '.agents/skills/android-adb/SKILL.md'; then
    ok "android-adb cargada (mensaje android)"
  else
    bad "android-adb cargada (mensaje android)"
  fi
}

test_router_discovery_by_triggers() {
  suite "router: descubrimiento por triggers del manifest"
  # Skill nueva (sin regla en el router): su skill.yaml define triggers y debe
  # descubrirse sola cuando el mensaje matchea sus triggers (contrato B2).
  local FIX="${TMPDIR:-/tmp}/buffy-router-disc-$$"
  rm -rf "$FIX"
  mkdir -p "$FIX/.agents/skills/mi-skill-nueva"
  printf '%s\n' \
    'id: mi-skill-nueva' \
    'name: Mi Skill Nueva' \
    'version: 1.0.0' \
    'entry: SKILL.md' \
    'safe: true' \
    'triggers:' \
    '  - quasar' \
    '  - warpdrive' > "$FIX/.agents/skills/mi-skill-nueva/skill.yaml"
  touch "$FIX/.agents/skills/mi-skill-nueva/SKILL.md"
  trap 'rm -rf "$FIX"' RETURN

  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --repo "$FIX" --quick "como arreglo el quasar del warpdrive" 2>/dev/null)
  if echo "$OUT" | grep -q '.agents/skills/mi-skill-nueva/SKILL.md'; then
    ok "skill con triggers matcheados se descubre sola"
  else
    bad "skill con triggers matcheados se descubre sola"
  fi
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --repo "$FIX" --quick "hola que tal" 2>/dev/null)
  if echo "$OUT" | grep -q 'mi-skill-nueva'; then
    bad "sin triggers matcheados NO se descubre"
  else
    ok "sin triggers matcheados NO se descubre"
  fi
}

test_router_missing_manifest_warning() {
  suite "router: skill sin manifest → warning de drift B2"
  local FIX="${TMPDIR:-/tmp}/buffy-router-miss-$$"
  rm -rf "$FIX"
  mkdir -p "$FIX/.agents/skills/sin-manifest"
  touch "$FIX/.agents/skills/sin-manifest/SKILL.md"
  trap 'rm -rf "$FIX"' RETURN

  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --repo "$FIX" "que es android" 2>/dev/null)
  if echo "$OUT" | grep -q 'sin manifest'; then
    ok "advierte skill referenciada sin skill.yaml"
  else
    bad "advierte skill referenciada sin skill.yaml"
  fi
}

test_router_json_valid() {
  suite "router: --json válido"
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --json "adios" 2>/dev/null)
  if [ -n "$OUT" ]; then ok "--json produce salida"; else bad "--json produce salida"; fi
  jassert "--json parseable + claves" "$OUT" 'import json,sys; d=json.load(sys.stdin); assert set(d.keys())=={"message","categories","base","knowledge","skills","scripts"}, d.keys(); assert isinstance(d["skills"],list) and isinstance(d["base"],list)'
}

test_router_quick_pure_paths() {
  suite "router: --quick solo rutas existentes"
  local OUT MISSING
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --quick "android adb" 2>/dev/null)
  MISSING=$(echo "$OUT" | grep -c 'ausente\|inexistente\|⚠️' || true)
  if [ "$MISSING" = "0" ]; then
    ok "--quick no imprime warnings ni anotaciones"
  else
    bad "--quick no imprime warnings ni anotaciones ($MISSING líneas)"
  fi
  if echo "$OUT" | grep -qE '^[^ ]'; then
    ok "una ruta por línea"
  else
    bad "una ruta por línea"
  fi
}

test_router_list() {
  suite "router: --list"
  expect_exit 0 "--list exit 0" bash "$SCRIPTS_DIR/buffy-router.sh" --list
  local OUT
  OUT=$(bash "$SCRIPTS_DIR/buffy-router.sh" --list 2>&1)
  if echo "$OUT" | grep -q 'Android'; then
    ok "--list muestra categorías"
  else
    bad "--list muestra categorías"
  fi
}

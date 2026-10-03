#!/usr/bin/env bash
# test-pii-guard.sh — guard de regresión PII (C2, auditoría 2026-09-28).
# Fuente de los patrones: auditoría PII 2026-09-28 (fases A/B; allowlist en D0.2).
# Alcance: SOLO contenido tracked (`git grep`, no disco) — el estado local
# gitignored lo cubre .gitignore, no este guard.
#
# C5 (2026-09-30): la exclusión de `scripts/tests/evals/` está LEVANTADA —
# el corpus del fixture fue sanitizado (redacciones A-list in situ, corpus_hash
# 0af49cc666d872a6 → bf10aeefecea8b74) y el guard lo cubre. 0 matches ABSOLUTOS.
#
# Allowlist consciente (no-PII o fuera de alcance):
#   - AKIAIOSFODNN7EXAMPLE / hf_xxx — fixtures del propio linter PII (en evals/).
#   - `maneskinleon-del` — usuario público de GitHub por diseño (D0.2).
#
# D2.1 (2026-10-03): el alias personal `mangonz` ENTRA al patrón. El repo
# declara identidad de SISTEMA — alias `buffy-maint`, `system-id: buffy-desktop`
# — y el alias personal solo sobrevive en artefactos congelados (abajo).
# Excepciones POR PATRÓN (ver `pii_excl_for` abajo), NO allowlist del patrón:
#   - este archivo (contiene las literales del array de patrones).
#   - fixture congelado + selector-pool: son snapshots de un corpus ya cerrado.
#     Editarlos rompe `corpus_hash` (validado por el manifest) y reabre la
#     decisión C5. No pueden reintroducir PII solos: solo cambian por un re-gen
#     deliberado, que es exactamente el momento de revisarlos a mano.
#   - CHANGELOG-archive: registra acciones reales sobre la máquina del operador
#     (`/etc/sudoers.d/...`). Redactarlo haría que la entrada dijera algo que no
#     ocurrió — el valor de un changelog es ser faithful, no higienizado.
#
# Estas exclusiones aplican SOLO al alias. Los demás patrones (email real, nombre
# real, seriales, claves) se siguen buscando en TODO el tracked, evals/ incluido —
# que es exactamente lo que C5 levantó a propósito. Una excepción de un patrón no
# puede ser excepción de los otros: el motivo de exceptuar el alias (vive en
# artefactos congelados) no dice nada sobre un email real.

# pii_excl_for <patrón> — imprime (una por línea) los pathspecs de exclusión de
# ESE patrón. Función aparte para que la política sea testeable: el guard la usa y
# el test la ejercita sobre un repo temporal. Sin esto, "agregar una excepción" es
# un cambio invisible hasta que alguien lee el array.
pii_excl_for() {
  case "$1" in
    'mangonz') printf '%s\n' \
                 ':!scripts/tests/test-pii-guard.sh' \
                 ':!scripts/tests/evals/fixtures/' \
                 ':!scripts/tests/evals/selector-pool-frozen-2026-08-13.json' \
                 ':!ai-context/CHANGELOG-archive.md' ;;
    *)         printf '%s\n' ':!scripts/tests/test-pii-guard.sh' ;;
  esac
}

test_pii_guard_patrones() {
  suite "pii-guard: patrones A-list ausentes en tracked (incl. evals — C5)"

  local -a patrones=(
    'mangonz970@gmail.com'
    'Manuel Gonzalez'
    'mangonz'
    '320344802623'
    '1yqqZXC4kysIlMMbY57Bi6Ft5Jf5mtO3fUX9EnT41BJtCOnMXmQ01I_sK'
    '1TW8pIdyQAUeAI7ZznVY4KCZgZtGirq_leLUX8vXWQa1e0i6prPIpzBOu'
  )
  # Auto-exclusión del propio guard: una vez commiteado (tracked), este archivo
  # contiene las literales de los patrones (este array) y se auto-matchearía —
  # misma familia que el pkill/pgrep que se auto-detecta (lección 2026-09-28:
  # bracket-trick o exclusión de pathspec).
  local -a excl_base=(':!scripts/tests/test-pii-guard.sh')

  # Excepciones POR PATRÓN (D2.3), no globales. La primera versión de D2.3 las
  # puso en un array compartido y eso tapó `mangonz970@gmail.com` y
  # `Manuel Gonzalez` dentro de evals/ — justo lo que C5 había LEVANTADO
  # explícitamente para que el guard llegara ahí. Una excepción de un patrón no
  # puede ser excepción de los otros: el motivo de exceptuar el alias (sobrevive
  # en artefactos congelados) no dice nada sobre un email real.
  local p hits
  local -a excl
  for p in "${patrones[@]}"; do
    excl=()
    while IFS= read -r _e; do excl+=("$_e"); done < <(pii_excl_for "$p")
    hits=$(git -C "$REPO_DIR" grep -c -F "$p" -- "${excl[@]}" 2>/dev/null \
           | awk -F: '{s+=$NF} END {print s+0}')
    if [ "$hits" -eq 0 ]; then
      ok "0 matches tracked: ${p:0:28}…"
    else
      bad "PII reintroducida ($hits matches): ${p:0:28}… — redactar (auditoría 2026-09-28)"
    fi
  done

  # Ruta home completa del operador: solo se acepta la forma `~` (convención
  # del repo). Guard específico porque el patrón es genérico y reaparece fácil.
  hits=$(git -C "$REPO_DIR" grep -c -F '/home/mangonz' -- "${excl_base[@]}" 2>/dev/null \
         | awk -F: '{s+=$NF} END {print s+0}')
  if [ "$hits" -eq 0 ]; then
    ok "0 matches tracked: /home/mangonz (usar ~)"
  else
    bad "ruta home del operador en tracked ($hits matches) — reemplazar por ~ (auditoría 2026-09-28)"
  fi
}

# La excepción del alias es una deuda que se paga sola si nadie la mira. Este test
# hace tres cosas que antes nadie hacia:
#   1. Que la excepción EXISTA y siga siendo la declarada (falla si alguien agrega
#      un pathspec más sin darse cuenta — el array deja de growing en silencio).
#   2. Que la excepción sea REAL (si el fixture se limpia, la excepción queda
#      vacía y hay que revisarla, no dejarla colgando).
#   3. Que NO se derrame: un patrón de PII real dentro de evals/ tiene que seguir
#      siendo cazado. Esto es la regresión que D2.3 introdujo y nadie miró.
test_pii_guard_excepciones_por_patron() {
  suite "pii-guard: excepciones por patrón, no globales (D2.3)"
  local TMP="${TMPDIR:-/tmp}/buffy-piiexcl-$$"
  rm -rf "$TMP"
  trap 'rm -rf "$TMP"' RETURN
  mkdir -p "$TMP/scripts/tests/evals/fixtures" "$TMP/ai-context"
  git -C "$TMP" init -q
  git -C "$TMP" config user.email t@t.t
  git -C "$TMP" config user.name t
  # Un archivo dentro del path congelado, con PII real Y el alias.
  printf '%s\n' 'Manuel Gonzalez <mangonz970@gmail.com>' 'alias: mangonz' \
    > "$TMP/scripts/tests/evals/fixtures/roto.md"
  printf '%s\n' 'sudo para mangonz' > "$TMP/ai-context/CHANGELOG-archive.md"
  git -C "$TMP" add -A

  local n_alias n_otro
  n_alias=$(pii_excl_for 'mangonz' | wc -l)
  n_otro=$(pii_excl_for 'Manuel Gonzalez' | wc -l)
  if [ "$n_alias" -eq 4 ]; then
    ok "el alias mantiene sus 4 exclusiones declaradas"
  else
    bad "el alias tiene $n_alias exclusiones (esperado 4) — ¿se agregó una sin revisar?"
  fi
  if [ "$n_otro" -eq 1 ]; then
    ok "los demás patrones conservan solo la auto-exclusión"
  else
    bad "un patrón real tiene $n_otro exclusiones (esperado 1) — la excepción se derramó"
  fi

  # Comportamiento real: repo temporal, PII real dentro de evals/ tiene que verse.
  local hits
  hits=$(git -C "$TMP" grep -c -F 'Manuel Gonzalez' -- $(pii_excl_for 'Manuel Gonzalez') 2>/dev/null \
         | awk -F: '{s+=$NF} END {print s+0}')
  if [ "$hits" -ge 1 ]; then
    ok "PII real dentro de evals/ sigue bajo el guard (no la tapa la excepción del alias)"
  else
    bad "PII real en evals/ pasa desapercibida — la excepción del alias se derramó"
  fi
  # Y el alias dentro de evals/ NO debe verse: esa es la excepción, declarada.
  hits=$(git -C "$TMP" grep -c -F 'mangonz' -- $(pii_excl_for 'mangonz') 2>/dev/null \
         | awk -F: '{s+=$NF} END {print s+0}')
  if [ "$hits" -eq 0 ]; then
    ok "el alias en artefactos congelados queda exceptuado (como dice la política)"
  else
    bad "el alias en evals/ sigue matcheando — la excepción dejó de aplicar"
  fi
}

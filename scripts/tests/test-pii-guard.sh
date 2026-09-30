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
#   - alias `mangonz` — FUERA del patrón hasta D2.1 (decisión pendiente:
#     identificador neutro vs identificador personal).

test_pii_guard_patrones() {
  suite "pii-guard: patrones A-list ausentes en tracked (incl. evals — C5)"

  local -a patrones=(
    'mangonz970@gmail.com'
    'Manuel Gonzalez'
    '320344802623'
    '1yqqZXC4kysIlMMbY57Bi6Ft5Jf5mtO3fUX9EnT41BJtCOnMXmQ01I_sK'
    '1TW8pIdyQAUeAI7ZznVY4KCZgZtGirq_leLUX8vXWQa1e0i6prPIpzBOu'
  )
  # Auto-exclusión del propio guard: una vez commiteado (tracked), este archivo
  # contiene las literales de los patrones (este array) y se auto-matchearía —
  # misma familia que el pkill/pgrep que se auto-detecta (lección 2026-09-28:
  # bracket-trick o exclusión de pathspec).
  local -a excl=(':!scripts/tests/test-pii-guard.sh')
  local p hits
  for p in "${patrones[@]}"; do
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
  hits=$(git -C "$REPO_DIR" grep -c -F '/home/mangonz' -- "${excl[@]}" 2>/dev/null \
         | awk -F: '{s+=$NF} END {print s+0}')
  if [ "$hits" -eq 0 ]; then
    ok "0 matches tracked: /home/mangonz (usar ~)"
  else
    bad "ruta home del operador en tracked ($hits matches) — reemplazar por ~ (auditoría 2026-09-28)"
  fi
}

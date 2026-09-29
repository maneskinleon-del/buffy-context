#!/usr/bin/env bash
# test-pii-guard.sh — guard de regresión PII (C2, auditoría 2026-09-28).
# Fuente de los patrones: auditoría PII 2026-09-28 (fases A/B; allowlist en D0.2).
# Alcance: SOLO contenido tracked (`git grep`, no disco) — el estado local
# gitignored lo cubre .gitignore, no este guard.
#
# EXCLUSIÓN TEMPORAL: `scripts/tests/evals/` (corpus congelado del selector,
# snapshot forense del 2026-08-13 con PII histórica). Se sanitiza en C5;
# hasta entonces este guard no lo mira. ⚠ AL EJECUTAR C5: quitar la exclusión
# y esperar 0 matches ABSOLUTOS (verificación "→ vacío" post-C5).
#
# Allowlist consciente (no-PII o fuera de alcance):
#   - AKIAIOSFODNN7EXAMPLE / hf_xxx — fixtures del propio linter PII (en evals/).
#   - `maneskinleon-del` — usuario público de GitHub por diseño (D0.2).
#   - alias `mangonz` — FUERA del patrón hasta D2.1 (decisión pendiente:
#     identificador neutro vs identificador personal).

test_pii_guard_patrones() {
  suite "pii-guard: patrones A-list ausentes en tracked (excl. evals hasta C5)"

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
  local -a excl=(':!scripts/tests/evals' ':!scripts/tests/test-pii-guard.sh')
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

#!/usr/bin/env bash
# migrate-system.sh — Migra SYSTEM.md/SYSTEM_FULL.md → AGENTS.md.
#
# 1. Actualiza las referencias a SYSTEM.md/SYSTEM_FULL.md en *.md y *.sh
#    (excluye .git/, ai-context/deprecated/ y los propios archivos a mover).
# 2. Mueve SYSTEM.md y SYSTEM_FULL.md a ai-context/deprecated/ con timestamp.
# 3. Verifica con la suite (--quick) que el repo sigue sano.
#
# Uso:
#   bash scripts/migrate-system.sh
#
# Nota: el doctor ya marca SYSTEM.md/SYSTEM_FULL.md como DEPRECATED (warn),
# así que moverlos a deprecated/ REDUCE las advertencias — no rompe nada.
#
# Exit: 0 éxito · 1 error.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AI_CONTEXT="$REPO_ROOT/ai-context"
DEPRECATED_DIR="$AI_CONTEXT/deprecated"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cd "$REPO_ROOT"

echo -e "${GREEN}🔃 Migrando SYSTEM.md → AGENTS.md${NC}"

# ── 1. AGENTS.md debe existir (consolidación previa) ────────
if [ ! -f "$AI_CONTEXT/AGENTS.md" ]; then
  echo -e "${RED}❌ No existe ai-context/AGENTS.md — la migración requiere el archivo consolidado.${NC}" >&2
  echo -e "${YELLOW}   Consolida SYSTEM.md en AGENTS.md manualmente y vuelve a correr este script.${NC}" >&2
  exit 1
fi

# ── 2. Actualizar referencias (solo archivos versionados) ───
# Precedencia correcta: -o agrupa con paréntesis; se excluyen .git/,
# deprecated/ y los propios SYSTEM.md/SYSTEM_FULL.md (para no corromperlos
# antes de moverlos). README.md se excluye: su árbol de estructura tiene
# comentarios tipo "⚠️ DEPRECATED" pegados al nombre del archivo — un sed
# global dejaría "AGENTS.md # ⚠️ DEPRECATED", semánticamente incorrecto.
# buffy-doctor.sh se excluye: su loop `for f in SYSTEM.md SYSTEM_FULL.md` es
# CÓDIGO funcional (chequea existencia), no una referencia documental — un sed
# lo rompería. migrate-system.sh se excluye para evitar auto-modificación.
# CHANGELOG-archive.md se excluye: registro histórico, no se reescribe.
mapfile -t FILES < <(find . -type f \( -name '*.md' -o -name '*.sh' \) \
  -not -path './.git/*' \
  -not -path './ai-context/deprecated/*' \
  -not -path './README.md' \
  -not -path './scripts/buffy-doctor.sh' \
  -not -path './scripts/migrate-system.sh' \
  -not -path './ai-context/CHANGELOG-archive.md' \
  -not -name 'SYSTEM.md' -not -name 'SYSTEM_FULL.md' 2>/dev/null | sort)

CHANGED=0
for f in "${FILES[@]}"; do
  if grep -q 'SYSTEM\.md\|SYSTEM_FULL\.md' "$f" 2>/dev/null; then
    sed -i 's/SYSTEM_FULL\.md/AGENTS.md (full)/g; s/SYSTEM\.md/AGENTS.md/g' "$f"
    echo -e "  ${YELLOW}→${NC} actualizado: $f"
    CHANGED=$((CHANGED+1))
  fi
done
[ "$CHANGED" -eq 0 ] && echo "  ℹ️  Sin referencias a SYSTEM.md en el resto del repo."
echo -e "  ${YELLOW}ℹ️${NC} README.md excluido del sed automático — actualiza su árbol manualmente si lo referencia."

# ── 3. Mover archivos obsoletos a deprecated/ ───────────────
mkdir -p "$DEPRECATED_DIR"

for f in SYSTEM.md SYSTEM_FULL.md; do
  if [ -f "$AI_CONTEXT/$f" ]; then
    TS=$(date +%Y%m%d_%H%M%S)
    mv "$AI_CONTEXT/$f" "$DEPRECATED_DIR/$f.$TS"
    echo -e "  ${YELLOW}📦${NC} movido: $f → deprecated/$f.$TS"
  else
    echo "  ℹ️  $f no existe (nada que mover)."
  fi
done

# ── 4. README en deprecated/ ────────────────────────────────
cat > "$DEPRECATED_DIR/README.md" << 'EOF'
# Archivos Deprecados

Esta carpeta contiene archivos obsoletos que se mantienen por referencia histórica.

- `SYSTEM.md.*` → Migrado a `AGENTS.md`
- `SYSTEM_FULL.md.*` → Migrado a `AGENTS.md` (contenido ampliado)

No uses estos archivos. Consulta la documentación actual en `ai-context/`.
EOF
echo -e "  ${GREEN}✅${NC} deprecated/README.md creado."

# ── 5. Verificar con la suite (--quick) ─────────────────────
echo -e "${GREEN}🔍 Ejecutando suite (--quick) para validar la migración...${NC}"
LOG="${TMPDIR:-/tmp}/migrate-system-$$.log"
if bash scripts/tests/run-tests.sh --quick >"$LOG" 2>&1; then
  echo -e "${GREEN}✅ Tests pasaron. Migración exitosa.${NC}"
else
  echo -e "${RED}⚠️  La suite falló — revisa $LOG.${NC}" >&2
  echo -e "${YELLOW}   Puedes restaurar desde deprecated/ si es necesario.${NC}" >&2
  exit 1
fi

echo -e "${YELLOW}📌 Próximo paso: revisa README.md, LOAD_CONTEXT.md y actualiza CHANGELOG.md.${NC}"

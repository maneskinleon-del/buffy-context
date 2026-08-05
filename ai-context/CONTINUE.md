# 🔄 CONTINUE — Handoff entre sesiones

> ⚡ **PRÓXIMA SESIÓN: LEE ESTO PRIMERO**
> Generado: 2026-08-05 (data_car: sync Base Técnica → ficha pusheado · auto-carga de contexto en Freebuff arreglada)

---

## Resumen de la sesión

**Tema principal:** Sesión retomada tras un reinicio (combinación de teclas bloqueó el teclado). El WIP de data_car sobrevivió en disco pero no estaba pusheado → revisado, validado (lint + build OK) y commiteado/pusheado (**`89f74cf`**). Además se diagnosticó **por qué las sesiones arrancaban sin contexto**: Freebuff (Codebuff) solo auto-carga archivos con nombre exacto `AGENTS.md`/`CLAUDE.md`/`*.knowledge.md` (proyecto o `~/.AGENTS.md` global) y tu archivo se llamaba `AGENTS-root.md`. Se creó **`~/.AGENTS.md`** → el contexto ahora se auto-carga en cada sesión.

---

### ✅ Logros principales

#### 1. 🚗 data_car — Sync Base Técnica → Ficha del vehículo (commit `89f74cf` pusheado)
- **`src/lib/specsSync.ts`** (NUEVO): puente entre los datos verificados del manual (confianza ≥ 0.5) y la ficha (tab Garage). Auto-sync llena solo campos vacíos; botón "Sincronizar ficha" fuerza el sobreescrito. Toasts con etiquetas.
- **`src/lib/technicalExtractor.ts` (v2 — "cobertura honesta")**: confianza parte en 0 y suma solo por evidencia real (unidad, cercanía keyword ≤180 chars, sección correcta, formato). Cada candidato trackea página + sección del manual. Se descartan falsos positivos. Componentes solo con ≥1 dato real. Cobertura = reglas requeridas con datos llenados. Base cacheada.
- **`src/components/TechnicalDatabase.tsx`**: extracción por páginas (`pdfPages`), auto-sync al montar (bases viejas) y tras extraer, cobertura por sistema real (rellenados/reglas), botón "Sincronizar ficha", invalida extractor cacheado al cambiar PDF.
- **`src/App.tsx`**: merge de specs guardados con defaults (fix inputs no controlados con campos nuevos). **`SpecForm.tsx`**: campos aceite caja, refrigerante, líquido frenos, bujías. **`types.ts`**: campo `alfombra` eliminado.
- Validación antes del push: `npm run lint` (tsc) ✅ + `npm run build` ✅. 6 archivos, +592/-175.

#### 2. 🧠 Freebuff — Contexto de sesión resuelto (causa raíz encontrada)
- **Causa raíz**: el cliente Freebuff (Codebuff, binario `~/.config/manicode/freebuff` v0.0.138, repo `CodebuffAI/freebuff-private`) auto-inyecta en el prompt los archivos llamados exactamente `AGENTS.md`, `CLAUDE.md` o `*.knowledge.md` (en el proyecto) y `~/.AGENTS.md`/`~/.CLAUDE.md`/`~/.knowledge.md` (globales, solo lectura). Verificado en el binario (lista `["knowledge.md","AGENTS.md","CLAUDE.md"]` + plantilla `{CODEBUFF_KNOWLEDGE_FILES_CONTENTS}`) y en codebuff.com/docs. `AGENTS-root.md` no matcheaba ningún nombre → nunca se cargaba.
- **Solución**: creado **`~/.AGENTS.md`** (copia de `AGENTS-root.md`, 825 B) — global, apunta al protocolo ai-context (INFO-core → SNAPSHOT → CONTINUE). La memoria `ai-context/` estaba intacta; faltaba la puerta de entrada.

### 📁 Archivos modificados/creados

| Archivo | Cambio |
|---|---|
| `~/.AGENTS.md` | **NUEVO** — auto-carga global de contexto en Freebuff |
| `~/data_car/` (6 archivos) | commit `89f74cf` pusheado (sync Base Técnica → ficha) |
| `ai-context/CONTINUE.md` | regenerado (esta sesión) |
| `ai-context/SESION.md` | entrada 2026-08-05 agregada |

---

### ⏳ Pendientes para próxima sesión

1. **Probar auto-carga**: abrir una sesión nueva de Freebuff y confirmar que arranca leyendo INFO-core.md / CONTINUE.md (debería ser automático con `~/.AGENTS.md`).
2. **data_car**: probar en navegador el flujo completo (PDF → construir base → "Sincronizar ficha"). Revisar deps del useEffect de auto-sync en TechnicalDatabase.tsx (converge por el guard `!database` pero conviene simplificar). SESION.md ya supera 30KB → podar a SESION-archive.md.
3. **(Opcional)** Crear `AGENTS.md` por proyecto activo (data_car, widgetos, pwa_securguard…) con instrucciones específicas.
4. **Arrastrados**: `gh auth login` · renombrar repo `enerador-de-boletas` → `generador-de-boletas` · ManUninstaller `versionName` 2.0.0 → 2.1.0 · Mi 10 toggle "Instalar vía USB" (toque manual) · revisar apps restantes del Nubia.

---

### ⚠️ Problemas conocidos

- **gh sin autenticar** — todo push por SSH (funciona con `~/.ssh/id_ed25519`).
- **`~/.AGENTS.md` es solo lectura para el agente** (fuera del proyecto) — editar el original `AGENTS-root.md` y re-copiar (o hacer symlink) para cambios.
- Los knowledge files se inyectan **completos** al prompt → mantener `AGENTS.md` liviano (puntero a ai-context), no pegar memorias enteras.

---

## Stack del usuario (referencia rápida)

```
OS:    EndeavourOS (Arch) · kernel 6.18.39-1-lts
WM:    bspwm (X11) · rice gh0stzk/cynthia · picom
Shell: zsh (Oh My Zsh + Starship) · alacritty · editor VSCodium
CPU:   Ryzen 5 3400G (4C/8T) + Vega 11 · 13GB RAM · 1360x768
Phone: ZTE Nubia Z2352N = laboratorio (Shizuku + ManUninstaller activos) · Mi 10 (tethering)
Disk:  39% usado / 126G libres · ollama + backups en HDD (/media/datos)
Stack: React + TS + Tailwind v4 + Vite → GitHub (maneskinleon-del) → Vercel
Node:  v26.4.0 · npm 11.18.0 · gh CLI (sin auth)
Git:   maneskinleon-del / mangonz970@gmail.com · push por SSH
AI CLI: freebuff v0.0.138 (auto-carga ~/.AGENTS.md) · Antigravity
```

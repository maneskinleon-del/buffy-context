# 🔄 CONTINUE — Handoff entre sesiones

> ⚡ **PRÓXIMA SESIÓN: LEE ESTO PRIMERO**
> Generado: 2026-08-05 (data_car: fixes extractor MG 350 pusheados `6b3e352` · Freebuff "temporarily busy" investigado + wrapper `fb-wait`)

---

## Resumen de la sesión

**Tema principal:** Tres frentes cerrados hoy: (1) se corrigió a fondo el extractor técnico de data_car y se **pusheó el commit `6b3e352`** (transmission_oil captura "2 L" real en vez del "18. L" espurio, torque de rueda, relación de compresión, caracteres corruptos del text-layer); (2) se investigó el mensaje **"Freebuff is temporarily busy"** (HTTP 429, modo limited) y se creó el wrapper **`~/.local/bin/fb-wait`** para reintentar con espera configurable; (3) se verificó el build de producción de la PWA.

---

### ✅ Logros principales

#### 1. 🚗 data_car — Fixes de extracción del manual MG 350 (commit `6b3e352` pusheado)

**Bug crítico resuelto — transmission_oil "18. L":** la keyword `/transmisi[oó]n\s*[:：]/` **no tenía el flag `/i`**. El manual solo usa "**T**ransmisión:" con mayúscula (p.75: "Transmisión: Llene Relleno seca **2 L**"), así que el regex case-sensitive nunca matcheaba y la regla caía en el patrón laxo que capturaba el "18. L" de una tabla de tornillería (p.398). Fue el único `fieldKeyword` de las 16 reglas sin `/i`. Fix: flag `/i` + patrón de capacidad estricto `(\d+(?:[.,]\d+)?)` que rechaza números truncados tipo "18. L" sin perder "2,9 l" → **captura "2 L" @80%**.

**Otras reglas arregladas con evidencia del manual:**
- `wheel_torque`: keywords ampliadas (`tornillos? de rueda`, `pernos? de rueda`, `wheel bolt`) + lookahead que excluye "rueda **dentada**" (sprockets) → **"115-130 Nm" @65% p.517** + nuevo mapeo `→ torqueTornillos` en specsSync.
- `compression`: el manual publica la **relación** ("Índice de compresión 10.5: 1", p.79), no psi → regla renombrada a "Relación de Compresión" con patrón de ratio + bonus de confianza por formato.
- `valve_clearance` (`/v[aá·]lvulas?:/i`), `tire_size` (keyword "tamaño"), `normalizeText` (mapea í→Ì, é→È, ú→˙, ñ→Ò corruptos del text-layer) → desbloquean brake_fluid (DOT4), filtros (BLT200010, FN745), neumáticos (205/55 R16).

**Resultado con `mg350-manual-final.pdf` (1018 págs):** cobertura **83%**, 12 componentes con datos, **7 campos sincronizados** a la ficha (aceiteMotor=4,5 l · aceiteCaja=2 L · refrigerante=7.3 L · bujias=0,9 mm · dimensionNeumaticos=205/55 R16 · capacidadEstanque=55 L · torqueTornillos=115-130 Nm). Validado: lint EXIT 0 + build ✅. 2 archivos, +50/-8.

**Datos que el manual NO publica (reglas quedan sin candidatos a propósito):** `tire_pressure` (solo TPMS sin valores; los "93-123 kPa" son de la tapa del radiador) y `brake_pad` (solo procedimientos, sin espesor mm). No hay correa — el MG 350 usa **cadena** de distribución (sin intervalo de reemplazo publicado).

#### 2. 🧠 Freebuff "temporarily busy" (modo limited / Chile) — investigado y mitigado

**Causa raíz (verificado en el binario `~/.config/manicode/freebuff`):** el mensaje `"Freebuff is temporarily busy. Please try again in a moment."` es la constante `_qH`, disparada **solo con HTTP 429** (`QqH`: `if (A.statusCode !== 429) return null`). Tres niveles de espera, todos **hardcodeados en el binario compilado** (sin config editable):
- Cliente HTTP: `MB$ = {maxRetries: 3, initialDelayMs: 1000, maxDelayMs: 10000}` (408/429/500/502/503/504).
- SDK de AI: `maxRetries: 2` + respeta header `Retry-After` (cap 60s o el backoff).
- Polling de sesión free: `G4$ = 30000` (30 s) + backoff `nl()` exponencial con **cap 300000 ms (5 min)**.

No existe `settings.json` ni env var `CODEBUFF_*` que controle estos valores. Freebuff es **TUI interactiva pura** (solo acepta `login` como subcomando; no hay modo one-shot con prompt).

**Solución creada — `~/.local/bin/fb-wait`** (en PATH, ejecutable, 4.5 KB): launcher de guardia que lanza Freebuff y, al salir, revisa la **cola** (tail 8 KB) del `log.jsonl` de la sesión más reciente (ordenada por mtime real vía `find -printf %T@`, no por nombre). Si el último error fue 429 busy → espera `FB_WAIT_MIN` (default **5 min**) y relanza con `--continue` para retomar la conversación, hasta `FB_MAX_RETRIES` (default 10). Trata Ctrl+C **con** busy reciente como reintentable; Ctrl+C/error genérico sin busy → sale. Valida env vars numéricas. Probado con mocks (5 escenarios OK). Alcance: no reintenta el prompt en vivo (la TUI no termina al ver el busy); automatiza "salir → esperar → relanzar".

#### 3. 📦 data_car — Build de producción verificado
`npm run lint` (tsc) EXIT 0 + `npm run build` ✅ (3.70s, 1684 módulos). Artefactos: `dist/` con index 0.42 kB, CSS 49.67 kB (gzip 8.32), JS 761.03 kB (gzip 225.46). Peso esperado (pdfjs-dist; `chunkSizeWarningLimit` 1000KB).

### 📁 Archivos modificados/creados

| Archivo | Cambio |
|---|---|
| `~/data_car/src/lib/technicalExtractor.ts` | fixes de extracción (commit `6b3e352` pusheado) |
| `~/data_car/src/lib/specsSync.ts` | mapeo wheel_torque → torqueTornillos (mismo commit) |
| `~/.local/bin/fb-wait` | **NUEVO** — wrapper de reintentos ante 429 busy |
| `ai-context/CONTINUE.md` | regenerado (esta sesión) |
| `ai-context/SESION.md` | entrada 2026-08-05 actualizada |

---

### ⏳ Pendientes para próxima sesión

1. **Probar `fb-wait` en vivo**: `fb-wait` (espera 5 min entre reintentos; `FB_WAIT_MIN=10` para más). Verificar que el log de la sesión registra el 429 y que relanza con `--continue`.
2. **data_car**: probar en navegador el flujo completo (PDF → construir base → "Sincronizar ficha"); el agente browser_use falló en este entorno al subir archivos — usar el test Node del pipeline (`tmp_*.ts` + esbuild) o probar manualmente con el preview (`npm run preview -- --port 4173`). Revisar deps del useEffect de auto-sync en TechnicalDatabase.tsx. SESION.md supera 30KB → podar a SESION-archive.md.
3. **(Opcional)** Crear `AGENTS.md` por proyecto activo (data_car, widgetos, pwa_securguard…). Sincronizar `~/.AGENTS.md` con `AGENTS-root.md` (symlink o re-copia si editas el original).
4. **Arrastrados**: `gh auth login` · renombrar repo `enerador-de-boletas` → `generador-de-boletas` · ManUninstaller `versionName` 2.0.0 → 2.1.0 · Mi 10 toggle "Instalar vía USB" · revisar apps restantes del Nubia.

---

### ⚠️ Problemas conocidos

- **gh sin autenticar** — todo push por SSH (funciona con `~/.ssh/id_ed25519`).
- **`~/.AGENTS.md` es solo lectura para el agente** — editar `AGENTS-root.md` y re-copiar (o symlink) para cambios. Los knowledge files se inyectan completos → mantenerlos livianos.
- **Freebuff busy (429)**: el cliente no tiene reintento largo configurable; el header `Retry-After` del servidor es la única palanca que respeta (hasta 5 min). Usar `fb-wait`.
- **Calidad de extracción depende del PDF**: `mg350-parte1*.pdf` dan poca cobertura (capas de texto malas); `mg350-manual-final.pdf` es el bueno (83%).

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
AI CLI: freebuff v0.0.138 (auto-carga ~/.AGENTS.md) · fb-wait para 429 · Antigravity
```

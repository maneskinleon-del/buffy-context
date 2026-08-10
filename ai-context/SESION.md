# 🧠 SESION — Buffy opencode (2026-08-10 · P1 data_car: precios IA + total CLP)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 🛒 data_car — P1 completado: precios de la IA asignados a la lista + total CLP

### Pedido del usuario
Pendiente P1 del CONTINUE (heredado de la sesión 2026-08-08): "elegir pack → agregar a compra → compartir con IA → pegar respuesta → precios asignados + total". `parseAIResponse` y `formatCLP` ya existían en `src/lib/aiShare.ts`; faltaba la UI y la lógica en el panel de compra.

### Lo implementado (`src/components/MaintenancePacks.tsx`, +118 líneas)
1. **Sección "💸 Precios desde la IA"** en el panel Mi compra: textarea para pegar la respuesta JSON de la IA + botón "Asignar precios" + contador `N/M con precio` + fila Total (CLP).
2. **`handleAssignPrices`**: `parseAIResponse(text)` → si no hay `repuestos` → toast de error; si parsea → por cada item de la shopping list busca su precio con `findPrice()` y lo guarda como `price` (unitario) en el item → toast con total o con faltantes.
3. **`findPrice` + `normalizeName`**: match tolerante — minúsculas, sin acentos (NFD), sin contenido entre paréntesis (refs tipo "UJ-1797"), solo alfanumérico, `includes` bidireccional ("Bujías NGK" ↔ "Bujías"). La IA puede variar el nombre (agregar "5W/40", "semisintético") y el match sigue funcionando.
4. **`computeTotal`**: suma `precio × cantidad` de cada item con precio → muestra con `formatCLP`. Los precios viven en el item (`price?: number`) → se persisten en `mg350_shopping_list` → sobreviven recarga.
5. Precio unitario visible por item en la lista (`— $18.490` en verde).

### Verificación (Playwright sobre `vite preview`, hash build `index-D4lIbUUa.js`)
| Caso | Resultado |
|---|---|
| JSON realista (Aceite 18.490 ×4,5 + Filtro 6.990) | Toast "total **$90.195**" ✓ (83.205 + 6.990) |
| Items con precio en lista + "2/2 con precio" + fila Total | ✓ |
| Caso límite: nombres parciales ("Aceite de Motor 5W/40 semisintético", "Filtro de aceite UJ-1797") | Match ✓ → total **$75.000** |
| JSON inválido ("esto no es json", `{"repuestos":[]}`) | Toast de error, 0 errores en consola, no rompe |
| Recarga (reload) | Total y precios persisten (localStorage) |

Typecheck (`npx tsc --noEmit`) y build (`npm run build`) OK.

### Lección
- La transformación **Python incremental** vuelve a ser el método que funciona sobre `MaintenancePacks.tsx` (confirmado por tercera vez; las ediciones con `edit` sobre este archivo no persisten). Ver sesión 2026-08-08.

### ⏳ Pendiente
- **Commit + push del cambio en data_car** (aún sin commitear).

---

# 🧠 SESION — Buffy opencode (2026-08-10 · P0 benchmark context-selection + congelamiento levantado)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 📊 P0 completado: bench-context-selection.sh — el benchmark que desbloquea el congelamiento

### Pedido del usuario
"vamos con los pendientes" + activar modo autónomo → el pendiente P0 del CONTINUE era `bench-context-selection.sh`: el benchmark pendiente que justificaba el próximo cambio en el motor de selección de contexto (congelamiento vigente: benchmark primero, feature después).

### Contexto que lo motivaba
El benchmark anterior (`bench-scale.sh --adversarial`) había demostrado que FTS5 puro NO distingue la aguja cuando los irrelevantes comparten el vocabulario de la query (`scrcpy`/`ZTE` en contextos distintos) — recall 1/2. El CONTINUE decía: "la capa que lo resuelve es el router (context selection), que este benchmark no ejercita".

### Lo implementado
1. **`scripts/tests/bench-context-selection.sh` (NUEVO, ~200 líneas)** — ejercita el pipeline COMPLETO:
   - Sandbox con repo simulado: `Knowledge/` por dominio (Android/scrcpy.md con la AGUJA, Android/ADB.md, Linux/System.md, FreeFire/GameOptimization.md, React/React.md) + manifests de skills mínimos (android-adb, scrcpy-freefire) para que el router los resuelva.
   - Tarea real: **"el teléfono no aparece en scrcpy"**.
   - Etapa 1: `buffy-router.sh --json` → categorías + knowledge files elegidos.
   - Etapa 2: `buffy-search.sh` FTS5 real sobre el índice del sandbox.
   - Métricas: `domain_precision` (¿knowledge del dominio correcto?), `domain_recall` (¿incluyó scrcpy.md + ADB.md?), `spurious_categories`, `search_recall`/`search_leaked` (límite FTS5), `context_chars`/`tokens`/`window_utilization`, `pipeline_healthy`.
   - Flags: `--count`, `--adversarial`, `--json`, `--quick`. Easy = gate (exit 0 si pipeline sano); adversarial = medición (exit 0 si corrió).
2. **Bug propio encontrado al validar:** el contador de `search_leaked` usaba `grep -cE "^(Nota Linux...)"` (anclado a inicio de línea), pero los hits de FTS5 empiezan con el path (`Knowledge/Linux/System.md:1: Nota Linux...`) → medía 0 cuando en realidad FTS5 estaba 100% contaminado. Corregido a grep sin `^`. Lección: los detectores deben considerar que el path antecede al contenido en la salida del search.
3. **`scripts/tests/test-context-selection.sh` (NUEVO)** — 2 tests en la suite: `test_context_selection` (easy: exit 0 + JSON healthy + precision 1.0 + 0 spurious) y `test_context_selection_adversarial` (medición: exit 0 + pipeline_healthy true). Registrado en `run-tests.sh`.
4. **README** — sección "Benchmark de selección de contexto con router (P0 — desbloquea el congelamiento)" + conteos actualizados: **209 full (204 functional + 5 meta) / 193 --quick (188 functional)** + árbol de tests (15 test_*.sh + 2 benchmarks).

### Resultado medido (evidencia)
| Métrica | Easy | Adversarial |
|---|---|---|
| categorías router | Android | Android |
| spurious | 0 | 0 |
| domain_precision | 1.00 | 1.00 |
| domain_recall | 2/2 | 2/2 |
| search_recall (FTS5 puro) | 2/2 | **0/2** |
| search_leaked | 0 | **10/10** |
| pipeline_healthy | true | **true** |

La tesis quedó demostrada: cuando FTS5 puro se contamina por completo (adversarial), el **router resuelve** cargando el archivo del dominio correcto → `pipeline_healthy` se mantiene. Esa es la evidencia que el congelamiento pedía.

### Verificación
- `run-tests.sh --quick`: **193 OK / 0 FAIL** · `run-tests.sh` (full): **209 OK / 0 FAIL**.
- Benchmark standalone: exit 0 en easy y adversarial.

### Lecciones
- **Un benchmark también tiene bugs** — el propio `search_leaked` medía mal (path antecede al contenido). El paso de validación contra el resultado real (¿realmente hay 0 leaked?) destapó el error.
- **El congelamiento cumplió su función:** forzó a medir el pipeline antes de tocar el motor, y la medición confirmó la hipótesis (router resuelve). Ahora cualquier cambio futuro tiene baseline.

---

# 🧠 SESION — Buffy opencode (2026-08-10 · scripts Gmail/Drive + update opencode)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 📧🗂️ Scripts de Google Apps Script: Gmail Organizer V3 + Drive Organizer Pro

### Pedido del usuario
"Estaba viendo unos scripts de Google, para ordenar Gmail y Drive que tengo, pero no sé si la sesión del teléfono te dejó la info en el repo" → la sesión anterior (desde el teléfono) NO había quedado registrada en buffy-context; se reconstruyó desde el historial de prompts de opencode (`~/.local/state/opencode/prompt-history.jsonl`).

### Lo hecho
1. **`~/proyectos/gmail-scripts/`** = Gmail Organizer v3 (`organiza_gmail_V3`, scriptId `1yqqZXC4kysIlMMbY57Bi6Ft5Jf5mtO3fUX9EnT41BJtCOnMXmQ01I_sK`): clasifica la bandeja en etiquetas (Compras, Telecom, Bancos, Gobierno, Trabajo, Facturas, Envíos, Spam, ⭐Importante + etiquetas por empresa: BancoEstado, Tenpo, Fonasa, Mercado Libre, AliExpress, WOM...). Rate limiting + reintentos + reanudación tras pausa/cuota; **fix de paginación**: snapshot único con `search()` en vez de `getInboxThreads(pos)`; `cleanup_tmp.js` = limpieza one-shot de etiquetas de usuario (corre una sola vez vía `cleanupEtiquetasDone` en ScriptProperties).
2. **`~/proyectos/gmail-scripts-otro/`** = Drive Organizer Pro v5.0 (`ordenar_drive_pro`, scriptId `1TW8pIdyQAUeAI7ZznVY4KCZgZtGirq_leLUX8vXWQa1e0i6prPIpzBOu`): modos MAESTRO (todo el Drive, BFS limitado) / ESPECÍFICO (carpeta por ID) × PRUEBA (simula) / REAL (mueve). Motor de reglas con prioridad (MIME > nombre), carpetas administradas (Scripts, Documentación, Android, Configuraciones, Multimedia, Backups, Web, Recursos, Sin clasificar, Comprimidos, Chats) y excluidas (Google Fotos, Trash...). Rate limiting estilo Gmail Organizer + triggers cada 10 min + reanudación por cola de carpetas.
3. **Sincronizados con la web** (`script.google.com`) vía `clasp pull` — "los de la página ya tienen mejoras" (el usuario los había mejorado desde la web). Ambos quedaron con **commit inicial** local:
   - `gmail-scripts`: `a207071` — "chore: estado sincronizado con Apps Script (organiza_gmail_V3) via clasp pull" (13 archivos, 1747 líneas)
   - `gmail-scripts-otro`: `610a040` — "chore: estado sincronizado con Apps Script (ordenar_drive_pro) via clasp pull" (11 archivos, 1738 líneas)
4. **opencode actualizado** a **1.18.16** (hoy 15:19, `~/.npm-global/lib/node_modules/opencode-ai`) — la actualización que "no se realizó" en la sesión anterior finalmente se completó. Verificado: `opencode --version` = 1.18.16 = última de npm.

### Lecciones
- **La sesión desde el teléfono NO quedó en buffy-context** → los datos solo existían en disco (los repos git) y en el historial de prompts de opencode. Lección: tras una sesión que toca proyectos nuevos, registrar en SESION.md/PROJECTS.md aunque no se haya "programado" el cierre. Reconstruible vía `~/.local/state/opencode/prompt-history.jsonl`.
- Ambos repos son **git locales sin remote** — no están en GitHub. Los scripts viven en la nube de Google (source of truth) y el repo local es el backup.

---

# 🧠 SESION — Buffy opencode (2026-08-09 · cierre noche)

> Contexto de lo implementado durante esta sesión. Corrida en **opencode**.

---

## 🎮 Evaluación Lyxel + Mantis — falsos caminos descartados con evidencia + lección de retroalimentación activa

### Pedido del usuario
Evaluar Lyxel (GUI scrcpy de GitHub) y Mantis Gamepad Pro como keymapper alternativo. **Lección de proceso que dejó el usuario al cerrar**: "quiero usar Mantis para scrcpy y tú me dices algo así: *¿tenés gamepad? porque esta app está diseñada para eso*" → **retroalimentación activa ANTES de instalar/probar herramientas**: verificar que la herramienta cubre el caso de uso exacto.

### Lo hecho
1. **Lyxel Linux v1.0.3 evaluado** (`/tmp/opencode/lyxel-unpack/lyxel-v1.0.3-linux-x64/`): app Avalonia/.NET 8 self-contained, trae scrcpy 4.1 + adb 37.0.0. **No incluye el Mapeador** (solo Windows: WPF propietario, código cerrado, no portable). Arrancó en el sistema (ventana 1344x666, PID 357612) — la GUI duplica funcionalidad del `scrcpy-freefire.sh` (perfiles, optimizaciones ADB) sin el mapeador ni el cleanup. **No aporta. Cerrado** (kill -9 de LyXel + adb track-devices hijo).
2. **Mantis Gamepad Pro** — es **mapper de GAMEPAD físico (control Xbox/PS/bluetooth), NO de teclado/mouse**. No sirve para jugar con teclado+mouse desde PC. Se instaló y activó de todos modos (oficial Play Store v3.4.8, versionCode=142):
   - APK parchado de Appteka (`app.mantispro.gamepad_3.4.1_138.apk`, firma `YOUAREFINISHED.RSA` = CN youarefinished / O Google falso / RSA-1024 SHA1) → **descartado**: Google Sign-In falla siempre (`ApiException: 10` — SHA-1 no coincide con Firebase) → loop infinito. Desinstalado.
   - Oficial Play Store v3.4.8: permisos (`SYSTEM_ALERT_WINDOW` allow, `GET_USAGE_STATS` allow, deviceidle whitelist), login con cuenta Maneskin Leon, **activación vía script interno `buddyNew.sh` por ADB** (`sh /sdcard/Android/data/app.mantispro.gamepad/files/buddyNew.sh` → "Mantis Buddy Conectado") — el flujo on-device Wireless Debugging falla (diálogo modal expira los códigos). Servicio `app.mantispro.gamepad:i` activo.
3. **Mantis ≠ Octopus corregido** en Knowledge: el baneable por clonación es **Octopus** (Garena baneó 829K cuentas feb-2026); Mantis usa NMC sin clonar (riesgo bajo). Mantis v3.x tiene suscripción Pro (~$9.99) e inestabilidad reportada.
4. **Conclusión**: **GG Mouse Pro 2 + scrcpy-freefire.sh es el setup correcto** — keymapper de teclado para PC, confiable, no-clonación. Lyxel y Mantis fueron dos falsos caminos eliminados con evidencia.

### Lecciones (registradas en la skill)
- **Regla de oro en `~/.agents/skills/scrcpy-freefire/SKILL.md`**: retroalimentación activa ANTES de instalar — ¿la herramienta mapea **teclado/mouse** (GG Mouse Pro 2, Panda, XtMapper) o **gamepad** (Mantis)? ¿Corre en Linux? ¿Requiere login de Google (APK parchado → imposible)? Mantis NO reemplaza a GG Mouse Pro 2.
- **APK cracked/parchado + login de Google = inutilizable por diseño** (SHA-1 del firmante no coincide con Firebase). Señal: firma `YOUAREFINISHED.RSA`, O=Google spoofeado, RSA-1024.
- **El flujo Wireless Debugging on-device es frágil en ZTE** (diálogo modal del sistema expira los códigos) — el script `buddyNew.sh` de la propia app vía ADB shell es el método confiable.
- Commits de hoy: `4b1ad07` (Keymappers.md), `a113b9d` (lección retroalimentación activa en skill + Keymappers + CHANGELOG). Todo pusheado.

---

# 🧠 SESION — Buffy opencode (2026-08-09)

> Contexto de lo implementado durante esta sesión.

---

## 🧠 Auditoría v2: paradoja del contador resuelta + benchmark adversarial

### Pedido del usuario
Revisión externa encontró 3 fallos nuevos en lo implementado la sesión anterior: (1) **paradoja del contador** — `doc_truth_check "$PASS"` recibía 198 y luego la fase sumaba 4 → 202, con README/CONTINUE diciendo números distintos; (2) **bug RC en test-scale.sh** — `OUT=$(...) || true` enmascaraba el exit code del benchmark; (3) **benchmark léxico fácil** — los irrelevantes no compartían vocabulario con la query.

### Lo hecho
1. **Contador canónico functional vs meta (Opción A)**: `run-tests.sh` captura `PASS_FUNCTIONAL` antes de la fase documental; `doc_truth_check` valida el functional contra el README (números estables) y el TOTAL contra `PASS+1` al final (se cuenta a sí mismo → detecta cualquier crecimiento de la fase meta). Resumen: `Functional: 200 OK · Meta: 5 OK · Total: 205 OK`.
2. **Fix RC en test-scale.sh**: quitado el `|| true` que mataba el exit code (RC siempre 0); ahora un benchmark fallido (exit 1) se detecta por RC y falla la suite. Verificado con simulación.
3. **Benchmark adversarial** (`--adversarial` en bench-scale.sh + test_scale_adversarial): los irrelevantes COMPARTEN `scrcpy`/`ZTE` en contextos distintos. **Hallazgo medido**: con query de 2 términos, BM25 puro ahoga la aguja con menor vocabulario exclusivo (recall 1/2, healthy=false). Es medición honesta del límite de FTS5 puro — la capa que lo resuelve es el router (context selection), que este benchmark no ejercita. Por eso es medición (exit 0 si corrió), no gate.
4. **Suite**: **205 OK / 0 FAIL** (full, 200 functional + 5 meta) · **189 OK / 0 FAIL** (--quick, 184 + 5).

### Lecciones
- La paradoja del contador es el tipo de bug que solo aparece cuando un sistema se mide a sí mismo — y la solución (functional/meta/total) lo hace más legible además de correcto.
- El adversarial demostró el límite REAL de FTS5 puro: con vocabulario compartido, BM25 no distingue la aguja con menos términos exclusivos. Siguiente benchmark natural: **bench-context-selection** que incluya el router.

---


### Pedido del usuario
Revisión del sistema detectó 2 inconsistencias documentales (README decía "3 sesiones" y "168 checks" cuando la regla real es 5 entradas/30KB y la suite 196→198) y propuso convertirlas en mecanismo anti-drift + benchmark adversarial de memoria.

### Lo hecho
1. **`test-documentation.sh`** (nuevo): fase final `doc_truth_check` en `run-tests.sh` — el número canónico se **deriva del PASS real del runner**, no se hardcodea. README debe declarar el mismo número; si la suite crece y nadie actualiza la doc, el CI rompe (verificado: README mintiendo → FAIL + exit 1).
2. **`bench-scale.sh`** (nuevo): benchmark P0 — siembra 500 hechos en índice FTS5 real (2 relevantes a la tarea "scrcpy ZTE", 498 irrelevantes) y mide recall, contaminación (leaked), bytes/tokens de contexto y utilización de ventana. **Resultado: recall 2/2, leaked 0, healthy**.
3. **`test-scale.sh`** (nuevo): integra el benchmark a la suite con `--quick`.
4. **README corregido**: "Últimas 5 sesiones", "198 checks (182 --quick)", "13 test_*.sh" + sección anti-drift y benchmark.
5. **Suite completa**: **202 OK / 0 FAIL** (full) · **186 OK / 0 FAIL** (--quick).

### Lecciones
- El sistema detectaba drift de hechos pero no de su PROPIA documentación → nueva categoría DRIFT documental cubierta por el runner.
- El benchmark demostró el problema real de FTS5: `snippet()` envuelve los términos de la query en `«»`, rompiendo greps sobre los resultados — los detectores deben usar substrings que NO estén en la query.

---


### Pedido del usuario
"Hicimos cambios importantes en el repo de buffy-context, ¿puedes adquirir esas nuevas habilidades?" → pull → 2 features nuevas (memoria curada + búsqueda FTS5). Y al final: "voy a matar esta sesión y lanzaré otra para ver los cambios — ¿es seguro?"

### Lo hecho
1. **Pull + rebase** del repo (`851c6c4..c1b9237`): llegaron `feat(memory)` (buffy-memory.sh + memory_engine.py, 196 tests) y `feat(search)` (buffy-search.sh, índice FTS5).
2. **Symlinks creados** en `~/.local/bin/`: `buffy-memory.sh`, `buffy-search.sh`, `buffy-source.sh`, `buffy-verify.sh`.
3. **Fix de symlinks (commit `849ac96`)**: `buffy-memory.sh`, `buffy-context.sh`, `buffy-router.sh` no resolvían `readlink -f` → con symlink, `SCRIPT_DIR` apuntaba a `~/.local/bin/` y el `source lib/...` fallaba. Verificado en vivo: router (--help), context (SNAPSHOT generado), memory (add/stats/render ok).
4. **Versiones sincronizadas (commit `5431ecf`)**: `buffy-source.sh --resolve` detectó stale real (kernel 6.18.39→6.18.42, node 26.4.0→26.7.0, npm 12.0.1→12.0.2) → corregido INFO-core + CONTINUE (incl. mención histórica que el extractor tomaba como valor) → `buffy-verify`: **trust 100%** (19 hechos, 0 stale, 0 expired).
5. **Memoria real inicializada** en `~/.buffy/memories/` (MEMORY 3 entradas 18% · USER 3 entradas 26%): WM bspwm, kernel/node/npm reales, stack, preferencias de mangonz (acción autónoma, verificación propia, español directo).
6. **SNAPSHOT regenerado** + doctor **CONSISTENTE** (64 OK, 1 warning preexistente form-filler).

### Lecciones
- Los scripts del repo asumen invocación por ruta real; al ser linkeados a `~/.local/bin/`, todo script que use `SCRIPT_DIR` para sourcear `lib/` necesita el patrón `readlink -f` (ya estaba en `buffy-source.sh`, faltaba en los demás).
- `buffy-verify.sh --update-facts` marca `stale` comparando doc vs sistema; tras corregir la doc hay que re-ejecutarlo para que suba a `verified` (conf 1.0).
- CONTINUE.md es un handoff vivo: las menciones históricas de versiones viejas en el texto pueden confundir a `buffy-source.sh` (el extractor toma la primera mención como valor actual) → reformular sin el patrón de versión.

---

# 🧠 SESION — Buffy opencode (2026-08-09)

## 🧠 Memoria curada estilo Hermes — brecha 2 cerrada (`buffy-memory.sh`)

### Pedido del usuario
"Tengo batería nuevamente, seguimos con la implementación para tener lo que tiene Hermes" — la sesión previa implementó la brecha 1 (búsqueda FTS5 de sesiones, `buffy-search.sh`); quedaba la **brecha 2: memoria curada** (MEMORY.md + USER.md con límites duros, snapshot congelado, tool add/replace/remove).

### Implementado (réplica fiel del `memory_tool.py` de Hermes, sin dependencias)
- **`scripts/lib/memory_engine.py`** — motor: stores `MEMORY.md` (2.200 chars) + `USER.md` (1.375 chars), entradas separadas por `\n§\n` (multiline), dedupe con primer-ocurrencia, replace/remove por **substring único** (`old_text`, ambigüedad → error con previews), **límites duros** con rechazo + sugerencia de consolidación, **lock fcntl** exclusivo, **escritura atómica** (tmp+rename 0600), **guard de drift** con `.bak.<ts>` (nunca sobrescribir lo que no hace round-trip — issue #26045 de Hermes), **guard de lectura fallida** (ilegible ≠ vacío → aborta), **batch atómico** all-or-nothing contra el presupuesto final, y **escaneo de inyección** mínimo (la memoria se congela en el system prompt).
- **`scripts/buffy-memory.sh`** — CLI: `list`, `render` (snapshot de prompt), `stats`, `add`, `replace`, `remove`, `batch`; flag `--json`; `BUFFY_MEM_DIR` para stores alternos (tests/PC). Fui el primero en usarla de verdad: la memoria del dispositivo quedó inicializada (MEMORY 3 entradas 12% · USER 2 entradas 15%).
- **`buffy-doctor.sh`** — sección "🧠 Memoria curada": directorio, presencia, límites por store (63 OK / 0 err, healthy).
- **Protocolo**: `LOAD_CONTEXT.md` (Paso 1.5 — snapshot congelado + semántica de guardado), `~/AGENTS.md` del dispositivo (sección "Memoria curada"), `README.md` (feature + script).
- **Tests**: `test-memory.sh` (8 suites) + gate de sintaxis de `buffy-memory.sh`. **Suite: 196 OK / 0 FAIL** (antes 168).

### Verificación en vivo (lo que se probó antes de versionar)
add/replace/remove básicos, duplicado, replace ambiguo ('Mi 10' en 2 entradas → "be more specific"), no-match, render con header+uso+contenido, stats, límite excedido (2.500 chars reject), **drift real** (entrada manual de 2.400 chars → DRIFT + `.bak` + rechazo; `add` post-drift sigue funcionando), batch correcto y batch con op rota (nada se aplica).

### Lecciones
- El **round-trip check** (raw ↔ re-serialize) es la señal #1 del drift; la #2 es "una entrada > límite del store entero" (el parser la atrapa cuando un escritor externo appendó texto libre). No confundir "contenido manual que cabe como entrada válida" (NO es drift — Hermes hace exactamente lo mismo) con "contenido que rompe el formato".
- El patrón de **`skip_drift` solo para `add`** (append nunca clobber) + drift obligatorio para replace/remove es la semántica que impide perder memoria escrita a mano.
- En los tests, `$TMPDIR` con `BUFFY_MEM_DIR` aislado basta (sin sandbox de repo): el motor es independiente del repo.

---

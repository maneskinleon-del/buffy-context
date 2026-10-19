# HANDOFF — GameBoost Pro FASE B (governor térmico cableado) — 2026-10-19

## Estado del repo GameBoostManu

| Ref | Hash | Nota |
|-----|------|------|
| Rama de trabajo `phase-b-governor` | `f79ac0a` | = origin (pusheada); local |
| `main` | `0e39226` | **intacto, sin merge** |
| Prerelease `thermal-m8-governor` | asset `GameBoostPro-debug-f79ac0a.apk` | SHA-256 verificado (descargado == compilado): `0949819ad5a3c454916471ef6d99db9e22bdcf5bf14b64959da5135703f071e0` |
| Release estable `checkpoint-b190221` | — | **intacta**, no tocada |

Commits de FASE B (ambos en `origin/phase-b-governor`):
- `5db03ce` — Cable de `ThermalGovernor` al `WatchdogManager`: loop de 2 s sobre `systemMetrics` → `onTick(cpuTemp, batteryTemp, idx)`; applier vía `setActiveProfile(id, isManual=false)`. Fixes previos: entry/restore eran **dead-code en FASE A** (la decisión calculada nunca llegaba al return); umbrales por NIVEL según el KDoc; cooldown interno de 120 s activado de verdad.
- `f79ac0a` — HA-B2: señales separadas. NA-total SOLO si faltan AMBAS señales; con cpu=NaN decide con batería sola.

## Items del operador (fuente: operador — la captura `~/session.log` NO existe en disco)

- **Item 8:** el guard fue **correctivo en el M8** (su captura previa actual).
- **Item 9:** señal del M8 **cpu-0-0=44600** en milidegrees → **44.6°C**.
- **Umbrales vigentes (defaults FASE A, sin calibrar con datos reales):**
  CPU: T_S(balanced)=55°C, T_S(saver)=60°C, emergencia 85°C (×10 ticks).
  Batería: T_B(balanced)=40°C, T_B(saver)=43°C. Dwell entrada 30 s,
  restore 60 s con histéresis (T_S−10 / T_B−3), cooldown interno 120 s.
- **Resultados:** governor cableado + decisión con señales separadas +
  tests 15/15 (`ThermalGovernorTest`) + suite completa verde (`BUILD
  SUCCESSFUL`, 47 tasks). Smoke en ZTE (serial redactado): default OFF
  confirmado (prefs sin la key), cableado probado con pref inyectado vía
  `run-as` con backup y restauración — loop sin excepciones, inerte con
  cpuMax=NaN del ZTE.

## Bloqueado / pendiente

- **B2 real (calibración CPU):** requiere captura en el M8 →
  `logcat -s ThermalSession > ~/session.log` → `python3 tools/summarize_session.py ~/session.log`
  → derivar T_S/T_B del p95/median → recalibrar sobre `phase-b-governor`.
  El M8 no estaba conectado a adb (solo el ZTE, que reporta cpuMax=NaN).
  NO se fabricaron números de calibración.
- **Reglas permanentes:** NO mergear a main; NO tocar `checkpoint-b190221`;
  el watchdog térmico sigue **apagado por defecto** (`thermal_watchdog=false`
  — el cableado no cambia ese default).
- Post-merge (cuando la rama aterrice): el modo batería solo entra si la
  señal queda **sostenida** (≥43°C con dwell de 30 s — los picos de
  la lectura de batería no disparan); el freno de emergencia es
  solo-CPU por diseño.

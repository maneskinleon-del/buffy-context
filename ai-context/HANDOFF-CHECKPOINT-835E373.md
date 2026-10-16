# GameBoost Pro — cierre de ciclo checkpoint-835e373

**Fecha: 2026-10-15**

═══════════════════════════════════════════════════════════════

## Estado del repo

- **Estado: retomado 2026-10-15 → backlog en progreso**
- main = 5dcb473 (retomada; cierre del checkpoint: 2a33679)
- Tag: checkpoint-835e373 → 751eeff (versionCode=3)
- Working tree limpio, todo pusheado.

## Release publicado

- URL: https://github.com/maneskinleon-del/GameBoosterManu/releases/tag/checkpoint-835e373
- Asset: GameBoostPro-debug-835e373.apk (18.4 MB)
- SHA-256: cf4a84d61c3f544c61ac92054db8079494e499f3f194388b7c501854c364938f
- Verificado end-to-end (download → hash → install en ZTE) ✓

## Ciclos cerrados en este checkpoint

- Mapper fix (detección ztezscreenshot + logging reason)
- Modo sin accesibilidad (switch + botón onboarding)
- Shizuku sin crash en cold start (fix P0)
- Overlay sync (perfil reflejado en todos los estados)
- Thread safety en FloatingPanelManager
- Schema migration fail-loud
- Dead code removal (ShizukuServiceConnection + IShizukuService.aidl)

## Backlog (por prioridad)

1. ~~TODO ShizukuExecutor — actualizar con decisión de NO migrar a UserService.~~
   **CERRADO 2026-10-15 en `5dcb473`**: decisión documentada en el KDoc de
   `ShizukuExecutor.kt` (tests 125/0).
   Referencia: auditoría comparativa con GG Mouse Pro 3 (2026-10-14).
2. ~~docs/audits/2026-10-14-ggmouse-comparison.md — registrar el informe
   de la auditoría comparativa (evidencia que en 6 meses nadie recordará).~~
   **CERRADO 2026-10-15 en `3b30a9e`**: informe transcrito íntegro (tabla de
   8 columnas, hallazgos, limitaciones) en
   `docs/audits/2026-10-14-ggmouse-comparison.md` (64 líneas).
3. Recomendación B (dead listener Shizuku Plus) — revisar changelog del fork,
   medir latencia actual del polling vs event-driven, decidir.
4. ~~R8/ProGuard — release hardening. Reglas -keep para Shizuku/Room/Compose.~~
   **CERRADO 2026-10-15 en `e7646b5` (R8 done vía FASE A).**
   Registro: minify + shrinkResources sobre buildType DEBUG con
   `-dontobfuscate`, 1 sola regla keep (`newProcess` de Shizuku,
   private static/reflexión, consumer rules del AAR vacías);
   APK 18.4 MB → 4.6 MB (−74.89%), tests 125/0, device checks 6/6
   (Shizuku OK ×17, sin degradación, mapper `Perfil: mapper=false, ext=true`
   en Room, prefs OK, crash 0 tras 2+ min con FF, Room íntegro).
   **FASE B no aplicable en debug** — no es un fallo: AGP 8.5 desactiva
   la ofuscación en builds debuggable por diseño (verificado: 6293/6344
   clases identidad en mapping.txt, sin `-dontobfuscate` en ninguna config).
   Referencia: issuetracker.google.com/issues/306202752.
5. Selector de mapper parte 2 — UI + SharedPreferences + integración
   en checkExternalDevices. MapperDetection.kt ya está commiteado, sin caller.
6. Schema migration explícita — prep para usuarios reales.
7. Release signing config (BAJA prioridad) — si se quiere ofuscación real,
   migrar de APK debug a APK release firmado. Requiere keystore +
   signingConfig + ajustar el flujo de publicación (README, Release GitHub,
   CI). Estimado: 2-3 rondas.
8. ~~Métrica de temperatura en overlay ("🌡 0°C" siempre).~~
   **CERRADO 2026-10-15 en `acdff69`** (no existía como item previo en el
   backlog — se registra aquí ya cerrado).
   - Fix aplicado. PREVENTIVO: el guard de `parseThermal()` (≤0 o >150°C →
     null) no se activa en ningún device verificado.
   - Causa raíz: `NaN.toInt() == 0` cosmético + SELinux bloquea `thermal_zone*`
     a uid shell en ZTE (avc denied visible en logcat de la app).
   - Descartados: B (vía Shizuku — shell uid 2000 tampoco lee) · D (battery
     temp) queda como OPCIÓN FUTURA para recuperar el throttling del Watchdog
     en devices sin sensor CPU legible (thresholds distintos: ~40/42/45°C
     batería, no CPU).
   - Nota: valores crudos entre 150 y 1000 se rechazan (un device que
     reportara en décimas de grado, p.ej. "450" = 45,0°C, quedaría NaN;
     antes devolvía 450°C — peor, no es regresión).
   - Tests: 134/0 (125 + 9 ThermalParseTest).
9. Verificar lectura de `thermal_zone0/temp` en Mi 10 y Poco M8 cuando
   estén accesibles (deciden si el fix preventivo basta o el sensor es
   legible en esos devices).

## Convenciones vigentes

- Evidencia cruda (git show, cat, grep, logcat), no summaries.
- Diff real antes de cada commit.
- Plan-audit antes de escribir código para PRs medianos.
- Push-back bidireccional verificado (grep antes de afirmar).
- Scripts en /tmp/ para comandos compuestos (workaround del tooling).

## Device

- ZTE Z2352N (Android 13), serial (serial redactado).
- Shizuku Plus activo (fork af.shizuku.plus.api).
- GG Mouse Pro 3: com.zjx.ztezscreenshot v3.1.13 (vcode 434).
- APK instalado: versionCode=3 (checkpoint-835e373).

---
name: android-project-setup
description: Automatiza el setup completo de proyectos Android locales del usuario (GameBoost Pro, ManUninstaller, GameBoostPro): verificar conexión ADB, compilar con Gradle, instalar el APK en el teléfono (ZTE Nubia / Xiaomi Mi 10), conceder permisos (Shizuku, overlay, batería) y lanzar la app. Úsala cuando el usuario pida compilar, instalar, probar o hacer setup de una app Android, o conceder permisos de Shizuku/overlay en el dispositivo.
---

# Android Project Setup

Automatiza el ciclo build → install → permisos → launch de los proyectos Android del usuario
(`~/proyectos/autoscript-mobile-interface` = GameBoost Pro, `~/proyectos/ManUninstaller`,
`~/proyectos/GameBoostPro`). Los comandos se ejecutan contra el dispositivo ADB conectado
(generalmente el ZTE Nubia Z2352N, serial `320344802623`).

## Cuándo usar

- "Compilá/instalá/probá la app X en el teléfono"
- "Hacé el setup de GameBoost Pro" / "dame permisos a la app en el dispositivo"
- "Conectá el teléfono y preparalo para instalar"
- Fallas de build/instalación en proyectos con `build.gradle.kts` + `gradlew`

## Workflow

### 1. Detectar y caracterizar el dispositivo

Ejecutar `scripts/check_device.sh` (con serial si hay más de uno). Confirmar: modelo, plataforma
(`ro.board.platform`), Android/API, presencia de Shizuku y rish. Si no hay dispositivo:
`adb devices` y pedir que conecten el teléfono (USB debugging activo).

### 2. Identificar el proyecto

- Proyecto con `app/build.gradle.kts` + `gradlew` → proyecto estándar (GameBoost Pro: namespace
  `com.example`, AGP 8.5.0, Kotlin 2.0, Compose, Shizuku 13.1.5, Gradle wrapper 9.3).
- Leer `AGENTS.md` del proyecto si existe (reglas anti-hallucination: no inventar APIs ni imports).
- Determinar `applicationId` desde `app/build.gradle.kts` si hace falta.

### 3. Compilar

Ejecutar `scripts/build_install.sh <ruta-proyecto> [applicationId]` desde el directorio del proyecto:

```bash
bash ~/.agents/skills/android-project-setup/scripts/build_install.sh ~/proyectos/autoscript-mobile-interface com.example
```

El script corre `./gradlew assembleDebug --console=plain`, instala el APK con `adb install -r`
y lanza la activity launcher. Si el build falla: leer el error completo (no solo el tail),
verificar `gradle/libs.versions.toml` y compilar de nuevo. No inventar dependencias: revisar el
version catalog antes de proponer cambios.

### 4. Conceder permisos

Ejecutar `scripts/grant_permissions.sh <paquete>` — aplica el set estándar (Shizuku API vía
`pm grant`, overlay `SYSTEM_ALERT_WINDOW`, `GET_USAGE_STATS`, `RUN_IN_BACKGROUND`,
whitelist de batería). Detalles y troubleshooting en `references/permissions.md`:

```bash
bash ~/.agents/skills/android-project-setup/scripts/grant_permissions.sh com.example
```

- Si el `pm grant` de Shizuku falla: reactivar el servidor con
  `adb shell sh /data/local/tmp/shizuku_starter.sh` y reintentar.
- Overlay/background: verificar con `appops get` (debe decir `allow`).
- **AccessibilityService no se concede por ADB**: abrir
  `adb shell am start -a android.settings.ACCESSIBILITY_SETTINGS` para que el usuario lo active.

### 5. Verificar

- App instalada: `adb shell pm path <pkg>`
- App corriendo: `adb shell pidof <pkg>`
- Logs de la app: `adb logcat -v threadtime -T 1 | grep -iE "GameBoost|FATAL|Caused by|AndroidRuntime"`
- Si el proyecto trae `capturar_logs.sh` o `medir_rendimiento.sh`, usarlos para captura/medición.

## Particularidades de los dispositivos

Ver `references/devices.md`:

- **ZTE Nubia Z2352N** (ums9620, Unisoc T820): encoder `c2.unisoc.avc.encoder`, Android 13.
- **Xiaomi Mi 10** (sm8250): encoder `OMX.qcom.video.encoder.avc`.
- **Device Admins ignoran el force-stop**: usar `pm disable-user` (y restaurar con `pm enable` +
  `dpm set-active-admin`) — ver devices.md para el receiver de MacroDroid.

## Scripts incluidos

| Script | Función |
|---|---|
| `scripts/check_device.sh` | Detecta y caracteriza el dispositivo conectado |
| `scripts/build_install.sh` | Build + install + launch de un proyecto |
| `scripts/grant_permissions.sh` | Set estándar de permisos (Shizuku/overlay/batería) |

## Reglas

- No inventar APIs de Shizuku ni imports: verificar en el código real del proyecto.
- No asumir el `applicationId`: leerlo de `app/build.gradle.kts` (o pasarlo explícito).
- Si el dispositivo pide autorización USB debugging, avisar al usuario.
- Los permisos de Accessibility se activan manualmente — nunca afirmar que se concedieron por ADB.

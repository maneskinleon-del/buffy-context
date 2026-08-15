# 🧪 Laboratorio ZTE Nubia — Setup, inventario y purga

> Dispositivo de pruebas principal: Free Fire + scrcpy + GG Mouse + ADB/Shizuku/AutoJS.
> Serial: `320344802623` · Modelo: **ZTE Z2352N** (P820F03) · **Android 13** (API 33) · security patch `2025-06-05`.
> Prerrequisitos activos: **Shizuku** (corriendo) + **ManUninstaller v2.1.0** (instalado vía `pm install`, verificado con Shizuku ACTIVE).

---

## 🎯 Propósito del lab

- Jugar **Free Fire** (`com.dts.freefireth`) desde el PC vía scrcpy con pantalla alargada.
- Probar **keymappers** (GG Mouse Pro, Mantis, Panda) y scripts de **AutoJS6**.
- Probar **herramientas de administración** (Shizuku, ManUninstaller, debloat, engineering mode) sin riesgo en el teléfono principal.
- La ROM stock ZTE **no bloquea la instalación por ADB** (`pm install` directo funciona) — a diferencia de MIUI/HyperOS.

## ⚙️ Stack del lab (NO tocar — verificado 2026-08-03)

| Componente | Paquete | Rol |
|---|---|---|
| Free Fire | `com.dts.freefireth` | El juego del lab |
| Termux + API + Widget | `com.termux`, `com.termux.api`, `com.termux.widget` | Terminal / scripts |
| Shizuku | `moe.shizuku.privileged.api` | Privilegios sin root (prerrequisito de ManUninstaller) |
| AutoJS6 | `org.autojs.autojs6` | Automatización de botones del juego |
| MacroDroid (+helper) | `com.arlosoft.macrodroid`, `com.arlosoft.macrodroid.helper` | Único **Device Admin** activo |
| ManUninstaller | `com.user.manuninstaller` | Desinstalación en lote vía Shizuku |
| Launchers | `com.launcher.hype`, `bitpit.launcher`, `com.teslacoilsw.launcher` | Launchers alternativos |
| GG Mouse | `com.zjx.ztezscreenshot` | Keymapper de mouse (screenshot service) |
| sndcpy | `com.rom1v.sndcpy` | Audio del teléfono al PC |
| Debloat/herramientas | `org.samo_lego.canta`, `rikka.appops`, `in.hridayan.ashell`, `dev.zwander.installwithoptions`, `ru.maximoff.apktool`, `com.smartpack.packagemanager`, `net.kollnig.missioncontrol` | Gestión de apps |
| Kustom | `org.kustom.widget`, `org.kustom.weather` | Widgets |
| Gaming de sistema | `cn.nubia.gamelauncher`, `cn.nubia.keymapcenter`, `cn.nubia.gamepad` | Launcher/mapeo de teclas/gamepad nativos |
| Engineering mode | `com.zte.emode` | Modo ingeniería (útil para el lab) |

## 🚫 Apps críticas del sistema (NO tocar NUNCA)

| Categoría | Paquetes |
|---|---|
| Launcher | `com.zte.mifavor.launcher` |
| Bloqueo | `com.zte.mfvkeyguard.resource` (keyguard) |
| Setup inicial | `com.zte.setupwizard` |
| Biometría | faceverify, fingerprints |
| Gestión de dispositivo | `zdm*` (device manager) |
| Teclado | `globalzboard` |
| Sistema base | `androidzte`, `permissioncapsule`, `powersavemode`, `zgesture`, `heartyservice`, `aiengine` (usado por sistema), overlays |

## 🧹 Purga realizada (2026-08-03)

**Apps de usuario borradas (22 — `pm uninstall --user 0`):** `com.example` (basura), 4 PWAs `org.chromium.webapk.*` (huérfanas), 9 apps de IA (ChatGPT, Claude, Grok, DeepSeek, Kimi, Gemini Pro, Qwen, Perplexity, Bard) y 8 financieras (MercadoPago, MercadoLibre, PayPal, Tenpo, Onepay, Tapp, WOM, Binance). Resultado: **90 → 68 apps de usuario**. Liberó ≈ 1.8–2.2 GB (APK + datos, sin residuos en `/data/data`).

**Bloat de fábrica ZTE deshabilitado (25 — `pm disable-user`, 100% reversible):**

```
zte.com.cn.filer          zte.com.cn.alarmclock      cn.zte.recorder
com.zte.storagecleanup    com.zte.privacyzone       com.zte.onekeycp
com.zte.livewallpaper     com.zte.easymode          com.zte.linkspeedup
com.zte.womreceiver       cn.nubia.inspiredwallpaper com.zte.beautify
com.zte.beautifyadapter   com.zte.appsimcardfilter  cn.nubia.externdevice
com.android.ztescreenshot cn.nubia.gamehighlights   cn.nubia.gamenotes
com.zte.flagreset         com.zte.heartyservice.strategy
com.zte.zbackup.platservice com.zte.aiengine        com.zte.burntest.camera
cn.nubia.gamehelperline   cn.nubia.gamehelpmodule
```

**Nota:** `com.zte.ztescreenshot` (alias/overlay) no se puede deshabilitar (Binder crash); el principal `com.android.ztescreenshot` sí quedó deshabilitado.

## 🛠️ Comandos de purga (referencia)

```bash
DEV=320344802623

# Inventario
adb -s $DEV shell pm list packages -3                     # Apps de usuario
adb -s $DEV shell pm list packages -d                    # Deshabilitadas
adb -s $DEV shell pm list packages -s | grep -iE 'zte|nubia'  # Bloat de fábrica

# Borrar app de usuario (libera disco)
adb -s $DEV shell pm uninstall --user 0 <paquete>

# Deshabilitar bloat de sistema (NO libera disco — quita RAM/batería; reversible)
adb -s $DEV shell pm disable-user --user 0 <paquete>
adb -s $DEV shell pm enable <paquete>                    # Revertir

# Device Admin bloquea la desinstalación (DELETE_FAILED_DEVICE_POLICY_MANAGER)
# → primero deshabilitar (desactiva el admin), luego desinstalar:
adb -s $DEV shell pm disable-user --user 0 <paquete>
adb -s $DEV shell pm uninstall --user 0 <paquete>

# Verificar residuos tras borrar
adb -s $DEV shell 'ls /data/data | grep -i <paquete>'    # Vacío = limpio
```

## ⚠️ Notas

- **`pm disable-user` NO libera espacio** — solo evita que la app corra (beneficio: RAM/batería). El espacio lo libera `pm uninstall` (APK + datos).
- El **Mi 10** (HyperOS) bloquea `adb install` por el toggle **"Instalar vía USB"** (Ajustes → Ajustes adicionales → Privacidad) — no se puede activar por ADB (`adb_install_need_confirm=0`, `pm clear-user-restriction` y `cmd user remove-user-restriction` no funcionan en la ROM). Requiere **toque manual** en el teléfono.
- **Candidatas restantes de usuario** (revisar si se usan en el lab): Truecaller, Waze, WhatsApp, Telegram+, Excel, Sony headphones (`com.sony.songpal.mdr`), ShifterCalendar, Steps, Graphite, Coddy, projengmenu, sendfilestotv, 360ramobile.
- Para revisión completa del estado en vivo: **ManUninstaller** muestra el conteo real (`SHIZUKU: ACTIVE · N APPS · M grandes`) y el tamaño por app vía Shizuku.

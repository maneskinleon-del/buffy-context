# Dispositivos Android del usuario

> Fuente: experiencias reales documentadas en sesiones (scrcpy-freefire, GameBoost Pro).

## ZTE Nubia Neo 2 (Z2352N) — principal para juegos
| Campo | Valor |
|---|---|
| Plataforma | `ums9620` (Unisoc T820) — verificado en vivo con `getprop ro.board.platform` |
| Android | 13 |
| Encoder HW | `c2.unisoc.avc.encoder` |
| Serial | `320344802623` (visto en sesiones) |
| Uso | Free Fire + GameBoost Pro + laboratorio de apps |

- Pantalla física 2400x1080; con Free Fire se fuerza `wm size 1600x720` (o 1920x480) + `wm density 280` + `user_rotation 1`.
- Shizuku activo + rish en `/data/local/tmp/rish`.
- Apps instaladas de laboratorio: MacroDroid (Device Admin restante), AutoJS6, Kustom Widget, Steps, launcher hype.

## ZTE Nubia Neo 2 Play / Nubia 5G
- Plataforma `ums9120` (Unisoc T820). Mismo encoder `c2.unisoc.avc.encoder`.

## Xiaomi Mi 10 (sm8250 — Snapdragon 865)
- Encoder HW: `OMX.qcom.video.encoder.avc`.
- Nota: desactivar `charging_optimization = 0` vía ADB para evitar ghost touches al cargar.
- Shizuku/rish configurado.

## Detección de plataforma (para elegir encoder)
```bash
adb shell getprop ro.board.platform   # ums9230 | ums9120 | sm8250 | ...
```

## Reglas de Device Admin (laboratorio — importante)
- **Device Admins IGNORAN el force-stop** (anti-malware de Android): `am force-stop` no los mata.
- Truco probado: `pm disable-user --user 0 <paquete>` los mata de verdad (desactiva su admin),
  y para restaurarlos: `pm enable <paquete>` + `dpm set-active-admin <receiver> --user 0`.
- En el ZTE el único Device Admin restante es MacroDroid:
  `com.arlosoft.macrodroid/.triggers.receivers.MacroDroidDeviceAdminReceiver`.

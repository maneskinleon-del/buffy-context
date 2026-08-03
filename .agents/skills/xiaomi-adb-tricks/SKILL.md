---
name: xiaomi-adb-tricks
description: "Trucos y workarounds ADB/rish/Shizuku para Xiaomi MIUI/HyperOS."
version: 1.0.0
author: "mangonz"
---

# Xiaomi ADB Tricks — Trucos para MIUI/HyperOS

## Overview

Trucos, comandos y workarounds específicos para **Xiaomi MIUI/HyperOS** usando **ADB, rish (Shizuku) y shell**. Basado en pruebas reales con un **Xiaomi Mi 10 — HyperOS 816 (Android 13) — Bootloader locked**.

---

## 📋 Índice

| # | Categoría | Descripción |
|---|---|---|
| 1 | 🔓 Restricted Settings | Bypass para "Configuración restringida" en Android 13+ |
| 2 | 🛑 Advertencia de permisos | Cómo evitar el diálogo "Peligro" de Xiaomi |
| 3 | 🔋 Batería y segundo plano | Evitar que HyperOS mate tus apps |
| 4 | 🪟 Overlay / Superposición | SYSTEM_ALERT_WINDOW en Xiaomi |
| 5 | ♿ Accesibilidad | Trucos para servicios de accesibilidad |
| 6 | 📸 Screencap alternativos | Cómo tomar screenshots sin root |
| 7 | 🧹 Bloatware de Xiaomi | Qué se puede deshabilitar sin root |
| 8 | 🔐 Bootloader unlock | Estado actual del desbloqueo en HyperOS |
| 9 | ⚙️ Tweaks de HyperOS | Ajustes ocultos y personalización |
| 10 | 🔍 Diagnóstico Xiaomi | Comandos para examinar el sistema |
| 11 | 🛡️ Seguridad Xiaomi | Sobre los paquetes de seguridad MIUI |

---

## 1️⃣ 🔓 Restricted Settings (Configuración Restringida)

Android 13+ bloquea permisos especiales (accesibilidad, superposición) para apps sideloaded. Xiaomi lo aplica estrictamente.

### Síntomas
- Botón "Permitir" aparece gris/no disponible
- "Configuración restringida" mensaje al intentar activar accesibilidad
- Superposición (overlay) no se puede activar

### Solución manual (única)

```
Ajustes → Apps → Gestionar apps → [App Name]
→ ⋮ (menú 3 puntos, esquina superior derecha)
→ "Permitir configuración restringida"
→ Ingresar PIN/patrón
```

> ⚠️ **No existe comando ADB/rish** para esto. Es una restricción del sistema Android 13+ que Xiaomi implementa sin excepción.

---

## 2️⃣ 🛑 Advertencia de Permisos Sensibles

### El problema
Xiaomi muestra un cartel naranja/rojo ("Peligro" / "Advertencia de Riesgo") antes de conceder permisos sensibles. Hardcodeado en `com.miui.securitycenter` / `com.miui.securitycore`.

### No se puede eliminar sin root
Con bootloader locked, **no hay forma de eliminar el diálogo del sistema**. Requeriría modificar el framework (services.jar) y eso necesita bootloader desbloqueado + root.

### Solución: Conceder permisos ANTES

```bash
# Si el permiso ya está concedido cuando la app lo pide,
# el diálogo de Xiaomi nunca aparece.

# Ejemplo: conceder CAMERA antes de que la app lo solicite
PKG="com.example.app"
rish pm grant $PKG android.permission.CAMERA
rish appops set $PKG CAMERA allow
```

### Texto exacto del diálogo (confirmado por OCR)

```
⚠ PELIGRO
"Accesibilidad" es un permiso muy sensible.
Si otorga este permiso, su información
privada podría filtrarse y su propiedad
podría estar en riesgo. Esto es lo que las
aplicaciones podrán hacer:
  • Leer todo el contenido de la pantalla...
  • Aprender su comportamiento y automatizar acciones...
```

---

## 3️⃣ 🔋 Batería y Segundo Plano

HyperOS es agresivo matando apps en segundo plano para ahorrar batería.

### Comandos rish para blindar

```bash
PKG="com.example.app"

# Whitelist de deviceidle (equivalente UI: Batería → Sin restricciones)
rish dumpsys deviceidle whitelist +$PKG

# RUN_IN_BACKGROUND (segundo plano básico)
rish appops set $PKG RUN_IN_BACKGROUND allow

# RUN_ANY_IN_BACKGROUND (app standby - segundo plano total)
rish appops set $PKG RUN_ANY_IN_BACKGROUND allow

# START_FOREGROUND (servicios foreground)
rish appops set $PKG START_FOREGROUND allow

# WAKE_LOCK (evitar que el dispositivo duerma la app)
rish appops set $PKG WAKE_LOCK allow
```

### Paquetes de batería de Xiaomi

```bash
# PowerKeeper - gestor de batería de MIUI
# Deshabilitarlo (experimental - puede causar mayor consumo)
rish pm disable com.miui.powerkeeper

# Joyose - optimización de juegos (consume recursos)
rish pm disable com.xiaomi.joyose
```

### Pasos UI complementarios

```
Ajustes → Apps → [App] → Batería → Sin restricciones
Ajustes → Apps → [App] → Auto-inicio → Activado
```

---

## 4️⃣ 🪟 Superposición (SYSTEM_ALERT_WINDOW)

### Doble concesión (recomendado para Xiaomi)

```bash
# En Xiaomi a veces no basta con uno solo
PKG="com.example.app"

# Método 1: pm grant
rish pm grant $PKG android.permission.SYSTEM_ALERT_WINDOW

# Método 2: AppOps
rish appops set $PKG SYSTEM_ALERT_WINDOW allow

# Verificar
rish appops get $PKG SYSTEM_ALERT_WINDOW
# Debe mostrar: allow
```

### Si el botón "Permitir" está gris

Es **Configuración restringida** (ver sección 1). Solución: UI → ⋮ → Permitir configuración restringida.

---

## 5️⃣ ♿ Accesibilidad

### Paso 1: Permitir configuración restringida (UI)

```
Ajustes → Apps → [App] → ⋮ → Permitir configuración restringida
```

### Paso 2: Activar servicio vía rish

```bash
# Obtener el nombre exacto del servicio de accesibilidad
# (varía según la app)

# Ejemplo MacroDroid:
SERVICE="com.arlosoft.macrodroid/com.arlosoft.macrodroid.ui.HomeActivity"

# Ejemplo GGMouse (puede variar):
SERVICE="com.zjx.ztezscreenshot/.AccessibilityService"

# Activar
rish settings put secure enabled_accessibility_services "$SERVICE"
rish settings put secure accessibility_enabled 1

# Verificar
rish settings get secure enabled_accessibility_services
```

### Desactivar

```bash
rish settings put secure enabled_accessibility_services ""
rish settings put secure accessibility_enabled 0
```

### Si HyperOS lo desactiva solo

Xiaomi tiene un comportamiento donde resetea los servicios de accesibilidad. Si pasa:
1. Reactivar con el comando de arriba
2. O crear un script que lo reactive automáticamente (usando tmux + loop)

---

## 6️⃣ 📸 Screencap Alternativos

`screencap` **NO funciona** vía rish en HyperOS con bootloader locked (requiere permisos gráficos que el shell user no tiene).

### Método que funciona: Screenshot manual

```bash
# El usuario presiona: Volumen Abajo + Power
# El archivo se guarda en: /sdcard/DCIM/Screenshots/
```

### Monitoreo automático de screenshots nuevos

```bash
# Script que detecta screenshots nuevos automáticamente
# (del skill hyperos-hardening o auto_permiso.py)
python3 ~/auto_permiso.py --monitor --pkg com.example.app --grant
```

### Alternativas que NO funcionaron

| Comando | Resultado |
|---|---|
| `rish /system/bin/screencap -p /sdcard/screen.png` | ❌ Falla silenciosamente |
| `rish screencap -p /sdcard/screen.png` | ❌ Falla |
| `rish cmd media-session screenshot` | ❌ No disponible |
| `rish am broadcast -a android.intent.action.SCREENSHOT` | ❌ No funciona |

---

## 7️⃣ 🧹 Bloatware de Xiaomi

### Apps de Xiaomi que se pueden deshabilitar (sin root)

```bash
# PowerKeeper (gestión de batería agresiva)
rish pm disable com.miui.powerkeeper

# Joyose (optimización de juegos)
rish pm disable com.xiaomi.joyose

# MSA (servicio de anuncios de MIUI)
rish pm disable com.miui.msa.global

# Analytics (telemetría)
rish pm disable com.miui.analytics
```

### Apps que NO deshabilitar

```bash
# Seguridad del sistema (NO TOCAR)
# com.miui.securitycenter - centro de seguridad
# com.miui.securitycore - núcleo de seguridad

# Servicios esenciales
# com.xiaomi.xmsf - servicios Xiaomi
# com.miui.global.packageinstaller - instalador de paquetes

# Si deshabilitas securitycenter, el diálogo de permisos
# podría fallar o comportarse erráticamente
```

### Ver apps del sistema

```bash
# Solo apps de sistema
rish pm list packages -s

# Apps de terceros
rish pm list packages -3

# Apps deshabilitadas
rish pm list packages -d
```

---

## 8️⃣ 🔐 Bootloader Unlock — Estado en HyperOS Global

### Investigación realizada (Julio 2026)

| Vía | Estado | Detalle |
|---|---|---|
| Ajustes → Mi Unlock Status | ❌ Bloqueado | "Couldn't add. Please go to Mi Community" |
| Xiaomi Community app (global) | ❌ Sin opción | Menú "Yo" no tiene "Desbloquear Bootloader" |
| new.c.mi.com (web) | ❌ Sin opción | Solo foros, ROMs y tienda |
| unlock.update.miui.com | ❌ Roto | Botón "Unlock Now" → apply.php → **404** |
| Mi Unlock Tool (PC) | ⚠️ Existe | Pero requiere solicitud previa que ya no existe |
| Versión China Community | 🤔 Pendiente | Podría tener la opción |

### Requisitos (cuando funcionaba)

- Cuenta Xiaomi con **30+ días** de antigüedad
- SIM insertada + **datos móviles** (no WiFi)
- Binding en: Ajustes → Opciones desarrollador → Mi Unlock Status
- Herramienta Mi Unlock Tool (Windows)
- Espera de **72h–168h** (3–7 días)

### Tools necesarias (PC)

| Herramienta | URL |
|---|---|
| Mi Unlock Tool | [unlock.update.miui.com](https://unlock.update.miui.com) |
| Xiaomi Community APK | new.c.mi.com → Forum → ROM Downloads |

### Comandos de diagnóstico

```bash
# Ver estado del bootloader
rish getprop ro.boot.flash.locked      # 1 = locked
rish getprop ro.boot.verifiedbootstate  # green = verified

# OEM Unlock (no visible en HyperOS)
rish settings get global oem_unlock_enabled  # null en HyperOS

# Datos de desbloqueo
rish settings get secure miui_unlock_data      # null = no vinculado
rish settings get secure miui_unlock_status    # null = sin estado
```

---

## 9️⃣ ⚙️ Tweaks de HyperOS

### Animaciones más rápidas

```bash
# Acelerar animaciones (0.5x)
rish settings put global window_animation_scale 0.5
rish settings put global transition_animation_scale 0.5
rish settings put global animator_duration_scale 0.5

# Desactivar completamente
rish settings put global window_animation_scale 0
rish settings put global transition_animation_scale 0
rish settings put global animator_duration_scale 0
```

### Forzar modo oscuro

```bash
# Forzar modo oscuro en todas las apps
rish settings put secure ui_night_mode 2

# Desactivar
rish settings put secure ui_night_mode 0
```

### Mostrar porcentaje de batería

```bash
# En la barra de estado
rish settings put system status_bar_show_battery_percent 1
```

### Desactivar sonido de cámara

```bash
# Requiere reinicio de la app de cámara
rish settings put system camera_sound_enabled 0
```

### Tasa de refresco (Mi 10 = 90 Hz)

```bash
# Forzar 90 Hz
rish settings put system peak_refresh_rate 90
rish settings put system user_refresh_rate 90

# Forzar 60 Hz (ahorrar batería)
rish settings put system peak_refresh_rate 60
rish settings put system user_refresh_rate 60
```

### Desactivar ads de MIUI

```bash
# Deshabilitar ads en apps del sistema
rish settings put system miui_ad_enable 0
rish settings put global msa_ad_enable 0

# Deshabilitar MSA (servicio de anuncios)
rish pm disable com.miui.msa.global
```

---

## 🔟 🔍 Diagnóstico Xiaomi

### Versión y ROM

```bash
rish getprop ro.miui.ui.version.name      # V816 = HyperOS
rish getprop ro.build.version.release      # Android version
rish getprop ro.product.model              # Modelo
rish getprop ro.build.version.incremental  # Build exacta
```

### Estado de seguridad

```bash
# Bootloader
rish getprop ro.boot.flash.locked
rish getprop ro.boot.verifiedbootstate

# SELinux
rish getprop ro.boot.selinux

# ADB
rish getprop ro.adb.secure    # 1 = ADB con auth
```

### Paquetes de Xiaomi instalados

```bash
# Todos los paquetes de Xiaomi
rish pm list packages | grep -E "xiaomi|miui"
```

### Servicios de Xiaomi en ejecución

```bash
rish ps -A | grep -E "xiaomi|miui"
```

### Logs de advertencia de permisos

```bash
# Ver logs de seguridad de Xiaomi en tiempo real
rish logcat | grep -iE "permission|sensitive|riesgo|peligro|securitycore|securitycenter"
```

### Información de batería

```bash
# Estado completo
rish dumpsys battery

# Apps que más batería consumen
rish dumpsys batterystats --charged | head -30
```

---

## 1️⃣1️⃣ 🛡️ Seguridad Xiaomi

### Paquetes de seguridad de Xiaomi

| Package | Función | ¿Deshabilitable? |
|---|---|---|
| `com.miui.securitycenter` | Centro de seguridad MIUI | ❌ No (afecta permisos) |
| `com.miui.securitycore` | Núcleo de seguridad | ❌ No |
| `com.miui.powerkeeper` | Gestión de batería | ⚠️ Experimental |
| `com.miui.analytics` | Telemetría | ✅ Sí |
| `com.miui.msa.global` | Servicio de anuncios | ✅ Sí |
| `com.xiaomi.joyose` | Optimización de juegos | ✅ Sí |
| `com.miui.global.packageinstaller` | Instalador de APKs | ❌ No |
| `com.xiaomi.xmsf` | Servicios Xiaomi (push) | ❌ No (notificaciones) |

### Depuración USB (configuración de seguridad)

Necesaria para que rish tenga permisos completos:

```
Ajustes → Ajustes adicionales → Opciones de desarrollador →
Depuración USB (configuración de seguridad) → ACTIVAR
→ Iniciar sesión con cuenta Xiaomi
```

Sin esta opción activada, `rish pm grant` y `rish appops set` pueden fallar silenciosamente.

### Verificar si Shizuku tiene permisos completos

```bash
rish dumpsys package moe.shizuku.privileged.api | grep -E "granted=true|permission"
```

---

## 🚨 Troubleshooting Rápido

| Problema | Comando/Solución |
|---|---|
| `pm grant` falla silenciosamente | Activar "Depuración USB (config. seguridad)" |
| App se cierra al minimizar | `deviceidle whitelist` + `RUN_IN_BACKGROUND` |
| Overlay no se activa | UI: ⋮ → Permitir configuración restringida |
| Accesibilidad se desactiva sola | Reactivar con `settings put` |
| Screenshot no funciona | Método manual (Vol- + Power) |
| Notificaciones no llegan | Sin restricciones batería + Auto-inicio |
| Diálogo de "Peligro" molesto | Conceder permisos ANTES con `pm grant` |
| Xiaomi Community sin opción unlock | Es bloqueo de HyperOS Global |

---

## 📚 Skills Relacionados

| Skill | Archivo | Para qué |
|---|---|---|
| `shizuku-rikka` | `.agents/skills/shizuku-rikka/SKILL.md` | Shizuku/rish setup |
| `hyperos-hardening` | `.agents/skills/hyperos-hardening/SKILL.md` | Blindaje de apps |
| `image-analyzer` | `.agents/skills/image-analyzer/SKILL.md` | OCR y procesamiento de imágenes |

---

*Última actualización: Julio 2026 — Basado en Xiaomi Mi 10 (umi) / HyperOS V816 / Android 13 / Bootloader locked*

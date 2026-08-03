---
name: hyperos-hardening
description: >
  Blindaje de aplicaciones contra las restricciones agresivas de Xiaomi
  MIUI/HyperOS usando Shizuku + rish: batería y segundo plano, permisos runtime,
  AppOps granulares, overlay, notificaciones, accesibilidad, y scripts
  todo-en-uno. Sin root y sin desbloquear bootloader.
version: 1.0.0
---

# hyperos-hardening — Blindaje de apps contra HyperOS

> **Problema:** HyperOS/Xiaomi mata apps en segundo plano, bloquea permisos
> especiales (overlay, accesibilidad) con "Configuración restringida" y muestra
> advertencias de "Peligro" antes de conceder permisos sensibles.
>
> **Solución:** Blindaje completo vía Shizuku + rish por categorías: batería,
> permisos runtime, AppOps, overlay, notificaciones, ubicación, cámara/micrófono,
> almacenamiento, accesibilidad y configuración restringida. Con scripts
> todo-en-uno y estrategias por tipo de app.

**Dispositivo de referencia:** Xiaomi Mi 10 — HyperOS 816 (V816.0.4.0.TJBMIXM) — Android 13 — Bootloader locked

---

## Señales de activación

| Señal | Ejemplo |
|---|---|
| Se menciona HyperOS, MIUI, Xiaomi | "mi Xiaomi mata la app" |
| App se cierra al minimizar | "GG Mouse se desactiva" |
| Permiso especial bloqueado | "el botón Permitir está gris" |
| Se menciona bloatware, debloat, privacidad | "quita el bloatware" |
| Accesibilidad se desactiva sola | "el servicio se apaga solo" |

---

## ⚙️ Configuración previa

### Alias rish
```bash
alias rish='RISH_APPLICATION_ID=com.termux MANAGER_APPLICATION_ID=moe.shizuku.privileged.api ~/bin/rish'
```

### Activar "Depuración USB (configuración de seguridad)"
Necesaria para que rish tenga permisos completos. Sin esto, `pm grant` y
`appops set` fallan **silenciosamente**.
```
Ajustes → Ajustes adicionales → Opciones de desarrollador →
Depuración USB (configuración de seguridad) → ACTIVAR
→ Iniciar sesión con cuenta Xiaomi
```

> **Variable usada en todos los ejemplos:** `PKG="com.example.app"`
> Reemplázala por el package name de tu app.

---

## Categorías de blindaje

| # | Categoría | Prioridad |
|---|---|---|
| 1 | 🔋 Batería y segundo plano | 🔴 Alta |
| 2 | 🔐 Runtime Permissions (pm grant) | 🔴 Alta |
| 3 | ⚙️ AppOps granulares | 🔴 Alta |
| 4 | 🪟 Overlay / Superposición | 🟡 Media |
| 5 | 🔔 Notificaciones | 🟡 Media |
| 6 | 📍 Ubicación | 🟡 Media |
| 7 | 📷 Cámara y micrófono | 🟡 Media |
| 8 | 🗂️ Almacenamiento y archivos | 🟡 Media |
| 9 | ♿ Accesibilidad | 🟡 Media |
| 10 | 🔓 Configuración restringida | 🟢 Info |
| 11 | 🧹 Diagnóstico y verificación | 🟢 Info |

---

## 1️⃣ Batería y segundo plano

```bash
# Whitelist de deviceidle (equivalente a "Sin restricciones")
rish dumpsys deviceidle whitelist +$PKG

# Verificar
rish dumpsys deviceidle whitelist | grep $(echo $PKG | cut -d. -f2)

# Segundo plano
rish appops set $PKG RUN_IN_BACKGROUND allow
rish appops set $PKG RUN_ANY_IN_BACKGROUND allow
rish appops set $PKG START_FOREGROUND allow
rish appops set $PKG WAKE_LOCK allow
```

### Deshabilitar PowerKeeper (opcional, afecta TODAS las apps)
```bash
# CUIDADO: afecta a todas las apps, requiere reinicio
rish pm disable com.miui.powerkeeper
```

---

## 2️⃣ Runtime Permissions (pm grant)

Conceder ANTES de que la app lo pida **evita el diálogo de advertencia de Xiaomi**.

### Permisos especiales
```bash
rish pm grant $PKG android.permission.SYSTEM_ALERT_WINDOW
rish pm grant $PKG android.permission.WRITE_SETTINGS
rish pm grant $PKG android.permission.MANAGE_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.REQUEST_INSTALL_PACKAGES
```

### Runtime — cámara, audio, ubicación, contactos, SMS, teléfono
```bash
rish pm grant $PKG android.permission.CAMERA
rish pm grant $PKG android.permission.RECORD_AUDIO

rish pm grant $PKG android.permission.ACCESS_FINE_LOCATION
rish pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
rish pm grant $PKG android.permission.ACCESS_BACKGROUND_LOCATION

rish pm grant $PKG android.permission.READ_CONTACTS
rish pm grant $PKG android.permission.WRITE_CONTACTS

rish pm grant $PKG android.permission.READ_SMS
rish pm grant $PKG android.permission.RECEIVE_SMS
rish pm grant $PKG android.permission.SEND_SMS

rish pm grant $PKG android.permission.READ_PHONE_STATE
rish pm grant $PKG android.permission.CALL_PHONE
```

### Almacenamiento (Android 13+)
```bash
rish pm grant $PKG android.permission.READ_MEDIA_IMAGES
rish pm grant $PKG android.permission.READ_MEDIA_VIDEO
rish pm grant $PKG android.permission.READ_MEDIA_AUDIO

# Legacy (Android 12-)
rish pm grant $PKG android.permission.READ_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.WRITE_EXTERNAL_STORAGE
```

### Notificaciones y otros
```bash
rish pm grant $PKG android.permission.POST_NOTIFICATIONS
rish pm grant $PKG android.permission.READ_CALENDAR
rish pm grant $PKG android.permission.WRITE_CALENDAR
rish pm grant $PKG android.permission.BODY_SENSORS
```

---

## 3️⃣ AppOps granulares

```bash
# Verificar estado
rish appops get $PKG
rish appops get $PKG SYSTEM_ALERT_WINDOW

# Esenciales
rish appops set $PKG SYSTEM_ALERT_WINDOW allow
rish appops set $PKG TOAST_WINDOW allow
rish appops set $PKG RUN_IN_BACKGROUND allow
rish appops set $PKG RUN_ANY_IN_BACKGROUND allow
rish appops set $PKG START_FOREGROUND allow
rish appops set $PKG WAKE_LOCK allow
rish appops set $PKG CAMERA allow
rish appops set $PKG RECORD_AUDIO allow
rish appops set $PKG INTERNET allow

# Reset
rish appops reset $PKG
```

---

## 4️⃣ Overlay / Superposición

### Método doble (recomendado en Xiaomi)
```bash
rish pm grant $PKG android.permission.SYSTEM_ALERT_WINDOW
rish appops set $PKG SYSTEM_ALERT_WINDOW allow

# Verificar → debe mostrar: allow
rish appops get $PKG SYSTEM_ALERT_WINDOW
```

---

## 5️⃣ Notificaciones

```bash
rish pm grant $PKG android.permission.POST_NOTIFICATIONS
rish appops set $PKG POST_NOTIFICATION allow
rish appops set $PKG SHOW_WHEN_LOCKED allow
rish appops set $PKG MANAGE_NOTIFICATION_LIST allow
```

---

## 6️⃣ Ubicación

```bash
rish pm grant $PKG android.permission.ACCESS_FINE_LOCATION
rish pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
rish pm grant $PKG android.permission.ACCESS_BACKGROUND_LOCATION
rish appops set $PKG FINE_LOCATION allow
rish appops set $PKG COARSE_LOCATION allow
rish appops set $PKG GPS allow
rish appops set $PKG WIFI_SCAN allow
```

---

## 7️⃣ Cámara y micrófono

```bash
rish pm grant $PKG android.permission.CAMERA
rish pm grant $PKG android.permission.RECORD_AUDIO
rish appops set $PKG CAMERA allow
rish appops set $PKG RECORD_AUDIO allow
rish appops set $PKG AUDIO_ACCESSIBILITY allow
rish appops set $PKG USE_SIP allow
```

---

## 8️⃣ Almacenamiento

```bash
rish pm grant $PKG android.permission.READ_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.WRITE_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.MANAGE_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.READ_MEDIA_IMAGES
rish pm grant $PKG android.permission.READ_MEDIA_VIDEO
rish pm grant $PKG android.permission.READ_MEDIA_AUDIO
rish appops set $PKG READ_MEDIA_IMAGES allow
rish appops set $PKG READ_MEDIA_VIDEO allow
rish appops set $PKG READ_MEDIA_AUDIO allow
```

---

## 9️⃣ Accesibilidad

### Paso 1: Permitir configuración restringida (UI)
```
Ajustes → Apps → Gestionar apps → [App Name]
→ ⋮ (3 puntos arriba a la derecha)
→ "Permitir configuración restringida"
→ Ingresar PIN/patrón
```
> ⚠️ **No existe comando rish para esto** — requiere interacción manual en la UI.

### Paso 2: Activar servicio vía rish
```bash
# El nombre exacto del servicio varía por app:
SERVICE="com.zjx.ztezscreenshot/.AccessibilityService"   # GG Mouse (ejemplo)

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

---

## 🔟 Configuración restringida (Android 13+)

### Síntomas
- No puedes activar overlay / accesibilidad
- El botón "Permitir" aparece gris/bloqueado

### Solución (manual, única)
```
Ajustes → Apps → Gestionar apps → [App]
→ ⋮ → "Permitir configuración restringida"
→ Ingresar PIN/patrón
```

---

## 1️⃣1️⃣ Diagnóstico y verificación

```bash
# Permisos runtime concedidos
rish dumpsys package $PKG | grep "granted=true"

# AppOps
rish appops get $PKG

# Whitelist batería
rish dumpsys deviceidle whitelist | grep $(echo $PKG | cut -d. -f2)

# Procesos / memoria
rish ps -A | grep $(echo $PKG | tr '.' '_')
rish dumpsys meminfo $PKG

# Info completa
rish dumpsys package $PKG
```

---

## 🚀 Scripts todo-en-uno

### blindar_app.sh

```bash
#!/bin/bash
# ============================================
# 🛡️ BLINDAJE COMPLETO CONTRA HyperOS
# ============================================

if [ -z "$1" ]; then
    echo "Uso: bash blindar_app.sh <package.name>"
    echo "Ej:  bash blindar_app.sh com.zjx.ztezscreenshot"
    exit 1
fi

PKG="$1"
echo "============================================"
echo "🛡️  BLINDANDO: $PKG"
echo "============================================"

echo ""
echo "🔋 1. BATERÍA Y SEGUNDO PLANO..."
rish dumpsys deviceidle whitelist +$PKG
rish appops set $PKG RUN_IN_BACKGROUND allow
rish appops set $PKG RUN_ANY_IN_BACKGROUND allow
rish appops set $PKG START_FOREGROUND allow
rish appops set $PKG WAKE_LOCK allow
echo "  ✅ Hecho"

echo ""
echo "🪟 2. SUPERPOSICIÓN (SYSTEM_ALERT_WINDOW)..."
rish pm grant $PKG android.permission.SYSTEM_ALERT_WINDOW
rish appops set $PKG SYSTEM_ALERT_WINDOW allow
echo "  ✅ Hecho"

echo ""
echo "🔧 3. WRITE_SETTINGS..."
rish pm grant $PKG android.permission.WRITE_SETTINGS
echo "  ✅ Hecho"

echo ""
echo "📁 4. ALMACENAMIENTO..."
rish pm grant $PKG android.permission.READ_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.WRITE_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.MANAGE_EXTERNAL_STORAGE
rish pm grant $PKG android.permission.READ_MEDIA_IMAGES
rish pm grant $PKG android.permission.READ_MEDIA_VIDEO
rish pm grant $PKG android.permission.READ_MEDIA_AUDIO
echo "  ✅ Hecho"

echo ""
echo "📦 4b. INSTALAR APKs..."
rish pm grant $PKG android.permission.REQUEST_INSTALL_PACKAGES
echo "  ✅ Hecho"

echo ""
echo "🔔 5. NOTIFICACIONES..."
rish pm grant $PKG android.permission.POST_NOTIFICATIONS
echo "  ✅ Hecho"

echo ""
echo "============================================"
echo "✅ BLINDAJE COMPLETADO PARA: $PKG"
echo "============================================"
echo ""
echo "📋 Pasos manuales pendientes:"
echo "  1. Ajustes → Apps → $PKG → ⋮ → Permitir configuración restringida"
echo "  2. Ajustes → Apps → $PKG → Batería → Sin restricciones"
echo "  3. Ajustes → Apps → $PKG → Auto-inicio → Activado"
echo ""
echo "🔍 Para verificar: rish appops get $PKG"
echo "   Para permisos:  rish dumpsys package $PKG | grep granted=true"
```

### verificar_blindaje.sh

```bash
#!/bin/bash
# ============================================
# 🔍 VERIFICAR ESTADO DE BLINDAJE
# ============================================

PKG="$1"
if [ -z "$PKG" ]; then
    echo "Uso: bash verificar_blindaje.sh <package.name>"
    exit 1
fi

echo "============================================"
echo "🔍 VERIFICANDO BLINDAJE: $PKG"
echo "============================================"

echo ""
echo "📊 PERMISOS RUNTIME (granted=true):"
rish dumpsys package $PKG 2>/dev/null | grep "granted=true" | sed 's/^/  /'

echo ""
echo "📊 APPops CLAVE:"
for op in SYSTEM_ALERT_WINDOW RUN_IN_BACKGROUND RUN_ANY_IN_BACKGROUND START_FOREGROUND WAKE_LOCK; do
    status=$(rish appops get $PKG $op 2>/dev/null)
    echo "  $op: $status"
done

echo ""
echo "📊 BATERÍA (deviceidle whitelist):"
rish dumpsys deviceidle whitelist 2>/dev/null | grep $(echo $PKG | cut -d. -f2) || echo "  ❌ NO está en whitelist"

echo ""
echo "============================================"
```

---

## 🧠 Estrategia de Blindaje por Tipo de App

### Auto-clicker / Automatización (ej. GGMouse)

| Prioridad | Permiso | Cómo |
|---|---|---|
| 🔴 | Superposición | `rish pm grant` + `appops set` |
| 🔴 | Segundo plano | `appops set RUN_* allow` + deviceidle |
| 🔴 | Accesibilidad | UI: "Permitir configuración restringida" + `settings put` |
| 🟡 | Notificaciones | `rish pm grant POST_NOTIFICATIONS` |
| 🟡 | Almacenamiento | `rish pm grant MANAGE_EXTERNAL_STORAGE` |

### Tasker / MacroDroid / Automatización

| Prioridad | Permiso | Cómo |
|---|---|---|
| 🔴 | Accesibilidad | UI: "Permitir configuración restringida" + `settings put` |
| 🔴 | Segundo plano | `appops set RUN_*` + deviceidle |
| 🔴 | Notificaciones | `rish pm grant POST_NOTIFICATIONS` |
| 🟡 | Superposición | `rish pm grant` + `appops set` |
| 🟡 | Ubicación | `rish pm grant ACCESS_*_LOCATION` |
| 🟡 | SMS/Teléfono | `rish pm grant READ_SMS, READ_PHONE_STATE` |

### App de streaming / TV (ej. Xuper TV)

| Prioridad | Permiso | Cómo |
|---|---|---|
| 🔴 | Segundo plano | `appops set RUN_*` + deviceidle |
| 🟡 | Almacenamiento | `rish pm grant READ_EXTERNAL_STORAGE` |
| 🟡 | Notificaciones | `rish pm grant POST_NOTIFICATIONS` |

---

## 📋 Checklist de Blindaje Completo

- [ ] `rish pm grant` todos los permisos runtime necesarios
- [ ] `rish appops set` todos los ops relevantes
- [ ] `rish dumpsys deviceidle whitelist +$PKG`
- [ ] UI: Batería → Sin restricciones
- [ ] UI: Auto-inicio → Activado
- [ ] UI: ⋮ → Permitir configuración restringida (si aplica)
- [ ] UI: Accesibilidad → Activar servicio (si aplica)
- [ ] `Depuración USB (configuración de seguridad)` activada

---

## Troubleshooting HyperOS

| Problema | Solución |
|---|---|
| `pm grant` falla silenciosamente | Activar "Depuración USB (config. seguridad)" |
| App se cierra al minimizar | deviceidle whitelist + RUN_IN_BACKGROUND |
| "Permitir" gris en overlay | UI: ⋮ → Permitir configuración restringida |
| Accesibilidad se desactiva sola | Reactivar con `settings put` |
| Notificaciones no llegan | Sin restricciones batería + Auto-inicio |
| Diálogo de "Peligro" molesto | Conceder permisos ANTES con `pm grant` |

---

## Integración con otras skills

- **`shizuku-rikka`** — base de rish/Shizuku (setup, permisos, troubleshooting)
- **`android-adb`** — comandos ADB base
- **`android-agent`** — agente orquestador Android

Referencia Knowledge/: `Knowledge/Android/HyperOS.md`.

---
name: form-filler
description: "Llenado automatico de formularios web (Node.js + Puppeteer + SmartMapper)."
version: 1.0.0
author: "mangonz"
---

# Form Filler — Llenado Automático de Formularios Web

## Overview

Script **Node.js + Puppeteer** que automatiza el llenado de formularios web usando Chromium headless. Detecta campos, clasifica su propósito mediante SmartMapper (patrones multi-idioma), y los llena con datos de prueba.

**Archivo:** `~/fill_form.js`
**Stack:** Chromium 149 + Node.js 26 + Puppeteer-core

---

## ⚙️ Instalación

```bash
# Requisitos (ya instalados en este dispositivo):
pkg install nodejs chromium x11-repo
npm install puppeteer-core
```

---

## 🚀 Uso Básico

```bash
# Llenar formulario automáticamente
node ~/fill_form.js <url>

# Llenar + clickear Sign Up + screenshots
node ~/fill_form.js <url> --click-signup --screenshot

# Modo interactivo (pregunta qué datos usar)
node ~/fill_form.js <url> --interactive

# Con datos personalizados desde JSON
node ~/fill_form.js <url> --data mis-datos.json

# Sin clickear botón submit
node ~/fill_form.js <url> --no-submit

# Modo lento (imita comportamiento humano)
node ~/fill_form.js <url> --slow

# Exportar resultados a JSON
node ~/fill_form.js <url> --export resultados.json

# Con resolución de CAPTCHA
node ~/fill_form.js <url> --captcha-api-key MI_KEY
CAPTCHA_API_KEY=xxx node ~/fill_form.js <url>
```

---

## 📋 CLI Options

| Opción | Descripción | Default |
|---|---|---|
| `<url>` | URL del formulario a llenar | **(requerido)** |
| `-i, --interactive` | Pregunta datos al usuario | `false` |
| `-d, --data <file>` | Carga datos desde JSON | `null` |
| `--click-signup` | Clickea "Sign Up/Registrarse" | `false` |
| `-s, --screenshot` | Guarda screenshots | `false` |
| `--no-submit` | No clickea botón submit | `false` |
| `--slow` | Modo lento con delays human-like | `false` |
| `--field-delay <ms>` | Delay entre caracteres | `15` (`60` si --slow) |
| `--captcha-api-key <key>` | API key de 2captcha | env `CAPTCHA_API_KEY` |
| `--captcha-timeout <sec>` | Timeout para resolver captcha | `120` |
| `--export <file>` | Exportar resultados a JSON | `null` |
| `--wait <ms>` | Espera inicial tras cargar | `3000` |
| `--headless <bool>` | Modo headless | `true` |
| `-o, --output <dir>` | Directorio de screenshots | `/sdcard/DCIM/Screenshots` |
| `-h, --help` | Muestra ayuda | — |

---

## 🧠 SmartMapper — Clasificación de Campos

El script clasifica automáticamente cada campo usando patrones multi-idioma (español + inglés) combinando:

- `placeholder`
- `name`
- `id`
- `label` (for, parent, previous sibling, aria-labelledby)
- `aria-label`
- `title`

### Categorías soportadas (29)

| Categoría | Patrones (ejemplos) |
|---|---|
| `first_name` | nombre, first name, given name, name (+ exclusiones) |
| `last_name` | apellido, surname, last name, family name |
| `full_name` | full name, nombre completo, display name |
| `email` | correo, email, e-mail, mail |
| `phone` | teléfono, phone, mobile, cell, whatsapp |
| `password` | contraseña, password, clave, pass |
| `confirm_password` | confirm, repetir, retype, repeat |
| `username` | usuario, username, nick, login |
| `address` | dirección, address, calle, street |
| `city` | ciudad, city, comuna, town |
| `state` | state, estado, región, province |
| `zip` | zip, postal, código postal, postcode |
| `country` | país, country, nación, nation |
| `company` | empresa, company, organization, business |
| `website` | website, web, sitio, url, página |
| `date` | fecha, date, day, month, year |
| `birth_date` | birth, nacimiento, birthday, date of birth |
| `age` | edad, age, years old |
| `gender` | género, gender, sex |
| `number` | number, cantidad, quantity, count |
| `price` | precio, price, cost, amount |
| `quantity` | cantidad, quantity, items |
| `description` | descripción, about, bio, profile |
| `message` | mensaje, message, comment, pregunta |
| `subject` | asunto, subject, título, title |
| `search` | buscar, search, find, query |
| `terms` | términos, terms, conditions, privacy |
| `accept` | acepto, accept, agree, de acuerdo |
| `captcha` | — (detectado por DOM, no por patrones de texto) |

### Sistema de Scoring

Cada patrón tiene un score basado en su longitud (patrones más largos = más específicos = mayor score). Exclusions restan `length * 2` del score. Gana la categoría con mayor score total.

---

## 🔒 CAPTCHA Support (Feature #1)

Detecta y resuelve CAPTCHAs automáticamente usando la API de 2captcha.

### Captchas soportados

| Tipo | Detección | Resolución |
|---|---|---|
| **reCAPTCHA v2** ("No soy un robot") | `.g-recaptcha` + `data-sitekey` o iframe | 2captcha API → token → inyectado en página |
| **reCAPTCHA v3** (invisible, score) | Script `recaptcha/api.js` + `render` param | 2captcha API (método userrecaptcha) |
| **hCaptcha** | `.h-captcha` + `data-sitekey` o iframe | 2captcha API (método hcaptcha) |
| **Image CAPTCHA** | `<img>` con `captcha` en src/alt | Parcial (detecta pero requiere worker) |

### API Key

```bash
# Opción 1: CLI argument
node fill_form.js <url> --captcha-api-key TU_API_KEY

# Opción 2: Variable de entorno
CAPTCHA_API_KEY=TU_API_KEY node fill_form.js <url>
```

### Flujo de resolución

```
1. Página cargada → detectCaptchas() escanea el DOM
2. Si hay reCAPTCHA/hCaptcha → extrae sitekey + pageUrl
3. POST a 2captcha.com/in.php → recibe request ID
4. Pool cada 5s a 2captcha.com/res.php hasta obtener token
5. Inyecta token en la página (g-recaptcha-response, callback, etc.)
6. Submit puede proceder con el CAPTCHA resuelto
```

### Sin API key

Si no se proporciona `--captcha-api-key`, el script igual **detecta** los CAPTCHAs y los reporta, pero no los resuelve:

```
🔒 Buscando CAPTCHAs (sin resolver — usa --captcha-api-key)...
  ⚠️  1 CAPTCHA(s) detectado(s), pero no hay API key.
```

**Costo:** 2captcha es un servicio pago (~$2/1000 requests). Se necesita una cuenta con saldo positivo.

---

## 🐢 Slow Mode (Feature #2)

El modo slow humaniza el comportamiento del script agregando delays realistas:

```bash
# Activar slow mode (predefinido: 60ms/char)
node fill_form.js <url> --slow

# Control manual del delay
node fill_form.js <url> --field-delay 50

# Combinados (slow + custom)
node fill_form.js <url> --slow --field-delay 80
```

### Efectos de Slow Mode

| Aspecto | Normal | Slow |
|---|---|---|
| Delay entre caracteres | 15ms | 60ms (o custom) |
| Entre limpiar y tipear campo | 30ms | 200ms |
| Entre tipear y events change/blur | 20ms | 150ms |
| Entre opción de select | 50ms | 500ms |
| Entre click y siguiente acción | ~50ms | 300-1000ms |
| Retry log verboso | No | Sí |

Útil para:
- Sitios con detección de bots (ratelimit por velocidad)
- SPAs que necesitan tiempo para procesar cada input
- Depuración visual (se ve cómo se llena campo por campo)

---

## 📊 Export Results (Feature #3)

Guarda un reporte JSON detallado con qué se llenó, qué no, y por qué:

```bash
node fill_form.js <url> --export ~/resultados.json
```

### Formato del JSON exportado

```json
{
  "url": "https://ejemplo.com/register",
  "timestamp": "2026-07-27T03:40:03.578Z",
  "duration_seconds": 14,
  "summary": {
    "total_detected": 21,
    "total_filled": 19,
    "total_failed": 0,
    "total_skipped": 0
  },
  "fields": [
    {
      "name": "first_name",
      "type": "text",
      "category": "unknown",
      "label": "Nombre(s) *",
      "value": "Juan Andrés",
      "filled": true,
      "error": null,
      "frameIndex": 0,
      "timestamp": "2026-07-27T03:39:55.723Z"
    },
    {
      "name": "terms",
      "type": "checkbox",
      "category": "unknown",
      "label": "Acepto los términos...",
      "value": true,
      "filled": true,
      "error": null,
      "frameIndex": 0,
      "timestamp": "2026-07-27T03:39:53.487Z"
    }
  ]
}
```

### Resultados en consola

Al finalizar, el script muestra un resumen:
```
📊 RESUMEN:
  ✅ Llenados: 19

📊 Exportado: ~/resultados.json (5.4 KB)
```

---

## 🔄 Retry Logic (Feature #4)

Cada operación de campo se reintenta automáticamente si falla:

| Parámetro | Valor |
|---|---|
| Reintentos máximos | 3 |
| Delay base | 600-800ms (según tipo) |
| Backoff | Exponencial (base × 2^attempt) |
| Tiempo máximo | ~2.5s por campo |

### Comportamiento

```
Intento 1 falla → espera 800ms → Intento 2 → espera 1600ms → Intento 3
```

En slow mode, se muestra el progreso:
```
  🔄 campo "Nombre": intento 1 falló, reintentando en 800ms...
  ✅ Nombre: "Juan Andrés"
```

### Campos con retry

- `fillTextField` — input text/email/password/tel
- `fillTextarea` — textarea
- `handleSelect` — selects con búsqueda de opción
- `handleCheckbox` — checkbox toggle
- `clickRadio` — radio button selection

---

## 🖼️ iframe Support (Feature #5)

El script detecta y llena campos dentro de **iframes**, tanto same-origin como cross-origin (estos últimos se saltan silenciosamente).

### Detección multi-frame

```
📋 25 campos interactivos detectados:
  [Documento principal — 21 campos]:
    [ 0] <input text "Nombre(s)" [first_name]>
    [ 1] <input email "Email" [email]>
    ...
  [iframe #1 — 4 campos]:
    [ 0] <input text "Card Number" [cardnumber]>
    [ 1] <input text "CVV" [cvv]>
```

### Mecanismo

1. `detectAllFields()` itera sobre `page.frames()`
2. Para cada frame, ejecuta `frame.evaluate()` para extraer campos
3. Los campos se etiquetan con su `frameIndex`
4. `getFrameForField()` devuelve el frame correcto para cada campo
5. `frameEvaluate()`, `frameType()`, `frameSelect()` son wrappers que operan en el frame adecuado

### Limitaciones

- **Cross-origin iframes**: No se pueden inspeccionar ni llenar (restricción del navegador)
- **Iframes dinámicos**: Si un iframe se carga después de la detección inicial, no se detecta
- **Frame indexes**: Pueden cambiar si los iframes se recargan. Se usa el índice del momento de detección

---

## 🧪 Resultados de Pruebas

### Prueba local con test-form.html (21 campos)

Se creó un formulario HTML completo con todos los tipos de campo y se probó `fill_form.js` contra `localhost:8000`:

| Métrica | Resultado |
|---|---|
| Campos totales | 21 |
| Campos detectados | 21 |
| **Campos llenados** | **19** 🏆 |
| Nombre | ✅ "Juan Andrés" |
| Apellido | ✅ "González Muñoz" |
| Email | ✅ "juan.gonzalez...@ejemplo.cl" |
| Teléfono | ✅ "+56912345678" |
| Fecha nacimiento | ✅ "1996-07-15" |
| Usuario | ✅ "juan.perez..." |
| Sitio web | ✅ "https://ejemplo.cl" |
| Contraseña | ✅ "TestPass789!xy" |
| Confirmar contraseña | ✅ "TestPass789!xy" |
| Dirección | ✅ "Av. Providencia 1234" |
| Ciudad | ✅ "Santiago" |
| Región | ✅ "Región Metropolitana" |
| Código postal | ✅ "7500000" |
| País (select) | ✅ "México" |
| Perfil (radio) | ✅ "Dropshipper" |
| Empresa | ✅ "TechSolutions SpA" |
| Descripción (textarea) | ✅ "Soy un usuario de prueba..." |
| Asunto | ✅ "Consulta desde formulario..." |
| Términos (checkbox) | ✅ Marcado |
| Submit | ✅ Click funcional (mensaje de éxito visible) |

**Precisión del SmartMapper: 100%** — Todos los campos fueron clasificados correctamente.

### Prueba en entorno real (Dropi)

| Sitio | URL | Resultado |
|---|---|---|
| Dropi login | `app.dropi.cl` | 3 campos detectados, 2 llenados (username + password) |
| Dropi registro | `app.dropi.cl` + `--click-signup` | 8 campos detectados, 8 llenados (nombre, apellido, teléfono, email, contraseña x2, perfil, términos) |
| example.com | `example.com/register` | 0 campos (página sin formulario — manejo graceful) |

### Prueba de nuevas features (v3.0)

| Feature | Resultado | Detalle |
|---|---|---|
| Slow mode | ✅ | 60ms/char, delays entre pasos visibles |
| Export JSON | ✅ | 5.4 KB, 19 campos, resumen correcto |
| Retry logic | ✅ | No hubo fallos (3 retries nuca necesarios en test-form) |
| iframe support | ✅ | `detectFieldsInFrame()` funcional, cross-origin skip |
| CAPTCHA detection | ✅ | "No se detectaron CAPTCHAs" en test-form (correcto) |

---

## 🔧 ActionEngine v2

| Tipo de campo | Mecanismo | Retry | Frame-aware |
|---|---|---|---|
| **Input text/email/password/tel** | `frame.type()` + `change`/`blur` | ✅ 3 intentos | ✅ |
| **Textarea** | `frame.type()` con delay | ✅ 3 intentos | ✅ |
| **Select** | `frame.select()` + búsqueda keyword + fallback | ✅ 3 intentos | ✅ |
| **Checkbox** | Click `<label for>` + events | ✅ 3 intentos | ✅ |
| **Radio** | Click label con texto + fallback input | ✅ 3 intentos | ✅ |
| **Términos** | Búsqueda por texto en DOM + click | ❌ (único intento) | Solo main frame |
| **CAPTCHA** | detectCaptchas() + 2captcha API + inject token | ❌ (timeout) | Solo main frame |
| **Submit** | `input[type=submit]` > button por texto | ❌ (único intento) | Solo main frame |

---

## 📝 Ejemplo de JSON de datos

```json
{
  "first_name": "María",
  "last_name": "López",
  "email": "maria@ejemplo.com",
  "phone": "+56987654321",
  "password": "MiPassSegura2024!",
  "address": "Av. Siempre Viva 742",
  "city": "Valparaíso",
  "country": "Chile",
  "company": "Mi Empresa Ltda"
}
```

---

## 💬 Modo Interactivo

En modo `--interactive`, el script:
1. Detecta todos los campos del formulario
2. Clasifica cada campo por categoría
3. Pregunta al usuario el valor para cada categoría única
4. Usa valores por defecto si se presiona Enter
5. Permite saltar campos con "skip"

---

## 🐛 Troubleshooting v3.0

| Problema | Causa | Solución |
|---|---|---|
| SPA no detecta cambios | Framework no escucha `input` events | Usar `page.type` (genera key events reales) |
| Radio no se selecciona | `name=""` vacío | Fallback a `input[type="radio"]` |
| Submit deshabilitado | Validación HTML5 no pasa | Verificar formato de datos (email, password length) |
| Formulario no aparece | SPA tarda en renderizar | Aumentar `--wait` o quitar `--no-submit` |
| Chromium no arranca | Faltan flags | Usar `--no-sandbox --disable-gpu` |
| CAPTCHA no se resuelve | API key inválida o saldo insuficiente | Verificar key en 2captcha.com |
| Export JSON no se crea | Ruta no existe | Usar ruta absoluta (ej: `~/resultados.json`) |
| iframe vacío | Cross-origin (no accesible) | Solo same-origin iframes son detectables |
| Slow mode muy lento | `--field-delay` muy alto | Reducir delay o usar default slow (60ms) |


---

## 🔗 Skills Relacionados

| Skill | Archivo | Para qué |
|---|---|---|
| `hyperos-hardening` | `.agents/skills/hyperos-hardening/SKILL.md` | Blindaje de apps Android |
| `image-analyzer` | `.agents/skills/image-analyzer/SKILL.md` | OCR y procesamiento de imágenes |
| `xiaomi-adb-tricks` | `.agents/skills/xiaomi-adb-tricks/SKILL.md` | Comandos ADB/rish HyperOS |

---

*Última actualización: Julio 2026 — Creado para Xiaomi Mi 10 / HyperOS / Termux*

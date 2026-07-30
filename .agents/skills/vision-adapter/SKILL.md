---
name: vision-adapter
description: >
  Adaptador portable de visión/VLM para analizar imágenes y capturas de pantalla.
  Usa Ollama + modelos VLM locales (MiniCPM-V, Qwen2.5-VL, LLaVA) para describir
  imágenes sin depender de APIs externas.
version: 1.0.0
---

# vision-adapter — Análisis de Imágenes con VLM Local

> **Problema:** Buffy (Freebuff) no puede ver imágenes directamente. Para analizar
> capturas de pantalla, screenshots de Android, diagramas, o UI mockups, necesita
> un VLM (Vision Language Model) que convierta imágenes en texto.
>
> **Solución:** Ollama + modelo VLM local. La imagen se envía a la API REST de
> Ollama, el VLM la describe, y el resultado se pasa al LLM principal.

---

## Requisitos

- **Ollama** corriendo (`systemctl --user status ollama`)
- **Modelo VLM** instalado (ver `Knowledge/Vision.md`)
- **Python 3** con `requests` o `curl` para enviar la imagen
- Imagen en formato PNG, JPG, o WebP (máx ~10MB recomendado)

---

## Cómo usar

### 1. Analizar una imagen (vía API directa)

```bash
# Descripción general de una imagen
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "minicpm-v",
    "prompt": "Describe esta imagen en detalle. ¿Qué ves?",
    "images": ["'"$(base64 -w0 /ruta/a/imagen.png)"'"],
    "stream": false,
    "options": {"temperature": 0.1}
  }' | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'
```

### 2. Análisis especializado

```bash
# OCR: extraer texto de una captura de pantalla
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "minicpm-v",
    "prompt": "Extrae TODO el texto visible en esta imagen. Devuelve solo el texto, sin descripción.",
    "images": ["'"$(base64 -w0 /ruta/a/screenshot.png)"'"],
    "stream": false
  }' | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'

# Análisis de UI Android
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "minicpm-v",
    "prompt": "Analiza esta captura de pantalla Android. ¿Qué app es? ¿Qué elementos UI ves? ¿Hay diálogos, notificaciones, o permisos?",
    "images": ["'"$(base64 -w0 /ruta/a/screenshot.png)"'"],
    "stream": false,
    "options": {"temperature": 0.1}
  }' | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'

# Diagnóstico de error (captura de pantalla de un crash)
curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "minicpm-v",
    "prompt": "Esta es una captura de pantalla de un error en Android. ¿Qué mensaje de error muestra? ¿Qué app? ¿Hay stack trace visible?",
    "images": ["'"$(base64 -w0 /ruta/a/error.png)"'"],
    "stream": false
  }' | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'
```

### 3. Script helper para uso rápido

Crear `~/.local/bin/see.sh`:

```bash
#!/bin/bash
# see.sh — describe una imagen usando el VLM local
# Uso: see.sh <imagen> [prompt]

IMG="$1"
PROMPT="${2:-Describe esta imagen en detalle. ¿Qué ves?}"

if [ ! -f "$IMG" ]; then
    echo "❌ Archivo no encontrado: $IMG"
    echo "Uso: see.sh <imagen> [prompt opcional]"
    exit 1
fi

echo "🔍 Analizando: $IMG"
echo "📝 Prompt: $PROMPT"
echo "---"

curl -s http://localhost:11434/api/generate \
  -d "$(python3 -c "
import json, base64
with open('$IMG', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()
print(json.dumps({
    'model': 'minicpm-v',
    'prompt': '''$PROMPT''',
    'images': [b64],
    'stream': False,
    'options': {'temperature': 0.1}
}))")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'
```

---

## Señales de activación

Cargar esta skill cuando:

| Señal | Ejemplo |
|---|---|
| El usuario comparte una imagen o screenshot | "Mira esta captura" |
| Error en Android con UI involucrada | "Aparece un diálogo de permiso" |
| Necesita analizar un diagrama o mockup | "Este es el diseño de la pantalla" |
| El usuario pega un base64 de imagen | Base64 data en el mensaje |
| OCR en capturas de pantalla | "¿Qué dice este error?" |

---

## Formato de respuesta

```
## 🖼️ Análisis de imagen

### Imagen: [ruta/nombre]
### Modelo: [minicpm-v / qwen2.5-vl / llava]
### Tiempo: [X.Xs]

[descripción detallada de la imagen]

### Texto extraído (si aplica):
[texto visible en la imagen]

### Conclusión:
[resumen y recomendación]
```

---

## Integración con Knowledge/

Skills relacionadas:
- **`android-adapter`** (Knowledge/Android/ADB.md) — para capturar screenshots del dispositivo
- **`code-search`** (.agents/skills/code-search/) — para buscar basado en lo que se ve en la imagen
- **`Knowledge/Vision.md`** — referencia de modelos VLM y comandos

Para capturar una screenshot del dispositivo Android:
```bash
adb shell screencap -p /sdcard/screen.png
adb pull /sdcard/screen.png /tmp/screen.png
see.sh /tmp/screen.png "Describe esta pantalla Android. ¿Qué app es? ¿Qué botones y textos ves?"
```

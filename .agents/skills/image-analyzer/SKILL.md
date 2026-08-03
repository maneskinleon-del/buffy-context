---
name: image-analyzer
description: "Analisis y procesamiento de imagenes (Python + Pillow + Tesseract OCR)."
version: 1.0.0
author: "mangonz"
---

# Image Analyzer — Procesamiento de Imágenes

## Overview

Skill para analizar y procesar imágenes usando **Python + Pillow** (ya instalado) y opcionalmente **Tesseract OCR** (requiere instalación).

**Limitación importante:** No puedo "ver" imágenes ni interpretar contenido visual (objetos, rostros, escenas). Lo que SÍ puedo hacer es leer metadatos técnicos y, con OCR, extraer texto.

---

## Requisitos

| Herramienta | Estado | Instalación |
|---|---|---|
| **Python 3** | ✅ Ya disponible | `python3 --version` |
| **Pillow** | ✅ Ya instalado | `pip3 list \| grep Pillow` |
| **Tesseract OCR** | ✅ **Instalado v5.5.3** | OCR español + inglés |

---

## 📐 Leer Metadatos de una Imagen

### Uso básico

```bash
python3 -c "
from PIL import Image
import os

path = 'ruta/de/la/imagen.jpg'
img = Image.open(path)

print('=== METADATOS DE LA IMAGEN ===')
print(f'Archivo:       {os.path.basename(path)}')
print(f'Tamaño:        {os.path.getsize(path):,} bytes')
print(f'Formato:       {img.format}')
print(f'Dimensiones:   {img.size[0]} × {img.size[1]} px')
print(f'Modo:          {img.mode}')
print(f'Paleta:        {img.palette}')

# Información adicional
if img.info:
    for key, value in img.info.items():
        print(f'Info [{key}]: {value}')
"
```

### Ejemplo de salida

```
=== METADATOS DE LA IMAGEN ===
Archivo:       screenshot.jpg
Tamaño:        245,678 bytes
Formato:       JPEG
Dimensiones:   1080 × 2340 px
Modo:          RGB
Info [exif]:   b'...'
Info [dpi]:    (72, 72)
```

---

## 🔍 Extraer EXIF (metadatos de cámara/GPS)

Útil para fotos originales (no screenshots):

```bash
python3 -c "
from PIL import Image
from PIL.ExifTags import TAGS

img = Image.open('ruta/imagen.jpg')
exif = img.getexif()

if exif:
    for tag_id, value in exif.items():
        tag_name = TAGS.get(tag_id, tag_id)
        print(f'{tag_name}: {value}')
else:
    print('No EXIF data found')
"
```

---

## 🔄 Convertir / Redimensionar Imágenes

### Convertir formato

```bash
python3 -c "
from PIL import Image
img = Image.open('captura.png')
img.save('captura.jpg', 'JPEG', quality=85)
print('✅ Convertido: PNG → JPG')
"
```

### Redimensionar

```bash
python3 -c "
from PIL import Image
img = Image.open('imagen.jpg')
img_resized = img.resize((1920, 1080))
img_resized.save('imagen_1080p.jpg', quality=90)
print(f'✅ Redimensionado: {img.size} → {img_resized.size}')
"
```

---

## 📝 OCR — Extraer Texto de Imágenes

### ✅ Tesseract ya está instalado

| Componente | Versión |
|---|---|
| **Tesseract** | 5.5.3 |
| **Inglés** (`eng`) ✅ | Incluido por defecto |
| **Español** (`spa`) ✅ | Descargado manualmente (18 MB) |

### Extraer texto de una imagen (uso básico)

```bash
# Inglés (por defecto)
tesseract ruta/captura.png stdout

# Español
tesseract ruta/captura.png stdout -l spa

# Ambos idiomas combinados (mejor precisión)
tesseract ruta/captura.png stdout -l spa+eng
```

### Extraer texto y guardarlo a archivo

```bash
tesseract captura.png salida -l spa
# Esto crea salida.txt con el texto extraído
```

---

## 🎯 Preprocesamiento de Imágenes para Mejorar OCR

Basado en pruebas reales con screenshots de **HyperOS (Xiaomi Mi 10)**, estas son las técnicas que funcionan y las que no.

### 📊 Resultados de pruebas reales

| Técnica | Screenshot real (HyperOS) | Imagen generada (PIL) | Tiempo |
|---|---|---|---|
| **Original** (sin procesar) | 🥇 Excelente | ✅ Bueno | Rápido |
| **Sharpen** (enfocar) | 🥇 Excelente | ✅ Bueno | Rápido |
| **Grayscale** (escala de grises) | ✅ Bueno | ✅ Bueno | Rápido |
| **Scale 2x** (escalar ×2) | ⚠️ Igual que original | ⚠️ Poca mejora | Lento (4×) |
| **Contrast** ( aumentar contraste) | ⚠️ Similar | ⚠️ Similar | Rápido |
| **Adaptive threshold** | ❌ Más errores | ❌ Más errores | Medio |
| **BW threshold** (binarización) | ❌ Fragmentado | ❌ Fragmentado | Rápido |
| **Full pipeline** (todo combinado) | ❌ Muy fragmentado | ❌ Muy fragmentado | Lento |

> **Conclusión clave:** Para screenshots limpios de HyperOS, **NO uses preprocesamiento agresivo**. El original o sharpen es suficiente. Las técnicas de binarización **destruyen** la calidad del texto en fondos oscuros (como el UI de Xiaomi).

---

### 🔧 Técnicas de Preprocesamiento que SÍ Funcionan

#### 1. Sharpen (Enfocar) — RECOMENDADO para screenshots

```bash
python3 << 'PYEOF'
from PIL import Image, ImageEnhance
import subprocess, os

img = Image.open('screenshot.png')

# Aplicar sharpen (enfocar bordes del texto)
enhancer = ImageEnhance.Sharpness(img)
img_sharp = enhancer.enhance(2.0)

img_sharp.save('screenshot_sharp.png')

# OCR sobre la imagen mejorada
result = subprocess.run(
    ['tesseract', 'screenshot_sharp.png', 'stdout', '-l', 'spa+eng'],
    capture_output=True, text=True
)
print(result.stdout)
PYEOF
```

#### 2. Escala de grises + Sharpen — Para imágenes con ruido de color

```bash
python3 << 'PYEOF'
from PIL import Image, ImageEnhance
import subprocess

img = Image.open('captura.png')

# Pipeline: grises → sharpen
img = img.convert('L')  # escala de grises
enhancer = ImageEnhance.Sharpness(img)
img = enhancer.enhance(2.0)

img.save('captura_proc.png')

result = subprocess.run(
    ['tesseract', 'captura_proc.png', 'stdout', '-l', 'spa+eng'],
    capture_output=True, text=True
)
print(result.stdout)
PYEOF
```

#### 3. Escalar 2x — Para imágenes con texto muy pequeño

```bash
python3 << 'PYEOF'
from PIL import Image
import subprocess

img = Image.open('captura.png')

# Escalar 2x con LANCZOS (alta calidad)
img_hd = img.resize((img.size[0]*2, img.size[1]*2), Image.LANCZOS)
img_hd.save('captura_hd.png')

result = subprocess.run(
    ['tesseract', 'captura_hd.png', 'stdout', '-l', 'spa+eng'],
    capture_output=True, text=True
)
print(result.stdout)
PYEOF
```

---

### ⚠️ Técnicas que NO Recomendar para HyperOS

| Técnica | Problema |
|---|---|
| **Binarización (BW threshold)** | El fondo oscuro de MIUI/HyperOS hace que el texto se pierda |
| **Adaptive threshold** | Crea artefactos en fondos degradados de Android |
| **Pipeline completo** | Acumula errores de cada etapa, empeorando el resultado |
| **Redimensionar a menor resolución** | Hace que el texto sea ilegible para Tesseract |

---

### 🧪 Smart OCR — Script que elige la mejor técnica automáticamente

```bash
python3 << 'PYEOF'
"""OCR inteligente: prueba original y sharpen, elige el mejor resultado"""
from PIL import Image, ImageEnhance
import subprocess, os

def ocr(img_path, lang="spa+eng"):
    result = subprocess.run(
        ['tesseract', img_path, 'stdout', '-l', lang],
        capture_output=True, text=True, timeout=30
    )
    return result.stdout.strip()

def score_text(text):
    """Puntúa cuán "bueno" es un texto OCR (más palabras únicas y largas = mejor)"""
    words = text.split()
    if not words:
        return 0
    # Puntúa: longitud total + palabras únicas + palabras largas
    unique = len(set(words))
    long_words = sum(1 for w in words if len(w) > 5)
    return len(text) + unique * 10 + long_words * 20

IMG = 'screenshot.png'

if not os.path.exists(IMG):
    print(f"❌ No se encuentra: {IMG}")
    exit(1)

print(f"📷 Analizando: {IMG}")

# 1. Original
text_orig = ocr(IMG)
score_orig = score_text(text_orig)
print(f"  Original:    {len(text_orig)} chars, score={score_orig}")

# 2. Sharpen
img = Image.open(IMG)
enhancer = ImageEnhance.Sharpness(img)
img_sharp = enhancer.enhance(2.0)
sharp_path = os.path.expanduser('~/ocr_sharp_temp.png')
img_sharp.save(sharp_path)
text_sharp = ocr(sharp_path)
score_sharp = score_text(text_sharp)
print(f"  Sharpen:     {len(text_sharp)} chars, score={score_sharp}")

# 3. Elegir el mejor
if score_sharp > score_orig:
    print(f"\n✅ Mejor resultado: SHARPEN (score: {score_sharp} vs {score_orig})")
    print("="*50)
    print(text_sharp)
else:
    print(f"\n✅ Mejor resultado: ORIGINAL (score: {score_orig} vs {score_sharp})")
    print("="*50)
    print(text_orig)

# Limpiar temporal
if os.path.exists(sharp_path):
    os.remove(sharp_path)
PYEOF
```

---

### 👇 Flujo recomendado para HyperOS

```
Screenshot (1080×2340)
    │
    ▼
¿El texto se ve nítido?  ──SÍ──→ OCR directo (original) ←── 🥇 MEJOR
    │
    No
    ▼
¿Fondo oscuro con texto claro?  ──SÍ──→ Sharpen + OCR
    │
    No
    ▼
¿Texto muy pequeño?  ──SÍ──→ Escalar 2x + OCR
    │
    No
    ▼
¿Mucho ruido/compresión?  ──SÍ──→ Grayscale + Sharpen + OCR
```

### OCR + análisis combinado (Python)

```bash
python3 -c "
import subprocess
from PIL import Image

img_path = 'screenshot.png'

# Primero mostrar metadatos
img = Image.open(img_path)
print(f'Dimensiones: {img.size}')
print(f'Formato: {img.format}')

# Luego OCR
result = subprocess.run(
    ['tesseract', img_path, 'stdout', '-l', 'spa+eng'],
    capture_output=True, text=True
)
print('\\n=== TEXTO EXTRAÍDO ===')
print(result.stdout)
"
```

---

## 💡 Casos de Uso en HyperOS / Android

### 1. Extraer texto de un diálogo de advertencia Xiaomi

```bash
# 1. Tomar screenshot (con ADB o atajo físico)
# 2. Extraer texto
tesseract /sdcard/DCIM/Screenshots/advertencia.png stdout -l spa
```

### 2. Analizar captura de pantalla de ajustes

```bash
python3 -c "
from PIL import Image
img = Image.open('settings_screenshot.png')
print(f'Resolución: {img.size}')
print(f'Modo: {img.mode}')
# Analizar si es screenshot de HyperOS (1080×2340 es típico de Mi 10)
if img.size == (1080, 2340):
    print('✅ Parece screenshot nativo de Mi 10')
"
```

### 3. Verificar si una imagen es una captura real o editada

```bash
python3 -c "
from PIL import Image
from PIL.ExifTags import TAGS

img = Image.open('imagen.jpg')
exif = img.getexif()

# Las screenshots nativas de Android NO tienen metadatos de cámara
has_camera_data = False
for tag_id in exif:
    name = TAGS.get(tag_id, '')
    if name in ('Make', 'Model', 'FNumber', 'ISOSpeedRatings'):
        has_camera_data = True
        break

if has_camera_data:
    print('📷 Foto original de cámara')
else:
    print('🖥️ Probablemente screenshot o imagen sin metadatos de cámara')
"
```

---

## 🚨 Troubleshooting

| Problema | Solución |
|---|---|
| `ModuleNotFoundError: No module named 'PIL'` | `pip3 install Pillow` |
| `tesseract: command not found` | `pkg install tesseract` (Termux) |
| OCR sale basura / texto ilegible | Idioma español ya instalado. Probar con `-l spa+eng` |
| Imagen no válida / corrupta | Verificar ruta y formato: `file imagen.jpg` |
| Permiso denegado en ruta | Usar ruta en `/sdcard/` o `~/storage/` |

---

## Resumen de Capacidades

| Capacidad | ¿Funciona? | Cómo |
|---|---|---|
| Ver tamaño/dimensiones/ formato | ✅ Sí | Python + Pillow |
| Leer EXIF (cámara, GPS, fecha) | ✅ Sí | Python + Pillow |
| Convertir/redimensionar | ✅ Sí | Python + Pillow |
| Extraer texto (OCR) | ✅ **Tesseract 5.5.3 + español** | `tesseract img.png stdout -l spa+eng` |
| Interpretar visualmente (objetos, rostros, UI) | ❌ No | Limitación del modelo |
| Reconocer si hay un botón, un perro, un texto | ❌ No | Limitación del modelo |

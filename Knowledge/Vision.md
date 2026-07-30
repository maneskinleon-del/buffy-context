# Visión/VLM — Referencia rápida

> Modelos de Vision Language Model (VLM) locales para analizar imágenes
> sin depender de APIs externas.

## Modelos disponibles en Ollama

| Modelo | Tamaño | RAM estimada | Velocidad CPU | Calidad |
|--------|--------|-------------|---------------|---------|
| **minicpm-v** | ~5.5 GB | 7-9 GB | Lenta | ⭐⭐⭐⭐⭐ |
| **moondream** | ~1.7 GB | 2-3 GB | Rápida | ⭐⭐⭐ |
| **llava** | ~4.7 GB | 6-8 GB | Media | ⭐⭐⭐⭐ |
| **qwen2.5-vl:7b** | ~6.0 GB | 9-11 GB | Muy lenta | ⭐⭐⭐⭐⭐ |

**Recomendado:** `minicpm-v` para hardware con 7+ GB libres (CPU-only).
**Alternativa ligera:** `moondream` si la RAM es escasa.

## Comandos básicos

```bash
# Ver modelos instalados
ollama list

# Verificar que el VLM responde
curl -s http://localhost:11434/api/generate \
  -d '{"model":"minicpm-v","prompt":"Di hola","stream":false}'

# Analizar imagen (base64 inline)
base64 -w0 imagen.png | curl -s http://localhost:11434/api/generate \
  -d "{\"model\":\"minicpm-v\",\"prompt\":\"Describe\",\"images\":[\"$(base64 -w0 imagen.png)\"],\"stream\":false}"

# Capturar y analizar screenshot de Android
adb exec-out screencap -p > /tmp/screen.png
base64 -w0 /tmp/screen.png | curl -s http://localhost:11434/api/generate \
  -d "{\"model\":\"minicpm-v\",\"prompt\":\"Describe esta pantalla Android\",\"images\":[\"$(</dev/stdin)\"],\"stream\":false}"
```

## Troubleshooting

- **Ollama no responde**: `systemctl --user restart ollama`
- **Out of memory**: Usar modelo más pequeño (`moondream`), cerrar apps pesadas
- **Primer token muy lento (~30-60s)**: Normal en CPU. Los siguientes son más rápidos
- **Error de imagen**: Verificar que el archivo exista y sea PNG/JPG/WebP válido

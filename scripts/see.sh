#!/bin/bash
# see.sh — describe una imagen usando VLM local vía Ollama
# Uso: see.sh <imagen> [modelo] [prompt]
# Ejemplo: see.sh screenshot.png "Describe esta pantalla"

set -e

IMG="${1:?Uso: see.sh <imagen> [modelo] [prompt]}"
MODEL="${2:-minicpm-v}"
PROMPT="${3:-Describe esta imagen en detalle. ¿Qué ves?}"

if [ ! -f "$IMG" ]; then
    echo "❌ Archivo no encontrado: $IMG"
    exit 1
fi

# Verificar que Ollama está corriendo
if ! curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "❌ Ollama no está corriendo. Ejecuta: systemctl --user start ollama"
    exit 1
fi

# Verificar que el modelo existe
if ! curl -sf http://localhost:11434/api/tags | python3 -c "import json,sys; models=[m['name'] for m in json.load(sys.stdin).get('models',[])]; sys.exit(0 if '$MODEL' in models else 1)" 2>/dev/null; then
    echo "⚠️  Modelo '$MODEL' no encontrado. Instálalo con: ollama pull $MODEL"
    echo "   Modelos disponibles:"
    curl -sf http://localhost:11434/api/tags | python3 -c "import json,sys; [print(f'   - {m[\"name\"]}') for m in json.load(sys.stdin).get('models',[])]" 2>/dev/null
    exit 1
fi

echo "🔍 Analizando: $IMG"
echo "🤖 Modelo: $MODEL"
echo "📝 Prompt: $PROMPT"
echo "---"

START=$(date +%s.%N)

curl -s http://localhost:11434/api/generate \
  -d "$(python3 -c "
import json, base64
with open('$IMG', 'rb') as f:
    b64 = base64.b64encode(f.read()).decode()
print(json.dumps({
    'model': '$MODEL',
    'prompt': '''$PROMPT''',
    'images': [b64],
    'stream': False,
    'options': {'temperature': 0.1}
}))")" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("response", "⚠️  Sin respuesta del modelo"))
except Exception as e:
    print(f"Error: {e}")
'

END=$(date +%s.%N)
DURATION=$(echo "$END - $START" | bc 2>/dev/null || echo "?")
echo "---"
echo "⏱  Tiempo: ${DURATION}s"

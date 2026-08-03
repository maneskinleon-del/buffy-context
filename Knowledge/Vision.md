# Visión/VLM — Referencia rápida

> Modelos de Vision Language Model (VLM) locales para analizar imágenes
> sin depender de APIs externas.

## Versión de Ollama (verificada 2026-08-03)

- **Mínimo recomendado**: **≥ 0.30** (sirve `qwen2.5:7b`, VLM y la API local).
- **Verificado en el PC** (EndeavourOS/Arch): binario `/usr/local/bin/ollama` **0.30.7**
  (el que sirve en `:11434`), paquete pacman `0.32.1-1`. Última release upstream: v0.32.5.
- **Servicio**: `ollama.service` de sistema (`/etc/systemd/system/`) — el servicio de
  usuario (`~/.config/systemd/user/ollama.service`) quedó **deshabilitado** (crash-loop
  por conflicto de puerto con el de sistema, 2026-08-02).
- **Bug conocido**: `ollama run` hace timeout en este entorno → usar siempre la API:
  `curl http://localhost:11434/api/generate`.
- Nota: los tags `:cloud` (p.ej. `nemotron-3-super:cloud`) corren en servidores de
  Ollama, no local — no ocupan RAM pero requieren cuenta en ollama.com.

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

# Analizar imagen (usando see.sh — recomendado)
see.sh imagen.png "Describe esta imagen"
see.sh screenshot.png "Extrae el texto visible"

# Analizar imagen (vía curl directo)
curl -s http://localhost:11434/api/generate \
  -d "$(python3 -c "
import json, base64
with open('imagen.png','rb') as f:
    print(json.dumps({'model':'minicpm-v','prompt':'Describe','images':[base64.b64encode(f.read()).decode()]}))
")" | python3 -c 'import json,sys; print(json.load(sys.stdin)["response"])'

# Capturar y analizar screenshot de Android
adb exec-out screencap -p > /tmp/screen.png && see.sh /tmp/screen.png "Describe esta pantalla Android"
```

## Gestión de memoria RAM

> ⚠️ **Lección aprendida**: Ollama mantiene los modelos VLM cargados en memoria
> después de usarlos. `moondream` (1.7GB en disco) puede ocupar **2.5GB+ en RAM**
> (~40% extra) mientras el proceso `llama-server` está activo.

### Liberar RAM cuando no se usa el VLM

```bash
# Mata solo el modelo VLM, mantiene ollama serve
~/buffy-context/scripts/ollama-kill.sh

# Ver consumo actual
~/buffy-context/scripts/ollama-kill.sh --status

# Matar todo (servidor + modelos)
~/buffy-context/scripts/ollama-kill.sh --all
```

### Automatización (opcional)
Agregar al cierre de sesión de bspwm (`bspwmrc`):
```bash
~/buffy-context/scripts/ollama-kill.sh
```

## Troubleshooting

- **Ollama no responde**: `systemctl --user restart ollama`
- **Out of memory**: Usar `ollama-kill.sh` para liberar, o usar `moondream` en vez de `minicpm-v`
- **Primer token muy lento (~30-60s)**: Normal en CPU. Los siguientes son más rápidos
- **Error de imagen**: Verificar que el archivo exista y sea PNG/JPG/WebP válido

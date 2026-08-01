# 🤖 Kimi K3 — Modelo multimodal vía Hugging Face

> Referencia rápida: cómo usar Kimi K3 (Moonshot AI) desde Hugging Face.
> Actualizado: 2026-08-01

---

## 📌 Qué es

| Campo | Valor |
|---|---|
| **Modelo** | `moonshotai/Kimi-K3` |
| **Creador** | Moonshot AI |
| **Arquitectura** | 2.8T parámetros, Mixture-of-Experts (MoE) |
| **Multimodal** | ✅ nativo (texto + imágenes) |
| **Contexto** | 1M tokens |
| **Licencia** | Kimi K3 License (gated, aceptar términos en HF) |
| **Tool calling** | ✅ soportado (agéntico, JSON mode) |

---

## 🔌 Formas de acceso

| Vía | Detalle |
|---|---|
| **HuggingChat web** | `huggingface.co/chat/models/moonshotai/Kimi-K3` — gratis, navegador |
| **API HF (OpenAI-compatible)** | `https://router.huggingface.co/hf/v1` + token HF (scope read/inference) |
| **API Moonshot** | `platform.kimi.ai` — OpenAI-compatible, pago por uso |
| **Inference Providers** | `moonshotai/Kimi-K3:together`, `:fireworks-ai`, etc. |

### API HF — ejemplo

```bash
export HF_TOKEN="hf_xxx"  # scope: read o inference

curl https://router.huggingface.co/hf/v1/chat/completions \
  -H "Authorization: Bearer $HF_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "moonshotai/Kimi-K3",
    "messages": [{"role": "user", "content": "Hola"}]
  }'
```

> ⚠️ Requiere método de pago configurado en HF (usage-based) según el provider.

---

## ⚠️ MCP ≠ modelo

- **MCP** (Model Context Protocol) conecta **herramientas** a un agente — NO es la forma de "usar el modelo".
- **HuggingChat es cliente MCP**: se le pueden agregar servidores MCP como herramientas, pero el modelo que responde sigue siendo el elegido en el chat.
- El **servidor MCP oficial de HF** (`@huggingface/mcp-server`) expone herramientas del Hub (buscar modelos, leer docs, etc.), no chat con modelos arbitrarios.
- Para usar Kimi K3 como cerebro: vía API OpenAI-compatible o HuggingChat web.

---

## 🎯 Casos de uso (Termux/Android)

1. **Visión real de screenshots** — analizar diálogos de permisos Xiaomi sin depender del OCR (upgrade de `auto_permiso.py`)
2. **Contexto gigante (1M tokens)** — CSVs de SecurGuard, dumpsys completos, logcat
3. **Segunda opinión de código** — revisión de lógica en `fill_form.js`, scripts rish
4. **JSON estructurado / clasificación** — tool calling + JSON mode

---

## 📌 Resumen

- Kimi K3 = modelo multimodal 2.8T de Moonshot AI, 1M contexto, tool calling.
- Acceso: HuggingChat (gratis) o API OpenAI-compatible en `router.huggingface.co` con token HF.
- MCP es para herramientas; el modelo se usa por API.
- Ideal como complemento: visión de screenshots + análisis de contexto grande.

# Instalación

## Requisitos

- Linux (probado en Arch/EndeavourOS) o Termux
- Bash 5+ (o Zsh; los scripts se ejecutan con `bash`)
- Git
- Node.js 18+ — **solo** para `scripts/kimi_vision.js` (usa `fetch` global)
- (Opcional) ADB, scrcpy, Ollama — ver [Dependencias opcionales](#dependencias-opcionales)

### Verificar dependencias

```bash
bash --version | head -1     # Bash 5+
git --version                # Git
node -v                      # Node 18+ (solo kimi_vision.js)

# Opcionales (si falta la herramienta, no pasa nada — son opcionales)
adb version || echo "adb no instalado"
scrcpy --version || echo "scrcpy no instalado"
ollama version || echo "ollama no instalado"

# Salida aceptable: node → v18.x o superior. Las opcionales no tienen versión
# mínima documentada — usa la del repositorio de tu distro.
```

## Setup rápido

```bash
# Clonar (repositorio real)
git clone https://github.com/maneskinleon-del/buffy-context.git ~/buffy-context
cd ~/buffy-context

# (Opcional) Vincular scripts al PATH — para invocarlos como binarios (buffy-doctor.sh)
mkdir -p ~/.local/bin
chmod +x "$PWD/scripts/"*.sh      # marca los scripts como ejecutables
# ⚠️ En Termux la invocación directa NO funciona: los scripts usan shebang
#    #!/usr/bin/env bash y /usr/bin/env no existe ahí — usa siempre bash script.sh.
# NOTA: ln -sf SOBRESCRIBE binarios existentes con el mismo nombre en ~/.local/bin.
# Verifica primero:  ls ~/.local/bin/ | grep buffy
ln -sf "$PWD/scripts/buffy-context.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-doctor.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-repair.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-agent.sh" ~/.local/bin/
ln -sf "$PWD/scripts/buffy-router.sh" ~/.local/bin/
ln -sf "$PWD/scripts/android-detect.sh" ~/.local/bin/

# Asegúrate de que ~/.local/bin esté en $PATH
# (si no, añádelo en ~/.bashrc o ~/.zshrc:  export PATH="$HOME/.local/bin:$PATH" )
echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin" && echo "OK: en PATH" || echo "FALTA: ~/.local/bin no está en PATH"

# Los scripts también pueden ejecutarse con 'bash script.sh' (no requieren bit de ejecución).
```

### Nota Termux

En Termux `/usr/bin/env` no existe (bash real: `$PREFIX/bin/bash`). Por eso:

- Ejecuta siempre con `bash` explícito: `bash scripts/buffy-doctor.sh --quick`
- El pre-commit hook se instala con el shebang real del sistema mediante el installer:

```bash
bash scripts/hooks/install.sh          # instala .git/hooks/pre-commit
bash scripts/hooks/install.sh --check  # verifica hook + shebang
```

> Detalle completo del hook en el README (sección Testing → Pre-commit hook).

## Smoke test (post-instalación)

Confirma que todo funciona:

```bash
# 1. Generar snapshot del sistema (se escribe en $HOME/ai-context/)
bash scripts/buffy-context.sh
test -f ~/ai-context/SNAPSHOT.md && echo "✅ SNAPSHOT.md generado"

# 2. Auditoría de salud (resumen de una línea)
# NOTA: con drift conocido sale con exit 1 — es su comportamiento normal.
bash scripts/buffy-doctor.sh --quick

# 3. Suite de tests rápida (salta ciclos de sandbox)
bash scripts/tests/run-tests.sh --quick

# 4. (Si linkeaste al PATH) probar invocación directa como binario
#    (solo en Linux — en Termux no hay /usr/bin/env, usa bash script.sh)
command -v buffy-doctor.sh && buffy-doctor.sh --quick
```

## Dependencias opcionales

| Herramienta | Para qué | Instalación (ejemplos) |
|---|---|---|
| **Node 18+** | `scripts/kimi_vision.js` (visión IA) | Arch: `pacman -S nodejs` · Debian/Ubuntu: `apt install nodejs` · Termux: `pkg install node` |
| **ADB** | Diagnóstico y automatización Android | Arch: `pacman -S android-tools` · Debian/Ubuntu: `apt install adb` · Termux: `pkg install android-tools` |
| **scrcpy** | Mirroring de Android | Arch: `pacman -S scrcpy` · Debian/Ubuntu: `apt install scrcpy` · Termux: `pkg install scrcpy` |
| **Ollama** | LLM local (opcional) | [ollama.com](https://ollama.com) — script oficial de instalación |

> `kimi_vision.js` necesita además `HF_TOKEN` — token de Hugging Face (scope read/inference),
> **no** una API key de Kimi — y aceptar la licencia del modelo gated. Ver `Knowledge/AI/Kimi-K3.md`.

## Seguridad / sandbox

- `buffy-repair --auto` aplica **solo fixes AUTO_SAFE** y verifica. Antes de aplicar, revisa el plan:

```bash
bash scripts/buffy-repair.sh            # plan (dry-run, no aplica nada)
bash scripts/buffy-repair.sh --auto     # aplica solo lo seguro
```

- Las operaciones que escriben (repair/agent) corren en un **sandbox con HOME aislado** dentro de la suite de tests; el repo real solo se lee (doctor, dry-run, `--no-repair`).

## Vincular ai-context original

Si ya tienes `~/ai-context/` funcionando y quieres mantener ambos sincronizados:

```bash
# El repo es la fuente de verdad. Copia sin sobrescribir archivos existentes:
cp -rn ~/buffy-context/ai-context/* ~/ai-context/
# Alternativa con backup de lo que se sobrescriba (requiere rsync):
# rsync -a --backup --suffix=.bak ~/buffy-context/ai-context/ ~/ai-context/

# Y viceversa (después de una sesión):
cp ~/ai-context/CONTINUE.md ~/ai-context/SESION.md ~/buffy-context/ai-context/
```

## Uso con otros agentes

Si quieres que otro agente IA (Antigravity, Claude, etc.) use el mismo contexto:

```bash
# Solo comparte la ruta y dile que lea:
# - buffy-context/ai-context/LOAD_CONTEXT.md (protocolo)
# - buffy-context/ai-context/CONTINUE.md (handoff)
# - buffy-context/Knowledge/ (base de conocimiento)
```

## Regenerar SNAPSHOT.md

```bash
bash ~/buffy-context/scripts/buffy-context.sh
# Se crea en ~/ai-context/SNAPSHOT.md  ($HOME/ai-context/ — NO en el repo)
# (No está en git — se regenera cada sesión)
```

## Diagnóstico Android

```bash
bash ~/buffy-context/scripts/android-detect.sh    # Completo
bash ~/buffy-context/scripts/android-detect.sh --quick  # Resumen
bash ~/buffy-context/scripts/android-detect.sh --watch   # Live loop
```

## Ciclo operativo (doctor → repair → agent)

Buffy puede diagnosticar su propio estado, corregir lo seguro y verificar antes de trabajar:

```bash
# Auditoría de salud del ecosistema (humano o JSON)
bash ~/buffy-context/scripts/buffy-doctor.sh
bash ~/buffy-context/scripts/buffy-doctor.sh --json

# Plan de reparación (dry-run, no aplica nada)
bash ~/buffy-context/scripts/buffy-repair.sh

# Aplicar solo fixes AUTO_SAFE y verificar
bash ~/buffy-context/scripts/buffy-repair.sh --auto

# Ciclo completo: preflight → repair → verify → carga de contexto
bash ~/buffy-context/scripts/buffy-agent.sh "tu mensaje"
bash ~/buffy-context/scripts/buffy-agent.sh --json
```

Exit codes: `buffy-agent` y `buffy-repair` usan `0` = consistente, `1` = drift que requiere decisión humana, `2` = error de uso.

En Termux, ejecuta siempre con `bash` explícito (ver nota arriba).

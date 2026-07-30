# Instalación

## Requisitos

- Linux (probado en Arch/EndeavourOS)
- Bash 5+ / Zsh
- Git
- (Opcional) ADB para el agente Android

## Setup rápido

```bash
# Clonar
git clone https://github.com/tu-usuario/buffy-context.git ~/buffy-context

# (Opcional) Vincular scripts al PATH
ln -sf ~/buffy-context/scripts/buffy-context.sh ~/.local/bin/
ln -sf ~/buffy-context/scripts/android-detect.sh ~/.local/bin/
```

## Vincular ai-context original

Si ya tienes `~/ai-context/` funcionando y quieres mantener ambos sincronizados:

```bash
# El repo es la fuente de verdad. Copia los archivos del repo a ~/ai-context/:
cp -r ~/buffy-context/ai-context/* ~/ai-context/

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
# Se crea en ~/buffy-context/ai-context/SNAPSHOT.md
# (No está en git — se regenera cada sesión)
```

## Diagnóstico Android

```bash
bash ~/buffy-context/scripts/android-detect.sh    # Completo
bash ~/buffy-context/scripts/android-detect.sh --quick  # Resumen
bash ~/buffy-context/scripts/android-detect.sh --watch   # Live loop
```

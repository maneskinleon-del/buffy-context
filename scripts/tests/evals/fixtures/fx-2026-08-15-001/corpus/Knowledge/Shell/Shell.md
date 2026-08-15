# Shell Scripting — Referencia rápida

> Shell del usuario: **zsh** (Oh My Zsh + Starship).
> Bash disponible como alternativa.
> Locale: `es_CL.UTF-8`.

## Shebang

```bash
#!/usr/bin/env bash      # Portable
#!/bin/bash               # Específico
#!/usr/bin/env zsh        # Zsh
```

## Variables

```bash
# Asignación
NOMBRE="valor"
NUMERO=42

# Uso
echo "$NOMBRE"
echo "${NOMBRE}_sufijo"

# Arrays
ARRAY=("a" "b" "c")
echo "${ARRAY[0]}"       # Primer elemento
echo "${ARRAY[@]}"       # Todos los elementos
echo "${#ARRAY[@]}"      # Cantidad

# Default
echo "${VAR:-default}"   # Usa default si VAR no está definida
echo "${VAR:=default}"   # Asigna default si VAR no está definida
```

## Condicionales

```bash
if [[ "$VAR" == "valor" ]]; then
  comando
elif [[ -z "$VAR" ]]; then
  echo "Vacía"
else
  echo "Otro"
fi

# Archivos
[[ -f "$archivo" ]]      # Existe y es archivo
[[ -d "$directorio" ]]   # Existe y es directorio
[[ -z "$var" ]]          # Vacía
[[ -n "$var" ]]          # No vacía
[[ $? -eq 0 ]]           # Último comando exitoso
```

## Loops

```bash
# For
for item in "${ARRAY[@]}"; do
  echo "$item"
done

# While
while read -r line; do
  echo "$line"
done < archivo.txt

# Números
for i in {1..10}; do
  echo "$i"
done
```

## Funciones

```bash
my_function() {
  local arg1="$1"
  local arg2="$2"
  echo "$arg1 $arg2"
  return 0
}
```

## Awk (procesamiento de texto)

```bash
# Columna específica
awk '{print $1, $3}' archivo.txt

# Filtrado
awk '/patron/ {print $2}' archivo.txt

# Con separador
awk -F: '{print $1}' /etc/passwd
```

## Sed (edición de texto)

```bash
# Reemplazar
sed -i 's/viejo/nuevo/g' archivo.txt

# Línea específica
sed -n '10,20p' archivo.txt

# Eliminar líneas
sed -i '/patron/d' archivo.txt
```

## Trap (cleanup)

```bash
cleanup() {
  rm -f /tmp/tempfile
  echo "🧹 Limpieza completa"
}
trap cleanup EXIT
trap cleanup SIGINT SIGTERM
```

## Tips

- Siempre usar `[[ ]]` en vez de `[ ]` (menos bugs)
- Usar `"$variable"` con comillas dobles para evitar word splitting
- `set -e` para salir en error, `set -x` para debug
- `trap cleanup EXIT` para limpiar recursos al salir
- Preferir `read -r` (raw) para evitar que `\` se interprete
- `mktemp` para crear archivos temporales seguros

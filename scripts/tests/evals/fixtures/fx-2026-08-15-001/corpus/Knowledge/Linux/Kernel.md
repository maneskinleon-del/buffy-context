# Linux Kernel — Referencia rápida

> Gestión del kernel Linux en Arch/EndeavourOS.
> Kernel actual del usuario: **6.18.39-1-lts**

## Versiones

```bash
uname -r                              # Kernel en uso
pacman -Q linux                       # Kernel instalado
pacman -Q linux-lts                   # Kernel LTS instalado
pacman -Qs linux                      # Todos los kernels
```

## Parámetros de arranque

```bash
# Ver parámetros actuales
cat /proc/cmdline

# Configuración (systemd-boot)
ls /efi/loader/entries/               # Entradas de boot
cat /efi/loader/loader.conf           # Config del loader

# Agregar parámetros
# Editar /efi/loader/entries/arch.conf
# Agregar: nvidia_drm.modeset=1 ... al final de la línea options
```

## Módulos

```bash
lsmod                                 # Módulos cargados
modinfo <módulo>                      # Info del módulo
sudo modprobe <módulo>                # Cargar módulo
sudo modprobe -r <módulo>             # Descargar módulo
```

## Rendimiento

```bash
# Sysctl (parámetros del kernel en runtime)
sysctl -a | grep <patrón>             # Ver parámetros
sudo sysctl -w <param>=<valor>        # Cambiar (no persistente)

# Parámetros útiles para gaming/rendimiento
vm.swappiness=10                      # Usar swap solo cuando sea necesario
kernel.numa_balancing=0               # Desactivar balanceo NUMA (CPU única)
net.core.rmem_max=134217728           # Buffer de red máximo
```

## dmesg / logs

```bash
dmesg -w                              # Logs del kernel en vivo
dmesg | grep -i error                 # Errores del kernel
dmesg | grep -i usb                   # Eventos USB
journalctl -k                         # Logs del kernel (systemd)
journalctl -k -p 3                    # Errores del kernel solamente
```

## Compilación (si aplica)

```bash
# Parámetros de compilación del kernel actual
zcat /proc/config.gz | grep <OPCIÓN>

# Si no existe /proc/config.gz:
modprobe configs
cat /proc/config.gz | gunzip | grep <OPCIÓN>
```

# Linux System — Referencia rápida

> Arch/EndeavourOS, bspwm, systemd, picom, y gestión del sistema.
> Para contexto completo del sistema del usuario → `ai-context/INFO-core.md`.

## Gestión de paquetes

```bash
# Pacman
sudo pacman -Syu              # Actualizar todo
sudo pacman -S <paquete>      # Instalar
sudo pacman -Rns <paquete>    # Eliminar (con dependencias)
sudo pacman -Qe                # Paquetes explícitamente instalados
sudo pacman -Qdt               # Huérfanos (dependencias no necesarias)

# AUR (paru)
paru -S <paquete>              # Instalar desde AUR
paru -Syu                      # Actualizar todo (incluye AUR)
paru -Qm                       # Paquetes del AUR
```

## bspwm

```bash
# Atajos clave (vía sxhkd)
Alt + Space                    # Launcher (rofi)
Alt + Enter                    # Terminal (alacritty)
Super + {1-6}                  # Cambiar workspace
Super + Shift + {1-6}          # Mover ventana a workspace

# Comandos bspc
bspc wm -r                     # Recargar configuración
bspc rule -a <app> -o desktop='^1'  # Regla para abrir app en workspace
bspc desktop -f ^1             # Ir a workspace 1
bspc node -k                   # Cerrar ventana enfocada
bspc node -f {left,down,up,right}  # Navegación directional
bspc config top_padding 30     # Padding superior (polybar)

# Recargar rice
RICE=$(cat ~/.config/bspwm/.rice)
~/.config/bspwm/rices/$RICE/Theme.sh
```

## systemd

```bash
# Servicios de usuario (--user)
systemctl --user status <servicio>     # Estado
systemctl --user start <servicio>      # Iniciar
systemctl --user enable <servicio>     # Habilitar en inicio
systemctl --user list-units           # Listar servicios activos
journalctl --user -u <servicio> -f     # Logs en vivo

# Servicios del sistema
sudo systemctl status <servicio>
sudo journalctl -u <servicio>
```

## picom (compositor)

```bash
# Iniciar
picom -b

# Verificar
ps aux | grep picom

# Reglas de transparencia/blur
# ~/.config/bspwm/config/picom/picom-rules.conf
```

## Alacritty

| Config | Archivo |
|--------|---------|
| Fuente | `~/.config/alacritty/fonts.toml` |
| Opacidad | `~/.config/alacritty/alacritty.toml` |
| Rice setea | `rices/<nombre>/theme-config.bash` → `P_TERM_OPACITY` |

La opacidad se sobreescribe en cada inicio de sesión por el módulo `05-alacritty.sh` del rice activo. Para cambiarla permanentemente, editar `theme-config.bash`.

## Polybar

```bash
# Recargar
polybar-msg cmd quit
MONITOR=HDMI-1 polybar <bar-name> -c ~/.config/bspwm/rices/$RICE/config.ini &

# Logs
journalctl --user -u polybar -f
```

## X11 / Wayland

```bash
# Sesión actual
echo $XDG_SESSION_TYPE    # x11 o wayland
echo $DESKTOP_SESSION     # bspwm, mango, plasma, etc.

# xrandr (resolución)
xrandr --output HDMI-1 --mode 1360x768 --rate 60.02

# Monitores disponibles
xrandr -q
```

#!/system/bin/sh
# collect.sh — reúne evidencia de PackageManager para android-package-origin-audit.
# Uso: ASHELL="adb shell" ./collect.sh | ASHELL="rish -c" ./collect.sh | ./collect.sh (root)
# Artefactos read-only: dumpsys/pm list/getprop/cmd package/settings/getprop.
set -eu
ASHELL="${ASHELL:-su -c}"
D="${OUTDIR:-/data/data/com.termux/files/home}"
mkdir -p "$D"
run() { $ASHELL "$*"; }          # para redirecciones simples (echo inofensivo)

# --- PackageManager (full dump, source of truth) ---
run "dumpsys package packages"   > "$D/pkg_dumpsys_full.txt"
run "dumpsys package"            > "$D/dumpsys_package_FULL.txt"   # full dump: Resolver Tables (parse_resolvers)

# --- listas pm (formato `package:name`); pkgs_plain.txt es lo que parse_full lee ---
run "pm list packages"      > "$D/pkgs_plain.txt"   # instalados AHORA (pm_plain)
run "pm list packages -s"     > "$D/pkgs_sys.txt"     # FLAG_SYSTEM
run "pm list packages -3"     > "$D/pkgs_third.txt"   # FLAG_INSTALLED sin SYSTEM
run "pm list packages -u"     > "$D/pkgs_u_f.txt"     # incl. desinstalados
run "pm list packages -f -i"  > "$D/pkgs_all_fi.txt"  # codePath + installer

# --- uid por paquete (formato package:NAME uid:NNN que parse_uid_map consume) ---
# El dump muestra `  Package [com.foo] (hash):` seguido de `    appId=NNNN`.
run "dumpsys package packages" | awk '
  /^  Package \[/ { m=$0; sub(/^  Package \[/,"",m); sub(/\].*/,"",m); pkg=m }
  pkg && /appId=/ { split($0,a,"="); gsub(/[^0-9]/,"",a[2]); printf "package:%s uid:%s\n", pkg, a[2]; pkg="" }
' > "$D/pkgs_uids.txt"

# --- componentes y servicios ---
run "cmd package query-receivers -a android.intent.action.BOOT_COMPLETED" > "$D/boot_receivers_raw.txt"
run "cmd package resolve-activity -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -c android.intent.category.DEFAULT" > "$D/launcher_acts.txt"
run "dumpsys activity services" > "$D/dumpsys_services.txt"
run "dumpsys jobscheduler"      > "$D/dumpsys_jobs.txt"
run "dumpsys alarm"             > "$D/dumpsys_alarm.txt"

# --- energia (formato legible: `    UID <id>: <mah> ... bg: .. fgs: ..`; parse_power) ---
run "dumpsys batterystats"     > "$D/power_use.txt"

# --- proceso, doze, políticas, backup, props ---
run "ps -A"                > "$D/ps_all.txt"
run "dumpsys deviceidle whitelist" > "$D/doze_whitelist.txt"
run "dumpsys device_policy"      > "$D/dumpsys_devpolicy.txt"
run "dumpsys backup"             > "$D/dumpsys_backup.txt"
run "getprop"                > "$D/ota_props.txt"

# --- epoch de arranque (parse_full.py lee HOME+'boot_epoch.txt') ---
# /proc/stat btime = boot epoch en segundos (root/rish). Un numero -> float()
run "grep btime /proc/stat" | awk '{print $2}' > "$D/boot_epoch.txt"

# --- defaults del sistema (IME / listeners / asistente): UN SOLO ARCHIVO ---
# Layout posicional d[0..4] que load_signals() consume por orden (no por echo).
# Se usa $ASHELL directamente para evitar cualquier ambigüedad de run().
{
  $ASHELL "settings get secure default_input_method"
  printf 'null\n'
  $ASHELL "settings get secure enabled_notification_listeners"
  printf 'null\n'
  $ASHELL "settings get secure voice_interaction_service"
} > "$D/defaults.txt"

printf 'observacion -> evidencia -> clasificacion -> matriz -> revision humana -> accion\n' > "$D/CHECKLIST.txt"
echo "OK: evidence collected into $D"

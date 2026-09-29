#!/data/data/com.termux/files/usr/bin/python3
"""Parse dumpsys package output (clean full dump) into an evidence table.

Evidence sources per package:
  - active codePath partition + flags + pkgFlags
  - isMiuiPreinstall (MIUI preinstall marker)
  - hidden system copy (package exists in system image) -> "Hidden system packages:"
  - installerPackageName / initiatingPackageName / originatingPackageName
  - packageSource / appMetadataSource
  - firstInstallTime / lastUpdateTime / installReason (per user 0)
  - installed state, pm -s / -3 / -u lists
"""
import re, csv, sys, time
from datetime import datetime

HOME = '/data/data/com.termux/files/home/'


def boot_epoch():
    """Device boot time: /proc/uptime is blocked for apps on Android, so fall back
    to the value captured from a shell (rish) session in boot_epoch.txt."""
    try:
        with open('/proc/uptime') as f:
            return time.time() - float(f.read().split()[0])
    except Exception:
        pass
    try:
        with open(HOME + 'boot_epoch.txt') as f:
            return float(f.read().strip())
    except Exception:
        return None


BOOT_EPOCH = boot_epoch()


def parse_dt(s):
    try:
        return datetime.strptime(s, '%Y-%m-%d %H:%M:%S').timestamp()
    except Exception:
        return None


PKG_RE = re.compile(r'^  Package \[([^\]]+)\] \((\w+)\):')
USER_RE = re.compile(r'^    User (\d+): (.*)$')
FIELD4_RE = re.compile(r'^    ([A-Za-z][A-Za-z0-9_]*)=(.*)$')
FIELD6_RE = re.compile(r'^      ([A-Za-z][A-Za-z0-9_]*)=(.*)$')

PKG_FIELDS = ('codePath', 'versionCode', 'versionName', 'isMiuiPreinstall', 'flags',
              'timeStamp', 'lastUpdateTime', 'installerPackageName', 'installerPackageUid',
              'initiatingPackageName', 'originatingPackageName', 'packageSource',
              'appMetadataFilePath', 'appMetadataSource', 'pkgFlags')
USER_FIELDS = ('installReason', 'uninstallReason', 'firstInstallTime')

def parse(path):
    main, hidden = {}, {}
    section = main
    cur = None
    with open(path, errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            if line.startswith('Hidden system packages:'):
                section, cur = hidden, None
                continue
            m = PKG_RE.match(line)
            if m:
                cur = {'pkg': m.group(1), 'hash': m.group(2), 'user0_installed': None}
                section.setdefault(m.group(1), cur)
                continue
            if cur is None:
                continue
            mu = USER_RE.match(line)
            if mu:
                if mu.group(1) == '0':
                    # varias entradas "User 0:" por paquete; installed=true prevalece
                    val = 'installed=true' in mu.group(2)
                    if cur['user0_installed'] is None or val:
                        cur['user0_installed'] = val
                continue
            m4 = FIELD4_RE.match(line)
            if m4 and m4.group(1) in PKG_FIELDS:
                cur.setdefault(m4.group(1), m4.group(2))
                continue
            m6 = FIELD6_RE.match(line)
            if m6 and m6.group(1) in USER_FIELDS:
                cur.setdefault(m6.group(1), m6.group(2))
    return main, hidden


def load_list(name):
    out = set()
    with open(HOME + name, errors='replace') as f:
        for line in f:
            line = line.strip()
            if line.startswith('package:'):
                out.add(line[len('package:'):])
    return out

pm_plain = load_list('pkgs_plain.txt')   # installed right now
pm_sys   = load_list('pkgs_sys.txt')     # pm -s (FLAG_SYSTEM)
pm_third = load_list('pkgs_third.txt')   # pm -3
pm_un    = load_list('pkgs_u_f.txt')     # incl. uninstalled

PART = ('/system_ext', '/product', '/vendor', '/apex', '/system', '/odm', '/data')

def partition(cp):
    if not cp:
        return 'UNKNOWN'
    for p in PART:
        if cp.startswith(p + '/'):
            return 'data' if p == '/data' else p[1:]
    return 'other'

# channel names for installer packages
CHANNEL = {
    'com.android.vending': 'PLAY_STORE',
    'com.google.android.packageinstaller': 'PACKAGE_INSTALLER',
    'com.xiaomi.discover': 'XIAOMI_GETAPPS',
    'com.xiaomi.mipicks': 'XIAOMI_GETAPPS',
    'com.facebook.system': 'FACEBOOK_PRELOAD_AGENT',
    'com.miui.analytics': 'MIUI_ANALYTICS',
    'com.google.android.shell': 'ADB_SHELL',
}

# installReason (AOSP PackageManager): 0 UNKNOWN, 1 POLICY, 2 DEVICE_RESTORE,
# 3 DEVICE_SETUP, 4 USER
REASON = {'0': 'UNKNOWN', '1': 'POLICY', '2': 'DEVICE_RESTORE', '3': 'DEVICE_SETUP',
          '4': 'USER', None: 'UNKNOWN'}
# packageSource (AOSP PackageInstaller): 0 UNSPECIFIED, 1 STORE, 2 LOCAL_FILE,
SOURCE = {'0': 'UNSPECIFIED', '1': 'STORE', '2': 'LOCAL_FILE', '3': 'DOWNLOADED_FILE',
          '4': 'OTHER', None: 'UNSPECIFIED'}


def classify(r, hid):
    cp = r.get('codePath', '')
    part = partition(cp)
    flags = (r.get('flags') or '').split()
    is_sys = 'SYSTEM' in flags
    upd = 'UPDATED_SYSTEM_APP' in flags
    inst = (r.get('installerPackageName') or 'null')
    chan = CHANNEL.get(inst, inst)
    reason = REASON.get(r.get('installReason'), 'UNKNOWN')
    src = SOURCE.get(r.get('packageSource'), 'UNSPECIFIED')
    first = r.get('firstInstallTime', '')
    date = first[:10]
    miui = r.get('isMiuiPreinstall') == 'true'
    has_img_copy = r['pkg'] in hid
    installed = r['pkg'] in pm_plain
    epoch = first.startswith('1970')

    ev = [f'part={part}',
          f'flags={"SYS+UPD" if is_sys and upd else ("SYS" if is_sys else "3rd")}',
          f'img_copy={"yes" if has_img_copy else "no"}',
          f'isMiuiPreinstall={miui}',
          f'installer={inst}',
          f'initiating={r.get("initiatingPackageName","")}',
          f'source={src}',
          f'installReason={reason}',
          f'first={date}',
          f'state={"installed" if installed else "uninstalled"}']

    if not installed:
        if has_img_copy or part != 'data':
            return 'IMAGEN_PERO_NO_INSTALADO', ev
        return 'DATOS_RESIDUALES_NO_INSTALADO', ev

    if part == 'data' and not has_img_copy and not is_sys:
        if reason in ('DEVICE_RESTORE', 'DEVICE_SETUP'):
            return 'USUARIO_RESTAURADO_' + reason, ev
        if reason == 'USER' or src in ('STORE', 'DOWNLOADED_FILE'):
            if chan == 'PLAY_STORE':
                return 'USUARIO_PLAY', ev
            if chan == 'PACKAGE_INSTALLER':
                return 'USUARIO_SIDELOAD', ev
            if chan == 'XIAOMI_GETAPPS':
                return 'USUARIO_XIAOMI_GETAPPS', ev
            if chan == 'ADB_SHELL':
                return 'USUARIO_ADB', ev
            if inst != 'null':
                return 'USUARIO_VIA_' + inst, ev
            return 'USUARIO_CANAL_DESCONOCIDO', ev
        return 'UNKNOWN_APK_EN_DATOS_PROVISIONING', ev

    if is_sys and upd:
        if chan == 'PLAY_STORE':
            return 'PREINSTALADO_ACTUALIZADO_PLAY', ev
        if chan == 'XIAOMI_GETAPPS':
            return 'PREINSTALADO_ACTUALIZADO_GETAPPS', ev
        if inst == 'null':
            return 'PREINSTALADO_ACTUALIZADO_SIN_INSTALADOR', ev
        return 'PREINSTALADO_ACTUALIZADO_' + chan, ev
    if part != 'data':
        t = parse_dt(first)
        if t and BOOT_EPOCH and t >= BOOT_EPOCH - 600:
            ev.append('sugerencia_ota_por_fecha=si')   # evidencia, NO clasificacion (ver §5.9/§5.12)
        if epoch:
            return 'PREINSTALADO_IMAGEN', ev
        return 'PREINSTALADO_IMAGEN_FECHA_TARDIA', ev
    if has_img_copy:
        return 'PREINSTALADO_COPIA_EN_DATOS', ev
    return 'UNKNOWN', ev

# 3 DOWNLOADED_FILE, 4 OTHER

def load_fi():
    """pkg -> (codePath, installer) from `pm list packages -f -i`."""
    d = {}
    with open(HOME + 'pkgs_all_fi.txt', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line.startswith('package:'):
                continue
            body = line[len('package:'):]
            m = re.search(r'\s+installer=(\S+)\s*$', body)
            inst = m.group(1) if m else 'null'
            if m:
                body = body[:m.start()].rstrip()
            if '=' in body:
                path, pkg = body.rsplit('=', 1)
            else:
                path, pkg = '', body
            d[pkg] = (path, inst)
    return d


def main():
    main_sec, hidden = parse(HOME + 'pkg_dumpsys_full.txt')
    fi = load_fi()
    rows = []
    for pkg in sorted(main_sec):
        r = main_sec[pkg]
        origin, ev = classify(r, hidden)
        h = hidden.get(pkg, {})
        rows.append({
            'pkg': pkg,
            'origin': origin,
            'partition': partition(r.get('codePath', '')),
            'img_copy': 'yes' if pkg in hidden else 'no',
            'img_codePath': h.get('codePath', ''),
            'isMiuiPreinstall': r.get('isMiuiPreinstall', ''),
            'flags': r.get('flags', ''),
            'installer': r.get('installerPackageName', ''),
            'initiating': r.get('initiatingPackageName', ''),
            'packageSource': r.get('packageSource', ''),
            'appMetadataSource': r.get('appMetadataSource', ''),
            'installReason': r.get('installReason', ''),
            'firstInstall': r.get('firstInstallTime', ''),
            'lastUpdate': r.get('lastUpdateTime', ''),
            'version': r.get('versionName', ''),
            'pm3': 'yes' if pkg in pm_third else 'no',
            'in_pm_list': 'yes' if pkg in pm_plain else 'no',
            'installed_user0': str(r.get('user0_installed')),
            'evidence': ';'.join(ev),
        })
    # paquetes instalados cuyo encabezado se perdio en la captura (artefacto PTY):
    # se completa el origen con la ruta real del APK y el instalador de `pm -f -i`.
    for pkg in sorted(pm_plain - set(main_sec)):
        path, inst = fi.get(pkg, ('', ''))
        part = partition(path)
        origin = 'PREINSTALADO_IMAGEN' if part != 'data' else 'UNKNOWN_APK_EN_DATOS_PROVISIONING'
        rows.append({
            'pkg': pkg, 'origin': origin, 'partition': part, 'img_copy': 'no',
            'img_codePath': '', 'isMiuiPreinstall': '', 'flags': '',
            'installer': inst, 'initiating': '', 'packageSource': '',
            'appMetadataSource': '', 'installReason': '', 'firstInstall': '',
            'lastUpdate': '', 'version': '', 'pm3': 'yes' if pkg in pm_third else 'no',
            'in_pm_list': 'yes', 'installed_user0': 'True',
            'evidence': f'encabezado_dumpsys_perdido(captura_pty);part={part};'
                        f'path={path};installer={inst};state=installed',
        })
    with open(HOME + 'pkg_origin.tsv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]), delimiter='\t')
        w.writeheader()
        w.writerows(rows)

    from collections import Counter
    print('filas:', len(rows), '| seccion principal:', len(main_sec),
          '| copias en imagen:', len(hidden))
    print('instalados == pm list:',
          {r['pkg'] for r in rows if r['in_pm_list'] == 'yes'} == pm_plain)
    for k, v in Counter(r['origin'] for r in rows).most_common():
        print(f'{v:4d}  {k}')


if __name__ == '__main__':
    main()

SOURCE = {'0': 'UNSPECIFIED', '1': 'STORE', '2': 'LOCAL_FILE', '3': 'DOWNLOADED_FILE',
          '4': 'OTHER', None: 'UNSPECIFIED'}

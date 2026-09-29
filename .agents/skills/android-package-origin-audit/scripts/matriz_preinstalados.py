#!/data/data/com.termux/files/usr/bin/python3
"""Segunda matriz: 365 preinstalados -> funcion, dependencias, proceso/servicio, impacto,
categoria (1-9) y candidato/no candidato. NO desinstala nada."""
import re, csv, os
from collections import Counter, defaultdict

H = '/data/data/com.termux/files/home/'
PKG_RE = re.compile(r'^  Package \[([^\]]+)\] \((\w+)\):')
USER_RE = re.compile(r'^    User (\d+): ')
F4 = re.compile(r'^    ([A-Za-z][A-Za-z0-9_]*)=(.*)$')
PERM_RE = re.compile(r'^\s+([A-Za-z0-9_.]+): granted=(true|false)')
SECTION_RE = re.compile(r'^([A-Z][A-Za-z ]+):\s*$')


def parse_blocks(path):
    """Campos extra por paquete desde el volcado completo."""
    out, cur, section = {}, None, None
    with open(path, errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            m = PKG_RE.match(line)
            if m:
                cur = {'pkg': m.group(1)}
                out.setdefault(m.group(1), cur)
                section = None
                continue
            if cur is None:
                continue
            if line.startswith('  ') and not line.startswith('    ') and line.strip().endswith(':'):
                section = line.strip()[:-1]
                continue
            m4 = F4.match(line)
            if m4:
                k, v = m4.group(1), m4.group(2)
                if k in ('appId', 'sharedUser', 'pkgFlags', 'privateFlags', 'apexModuleName',
                         'isMiuiPreinstall', 'codePath', 'versionName', 'queriesPackages',
                         'sharedUser'):
                    cur.setdefault(k, v)
                continue
            mp = PERM_RE.match(line)
            if mp and mp.group(2) == 'true':
                cur.setdefault('perms', set()).add(mp.group(1))
    return out


RESOLVER_KEYS = {'Activity Resolver Table': 'activities',
                 'Receiver Resolver Table': 'receivers',
                 'Service Resolver Table': 'services',
                 'Provider Resolver Table': 'providers'}


def parse_resolvers(path):
    """Componentes por paquete desde las tablas de resolucion del dump completo."""
    comp = defaultdict(lambda: {'activities': 0, 'receivers': 0, 'services': 0,
                                'providers': 0, 'actions_rx': set(), 'authorities': set()})
    section, action, cur_pkg = None, None, None
    last_authority = None
    with open(path, errors='replace') as f:
        for line in f:
            line = line.rstrip('\n')
            s = line.strip()
            if not s:
                continue
            if s in ('Activity Resolver Table:', 'Receiver Resolver Table:',
                     'Service Resolver Table:', 'Provider Resolver Table:',
                     'Registered ContentProviders:', 'ContentProvider Authorities:'):
                section, action, cur_pkg, last_authority = s[:-1], None, None, None
                continue
            if section is None:
                continue
            indent = len(line) - len(line.lstrip(' '))
            if section in RESOLVER_KEYS:
                if indent == 6 and s.endswith(':'):
                    action = s.rstrip(':').strip('"')
                    continue
                if indent == 8:
                    m = re.match(r'^[0-9a-f]+ ([A-Za-z0-9_.]+)/(\S+)', s)
                    if m:
                        pkg = m.group(1)
                        cur_pkg = pkg
                        key = RESOLVER_KEYS[section]
                        comp[pkg][key] += 1
                        if key == 'receivers' and action:
                            comp[pkg]['actions_rx'].add(action)
                    continue
                continue
            if section == 'Registered ContentProviders':
                if indent == 2 and s.endswith(':'):
                    m = re.match(r'^([A-Za-z0-9_.]+)/', s)
                    if m:
                        comp[m.group(1)]['providers'] += 1
                continue
            if section == 'ContentProvider Authorities':
                if indent == 2 and s.startswith('['):
                    last_authority = s.rstrip(':').strip('[]')
                    continue
                if indent == 4 and last_authority:
                    m = re.match(r'^Provider\{\w+ ([A-Za-z0-9_.]+)/', s)
                    if m:
                        comp[m.group(1)]['authorities'].add(last_authority)
                continue
    return comp


def parse_boot_receivers(path):
    """Paquetes con receptor de BOOT_COMPLETED resoluble (cmd package query-receivers)."""
    pkgs = set()
    if not os.path.exists(path):
        return pkgs
    with open(path, errors='replace') as f:
        for line in f:
            m = re.match(r'^\s+([A-Za-z0-9_.]+)/[A-Za-z0-9_.$]+', line)
            if m:
                pkgs.add(m.group(1))
    return pkgs


def parse_launcher(path):
    """Paquetes con actividad LAUNCHER (app visible en el cajon)."""
    pkgs = set()
    if not os.path.exists(path):
        return pkgs
    with open(path, errors='replace') as f:
        for line in f:
            m = re.match(r'^\s*([A-Za-z0-9_.]+)/[A-Za-z0-9_.$]+', line.strip())
            if m:
                pkgs.add(m.group(1))
    return pkgs


def parse_uid_map(path):
    uid = {}
    with open(path, errors='replace') as f:
        for line in f:
            m = re.match(r'^package:(\S+)\s+uid:(\d+)', line.strip())
            if m:
                uid[m.group(1)] = int(m.group(2))
    return uid


def parse_power(path):
    """mAh por UID + desglose bg/fgs/cached."""
    out = {}
    if not os.path.exists(path):
        return out
    rx = re.compile(r'^\s+UID (\S+): ([0-9.]+)(.*)$')
    with open(path, errors='replace') as f:
        for line in f:
            m = rx.match(line)
            if m:
                rest = m.group(3)
                bg = re.search(r' bg: ([0-9.]+)', rest)
                fgs = re.search(r' fgs: ([0-9.]+)', rest)
                out[m.group(1)] = {'mah': float(m.group(2)),
                                   'bg': float(bg.group(1)) if bg else 0.0,
                                   'fgs': float(fgs.group(1)) if fgs else 0.0}
    return out


def count_per_pkg(path, pattern, group=1):
    c = Counter()
    if not os.path.exists(path):
        return c
    rx = re.compile(pattern)
    with open(path, errors='replace') as f:
        for line in f:
            m = rx.search(line)
            if m:
                                c[m.group(group)] += 1
    return c


# ---------------------------------------------------------------- base curada
# Funcion documentada (AOSP/MIUI/Qualcomm/Google). Solo etiqueta de funcion;
# la categoria final la decide la evidencia estructural y de ejecucion.
FUNC = {
 'android': 'Framework del sistema (paquete "android")',
 'com.android.systemui': 'Interfaz de sistema: barra de estado, notificaciones, lockscreen',
 'com.android.settings': 'Ajustes del sistema',
 'com.android.shell': 'Shell del sistema (ADB/Shizuku)',
 'com.android.phone': 'Telefonia: llamadas, SIM, IMS',
 'com.android.server.telecom': 'Servicio de llamadas (Telecom)',
 'com.android.providers.settings': 'Proveedor de ajustes del sistema',
 'com.android.providers.telephony': 'Proveedor de SMS/telefonia',
 'com.android.providers.contacts': 'Proveedor de contactos',
 'com.android.providers.media': 'Proveedor de medios (MediaStore)',
 'com.google.android.providers.media.module': 'MediaProvider (modulo Mainline/Google)',
 'com.android.permissioncontroller': 'Controlador de permisos',
 'com.google.android.permissioncontroller': 'Controlador de permisos (Google)',
 'com.mi.android.globallauncher': 'Lanzador POCO/MIUI',
 'com.android.bluetooth': 'Stack Bluetooth',
 'com.android.nfc': 'NFC',
 'com.android.se': 'Secure Element (NFC/eSIM)',
 'com.google.android.gsf': 'Servicios de Google Framework (base de GMS/Play)',
 'com.google.android.gms': 'Google Play services (GMS)',
 'com.android.vending': 'Google Play Store',
 'com.google.android.packageinstaller': 'Instalador de paquetes del sistema',
 'com.miui.global.packageinstaller': 'Instalador de paquetes MIUI',
 'com.android.keychain': 'Almacen de claves/certificados de usuario',
 'com.android.certinstaller': 'Instalador de certificados',
 'com.android.credentialmanager': 'Credential Manager (passkeys)',
 'com.android.externalstorage': 'Almacenamiento externo/emulado',
 'com.android.documentsui': 'Selector de documentos (SAF)',
 'com.android.mtp': 'Transferencia MTP (USB)',
 'com.android.cellbroadcastreceiver': 'Alertas de emergencia celular',
 'com.android.emergency': 'Informacion de emergencia',
 'com.android.networkstack.tethering': 'Modulo de red/tethering',
 'com.android.providers.downloads': 'Descargas del sistema',
 'com.android.providers.blockednumber': 'Lista de numeros bloqueados',
 'com.android.providers.calendar': 'Proveedor de calendario',
 'com.android.providers.userdictionary': 'Diccionario de usuario',
 'com.android.providers.contactkeys': 'Claves de contacto cifradas',
 'com.android.statementservice': 'Verificacion de App Links',
 'com.android.mms.service': 'Servicio MMS',
 'com.android.dynsystem': 'Particiones dinamicas (DSU)',
 'com.android.managedprovisioning': 'Provision empresarial (work profile)',
 'com.android.provision': 'Aprovisionamiento inicial',
 'com.android.wallpaperbackup': 'Respaldo de fondos de pantalla',
 'com.android.localtransport': 'Transporte de backup local',
 'com.android.backupconfirm': 'Confirmacion de restauracion',
 'com.android.traceur': 'Herramienta de trazado del sistema (desarrollo)',
 'com.android.egg': 'Easter egg de Android',
 'com.android.updater': 'Actualizador del sistema (OTA)',
 'com.miui.powerkeeper': 'Gestor de energia/rendimiento MIUI',
 'com.miui.securitycenter': 'Centro de seguridad MIUI',
 'com.miui.cleaner': 'Limpiador MIUI',
 'com.xiaomi.mipicks': 'GetApps (tienda Xiaomi)',
 'com.xiaomi.discover': 'Recomendaciones/actualizaciones de apps Xiaomi',
 'com.xiaomi.trustservice': 'Servicio de confianza Xiaomi (pagos)',
 'com.tencent.soter.soterserver': 'SOTER: autenticacion de pagos (Tencent)',
      'com.rongcard.eid': 'eID (identidad digital)',
}

FUNC.update({
 # telemetria / diagnostico
 'com.miui.analytics': 'Telemetria/analitica MIUI',
 'com.miui.msa.global': 'MIUI System Ads (anuncios del sistema)',
 'com.miui.misightservice': 'Analitica de uso MIUI (MIsight)',
 'com.xiaomi.mtb': 'Herramienta de test/benchmark Xiaomi',
 'com.xiaomi.ugd': 'Servicio de crecimiento de usuario/anuncios Xiaomi (UGD)',
 'com.google.mainline.telemetry': 'Telemetria de modulos Mainline',
 'com.google.android.as': 'Android System Intelligence (IA en dispositivo)',
 'com.google.android.as.oss': 'Private Compute Services (IA privada)',
 'com.bsp.logmanager': 'Gestion de logs de diagnostico (BSP)',
 'com.wdstechnology.android.kryten': 'Agente de diagnostico del dispositivo',
 'com.qualcomm.qti.devicestatisticsservice': 'Estadisticas/diagnostico Qualcomm',
 'com.miui.bugreport': 'Reporte de errores MIUI',
 # servicios OEM prescindibles
 'com.miui.daemon': 'Daemon de rendimiento/memoria MIUI',
 'com.miui.touchassistant': 'Asistente de toque flotante MIUI',
 'com.xiaomi.joyose': 'Optimizacion de rendimiento/juegos (Joyose)',
 'com.miui.audiomonitor': 'Monitor de audio MIUI',
 'com.miui.yellowpage': 'Identificador de llamadas/paginas MIUI',
 'com.miui.qr': 'Lector de QR del sistema MIUI',
 'com.miui.phrase': 'Frases rapidas MIUI',
 'com.miui.screenshot': 'Capturas de pantalla MIUI',
 'com.xiaomi.barrage': 'Notificaciones danmaku para video',
 'com.dti.aone': 'Digital Turbine: entrega de apps/anuncios (monetizacion OEM)',
 'com.longcheertel.cit': 'Test de fabrica (CIT) del ODM',
 'com.qualcomm.qti.ridemodeaudio': 'Perfil de audio modo moto (Qualcomm)',
 'com.qualcomm.atfwd': 'Reenvio de comandos AT (diagnostico)',
 'com.qualcomm.atfwd2': 'Reenvio de comandos AT v2 (diagnostico)',
 # Xiaomi/POCO opcional
 'com.miui.gallery': 'Galeria MIUI', 'com.miui.videoplayer': 'Reproductor de video MIUI',
 'com.miui.player': 'Reproductor de musica MIUI', 'com.miui.notes': 'Notas MIUI',
 'com.miui.weather2': 'Clima MIUI', 'com.android.thememanager': 'Temas MIUI',
 'com.miui.miwallpaper': 'Fondos de pantalla MIUI',
 'com.miui.screenrecorder': 'Grabador de pantalla MIUI',
 'com.xiaomi.scanner': 'Escaner de documentos/codigos',
 'com.miui.compass': 'Brujula MIUI', 'com.miui.calculator': 'Calculadora MIUI',
 'com.android.soundrecorder': 'Grabadora de voz MIUI',
 'com.miui.mediaeditor': 'Editor de medios MIUI', 'com.miui.mediaviewer': 'Visor de medios MIUI',
 'com.xiaomi.midrop': 'Transferencia entre dispositivos (Mi Drop)',
 'com.xiaomi.smarthome': 'Mi Home (casa inteligente)',
 'com.xiaomi.mi_connect_service': 'Mi Connect: continuidad con PC/tablet',
 'com.miui.mishare.connectivity': 'Mi Share: compartir archivos',
 'com.miui.huanji': 'Mi Mover (migracion de datos)', 'com.miui.backup': 'Backup local MIUI',
 'com.miui.cloudservice': 'Mi Cloud', 'com.miui.cloudbackup': 'Respaldo en Mi Cloud',
 'com.miui.micloudsync': 'Sincronizacion Mi Cloud',
 'com.xiaomi.finddevice': 'Buscar mi dispositivo (Xiaomi)', 'com.xiaomi.payment': 'Pagos Xiaomi',
 'com.miui.miservice': 'Mi Services / soporte', 'com.miui.systemui.plugin': 'Plugins de SystemUI MIUI',
 'com.xiaomi.aicr': 'Mi AI Call Recognition', 'com.xiaomi.aiasst.vision': 'Vision de asistente IA Xiaomi',
 'com.miui.thirdappassistant': 'Asistente de apps de terceros MIUI',
 'com.miui.securityadd': 'Complementos del centro de seguridad MIUI',
 'com.miui.guardprovider': 'Proveedor antivirus MIUI (AVL)',
 'com.miui.rom': 'Recursos del framework MIUI', 'com.miui.system': 'Servicios base MIUI',
 'com.miui.core': 'Nucleo MIUI (autoinstalacion/config)', 'com.miui.notification': 'Notificaciones MIUI',
 'com.miui.wallpaper': 'Motor de fondos de pantalla MIUI',
 # Google opcional
 'com.google.android.youtube': 'YouTube', 'com.google.android.apps.youtube.music': 'YouTube Music',
 'com.google.android.videos': 'Google TV / Play Peliculas', 'com.google.android.apps.photos': 'Google Fotos',
 'com.google.android.apps.docs': 'Google Drive', 'com.google.android.gm': 'Gmail',
 'com.google.android.apps.maps': 'Google Maps', 'com.google.android.apps.subscriptions.red': 'Google One',
 'com.google.android.apps.tachyon': 'Google Meet', 'com.google.android.apps.bard': 'Gemini',
 'com.android.chrome': 'Chrome', 'com.google.android.inputmethod.latin': 'Teclado Gboard',
 'com.google.android.apps.wellbeing': 'Bienestar digital', 'com.google.android.projection.gearhead': 'Android Auto',
 'com.google.ambient.streaming': 'Google Cast/Ambient', 'com.google.android.apps.nbu.files': 'Archivos de Google',
 'com.google.android.apps.chromecast.app': 'Google Home', 'com.google.android.apps.walletnfcrel': 'Google Wallet',
 'com.google.android.apps.adm': 'Encontrar mi dispositivo (Google)',
 'com.google.android.apps.safetyhub': 'Seguridad personal (Google)',
 'com.google.android.marvin.talkback': 'TalkBack (accesibilidad)',
 'com.google.android.apps.kids.familylink': 'Family Link (control parental)',
 'com.google.android.apps.safetycore': 'Safety Core (clasificacion en dispositivo)',
 'com.google.android.apps.restore': 'Restauracion de datos de Google',
 'com.google.android.partnersetup': 'Configuracion de partners de Google',
 'com.google.android.tts': 'Sintesis de voz de Google',
 'com.google.android.googlequicksearchbox': 'Busqueda/Asistente de Google',
 'com.google.android.configupdater': 'Actualizador de configuracion de seguridad',
 'com.google.android.dialer': 'Telefono de Google', 'com.google.android.contacts': 'Contactos de Google',
 'com.google.android.calendar': 'Calendario de Google',
 'com.google.android.apps.messaging': 'Mensajes de Google (SMS/RCS)',
})



# --- conjuntos curados (por funcion) -------------------------------------
CRITICAL_CORE = {
 'android', 'com.android.systemui', 'com.android.settings', 'com.android.shell',
 'com.android.phone', 'com.android.server.telecom', 'com.android.providers.settings',
 'com.android.providers.telephony', 'com.android.providers.contacts',
 'com.android.providers.media', 'com.google.android.providers.media.module',
 'com.android.permissioncontroller', 'com.google.android.permissioncontroller',
 'com.mi.android.globallauncher', 'com.android.bluetooth', 'com.android.nfc',
 'com.android.se', 'com.google.android.gsf', 'com.google.android.gms',
 'com.android.vending', 'com.google.android.packageinstaller', 'com.miui.global.packageinstaller',
 'com.android.keychain', 'com.android.certinstaller', 'com.android.credentialmanager',
 'com.android.externalstorage', 'com.android.documentsui', 'com.android.mtp',
 'com.android.cellbroadcastreceiver', 'com.android.emergency', 'com.android.dynsystem',
 'com.android.managedprovisioning', 'com.android.provision', 'com.android.localtransport',
 'com.android.backupconfirm', 'com.android.statementservice', 'com.android.mms.service',
 'com.android.providers.downloads', 'com.android.providers.calendar',
 'com.miui.powerkeeper', 'com.android.updater', 'com.miui.securitycenter',
 'com.android.wallpaperbackup',
}
SYS_NECESSARY = {
 'com.android.providers.blockednumber', 'com.android.providers.userdictionary',
 'com.android.providers.contactkeys', 'com.android.providers.partnerbookmarks',
 'com.google.android.configupdater', 'com.google.android.tts', 'com.google.android.partnersetup',
 'com.google.android.apps.restore', 'com.android.wifi.resources.xiaomi',
 'com.android.ons', 'com.android.imsserviceentitlement', 'com.android.carrierconfig',
 'com.google.android.apps.messaging', 'com.google.android.dialer', 'com.google.android.contacts',
 'com.google.android.calendar', 'com.google.android.inputmethod.latin',
 'com.miui.core', 'com.miui.system', 'com.miui.rom', 'com.miui.notification',
 'com.miui.wallpaper',
}
TELEMETRY = {
 'com.miui.analytics', 'com.miui.msa.global', 'com.miui.misightservice', 'com.xiaomi.mtb',
 'com.xiaomi.ugd', 'com.google.mainline.telemetry', 'com.google.android.as',
 'com.google.android.as.oss', 'com.bsp.logmanager', 'com.wdstechnology.android.kryten',
 'com.qualcomm.qti.devicestatisticsservice', 'com.miui.bugreport',
}
MIUI_OPT = {
 'com.miui.gallery', 'com.miui.videoplayer', 'com.miui.player', 'com.miui.notes',
 'com.miui.weather2', 'com.android.thememanager', 'com.miui.miwallpaper',
 'com.miui.screenrecorder', 'com.xiaomi.scanner', 'com.miui.compass', 'com.miui.calculator',
 'com.android.soundrecorder', 'com.miui.mediaeditor', 'com.miui.mediaviewer',
 'com.xiaomi.midrop', 'com.xiaomi.smarthome', 'com.xiaomi.mi_connect_service',
 'com.miui.mishare.connectivity', 'com.miui.huanji', 'com.miui.backup',
 'com.miui.cloudbackup', 'com.miui.micloudsync', 'com.xiaomi.finddevice',
 'com.xiaomi.payment', 'com.miui.miservice', 'com.miui.systemui.plugin', 'com.xiaomi.aicr',
 'com.xiaomi.aiasst.vision', 'com.miui.thirdappassistant', 'com.miui.securityadd',
 'com.miui.guardprovider', 'com.miui.cleaner', 'com.xiaomi.mipicks', 'com.xiaomi.discover',
 'com.xiaomi.trustservice',
}
GOOG_OPT = {
 'com.google.android.youtube', 'com.google.android.apps.youtube.music', 'com.google.android.videos',
 'com.google.android.apps.photos', 'com.google.android.apps.docs', 'com.google.android.gm',
 'com.google.android.apps.maps', 'com.google.android.apps.subscriptions.red',
 'com.google.android.apps.tachyon', 'com.google.android.apps.bard', 'com.android.chrome',
 'com.google.android.apps.wellbeing', 'com.google.android.projection.gearhead',
 'com.google.ambient.streaming', 'com.google.android.apps.nbu.files',
 'com.google.android.apps.chromecast.app', 'com.google.android.apps.walletnfcrel',
 'com.google.android.apps.adm', 'com.google.android.apps.safetyhub',
 'com.google.android.marvin.talkback', 'com.google.android.apps.kids.familylink',
 'com.google.android.apps.safetycore', 'com.google.android.googlequicksearchbox',
}
OEM_DISP = {
 'com.miui.daemon', 'com.miui.touchassistant', 'com.xiaomi.joyose', 'com.miui.audiomonitor',
 'com.miui.yellowpage', 'com.miui.qr', 'com.miui.phrase', 'com.miui.screenshot',
 'com.xiaomi.barrage', 'com.dti.aone', 'com.longcheertel.cit', 'com.qualcomm.atfwd',
 'com.qualcomm.atfwd2', 'com.qualcomm.qti.ridemodeaudio', 'com.android.traceur',
 'com.android.egg', 'com.novatek.novavis',
}
# Seguridad/pago: aunque estén inerciales no se promueve a cat 8 (bajo riesgo).
# Su borrado afecta funcionalidad sensible (pagos NFC, autenticacion, identidad).
NO_AUTOCAT8 = {
 'com.xiaomi.payment', 'com.xiaomi.trustservice', 'com.tencent.soter.soterserver',
 'com.rongcard.eid', 'com.miui.daemon', 'com.miui.powerkeeper',
 'com.xiaomi.finddevice',
}




def load_signals():
    boot_rx = parse_boot_receivers(H + 'boot_receivers_raw.txt')
    launcher = parse_launcher(H + 'launcher_acts.txt')
    uids = parse_uid_map(H + 'pkgs_uids.txt')
    power = parse_power(H + 'power_use.txt')
    running = set()
    with open(H + 'ps_all.txt', errors='replace') as f:
        for line in f:
            parts = line.split()
            if len(parts) >= 3:
                running.add(parts[2].split(':')[0])
    svc_run = count_per_pkg(H + 'dumpsys_services.txt',
                            r'ServiceRecord\{\w+ u\d+ ([A-Za-z0-9_.]+)/')
    jobs = count_per_pkg(H + 'dumpsys_jobs.txt', r'JOB #\d+/\d+: \w+ ([A-Za-z0-9_.]+)/')
    alarms = count_per_pkg(H + 'dumpsys_alarm.txt',
                           r'Alarm\{\w+ type \d+.*?([A-Za-z0-9_.]+)\}\s*$')
    doze = set()
    with open(H + 'doze_whitelist.txt', errors='replace') as f:
        for line in f:
            p = line.strip().split(',')
            if len(p) >= 2:
                doze.add(p[1])
    admins = set()
    with open(H + 'dumpsys_devpolicy.txt', errors='replace') as f:
        for line in f:
            m = re.search(r'mPackageName= ([A-Za-z0-9_.]+)', line)
            if m:
                admins.add(m.group(1))
    with open(H + 'defaults.txt', errors='replace') as f:
        d = [l.strip() for l in f]
    ime = d[0].split('/')[0] if d else ''
    notif = ({x.split('/')[0] for x in d[2].split(':')}
             if len(d) > 2 and d[2] != 'null' else set())
    assistant = d[4].split('/')[0] if len(d) > 4 else ''
    return dict(boot_rx=boot_rx, launcher=launcher, uids=uids, power=power, running=running,
                svc_run=svc_run, jobs=jobs, alarms=alarms, doze=doze, admins=admins,
                ime=ime, notif=notif, assistant=assistant)


def is_overlay(pkg, img_path, code_path):
    p = img_path or code_path or ''
    if '/overlay/' in p:
        return True
    if pkg.startswith('android.') and ('overlay' in pkg or 'rro' in pkg):
        return True
    if pkg.endswith(('overlay', '.rro', 'rro')) or '.overlay.' in pkg:
        return True


def main():
    rows_in = [r for r in csv.DictReader(open(H + 'pkg_origin.tsv'), delimiter='\t')
               if r['origin'].startswith('PREINSTALADO') and r['in_pm_list'] == 'yes']
    blocks = parse_blocks(H + 'pkg_dumpsys_full.txt')
    comp = parse_resolvers(H + 'dumpsys_package_FULL.txt')
    S = load_signals()
    referenced_by_queries = Counter()
    for pkg, b in blocks.items():
        for ref in re.findall(r'[A-Za-z0-9_.]+', b.get('queriesPackages', '')):
            referenced_by_queries[ref] += 1

    out = []
    for r in rows_in:
        pkg, b, c = r['pkg'], blocks.get(pkg, {}), comp.get(pkg, {})
        uid = S['uids'].get(pkg, -1)
        pf = (b.get('pkgFlags', '') + ' ' + b.get('privateFlags', '')).split()
        persistent, privileged = 'PERSISTENT' in pf, 'PRIVILEGED' in pf
        apex = b.get('apexModuleName') not in (None, 'null', '')
        perms = b.get('perms', set())
        uidstr = 'u0a%d' % (uid - 10000) if uid >= 10000 else str(uid)
        pw = S['power'].get(uidstr, {})
        mah, pbg, pfgs = pw.get('mah', 0.0), pw.get('bg', 0.0), pw.get('fgs', 0.0)
        run = pkg in S['running']
        uprov = c.get('providers', 0)
        brx = pkg in S['boot_rx']
        svc, job, alm = S['svc_run'].get(pkg, 0), S['jobs'].get(pkg, 0), S['alarms'].get(pkg, 0)
        # crítico/sistema: nunca candidatos a borrado. ATENCION: uid 1000 o
        # sharedUser=android.uid.system NO implica que la app sea el framework: muchas apps
        # MIUI opcionales se instalan en /system/priv-app con sharedUserId system. Solo se
        # considera critico el paquete 'android', modulos APEX, flag PERSISTENT, o estar en
        # CRITICAL_CORE (los privilegios PRIVILEGED por si solo no lo son).
        is_crit = (pkg == 'android' or persistent or apex or pkg in CRITICAL_CORE)
        is_sys = (is_overlay(pkg, r['img_codePath'], b.get('codePath', ''))
                  or (uprov > 0 and pkg.startswith(('com.android','com.qualcomm','com.qti',
                      'vendor.','org.codeaurora','com.google.android.providers')))
                  or pkg in SYS_NECESSARY)
        # bajo riesgo = sin dependencia externa (referenced_by_queries==0) y no activo como
        # servicio/vendor/HAL. Los proveedores PROPIOS de una app opcional no hacen
        # insegura la eliminacion por --user 0; importa referencias/queries, doze-whitelist,
        # admin/IME/listener, flag PERSISTENT/PRIVILEGED/APEX o proceso activo.
        inert = (not brx and not run and svc == 0 and job == 0 and alm == 0
                 and uid != 1000 and not persistent and not apex and not privileged
                 and referenced_by_queries.get(pkg, 0) == 0 and pkg not in S['doze']
                 and not is_crit and not is_sys
                 and pkg not in S['admins'] and pkg != S['ime']
                 and pkg not in S['notif'] and pkg != S['assistant'])
        if is_crit:
            cat = 1
        elif is_sys:
            cat = 2
        elif pkg in TELEMETRY:
            cat = 8 if inert and pkg not in NO_AUTOCAT8 else 5
        elif pkg in MIUI_OPT:
            cat = 8 if inert and pkg not in NO_AUTOCAT8 else 3
        elif pkg in GOOG_OPT:
            cat = 8 if inert and pkg not in NO_AUTOCAT8 else 4
        elif pkg in OEM_DISP:
            cat = 8 if inert and pkg not in NO_AUTOCAT8 else 6
        elif pkg in S['launcher']:
            cat = 7
        elif inert and pkg in FUNC:
            cat = 8
        else:
            cat = 9



        cand = {1: 'NO - critico', 2: 'NO - necesario del sistema',
                3: 'CONDICIONAL - decidir por uso', 4: 'CONDICIONAL - app Google',
                5: 'CONDICIONAL - telemetria', 6: 'CONDICIONAL - servicio OEM',
                7: 'NO - app visible preinstalada',
                8: 'SI - bajo riesgo (inerte, reversible)', 9: 'NO - sin evidencia suficiente'}[cat]
        if pkg in S['admins']:
            cand += ' / admin de dispositivo'
        if pkg == S['ime']:
            cand += ' / IME por defecto'
        if pkg in S['notif']:
            cand += ' / listener de notificaciones'
        if pkg == S['assistant']:
            cand += ' / asistente por defecto'
        if mah >= 20 or pfgs >= 10 or alm >= 5:
            lvl = 'alto'
        elif mah >= 5 or pfgs >= 2 or alm >= 1 or svc >= 1 or job >= 1:
            lvl = 'medio'
        elif mah > 0 or run or brx or pkg in S['doze']:
            lvl = 'bajo'
        else:
            lvl = 'nulo'
        clave = ','.join(sorted(p for p in perms if p.split('.')[-1] in (
            'RECEIVE_BOOT_COMPLETED', 'WAKE_LOCK', 'FOREGROUND_SERVICE', 'SCHEDULE_EXACT_ALARM',
            'SYSTEM_ALERT_WINDOW', 'INTERACT_ACROSS_USERS', 'REQUEST_IGNORE_BATTERY_OPTIMIZATIONS')))
        out.append({
            'pkg': pkg, 'categoria': cat, 'candidato': cand, 'procedencia': r['origin'],
            'funcion': FUNC.get(pkg, 'no documentada'), 'partition': r['partition'],
            'img_copy': r['img_copy'], 'uid': uid, 'sharedUser': b.get('sharedUser', ''),
            'privileged': privileged, 'persistent': persistent, 'apex': apex,
            'activities': c.get('activities', 0), 'receivers': c.get('receivers', 0),
            'services': c.get('services', 0), 'providers': uprov,
            'authorities': len(c.get('authorities', ())), 'launcher': pkg in S['launcher'],
            'boot_receiver': brx, 'referenced_by_queries': referenced_by_queries.get(pkg, 0),
            'running': run, 'services_running': svc, 'jobs': job, 'alarms': alm,
            'doze': pkg in S['doze'], 'power_mah': round(mah, 3), 'power_fgs': round(pfgs, 3),
            'power_bg': round(pbg, 3), 'impacto': lvl, 'inert': inert,
            'perms_clave': clave, 'version': r['version'],
        })
    out.sort(key=lambda x: (x['categoria'], -x['power_mah'], x['pkg']))
    with open(H + 'matriz_preinstalados.tsv', 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(out[0]), delimiter='\t')
        w.writeheader()
        w.writerows(out)
    print('filas:', len(out))
    for k, v in sorted(Counter(x['categoria'] for x in out).items()):
        print(f'  categoria {k}: {v}')
    print('impacto alto:', sum(1 for x in out if x['impacto'] == 'alto'),
          '| medio:', sum(1 for x in out if x['impacto'] == 'medio'),
          '| bajo:', sum(1 for x in out if x['impacto'] == 'bajo'))
    return out


if __name__ == '__main__':
    main()


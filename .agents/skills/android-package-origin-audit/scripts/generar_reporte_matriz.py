#!/data/data/com.termux/files/usr/bin/python3
"""Genera reporte_matriz_preinstalados.md combinando origen + matriz.

Lee pkg_origin.tsv (procedencia) y matriz_preinstalados.tsv (categoria/riesgo/
impacto) y emite un unico informe con la separacion:

    USER | RESTORED/MIGRATED | PREINSTALLED | UNKNOWN

y, dentro de PREINSTALLED, el detalle de categorias/riesgos/impactos y la
shortlist reversible. NO desinstala nada.
"""
import csv
from collections import Counter, defaultdict

HOME = '/data/data/com.termux/files/home/'
OUT = HOME + 'reporte_matriz_preinstalados.md'

CAT = {
 1: ('Critica / framework', 'NO - critico'),
 2: ('Necesaria del sistema', 'NO - necesario del sistema'),
 3: ('App opcional MIUI', 'CONDICIONAL - decidir por uso'),
 4: ('App opcional Google', 'CONDICIONAL - app Google'),
 5: ('Telemetria / datos', 'CONDICIONAL - telemetria'),
 6: ('Servicio OEM prescindible', 'CONDICIONAL - servicio OEM'),
 7: ('App visible preinstalada', 'NO - app visible preinstalada'),
 8: ('Candidato bajo riesgo (inerte)', 'SI - bajo riesgo'),
 9: ('No documentada / desconocida', 'NO - sin evidencia suficiente'),
}


def load_rows():
    oro = list(csv.DictReader(open(HOME + 'pkg_origin.tsv'), delimiter='\t'))
    try:
        m = list(csv.DictReader(open(HOME + 'matriz_preinstalados.tsv'), delimiter='\t'))
    except FileNotFoundError:
        m = []
    mmap = {r['pkg']: r for r in m}
    return oro, mmap


def bucket(origin):
    if origin.startswith('PREINSTALADO'):
        return 'PREINSTALLED'
    if origin.startswith('USUARIO'):
        return 'RESTORED' if 'RESTAURADO' in origin else 'USER'
    return 'UNKNOWN'


oro, mmap = load_rows()
bkt = defaultdict(list)
for r in oro:
    bkt[bucket(r['origin'])].append(r)

L = []
def l(*a): L.append(' '.join(str(x) for x in a))


l('# Auditoria de paquetes Android — origen + matriz')
l('')
l('> **Disclaimer**: este informe es **solo observacion/informe**. No ejecuta')
l('> `pm uninstall`/`rm` ni modifica nada del sistema. La eliminacion, si se decide,')
l('> se realiza FUERA de la auditoria con `pm uninstall --user 0` (reversible con')
l('> `pm install-existing --user 0`) tras revision humana. La procedencia se clasifica')
l('> por **evidencia**, nunca por nombre, fabricante ni apariencia.')
l('')
l('## 1. Resumen global')
l('')
l('| macro-grupo | paquetes | instalados (`pm list`) |')
l('|---|---:|---:|')
tot = 0
for name in ('USER', 'RESTORED', 'PREINSTALLED', 'UNKNOWN'):
    items = bkt[name]
    tot += len(items)
    inst = sum(1 for r in items if r['in_pm_list'] == 'yes')
    l(f'| {name} | {len(items)} | {inst} |')
l(f'| **total** | **{tot}** | **{sum(1 for r in oro if r["in_pm_list"]=="yes")}** |')
l('')
l('Reglas de procedencia (ver skill `android-package-origin-audit`):')
l('- USER: particion `data`, 0 FLAG_SYSTEM, sin copia en imagen,')
l('  `installReason=USER` (4) o `packageSource=STORE/DOWNLOADED_FILE` (1/3).')
l('- RESTORED: particion `data`, sin FLAG_SYSTEM, pero `installReason=DEVICE_RESTORE/SETUP` (2/3).')
l('- PREINSTALLED: copia en la imagen (`Hidden system packages`) o flags SYSTEM/UPDATED,')
l('  o `isMiuiPreinstall=true`, o `firstInstallTime` de este boot (OTA).')
l('- UNKNOWN: evidencia insuficiente; quedan excluidos de cualquier candidatura.')
l('')

def tabla_macro(name, cols=('installer', 'installReason', 'packageSource', 'firstInstall')):
    items = bkt[name]
    l(f'### {name} ({len(items)})')
    l('| paquete | ' + ' | '.join(cols) + ' |')
    l('|---|' + '---|' * len(cols))
    for r in sorted(items, key=lambda x: x['pkg']):
        l(f"| `{r['pkg']}` | " + ' | '.join(r.get(c, '') or '-' for c in cols) + ' |')
    l('')

l('## 2. USER')
l('')
l('Evidencia tipica: particion `data`, sin FLAG_SYSTEM, sin copia en la imagen,')
l('`installReason=USER` o `packageSource=STORE/DOWNLOADED_FILE`.')
l('')
l('> Regla: `pm list packages -3` (FLAG_SYSTEM=0) **no implica** USER; tambien puede')
l('> ser PREINSTALLED_actualizado (en `/data` con copia en `/system`) o RESTORED.')
l('')
tabla_macro('USER')
l('## 3. RESTORED / MIGRATED')
l('')
l('Apps con `installReason=DEVICE_RESTORE` (2) o `DEVICE_SETUP` (3) y/o marca de')
l('tiempo dentro de la ventana de restauracion del provisioning (Google backup).')
l('')
tabla_macro('RESTORED', cols=('installer', 'installReason', 'firstInstall'))
l('## 4. UNKNOWN')
l('')
l('Apps que no dejan evidencia concluyente de procedencia. Quedan **excluidos**')
l('de cualquier recomendacion de eliminacion.')
l('')
tabla_macro('UNKNOWN', cols=('installer', 'installReason', 'packageSource', 'partition', 'installed_user0'))
l('## 5. PREINSTALLED')
l('')
l('Aplicaciones con copia en la imagen, flags `SYSTEM`/`UPDATED_SYSTEM_APP`,')
l('`isMiuiPreinstall=true` o marca de tiempo de arranque/OTA. Aqui se anida la')
l('matriz de categoria/riesgo/impacto (definiciones en `matriz_preinstalados.py`):')
l('Cat 1 critica | 2 necesaria | 3 opcional MIUI | 4 opcional Google |')
l('5 telemetria | 6 servicio OEM | 7 app visible | 8 candidato bajo riesgo |')
l('9 desconocida. La columna `candidato` indica **riesgo de eliminacion**.')
l('')

# --- matriz dentro de PREINSTALLED ---
pre_rows = [mmap[r['pkg']] for r in bkt['PREINSTALLED'] if r['pkg'] in mmap and r['in_pm_list'] == 'yes']
by_cat = defaultdict(list)
for r in pre_rows: by_cat[r['categoria']].append(r)

ma = sum(float(r['power_mah']) for r in pre_rows)
hi = sum(1 for r in pre_rows if r['impacto'] == 'alto')
md = sum(1 for r in pre_rows if r['impacto'] == 'medio')
cr = sum(1 for r in pre_rows if r['candidato'].startswith('SI'))
l(f'- Paquetes preinstalados con matriz: **{len(pre_rows)}** | mAh total: **{ma:.2f}** |')
l(f'  impacto alto/medio: **{hi}/{md}** | candidatos bajo riesgo: **{cr}**.')
l('')
l('| cat | grupo | paquetes | mAh | alto/medio | bajo riesgo |')
l('|---|---|:---:|:---:|:---:|:---:|')
for k in sorted(by_cat, key=lambda x: int(x)):
    rrs = by_cat[k]
    m_ = sum(float(r['power_mah']) for r in rrs)
    hi2 = sum(1 for r in rrs if r['impacto'] == 'alto')
    md2 = sum(1 for r in rrs if r['impacto'] == 'medio')
    c2 = sum(1 for r in rrs if r['candidato'].startswith('SI'))
    l(f'| {k} | {CAT[int(k)][0]} | {len(rrs)} | {m_:.2f} | {hi2}/{md2} | {c2} |')
l('')

def detalle(r):
    e = []
    if r['privileged'] == 'True': e.append('PRIVILEGED')
    if r['persistent'] == 'True': e.append('PERSISTENT')
    if r['apex'] == 'True': e.append('APEX')
    if r['boot_receiver'] == 'True': e.append('boot_rx')
    if r['launcher'] == 'True': e.append('launcher')
    if r['doze'] == 'True': e.append('doze-wl')
    if r['running'] == 'True': e.append('running')
    if r['services_running'] not in ('0', ''): e.append(f'svc={r["services_running"]}')
    if r['jobs'] not in ('0', ''): e.append(f'jobs={r["jobs"]}')
    if r['alarms'] not in ('0', ''): e.append(f'alarms={r["alarms"]}')
    if r['referenced_by_queries'] not in ('0', ''): e.append(f'ref={r["referenced_by_queries"]}')
    if r['power_mah'] not in ('0', '0.0', ''): e.append(f'mah={r["power_mah"]}')
    s = f'`{r["pkg"]}`  # {r["funcion"][:55]}'
    if e: s += '  · ' + ', '.join(e)
    return s

shortlist = [r for r in pre_rows if r['categoria'] == '8']
l('### Shortlist de bajo riesgo (Cat 8) — eliminacion REVERSIBLE con `pm uninstall --user 0`')
l('')
l('```bash')
for r in shortlist:
    l(f'# {r["pkg"]:50s} {r["funcion"][:45]}')
l('# aplicar (NO borra el APK de la particion; solo oculta al usuario 0):')
for r in shortlist:
    l(f'pm uninstall --user 0 {r["pkg"]}')
l('# revertir:')
for r in shortlist:
    l(f'pm install-existing --user 0 {r["pkg"]}')
l('```')
l('')
l('> Pago/NFC, eID, autenticacion y demonios de rendimiento se excluyen de la')
l('> shortlist por disenar (`NO_AUTOCAT8`), incluso si estan inerciales.')
l('')

l('### Cat 9 (preinstalados no documentados) — revision obligada antes de tocar')
l('')
for r in sorted(by_cat.get('9', []), key=lambda x: x['pkg']):
    l(f'- `{r["pkg"]}` — {r["funcion"][:55]} (part {r["partition"]})')
l('')

l('### Apps visibles / defaults — NO tocar sin alternativa')
l('')
l('| paquete | candidato | notas |')
l('|---|---|---|')
for r in sorted(pre_rows, key=lambda x: x['pkg']):
    if r['launcher'] == 'True' or 'IME' in r['candidato'] or 'listener' in r['candidato'] \
            or 'asistente' in r['candidato'] or 'admin de dispositivo' in r['candidato']:
        l(f'| `{r["pkg"]}` | {r["candidato"]} | {r["funcion"][:50]} |')
l('')

l('### Telemetria (Cat 5) y servicios OEM (Cat 6) activos — preferiblemente DESHABILITAR')
l('')
l('| paquete | candidato | senales | mAh |')
l('|---|---|---|---|')
for r in sorted(by_cat.get('5', []) + by_cat.get('6', []), key=lambda x: -float(r['power_mah'])):
    sigs = []
    for k in ('boot_receiver', 'running', 'doze', 'services_running', 'jobs', 'alarms', 'referenced_by_queries'):
        v = r[k]
        if v not in ('False', '0', ''):
            sigs.append(f'{k}={v}')
    l(f'| `{r["pkg"]}` | {r["candidato"]} | {", ".join(sigs) or "activo"} | {r["power_mah"]} |')
l('')

l('## 6. Regla de no-eliminacion automatica')
l('')
l('1. La auditoria **no elimina**. Produce `matriz_preinstalados.tsv` + este reporte.')
l('2. `pm uninstall --user 0` es la unica forma soportada; `rm -rf /system` invalida')
l('   OTA/SELinux y no es una auditoria. Para overlays RRO (Cat 2) usar `cmd overlay disable`.')
l('3. UNKNOWN y Cat 1/2 quedan fuera de la shortlist; Cat 9 implica revision manual.')
l('')
l('## 7. Checklist de reproducibilidad')
l('')
l('1. Recolectar evidencia fresca: `dumpsys package`, `dumpsys activity services/jobs`,')
l('   `dumpsys alarm`, `dumpsys power`, `dumpsys device_policy`, `ps -A`, `doze_whitelist`,')
l('   `defaults.txt` (ime/listener/assistant), listas `pm -s/-3/-u`, `boot_receivers`,')
l('   `launcher_acts`, `pkgs_uids.txt`, `boot_epoch.txt`, `props OTA`.')
l('2. `python3 parse_full.py` -> `pkg_origin.tsv`.')
l('3. `python3 matriz_preinstalados.py` -> `matriz_preinstalados.tsv` + resumen.')
l('4. `python3 generar_reporte_matriz.py` -> `reporte_matriz_preinstalados.md`.')
l('5. Verificar: total TSV == preinstalados; ningun candidato en UNKNOWN; regrabar tras OTA.')
l('')
l('## 8. Archivos')
l('')
l('- `pkg_origin.tsv`: procedencia + evidencia (parse_full.py).')
l('- `matriz_preinstalados.tsv`: categoria/candidato/funcion/impacto/diagnostico.')
l('- `reporte_matriz_preinstalados.md`: este informe.')
l('')

with open(OUT, 'w') as f:
    f.write('\n'.join(L) + '\n')
print(f'{OUT} escrito: {len(L)} lineas, {len(oro)} origen / {len(pre_rows)} preinstalados con matriz.')
print('shortlist cat8:', len(shortlist))

#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────
// kimi_vision.js — Detección de permisos con visión IA (Kimi K3)
// =============================================================
// Upgrade de auto_permiso.py: en lugar de OCR (Tesseract), envía
// el screenshot a Kimi K3 vía la API de Hugging Face (endpoint
// OpenAI-compatible) para que el modelo "vea" el diálogo y lo
// clasifique, incluso cuando el OCR falla (bajo contraste, emojis,
// textos redondeados).
//
// Requisitos:
//   export HF_TOKEN=hf_xxx     (token con scope de inferencia/lectura)
//   Aceptar la licencia del modelo gated:
//     https://huggingface.co/moonshotai/Kimi-K3
//
// Modos (misma interfaz que auto_permiso.py):
//   node kimi_vision.js --img screenshot.png
//   node kimi_vision.js --img screenshot.png --pkg com.app --grant
//   node kimi_vision.js --monitor --pkg com.app --grant
//   node kimi_vision.js --watch --pkg com.app
//   node kimi_vision.js --screenshot --pkg com.app --grant
//   node kimi_vision.js --img x.png --json    → salida JSON cruda
//
// Env vars opcionales:
//   KIMI_MODEL    (default: moonshotai/Kimi-K3)
//   KIMI_ENDPOINT (default: https://router.huggingface.co/v1/chat/completions)
//   KIMI_TIMEOUT_MS (default: 120000)
// ─────────────────────────────────────────────────────────────

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const log = require('./lib/logger');
const { sleep } = require('./lib/utils');

const HOME = process.env.HOME || '/data/data/com.termux/files/home';
const RISH = 'rish';
const RISH_ENV = 'RISH_APPLICATION_ID=com.termux MANAGER_APPLICATION_ID=moe.shizuku.privileged.api';
const SCREENSHOT_PATH = '/sdcard/kimi_vision_temp.png';
const SCREENSHOTS_DIR = '/sdcard/DCIM/Screenshots';

const HF_TOKEN = process.env.HF_TOKEN || '';
const KIMI_MODEL = process.env.KIMI_MODEL || 'moonshotai/Kimi-K3';
const KIMI_ENDPOINT = process.env.KIMI_ENDPOINT || 'https://router.huggingface.co/v1/chat/completions';
const KIMI_TIMEOUT_MS = Number(process.env.KIMI_TIMEOUT_MS || 120000);
const MAX_RETRIES = 3;

// ============================================================
// 🗺️  MAPA DE PERMISOS: categoría detectada → rish
// ============================================================
// El modelo devuelve un tipo normalizado; aquí se mapea a los
// permisos/appops exactos para concederlos vía rish.
// ============================================================

const PERMISSION_MAP = [
  {
    type: 'camera',
    label: '📷 Cámara',
    appops: ['CAMERA'],
    permissions: ['android.permission.CAMERA'],
  },
  {
    type: 'microphone',
    label: '🎤 Micrófono',
    appops: ['RECORD_AUDIO'],
    permissions: ['android.permission.RECORD_AUDIO'],
  },
  {
    type: 'location',
    label: '📍 Ubicación',
    appops: ['FINE_LOCATION', 'COARSE_LOCATION', 'GPS'],
    permissions: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.ACCESS_BACKGROUND_LOCATION',
    ],
  },
  {
    type: 'phone',
    label: '📞 Teléfono',
    appops: [],
    permissions: ['android.permission.READ_PHONE_STATE', 'android.permission.CALL_PHONE'],
  },
  {
    type: 'sms',
    label: '💬 SMS',
    appops: [],
    permissions: ['android.permission.READ_SMS', 'android.permission.RECEIVE_SMS', 'android.permission.SEND_SMS'],
  },
  {
    type: 'contacts',
    label: '📇 Contactos',
    appops: ['READ_CONTACTS', 'WRITE_CONTACTS'],
    permissions: ['android.permission.READ_CONTACTS', 'android.permission.WRITE_CONTACTS'],
  },
  {
    type: 'storage',
    label: '🗂️ Almacenamiento',
    appops: ['READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE', 'READ_MEDIA_IMAGES', 'READ_MEDIA_VIDEO', 'READ_MEDIA_AUDIO'],
    permissions: [
      'android.permission.READ_EXTERNAL_STORAGE',
      'android.permission.WRITE_EXTERNAL_STORAGE',
      'android.permission.MANAGE_EXTERNAL_STORAGE',
      'android.permission.READ_MEDIA_IMAGES',
      'android.permission.READ_MEDIA_VIDEO',
      'android.permission.READ_MEDIA_AUDIO',
    ],
  },
  {
    type: 'overlay',
    label: '🪟 Superposición',
    appops: ['SYSTEM_ALERT_WINDOW'],
    permissions: ['android.permission.SYSTEM_ALERT_WINDOW'],
  },
  {
    type: 'notifications',
    label: '🔔 Notificaciones',
    appops: ['POST_NOTIFICATION'],
    permissions: ['android.permission.POST_NOTIFICATIONS'],
  },
  {
    type: 'accessibility',
    label: '♿ Accesibilidad',
    appops: [],
    permissions: [],
    is_accessibility: true,
  },
  {
    type: 'write_settings',
    label: '⚙️ Ajustes del sistema',
    appops: [],
    permissions: ['android.permission.WRITE_SETTINGS'],
  },
  {
    type: 'install_packages',
    label: '📦 Instalar apps',
    appops: [],
    permissions: ['android.permission.REQUEST_INSTALL_PACKAGES'],
  },
  {
    type: 'other',
    label: '❓ Otro permiso',
    appops: [],
    permissions: [],
  },
];

const SYSTEM_PROMPT = [
  'Eres un analizador de screenshots de Android (Xiaomi/HyperOS).',
  'Dado un screenshot, determina si muestra un diálogo de solicitud de permiso',
  '(runtime permission, appops, superposición, notificaciones, accesibilidad, etc.).',
  '',
  'Responde ÚNICAMENTE con JSON válido, sin markdown, con este esquema exacto:',
  '{',
  '  "es_dialogo_permiso": true o false,',
  '  "tipo_permiso": "camera|microphone|location|phone|sms|contacts|storage|overlay|notifications|accessibility|write_settings|install_packages|other",',
  '  "app": "nombre de la app que solicita (o null)",',
  '  "titulo": "título del diálogo",',
  '  "descripcion": "texto completo visible del diálogo",',
  '  "botones": ["Permitir", "Denegar"],',
  '  "confianza": 0-100,',
  '  "resumen": "explicación breve en español de qué permiso pide"',
  '}',
  '',
  'Reglas:',
  '- tipo_permiso: elige la categoría EXACTA del permiso solicitado. "other" si no encaja.',
  '- Si NO es un diálogo de permiso: es_dialogo_permiso=false, tipo_permiso="other", confianza baja.',
  '- confianza: tu certeza de que es un diálogo de permiso Y de que la categoría es correcta.',
  '- botones: lista de los botones visibles del diálogo.',
].join('\n');

// ============================================================
// 🛠️  Utilidades
// ============================================================

function runCmd(cmd, timeout = 15) {
  try {
    const out = execSync(cmd, { encoding: 'utf8', timeout: timeout * 1000, stdio: ['pipe', 'pipe', 'pipe'] });
    return { stdout: (out || '').trim(), stderr: '', code: 0 };
  } catch (e) {
    return {
      stdout: (e.stdout || '').toString().trim(),
      stderr: (e.stderr || '').toString().trim(),
      code: e.status == null ? -1 : e.status,
    };
  }
}

function takeScreenshot() {
  log.info('📸 Tomando screenshot...');
  runCmd(`rm -f ${SCREENSHOT_PATH}`, 3);
  const cmds = [
    `${RISH_ENV} ${RISH} /system/bin/screencap -p ${SCREENSHOT_PATH}`,
    `${RISH_ENV} ${RISH} screencap -p ${SCREENSHOT_PATH}`,
  ];
  for (const cmd of cmds) {
    const { code } = runCmd(cmd, 10);
    if (code === 0 && fs.existsSync(SCREENSHOT_PATH) && fs.statSync(SCREENSHOT_PATH).size >= 1000) {
      log.info(`  ✅ Screenshot guardado (${fs.statSync(SCREENSHOT_PATH).size.toLocaleString()} bytes)`);
      return SCREENSHOT_PATH;
    }
  }
  log.error('❌ Error tomando screenshot (screencap no disponible en HyperOS sin root).');
  log.error('   💡 Usa --monitor (screenshot manual) o --img con un archivo existente.');
  return null;
}

function fileToDataUrl(imgPath) {
  const ext = path.extname(imgPath).toLowerCase();
  const mime = ext === '.jpg' || ext === '.jpeg' ? 'image/jpeg' : ext === '.webp' ? 'image/webp' : 'image/png';
  return `data:${mime};base64,${fs.readFileSync(imgPath).toString('base64')}`;
}

// ============================================================
// 🤖 API Kimi K3 (OpenAI-compatible)
// ============================================================

async function callKimi(imgPath) {
  if (!HF_TOKEN) {
    throw new Error('Falta HF_TOKEN. Ejecuta: export HF_TOKEN=hf_xxx');
  }

  const payload = {
    model: KIMI_MODEL,
    messages: [
      { role: 'system', content: SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'text', text: 'Analiza este screenshot y responde solo con el JSON.' },
          { type: 'image_url', image_url: { url: fileToDataUrl(imgPath) } },
        ],
      },
    ],
    max_tokens: 1024,
    temperature: 0.1,
  };

  let lastErr;
  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), KIMI_TIMEOUT_MS);
    try {
      const resp = await fetch(KIMI_ENDPOINT, {
        method: 'POST',
        headers: { Authorization: `Bearer ${HF_TOKEN}`, 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      clearTimeout(timer);

      if (!resp.ok) {
        const bodyText = await resp.text().catch(() => '');
        const err = new Error(`API ${KIMI_MODEL} respondió ${resp.status}: ${bodyText.slice(0, 300)}`);
        err.status = resp.status;
        throw err;
      }

      const data = await resp.json();
      const content = data && data.choices && data.choices[0] && data.choices[0].message && data.choices[0].message.content;
      if (!content) throw new Error('Respuesta vacía de la API');
      return extractJson(content);
    } catch (err) {
      clearTimeout(timer);
      lastErr = err;

      if (err.status === 401 || err.status === 403) {
        log.error('  💡 Verifica: (1) HF_TOKEN válido con scope de inferencia/lectura,');
        log.error('     (2) aceptaste la licencia del modelo en https://huggingface.co/moonshotai/Kimi-K3');
        throw err;
      }

      if (err.status === 404) {
        log.error('  💡 Endpoint/modelo no encontrado. Revisa KIMI_ENDPOINT');
        log.error('     (debe ser https://router.huggingface.co/v1, sin /hf) y KIMI_MODEL');
        throw err;
      }

      const retriable =
        err.name === 'AbortError' ||
        err.name === 'TypeError' ||
        err.status === 429 ||
        (err.status >= 500 && err.status <= 599);

      if (!retriable || attempt === MAX_RETRIES) throw err;

      const delay = 3000 * attempt;
      log.warn(`  🔄 API falló (intento ${attempt}/${MAX_RETRIES}): ${err.message.slice(0, 80)} — reintentando en ${delay / 1000}s...`);
      await sleep(delay);
    }
  }
  throw lastErr;
}

function extractJson(text) {
  const t = String(text).trim();
  try { return JSON.parse(t); } catch { /* sigue */ }

  const fenced = t.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim();
  try { return JSON.parse(fenced); } catch { /* sigue */ }

  const start = fenced.indexOf('{');
  const end = fenced.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try { return JSON.parse(fenced.slice(start, end + 1)); } catch { /* sigue */ }
  }
  throw new Error(`No se pudo extraer JSON de la respuesta del modelo: ${t.slice(0, 300)}`);
}

function detectPermission(result) {
  if (!result || result.es_dialogo_permiso !== true) return null;
  const type = typeof result.tipo_permiso === 'string' ? result.tipo_permiso : 'other';
  const entry = PERMISSION_MAP.find(p => p.type === type) || PERMISSION_MAP.find(p => p.type === 'other');
  return {
    type,
    label: entry.label,
    confidence: Number(result.confianza) || 0,
    permissions: entry.permissions,
    appops: entry.appops,
    is_accessibility: !!entry.is_accessibility,
    app: result.app || null,
    titulo: result.titulo || null,
    descripcion: result.descripcion || null,
    botones: Array.isArray(result.botones) ? result.botones : [],
    resumen: result.resumen || null,
  };
}

// ============================================================
// 🛡️  Concesión de permisos vía rish
// ============================================================

function grantPermission(pkg, info) {
  log.info(`\n  🛡️  Concediendo: ${info.label}`);
  const safePkg = `'${pkg}'`;

  for (const perm of info.permissions) {
    const { code, stderr } = runCmd(`${RISH_ENV} ${RISH} pm grant ${safePkg} ${perm}`, 10);
    if (code === 0) {
      log.info(`      ✅ pm grant ${perm.split('.').pop()}`);
    } else if (/not declared|SecurityException/i.test(stderr)) {
      log.info(`      ⚠️  ${perm.split('.').pop()} no declarado por la app`);
    } else {
      log.info(`      ❌ ${perm.split('.').pop()}: ${stderr.slice(0, 60)}`);
    }
  }

  for (const op of info.appops) {
    const { code, stderr } = runCmd(`${RISH_ENV} ${RISH} appops set ${safePkg} ${op} allow`, 10);
    if (code === 0) {
      log.info(`      ✅ appops ${op} = allow`);
    } else {
      log.info(`      ⚠️  appops ${op}: ${stderr.slice(0, 60)}`);
    }
  }

  if (info.is_accessibility) {
    log.info('      ℹ️  Accesibilidad requiere pasos manuales:');
    log.info('         1. Ajustes → Apps → ' + pkg + ' → ⋮ → Permitir configuración restringida');
    log.info('         2. Ajustes → Accesibilidad → activar servicio');
  }
}

// ============================================================
// 🔍 Análisis principal
// ============================================================

async function analyzeImage(imgPath, opts = {}) {
  const { pkg = '', grant = false, minConfidence = 50, json = false } = opts;

  if (!json) {
    log.info(`\n${'='.repeat(60)}`);
    log.info('🔍 ANALIZANDO SCREENSHOT (visión Kimi K3)');
    log.info('='.repeat(60));
    log.info(`  📷 Imagen: ${path.basename(imgPath)}`);
    if (pkg) log.info(`  📦 Package: ${pkg}`);
    const size = fs.statSync(imgPath).size;
    log.info(`  ⏳ Enviando a ${KIMI_MODEL} (${(size / 1024).toFixed(0)} KB)...`);
  }

  const start = Date.now();
  const result = await callKimi(imgPath);
  const elapsed = ((Date.now() - start) / 1000).toFixed(1);

  if (json) {
    const info = detectPermission(result);
    console.log(JSON.stringify({
      ...result,
      _model: KIMI_MODEL,
      _elapsed_s: Number(elapsed),
      _mapeado: info ? {
        label: info.label,
        permissions: info.permissions,
        appops: info.appops,
        is_accessibility: info.is_accessibility,
      } : null,
    }, null, 2));
    return { result, info };
  }

  log.info(`  ✅ Respuesta en ${elapsed}s`);

  const info = detectPermission(result);
  if (!info) {
    log.info('\n  ❌ No se detectó un diálogo de permiso.');
    if (result) {
      if (result.app) log.info(`  📦 App detectada: ${result.app}`);
      if (result.titulo) log.info(`  🏷️  ${result.titulo}`);
      if (result.resumen) log.info(`  💬 ${result.resumen}`);
      if (result.descripcion) log.info(`  📄 ${result.descripcion.slice(0, 200)}`);
    }
    return { result, info: null };
  }

  const bar = '█'.repeat(Math.round(info.confidence / 10)) + '░'.repeat(10 - Math.round(info.confidence / 10));
  log.info(`\n  🎯 Permiso detectado: ${info.label} [${bar}] ${info.confidence}%`);
  if (info.app) log.info(`     📦 App: ${info.app}`);
  if (info.titulo) log.info(`     🏷️  Título: ${info.titulo}`);
  if (info.resumen) log.info(`     💬 ${info.resumen}`);
  if (info.botones.length) log.info(`     🔘 Botones: ${info.botones.join(' | ')}`);

  if (grant && pkg) {
    if (info.confidence >= minConfidence) {
      grantPermission(pkg, info);
      log.info('  ✅ Permiso concedido');
    } else {
      log.info(`\n  ⚠️  Confianza (${info.confidence}%) < mínimo (${minConfidence}%) — no se concede.`);
    }
  } else if (grant && !pkg) {
    log.info('\n  ⚠️  Falta --pkg para conceder.');
  } else {
    log.info('\n  ℹ️  Usa --grant --pkg <paquete> para conceder automáticamente.');
  }

  return { result, info };
}

// ============================================================
// 👁️  Loops: watch (screencap) y monitor (galería)
// ============================================================

function getLatestScreenshot() {
  try {
    if (!fs.existsSync(SCREENSHOTS_DIR)) return null;
    return fs.readdirSync(SCREENSHOTS_DIR)
      .filter(f => /\.(png|jpg|jpeg)$/i.test(f))
      .map(f => path.join(SCREENSHOTS_DIR, f))
      .sort((a, b) => fs.statSync(b).mtimeMs - fs.statSync(a).mtimeMs)[0] || null;
  } catch {
    return null;
  }
}

async function waitForFileStable(filepath, checks = 3, delay = 1) {
  let prev = -1;
  for (let i = 0; i < checks; i++) {
    try {
      const size = fs.statSync(filepath).size;
      if (size === prev) return true;
      prev = size;
    } catch { /* el archivo aún no existe */ }
    await sleep(delay * 1000);
  }
  return false;
}

async function watchLoop(interval, opts) {
  log.info(`\n${'='.repeat(60)}`);
  log.info('👁️  MODO WATCH — screencap cada ' + interval + 's');
  log.info('='.repeat(60));
  if (opts.pkg) log.info(`  📦 Package: ${opts.pkg}`);
  log.info('  ⚠️  screencap puede no funcionar en HyperOS sin root — usa --monitor si falla.');
  log.info('\n  Presiona Ctrl+C para salir');

  let cycle = 0;
  while (true) {
    cycle++;
    log.info(`\n[${new Date().toTimeString().slice(0, 8)}] Ciclo #${cycle}`);
    const img = takeScreenshot();
    if (!img) {
      log.info(`  💡  python3 auto_permiso.py --monitor --pkg ${opts.pkg || ''} (fallback OCR)`);
      return;
    }
    try {
      await analyzeImage(img, opts);
    } catch (e) {
      log.error(e.message);
    }
    await sleep(interval * 1000);
  }
}

async function monitorLoop(interval, opts) {
  log.info(`\n${'='.repeat(60)}`);
  log.info('👁️  MODO MONITOR — esperando screenshot nuevo');
  log.info('='.repeat(60));
  if (opts.pkg) log.info(`  📦 Package: ${opts.pkg}`);
  log.info(`  📂 Vigilando: ${SCREENSHOTS_DIR}/`);
  log.info(`  🛡️  Auto-grant: ${opts.grant ? 'SÍ' : 'NO (usa --grant)'}`);
  log.info('\n  📸 Toma un screenshot manual (Vol- + Power)');
  log.info('     cuando la app muestre el diálogo de permiso.');
  log.info('\n  Presiona Ctrl+C para salir');

  let last = getLatestScreenshot();
  let lastMtime = last ? fs.statSync(last).mtimeMs : 0;
  if (last) log.info(`  📸 Último screenshot conocido: ${path.basename(last)}`);

  while (true) {
    await sleep(interval * 1000);
    const current = getLatestScreenshot();
    if (!current) continue;

    const mtime = fs.statSync(current).mtimeMs;
    const isNew = !last || current !== last || mtime > lastMtime;

    if (!isNew) continue;

    log.info(`\n[${new Date().toTimeString().slice(0, 8)}] 📸 Nuevo screenshot! ${path.basename(current)}`);
    last = current;
    lastMtime = mtime;

    if (!(await waitForFileStable(current))) {
      log.info('     ⚠️  El archivo puede estar aún escribiéndose');
    }

    try {
      await analyzeImage(current, opts);
    } catch (e) {
      log.error(e.message);
    }
  }
}

// ============================================================
// 🏁 MAIN
// ============================================================

function printHelp() {
  console.log(`
🔐 KIMI_VISION — Detección de permisos con visión IA (Kimi K3)
=============================================================
Uso: node kimi_vision.js [opciones]

  --img RUTA            Analizar screenshot existente
  --pkg PAQUETE         Package name de la app
  --grant               Conceder permiso automáticamente (vía rish)
  --monitor             [RECOMENDADO] Espera screenshot nuevo en galería
  --watch               Toma screenshot automático (screencap)
  --screenshot          Tomar screenshot ahora y analizar
  --interval SEG        Intervalo en segundos (default: monitor=3, watch=5)
  --min-confidence N    Mínimo % para conceder (default: 50)
  --json                Salida JSON cruda (para scripting)
  -h, --help            Esta ayuda

Requisitos:
  export HF_TOKEN=hf_xxx
  Aceptar licencia: https://huggingface.co/moonshotai/Kimi-K3

Ejemplos:
  node kimi_vision.js --img screenshot.png
  node kimi_vision.js --img screenshot.png --pkg com.xuper.tv --grant
  node kimi_vision.js --monitor --pkg com.xuper.tv --grant
`);
}

function toInt(value, fallback) {
  const n = parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
}

function parseArgs(argv) {
  const opts = { img: null, pkg: '', grant: false, watch: false, monitor: false, screenshot: false, interval: null, json: false, minConfidence: 50 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--img': opts.img = argv[++i]; break;
      case '--pkg': opts.pkg = argv[++i]; break;
      case '--grant': opts.grant = true; break;
      case '--watch': opts.watch = true; break;
      case '--monitor': opts.monitor = true; break;
      case '--screenshot': opts.screenshot = true; break;
      case '--json': opts.json = true; break;
      case '--interval': opts.interval = toInt(argv[++i], null); break;
      case '--min-confidence': opts.minConfidence = toInt(argv[++i], 50); break;
      case '-h':
      case '--help': printHelp(); process.exit(0); break;
      default:
        console.error(`❌ Opción desconocida: ${a}`);
        printHelp();
        process.exit(1);
    }
  }
  return opts;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));

  if (!opts.img && !opts.watch && !opts.monitor && !opts.screenshot) {
    printHelp();
    return;
  }

  if (!HF_TOKEN) {
    log.error('Falta HF_TOKEN. Ejecuta: export HF_TOKEN=hf_xxx');
    process.exit(1);
  }

  if (opts.monitor) { await monitorLoop(opts.interval || 3, opts); return; }
  if (opts.watch) { await watchLoop(opts.interval || 5, opts); return; }

  if (opts.screenshot) {
    const img = takeScreenshot();
    if (!img) return;
    await analyzeImage(img, opts);
    return;
  }

  const imgPath = path.resolve(opts.img.replace(/^~\//, HOME + '/'));
  if (!fs.existsSync(imgPath)) {
    log.error(`❌ No se encuentra: ${opts.img}`);
    process.exit(1);
  }
  await analyzeImage(imgPath, opts);
}

if (require.main === module) {
  process.on('SIGINT', () => {
    log.info('\n  👋 Hasta luego');
    process.exit(0);
  });
  main().catch(e => {
    log.error(e.message);
    process.exit(1);
  });
}

module.exports = {
  PERMISSION_MAP,
  SYSTEM_PROMPT,
  runCmd,
  takeScreenshot,
  fileToDataUrl,
  callKimi,
  extractJson,
  detectPermission,
  grantPermission,
  analyzeImage,
  getLatestScreenshot,
  waitForFileStable,
};

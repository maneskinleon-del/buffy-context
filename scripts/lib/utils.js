// ─────────────────────────────────────────────
// lib/utils.js — Utilidades generales
// ─────────────────────────────────────────────

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const log = require('./logger');

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function screenshot(page, label, opts) {
  if (!opts.screenshot) return;
  const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const dir = opts.screenshotDir;
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  const filePath = path.join(dir, `form_${label}_${ts}.png`);
  await page.screenshot({ path: filePath, fullPage: true });
  log.info(`  📸 ${filePath}`);
}

function askQuestion(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise(resolve => rl.question(query, answer => {
    rl.close();
    resolve(answer);
  }));
}

function loadDataFile(filePath, defaultData) {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const data = JSON.parse(content);
    return { ...defaultData, ...data };
  } catch (e) {
    log.error(`Error al cargar archivo de datos: ${e.message}`);
    process.exit(1);
  }
}

function getTypeName(el) {
  if (el.tag === 'input' && el.type) return el.type;
  return el.tag;
}

async function retry(fn, options = {}) {
  const {
    maxRetries = 3,
    baseDelay = 800,
    label = 'operación',
  } = options;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      if (attempt === maxRetries) throw err;
      const delay = baseDelay * Math.pow(2, attempt - 1);
      if (options.verbose) {
        log.warn(`  🔄 ${label}: intento ${attempt} falló, reintentando en ${delay}ms...`);
      }
      await sleep(delay);
    }
  }
}

module.exports = {
  sleep,
  screenshot,
  askQuestion,
  loadDataFile,
  getTypeName,
  retry,
};

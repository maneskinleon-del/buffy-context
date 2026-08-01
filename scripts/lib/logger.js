// ─────────────────────────────────────────────
// lib/logger.js — Logging estructurado con niveles
// ─────────────────────────────────────────────
//
// Niveles: DEBUG (0) < INFO (1) < WARN (2) < ERROR (3) < SILENT (4)
// Uso:
//   const log = require('./logger');
//   log.debug('Mensaje detallado');
//   log.info('Mensaje normal');
//   log.warn('Cuidado...');
//   log.error('Algo falló');
//
// Para activar DEBUG: node fill_form.js <url> --verbose
// Para nivel específico: LOG_LEVEL=debug node fill_form.js <url>

const LOG_LEVELS = {
  DEBUG: 0,
  INFO:  1,
  WARN:  2,
  ERROR: 3,
  SILENT: 4,
};

const LEVEL_NAMES = ['DEBUG', 'INFO', 'WARN', 'ERROR'];

let currentLevel = LOG_LEVELS.INFO;  // Default

function setLevel(level) {
  if (typeof level === 'string') {
    const upper = level.toUpperCase();
    if (LOG_LEVELS[upper] !== undefined) {
      currentLevel = LOG_LEVELS[upper];
      return;
    }
  }
  if (typeof level === 'number' && level >= 0 && level <= 4) {
    currentLevel = level;
  }
}

function getLevel() { return currentLevel; }
function isDebug() { return currentLevel <= LOG_LEVELS.DEBUG; }

// Timestamp corto: [HH:MM:SS]
function ts() {
  const d = new Date();
  return d.toTimeString().slice(0, 8);
}

function debug(...args) {
  if (currentLevel <= LOG_LEVELS.DEBUG) {
    console.log(`  🔍 [${ts()}]`, ...args);
  }
}

function info(...args) {
  if (currentLevel <= LOG_LEVELS.INFO) {
    console.log(...args);
  }
}

function warn(...args) {
  if (currentLevel <= LOG_LEVELS.WARN) {
    console.log(`  ⚠️ [${ts()}]`, ...args);
  }
}

function error(...args) {
  if (currentLevel <= LOG_LEVELS.ERROR) {
    const prefix = `  ❌ [${ts()}]`;
    if (args.length === 1 && args[0] instanceof Error) {
      console.error(prefix, args[0].message);
      if (isDebug()) console.error(args[0].stack);
    } else {
      console.error(prefix, ...args);
    }
  }
}

// Inicializar desde variable de entorno
const envLevel = process.env.LOG_LEVEL;
if (envLevel) setLevel(envLevel);

module.exports = {
  LOG_LEVELS,
  setLevel,
  getLevel,
  isDebug,
  debug,
  info,
  warn,
  error,
};

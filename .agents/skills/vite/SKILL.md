---
name: vite
description: "Referencia de Vite para React + TypeScript: config básica, plugins, path aliases, env vars y PWA. El stack del usuario es React + TypeScript + Tailwind v4 + Vite."
version: 1.0.0
author: "mangonz"
---

# vite — Build Tool (React + TypeScript)

## Propósito

Referencia rápida de Vite para proyectos React + TypeScript: configurar, optimizar y buildear sin buscar en docs cada vez.

## Config básica (`vite.config.ts`)

```ts
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    host: true,             // Accesible desde la red local
  },
  build: {
    outDir: 'dist',
    sourcemap: false,       // Desactivar en producción
    minify: 'esbuild',      // O 'terser' para mejor ofuscación
  },
});
```

## Comandos

```bash
npm run dev                  # Desarrollo (localhost:5173)
npm run build                # Build producción
npm run preview              # Preview del build
npx vite --host              # Dev accesible desde la red
```

## Plugins comunes

```bash
npm i -D @vitejs/plugin-react          # React
npm i -D @tailwindcss/vite            # Tailwind v4
npm i -D vite-plugin-pwa              # PWA
npm i -D vite-plugin-terminal         # Logs en terminal
```

## Path aliases

```ts
// vite.config.ts
resolve: {
  alias: {
    '@': '/src',
    '@components': '/src/components',
    '@lib': '/src/lib',
  }
}

// tsconfig.json (para que TS lo entienda)
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"]
    }
  }
}
```

## Environment variables

```
# .env
VITE_API_URL=http://localhost:8080
VITE_APP_TITLE=MiApp

# En código: import.meta.env.VITE_API_URL
# Solo VITE_* se exponen al frontend
```

## PWA con Vite

```ts
import { VitePWA } from 'vite-plugin-pwa';

plugins: [
  VitePWA({
    registerType: 'autoUpdate',
    manifest: {
      name: 'MiApp',
      short_name: 'MiApp',
      theme_color: '#1e222a',
    },
  }),
],
```

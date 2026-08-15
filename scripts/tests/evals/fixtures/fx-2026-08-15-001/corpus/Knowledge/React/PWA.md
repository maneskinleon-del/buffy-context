# Progressive Web Apps — Referencia

> El usuario tiene proyectos PWA: `pwa_securguard`, `widgetos`, `timemark`.

## Manifest

```json
{
  "name": "MiApp",
  "short_name": "MiApp",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1e222a",
  "theme_color": "#1e222a",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

## Service Worker

```ts
// Estrategia: Cache First para assets, Network First para API
self.addEventListener('fetch', (event) => {
  if (event.request.url.includes('/api/')) {
    // Network First
    event.respondWith(networkFirst(event.request));
  } else {
    // Cache First
    event.respondWith(cacheFirst(event.request));
  }
});
```

## vite-plugin-pwa

```ts
// vite.config.ts
import { VitePWA } from 'vite-plugin-pwa';

VitePWA({
  registerType: 'autoUpdate',
  includeAssets: ['*.svg', '*.png'],
  manifest: { /* ... */ },
  workbox: {
    globPatterns: ['**/*.{js,css,html,svg,png}'],
    runtimeCaching: [
      { urlPattern: /^https?:\/\/api\./, handler: 'NetworkFirst' },
    ],
  },
});
```

## Comprobación

```ts
// Verificar service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/sw.js');

  // Escuchar actualizaciones
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    window.location.reload();
  });
}

// Verificar instalación
const isInstalled = window.matchMedia('(display-mode: standalone)').matches;
```

## Tips

- Los PWAs necesitan **HTTPS** (o localhost) para service worker
- `display: standalone` oculta la barra del navegador
- Preferir `autoUpdate` en `vite-plugin-pwa` para usuarios normales
- El `theme_color` en manifest coincide con la paleta del tema
- Iconos mínimos: 192x192 + 512x512 (maskable para Android)

# Node.js — Referencia rápida

> Versiones del usuario: **node v26.4.0** · **npm 11.18.0**.
> Instalación global en `~/.npm-global`.

## npm global

```bash
# Ver dónde se instalan los paquetes globales
npm root -g                   # ~/.npm-global/lib/node_modules

# Listar paquetes globales
npm list -g --depth=0

# Instalar global
npm install -g <paquete>

# Configurar prefix (si no está en PATH)
npm config set prefix ~/.npm-global
```

## package.json

```json
{
  "name": "mi-proyecto",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "lint": "eslint src/",
    "test": "vitest"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "vite": "^8.0.0",
    "vitest": "^3.0.0"
  }
}
```

## Scripts útiles

```bash
npm run dev                    # Desarrollo
npm run build                  # Build producción
npm run preview                # Vista previa del build
npm test                       # Tests
npm run <script>               # Script personalizado
npx <comando>                  # Ejecutar sin instalar
```

## Tips

- `npm ci` instala desde `package-lock.json` (más rápido, reproducible)
- `npm outdated` muestra paquetes desactualizados
- `npm audit` muestra vulnerabilidades
- Preferir `--save-exact` para versiones fijas en producción
- Usar `.nvmrc` si se necesita cambiar versión de Node

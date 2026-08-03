---
name: tailwind-design-system
description: "Design system con Tailwind CSS v4 + convención de colores estilo Material Design 3 (surface, on-surface, primary, outline). El usuario usa Tailwind v4 con Vite."
version: 1.0.0
author: "mangonz"
---

# tailwind-design-system — Design System Tailwind v4

## Propósito

Mantener consistencia visual en los proyectos React del usuario: utilidades Tailwind, convención de nombres de colores (tema oscuro) y patrones de layout, hover y responsive.

## Setup con Vite

```bash
npm install tailwindcss @tailwindcss/vite
```

```ts
// vite.config.ts
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  plugins: [react(), tailwindcss()],
});
```

```css
/* src/index.css - Única línea necesaria */
@import "tailwindcss";
```

## Colores (tema oscuro) — convención Material Design 3

```tsx
bg-surface                 // Fondo principal
bg-surface-container       // Fondo de contenedores
bg-surface-container-high  // Fondo elevado
text-on-surface            // Texto principal
text-on-surface-variant    // Texto secundario
text-primary               // Texto de acento
bg-primary                 // Fondo de acento
text-on-primary            // Texto sobre acento
border-outline             // Bordes
border-outline-variant     // Bordes suaves
```

## Utilidades frecuentes

```tsx
/* Layout */
<div className="flex items-center justify-between gap-4" />

/* Grid responsivo */
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6" />

/* Cards */
<div className="rounded-xl bg-surface p-4 shadow-sm hover:shadow-md transition-shadow" />

/* Texto */
<h1 className="text-2xl font-bold text-on-surface" />
<p className="text-sm text-on-surface-variant" />

/* Botones */
<button className="px-4 py-2 bg-primary text-on-primary rounded-lg 
  hover:bg-primary-hover active:scale-95 transition-all" />

/* Inputs */
<input className="w-full px-3 py-2 bg-surface-container border border-outline 
  rounded-lg focus:ring-2 focus:ring-primary outline-none" />
```

## Animaciones

```tsx
className="transition-all duration-200 ease-in-out"
className="hover:scale-105 transition-transform"
className="animate-fade-in"
className="animate-spin"
```

## Responsive

```tsx
// Breakpoints: sm (640), md (768), lg (1024), xl (1280), 2xl (1536)
className="text-sm md:text-base lg:text-lg"
className="grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
className="hidden md:flex"     // Oculto en mobile, visible en desktop
className="flex md:hidden"     // Visible en mobile, oculto en desktop
```

## Dark mode (por clase)

```tsx
// Config en index.css
@custom-variant dark (&:where(.dark, .dark *));

// Uso
className="bg-white dark:bg-surface text-black dark:text-on-surface"
```

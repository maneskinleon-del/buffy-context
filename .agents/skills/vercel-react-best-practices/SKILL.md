---
name: vercel-react-best-practices
description: "Buenas prácticas React + TypeScript para proyectos deployados en Vercel: patrones de componentes, state, performance (memo/useMemo/useCallback) y testing con Vitest."
version: 1.0.0
author: "mangonz"
---

# vercel-react-best-practices — React + TypeScript en Vercel

## Propósito

Patrones consistentes para los proyectos React + TypeScript + Tailwind v4 + Vite del usuario, que se deployan a Vercel: componentes limpios, estado manejado y performance sin librerías externas innecesarias.

## Patrones de componentes

```tsx
interface Props {
  title: string;
  children?: React.ReactNode;
}

export const Card = ({ title, children }: Props) => (
  <div className="rounded-xl bg-surface p-4">
    <h2>{title}</h2>
    {children}
  </div>
);
```

## State management

```tsx
// Preferir useState + useReducer antes que librerías externas
const [state, dispatch] = useReducer(reducer, initialState);

// Context para estado global (no sobreusar)
const ThemeContext = createContext<ThemeContextType | null>(null);
```

## Efectos

```tsx
useEffect(() => {
  // cleanup siempre
  return () => { /* cleanup */ };
}, [deps]);
```

## Performance

```tsx
// Memoizar componentes pesados
const ExpensiveList = memo(({ items }: { items: Item[] }) => (
  <ul>{items.map(item => <li key={item.id}>{item.name}</li>)}</ul>
));

// useMemo para cálculos caros
const sorted = useMemo(() => 
  items.sort((a, b) => a.name.localeCompare(b.name)), 
  [items]
);

// useCallback para callbacks (evita re-renders hijos)
const handleClick = useCallback(() => {
  setCount(c => c + 1);
}, []);
```

## Testing (Vitest)

```tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';

describe('Card', () => {
  it('renders title', () => {
    render(<Card title="Hello" />);
    expect(screen.getByText('Hello')).toBeDefined();
  });
});
```

## Reglas

1. Sin librerías de estado externas (Redux/Zustand) salvo necesidad real — useState/useReducer cubren el 90%.
2. `memo`/`useMemo`/`useCallback` solo donde hay costo medible; no decorar todo.
3. Cada efecto con cleanup; deps explícitas.

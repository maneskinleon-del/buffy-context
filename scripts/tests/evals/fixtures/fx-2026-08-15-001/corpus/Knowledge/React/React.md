# React + TypeScript — Referencia rápida

> Stack del usuario: React + TypeScript + Tailwind v4 + Vite → GitHub → Vercel.
> Skills relacionadas: `.agents/skills/vercel-react-best-practices/`, `.agents/skills/typescript-advanced-types/`.

## Patrones comunes

```tsx
// Componente funcional con tipos
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

### State management

```tsx
// Preferir useState + useReducer antes que librerías externas
const [state, dispatch] = useReducer(reducer, initialState);

// Context para estado global (no sobreusar)
const ThemeContext = createContext<ThemeContextType | null>(null);
```

### Efectos

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

## TypeScript tips

```tsx
// Type narrowing
type Result<T> = { ok: true; data: T } | { ok: false; error: string };

// Template literals
type EventName = `on${Capitalize<string>}`;

// Utility types
type PartialUser = Partial<User>;
type ReadonlyUser = Readonly<User>;
type UserWithoutId = Omit<User, 'id'>;
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

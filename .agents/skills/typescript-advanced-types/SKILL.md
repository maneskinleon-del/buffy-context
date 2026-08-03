---
name: typescript-advanced-types
description: "Patrones de tipos avanzados de TypeScript para el stack React + TS del usuario: narrowing, template literal types, utility types, discriminated unions."
version: 1.0.0
author: "mangonz"
---

# typescript-advanced-types — Tipos Avanzados

## Propósito

Escribir tipos precisos en proyectos React + TypeScript: reducir `any`, modelar estados con unions discriminadas y aprovechar utility types sin reinventar.

## Type narrowing — discriminated unions

```ts
// Modela resultados con éxito/error sin ambigüedad
type Result<T> = { ok: true; data: T } | { ok: false; error: string };

function handle(r: Result<User>) {
  if (r.ok) {
    r.data; // TS sabe que es User
  } else {
    r.error; // TS sabe que es string
  }
}
```

## Template literal types

```ts
type EventName = `on${Capitalize<string>}`;
// "onClick" | "onChange" | "onSubmit" ...
```

## Utility types

```ts
type PartialUser = Partial<User>;
type ReadonlyUser = Readonly<User>;
type UserWithoutId = Omit<User, 'id'>;
type PickedUser = Pick<User, 'name' | 'email'>;
```

## Componentes tipados

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

## Reglas

1. Nunca usar `any` a propósito — modelar con unions discriminadas o genéricos.
2. Preferir `Omit`/`Pick`/`Partial` sobre redefinir interfaces.
3. Para callbacks de eventos, dejar que TS infiera el tipo del parámetro.

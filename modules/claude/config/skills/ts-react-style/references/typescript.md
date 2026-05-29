# Plain TypeScript

## Types

- Never `any` — not even to silence a TS error. Use `unknown` and narrow it,
  or fix the actual type.
- Prefer `interface` over `type` everywhere an interface can express it. `type`
  only for unions, intersections, tuples, mapped / conditional / utility types.
- Type guards live in one shared `falsy` / `truthy` / `isX` module — no ad-hoc
  inline checks.

## Constants & enums

- `enum` for runtime constant sets referenced as values (statuses, kinds, roles).
- `as const satisfies Record<Enum, ...>` for label / config / lookup maps keyed
  by those enums:

  ```ts
  const statusLabels = {
    [Status.Pending]: 'Pending',
    [Status.Done]: 'Done',
  } as const satisfies Record<Status, string>
  ```

## Pattern matching

- Native `switch` / `if`-return for simple branching.
- `ts-pattern` `match()` for discriminated unions, multi-field matching, and
  exhaustive checks (`.exhaustive()`).

## Validation at boundaries

- Parse external / unknown data with Zod (API responses, env, storage,
  payloads) — parse, never cast.
- Derive TS types from the schema; don't declare them twice.

## Classes

- Explicit accessibility modifier on every member.
- Constructor parameter properties for DI: `constructor(private readonly page: Page) {}`.

## Naming

- Name a `Map` / lookup `<values>By<key>` so the key is obvious from the name:
  `backlinksByTarget` (keyed by target path), `usersById`. Not a bare `index` /
  `map` / `cache`.
- When the same concept exists in a raw and a resolved form, give each a
  distinct name — `linkTarget` (raw `[[...]]` string) vs `targetPath` (resolved
  vault path). Don't reuse one word for both states.

## Modules

- Relative imports inside a module; absolute alias imports across modules, only
  from the public `index.ts` barrel.
- Barrels export only public API.

## Preferred libraries

Before writing a utility, check the libraries below first — reach for a hand-
rolled helper only when none of them covers the case. Specifically: no custom
array / object / function helpers that `es-toolkit` already provides, and no
custom utility types that `type-fest` already provides.

- `zod` — runtime validation
- `ts-pattern` — complex pattern matching
- `es-toolkit` — general utilities (over lodash)
- `date-fns` — dates
- `type-fest` — advanced utility types
- `nanoid` — ID generation

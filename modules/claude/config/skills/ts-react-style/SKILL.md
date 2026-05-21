---
name: ts-react-style
description: "User's personal TypeScript and React code conventions — naming, formatting, type style, error handling, component structure, accessibility. Use when writing or reviewing TypeScript or React code. Read references/typescript.md for plain TS rules, references/react.md for React/JSX rules."
---

# TypeScript & React style

Encodes the user's personal conventions for writing TypeScript and React code.
Base TS/React knowledge is assumed — this file only lists the choices that
differ from default code generation.

## How to use

1. Read this file fully — it covers rules common to all TypeScript code.
2. Read the relevant reference:
   - Plain TypeScript (types, errors, classes, modules) → [references/typescript.md](references/typescript.md)
   - React components, JSX, hooks, styling, a11y → [references/react.md](references/react.md)
3. If the project ships its own style skill or rules (an Effect skill,
   project `.cursor/rules`, a local `CLAUDE.md`), those take precedence —
   this skill is the fallback for stack-agnostic preferences.

## Common rules (DO / DON'T)

| Area | DO | DON'T |
|---|---|---|
| Files & dirs | kebab-case everywhere (`partner-balance-form.tsx`) | PascalCase / camelCase file names |
| Exports | named exports | `export default` |
| Functions | top-level `function` declarations | top-level `const fn = () => {}` |
| Callbacks | arrow functions for inline callbacks | wrapping inline callbacks in declarations |
| Parameters | destructure in the signature | positional params + `.prop` access inside |
| Comments | none — write self-documenting code | inline / JSDoc / TODO comments unless asked |
| Debug logs | `console.log({ value })` | `console.log(value)` |
| Quotes / semicolons | single quotes, no semicolons | double quotes, trailing semicolons |
| Indentation | spaces | tabs |

## Formatting

Biome is the formatter and linter: single quotes, semicolons as-needed (i.e.
omitted), space indentation.

Biome `organizeImports` groups and orders imports automatically (built-ins →
external packages → shared-layer alias → other aliases → relative → URL, with
blank lines between groups). Don't hand-order imports against it.

# Proxy Bindings

Shared registry of keyboard shortcuts assigned in third-party apps (1Password, CleanShot, Raycast, etc.) that are triggered programmatically by Hammerspoon and Karabiner.

## Problem

To trigger an app's action from LeaderFlow (Hammerspoon), you either use its macOS menu or assign a keyboard shortcut in that app and send it via `hs.eventtap.keyStroke()`. These "proxy shortcuts" are invisible contracts between your tools and third-party apps — without a central registry they end up as magic strings scattered across configs.

## Architecture

```
modules/proxy-bindings/
  proxy-bindings.yaml          ← single source of truth

packages/proxy-bindings/
  src/
    cli.ts                     ← entry point (bun CLI)
    config.ts                  ← YAML loading + auto-discovery
    generate.ts                ← orchestrator
    generators/
      lua.ts                   ← Hammerspoon output
      typescript.ts            ← Karabiner output (karabiner.ts toKey() calls)

modules/hammerspoon/config/
  generated/
    proxy-bindings.lua         ← GENERATED

modules/karabiner/config/src/
  generated/
    proxy-bindings.ts          ← GENERATED
```

## Config format

```yaml
# modules/proxy-bindings/proxy-bindings.yaml
outputs:
  lua: ../hammerspoon/config/generated/proxy-bindings.lua
  typescript: ../karabiner/config/src/generated/proxy-bindings.ts

bindings:
  fix: cmd alt ctrl shift 1
  passwords: cmd shift space
  colorPicker: cmd alt ctrl p
  screenshotArea: cmd shift 2
  # ...
```

- Keys are camelCase identifiers
- Values are Hammerspoon keystroke strings (`mod1 mod2 key`)
- Output paths are relative to the YAML file

## Generated outputs

**Lua** (Hammerspoon) — keys are converted to snake_case:

```lua
local M = {}
M.fix = "cmd alt ctrl shift 1"
M.passwords = "cmd shift space"
return M
```

**TypeScript** (Karabiner) — shortcuts are parsed into `toKey()` calls:

```typescript
export const proxy = {
  fix: toKey('1' as ToKeyParam, '⌘⌥⌃⇧' as ModifierParam),
  passwords: toKey('space' as ToKeyParam, '⌘⇧' as ModifierParam),
} as const
```

## Usage

### Regenerate

```bash
dot proxy-bindings              # auto-discovers proxy-bindings.yaml
dot proxy-bindings -c path.yaml # explicit config
```

Also runs automatically as Karabiner's `prebuild` step (`bun run build` triggers it).

### In Hammerspoon

```lua
local proxy = require("generated.proxy-bindings")
shortcut(proxy.fix)
shortcut(proxy.passwords)
```

### In Karabiner

```typescript
import { proxy } from './generated/proxy-bindings'
map('f').to(proxy.fix)
```

## Adding a new binding

1. Add entry to `modules/proxy-bindings/proxy-bindings.yaml`
2. Run `dot proxy-bindings`
3. Use the new key in Hammerspoon (`proxy.new_key`) or Karabiner (`proxy.newKey`)

# Proxy Bindings

Shared registry of keyboard shortcuts assigned in third-party apps that are triggered programmatically by Hammerspoon and Karabiner. All proxy shortcuts use the Hyper modifier (⌃⌥⇧⌘) so they can't be triggered accidentally.

## Problem

To trigger an app's action from LeaderFlow (Hammerspoon), you either use its macOS menu or assign a keyboard shortcut in that app and send it via `hs.eventtap.keyStroke()`. These "proxy shortcuts" are invisible contracts between your tools and third-party apps — without a central registry they end up as magic strings scattered across configs.

## Architecture

```
modules/proxy-bindings/
  proxy-bindings.yaml          ← single source of truth (YAML config)

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
    proxy-bindings.lua         ← GENERATED — require("generated.proxy-bindings")

modules/karabiner/config/src/
  generated/
    proxy-bindings.ts          ← GENERATED — import { proxy } from './generated/proxy-bindings'
```

## Config format

```yaml
# modules/proxy-bindings/proxy-bindings.yaml
outputs:
  lua: ../hammerspoon/config/generated/proxy-bindings.lua
  typescript: ../karabiner/config/src/generated/proxy-bindings.ts

bindings:
  fix: cmd alt ctrl shift r
  passwords: cmd alt ctrl shift p
  colorPicker: cmd alt ctrl shift c
  screenshotArea: cmd alt ctrl shift 1
  # ...
```

- Keys are camelCase identifiers
- Values are Hammerspoon keystroke strings (`mod1 mod2 key`)
- All bindings use Hyper (⌃⌥⇧⌘) to avoid conflicts with regular shortcuts
- Output paths are relative to the YAML file

## Current bindings

| ID | Shortcut | App | LeaderFlow |
|---|---|---|---|
| `fix` | ⌃⌥⇧⌘R | RewriteBar | a → a |
| `passwords` | ⌃⌥⇧⌘P | 1Password | p |
| `colorPicker` | ⌃⌥⇧⌘C | Sip | u → c |
| `roulette` | ⌃⌥⇧⌘X | PixelSnap | u → r |
| `rouletteClear` | ⌃⌥⇧⌘Z | PixelSnap | u → x |
| `spotlight` | ⌃⌥⇧⌘F | Raycast | (Karabiner Hyper+F) |
| `screenshotArea` | ⌃⌥⇧⌘1 | CleanShot X | s → s |
| `screenshotFull` | ⌃⌥⇧⌘2 | CleanShot X | s → f |
| `screenshotWindow` | ⌃⌥⇧⌘3 | CleanShot X | s → w |
| `screenshotOcr` | ⌃⌥⇧⌘4 | CleanShot X | s → o |
| `screenshotVideo` | ⌃⌥⇧⌘5 | CleanShot X | s → r |
| `screenshotScroll` | ⌃⌥⇧⌘6 | CleanShot X | s → l |
| `screenshotHistory` | ⌃⌥⇧⌘7 | CleanShot X | s → h |

## Generated outputs

**Lua** (Hammerspoon) — keys are converted to snake_case:

```lua
local M = {}
M.fix = "cmd alt ctrl shift r"
M.passwords = "cmd alt ctrl shift p"
return M
```

**TypeScript** (Karabiner) — shortcuts are parsed into `toKey()` calls:

```typescript
export const proxy = {
  fix: toKey('r' as ToKeyParam, '⌘⌥⌃⇧' as ModifierParam),
  passwords: toKey('p' as ToKeyParam, '⌘⌥⌃⇧' as ModifierParam),
} as const
```

## Usage

### Regenerate

```bash
dot proxy-bindings              # auto-discovers proxy-bindings.yaml
dot proxy-bindings -c path.yaml # explicit config
```

Generation runs automatically:
- `dot rebuild` runs `dot:proxy-bindings` as a dependency before `darwin-rebuild`
- `bun run build` in Karabiner runs it as a `prebuild` step

### In Hammerspoon

```lua
local proxy = require("generated.proxy-bindings")
shortcut(proxy.fix)
shortcut(proxy.passwords)
shortcut(proxy.screenshot_area)
```

### In Karabiner

```typescript
import { proxy } from './generated/proxy-bindings'
map('f').to(proxy.spotlight)
```

## Hyper Setup mode

To configure proxy shortcuts in third-party apps, you need to send the real ⌃⌥⇧⌘ modifier. Hammerspoon provides a toggle mode where Tab acts as Hyper:

1. **F18 → u → h** — toggle Hyper Setup mode
2. In the app's "Record shortcut" dialog, hold **Tab + key**
3. **F18 → u → h** — toggle off when done

## Adding a new binding

1. Enable Hyper Setup mode (**F18 → u → h**)
2. Open the third-party app's shortcut settings
3. In the "Record shortcut" dialog, hold **Tab + key** to assign ⌃⌥⇧⌘+key
4. Disable Hyper Setup mode (**F18 → u → h**)
5. Add the entry to `modules/proxy-bindings/proxy-bindings.yaml`
6. Run `dot proxy-bindings`
7. Use the new key in Hammerspoon (`proxy.new_key`) or Karabiner (`proxy.newKey`)

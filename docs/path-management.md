# PATH Management

## Проблемы (текущее состояние)

PATH модифицируется в 6+ местах: `00-env.fish`, `01-brew.fish`, `pnpm.fish`, `mise.fish`, `zz-env.fish`, nix-darwin `set-environment`.

- `mise activate` вызывается дважды (mise.fish + zz-env.fish)
- Nix paths дублируются (set-environment + zz-env.fish)
- Zsh (Cursor агенты) — только Nix paths, нет brew/mise/pnpm/bun/~/.local/bin
- pnpm/bun global CLI не работают
- Конфигурация размазана, сложно понять итоговый PATH

## Целевая архитектура: 3 слоя

### Слой 1: nix-darwin (все shells)

`environment.systemPath` → попадает в `set-environment` → sourced через `/etc/zshenv` (zsh) и nix-darwin fish module (fish).

Один список — оба shell получают одинаковый PATH.

```nix
environment.systemPath = [
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "/opt/homebrew/opt/ruby/bin"
  "/opt/homebrew/opt/curl/bin"
  "/opt/homebrew/opt/sqlite/bin"
  "$HOME/.local/share/mise/shims"  # non-interactive shells, IDE, агенты
  "$HOME/.local/share/pnpm"
  "$HOME/.bun/bin"
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/go/bin"
];

environment.variables = {
  HOMEBREW_PREFIX = "/opt/homebrew";
  HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY = "/opt/homebrew";
  GOPATH = "$HOME/go";
  PNPM_HOME = "$HOME/.local/share/pnpm";
  EDITOR = "cursor --wait";
  VISUAL = "cursor --wait";
};
```

`environment.variables` — то же: одно место, оба shell.

### Слой 2: launchd (GUI apps)

```nix
launchd.user.envVariables = {
  PATH = "...полный статический PATH с абсолютными путями...";
};
```

Единственный способ дать PATH GUI приложениям (Cursor, VS Code). Не поддерживает $HOME — только абсолютные пути. Требует logout/login.

### Слой 3: fish interactive (минимум)

Единственное что нельзя вынести в nix — `mise activate fish` (runtime hook, shell-specific).

```fish
# conf.d/mise.fish
if status is-interactive; and type -q mise
    mise activate fish | source
end
```

Всё остальное удаляется из fish conf.d.

## mise: shims vs activate

- **shims** (`~/.local/share/mise/shims` в systemPath) — работают везде: скрипты, IDE, non-interactive. Шим сам определяет версию при вызове.
- **activate** — динамическое переключение при `cd`, поддержка `[env]` из `.mise.toml`. Только interactive.
- Совместимы: shims как fallback, activate перекрывает в interactive shell.

## Сравнение подходов

| Подход | Fish | Zsh | GUI | Декларативный |
|---|---|---|---|---|
| `environment.systemPath` | через nix fish module | да (/etc/zshenv) | нет | да |
| `/etc/paths.d/` | нет | login only | нет | возможен |
| `launchd.user.envVariables` | нет | нет | **да** | да |
| `fish_add_path` в conf.d | **да** | нет | нет | да |
| mise shims | да | да | да | да |
| mise activate | да | да | нет | да |

`/etc/paths.d/` не рекомендуется — `path_helper` переупорядочивает PATH, конфликтует с nix-darwin.
`environment.d/` не существует на macOS (systemd-only).

## Что удалить из fish при миграции

- PATH/env из `00-env.fish` (→ nix environment.variables)
- `01-brew.fish` целиком (→ homebrew module integration)
- `pnpm.fish` (→ environment.systemPath + environment.variables)
- `zz-env.fish` целиком (→ environment.systemPath)
- Дублирование `mise activate` из zz-env.fish

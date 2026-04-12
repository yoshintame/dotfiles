# PATH Management

## Текущая архитектура

PATH и env vars задаются в **двух** местах из-за ограничений nix-darwin:

- `environment.variables` (nix-darwin) → bash-скрипт `set-environment` → sourced через `/etc/zshenv` → **zsh only**
- `home.sessionVariables` (home-manager) → `hm-session-vars.fish` → sourced через `config.fish` → **fish only**

Ни один механизм не покрывает оба shell, поэтому **env vars дублируются** в обоих местах.

| Механизм | zsh interactive | zsh non-interactive | fish |
|---|---|---|---|
| `environment.variables` | ✅ | ✅ | ❌ |
| `home.sessionVariables` | ✅ (`.zshrc`) | ❌ | ✅ |

### Слой 1: nix-darwin `environment.variables`

`hosts/lasthaze-mbp/default.nix` — вне home-manager блока:

```nix
environment.variables = {
  HOMEBREW_PREFIX = "/opt/homebrew";
  HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY = "/opt/homebrew";
  HOMEBREW_NO_ANALYTICS = "1";
  HOMEBREW_NO_ENV_HINTS = "1";
  HOMEBREW_BUNDLE_FILE = "${homeDir}/.config/packages/Brewfile";
  GOPATH = "${homeDir}/go";
  PNPM_HOME = "${homeDir}/.local/share/pnpm";
  DOTFILES = "${homeDir}/.dotfiles";
  EDITOR = "cursor --wait";
  VISUAL = "cursor --wait";
};
```

Попадает в `/nix/store/...-set-environment` → `/etc/zshenv`.
Покрывает zsh (включая non-interactive — Cursor агенты, скрипты).

### Слой 2: home-manager `home.sessionPath` + `home.sessionVariables`

`hosts/lasthaze-mbp/default.nix` — внутри home-manager блока:

```nix
home.sessionPath = [
  "/opt/homebrew/bin"
  "/opt/homebrew/sbin"
  "/opt/homebrew/opt/ruby/bin"
  "/opt/homebrew/opt/curl/bin"
  "/opt/homebrew/opt/sqlite/bin"
  "${homeDir}/.local/share/mise/shims"
  "${homeDir}/.local/share/pnpm"
  "${homeDir}/.bun/bin"
  "${homeDir}/go/bin"
  "${homeDir}/.local/bin"
  "${homeDir}/bin"
];

home.sessionVariables = {
  EDITOR = "cursor --wait";
  VISUAL = "cursor --wait";
  GOPATH = "${homeDir}/go";
  PNPM_HOME = "${homeDir}/.local/share/pnpm";
  DOTFILES = "${homeDir}/.dotfiles";
};
```

Генерирует `hm-session-vars.fish` (PATH + env vars) → sourced из `config.fish`.
Покрывает fish. Также генерирует `.zshrc` (для interactive zsh).

### Слой 3: fish conf.d (минимум)

После рефакторинга в fish conf.d остаётся только то, что нельзя вынести в nix:

- `00-env.fish` — `__fish_cache_dir`, `node_modules/.bin` (per-project), GRC plugin config
- `01-brew.fish` — fish completions path, manpath для keg-only apps
- `keybinds.fish` — кастомные биндинги и smart-функции
- `tmux.fish` — auto-attach с исключениями для VSCode/Warp
- `vscode.fish` — VSCode shell integration

Удалено: `mise.fish`, `pnpm.fish`, `zz-env.fish`, `atuin.fish`, `promt.fish`, `zoxide.fish`, `fisher.fish`, `source.fish`, `abbr.fish`, `aliases/`.

### Fish модуль через nix

Структура `modules/fish/` разделена на несколько файлов:
- `default.nix` — основной модуль, programs.fish.enable, functions, bash auto-exec для Linux
- `abbrs.nix` — `programs.fish.shellAbbrs` (fish-only)
- `aliases.nix` — `home.shellAliases` (shared: fish/zsh/bash)
- `plugins.nix` — `programs.fish.plugins`

Плагины: autopair, sponge, puffer, plugin-git, grc (из nixpkgs), plugin-thefuck, fish-plugin-sudo, fish-utils-core, fish-utils, fish-finders, catppuccin (через fetchFromGitHub).

### Fish как login shell

Подробности в [shell-setup.md](shell-setup.md). Кратко:
- **macOS:** fish как login shell через `system.activationScripts` (dscl)
- **Linux:** bash как login shell + auto-exec fish из `programs.bash.initExtra`

### Shell интеграции через nix

| Инструмент | Модуль | fish | zsh | bash |
|---|---|---|---|---|
| mise | `programs.mise` (home-manager) | ✅ | ✅ | ✅ |
| atuin | `programs.atuin` (home-manager) | ✅ | ✅ | ✅ |
| starship | `programs.starship` (home-manager) | ✅ | ✅ | ✅ |
| zoxide | `programs.zoxide` (home-manager) | ✅ | ✅ | ✅ |
| fzf | `programs.fzf` (home-manager) | ✅ | ✅ | ✅ |
| homebrew | `homebrew` (nix-darwin) | через sessionPath | через set-environment | — |

## mise: shims vs activate

- **shims** (`~/.local/share/mise/shims` в sessionPath) — работают везде: скрипты, IDE, non-interactive. Шим сам определяет версию.
- **activate** — динамическое переключение при `cd`, поддержка `[env]`. Только interactive. Через `programs.mise.enableFishIntegration`.
- Совместимы: shims как fallback, activate перекрывает в interactive shell.

## Известные нюансы

### `__HM_SESS_VARS_SOURCED` inheritance

home-manager ставит guard `__HM_SESS_VARS_SOURCED` как `set -gx` (exported). Если терминальное приложение не перезапущено после rebuild, старые сессии передают эту переменную дочерним fish → `setup_hm_session_vars` скипается → PATH не устанавливается. Решение: полный перезапуск терминала (Cmd+Q) после `darwin-rebuild switch`.

### `/etc/paths.d/`

Не используется. `path_helper` переупорядочивает PATH, конфликтует с nix-darwin.

### `environment.d/`

Не существует на macOS (systemd-only).

### launchd (GUI apps)

`launchd.user.envVariables` — единственный способ дать PATH GUI приложениям. Не поддерживает $HOME — только абсолютные пути. Требует logout/login. Пока не настроен.

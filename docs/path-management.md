# PATH Management

## Текущая архитектура

PATH и env vars задаются в **трёх** местах из-за того что разные контексты (zsh, fish, GUI apps) читают окружение разными способами:

| Механизм | zsh interactive | zsh non-interactive | fish | GUI apps (launchd) |
|---|---|---|---|---|
| `environment.variables` (nix-darwin) | ✅ | ✅ | ❌ | ❌ |
| `home.sessionVariables` (home-manager) | ✅ (`.zshrc`) | ❌ | ✅ | ❌ |
| `launchd.user.envVariables` (nix-darwin) | ❌ | ❌ | ❌ | ✅ |

Чтобы переменные были доступны **везде**, они дублируются во всех трёх слоях. Для избежания ручного дублирования в `hosts/lasthaze-mbp/default.nix` определены shared bindings в `let` блоке:

```nix
let
  sharedEnv = {
    EDITOR = "code --wait";
    GOPATH = "${homeDir}/go";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";
    DOTFILES = "${homeDir}/.dotfiles";
    XDG_CONFIG_HOME = "${homeDir}/.config";
    # ... etc
  };
  sharedPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDir}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${homeDir}/.local/share/mise/shims"
    "${homeDir}/.local/share/pnpm"
    "${homeDir}/.bun/bin"
    "${homeDir}/go/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/bin"
    "/usr/local/bin"
    "/usr/bin" "/bin" "/usr/sbin" "/sbin"
  ];
in { ... }
```

### Слой 1: nix-darwin `environment.variables`

Вне home-manager блока. Попадает в `/nix/store/...-set-environment` → `/etc/zshenv`.
**Покрывает:** zsh (interactive и non-interactive, Cursor агенты, скрипты).

```nix
environment.variables = sharedEnv // {
  HOMEBREW_PREFIX = "/opt/homebrew";
  HOMEBREW_NO_ANALYTICS = "1";
  HOMEBREW_BUNDLE_FILE = "${homeDir}/.config/packages/Brewfile";
  HOMEBREW_BUNDLE_DUMP_NO_GO = "1";
  HOMEBREW_BUNDLE_DUMP_NO_NPM = "1";
  # ...
};
```

### Слой 2: home-manager `home.sessionPath` + `home.sessionVariables`

Внутри home-manager блока. Генерирует `hm-session-vars.fish` → sourced из `config.fish`. Также в `.zshrc`.
**Покрывает:** fish (полностью), zsh (только interactive через `.zshrc`).

```nix
home.sessionPath = sharedPath;
home.sessionVariables = sharedEnv;
```

### Слой 3: nix-darwin `launchd.user.envVariables` — для GUI apps

**Ключевой слой** для VSCode, Cursor, Warp и их extensions. macOS GUI приложения запускаются через **launchd**, который не читает shell configuration — только свой собственный environment. По умолчанию launchd PATH содержит лишь `/usr/bin:/bin:/usr/sbin:/sbin` — без brew, nix, mise.

nix-darwin создаёт `~/Library/LaunchAgents/org.nixos.user-environment.plist` который при старте user session выполняет `launchctl setenv` для каждой переменной.

```nix
launchd.user.envVariables = sharedEnv // {
  PATH = builtins.concatStringsSep ":" sharedPath;
};
```

**Почему это единственный правильный способ для GUI на macOS:**
- `environment.systemPath` — только для login shells через `path_helper`, GUI apps игнорируют
- `launchctl config user path` через `extraUserActivation` — сломан на macOS Sequoia
- `/etc/paths.d/` — только для login shells

**Что это даёт:**
- VSCode/Cursor/Warp terminal находят `fish`, `code`, `git`, `op` и т.д.
- Extensions (1Password CLI, Mise VSCode) видят свои бинарники
- Claude Code Bash tool получает полный PATH

**Ограничение:** launchd читает environment **только при старте user session**. После `darwin-rebuild switch` нужен **logout → login** чтобы GUI apps подхватили изменения. Альтернатива `launchctl reboot user/$UID` работает не всегда чисто.

### Слой 4: fish conf.d (минимум)

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

### Logout/login required for GUI apps

launchd читает environment только при старте user session. После изменений в `launchd.user.envVariables` нужен **logout → login** (или `launchctl reboot user/$UID`), иначе уже запущенные GUI apps будут с старым PATH.

### `/etc/paths.d/`

Не используется. `path_helper` переупорядочивает PATH, конфликтует с nix-darwin.

### `environment.d/`

Не существует на macOS (systemd-only).

### `$HOME` expansion в launchd

launchd **не поддерживает** переменные типа `$HOME`, `$USER`. Все пути в `sharedPath` раскрываются на этапе nix eval через `${homeDir}` (hardcoded `/Users/yoshintame`). Для single-user dotfiles это не проблема.

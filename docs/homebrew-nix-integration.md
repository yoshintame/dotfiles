# Homebrew + nix-darwin интеграция

## Решение: вариант 3 — shell integration only

Модуль nix-darwin `homebrew.*` — только для PATH/env/completions.
Пакеты — через Brewfile отдельно, `brew bundle` руками.

### Конфигурация

```nix
# hosts/lasthaze-mbp/default.nix

homebrew = {
  enable = true;
  enableFishIntegration = true;   # brew shellenv + completions в fish
  enableZshIntegration = true;    # brew shellenv в zsh (для Cursor агентов)
  global.brewfile = false;        # не перезаписывать HOMEBREW_BUNDLE_FILE
};

environment.variables.HOMEBREW_BUNDLE_FILE =
  "${flakeRoot}/os/macos/packages/Brewfile";
```

### Что это даёт

- **Fish** — `brew shellenv` + completions автоматом, без `01-brew.fish`
- **Zsh** (Cursor агенты) — `brew shellenv` через `/etc/zshenv`, brew в PATH
- **Brewfile** — отдельный файл, редактируется как обычно
- **`brew bundle dump`** — пишет в тот же Brewfile через `HOMEBREW_BUNDLE_FILE`
- **Brew wrapper** в fish — работает как раньше

### Что удаляется

`modules/fish/config/conf.d/01-brew.fish` — целиком. Модуль делает то же самое.

### Что остаётся в fish (если нужно)

Brew wrapper для multi-user setup и keg-only apps — если модуль не покрывает:

```fish
# Keg-only apps (если не в environment.systemPath)
for app in ruby curl sqlite
    fish_add_path "$HOMEBREW_PREFIX/opt/$app/bin"
end

# Multi-user brew wrapper
set -gx HOMEBREW_OWNER (stat -f "%Su" $HOMEBREW_PREFIX)
if test $HOMEBREW_OWNER != (whoami)
    function brew
        sudo -Hu $HOMEBREW_OWNER brew $argv
    end
end
```

Keg-only apps лучше вынести в `environment.systemPath` — тогда и это не нужно.

### nix-homebrew (опционально, на будущее)

Отдельный flake [zhaofengli/nix-homebrew](https://github.com/zhaofengli/nix-homebrew) — декларативная установка самого Homebrew.

```nix
# flake.nix inputs
nix-homebrew.url = "github:zhaofengli/nix-homebrew";

# host config
nix-homebrew = {
  enable = true;
  user = username;
  autoMigrate = true;
};
```

Не управляет пакетами — только установку brew + taps. Совместим с `homebrew.*` модулем.

### Отвергнутые варианты

**Вариант 1: парсить Brewfile в nix** — парсить Ruby DSL в nix нереально.

**Вариант 2: custom activation script** — `brew bundle` при `darwin-rebuild switch`.
Рабочий, но избыточен если не нужен auto-install при rebuild. Можно добавить позже:

```nix
system.activationScripts.brewBundle.text = ''
  if [ -f /opt/homebrew/bin/brew ]; then
    sudo --preserve-env=PATH --user=${username} --set-home \
      /opt/homebrew/bin/brew bundle \
      --file='${flakeRoot}/os/macos/packages/Brewfile' \
      --no-upgrade --no-lock
  fi
'';
```

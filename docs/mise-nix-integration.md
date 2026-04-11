# mise + home-manager интеграция

## Решение: shell integration + отдельный config

Модуль home-manager `programs.mise` — установка пакета + shell activate.
Config — через dotbot линк отдельно.

### Конфигурация

```nix
# modules/mise/default.nix

{ pkgs-unstable ? pkgs, ... }: {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableFishIntegration = true;   # mise activate fish | source
    enableZshIntegration = true;    # eval "$(mise activate zsh)" для Cursor
    # globalConfig не указан — config.toml не генерируется
  };

  # config.toml линкуется отдельно
  nixDotbot.links = {
    "~/.config/mise/config.toml" = "modules/mise/config/config.toml";
  };
}
```

### Что это даёт

- **Fish** — `mise activate fish | source` в `interactiveShellInit` автоматом
- **Zsh** (Cursor агенты) — `eval "$(mise activate zsh)"` в interactive zsh
- **config.toml** — отдельный файл, редактируется как обычно
- **Shims** — для non-interactive shells через `environment.systemPath` (отдельно в nix-darwin)

### Что удаляется

- `modules/fish/config/conf.d/mise.fish` — целиком. Модуль делает то же самое.
- `home.packages = [ pkgs-unstable.mise ]` — модуль ставит пакет сам.

### Что остаётся в fish (если нужно)

`MISE_ENV_FILE` — модуль не ставит. Добавить через `home.sessionVariables`:

```nix
home.sessionVariables = {
  MISE_ENV_FILE = ".env";
};
```

Или в nix-darwin `environment.variables` если нужно для всех shells.

### Shims в системном PATH (nix-darwin, отдельно)

Модуль не управляет shims. Для non-interactive shells (скрипты, IDE, Cursor агенты без interactive zsh):

```nix
# hosts/lasthaze-mbp/default.nix
environment.systemPath = [
  "$HOME/.local/share/mise/shims"
];
```

Shims и activate совместимы — activate перекрывает shims в interactive shell.

### Что делает модуль под капотом

| Опция | Генерирует |
|---|---|
| `enable` | ставит пакет в `home.packages` |
| `enableFishIntegration` | `mise activate fish \| source` в `programs.fish.interactiveShellInit` |
| `enableZshIntegration` | `eval "$(mise activate zsh)"` в `programs.zsh.initContent` |
| `globalConfig` | `~/.config/mise/config.toml` из nix attrset (не используем) |

### Shims vs activate

| | Shims (PATH) | Activate (hook) |
|---|---|---|
| Когда | non-interactive | interactive |
| Как | `~/.local/share/mise/shims` в `environment.systemPath` | `mise activate <shell>` через модуль |
| Плюс | работает везде (скрипты, IDE, агенты) | мгновенный cd-switch, `[env]` поддержка |
| Минус | overhead на каждый вызов, нет `[env]` | только interactive |

Оба совместимы — shims как fallback, activate перекрывает в interactive.

### Отвергнутые варианты

**Ручная установка + conf.d/mise.fish** — текущий подход. Работает, но:
- дублирование activate для каждого shell отдельно
- пакет mise в `home.packages` отдельно от интеграции
- нет zsh integration → Cursor агенты без mise

**globalConfig через nix** — рабочий, но config.toml удобнее редактировать напрямую. Модуль генерирует файл только если `globalConfig != {}`, конфликта с dotbot линком нет.

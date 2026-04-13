# mise + home-manager интеграция

## Текущая конфигурация

Модуль home-manager `programs.mise` — установка пакета + shell activate.
Config — через dotbot линк отдельно.

### `modules/mise/default.nix`

```nix
{pkgs-unstable ? pkgs, pkgs, ...}: {
  programs.mise = {
    enable = true;
    package = pkgs-unstable.mise;
    enableFishIntegration = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
  };

  nixDotbot.links = {
    "~/.config/mise/config.toml" = "modules/mise/config/config.toml";
    "~/.config/mise/tasks/dot.toml" = "dot.toml";
  };
}
```

### Что делает модуль

| Опция | Генерирует |
|---|---|
| `enable` | ставит пакет в `home.packages` |
| `enableFishIntegration` | `mise activate fish \| source` в `programs.fish.interactiveShellInit` |
| `enableZshIntegration` | `eval "$(mise activate zsh)"` в `programs.zsh.initContent` |
| `enableBashIntegration` | `eval "$(mise activate bash)"` в bash init |

`globalConfig` не используется — config.toml линкуется через dotbot.

### Shims в PATH

Модуль не управляет shims. Для non-interactive shells (скрипты, IDE, Cursor агенты):

```nix
home.sessionPath = [
  "${homeDir}/.local/share/mise/shims"
];
```

Shims и activate совместимы — activate перекрывает shims в interactive shell.

### Что удалено

- `modules/fish/config/conf.d/mise.fish` — модуль делает то же самое
- `modules/fish/config/conf.d/zz-env.fish` — повторный `mise activate` больше не нужен
- `pkgs-unstable.mise` из `modules/fish/default.nix` — модуль ставит пакет сам

### Shims vs activate

| | Shims (PATH) | Activate (hook) |
|---|---|---|
| Когда | non-interactive | interactive |
| Как | `~/.local/share/mise/shims` в sessionPath | `mise activate <shell>` через модуль |
| Плюс | работает везде | мгновенный cd-switch, `[env]` |
| Минус | overhead на каждый вызов, нет `[env]` | только interactive |

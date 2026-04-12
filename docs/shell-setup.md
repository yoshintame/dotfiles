# Shell Setup

## Проблема

Fish — не POSIX-совместимый. На Linux это ломает `/etc/profile` chain → теряется nix PATH при логине. На macOS `/etc/profile` не используется, поэтому fish как login shell безопасен.

Dotfiles должны работать на трёх типах хостов:
- macOS с nix-darwin (`lasthaze-mbp`)
- Standalone home-manager на Linux/WSL (`lasthaze-home`)
- NixOS (гипотетический, на будущее)

Нужно единое поведение (fish в терминале), но разная установка под каждую платформу.

## Решение

### macOS — fish как login shell

`programs.fish.enable = true` на system level nix-darwin:
- Ставит fish в `/run/current-system/sw/bin/fish`
- Добавляет в `/etc/shells`
- Включает vendor completions

`system.activationScripts.postActivation` идемпотентно меняет login shell через `dscl`:

```nix
system.activationScripts.postActivation.text = ''
  fishPath="/run/current-system/sw/bin/fish"
  currentShell=$(/usr/bin/dscl . -read /Users/${username} UserShell 2>/dev/null | awk '{print $2}')
  if [ "$currentShell" != "$fishPath" ]; then
    /usr/bin/dscl . -change /Users/${username} UserShell "$currentShell" "$fishPath"
  fi
'';
```

`darwin-rebuild switch` запускается через `sudo`, поэтому `dscl` работает без пароля. Проверка делает скрипт идемпотентным — если уже fish, ничего не делает.

`chsh` вручную не нужен. Bootstrap новой машины полностью декларативный.

**Почему `dscl` а не `chsh`:** `chsh` прокси над `dscl` с интерактивным prompt для пароля. `dscl` работает напрямую без prompt (раз есть root).

**Почему `users.users.<name>.shell = pkgs.fish` не используется:** nix-darwin применяет эту опцию **только** к юзерам в `users.knownUsers`, то есть к юзерам которых nix-darwin сам создал. Для существующих macOS юзеров (созданных System Settings при установке) опция тихо игнорируется. `activationScripts` обходит это ограничение.

### Linux — bash как login shell + auto-exec fish

На Linux fish как login shell **нельзя** — ломается `/etc/profile` и nix PATH. Вместо этого bash остаётся login shell, но в интерактивном режиме немедленно `exec`-ит в fish:

```nix
# modules/fish/default.nix
programs.bash = {
  enable = true;
  initExtra = lib.mkIf pkgs.stdenv.isLinux ''
    if [[ $(ps --no-header --pid=$PPID --format=comm) != "fish" && -z $BASH_EXECUTION_STRING ]]; then
      exec fish
    fi
  '';
};
```

`lib.mkIf pkgs.stdenv.isLinux` — включается только на Linux, на macOS код не выполняется.

Условия для exec:
- Родительский процесс **не fish** — защита от бесконечной рекурсии
- `$BASH_EXECUTION_STRING` пустой — значит не вызов вида `bash -c 'cmd'`, а интерактивная сессия

Результат:
- `/etc/profile` корректно исполняется через bash → nix PATH установлен
- Интерактивный терминал сразу попадает в fish
- Скрипты `#!/bin/bash` и `bash -c 'cmd'` продолжают работать в bash
- `chsh` не нужен

### Сводная таблица

| Платформа | Login shell | Interactive shell | Установка fish | Механизм смены shell |
|---|---|---|---|---|
| macOS (nix-darwin) | fish | fish | `programs.fish.enable` system level | `activationScripts` через `dscl` |
| NixOS | bash (POSIX) | fish | `programs.fish.enable` system level | auto-exec из `programs.bash.initExtra` |
| Ubuntu/WSL (standalone home-manager) | bash (apt) | fish | home-manager `programs.fish` + auto-exec | `programs.bash.initExtra` |

## Что такое login shell вообще

**Login shell** — процесс, запускаемый при аутентификации пользователя.

**Где хранится:**
- Linux: `/etc/passwd` (последнее поле)
- macOS: `UserShell` в Directory Services, читается через `dscl`

**Где используется:**
- TTY login (физическая консоль)
- SSH session (`ssh user@host`)
- Запуск терминального приложения (Terminal.app, Warp, iTerm2, VSCode terminal) — большинство читают login shell из user database
- `$SHELL` переменная в новых процессах

**Где НЕ используется:**
- cron, launchd, systemd — используют свой shell
- Скрипты с shebang (`#!/bin/bash`) — используют shell из shebang
- GUI приложения (Dock, Finder) — запускаются launchd, не login shell

**`/etc/shells`:**
Белый список разрешённых login shell. `chsh` проверяет что путь есть в этом файле. Защита от установки произвольного бинарника как shell.

## Что удалено

- `modules/fish/srcipts/setup.sh` — legacy dotbot скрипт с опечаткой в имени директории, вызовом несуществующей функции `setup` и ссылкой на несуществующий `../scripts/functions.sh`. Его функции (симлинк .fish файлов, `/etc/shells`, `chsh`) теперь покрыты nix.
- `brew "fish"` из Brewfile — fish ставится через nix.

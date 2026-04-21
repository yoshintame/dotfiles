# Global CLI wrappers via mise tasks

Pattern for creating global CLI commands backed by mise task runner, exposed as **real binaries** in nix-profile so they work from any shell, from scripts, from GUI apps (VSCode/Cursor), and from Claude Code agents.

## Почему бинарник, а не fish-function

Раньше обёртка была fish-функцией: `dot` / `rp` жили в `modules/fish/config/functions/*.fish`. Это работало только в fish. zsh, bash, Claude Code Bash tool (который запускает команды в zsh), cron, CI-скрипты — ни один из них не видел этих команд.

Правило: **любая пользовательская команда, которую можно вызвать из скрипта или агента, должна быть настоящим executable в PATH**. fish-functions допустимы только для inherently-shell вещей (cd, eval в текущий shell, интерактивные виджеты).

Подробнее: [path-management.md](path-management.md#executables-vs-shell-functions).

## Эволюция паттерна

1. **justfiles** — 3 файла на утилиту (justfile + fish function + completion), нет flags/choices.
2. **mise tasks + fish function** — usage/choices есть, но обёртка fish-only.
3. **mise tasks + `mkMiseCli` helper (текущий)** — TOML с тасками + одна строчка в nix = настоящий бинарник в PATH.

## `mkMiseCli` helper

Helper в [lib/mkMiseCli.nix](../lib/mkMiseCli.nix). Принимает имя, опциональные proxy-subcommands и specials, возвращает `pkgs.writeShellApplication` пакет.

### Сигнатура

```nix
mkMiseCli {
  name = "<name>";                   # команда и префикс тасков "<name>:*"
  proxied = [                        # опционально: subcommands, делегирующие в другой бинарник
    { sub = "link"; target = "doc"; help = "..."; }
  ];
  specials = [                       # опционально: raw-shell handlers
    { sub = "go"; help = "..."; run = ''echo "..." >&2; exit 2''; }
  ];
  runtimeInputs = [ ... ];           # опционально: дополнительные пакеты в PATH рантайма
}
```

### Что генерирует

Bash-скрипт с `set -euo pipefail`:

```sh
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  mise tasks ls | grep '^<name>:'
  # + help для proxied/specials
  exit 0
fi
case "$1" in
  <proxied-cases>   # exec <target> "$@"
  <special-cases>   # inline shell
  *) sub="$1"; shift; exec mise run "<name>:$sub" -- "$@" ;;
esac
```

Попадает в `/etc/profiles/per-user/<user>/bin/<name>` через `home.packages`.

## Как добавить новую утилиту

### 1. Создать tasks TOML

`modules/<module>/config/<name>.toml` — формат тот же, что раньше (`mise` usage spec с flags/choices). См. [официальные доки mise tasks](https://mise.jdx.dev/tasks/) и `dot.toml` / `rp.toml` как примеры.

### 2. Слинковать TOML в `~/.config/mise/tasks/`

В `modules/<module>/default.nix`:

```nix
nixDotbot.links = {
  "~/.config/mise/tasks/<name>.toml" = "modules/<module>/config/<name>.toml";
};
```

### 3. Подключить в `modules/mise/config/config.toml`

```toml
[task_config]
includes = ["tasks/<name>.toml"]
```

### 4. Сгенерировать бинарник через `mkMiseCli`

В том же `modules/<module>/default.nix`:

```nix
{ pkgs-unstable ? pkgs, pkgs, ... }: let
  mkMiseCli = import ../../lib/mkMiseCli.nix {
    inherit pkgs;
    mise = pkgs-unstable.mise;
  };
  cli = mkMiseCli { name = "<name>"; };
in {
  home.packages = [ cli ];
  nixDotbot.links = { ... };
}
```

### 5. (Опционально) fish completion

Если хочется tab-completion в fish — положить `modules/fish/config/completions/<name>.fish`:

```fish
complete -c <name> -f
complete -c <name> -n "test (count (commandline -opc)) -eq 1" \
    -a "(mise tasks ls 2>/dev/null | grep '^<name>:' | sed 's/^<name>://' | awk '{print \$1\"\t\"\$2\" \"\$3\" \"\$4\" \"\$5}')"
```

Файл подхватится через существующий dotbot-линк `~/.config/fish/` в `modules/fish/default.nix`.

### 6. Rebuild

```sh
dot rebuild
```

После `darwin-rebuild switch` бинарник в `/etc/profiles/.../bin/<name>`, виден отовсюду.

## Примеры

### `rp` — без спецкейсов

`modules/resticprofile/default.nix`:

```nix
home.packages = [ (mkMiseCli { name = "rp"; }) ];
```

Всё. Таски из `rp.toml` (`rp:backup`, `rp:save`, `rp:load`, …) становятся доступны как `rp backup`, `rp save`, `rp load` из любого shell.

### `dot` — с proxy и shell-bound спецкейсом

`modules/mise/default.nix`:

```nix
dotCli = mkMiseCli {
  name = "dot";
  proxied = [
    { sub = "link";   target = "doc"; help = "Link dotfiles via dotbot"; }
    { sub = "config"; target = "doc"; help = "Print dotbot config"; }
  ];
  specials = [{
    sub = "go";
    help = "cd $DOTFILES (shell-only, use fish function)";
    run = ''echo "dot go: shell-bound, run:  cd \"$DOTFILES\"" >&2; exit 2'';
  }];
};
```

`dot link` и `dot config` делегируют в `doc` (nix-dotbot). `dot <anything else>` → `mise run dot:<anything else>`. `dot go` — спецкейс (см. ниже).

## Inherently-shell команды: `dot go`

`cd` не может работать из child-процесса. Для подобного UX в интерактивном shell-e заводим **тонкий fish-wrapper**, который перехватывает только этот подкоманд-кейс и в остальном делегирует в бинарник:

```nix
# modules/mise/default.nix
programs.fish.functions.dot = {
  description = "Dotfiles management (fish UX wrapper over `dot` binary)";
  body = ''
    if test (count $argv) -gt 0; and test "$argv[1]" = "go"
        cd $DOTFILES
        return
    end
    command dot $argv
  '';
};
```

В fish эта функция перекрывает бинарник. В zsh/bash — работает сам бинарник, `dot go` выводит хинт и exits. Агенты/скрипты всё равно не должны вызывать `dot go` — их интересует `dot rebuild`, `dot link` и т.п.

## Альтернативы, которые рассматривали

- **`mise generate task-stubs`** — нативный mise-механизм, генерирует шимы `bin/<name>:<task>` (по одному на каждую таску). Не подходит: ломает UX `<name> <subcmd>` → заменяет на `<name>:<subcmd>`, нет общей help-команды-диспетчера.
- **Shell-скрипт без mise** — переписать всю логику инлайн через `writeShellApplication`. Регресс: теряем usage-парсинг (`choices`, `flag`, `default`, `env`) из mise.
- **Оставить fish-function, переключить Claude Code Bash на fish** — fish не POSIX, CI/hooks/скрипты ломаются.

## Gotchas

- **`--` разделитель**: `mise run <task> -- "$@"` — `--` нужен чтобы args прошли в таск, а не в mise. Helper делает это автоматически.
- **Пустой `$@`**: `exec mise run "rp:save" -- ` с пустым args — валидно, mise не падает.
- **writeShellApplication + shellcheck**: скрипт прогоняется через shellcheck при сборке. Helper уже безопасен (проверка `$#` перед доступом к `$1`). При добавлении `specials.run` следить за nounset.
- **`doc` в PATH**: `doc` (nix-dotbot) установлен в nix-profile — виден в рантайме `writeShellApplication`, который prepend'ит runtimeInputs к существующему PATH, а не заменяет его.
- **Included task file format**: в `.toml` — `["name:cmd"]`, не `[tasks."name:cmd"]`.
- **TOML multiline strings**: `'''` для строк с кавычками, чтобы не экранировать.

## Миграция со старого паттерна

Если есть утилита, сделанная по старой схеме (fish function + completion):

1. Удалить `modules/fish/config/functions/<name>.fish`.
2. Добавить `mkMiseCli { name = "<name>"; }` в `home.packages` соответствующего модуля.
3. Completion (если был) — оставить как есть, он работает и для бинарника.
4. Если была shell-bound логика (cd, eval) — перенести в `programs.fish.functions.<name>` как тонкий wrapper над бинарником.
5. `dot rebuild` → logout/login (для launchd) → проверить: `which <name>` в **zsh** должен находить `/etc/profiles/per-user/.../bin/<name>`.

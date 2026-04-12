# Trash concept

Как устроено безопасное удаление файлов в этом dotfiles-репозитории, почему
сделано именно так, какие есть альтернативы и что сознательно не делается.

## Зачем вообще trash вместо rm

`rm` необратим. Один неверный `rm -rf` — и нужен бэкап. Trash-утилита
перехватывает удаление, перемещает файл в корзину и даёт восстановить. Цена —
место на диске и небольшая задержка на периодический prune; выгода — один
уровень защиты между человеческой ошибкой и потерей данных.

## Текущая реализация

### Инструмент: gtrash

- [umlx5h/gtrash](https://github.com/umlx5h/gtrash), Go, FreeDesktop-спецификация.
- Ставится через Homebrew tap: [hosts/lasthaze-mbp/packages/Brewfile](../hosts/lasthaze-mbp/packages/Brewfile)
  (`brew "umlx5h/tap/gtrash"`) и декларируется в
  [modules/fish/default.nix](../modules/fish/default.nix) и
  [modules/yazi/default.nix](../modules/yazi/default.nix).
- На macOS gtrash **не использует `~/.Trash`** (Finder-корзину), а кладёт файлы
  в `~/.local/share/Trash` по FreeDesktop. Следствие: файлы не видны в Finder,
  не работает ⌘⌫ "Put Back", Dock не показывает «наполненную» корзину. Это
  сознательный trade-off ради TUI-restore, group-restore и prune.

### Алиасы в fish

[modules/fish/aliases.nix](../modules/fish/aliases.nix),
[modules/fish/config/aliases.fish](../modules/fish/config/aliases.fish):

| Алиас | Команда | Назначение |
|---|---|---|
| `rm`  | `gtrash put`                       | удаление = «в корзину» |
| `rm!` | `/bin/rm`                          | настоящее удаление, escape-hatch |
| `trs` | `gtrash summary`                   | сводка по корзине |
| `trf` | `gtrash find`                      | поиск в корзине |
| `trr` | `gtrash restore`                   | интерактивный restore (TUI) |
| `trl` | `gtrash find -n 1 --restore -f`    | restore последнего файла |
| `trg` | `gtrash restore-group`             | restore группы (одна операция удаления) |

`gtrash put` по умолчанию **молчит**. Флаг `-v` (verbose) печатает
`trashed: <file>` на каждый файл — его сознательно нет в алиасе, иначе вызовы
rm из fish-функций и плагинов засоряют stdout. Флаг `-r` у `gtrash put` —
no-op без `--rm-mode`, рекурсивное удаление директорий работает по умолчанию.

### Yazi-интеграция

[modules/yazi/config/keymap.toml](../modules/yazi/config/keymap.toml):

- `dd` — trash выделенного (`gtrash put`)
- `du` — restore последнего (`gtrash find -n 1 --restore -f`)
- `u`  — интерактивный restore (`gtrash r -f`)
- `gt` — переход в `$TRASH`

### Переменная TRASH

[hosts/lasthaze-mbp/default.nix](../hosts/lasthaze-mbp/default.nix) выставляет
`TRASH=~/.Trash` — это путь **нативной macOS-корзины**, не gtrash. Используется
функцией `emptytrash` из
[modules/fish/config/functions/empty-trash.fish](../modules/fish/config/functions/empty-trash.fish),
которая чистит `~/.Trash` и `/Volumes/*/.Trashes`. То есть `emptytrash` **не
затрагивает корзину gtrash** — её надо чистить через `gtrash prune` или
автопрюн в `~/.config/gtrash/config.yaml`.

Это расхождение — известная шероховатость: концептуально `TRASH` должна была
бы указывать на то же место, куда складывает gtrash. Оставлено как есть,
потому что Finder-корзина тоже существует (например, drag-to-trash), и
`emptytrash` относится именно к ней.

## Почему алиас на `rm` — это нормально (именно в fish)

Классическая претензия ([OSTechNix](https://ostechnix.com/aliasing-rm-command-is-a-bad-practice/),
[sindresorhus/guides](https://github.com/sindresorhus/guides/blob/main/how-not-to-rm-yourself.md))
— «алиас rm ломает скрипты». Это справедливо для bash/zsh, где алиасы могут
наследоваться в нестандартных конфигурациях, и для PATH-шимов, которые
перехватывают всё.

В fish ситуация другая:

- Алиасы в fish — это функции текущего интерактивного shell. Они **не
  экспортируются** в дочерние процессы. Любой bash-скрипт, Makefile, hook,
  утилита из `$PATH` — всё это вызывает настоящий `/bin/rm`.
- Сломаться могут только fish-функции и fish-плагины, которые прямо внутри
  fish-контекста пишут слово `rm`. Таких мало, и видны они сразу (выводом).
- Значит алиас даёт защиту интерактивного ввода, не ломая автоматизацию.

Escape-hatch `rm!` → `/bin/rm` нужен для случаев, когда реально надо удалить
безвозвратно: освободить место на диске, снести большой мусорный каталог,
и т.п. Используется как `rm! -rf path`.

## Политика бэкапа корзины

[modules/resticprofile/config/profiles.yaml](../modules/resticprofile/config/profiles.yaml).

Корзина в бэкап **не включается**:

- Профиль `home` бэкапит явный список подкаталогов `$HOME`; ни `.Trash`, ни
  `.local/share/Trash` там не перечислены.
- В `base.backup.exclude` явно добавлены `**/.Trash/**` и
  `**/.local/share/Trash/**` как страховка на случай будущих правок `source`.

Причины не бэкапить:

1. Корзина сама по себе — safety net; бэкап safety net раздувает репозиторий
   restic без пропорциональной выгоды.
2. Файлы в корзине эфемерны. `forget`/`prune` будет бесконечно крутить
   поколения одного и того же «мусора».
3. Если файл действительно ценен — он восстанавливается из gtrash TUI
   мгновенно, до следующего автопрюна. Бэкап включается позже, это второй
   уровень защиты для файлов, которые уже **не** в корзине.

Практическая мера: включить `trash.auto_prune` в `~/.config/gtrash/config.yaml`
(по размеру или по дате), чтобы корзина не росла неконтролируемо.

## Альтернативы, которые рассматривались

Данные из [gtrash/doc/alternatives.md](https://github.com/umlx5h/gtrash/blob/main/doc/alternatives.md)
и собственного поиска.

| Инструмент | Язык | Подход | Статус для macOS |
|---|---|---|---|
| **gtrash** (umlx5h) | Go | FreeDesktop, TUI restore, group, auto-prune, summary | выбран |
| **trash-cli** (andreafrancia) | Python | FreeDesktop | медленный старт Python, нет TUI |
| **trashy** | Rust | FreeDesktop | фич меньше, чем у gtrash |
| **trash-d** | D | `rm`-совместимый drop-in | минимум фич |
| **nivekuil/rip** | Rust | своя «graveyard», не FreeDesktop | не поддерживается с 2020 |
| **MilesCranmer/rip2** | Rust | форк rip, актуален | не FreeDesktop, другая парадигма |
| **macos-trash** / **sindresorhus/trash** | Swift/JS | NSFileManager → настоящая `~/.Trash` с Finder Put Back | нативно для macOS |

### Почему не macos-trash

Главный плюс `macos-trash` — нативная интеграция с Finder: файлы попадают в
`~/.Trash`, видны в Dock, работает «Put Back». Главный минус — всё, кроме
«перекинь и забудь», приходится делать руками в Finder: нет TUI, нет
группового restore, нет prune, нет быстрого поиска по корзине. Для workflow,
где rm-как-trash используется часто, этого критически не хватает.

Теоретически можно собрать гибрид: gtrash для CLI + Finder drag-to-trash для
GUI, и функция `emptytrash` чистит оба места. Текущее состояние близко к
этому: gtrash хранит в `~/.local/share/Trash`, Finder — в `~/.Trash`, а
`emptytrash` чистит только `~/.Trash`. Для gtrash-части нужен отдельный prune.

### Почему не rip/rip2

Нет FreeDesktop-совместимости. Корзина приватная к утилите, совместимость с
другими инструментами (yazi, ручной просмотр) теряется. gtrash выигрывает
именно совместимостью.

## Что осознанно не сделано

### Глобальный PATH-шим для rm

Идея: положить скрипт `rm` в `$PATH` раньше `/bin/rm`, чтобы **все** вызовы
rm — включая bash-скрипты, git-hooks, CI, пакетные менеджеры — шли через
gtrash.

Плюс: единая политика, никаких «забытых» путей удаления.

Минусы, которые удерживают от этого шага:

1. **Пакетные менеджеры.** `brew`, `npm`, `cargo`, `pip` и прочие постоянно
   делают `rm -rf` по временным и кеш-каталогам в рамках install/uninstall.
   Каждый такой вызов превращается в «переложить в корзину». Корзина пухнет
   гигабайтами за неделю, prune не успевает.
2. **Семантика освобождения места.** Скрипты, которые явно чистят место
   через `rm`, перестанут его освобождать. Это неочевидный и отложенный
   баг — диск заполнится через неделю-другую.
3. **Флаговая совместимость.** `gtrash put --rm-mode` покрывает основные
   флаги GNU `rm` (`-r`, `-R`, `-d`, `-f`, `-i`), но не все редкие
   (`--preserve-root`, `--one-file-system`, `--no-preserve-root`). Скрипт,
   который полагается на точное поведение `rm`, может упасть или, хуже,
   сработать не так, как ожидается.
4. **CI и Nix-сборки.** Если шим попадёт в PATH сборки пакета, результат
   непредсказуем. Nix-окружения рассчитывают на stock `rm`.

Если когда-нибудь делать шим, то не глобально, а точечно: только для
интерактивного PATH пользователя, с жёстким whitelist по TTY/родительскому
процессу, и с исключениями для известных потребителей. Это отдельная
нетривиальная задача.

## Быстрая справка

```fish
rm file           # → gtrash put file (в корзину)
rm -rf dir        # → gtrash put dir  (в корзину, -rf проигнорированы мягко)
rm! -rf dir       # → /bin/rm -rf dir (навсегда)
trs               # сводка корзины
trr               # интерактивный restore
trl               # restore последнего
gtrash prune      # почистить по политике
emptytrash        # очистить Finder-корзину (не gtrash!)
```

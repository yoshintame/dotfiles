# Homebrew + nix-darwin интеграция

## Текущая конфигурация

Модуль nix-darwin `homebrew.*` управляет brew (установка/удаление через `onActivation`), а Brewfile хранится во внешнем файле и подключается через `extraConfig = builtins.readFile`. Дамп Brewfile делает кастомный fish-врапер `brew`.

### `hosts/lasthaze-mbp/default.nix`

```nix
homebrew = {
  enable = true;
  onActivation = {
    cleanup = "uninstall";
    autoUpdate = false;
    upgrade = false;
  };
  global.brewfile = false;
  extraConfig = builtins.readFile ./packages/Brewfile;
};

environment.variables = sharedEnv // {
  HOMEBREW_PREFIX = "/opt/homebrew";
  HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
  HOMEBREW_REPOSITORY = "/opt/homebrew";
  HOMEBREW_NO_ANALYTICS = "1";
  HOMEBREW_NO_ENV_HINTS = "1";
  HOMEBREW_BUNDLE_FILE = "${homeDir}/.config/packages/Brewfile";
  HOMEBREW_BUNDLE_DUMP_NO_GO = "1";
  HOMEBREW_BUNDLE_DUMP_NO_NPM = "1";
};
```

### Как это работает

- **`extraConfig = builtins.readFile`** — содержимое Brewfile попадает в nix-generated Brewfile, который nix-darwin использует при `onActivation`. Сам файл остаётся во внешнем месте (`hosts/lasthaze-mbp/packages/Brewfile`), и к нему имеет прямой доступ wrapper `brew`.
- **`global.brewfile = false`** — nix не перезаписывает `HOMEBREW_BUNDLE_FILE`. Мы сами указываем путь через `environment.variables`, чтобы wrapper и `darwin-rebuild` оперировали одним и тем же файлом.
- **`onActivation.cleanup = "uninstall"`** — при `darwin-rebuild switch` brew автоматически удалит формулы/каски, которых больше нет в Brewfile. Это закрывает дрейф состояния.
- **`HOMEBREW_BUNDLE_DUMP_NO_GO=1`** — `brew bundle dump --go` ошибочно пытается дампить бинарники из `$GOPATH/bin` (например, `go`, `gofmt`) как `go "cmd/go"`. Флаг полностью отключает Go-секцию при дампе.
- **`HOMEBREW_BUNDLE_DUMP_NO_NPM=1`** — аналогично для глобальных npm-пакетов: ими управляет mise/bun, а не brew.

### PATH

`/opt/homebrew/bin` и `/opt/homebrew/sbin` добавлены в `home.sessionPath`. Через это работает fish (через hm-session-vars). Для zsh nix-darwin сам прописывает их в `set-environment`.

### `01-brew.fish`

В fish осталось только то, что не делает nix:

```fish
if test -d "$HOMEBREW_PREFIX/share/fish/completions"
    set --append fish_complete_path "$HOMEBREW_PREFIX/share/fish/completions"
end

set -q MANPATH || set -gx MANPATH ''
set -q HOMEBREW_KEG_ONLY_APPS || set -U HOMEBREW_KEG_ONLY_APPS ruby curl sqlite
for app in $HOMEBREW_KEG_ONLY_APPS
    if test -d "$HOMEBREW_PREFIX/opt/$app/share/man"
        set MANPATH "$HOMEBREW_PREFIX/opt/$app/share/man" $MANPATH
    end
end
```

### Brew wrapper

Файл: [modules/fish/config/functions/brew.fish](../modules/fish/config/functions/brew.fish)

Обёртка над `brew` со следующим поведением:

- `brew install` (без аргументов) → запускает `brew bundle install --cleanup` по `HOMEBREW_BUNDLE_FILE`. Перед этим чистит `*.incomplete` лок-файлы из downloads-кеша и форсит `HOMEBREW_DOWNLOAD_CONCURRENCY=1`, чтобы избежать гонок при параллельных скачиваниях.
- `brew install <pkg>` → ставит пакет, потом `brew bundle dump --force`.
- `brew remove <pkg>` → удаляет, потом `brew bundle dump --force`.
- `brew dump` → ручной форс-дамп.
- `brew list -o` / `brew list -D` — кастомные удобные форматы.

`HOMEBREW_BUNDLE_DUMP_NO_GO=1` и `HOMEBREW_BUNDLE_DUMP_NO_NPM=1` (см. выше) гарантируют, что дамп не пишет Go- и npm-пакеты — ими управляет mise/bun, а не brew. Никаких пост-фильтров и append-костылей в wrapper не нужно.

> ⚠️ Дамп происходит только через wrapper. При `darwin-rebuild switch` `onActivation` лишь применяет Brewfile, но не пишет в него.

### Что НЕ должно попадать в Brewfile

Граница ответственности с другими менеджерами:

- **Языковые рантаймы** (`node`, `go`, `python@3.12`, `uv`, `bun`) — управляются [mise](mise-nix-integration.md). В Brewfile их быть не должно. Если попадают как транзитивные deps других формул (`ffmpeg`, `imagemagick` тащат python; JS-инструменты тащат node), brew ставит их как auto-deps, и `brew leaves` / `brew bundle dump` их не показывают.
- **Python-инструменты** (`yamllint`, `yt-dlp`, `ansible`, `poetry`, `keymap-drawer`, `cc-conversation-search`, `claude-conversation-extractor`) — через `uv tool install`, в Brewfile записаны как `uv "name"`. brew bundle понимает `uv` syntax и сам вызывает `uv tool install`.
- **Глобальные npm/bun-пакеты** — через `bun install -g` (см. [bun-scripts.md](bun-scripts.md) и [bun-global-packages-issue.md](bun-global-packages-issue.md)). `HOMEBREW_BUNDLE_DUMP_NO_NPM=1` гарантирует что они не утекут в Brewfile.
- **Go-бинарники** — через `go install`. `HOMEBREW_BUNDLE_DUMP_NO_GO=1` исключает их из дампа.

#### Почему это важно

`brew bundle cleanup` строит topological sort из формул в Brewfile и их `depends_on`-метаданных. Если в Brewfile лежит формула которая объявляет `depends_on "python@3.12"` (например, `yamllint` или `yt-dlp`), tsort требует чтобы `python@3.12` тоже был в Brewfile — иначе крашится с `key not found: "python@3.12"`. Перенос Python-инструментов в `uv "name"` решает это: brew-формула больше не объявляет python как явную зависимость, и cleanup проходит чисто. Аналогично с node-зависимыми CLI (`aicommit2` и т.п.) — их не должно быть в Brewfile вообще, либо их нужно ставить через bun/mise.

### Отвергнутые варианты

**Парсить Brewfile в nix** — Brewfile это Ruby DSL, в nix распарсить нельзя.

**Custom activation script** — рабочий вариант, но штатный модуль `homebrew.*` делает то же самое через `extraConfig` чище.

# Архитектура Dotfiles

## Философия

Этот репозиторий использует Nix нетипичным образом. Вместо классического подхода NixOS/home-manager, где Nix декларативно управляет всем через Nix store, здесь Nix выступает **оркестратором конфигурации** с чётким разделением на три слоя:

1. **Nix-слой** — декларативная установка пакетов и сборка конфигурации
2. **nix-dotbot-слой** — живые симлинки из репозитория прямо в систему
3. **sops-templates-слой** — рендеринг конфигов с подстановкой секретов при активации

Такой гибридный подход решает фундаментальное противоречие: инструменты вроде VS Code, Hammerspoon или Karabiner постоянно модифицируют собственные конфиги, и чисто декларативный Nix-подход либо теряет эти изменения, либо требует постоянных ребилдов. Благодаря симлинкам конфигов напрямую из репозитория, любое изменение — сделанное инструментом или вручную — моментально вступает в силу И отражается как git diff, так что ничего не теряется.

### Когда использовать какой слой

| Слой                            | Когда использовать                                                                 | Пример                                   |
| ---------------------------------| ------------------------------------------------------------------------------------| ------------------------------------------|
| **Nix (nix store)**             | Установка пакетов, включение программ, системные настройки, которые меняются редко | `home.packages = [pkgs.atuin]`           |
| **nix-dotbot (живые симлинки)** | Конфиг-файлы, которые часто меняются или модифицируются самими инструментами       | `~/.config/atuin → modules/atuin/config` |
| **sops-templates (секреты)**    | Конфиг-файлы, в которые нужно подставить секретные значения                        | resticprofile профили с API-ключами      |

## Структура репозитория

```
.dotfiles/
├── flake.nix              # Входная точка — inputs, хосты, общие модули
├── flake.lock             # Залоченные версии зависимостей
├── .sops.yaml             # Правила шифрования SOPS (age-ключ)
├── dot.toml               # Mise tasks для управления dotfiles (rebuild, proxy-bindings, bootstrap)
│
├── hosts/                 # Конфигурации конкретных машин
│   ├── lasthaze-mbp/      # macOS ноутбук (aarch64-darwin)
│   │   ├── default.nix    #   импорт модулей, nixDotbot, sopsTemplates, session vars
│   │   └── file-associations/  # duti конфигурация (macOS file type associations)
│   └── lasthaze-home/     # Linux сервер (x86_64-linux)
│       └── default.nix    #   облегчённый набор модулей, тот же паттерн
│
├── modules/               # Самодостаточные модули инструментов (~28 модулей)
│   ├── atuin/             # Пример: простой модуль
│   │   ├── default.nix    #   пакет + dotbot-линк
│   │   └── config/        #   конфиг-файлы (симлинкуются живьём)
│   ├── fish/              # Пример: сложный модуль
│   │   ├── default.nix    #   пакеты + glob-линки
│   │   └── config/        #   conf.d/ (15), functions/ (26), completions/
│   ├── resticprofile/     # Пример: модуль с секретами
│   │   ├── default.nix    #   dotbot-линки + sopsTemplates.render
│   │   ├── config/        #   *.tmpl.yaml шаблоны + rp.toml (mise tasks)
│   │   └── secrets.yaml   #   SOPS-зашифрованные секреты
│   ├── karabiner/         # Конфиг — отдельный git submodule (TS-проект с билдом)
│   ├── vscode/            # Поддержка VS Code и Cursor, тема — git submodule
│   ├── proxy-bindings/    # YAML-реестр proxy-шорткатов + nix-модуль
│   ├── sops-templates/    # Кастомный home-manager модуль (инфраструктура, не инструмент)
│   │   ├── options.nix    #   определения опций
│   │   └── module.nix     #   activation-скрипт (sops exec-env + envsubst)
│   └── ...                # aerospace, bat, btop, claude, ghostty, git, gitui,
│                          # hammerspoon, iina, kitty, lazygit, mise, nvim, starship,
│                          # tmux, warp, wezterm, zoxide
│
├── packages/              # Внутренние CLI-утилиты
│   └── proxy-bindings/    # Bun CLI: генерация Lua/TS из proxy-bindings.yaml
│
├── os/                    # OS-специфичные конфигурации
│   ├── macos/
│   │   ├── packages/
│   │   │   ├── Brewfile       # Homebrew-пакеты (автоподдерживается brew wrapper'ом)
│   │   │   └── package.json   # Глобальные pnpm-пакеты
│   │   ├── config/
│   │   │   └── defaults/      # macOS system defaults (yml, пока не интегрированы)
│   │   └── scripts/           # Скрипты бутстрапа и синхронизации
│   └── windows/               # Cloud-init конфигурация
│
├── docs/                  # Документация
├── archive/               # Неиспользуемые модули (zsh, yabai, neofetch, etc.)
│
│  # Git submodules:
│  #   dotbot — anishathalye/dotbot
│  #   modules/karabiner/config — Yoshintame/karabiner-config (TS-проект)
│  #   modules/vscode/theme/true-vibrant-vscode-theme — кастомная тема
```

## Входная точка: flake.nix

Flake определяет все внешние зависимости и две конфигурации хостов:

**Inputs:**
- `nixpkgs` (25.05) / `nixpkgs-unstable` / `nixpkgs-darwin` (25.05) — наборы пакетов
- `nix-darwin` (25.05) — управление macOS-системой (uses `nixpkgs-darwin`)
- `home-manager` (25.05) — управление пользовательским окружением и пакетами (follows `nixpkgs`)
- `nix-dotbot` — кастомный менеджер симлинков (форк: `yoshintame/nix-dotbot`)

**Outputs:**
- `darwinConfigurations.lasthaze-mbp` — полная macOS-конфигурация через nix-darwin + home-manager
- `homeConfigurations.lasthaze-server` — минимальная Linux-конфигурация только через home-manager

**Специальные аргументы для модулей** (через `extraSpecialArgs`):
- `flakeRoot` — абсолютный путь к корню репозитория
- `pkgs-unstable` — пакеты из nixpkgs-unstable (для свежих версий, например mise)

Обе конфигурации загружают `nix-dotbot` и `sops-templates` как общие home-manager модули, затем импортируют хост-специфичную конфигурацию, которая в свою очередь импортирует модули инструментов.

```
flake.nix → hosts/lasthaze-mbp/default.nix → modules/*/default.nix
                                            ↳ nixDotbot config
                                            ↳ sopsTemplates config
```

## Хосты

Файлы хостов решают две задачи:
1. **Импорт модулей** — список `../../modules/*` импортов определяет, какие инструменты настроены на данной машине
2. **Настройка инфраструктуры** — дефолты nixDotbot, пути sopsTemplates, пользовательские настройки

macOS хост (`lasthaze-mbp`): ~24 модуля, включая GUI-инструменты (VS Code, Hammerspoon, Aerospace, Karabiner и т.д.) + file-associations (duti)
Linux сервер (`lasthaze-home`): ~12 модулей, только CLI (git, fish, tmux, neovim и т.д.)

Добавление инструмента на хост — это одна строка: `../../modules/toolname`.

## Модули

Модули — это **самодостаточные конфигурационные блоки** для отдельных инструментов. Это НЕ Nix-модули в традиционном понимании — они не определяют options и не имеют enable-флагов. Это независимые блоки, которые декларируют:

- Какие пакеты установить (`home.packages`)
- Какие конфиг-файлы симлинкнуть (`nixDotbot.links`)
- Какие шаблоны с секретами отрендерить (`sopsTemplates.render`)

### Паттерны модулей

**Простой модуль** (большинство модулей следует этому паттерну):
```nix
# modules/atuin/default.nix
{pkgs, ...}: {
  home.packages = [ pkgs.atuin ];
  nixDotbot.links = {
    "~/.config/atuin" = "modules/atuin/config";
  };
}
```

**Модуль с glob-линками** (для инструментов с множеством конфиг-файлов):
```nix
# modules/fish/default.nix
{pkgs, ...}: {
  programs.fish.enable = true;
  home.packages = with pkgs; [ grc eza bat fd ripgrep fzf ];
  nixDotbot.links = {
    "~/.config/fish/" = {
      path = "modules/fish/config/**";
      glob = true;
    };
  };
}
```

**Модуль с секретами** (для конфигов, требующих секретных значений):
```nix
# modules/resticprofile/default.nix
{pkgs, ...}: {
  nixDotbot.links = {
    "~/.config/resticprofile/logrotate.conf" = "modules/resticprofile/config/logrotate.conf";
  };
  sopsTemplates.render = {
    "~/.config/resticprofile/profiles.yaml" = {
      template = "modules/resticprofile/config/profiles.tmpl.yaml";
      secretsFile = "modules/resticprofile/secrets.yaml";
      variables = ["HC_DEVELOPMENT_BACKUP_UUID" "HC_HOME_BACKUP_UUID"];
    };
  };
}
```

### Структура директории модуля

```
modules/<tool>/
├── default.nix          # Nix-конфигурация (обязательно)
├── config/              # Конфиг-файлы, симлинкуемые через nix-dotbot
│   ├── config.toml      # Основной конфиг
│   └── ...
├── scripts/             # Вспомогательные скрипты (опционально)
├── templates/           # Исходники для sops-templates (опционально, планируется)
├── bin/                 # Исполняемые скрипты, линкуемые в ~/.local/bin (опционально)
└── secrets.yaml         # SOPS-зашифрованные секреты (опционально)
```

### Принципы дизайна модулей

- **Самодостаточность**: модуль должен содержать всё необходимое для инструмента — пакеты, конфиги, скрипты, секреты
- **Кроссплатформенность**: использовать `pkgs.*` для пакетов (работает и на macOS, и на Linux), избегать захардкоженных путей
- **Композируемость**: импорт модуля должен «просто работать» без дополнительной настройки в файле хоста
- **Живые конфиги**: конфиг-файлы симлинкуются, а не копируются — изменения работают в обе стороны

## nix-dotbot: слой живых симлинков

[nix-dotbot](https://github.com/yoshintame/nix-dotbot) — кастомный home-manager модуль, который генерирует конфигурацию dotbot и запускает её во время `home-manager switch`.

**Что он делает:** создаёт симлинки из `~/.config/*` (и других мест) напрямую на файлы внутри этого репозитория. В отличие от встроенного управления файлами home-manager, которое копирует файлы в Nix store, nix-dotbot создаёт **живые ссылки** — правки в репозитории моментально влияют на инструменты, а изменения, внесённые инструментами, отражаются как git diff.

**Конфигурация в файлах хостов:**
```nix
nixDotbot = {
  enable = true;
  dotfilesDir = flakeRoot;          # корень репозитория
  defaults.link = {
    relink = true;                   # обновлять существующие ссылки
    create = true;                   # создавать родительские директории
    force = true;                    # перезаписывать не-ссылки
  };
  clean = ["~/.dotfiles" "~/.config"];  # чистить битые ссылки
};
```

**Использование в модулях:**
```nix
nixDotbot.links = {
  "<назначение>" = "<источник относительно dotfilesDir>";
  # или с опциями:
  "<назначение>" = { path = "<glob-паттерн>"; glob = true; };
};
```

Все пути ссылок указываются относительно `dotfilesDir` (корня репозитория).

## sops-templates: слой секретов

Кастомный NixOS/home-manager модуль (`modules/sops-templates/`), который связывает зашифрованные секреты с конфиг-файлами, которым они нужны.

**Как это работает:**
1. Секреты зашифрованы с помощью [age](https://age-encryption.org/) через SOPS и хранятся в файлах `secrets.yaml`
2. Файлы шаблонов содержат плейсхолдеры `${VAR_NAME}`
3. При `home-manager switch` SOPS расшифровывает секреты, а `envsubst` подставляет их в шаблоны и записывает в конечные файлы
4. Отрендеренные файлы получают `chmod 600` для безопасности

**Поток данных:**
```
secrets.yaml (зашифрован) ──┐
                             ├──► sops exec-env + envsubst ──► ~/.config/tool/config.yaml
template.tmpl.yaml ─────────┘
```

**Конфигурация:**
```nix
sopsTemplates = {
  dotfilesDir = flakeRoot;
  render = {
    "<путь назначения>" = {
      template = "<путь к шаблону относительно dotfilesDir>";
      secretsFile = "<путь к зашифрованным секретам>";  # опционально, по умолчанию secrets/secrets.yaml
      variables = ["VAR1" "VAR2"];                       # опционально, ограничивает подставляемые переменные
    };
  };
};
```

Приватный age-ключ ожидается по пути `~/.config/sops/age/keys.txt`.

## Управление пакетами

Управление пакетами использует намеренно гибридный подход, отвергая как чистую Nix-декларативность, так и чисто интерактивные воркфлоу:

### Nix-пакеты (`home.packages`)

Используются для **базовых CLI-инструментов**, обеспечивающих кроссплатформенность модулей. Когда модулю нужен бинарник, он декларирует его в Nix, чтобы это работало и на macOS, и на Linux.

```nix
home.packages = [ pkgs.atuin ];
```

### Homebrew (Brewfile)

Используется для **macOS GUI-приложений (casks) и инструментов, которые плохо работают через Nix на macOS**. Brewfile в `os/macos/packages/Brewfile` автоматически поддерживается кастомной `brew`-обёрткой для fish.

Обёртка (`modules/fish/config/functions/brew.fish`) перехватывает brew-команды:
- `brew install <pkg>` → устанавливает, затем автоматически запускает `brew bundle dump` для обновления Brewfile
- `brew remove <pkg>` → удаляет, затем обновляет Brewfile
- `brew install` (без аргументов) → запускает `brew bundle install` из Brewfile

Это даёт опыт, похожий на package.json: интерактивные команды install/remove автоматически обновляют декларативный файл, который отслеживается в git.

### Глобальные npm/pnpm пакеты

Управляются через `os/macos/packages/package.json`, который симлинкуется в глобальное расположение pnpm. Та же философия, что и с Brewfile — файл декларативно отслеживает установленное, но пакеты управляются интерактивно.

### mise (менеджер версий инструментов)

Используется для управления рантаймами и версиями языков (Node, Python и т.д.) через `modules/mise/config/config.toml`. Также служит глобальным таск-раннером для CLI-обёрток (см. [mise-cli-wrappers.md](mise-cli-wrappers.md)).

### Философия управления пакетами

Полностью декларативный подход (всё в nix) неудобен для интерактивной работы. Полностью интерактивный (brew/apt без файлов) — не воспроизводим. Гибридный подход по аналогии с `package.json` в Node.js: интерактивные команды (`brew install`, `pnpm add -g`) автоматически обновляют декларативный файл, который коммитится в git.

| Менеджер | Декларативный файл | Автообновление |
|---|---|---|
| Homebrew | `os/macos/packages/Brewfile` | brew wrapper в fish |
| pnpm global | `os/macos/packages/package.json` | pnpm (нативно) |
| Nix | `modules/*/default.nix` | ручное, для кроссплатформенных CLI |

## Управление dotfiles: `dot` CLI

Mise tasks в `dot.toml` + fish-обёртка `dot`:

| Команда | Действие |
|---|---|
| `dot rebuild` | `darwin-rebuild switch` (автоматически сначала генерирует proxy-bindings) |
| `dot proxy-bindings` | Генерация Lua/TS из `proxy-bindings.yaml` |
| `dot bootstrap-age-key` | Восстановление SOPS age key из 1Password (one-time) |
| `dot edit` | Открыть dotfiles в редакторе |

## Proxy Bindings

Централизованный реестр клавиатурных шорткатов для сторонних приложений (1Password, CleanShot, Raycast и т.д.), которые программно триггерятся из Hammerspoon и Karabiner.

**Архитектура:**
```
modules/proxy-bindings/proxy-bindings.yaml   ← единый источник
        │
        ▼  packages/proxy-bindings/ (Bun CLI)
        │
        ├──► modules/hammerspoon/config/generated/proxy-bindings.lua
        └──► modules/karabiner/config/src/generated/proxy-bindings.ts
```

Подробнее: [proxy-bindings.md](proxy-bindings.md)

## Текущее состояние и планы

### Сделано
- Базовая система модулей с nix-dotbot интеграцией (~28 модулей)
- sops-templates для управления секретами
- Две конфигурации хостов (macOS + Linux)
- Brew-обёртка для гибридного управления пакетами
- Proxy-bindings кодогенерация (YAML → Lua/TS)
- mise CLI-обёртки (rp, dot)
- Resticprofile бэкап-система с мониторингом (healthchecks.io)
- Документация: homebrew/mise/path интеграция, бэкап-план, секреты

### В процессе / Планируется
- **Централизация PATH**: перенос PATH/env из fish conf.d в `environment.systemPath` / `environment.variables` nix-darwin. См. [path-management.md](path-management.md)
- **Homebrew nix-darwin интеграция**: `homebrew.*` модуль для shell integration вместо ручного `01-brew.fish`. См. [homebrew-nix-integration.md](homebrew-nix-integration.md)
- **mise home-manager интеграция**: `programs.mise` вместо ручного `conf.d/mise.fish`. См. [mise-nix-integration.md](mise-nix-integration.md)
- **Изоляция шелл-конфигов**: fish aliases, abbreviations, PATH-записи и env-переменные, связанные с конкретным инструментом, должны определяться внутри модуля этого инструмента и активироваться только при его подключении. Сейчас большая часть шелл-конфигов живёт монолитно в модуле fish.
- **macOS system defaults**: перенос macOS `defaults write` команд из скриптов в декларативную конфигурацию nix-darwin. YAML-файлы уже есть в `os/macos/config/defaults/`.
- **Перенос sops-templates**: `modules/sops-templates/` — инфраструктура, не модуль инструмента — нужно вынести за `modules/` (в `lib/` или корневой `nix/`).
- **Конвенция templates/**: модули с секретами должны использовать поддиректорию `templates/` для `.tmpl.*` файлов.

### Известные проблемы
- `mise activate fish` вызывается дважды (`conf.d/mise.fish` + `conf.d/zz-env.fish`)
- Модуль `nvim` — установка пакета закомментирована
- Модуль `vscode` устанавливает `pkgs.tmux` (лишний)
- Orphaned модули без `default.nix`: posh, raycast, tig, windows-terminal
- `fisher.fish` (241 строка) — полный plugin manager встроен в conf.d вместо внешней зависимости

## Связанная документация

- [Homebrew + Nix интеграция](homebrew-nix-integration.md) — shell integration через nix-darwin
- [mise + Nix интеграция](mise-nix-integration.md) — home-manager модуль, shims vs activate
- [Управление PATH](path-management.md) — централизация PATH через environment.systemPath
- [Управление секретами](secrets-management.md) — стратегия секретов и дизайн sops-templates
- [mise CLI-обёртки](mise-cli-wrappers.md) — паттерн глобальных CLI через mise tasks
- [Proxy Bindings](proxy-bindings.md) — реестр proxy-шорткатов и кодогенерация
- [Бэкап-план](backup/backup-plan.md) — resticprofile архитектура и CLI
- [Hammerspoon keybindings](hammerspoon-keybindings.md) — справочник клавиатурных сочетаний
- [Bun global packages](bun-global-packages-issue.md) — проблема конфликтов зависимостей

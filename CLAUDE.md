# Dotfiles — правила и архитектура репозитория

## Архитектура (кратко)

Декларативный конфиг macOS/Linux в три слоя: **Nix** (nix-darwin + home-manager, пакеты и системные настройки) + **nix-link** (нативные живые симлинки конфигов, `lib/nix-link.nix`) + **sops-templates** (секреты). Реально активен только хост `lasthaze-mbp` (aarch64-darwin); прочие хосты в README — планы.

- **Модуль** = `modules/{home,darwin,nixos}/<name>/default.nix`, обёрнут в `myLib.mkModule config "<name>" { … }`: объявляет `my.<name>.enable`, а тело (пакеты + `nixLink.links` вида `"~/.config/x" = "modules/home/x/config"`, glob — `{ path = "...**"; glob = true; }`) активно только при `my.<name>.enable = true`. Импорт инертен; включает модуль манифест хоста `hosts/<host>/manifest.nix` (`myLib.enableList [ … ]`). Опция линков — `nixLink.links` (модуль `lib/nix-link.nix`).
- **Симлинки живые и двусторонние:** настоящий файл лежит в репо, путь в системе (`~/.config/<x>`) — симлинк на него. Правишь конфиг инструмента → правишь файл репозитория, и наоборот.
- **Применить изменения:** `mise run dot:rebuild` (= `git add -A && sudo darwin-rebuild switch --impure --flake .#lasthaze-mbp`). Два неочевидных момента: (1) флейк видит только **git-tracked** файлы — новый файл без `git add` не подхватится (для этого в задаче есть `git add -A`); (2) `--impure` **обязателен** — иначе sops-секреты молча не рендерятся (гейт по наличию age-ключа на диске).
- **Секреты:** `lib/sops-templates` рендерит `*.tmpl` → файл, подставляя `${VAR}` из sops-зашифрованного `secrets.yaml` (age). Декларируется через опцию `sopsTemplates.render`.
- **Прочее:** `packages/` — bun/TS-тулинг (proxy-bindings, btt-gestures, dump-packages), запуск через `dot:*` mise-задачи; `lib/` — Nix-хелперы (`myLib`/`mk-module`, `sopsRefs`) и инфраструктурные HM-модули (nix-link, sops-templates); `archive/` — старое; karabiner-config (`modules/home/karabiner/config`), vscode-тема (`modules/home/vscode/theme/…`) и dotbot (vestigial) — git-сабмодули.

## Правка симлинкнутых конфигов

Записи `nixLink.links` в `modules/home/*/default.nix` — живые симлинки: **оригинал в репо, путь в системе — симлинк на него** (резолвится через `readlink -f`). Правка содержимого уже слинкованного файла видна сразу.

Перематериализация нужна **только** при изменении самой `nixLink.links` или при добавлении файла под glob-link:

- **Folder-link** (`"~/.config/x" = "modules/home/x/config"`) — симлинк на **саму папку**: добавление/удаление файлов внутри видно сразу.
- **Glob-link** (`{ path = "...**"; glob = true; }`) — папка реальная, внутри пофайловые симлинки с момента сборки → **новый файл не слинкуется до перематериализации**.

Раскладку теперь делает нативный модуль `lib/nix-link.nix` (`home.file` + `mkOutOfStoreSymlink`), не dotbot. Перематериализовать:

- **`mise run dot:link`** — собирает home-generation и активирует его, **без sudo** (пишет только `$HOME`) и **без `git add`** (glob читает живое дерево под `--impure`, untracked-файл виден). Штатный путь агента для нового файла под glob.
- **`mise run dot:rebuild`** — полный системный switch (sudo): нужен для системного слоя, пакетов, sops. Сам делает `git add -A`.

Исключение — новый **Nix-код** (`*.nix`): флейк видит только git-tracked, его надо `git add` перед любой из команд.

## Скиллы через APM

Скиллы Claude Code и Codex доставляет APM, а не Nix/nix-link. Глобальный manifest и lock живут в `modules/home/apm/config/`; project-зависимости — в `apm.yml` и `apm.lock.yaml` корня соответствующего репозитория. В dotfiles project manifest подключает ровно `lasthaze-edge-ops` и `lasthaze-edge-decoy-site` из versioned-пакета `lasthaze-edge` и разворачивает их в `.claude/skills/` и `.agents/skills/`.

Восстановить project deployment: `apm install --frozen`; проверить: `apm audit --ci --no-policy`. Каталоги `.claude/skills/`, `.agents/skills/` и `apm_modules/` сгенерированы и в Git не попадают. Глобальные mutating-команды запускаются через `mise run dot:apm`, чтобы сохранить lock в dotfiles и восстановить Home Manager-ссылку.

## Гейты качества (flake-parts)

Флейк собран на **flake-parts + easy-hosts**; хосты перечислены таблицей `easy-hosts.hosts` в `flake.nix` (`lasthaze-mbp` aarch64/darwin, `lasthaze-homelab` x86_64/nixos). Общая home-manager-обвязка (`extraSpecialArgs` `flakeRoot`/`pkgs-unstable`/`myLib`/`sopsRefs`, `sharedModules` nix-link/sops/sops-templates + все тул-модули `modules/home/*`) — в `modules/home-manager.nix`; per-система glue гейтов — в `parts/dev.nix`. Поверх — слой гейтов:

- **`just`** — дискаверабельный вход (`just --list`): `just check` (= `nix flake check --impure`), `just fmt` (= `nix fmt`), `just rebuild` / `just link` (обёртки над `dot:*`), `just update`.
- **Форматирование — только treefmt** (`nixfmt-rfc-style` + `deadnix` + `statix`), не руками: `nix fmt` / `just fmt`. Сходится за два прохода (deadnix `{ ... }:` → `_:` + nixfmt). Тот же набор — pre-commit-хуком (git-hooks.nix) и как `checks.treefmt`.
- **`nix flake check --impure`** — единый гейт: treefmt, pre-commit, явный eval darwin- и nixos-toplevel (проверки-обёртки над `.drvPath` через `builtins.unsafeDiscardStringContext`, чтобы форсить eval без сборки). На darwin `x86_64-linux`-проверки пропускаются («omitted incompatible systems») — это норма, linux-builder не нужен.
- **devShell** через `.envrc` (`use flake`, direnv) или `nix develop`: `nixd`, `just`, `nixfmt-rfc-style`.

## Скрипты (bun/TS)

Скрипты репо (`packages/*`, `modules/*/config/bin/`, скилловые `scripts/`) пишу и поддерживаю я один, и они уже требуют `bun` — «запуск где угодно без зависимостей» неприменим изначально. **Не жертвуй читаемостью ради zero-dep и не переизобретай базовое в каждом скрипте** — внешние библиотеки бери свободно: CLI-аргументы — `citty` (`defineCommand`/`runMain`), shell-операции — `dax-sh` (`$`). Обратное тоже верно: не тащи либу, которая в конкретном скрипте не нужна (напр. `dax-sh` в скрипт без шелла — мёртвый груз).

Деп декларируй в ближайшем **tracked** `package.json` + `bun.lock` (для `bin/`-скриптов — корневой `~/.dotfiles/package.json`), чтобы был запинен и воспроизводим; `node_modules` в .gitignore, ставится `bun install` / bun auto-install.

## Документация

**НЕ создавай каталог `docs/` в этом репозитории и не пиши туда документацию.** Вся документация по dotfiles живёт в Obsidian vault, а не в репо.

Vault: `/Users/yoshintame/Documents/obsidian/yoshintame/`

- Точка входа (area): `areas/dotfiles.md`
- Проект: `projects/dotfiles-architecture/` — спеки в `implementation-spec/` (существующее состояние — `repo-architecture.md`), разборы в `analysis/`, задачи в `tasks/`

Нужно что-то задокументировать по dotfiles — добавляй или обновляй заметку в vault (через skill `obsidian-vault`), а не файл в этом репозитории.

# Dotfiles — правила и архитектура репозитория

## Архитектура (кратко)

Декларативный конфиг macOS/Linux в три слоя: **Nix** (nix-darwin + home-manager, пакеты и системные настройки) + **nix-dotbot** (живые симлинки конфигов) + **sops-templates** (секреты). Реально активен только хост `lasthaze-mbp` (aarch64-darwin); прочие хосты в README — планы.

- **Модуль** = `modules/<name>/default.nix`: ставит пакеты И декларирует `nixDotbot.links` (`"~/.config/x" = "modules/x/config"`; glob — через `{ path = "...**"; glob = true; }`). Модуль действует, только если он импортирован в `hosts/lasthaze-mbp/default.nix`.
- **Симлинки живые и двусторонние:** настоящий файл лежит в репо, путь в системе (`~/.config/<x>`) — симлинк на него. Правишь конфиг инструмента → правишь файл репозитория, и наоборот.
- **Применить изменения:** `mise run dot:rebuild` (= `git add -A && sudo darwin-rebuild switch --impure --flake .#lasthaze-mbp`). Два неочевидных момента: (1) флейк видит только **git-tracked** файлы — новый файл без `git add` не подхватится (для этого в задаче есть `git add -A`); (2) `--impure` **обязателен** — иначе sops-секреты молча не рендерятся (гейт по наличию age-ключа на диске).
- **Секреты:** `modules/sops-templates` рендерит `*.tmpl` → файл, подставляя `${VAR}` из sops-зашифрованного `secrets.yaml` (age). Декларируется через опцию `sopsTemplates.render`.
- **Прочее:** `packages/` — bun/TS-тулинг (proxy-bindings, btt-gestures, dump-packages), запуск через `dot:*` mise-задачи; `lib/` — Nix-хелперы; `archive/` — старое; karabiner-config, vscode-тема и dotbot — git-сабмодули.

## Правка симлинкнутых конфигов

Записи `nixDotbot.links` в `modules/*/default.nix` — живые симлинки: **оригинал в репо, путь в системе — симлинк на него** (резолвится через `readlink -f`). Правка содержимого уже слинкованного файла видна сразу.

`dot:rebuild` нужен **только** при изменении самой `nixDotbot.links` или при добавлении файла под glob-link:

- **Folder-link** (`"~/.config/x" = "modules/x/config"`) — симлинк на **саму папку**: добавление/удаление файлов внутри видно сразу.
- **Glob-link** (`{ path = "...**"; glob = true; }`) — папка реальная, внутри пофайловые симлинки с момента сборки → **новый файл не слинкуется до `dot:rebuild`**.

(`dot:rebuild` сам делает `git add -A` — флейк видит только tracked-файлы.)

**Частый кейс — Claude Code:** всё в `~/.claude/` симлинкнуто из `modules/claude/` и `modules/agents-shared/`. `~/.claude/skills/` — glob-link, поэтому правка скилла видна сразу, а **новый** скилл подхватится только после `dot:rebuild`; проверить раньше — `ln -s "$DOTFILES/modules/claude/config/skills/<name>/SKILL.md" ~/.claude/skills/<name>/SKILL.md`.

## Документация

**НЕ создавай каталог `docs/` в этом репозитории и не пиши туда документацию.** Вся документация по dotfiles живёт в Obsidian vault, а не в репо.

Vault: `/Users/yoshintame/Documents/obsidian/yoshintame/`

- Точка входа (area): `areas/dotfiles.md`
- Проекты: `projects/dotfiles/` (а также `projects/dotfiles-architecture/`, `projects/dotfiles-target-architecture.md`)

Нужно что-то задокументировать по dotfiles — добавляй или обновляй заметку в vault (через skill `obsidian-vault`), а не файл в этом репозитории.

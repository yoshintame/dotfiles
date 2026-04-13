# Target architecture и roadmap

Документ фиксирует **целевое** состояние архитектуры репозитория — как оно должно выглядеть когда все планируемые хосты будут реализованы — и последовательность реализации с приоритетами. Дополняет [architecture.md](architecture.md), который описывает существующее состояние и паттерны.

## TL;DR

Целевая архитектура — **четыре host'а, три wrapper'а, один общий `modules/`**. Все хосты переиспользуют одни и те же модули из [modules/](../modules/) — этот слой платформо-агностичен на 95% (единственное исключение — macOS-only GUI инструменты). Никакого дополнительного слоя абстракции между `modules/` и `hosts/*` не вводится.

## Целевые хосты

| Host              | Platform                     | Wrapper                                     | Role                                | Status       |
| ----------------- | ---------------------------- | ------------------------------------------- | ----------------------------------- | ------------ |
| `lasthaze-mbp`    | macOS (aarch64-darwin)       | `nix-darwin` + `home-manager`               | Daily-driver MacBook Pro            | ✅ exists    |
| `lasthaze-server` | Linux (x86_64)               | **NixOS** + `home-manager`                  | Physical homelab server at home     | 🔨 planned P2 |
| `lasthaze-wsl`    | Fedora WSL2 on Windows       | `home-manager` (+ `system-manager` future)  | Work laptop WSL dev env             | 💭 future P3  |
| `lasthaze-vps`    | Fedora (generic x86_64)      | `home-manager` (+ `system-manager` future)  | Generic base config for any VPS     | 💭 future P3  |

### Ключевые свойства

- **`lasthaze-mbp`** — существует, работает. Это источник правды для паттернов модулей.
- **`lasthaze-server`** — **реальный физический сервер** (homelab, стоит дома), будет конфигурироваться как полноценный NixOS. Это **не** абстрактная гипотеза, это конкретное железо с реальными workload'ами. Полный NixOS оправдан: нужны system-level сервисы, declarative root FS, атомарные rollback'и, поддержка restic-бэкапов, мониторинга, etc.
- **`lasthaze-wsl`** — Fedora внутри WSL2 на рабочем ноуте с Windows. Home-manager-only сейчас, `system-manager` в будущем для декларативного `/etc/wsl.conf`, systemd user services, и прочего system-level конфига.
- **`lasthaze-vps`** — **generic** конфиг для любой Fedora VPS которая может появиться. Не конкретный один сервер — шаблон для быстрого провижининга «какого-нибудь» VPS под базовые задачи (личный bastion host, ad-hoc dev environment, маленький self-hosted сервис). Почти полностью переиспользует `lasthaze-wsl` — разница в 5% system-level штук (firewalld, sshd, NTP).

## Почему именно такая раскладка wrapper'ов

Wrapper — это тонкий слой, который берёт модули и применяет их к конкретной платформе. Разные платформы требуют разных wrapper'ов потому что у них разные system-level abstractions. Пользовательский слой (`home-manager`) при этом везде одинаковый.

### `nix-darwin` для `lasthaze-mbp`

macOS требует специального wrapper'а потому что у неё уникальные system settings (`system.defaults.dock`, `system.defaults.finder`, Homebrew как integration layer для GUI apps, Mac App Store через `mas`, file associations через `duti`). `nix-darwin` предоставляет Nix options для всего этого. `home-manager` подключается как darwin-module внутри `nix-darwin`.

### NixOS для `lasthaze-server`

Физический homelab требует управления **всей** системой декларативно: kernel, init, сетевой стек, файрвол, systemd сервисы, users, SSH, бэкапы, мониторинг. `NixOS` — единственный способ получить всё это декларативно в одном флейке. `home-manager` подключается как NixOS-module внутри `nixosConfiguration`.

**Бонус:** `nix build .#nixosConfigurations.lasthaze-server.config.system.build.vm` даёт встроенное средство тестирования — см. [testing-bootstrap.md](testing-bootstrap.md).

### `home-manager` standalone для `lasthaze-wsl` / `lasthaze-vps`

WSL и generic VPS **не требуют** полного управления системой через Nix:
- **WSL2** — системой управляет Windows через `/etc/wsl.conf`. Init system тривиальный (только `systemd=true` флаг). Firewall не нужен (Windows host защищает). sshd не нужен. DNS и сеть авто-настраиваются WSL. Реальная поверхность для system-level конфига — ~3 строки в `/etc/wsl.conf`.
- **Generic VPS** — стартует с cloud-init (задаёт hostname, SSH keys, базовые пакеты). Дальше home-manager достаточен для user environment. Более сложные штуки (reverse proxy, docker, мониторинг) — отдельные сервисы, не часть dotfiles.

Таким образом для этих двух хостов нужен **только user-level** слой. `home-manager` standalone — правильный инструмент. Он работает на любом Linux без прав root.

### `system-manager` как future upgrade path для WSL/VPS

[system-manager](https://github.com/numtide/system-manager) от numtide — **прямой Linux-аналог `nix-darwin`** для non-NixOS систем. Позволяет декларативно описывать `/etc/*`, systemd system services, users поверх любого Linux-дистрибутива, параллельно с его родным package manager'ом (dnf, apt, etc.).

**Когда имеет смысл добавить:**
- Появится реальная потребность в декларативном `/etc/wsl.conf`, systemd user-level сервисах, `/etc/hosts`, firewall rules
- Захочется единой парадигмы «declarative system layer» на всех не-NixOS хостах
- Наскучит поддерживать system-level конфиг через cloud-init + shell скрипты

**Пока не имеет смысла:**
- `lasthaze-wsl` и `lasthaze-vps` не существуют, потребностей не видно
- Добавление ещё одного wrapper'а = ещё одна зависимость во флейке и ещё один способ bootstrap'а. Стоимость входа не окупается при нулевом количестве реальных хостов

**Future structure when adopted:**
```nix
# flake.nix (будущее)
systemConfigs.lasthaze-wsl = system-manager.lib.makeSystemConfig {
  modules = [ ./hosts/lasthaze-wsl home-manager.nixosModules.home-manager ];
};
systemConfigs.lasthaze-vps = system-manager.lib.makeSystemConfig {
  modules = [ ./hosts/lasthaze-vps home-manager.nixosModules.home-manager ];
};
```

Стратегия по secret management уже описана в [bootstrap-secret-strategies.md](bootstrap-secret-strategies.md) — независима от wrapper'а.

## Структура hosts/ в целевом состоянии

```
hosts/
├── lasthaze-mbp/              # nix-darwin host (aarch64-darwin)
│   ├── default.nix            # импорты модулей, system.defaults, homebrew config
│   ├── macos-defaults.nix     # dock, finder, keyboard, animations
│   ├── packages/
│   │   ├── Brewfile           # Homebrew casks + formulae
│   │   ├── package.json       # bun global packages
│   │   └── Appsfile.*         # unmanaged и Setapp apps
│   └── file-associations/     # duti конфигурация
│
├── lasthaze-server/           # NixOS host (x86_64-linux) — physical homelab
│   ├── default.nix            # system-level: networking, users, sshd, services
│   ├── hardware.nix           # железо: disk layout, kernel, bootloader
│   ├── modules-user.nix       # импорты shared modules/* для home-manager слоя
│   └── services/              # homelab-specific NixOS modules:
│       ├── restic.nix
│       ├── monitoring.nix
│       └── ...
│
├── lasthaze-wsl/              # home-manager host (Fedora WSL, future)
│   ├── default.nix            # импорты shared modules/* + WSL-specific tweaks
│   └── wsl-specific.nix       # заметки про /etc/wsl.conf (применяется руками до
│                              #   миграции на system-manager)
│
└── lasthaze-vps/              # home-manager host (Fedora generic, future)
    ├── default.nix            # практически идентичен lasthaze-wsl
    └── vps-specific.nix       # заметки про firewalld, sshd, NTP
                               #   (до миграции на system-manager — через cloud-init)
```

**Важный принцип:** каждый `hosts/<name>/default.nix` — это **список импортов из `modules/*`** плюс тонкий host-specific layer. Никаких «profiles» или промежуточных абстракций. Если `lasthaze-wsl/default.nix` и `lasthaze-vps/default.nix` окажутся на 95% идентичными — **это нормально и правильно**. Явная дупликация 10-20 строк между двумя файлами **лучше** чем один уровень косвенности через общий `_base.nix`, потому что:

1. Явность > DRY когда разница маленькая
2. Любая будущая divergence делается добавлением строки, не рефакторингом
3. Новый читатель понимает что делает хост без прыжков между файлами

Если когда-нибудь дупликация станет болезненной (например 100 строк общего кода + 5 строк разницы) — рефакторишь в `hosts/_common-fedora.nix` единым движением. Но не раньше.

## Переиспользование `modules/*`

Все 34 модуля в [modules/](../modules/) делятся на **две категории**:

### Cross-platform (большинство)

Работают на macOS, NixOS и standalone home-manager без изменений:
`fish`, `nvim`, `git`, `tmux`, `vscode`, `btop`, `bat`, `starship`, `fzf`, `atuin`, `zoxide`, `mise`, `lazygit`, `yazi`, `tig`, `gitui`, `claude`, `codex`, `agents-shared`, `posh`, `proxy-bindings`, `resticprofile`, `sops-templates`. Terminal-эмуляторы `kitty`, `ghostty`, `wezterm`, `warp` — де-факто cross-platform, но на headless сервере не импортируются.

Они импортируются в любой host без условной логики. На каждой платформе Nix выбирает правильный `pkgs.*`, остальное идентично.

### macOS-only (несколько модулей)

`hammerspoon`, `karabiner`, `aerospace`, `yabai` — завязаны на macOS APIs (Accessibility, window management, keyboard event interception). Также `iina` (video player), `raycast` (launcher) — macOS-only. Импортируются только в `lasthaze-mbp`.

`windows-terminal` — Windows-only, используется в planned `lasthaze-wsl`.

### Edge case: `resticprofile`

Используется и на macOS и на NixOS. Требует `sops-templates` для расшифровки API-ключей (healthcheck UUIDs, B2 credentials). На `lasthaze-server` (NixOS) будет также использоваться для бэкапов — конфиг идентичен, только добавляется NixOS-side systemd timer для scheduling.

## Roadmap — приоритеты реализации

Последовательность важна — каждая следующая фаза **опирается** на предыдущую, но блокируется реальной потребностью, не гипотетикой.

### Priority 0 — текущая сессия (уже сделано в течение этой сессии)

Фиксация архитектуры, bootstrap.sh, install.sh, sops-templates bootstrap guard, post-install checklist, dot:bootstrap-ssh, testing strategy, target-architecture + testing-bootstrap docs.

### Priority 1 — следующая сессия: завершить macOS и проверить установку

**Цель:** убедиться что `bootstrap.sh lasthaze-mbp` реально работает end-to-end на свежей macOS.

**Задачи:**
1. Поставить **Tart** (`brew install cirruslabs/cli/tart`)
2. Скачать base образ: `tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest bootstrap-base`
3. Clone + run чистую VM: `tart clone bootstrap-base test-run && tart run test-run`
4. Внутри VM: `curl ... | bash -s -- lasthaze-mbp`
5. Пройти по чеклисту из [post-install-checklist.md](post-install-checklist.md) — авторизовать 1Password, включить CLI integration, включить TCC permissions
6. Проверить что финальный `mise run dot:rebuild` проходит чисто с расшифровкой секретов
7. Зафиксировать проблемы и fix'ы в bootstrap.sh если что-то упадёт
8. Зафиксировать **реальные** (а не предполагаемые) TCC permission prompts которые появляются, обновить post-install-checklist если нужно

**Гарантия на выходе:** `bootstrap.sh lasthaze-mbp` проверен живьём, можно с уверенностью переустанавливать основной Mac в любой момент.

### Priority 2 — отдельная сессия: NixOS для `lasthaze-server`

**Цель:** поднять реальный физический homelab сервер дома на NixOS. Это критично потому что железо уже есть и его нужно настраивать **сейчас**.

**Задачи:**
1. **Rename fix:** привести в соответствие имена в flake.nix (`homeConfigurations.lasthaze-server`) и директории (`hosts/lasthaze-home/`). Одно из: либо переименовать директорию в `hosts/lasthaze-server/`, либо output в `homeConfigurations.lasthaze-home`. Первое правильнее семантически
2. **Миграция с `homeConfigurations` на `nixosConfigurations`:**
   - Создать `nixosConfigurations.lasthaze-server` в flake.nix
   - Добавить `nixpkgs.nixosModules` импорт
   - Добавить NixOS-специфичные модули: `networking`, `users`, `services.openssh`, `boot.loader`, `fileSystems`, `time.timeZone`, `i18n`
   - Встроить home-manager через `home-manager.nixosModules.home-manager`
3. **hardware-configuration.nix** — сгенерировать `nixos-generate-config` на реальном железе
4. **Импорт shared `modules/*`** — вся user-space начинка переиспользуется как есть
5. **Homelab-specific NixOS модули:**
   - restic systemd timer через nixos-module (сейчас resticprofile через mise на macOS — для сервера нужен нативный systemd)
   - Monitoring agent (node_exporter или что-то подобное)
   - SSH hardening
   - Firewall rules
6. **Installation** на реальное железо — либо nixos-anywhere, либо классический NixOS installer с импортом флейка
7. **Backup/restore стратегия** для состояния сервера
8. **Тестирование** через `nixos-rebuild build-vm` параллельно с реальным развёртыванием

**Гарантия на выходе:** реальный homelab работает, декларативен, можно rollback, бэкапы идут.

### Priority 3 — далёкое будущее: `lasthaze-wsl` и `lasthaze-vps`

**Цель:** покрыть work-laptop WSL dev environment и любые будущие generic Fedora VPS.

**Архитектурно** это уже заложено (см. выше), но **не реализовано**. Реализация когда:
- Появится конкретная потребность (новая работа с WSL, конкретный VPS под задачу)
- У тебя будет время на рефакторинг и тесты

**Задачи (когда придёт время):**
1. Создать `hosts/lasthaze-wsl/default.nix` — список импортов shared модулей + тонкий WSL layer
2. Создать `hosts/lasthaze-vps/default.nix` — почти идентично, минимальные различия через `lib.mkIf`
3. Добавить `homeConfigurations.lasthaze-wsl` и `homeConfigurations.lasthaze-vps` в flake.nix (мульти-арч `x86_64-linux` + `aarch64-linux`)
4. Обновить `bootstrap.sh` — добавить hosts в usage text, Linux branch уже работает
5. Создать `tests/lima/lasthaze-wsl.yaml` / `lasthaze-vps.yaml` для декларативного тестирования через Lima
6. (Опционально) Добавить `system-manager` если захочется декларативный system-level на Fedora

### Priority 4 — ещё дальше: `system-manager` integration

**Когда появится реальная потребность** — мигрировать `lasthaze-wsl` и `lasthaze-vps` с `homeConfigurations` на `systemConfigs` (system-manager). Это аддитивное изменение — существующие модули продолжают работать, добавляется декларативный system layer сверху.

---

## Что **не** в target architecture

Несколько вещей которые могут показаться логичным следующим шагом но **намеренно оставлены out of scope**:

- **Отдельный wrapper для Raspberry Pi / ARM SBC** — если появится — это просто ещё один `nixosConfigurations.foo` с `system = "aarch64-linux"`. Не новая архитектурная концепция.
- **Multi-user хост** (несколько пользователей на одной машине) — не нужно для личного репозитория. Если когда-то понадобится — home-manager поддерживает multi-user через `home-manager.users.*` в NixOS.
- **Общий `hosts/_common` или `hosts/_profiles` слой** — YAGNI. Если дупликация болит — рефакторим тогда. Не раньше.
- **Отдельные `modules/linux/*` и `modules/darwin/*` поддиректории** — текущая плоская структура `modules/*` работает, потому что 95% модулей cross-platform. Макось-only GUI инструменты импортируются только в `lasthaze-mbp`. Разделение по платформам сейчас — over-engineering.
- **CI/CD поверх Tart + Lima** — в будущем может быть полезно (GitHub Actions workflow, который прогоняет bootstrap в VM на каждый push), но пока ручного тестирования достаточно.

---

## Связанные документы

- [architecture.md](architecture.md) — текущая архитектура и паттерны модулей (источник правды для «как оно работает сейчас»)
- [testing-bootstrap.md](testing-bootstrap.md) — стратегия VM-тестирования каждого хоста (Tart / Lima / build-vm / Parallels)
- [bootstrap-secret-strategies.md](bootstrap-secret-strategies.md) — управление секретами (1Password сейчас, YubiKey / Tailscale future)
- [post-install-checklist.md](post-install-checklist.md) — ручные шаги после `bootstrap.sh` на macOS
- [secrets-management.md](secrets-management.md) — общая философия секретов, обоснование SOPS

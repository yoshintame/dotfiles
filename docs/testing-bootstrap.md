# Testing the bootstrap flow

Документ фиксирует стратегию тестирования `bootstrap.sh` и связанных с ним установочных скриптов на всех платформах, которые репозиторий поддерживает или планирует поддерживать. Цель — иметь возможность быстро и воспроизводимо проверять что свежая установка работает, без физического factory reset реального железа.

## Зачем это нужно

`bootstrap.sh` — single-entry-point установщик, запускаемый через `curl | bash` на чистой машине. Он делает необратимые вещи (ставит Nix, клонирует репо, запускает `darwin-rebuild switch`), и любая регрессия проявится только при следующей переустановке. Без регулярного теста в VM ты узнаешь о баге в момент когда он больнее всего — при реальном factory reset.

VM-тестирование решает это: один прогон в виртуальной машине занимает ~5-30 минут, даёт реальное подтверждение что флоу работает end-to-end, и позволяет ловить регрессии на уровне commit'ов.

## Поддерживаемые targets

Целевое состояние архитектуры описано в [target-architecture.md](target-architecture.md). Каждый host — отдельный target тестирования со своим инструментом:

| Host              | Platform                  | Wrapper                     | Testing tool                 | Status              |
| ----------------- | ------------------------- | --------------------------- | ---------------------------- | ------------------- |
| `lasthaze-mbp`    | macOS (aarch64-darwin)    | `nix-darwin` + home-manager | **Tart**                     | exists, test P1     |
| `lasthaze-server` | Linux (x86_64), homelab   | **NixOS** + home-manager    | **`nixos-rebuild build-vm`** | planned P2 (real HW)|
| `lasthaze-wsl`    | Fedora WSL2 on Windows    | home-manager (+ sys-mgr P4) | **Lima** + **Parallels**     | future P3           |
| `lasthaze-vps`    | Fedora (generic x86_64)   | home-manager (+ sys-mgr P4) | **Lima**                     | future P3           |

Priority нотация (`P1`/`P2`/`P3`/`P4`) — это последовательность реализации из [target-architecture.md](target-architecture.md#roadmap--приоритеты-реализации). Текущая сессия — **P0**: фиксация архитектуры и bootstrap-скриптов. **P1** (следующая сессия): реальный прогон `bootstrap.sh lasthaze-mbp` в Tart VM. **P2**: миграция `lasthaze-server` на NixOS и развёртывание на реальное железо homelab'а (высокий приоритет — железо уже есть). **P3**: WSL/VPS хосты (архитектура заложена, реализация когда появится потребность). **P4**: опциональная миграция на `system-manager` для Fedora-хостов.

## Матрица инструментов

| Инструмент | Что тестирует | Почему выбран |
|---|---|---|
| **Tart** | macOS guest на Apple Silicon хосте | CLI-first, CoW snapshots через `tart clone`, готовые base образы macOS через ghcr.io, пригоден для CI, headless режим |
| **Lima** | Linux guest декларативно через YAML | Декларативный конфиг в git, cloud-init support, CI-friendly, работает на Virtualization.framework нативно, open source |
| **`nixos-rebuild build-vm`** | NixOS конфиг целиком | Встроено в Nix, **один код описывает и прод и тест-VM** — zero drift. Работает для NixOS хостов, не для home-manager-as-guest |
| **Parallels Desktop** | Windows + WSL интеграция | Уже используется для Windows в daily workflow; snapshot tree; единственный практичный путь тестировать WSL-специфичные quirks |

## Что мы **не** используем и почему

- **VirtualBuddy** — отличный GUI, но без CLI нет автоматизации, для итеративного тестирования медленнее чем `tart clone`
- **UTM** — нет встроенных snapshot'ов для Virtualization.framework гостей, reset означает полную переустановку macOS заново
- **Parallels для macOS guest** — работает, но преимущества Parallels (coherence, shared folders, drag-n-drop) недоступны для macOS guest из-за ограничений Apple API. Для macOS guest бесплатный Tart эквивалентен технически и удобнее операционно
- **OrbStack для тестирования dotfiles** — отличный инструмент для Docker/Linux daily use, но нет декларативного YAML-конфига в git. Оставлен вне testing стека, но уместен как daily-driver Linux VM manager параллельно
- **VMware Fusion** — бесплатен с 2024, но не даёт преимуществ над Lima для Linux guest и над Tart для macOS guest
- **Docker containers с systemd** — быстрее VM, но ограничены в плане systemd user services и реального kernel. Недостаточно для интеграционного теста

---

## Setup: Tart для macOS guest

**Применимо к хостам:** `lasthaze-mbp` (priority P1 — следующая сессия).

### Установка

```bash
brew install cirruslabs/cli/tart
```

### Скачать base образ (один раз, ~30-40 GB)

```bash
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest bootstrap-base
```

Base образ **не изменяется** — только клонируется. Все тестовые прогоны работают с его клонами.

Актуальные образы: смотри https://github.com/cirruslabs/macos-image-templates — есть Ventura, Sonoma, Sequoia, Tahoe, с вариантами `base` (чистая macOS) и `xcode` (с preinstalled Xcode и т.д.).

### Один цикл теста

```bash
# 1. Clone от base — мгновенно (copy-on-write)
tart clone bootstrap-base bootstrap-run

# 2. Запуск VM в окне
tart run bootstrap-run

# 3. Внутри гостя (после прохождения setup assistant в первый раз):
#    Открыть Terminal.app и выполнить:
curl -fsSL https://raw.githubusercontent.com/yoshintame/dotfiles/master/bootstrap.sh \
  | bash -s -- lasthaze-mbp

# 4. После завершения теста — удалить clone, base остаётся нетронутым
tart stop bootstrap-run
tart delete bootstrap-run
```

Для следующего теста: `tart clone bootstrap-base bootstrap-run` и по кругу.

### Headless режим (для автоматизации)

```bash
tart run bootstrap-run --no-graphics &
IP=$(tart ip bootstrap-run)
ssh admin@"$IP"   # пароль admin для cirruslabs образов
```

Через SSH внутри можно запустить `bootstrap.sh` без GUI и проверить exit code.

### Что Tart в macOS VM покрывает

**Полностью покрывает:**
- `xcode-select --install` путь
- Determinate Systems Nix installer
- `git clone` репозитория
- Первый `darwin-rebuild switch` с sops-templates bootstrap guard
- Установка Brewfile пакетов (кроме `mas`)
- nix-dotbot симлинки
- Генерация proxy-bindings
- SOPS расшифровка секретов (если залогинишься в 1Password внутри VM master password'ом)
- Второй `darwin-rebuild switch` с render'ом секретов
- Печать post-install checklist

**Частично покрывает:**
- 1Password авторизация — работает через master password + 2FA, но **Touch ID недоступен в VM** (нет Secure Enclave passthrough)
- `mas install` из Brewfile — может не работать в VM из-за DRM ограничений App Store, зависит от состояния образа

**Не покрывает:**
- Реальная работа Karabiner/Hammerspoon/Aerospace — у них есть дополнительные системные зависимости, которые в VM ведут себя странно. Функциональные тесты этих инструментов делай на реальной машине
- TCC permissions UX — технически всё кликается в VM, но это ручной процесс

### Когда запускать macOS тест

- Перед merge в `master` изменений, затрагивающих `bootstrap.sh`, `install.sh`, `flake.nix`, `hosts/lasthaze-mbp/*`, `modules/sops-templates/*`
- После bump'ов nix-darwin / home-manager major версий
- Раз в квартал как sanity check

---

## Setup: Lima для Linux guest

**Применимо к хостам:** `lasthaze-wsl`, `lasthaze-vps` (priority P3, future). Для `lasthaze-server` используется `nixos-rebuild build-vm` (см. ниже) потому что сервер на NixOS, а не на Fedora+home-manager.

### Установка

```bash
brew install lima
```

### Canonical test configs (в репозитории)

Конфиги тестов живут в `tests/lima/*.yaml` и описывают каждый Linux target декларативно. Это делает тест частью репо — если конфиг в мастере, значит тест воспроизводим.

**Пример** (TODO: добавить реальные файлы):

```yaml
# tests/lima/lasthaze-server.yaml
vmType: "vz"
arch: "aarch64"
images:
- location: "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-arm64.img"
memory: "4GiB"
cpus: 4
disk: "20GiB"
mounts:
- location: "~/.dotfiles"
  mountPoint: "/home/lima.linux/.dotfiles"
  writable: false
provision:
- mode: user
  script: |
    set -euo pipefail
    bash /home/lima.linux/.dotfiles/bootstrap.sh lasthaze-server
```

### Один цикл теста

```bash
limactl start --name=dotfiles-test tests/lima/lasthaze-server.yaml
limactl shell dotfiles-test    # войти внутрь для проверки
limactl delete dotfiles-test   # reset
```

### Предварительное условие: мульти-арч flake

Lima на Apple Silicon host'е запускает **aarch64** Linux гостей нативно через Virtualization.framework. Чтобы тест работал без x86_64 эмуляции (которая медленнее и сложнее), flake должен объявлять `aarch64-linux` как supported system для `lasthaze-server`:

```nix
# flake.nix
outputs = { ... }: {
  homeConfigurations.lasthaze-server = home-manager.lib.homeManagerConfiguration {
    # было: только x86_64-linux
    # стало: поддерживать обе архитектуры
    pkgs = nixpkgs.legacyPackages.${system};  # где system выбирается per-machine
    ...
  };
};
```

Это изменение обратно-совместимо: production сервер x86_64 продолжает работать, а тесты могут использовать aarch64 нативно.

### Что Lima в Linux VM покрывает

**Полностью покрывает:**
- `home-manager switch` с полным флейком
- nix-dotbot симлинки в guest home directory
- sops-templates рендеринг секретов (если age-key пробрасывается через mount или env)
- Установка всех нужных CLI инструментов (fish, nvim, git, tmux, btop, starship, bat, fzf, zoxide, mise)
- Fish shell конфигурация + плагины
- systemd user services (через `systemctl --user`)
- Интеграционный тест — внутри shell'а проверить что fish работает, `git` подписывает, etc.

**Не покрывает:**
- GUI инструменты (нет DE по задумке — headless Linux у тебя)
- Физические devices (камеры, микрофоны) — не релевантно для server workload'а
- Реальное железо / сетевая карта / диски — для функциональных тестов в другом месте

---

## Setup: `nixos-rebuild build-vm` (priority P2 — `lasthaze-server`)

**Применимо к хостам:** `lasthaze-server` (physical homelab, priority P2). Это **приоритетный** реальный путь — homelab-сервер уже существует физически и будет развёрнут на NixOS. До этого момента секция описывает как тестировать конфиг до реального развёртывания на железо.

Nix даёт встроенный путь без внешних инструментов.

### Как работает

```bash
# Из корня репо
nix build .#nixosConfigurations.lasthaze-server.config.system.build.vm
./result/bin/run-lasthaze-server-vm
```

Nix собирает QEMU-based VM с **ровно тем** NixOS конфигом что описан в `nixosConfigurations`. Ты видишь свою систему такой, какой она была бы на реальном железе. Диск в памяти — изменения не сохраняются, каждый запуск = чистое состояние. Опционально `--writable` для persistent диска.

### Почему это уникально

- **Один код** описывает production и test-VM. Нет расхождения «на тесте работало, на проде нет»
- **Абсолютно воспроизводимо** — через годы один и тот же commit даст идентичную VM
- **Интеграция с NixOS tests** — можно писать декларативные интеграционные тесты на Python, которые запускают несколько VM, гоняют команды, asserts'ят результаты. Nixpkgs использует этот механизм для тестирования сотен сервисов
- **Нет третьих инструментов** — всё внутри Nix, один флейк self-contained

### Почему это выбрано для `lasthaze-server` именно сейчас

- Сервер — **реальный физический homelab**, уже существует как железо, требует настройки
- NixOS-конфиг описывает корневую систему целиком: kernel, init, firewall, systemd services, users, SSH — всё что нужно серверу
- `build-vm` позволяет протестировать конфиг **до** развёртывания на настоящее железо, найти опечатки и ошибки в networking/services быстро
- Один код описывает и test-VM и продакшен-сервер — нет расхождения
- Для WSL/VPS хостов эта стратегия **неприменима** — они home-manager only, NixOS не ставим. Там Lima.

---

## Setup: Windows + WSL2 Fedora тестирование

**Применимо к хостам:** `lasthaze-wsl` (priority P3, future). До создания этого host'а в flake.nix тестировать нечего — раздел оставлен как зафиксированная стратегия на момент реализации.

### Ключевой инсайт: двухуровневое разделение

Большая часть тестирования для WSL Fedora это **тестирование home-manager конфига на Fedora как таковой**. Home-manager не знает про WSL — видит systemd, user, Nix. Значит **Lima с Fedora cloud image** даёт 90% покрытия без Windows вообще.

Остальные 10% — WSL-специфичные quirks:
- systemd под WSL (нужен `[boot] systemd=true` в `/etc/wsl.conf`)
- systemd user services автостарт
- `/mnt/c/...` пути
- Windows interop (запуск `.exe` из Linux)
- Сетевая модель WSL2 (NAT, localhost forwarding)
- Memory limits через `.wslconfig`
- DNS resolver автогенерация Windows'ом

Эти quirks ловятся только в **реальном WSL**.

### Уровень 1: Lima с Fedora (быстрый daily тест)

```yaml
# tests/lima/fedora.yaml (когда host появится в flake)
vmType: "vz"
arch: "aarch64"
images:
- location: "https://dl.fedoraproject.org/pub/fedora/linux/releases/41/Cloud/aarch64/images/Fedora-Cloud-Base-Generic-41-1.4.aarch64.qcow2"
memory: "4GiB"
cpus: 4
mounts:
- location: "~/.dotfiles"
  mountPoint: "/home/lima.linux/.dotfiles"
provision:
- mode: user
  script: |
    bash /home/lima.linux/.dotfiles/bootstrap.sh lasthaze-wsl
```

Покрывает всё что не специфично для WSL-среды. Быстро, декларативно, можно запускать в CI.

### Уровень 2: Parallels + Windows 11 ARM + WSL2 Fedora (WSL quirks)

**Prerequisite:** Windows 11 ARM VM в Parallels уже установлен (для daily работы).

**Setup один раз:**
1. Внутри Windows: `wsl --install Fedora` (официальный Fedora WSL образ доступен с 2025)
2. Настроить `/etc/wsl.conf` внутри Fedora: `[boot]\nsystemd=true`
3. `wsl --shutdown && wsl -d Fedora` — перезапустить с systemd
4. **В Parallels: сделать snapshot «clean-fedora-wsl»**

**Один цикл теста:**
1. Parallels: revert к snapshot «clean-fedora-wsl»
2. Внутри Fedora WSL: `curl ... | bash bootstrap.sh lasthaze-wsl`
3. Наблюдать результат, проверять WSL-специфичные штуки руками

**Полностью автоматизировать этот уровень сложно** — Parallels CLI (`prlctl snapshot-switch`) умеет revert, но запустить `bash` внутри WSL внутри Windows VM через CLI требует извращений. Оставляем как **ручной, редкий тест** — запускать при добавлении модулей с WSL-интеграцией или при bump'ах Nix на WSL.

### Уровень 3 (опционально): GitHub Actions Windows runner

GitHub Actions даёт бесплатный `windows-latest` runner с поддержкой WSL2. Workflow может:
1. `wsl --install` Fedora
2. Скопировать репо внутрь
3. Запустить `bash bootstrap.sh lasthaze-wsl`
4. Проверить exit code и ключевые артефакты

Ограничения: runner'ы x86_64 Windows (ARM Windows runner'ы в preview). Для WSL-тестирования это не критично — home-manager проблемы одинаковы на обеих архитектурах.

### Предварительное условие

Прежде чем что-либо тестировать для WSL, **в [flake.nix](../flake.nix) должен появиться `homeConfigurations.lasthaze-wsl`** с Fedora WSL-специфичной конфигурацией — без которой команда `bootstrap.sh lasthaze-wsl` просто не имеет смысла. Этот host ещё не создан. Создание это часть priority P3 ([target-architecture.md](target-architecture.md#priority-3--далёкое-будущее-lasthaze-wsl-и-lasthaze-vps)), не часть testing стека.

---

## Cheatsheet

### Daily iteration

```bash
# macOS
tart clone bootstrap-base run && tart run run
# ... тест внутри VM ...
tart stop run && tart delete run

# Linux
limactl start --name=run tests/lima/lasthaze-server.yaml
# автоматически провижинит через bootstrap.sh
limactl delete run
```

### Pre-merge checklist

Перед merge в `master` изменений затрагивающих bootstrap или host configs:
1. `tart clone bootstrap-base pre-merge && tart run pre-merge` — проверить macOS путь
2. `limactl start --name=pre-merge tests/lima/lasthaze-server.yaml` — проверить Linux путь
3. (опционально) Parallels WSL snapshot revert — если затронуты WSL модули

### Когда забыть и вернуться

Если VM пылится месяцами неактуальные base образы:
```bash
# обновить macOS base
tart delete bootstrap-base
tart clone ghcr.io/cirruslabs/macos-sequoia-base:latest bootstrap-base

# обновить Lima images в tests/lima/*.yaml (вручную, это YAML в git)
```

---

## Что ещё предстоит сделать

Упорядочено по приоритетам из [target-architecture.md](target-architecture.md#roadmap--приоритеты-реализации):

**P1 (следующая сессия):**
- [ ] Поставить Tart, скачать base образ `ghcr.io/cirruslabs/macos-sequoia-base`
- [ ] Реально прогнать `bootstrap.sh lasthaze-mbp` в Tart VM end-to-end
- [ ] Зафиксировать реальные TCC prompts в `post-install-checklist.md`

**P2 (отдельная сессия, высокий приоритет — physical homelab):**
- [ ] Создать `nixosConfigurations.lasthaze-server` в `flake.nix`
- [ ] Миграция `hosts/lasthaze-home/` → `hosts/lasthaze-server/` (fix legacy naming)
- [ ] `hardware-configuration.nix` для реального железа
- [ ] NixOS модули: networking, users, sshd, firewall, restic systemd timer
- [ ] Тестировать через `nix build .#nixosConfigurations.lasthaze-server.config.system.build.vm`
- [ ] Реальное развёртывание на homelab сервер

**P3 (future, когда появится потребность):**
- [ ] Создать `homeConfigurations.lasthaze-wsl` и `homeConfigurations.lasthaze-vps` в flake
- [ ] Сделать их мульти-арчными (`x86_64-linux` + `aarch64-linux`)
- [ ] Создать `tests/lima/lasthaze-wsl.yaml` и `tests/lima/lasthaze-vps.yaml`
- [ ] Parallels Windows VM + Fedora WSL snapshot для integration теста WSL quirks

**P4 (опциональное будущее):**
- [ ] Миграция `lasthaze-wsl` и `lasthaze-vps` на `system-manager` для декларативного system-level
- [ ] GitHub Actions workflow с matrix: macos-runner → Tart, ubuntu-runner → Lima, windows-runner → WSL
- [ ] `nixosTests` для интеграционного тестирования сервисов homelab'а

# Tart base image: `-base` + preflight vs vanilla

Документ фиксирует выбор тестового образа для прогона `bootstrap.sh` в Tart VM на macOS guest. Конкретно — почему мы используем `ghcr.io/cirruslabs/macos-sonoma-base:latest` плюс короткий preflight-скрипт, а не «truly clean» `macos-sonoma-vanilla`.

Связанные документы: [testing-bootstrap.md](testing-bootstrap.md) (общая стратегия VM-тестирования), [target-architecture.md](target-architecture.md) (целевая архитектура и P1 roadmap).

## TL;DR

Cirruslabs `-base` уже **не «чистый»** — в нём есть юзер `admin` (UID 501) и preinstalled `/opt/homebrew` под него. Это создаёт три конкретные блокирующие проблемы при прогоне `bootstrap.sh` под нашим primary user'ом `yoshintame` (UID 502). Решение — **2-3 строчный preflight внутри VM** который создаёт `yoshintame` и chown'ит `/opt/homebrew`. `bootstrap.sh` остаётся test-env-agnostic.

Альтернатива — `vanilla` образ с ручным проходом Setup Assistant — концептуально честнее, но обходится ~5-10 минут VNC-клика при каждой регенерации golden image и не даёт пропорциональной выгоды.

## Контекст

`bootstrap.sh lasthaze-mbp` рассчитан на то что юзер делает factory reset Mac → Setup Assistant создаёт его primary account (`yoshintame`) → внутри этого аккаунта он запускает bootstrap. Скрипт не предполагает существования никаких других юзеров и никаких preinstalled пакет-менеджеров.

VM-тестирование должно симулировать этот сценарий настолько точно, насколько это разумно. «Разумно» — потому что 100% точная симуляция требует automating Apple Setup Assistant, что отдельный полноценный проект.

## Проблема: что значит «не чистый» в `-base`

Cirruslabs не гоняют Setup Assistant вручную при сборке базовых образов. Они автоматизируют через [Packer](https://github.com/cirruslabs/macos-image-templates) — и в процессе:

1. **Создают юзера `admin` (UID 501, password `admin`)** с passwordless sudo
2. **Ставят Xcode CLT и Homebrew** под этим `admin`
3. Включают SSH server для удалённого доступа
4. Снимают snapshot → публикуют как `ghcr.io/cirruslabs/macos-sonoma-base`

Это удобно для их типичного use case (CI runner за 30 секунд до готовности), но означает что состояние образа = «Mac в котором первый юзер уже залогинился и сделал базовый setup», а не «Mac до Setup Assistant».

## Что ломается

Тестируя `bootstrap.sh` под нашим primary user'ом `yoshintame`, мы получили **три блокера** и **несколько minor артефактов**.

### Блокеры

#### 1. nix-darwin требует существующего primary user'а

`hosts/lasthaze-mbp/default.nix` хардкодит `username = "yoshintame"`. nix-darwin 25.05 при активации проверяет:

```
error: primary user `yoshintame` does not exist, aborting activation
Please ensure that `system.primaryUser` is set to the name of an existing user.
```

В `-base` есть только `admin` — наша активация падает.

#### 2. У нового юзера `yoshintame` нет passwordless sudo

`bootstrap.sh:run_system_switch` делает `sudo --preserve-env=NIX_CONFIG ... darwin-rebuild switch`. Без NOPASSWD bootstrap зависает на password prompt'е (нет TTY в headless SSH сценарии).

Строго говоря, **это противоречие реальной машине** — на твоём настоящем Mac sudo требует пароль или Touch ID. То есть это test-env-only хак ради `--test mode` неинтерактивности, и он будет нужен **независимо** от выбора base/vanilla.

#### 3. `/opt/homebrew` владеется `admin`

После создания `yoshintame` brew bundle от его имени падает с массой:
```
Error: Permission denied @ rb_sysopen - /opt/homebrew/var/homebrew/locks/...
```

Все каталоги `/opt/homebrew/{var,Cellar,Library/Taps,...}` владеются `admin:admin` от Packer-сборки. yoshintame может только читать.

### Minor артефакты

| Симптом | Влияние |
|---|---|
| `warning: $HOME ('/Users/yoshintame') is not owned by you, falling back to '/var/root'` под sudo nix | Безобидно, но nix кеши растут в `/var/root/.cache` параллельно user-home кешу |
| Pre-installed brew formulae в Cellar (`git`, `curl`, etc. от cirruslabs) | При полном `dot:rebuild` с `brew bundle cleanup` они удалятся как «extra» — искажает диффу с боевой машиной. В `--test` mode не активно |
| `/Users/admin` как мусор + admin'овские dotfiles | +14 GB диска, не блокирует |
| TCC permissions, Karabiner accessibility, login items | **Не различаются** между -base и vanilla — TCC.db в обоих пуст, требует ручного клика на любой машине |

## Альтернативы

### A. macos-sonoma-vanilla + ручной Setup Assistant раз в квартал

Vanilla образ начинается **до Setup Assistant'а**. Когда `tart run`, ты получаешь **GUI Apple Setup Assistant** (10-15 экранов: язык, регион, клавиатура, Apple ID, FileVault, аналитика, Siri, Screen Time). SSH порт **не открыт** пока кто-то не пройдёт setup и не включит Remote Login.

Workflow:
1. Раз в квартал: `tart run vanilla` с GUI окном, ручной клик через Setup Assistant
2. Создать `yoshintame` (получит UID 501 — совпадает с реальным factory reset)
3. Включить SSH (`sudo systemsetup -setremotelogin on`)
4. Прописать SSH key
5. `tart stop && tart clone vanilla → dotfiles-test-base-vanilla`
6. Дальше каждый тест клонит `dotfiles-test-base-vanilla`

**Плюсы:**
- yoshintame получает UID 501 как на реальном Mac (vs UID 502 в base+preflight)
- `/opt/homebrew` отсутствует на старте — bootstrap.sh `ensure_homebrew` тестируется вживую
- Cellar пустой — точное соответствие Brewfile при cleanup
- Нет admin/yoshintame split-disk-overhead
- Reproducibility: golden image коммитится по SHA, тесты бит-в-бит идентичны

**Минусы:**
- 5-10 минут VNC-клика при каждой регенерации (cirruslabs обновляет vanilla когда выходит новая minor macOS, ~раз в квартал)
- Apple ломает Setup Assistant flow в minor update'ах — клик-инструкции протухают
- +30 GB диска для второго базового образа (если хочется хранить и `-base` и `vanilla`)
- Setup Assistant automation через `cliclick` + AppleScript = 1-2 дня инжиниринга, ломается с каждой версией macOS — **отказались сразу**

### B. Использовать `-base` + preflight скрипт (выбрано)

Workflow:
1. `tart clone bootstrap-base test-run`
2. `tart run test-run --no-graphics &`
3. `ssh admin@<ip>` (passwordless через Tart's стандартный admin pubkey или создать через expect)
4. **Preflight (~30 сек):**
   - `sudo sysadminctl -addUser yoshintame -password yoshintame -admin`
   - `sudo createhomedir -c -u yoshintame`
   - inject SSH key for yoshintame
   - `echo 'yoshintame ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/yoshintame-test`
   - `sudo chown -R yoshintame:staff /opt/homebrew`
5. `ssh yoshintame@<ip> 'bash ~/.dotfiles/bootstrap.sh --test lasthaze-mbp'`

**Плюсы:**
- Preflight = pure CLI, ~30 секунд, voiceless, codified в репо как `tests/tart/preflight.sh`
- Cirruslabs регулярно обновляет `-base` без нашего участия
- `bootstrap.sh` остаётся test-env-agnostic (нет в нём «if VM, create user»-кода)
- Воспроизводимо: тот же preflight на любой версии `-base`

**Минусы:**
- yoshintame получает UID **502** (admin сидит на 501) — расходится с реальной машиной где yoshintame=501
- Pre-installed Homebrew формулы в Cellar остаются как фоновый шум (impact только при `cleanup`)
- Дополнительный `/Users/admin` мусор в guest

### C. Setup Assistant automation (отказались сразу)

Полная автоматизация Setup Assistant через VNC click + AppleScript. Закрывает gap полностью, генерирует vanilla→ready образ из CLI без человеческого вмешательства. **Не делаем** потому что:
- 1-2 дня инжиниринга на первую версию
- Регулярные поломки при minor-обновлении macOS Setup Assistant UX
- Cirruslabs делают это **за нас** в `-base` — двойная работа
- Overkill для домашнего dotfiles репо. Это размер задачи который имеет смысл только для платформы как Cirrus CI

## Решение: `-base` + preflight (вариант B)

**Обоснование:**

1. **Из 3 блокеров vanilla закрывает только 2** — passwordless sudo нужен в обоих окружениях (test-only хак ради `--test` неинтерактивности). То есть конкретная польза vanilla = «не делать sysadminctl + не делать chown brew»
2. **Цена закрытия gap'а в vanilla** = 5-10 минут VNC-клика при каждом обновлении upstream + риск поломки от Apple. Цена preflight'а = 2 строки скрипта раз и навсегда
3. **UID разница (501 vs 502) не задевает наш код** — нигде в `hosts/*`, `modules/*`, `bootstrap.sh` нет хардкода UID. Имена юзеров используются, не numeric ID
4. **Pre-installed brew artifacts** — relevant только при `brew bundle cleanup --force` который в `--test` режиме отключён, а в боевом mode не запускается без явного флага

**Канонический preflight будет лежать в `tests/tart/preflight.sh`** (TODO: создать), вызывается между `tart run` и `bootstrap.sh`. Содержимое:

```bash
#!/usr/bin/env bash
set -euo pipefail
HOST="$1"; KEY_PUB="$2"

ssh "admin@${HOST}" "bash -s -- '${KEY_PUB}'" <<'EOF'
set -euo pipefail
PUBKEY="$1"

# Create primary user matching hosts/*/default.nix#username
sudo sysadminctl -addUser yoshintame \
  -fullName "Yoshintame" \
  -password yoshintame \
  -home /Users/yoshintame \
  -shell /bin/zsh \
  -admin \
  -adminUser admin -adminPassword admin

sudo createhomedir -c -u yoshintame

# SSH access for yoshintame
sudo mkdir -p /Users/yoshintame/.ssh
echo "$PUBKEY" | sudo tee /Users/yoshintame/.ssh/authorized_keys >/dev/null
sudo chown -R yoshintame:staff /Users/yoshintame/.ssh
sudo chmod 700 /Users/yoshintame/.ssh
sudo chmod 600 /Users/yoshintame/.ssh/authorized_keys

# NOPASSWD sudo for unattended bootstrap (--test mode)
echo "yoshintame ALL=(ALL) NOPASSWD: ALL" \
  | sudo tee /etc/sudoers.d/yoshintame-test >/dev/null
sudo chmod 440 /etc/sudoers.d/yoshintame-test

# Reown preinstalled Homebrew so brew bundle works under yoshintame
sudo chown -R yoshintame:staff /opt/homebrew
EOF
```

## Когда пересмотреть это решение

Поводы вернуться к vanilla:

- **`bootstrap.sh` стал ставить brew сам и это нужно явно тестировать** — текущий `ensure_homebrew` в base пропускается потому что brew уже стоит. Не тестируется реальный install path. Если эта дыра поймает регрессию — vanilla становится оправдан
- **Cirruslabs перестали обновлять `-base` или сильно поменяли что-то в нём** — заведём свой Packer flow на vanilla
- **CI-флоу появится** (GitHub Actions matrix testing) — vanilla становится более воспроизводимым по дизайну, golden image коммитится по SHA
- **Кто-то жалуется на UID-related баги** — нашёлся реальный пример где UID 501 vs 502 даёт разное поведение. Сейчас не очевидно что таковой существует

Без этих триггеров — `-base` + preflight остаётся правильным выбором.

## Что **точно не делать**

Впихивать в `bootstrap.sh` логику типа «если я в VM или юзер не yoshintame — создай yoshintame и chown brew». Test-env-only код в production-пути это:
- Dead code в проде (на реальной машине user уже yoshintame, ветка не выполняется)
- Риск сломать боевую установку потому что мёртвый код иногда оживает на edge case'ах
- Семантический шум — будущему читателю надо разбираться что есть test-only заглушка

Test-env специфика **остаётся в `tests/tart/preflight.sh`**. `bootstrap.sh` ничего про VM не знает.

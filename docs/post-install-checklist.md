# Post-install checklist

Чеклист ручных шагов после запуска [bootstrap.sh](../bootstrap.sh) на свежем macOS. Пункты отсюда **принципиально нельзя автоматизировать** без MDM / Apple Business Manager — macOS требует интерактивного подтверждения пользователя в System Settings (TCC, Apple ID, приватность).

Скрипт `bootstrap.sh` в финальной фазе печатает этот чеклист и последовательно открывает нужные панели Settings. Всё что ниже — это то, что остаётся кликнуть руками.

---

## 1. Apple ID и App Store

**Зачем:** `brew bundle` через nix-darwin вызывает `mas install <id>` для приложений из Mac App Store (см. [Brewfile](../hosts/lasthaze-mbp/packages/Brewfile)). `mas` требует чтобы App Store уже был залогинен в GUI — Apple убрала API `mas signin` с macOS 10.13+.

**Действия:**
1. Открыть `App Store.app`
2. Ввести Apple ID + пароль + 2FA
3. Согласиться на iCloud если нужно

**Deeplink:**
```bash
open -a "App Store"
```

Это стоит сделать **до** первого `darwin-rebuild switch`, иначе `brew bundle` упадёт на `mas install`.

---

## 2. 1Password и SSH Agent

**Зачем:**
- Primary password manager
- Хранит SOPS age-key (восстанавливается через `dot:bootstrap-age-key`)
- Хранит SSH приватный ключ и работает как SSH Agent — подпись git commits идёт через `op-ssh-sign` (см. [modules/git/config/config](../modules/git/config/config))

**Действия:**
1. Открыть `1Password.app`
2. Авторизоваться в аккаунте
3. Settings → Developer → включить **Use the SSH agent**
4. Settings → Developer → включить **Integrate with 1Password CLI** (для `op` биометрии)
5. Проверить в терминале: `ssh-add -l` должен показать ключи из 1Password

**Deeplink:**
```bash
open -a "1Password"
```

После этого `mise run dot:bootstrap-age-key` и `mise run dot:bootstrap-ssh` смогут отработать.

---

## 3. Accessibility permissions

**Зачем:** Karabiner-Elements, Hammerspoon и Aerospace перехватывают и модифицируют системные события (нажатия клавиш, управление окнами). Без Accessibility они просто не работают.

**Действия:** в System Settings → Privacy & Security → Accessibility включить тумблеры для:
- `Karabiner-Elements`
- `karabiner_grabber` (появляется после первого запуска Karabiner)
- `Hammerspoon`
- `AeroSpace`

**Deeplink:**
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
```

---

## 4. Input Monitoring

**Зачем:** Karabiner читает raw keyboard events на уровне ниже Accessibility. Требует отдельного разрешения.

**Действия:** System Settings → Privacy & Security → Input Monitoring:
- `karabiner_grabber`
- `karabiner_observer`

**Deeplink:**
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
```

---

## 5. Full Disk Access

**Зачем:**
- Терминал (`Ghostty`, `WezTerm`, `Warp`, `kitty`) — чтобы скрипты могли читать/писать в защищённые директории (`~/Library`, `~/Documents`)
- `restic` (через [resticprofile](../modules/resticprofile)) — чтобы бэкапы охватывали всё

**Действия:** System Settings → Privacy & Security → Full Disk Access, добавить:
- Терминал, который ты используешь по умолчанию (`Ghostty.app` или другой из Brewfile)
- `restic` (если делаешь backup под текущим пользователем) — через `+` → выбрать бинарь `/opt/homebrew/bin/restic` или nix-путь

**Deeplink:**
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
```

---

## 6. Screen Recording (опционально)

**Зачем:** если используешь скриншот-утилиты (CleanShot, Shottr) или любой screen capture через Hammerspoon.

**Действия:** System Settings → Privacy & Security → Screen & System Audio Recording.

**Deeplink:**
```bash
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

---

## 7. Login Items

**Зачем:** автостарт ключевых агентов.

**Действия:** System Settings → General → Login Items & Extensions. Убедиться что в списке есть:
- `Karabiner-Elements`
- `Hammerspoon`
- `AeroSpace`
- `1Password` (обычно добавляется сам при первом логине)

**Deeplink:**
```bash
open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
```

---

## 8. Tailscale (опционально)

**Зачем:** доступ в tailnet к домашним сервисам. `tailscale` установлен через Brewfile, но требует ручного логина.

**Действия:**
```bash
sudo tailscale up
```
Откроется браузер для SSO. После логина проверить:
```bash
tailscale status
```

---

## 9. Что делать если первый `darwin-rebuild switch` напечатал предупреждение про sops-templates

Это нормально и ожидаемо. Модуль [sops-templates](../modules/sops-templates/module.nix) на свежей машине печатает:

```
sops-templates: no age key at ~/.config/sops/age/keys.txt — skipping rendering (bootstrap mode).
sops-templates: run 'mise run dot:bootstrap-age-key' then re-run switch to render secrets.
```

Это **bootstrap guard** — он специально не падает, а пропускает рендеринг, чтобы первый switch на factory-reset машине прошёл без ошибок. После того как ты восстановишь age-key (пункт 2 выше) и запустишь `mise run dot:rebuild`, секреты отрендерятся нормально.

---

## 10. Проверка что всё работает

После прохождения чеклиста:

```bash
# SSH через 1Password Agent
ssh -T git@github.com

# Git с подписью
cd ~/.dotfiles && git log --show-signature -1

# SOPS расшифровка секретов
sops -d modules/resticprofile/secrets.yaml

# Повторный rebuild — должен отработать чисто, без пропусков sops-templates
mise run dot:rebuild

# Karabiner / Hammerspoon / Aerospace — запустить и проверить что shortcuts работают
```

Если всё выше выдаёт success — машина в полностью восстановленном состоянии.

---

## Что принципиально нельзя автоматизировать и почему

- **TCC permissions** (Accessibility, Input Monitoring, Full Disk Access, Screen Recording) — база `/Library/Application Support/com.apple.TCC/TCC.db` защищена SIP. Запись туда напрямую невозможна с macOS 10.14+. Единственный автоматический путь — MDM profile с подписанным `PPPC payload`, доставляемый через Apple Business Manager. Для личного Mac это оверкилл.
- **`mas signin`** — Apple убрала API в macOS 10.13+, только ручной логин через App Store GUI
- **iCloud / Apple ID** — защищено 2FA, интерактивный флоу нельзя скриптовать
- **1Password initial signin** — защищено Secret Key + Master Password, интерактивно
- **Tailscale initial auth** — SSO через браузер, интерактивно

Итого: реальный минимум ручных шагов = ~5-7 минут кликов в System Settings после запуска `bootstrap.sh`.

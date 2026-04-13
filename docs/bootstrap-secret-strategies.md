# Bootstrap secret strategies — варианты доставки master-ключа на новый хост

Документ фиксирует варианты решения **bootstrap-проблемы** для dotfiles: как получить master-секрет (age-ключ для SOPS, SSH-ключ) на свежеустановленном macOS, чтобы потом раскрутить остальные секреты декларативно через `sops-templates`.

## Контекст

После factory reset Mac у тебя ничего нет: ни ключей, ни авторизаций, ни установленного софта. Весь дальнейший pipeline `nix-darwin switch` → `sops decrypt` → `envsubst` зависит от того, что в `~/.config/sops/age/keys.txt` появился правильный age-ключ. Вопрос: **откуда его взять**.

Любой вариант сводится к схеме «есть один внешний источник истины, к которому ты так или иначе авторизуешься на новой машине». Дальше всё автоматизируется. Различия между вариантами — только в **цепочке доверия** и **chicken-and-egg** проблемах.

---

## Текущий выбор: 1Password CLI

**Используется сейчас.** age-ключ хранится в 1Password как Secure Note, забирается через `op read 'op://Private/sops-age-key/private key'` (см. задачу `dot:bootstrap-age-key` в [dot.toml](../dot.toml)).

**Почему это правильный выбор сейчас:**
- 1Password — основной password manager пользователя, всё равно ставится первым делом на любой новый Mac
- Биометрия (Touch ID), мобайл, GUI — UX лучший в классе
- Никакой дополнительной инфраструктуры
- Цепочка bootstrap: `brew install 1password 1password-cli` → авторизация в GUI → `op signin` в терминале → `op read`

**Минусы (которые есть у любой альтернативы):**
- Зависимость от серверов AgileBits
- Интерактивный signin при первом запуске на новой машине
- 2FA требует второе устройство

---

## Альтернатива на будущее: Tailscale + selfhost secret manager

**Идея.** Иметь второй always-on хост дома (Raspberry Pi, NAS, мини-PC, старый Mac mini) с self-hosted secret manager (Vaultwarden / Infisical / OpenBao). Новый Mac подключается к домашнему хосту через Tailscale tailnet и забирает секреты по приватному адресу.

### Как работает Tailscale tailnet

Tailscale — это zero-config mesh-VPN на базе WireGuard. **Не путать с локалкой**: работает откуда угодно в интернете, но устройства выглядят как соседи в одной подсети.

- Каждое устройство получает приватный IP `100.x.y.z` и DNS-имя `<hostname>.<tailnet>.ts.net`
- Авторизация через SSO (Google/GitHub/Apple)
- E2E шифрование WireGuard, серверы Tailscale используются только для координации (NAT traversal)
- Бесплатный tier до 100 устройств для личного использования

### Flow на свежем MBP

```
[свежий MBP]                                  [home-server.tailnet.ts.net]
     |                                                       |
     | brew install tailscale                                |
     | sudo tailscale up  (SSO в браузере)                   |
     | tailscale status   (получили 100.x.y.z)               |
     |                                                       |
     | bw config server https://vault.home.tailnet.ts.net    |
     | bw login                                              |
     | bw get notes age-sops-key  ------------------------>  |
     | <-------------------- age-key --------------------    |
     |                                                       |
     | echo $age_key > ~/.config/sops/age/keys.txt           |
     | (дальше обычный nix-darwin switch + sops)             |
```

### Варианты secret manager на домашнем хосте

| Решение | Сложность | Заметки |
|---|---|---|
| **Vaultwarden** | минимальная (1 docker container) | Bitwarden-совместимый, есть `bw` CLI и мобайл клиенты, может полностью заменить 1Password |
| **Infisical** (selfhost) | средняя | Заточен под env vars и dev-секреты, есть CLI |
| **OpenBao** (форк HashiCorp Vault) | высокая | Enterprise vault, dynamic secrets, audit log — оверкилл для dotfiles |

Для dotfiles — **Vaultwarden** оптимален: один docker container, знакомый UX через Bitwarden mobile app, `bw` CLI близок к `op`.

### Плюсы

- Полный контроль, никаких third-party серверов
- Tailscale ACL позволяет жёстко ограничить доступ (MBP → vault разрешён, MBP → NFS запрещён)
- Tailnet универсален — после bootstrap можно ходить на домашние сервисы (NAS, мониторинг, медиа) откуда угодно
- Tailscale SSH в подарок — `ssh home-server` без `~/.ssh/config` и ключей, авторизация через tailnet identity
- Бесплатно для личного использования

### Минусы и почему это **не** решает chicken-and-egg

**Главное:** этот вариант **не убирает** необходимость интерактивного шага на bootstrap. Цепочки сравнимы по длине:

```
1Password:  brew install 1password-cli → op signin (2FA) → op read
Tailscale:  brew install tailscale → tailscale up (SSO в браузере) → bw login → bw get
```

В обоих случаях нужно: установить CLI, пройти интерактивную авторизацию, забрать секрет. Разница только в том, **кто хостит** конечную точку доверия.

Дополнительные минусы:
- **Нужен always-on хост дома** — деньги на электричество, время на поддержку, точка отказа
- **Нужно бэкапить домашний сервер** — иначе при его смерти теряешь все секреты (нужен ещё один уровень бэкапов через restic на S3/B2)
- **Сетевые задержки** при первом bootstrap из удалённой локации (NAT traversal через DERP relay)
- **Tailscale тоже надо bootstrapнуть** — chicken-egg переносится с 1Password на Tailscale + SSO провайдер
- **Точка отказа добавляется** — больше движущихся частей: Tailscale координатор + домашний сервер + Vaultwarden + диск + сеть
- **1Password всё равно остаётся** как primary password manager — Vaultwarden его не вытесняет в краткосроке

### Когда это реально стоит того

- У тебя **уже** хостится домашняя инфра (NAS, Home Assistant, *arr stack, медиа)
- Секреты нужны не только для dotfiles, но и для кучи self-hosted сервисов, CI, скриптов
- Принципиальная позиция «ничего не отдавать в облако третьим сторонам»
- Есть желание поднять unified vault для семьи без подписки

### Вердикт для текущего сетапа

**Пока не нужно.** В [hosts/](../hosts) нет постоянного домашнего сервера с этой ролью (`lasthaze-home` — отдельный Linux хост, но он не позиционируется как always-on secret-сервер). Заводить целый self-host стек ради одного age-ключа, который восстанавливается раз в 2 года, — overengineering. 1Password остаётся primary вариантом.

---

## Альтернатива на будущее: YubiKey + age-plugin-yubikey

**Самая интересная альтернатива.** Использует [age-plugin-yubikey](https://github.com/str4d/age-plugin-yubikey) — приватный age-ключ генерируется и живёт **на железке YubiKey**, никогда её не покидает.

### Как работает

1. На YubiKey генерируется PIV slot с приватным ключом (curve P-256)
2. `age-plugin-yubikey` экспортирует **identity stub** — крошечный файл-указатель, который можно безопасно хранить где угодно
3. Когда age расшифровывает файл, он зовёт plugin, plugin зовёт YubiKey, YubiKey требует касания (touch) для подтверждения операции
4. Приватный ключ физически невозможно вытащить с железки

### Flow на свежем MBP

```
1. Установить age-plugin-yubikey:
   nix-shell -p age-plugin-yubikey

2. Вставить YubiKey

3. Скопировать identity stub на машину
   (можно держать прямо в репо — это публичная информация):
   cp ~/.dotfiles/secrets/yubikey-identity.txt ~/.config/sops/age/keys.txt

4. Любая sops/age операция автоматически дёргает YubiKey,
   YubiKey мигает, ты касаешься его → расшифровка работает
```

### Преимущества над 1Password

- **Убирает chicken-and-egg почти полностью** — не нужен `op signin`, не нужен интернет, не нужен 2FA через мобайл
- **Identity stub можно коммитить в git** — это не секрет, расшифровать без физического YubiKey невозможно
- **Phishing-resistant** — приватный ключ нельзя украсть удалённо никаким способом
- **Работает оффлайн** — в самолёте, без интернета, без серверов AgileBits и Tailscale
- **Touch-to-confirm** — каждая операция расшифровки требует физического касания, защита от malware на машине

### Минусы

- **Стоимость** — YubiKey 5 NFC ~$50-70
- **Single point of failure** — потерял ключ = потерял доступ. Решение: **второй YubiKey как backup в сейфе/у родителей**, оба прописаны как recipients в `.sops.yaml`
- **Не заменяет 1Password** для обычных паролей сайтов — это специализированный hardware token, не password manager
- **Plugin ставится отдельно** через nix — нельзя вызвать `age` без `age-plugin-yubikey` на новой машине

### Вердикт

**Целевой вариант на будущее.** После покупки YubiKey стоит мигрировать bootstrap age-ключа именно туда:

- Купить **два** YubiKey (primary + backup)
- Сгенерировать identity на обоих
- Перешифровать все `secrets.yaml` через `sops updatekeys` с двумя age recipients (оба YubiKey)
- Backup YubiKey убрать в физически безопасное место
- 1Password оставить как daily-driver password manager (не для bootstrap age-ключа)

Это **самый чистый** вариант с точки зрения цепочки доверия: zero network dependencies, zero интерактивных авторизаций, zero third-party серверов в bootstrap-флоу.

---

## Резюме: эволюция стратегии

| Этап | Bootstrap age-key | Daily password manager | SSH ключи |
|---|---|---|---|
| **Сейчас** | 1Password CLI (`op read`) | 1Password GUI | 1Password SSH Agent (рекомендуется) |
| **После покупки YubiKey** | YubiKey + age-plugin-yubikey | 1Password GUI | 1Password SSH Agent или YubiKey PIV |
| **Если появится домашний сервер** | YubiKey (primary) + Vaultwarden (backup пароля от vault) | Vaultwarden или 1Password | как раньше |

Главный принцип: **минимизировать количество интерактивных шагов на bootstrap** и **избегать single point of failure**. YubiKey + бэкап-YubiKey в сейфе достигает обоих целей лучше всего.

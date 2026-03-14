<!-- fullWidth: true tocVisible: false tableWrap: true -->
# Backup: restic copy (Local → B2)

Бэкап-система на базе **resticprofile** с использованием **restic copy**.

**Хост:** MacBook (lasthaze-mbp)\
**Метод:** restic copy — backup в локальный repo, затем copy в B2 (см. [выбор стратегии](strategies.md))\
**CLI:** `[rp](../mise-cli-wrappers.md)` — обёртка над mise tasks

---

## Архитектура

```cpp
MacBook
  [~/Development, ~/.ssh, ~/.config, ...]
      │
      ▼
  restic backup (каждые 30 мин / ежедневно 02:00)
      │
      ▼
  [Local repo: ~/Backups/restic/main]
      │
      ▼ restic copy (каждые 3 часа)
      │
  [B2 repo: b2:yoshintame:restic/main]
```

Локальный репозиторий — хаб. Все бэкапы сначала попадают в него, затем `restic copy` копирует снепшоты в B2.

### Почему restic copy

- Файловая система сканируется **один раз** (backup только в локальный repo)
- Оба репозитория **полностью независимы** — разные мастер-ключи, самодостаточное восстановление
- **Нативный механизм restic** — атомарное копирование снепшотов
- **Независимая retention** — локальный repo плотнее (быстрый rollback), B2 — длиннее (долгосрочное хранение)
- **Расширяемость** — добавление нового хранилища = ещё одна секция `copy`

---

## Хранилища (Repositories)

Один репозиторий на каждое место назначения. Все профили (dev, home) попадают в один repo — максимальная дедупликация.

| Хранилище | URI                         | Назначение                 |
| --------- | --------------------------- | -------------------------- |
| Local     | `local:~/Backups/restic/main` | Быстрый доступ, rollback   |
| B2        | `b2:yoshintame:restic/main` | Offsite, disaster recovery |

**Lock-файлы:**

- `/tmp/resticprofile-local.lock` — сериализует операции на локальном repo
- `/tmp/resticprofile-b2.lock` — сериализует операции на B2 repo

---

## Профили данных

### dev (`~/Development`)

Весь каталог с проектами. Бэкапится часто — код меняется постоянно, git не покрывает незакоммиченные изменения, локальные конфиги IDE.

**Тег:** `dev`\
**Частота:** каждые 30 минут

### home (конфиги, документы)

Критически важные файлы, которые меняются реже.

**Тег:** `home`\
**Частота:** ежедневно в 02:00\
**Что входит:**

| Путь                           | Описание                     |
| ------------------------------ | ---------------------------- |
| `.ssh`                         | SSH-ключи                    |
| `.config`                      | Конфигурации приложений      |
| `.dotfiles`                    | Репозиторий dotfiles         |
| `Documents`                    | Документы                    |
| `Pictures`                     | Фотографии                   |
| `remnote`                      | RemNote данные               |
| `Backups`                      | Другие бэкапы (кроме restic) |
| `.gnupg`                       | GPG-ключи                    |
| `.zsh_history`                 | История zsh                  |
| `.bash_history`                | История bash                 |
| `.history.db`                  | Atuin history                |
| `.local/share/fish/fish_history` | История fish                 |

### quicksave (текущая директория)

Полный бэкап текущей директории без исключений. Используется через `rp save` / `rp load`.

**Тег:** `quicksave`\
**Частота:** по запросу

### Глобальные исключения

```
**/node_modules
**/.venv
**/.DS_Store
**/Backups/restic/**
**/.config/resticprofile/*.key
```

Плюс `exclude-caches: true` — исключает директории с `CACHEDIR.TAG`.

---

## Структура профилей (profiles.yaml)

### Иерархия наследования

```
base              (password-file, exclude)
  ├── local       (repository local, lock, mkdir)
  │     ├── default
  │     ├── dev           (source ~/Development, schedule */30, HC hooks)
  │     ├── home          (source home dirs, schedule 02:00, HC hooks)
  │     ├── local-to-b2   (copy section → B2, schedule */3h, HC hooks)
  │     ├── local-ops     (forget/prune local, check local, HC hooks)
  │     └── quicksave     (source $RP_SAVE_DIR)
  │
  └── b2          (repository b2, env-file, lock)
        └── b2-ops        (forget/prune B2, check B2 --read-data-subset=5%, HC hooks)
```

Хуки (`run-after`, `run-after-fail`) определены в каждом leaf-профиле — у каждого свой HC UUID.

### Группы профилей

| Группа      | Профили           | Использование                  |
| ----------- | ----------------- | ------------------------------ |
| `all`       | dev, home         | Запустить все backup-и         |
| `maintenance` | local-ops, b2-ops | Forget+prune на всех repo      |
| `check`     | local-ops, b2-ops | Проверка целостности всех repo |

---

## Retention (политика хранения)

### Local repo

| Параметр     | Значение | Эффект                                |
| ------------ | -------- | ------------------------------------- |
| `keep-within` | `1d`     | Все снепшоты за последние 24ч         |
| `keep-daily` | `14`     | По одному снепшоту в день за 2 недели |
| `keep-weekly` | `8`      | По одному в неделю за 2 месяца        |
| `keep-monthly` | `6`      | По одному в месяц за полгода          |

### B2 repo

| Параметр     | Значение | Эффект                       |
| ------------ | -------- | ---------------------------- |
| `keep-daily` | `30`     | Ежедневно за последний месяц |
| `keep-weekly` | `12`     | Еженедельно за 3 месяца      |
| `keep-monthly` | `12`     | Ежемесячно за год            |
| `keep-yearly` | `3`      | Ежегодно за 3 года           |

Retention применяется с `group-by: host,tags`. Forget запускается еженедельно, prune — сразу после forget.

---

## Scheduling (расписание)

| Job                | Профиль     | Расписание             | Описание          |
| ------------------ | ----------- | ---------------------- | ----------------- |
| Dev backup         | `dev`       | `*:00,30`              | Каждые 30 мин     |
| Home backup        | `home`      | `2:00`                 | Ежедневно в 02:00 |
| Copy → B2          | `local-to-b2` | `0,3,6,9,12,15,18,21:00` | Каждые 3 часа     |
| Forget+prune local | `local-ops` | `sun 4:00`             | Воскресенье 04:00 |
| Forget+prune B2    | `b2-ops`    | `sun 5:00`             | Воскресенье 05:00 |
| Check local        | `local-ops` | `*-*-01 6:00`          | 1-е число месяца  |
| Check B2           | `b2-ops`    | `*-*-01 7:00`          | 1-е число месяца  |
| Log rotation       | logrotate   | `0 7 * * *` (cron)     | Ежедневно в 07:00 |

### Реализация расписания

resticprofile использует **cron** (`scheduler: crond`). Формат расписания — systemd-calendar — resticprofile конвертирует его в cron-формат автоматически.

Управление расписанием — через `rp schedule`:

```fish
rp schedule up       # включить все расписания + logrotate
rp schedule down     # отключить все расписания
rp schedule reload   # переприменить расписания
rp schedule status   # показать статус
```

### Почему cron вместо launchd

Launchd-агенты на macOS создаются с `LimitLoadToSessionType: Background` — при входе в GUI (Aqua) могут не загружаться. Cron не зависит от типа сессии и работает стабильно.

**Нюансы cron на macOS:**

- `/usr/sbin/cron` может потребовать **Full Disk Access** в System Settings → Privacy & Security
- cron не наследует PATH — resticprofile записывает полный путь к бинарнику
- Формат расписания в `profiles.yaml` — systemd-calendar (не cron-синтаксис); step-нотация (`*/3`) не поддерживается

### Поведение при sleep/lid close

cron **не запускает пропущенные задачи** после пробуждения. На практике это приемлемо — dev backup каждые 30 мин, copy при следующем запуске скопирует всё накопившееся.

---

## Логи и ротация

Логи пишутся в `~/.local/share/resticprofile/logs/`:

| Job                | Лог-файл                           |
| ------------------ | ---------------------------------- |
| Dev backup         | `resticprofile-dev.log`            |
| Home backup        | `resticprofile-home.log`           |
| Copy to B2         | `resticprofile-local-to-b2.log`    |
| Local forget/prune | `resticprofile-local-ops-forget.log` |
| Local check        | `resticprofile-local-ops-check.log` |
| B2 forget/prune    | `resticprofile-b2-ops-forget.log`  |
| B2 check           | `resticprofile-b2-ops-check.log`   |

Ротация логов — через **logrotate** (cron ежедневно в 07:00):

- Ротация при размере > 5M
- Хранение 14 ротированных файлов
- Сжатие с задержкой (`delaycompress`)

Просмотр логов: `rp log dev`, `rp log copy`, `rp log b2` и т.д.

---

## Alerting (Healthchecks.io)

### Два уровня

| Уровень    | Механизм             | Что детектирует                             | Каналы           |
| ---------- | -------------------- | ------------------------------------------- | ---------------- |
| **Active** | `run-after-fail`     | Ошибка операции (backup/copy/forget)        | HC.io → Telegram |
| **Passive** | Healthchecks.io пинг | Операция не запустилась (dead-man's switch) | HC.io → Telegram |

Уведомления делегированы **Healthchecks.io** — Telegram-интеграция настроена в дашборде HC.io. Resticprofile пингует HC.io через `curl` в хуках `run-after` / `run-after-fail`.

### Хуки в профилях

Каждый leaf-профиль имеет свои хуки с вшитым UUID:

```yaml
run-after:
  - "curl -fsS -m 10 --retry 5 https://hc-ping.com/<UUID>"
run-after-fail:
  - "curl -fsS -m 10 --retry 5 https://hc-ping.com/<UUID>/fail"
```

UUID-ы подставляются из SOPS-секретов при рендеринге `profiles.tmpl.yaml` → `profiles.yaml`.

### Проверки HC.io

| Имя                  | Period   | Grace   | Профиль      |
| -------------------- | -------- | ------- | ------------ |
| `development-backup` | 1 час    | 1 час   | dev          |
| `home-backup`        | 1 день   | 6 часов | home         |
| `copy-to-b2`         | 3 часа   | 3 часа  | local-to-b2  |
| `maint-local`        | 1 неделя | 1 день  | local-ops    |
| `maint-b2`           | 1 неделя | 1 день  | b2-ops       |

### Тестирование

```fish
rp test-notify success        # пинг success для dev
rp test-notify fail            # пинг fail для dev
rp test-notify success home    # пинг success для home
```

---

## Секреты и безопасность

Секреты управляются через **SOPS** — зашифрованные шаблоны рендерятся при сборке dotfiles. Подробнее: [secrets-management.md](../secrets-management.md).

### Файлы секретов

| Файл                                    | Источник                    | Содержимое                    |
| ---------------------------------------- | --------------------------- | ----------------------------- |
| `~/.config/resticprofile/profiles.yaml` | `profiles.tmpl.yaml` + SOPS | Конфиг с HC UUID-ами         |
| `~/.config/resticprofile/repo.key`      | `repo.key.tmpl` + SOPS      | Пароль репозитория            |
| `~/.config/resticprofile/b2.env`        | `b2.env.tmpl` + SOPS        | B2_ACCOUNT_ID, B2_ACCOUNT_KEY |
| `~/.config/resticprofile/hc.env`        | `hc.env.tmpl` + SOPS        | HC UUID-ы (для test-notify)   |

Конфигурация в `default.nix`:

```nix
sopsTemplates.render = {
  "~/.config/resticprofile/profiles.yaml" = {
    template = "modules/resticprofile/config/profiles.tmpl.yaml";
    secretsFile = "modules/resticprofile/secrets.yaml";
    variables = [ "HC_DEVELOPMENT_BACKUP_UUID" "HC_HOME_BACKUP_UUID" ... ];
  };
  "~/.config/resticprofile/hc.env" = { ... };
  "~/.config/resticprofile/b2.env" = { ... };
  "~/.config/resticprofile/repo.key" = { ... };
};
```

Опция `variables` — envsubst заменяет только указанные `${HC_*}` переменные, оставляя прочие `$` (как `$ERROR_MESSAGE`) нетронутыми.

### Резервное хранение

Пароль от repo и B2 credentials должны быть сохранены **вне** ноутбука (password manager). Без пароля от repo данные невосстановимы.

---

## CLI: `rp` (mise wrapper)

Все команды доступны через обёртку `rp` на базе [mise tasks](../mise-cli-wrappers.md).

### Backup

```fish
rp backup             # backup all (default)
rp backup dev         # backup только dev
rp backup home        # backup только home
rp push               # copy local → B2
rp backup-and-push    # full cycle: backup all + copy to B2
```

### Снепшоты и статистика

```fish
rp snapshots          # list local snapshots
rp snapshots b2       # list B2 snapshots
rp snapshots local dev  # local snapshots с тегом dev
rp stats              # stats для dev (default)
rp stats b2           # stats для B2
rp diff               # diff последних двух снепшотов dev
rp diff home          # diff последних двух снепшотов home
```

### Quick save/load (текущая директория)

```fish
rp save               # полный бэкап текущей директории
rp load               # восстановить текущую директорию из последнего snapshot
rp load --no-clean    # восстановить без удаления существующих файлов
```

### Restore

```fish
rp restore latest /tmp/restore /path/to/include        # restore файла из dev
rp restore latest /tmp/restore /path/to/include home   # restore из home
rp restore-from-b2                                     # restore home из B2 в /tmp/home-restore
rp restore-from-b2 /tmp/my-restore                     # restore home из B2 в указанную директорию
```

### Обслуживание

```fish
rp maintenance        # forget+prune all
rp maintenance local  # forget+prune только local
rp maintenance b2     # forget+prune только B2
rp check              # проверка целостности all
rp check full         # полная проверка данных local (--read-data)
```

### Расписание

```fish
rp schedule up        # включить все расписания
rp schedule down      # отключить все расписания
rp schedule reload    # переприменить расписания
rp schedule status    # показать статус
```

### Логи и уведомления

```fish
rp log dev            # tail лог dev backup
rp log home           # tail лог home backup
rp log copy           # tail лог copy to B2
rp log local          # tail лог local forget/prune
rp log b2             # tail лог B2 forget/prune
rp rotate-logs        # принудительная ротация логов
rp test-notify success       # тест HC.io пинг (dev)
rp test-notify fail          # тест HC.io fail-пинг (dev)
rp test-notify success home  # тест HC.io пинг (home)
```

---

## Disaster Recovery

### Сценарий: MacBook потерян/сломан

Необходимые секреты (хранить отдельно от ноутбука):

- Пароль репозитория (`repo.key`)
- B2 credentials (`B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`)
- SOPS age key (для расшифровки secrets.yaml)

### Шаг 1: Восстановить файлы из B2

```bash
brew install restic

export B2_ACCOUNT_ID="..."
export B2_ACCOUNT_KEY="..."
restic -r b2:yoshintame:restic/main -p repo.key snapshots

# Восстановить home
restic -r b2:yoshintame:restic/main -p repo.key restore latest --tag home --target ~/

# Восстановить development
restic -r b2:yoshintame:restic/main -p repo.key restore latest --tag dev --target ~/
```

### Шаг 2: Воссоздать локальный repo

**Вариант A — свежий старт** (быстро, без локальной истории):

```bash
mkdir -p ~/Backups/restic
restic init --repo ~/Backups/restic/main --password-file ~/.config/resticprofile/repo.key
```

**Вариант B — перенести историю из B2** (сохраняет историю, долго):

```bash
mkdir -p ~/Backups/restic

# Инициализировать с chunker-params из B2
restic init \
  --repo ~/Backups/restic/main \
  --password-file ~/.config/resticprofile/repo.key \
  --copy-chunker-params \
  --repo2 b2:yoshintame:restic/main \
  --password-file2 ~/.config/resticprofile/repo.key

# Скопировать все снепшоты из B2 в локальный
restic copy \
  --repo b2:yoshintame:restic/main \
  --repo2 ~/Backups/restic/main \
  --password-file ~/.config/resticprofile/repo.key \
  --password-file2 ~/.config/resticprofile/repo.key
```

### Шаг 3: Развернуть dotfiles и resticprofile

```bash
git clone git@github.com:yoshintame/.dotfiles.git ~/.dotfiles
# nix rebuild — SOPS автоматически отрендерит секреты
sudo darwin-rebuild switch --flake ~/.dotfiles
rp schedule up
```

---

## Структура файлов модуля

```
modules/resticprofile/
  config/
    profiles.tmpl.yaml      # SOPS-шаблон для profiles.yaml (HC UUIDs)
    rp.toml                 # mise tasks для CLI (→ ~/.config/mise/tasks/)
    logrotate.conf          # конфиг ротации логов (→ ~/.config/resticprofile/)
    hc.env.tmpl             # SOPS-шаблон для hc.env (HC UUIDs для test-notify)
    b2.env.tmpl             # SOPS-шаблон для b2.env
    repo.key.tmpl           # SOPS-шаблон для repo.key
  secrets.yaml              # зашифрованные секреты (SOPS)
  default.nix               # ссылки и SOPS-рендеринг

modules/fish/config/
  functions/rp.fish         # fish-обёртка для rp
  completions/rp.fish       # автодополнение для rp
```

## См. также

- [Сравнение стратегий бэкапа](strategies.md) — анализ подходов local+B2
- [Mise CLI wrappers](../mise-cli-wrappers.md) — паттерн создания CLI-обёрток через mise
- [Управление секретами](../secrets-management.md) — подходы к хранению секретов

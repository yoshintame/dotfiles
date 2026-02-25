# Backup Plan: restic copy (Local → B2)

Полное описание бэкап-стратегии на базе **resticprofile** с использованием **restic copy**.

**Хост:** MacBook (lasthaze-mbp)
**Метод:** Стратегия 2 — restic copy (backup в локальный repo, затем copy в B2)
**Планы:** добавление Home Lab сервера как третьего хранилища

---

## Содержание

1. [Архитектура](#1-архитектура)
2. [Хранилища](#2-хранилища-repositories)
3. [Профили данных](#3-профили-данных)
4. [Поток операций](#4-поток-операций)
5. [Retention](#5-retention-политика-хранения)
6. [Scheduling](#6-scheduling-расписание)
7. [Alerting (Apprise)](#7-alerting-apprise)
8. [User Guide — как пользоваться](#8-user-guide--как-пользоваться)
9. [Disaster Recovery](#9-disaster-recovery)
10. [Фаза 2: Home Lab Server](#10-фаза-2-home-lab-server)
11. [Секреты и безопасность](#11-секреты-и-безопасность)
12. [Структура профилей](#12-структура-профилей-profilesyaml)
13. [Мониторинг и проверка](#13-мониторинг-и-проверка)
14. [Миграция с предыдущей стратегии](#14-миграция-с-предыдущей-стратегии)

---

## 1. Архитектура

```
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
  [B2 repo: b2:blackgaze:restic/main]
      │
      ▼ restic copy (фаза 2)
      │
  [Home Lab: rest:http://server:8000/main]  ← будущее
```

Ключевой принцип: **локальный репозиторий — хаб**. Все бэкапы сначала попадают в него, затем `restic copy` веерно копирует снепшоты в удалённые хранилища.

### Почему restic copy

- Файловая система сканируется **один раз** (backup только в локальный repo)
- Оба репозитория **полностью независимы** — разные мастер-ключи, самодостаточное восстановление
- **Нативный механизм restic** — атомарное копирование снепшотов, нет риска промежуточных состояний
- **Независимая retention** — локальный repo может быть плотнее (для быстрого rollback), B2 — длиннее (для долгосрочного хранения)
- **Расширяемость** — добавление нового хранилища = ещё одна секция `copy`

### Инициализация B2-репозитория

При первом запуске B2-репозиторий инициализируется с `--copy-chunker-params` из локального репозитория. Это гарантирует одинаковую разбивку на чанки — без этого каждый copy будет копировать все данные заново.

В resticprofile это обеспечивается настройкой `initialize-copy-chunker-params: true` в секции `copy`.

---

## 2. Хранилища (Repositories)

Один репозиторий на каждое место назначения. Все профили данных (development, home) попадают в один и тот же repo — это даёт максимальную дедупликацию.


| Хранилище    | URI                            | Назначение                  |
| ----------------------- | -------------------------------- | --------------------------------------- |
| Local                 | `local:~/Backups/restic/main`  | Быстрый доступ, rollback |
| B2                    | `b2:blackgaze:restic/main`     | Offsite, disaster recovery            |
| Home Lab (фаза 2) | `rest:http://server:8000/main` | Ещё одна offsite-копия    |

**Lock-файлы:**

- `/tmp/resticprofile-local.lock` — сериализует все операции на локальном repo
- `/tmp/resticprofile-b2.lock` — сериализует все операции на B2 repo

Lock-файлы resticprofile гарантируют, что одновременно на одном repo работает только одна операция (backup, copy, forget, prune).

---

## 3. Профили данных

### 3.1 Development (`~/Development`)

Весь каталог с проектами. Бэкапится часто — код меняется постоянно, git не покрывает незакоммиченные изменения, локальные конфиги IDE, базы данных dev-окружений.

**Тег:** `development`
**Частота backup:** каждые 30 минут
**Исключения:** `node_modules`, `.venv`, `.DS_Store`, кэши

### 3.2 Home (конфиги, документы, фото)

Критически важные файлы, которые меняются реже, но потеря которых наиболее болезненна.

**Тег:** `home`
**Частота backup:** ежедневно в 02:00
**Что входит:**


| Путь                         | Описание                              |
| ---------------------------------- | ----------------------------------------------- |
| `.ssh`                           | SSH-ключи                                |
| `.config`                        | Конфигурации приложений |
| `.dotfiles`                      | Репозиторий dotfiles               |
| `Documents`                      | Документы                            |
| `Pictures`                       | Фотографии                          |
| `remnote`                        | RemNote данные                          |
| `Backups`                        | Другие бэкапы (кроме restic) |
| `.gnupg`                         | GPG-ключи                                |
| `.zsh_history`                   | История zsh                            |
| `.bash_history`                  | История bash                           |
| `.history.db`                    | Atuin history                                 |
| `.local/share/fish/fish_history` | История fish                           |

### Глобальные исключения (все профили)

```
**/node_modules
**/.venv
**/.DS_Store
/Backups/restic/**
/.config/resticprofile/*.key
```

Плюс `exclude-caches: true` — исключает директории с `CACHEDIR.TAG`.

---

## 4. Поток операций

### 4.1 Backup (каждые 30 мин / ежедневно)

```
[файлы] → restic backup → [local repo]
                              │
                    success? ──┤
                    │ yes      │ no
                    ▼          ▼
              ping HC.io   notify (TG + email)
              TG success
```

1. restic backup сканирует файлы и записывает снепшот в локальный repo
2. При успехе — Apprise отправляет TG-уведомление + пингует HC.io (dead-man's switch)
3. При ошибке — Apprise отправляет TG + email + fail-пинг в HC.io

### 4.2 Copy (каждые 3 часа)

```
[local repo] → restic copy → [B2 repo]
                                │
                      success? ──┤
                      │ yes      │ no
                      ▼          ▼
                ping HC.io   notify (TG + email)
```

1. `restic copy` находит снепшоты, которых нет в B2, и копирует их
2. Данные перешифровываются (re-encryption) мастер-ключом B2 repo
3. Инкрементально — передаются только новые блобы

### 4.3 Maintenance (еженедельно, воскресенье)

```
04:00  forget + prune (local)  — удаление лишних снепшотов по retention-политике
05:00  forget + prune (B2)     — удаление лишних снепшотов по retention-политике B2
```

`prune: true` в секции `forget` объединяет удаление снепшотов и очистку данных за один проход.

### 4.4 Check (ежемесячно, 1-е число)

```
06:00  restic check (local)       — проверка структуры и целостности
07:00  restic check (B2)          — структура + 5% данных (экономия трафика)
```

Полная проверка данных (`--read-data`) — раз в 6 месяцев вручную для локального repo. Для B2 — `--read-data-subset=5%` ежемесячно (проверяет случайные 5% блобов, не тратит весь download-бюджет).

---

## 5. Retention (политика хранения)

### Принципы

- **Локальный repo** — плотнее по времени, короче по глубине (диск ограничен)
- **B2** — реже по времени, глубже по истории (B2 стоит $0.005/GB/мес — дёшево хранить долго)
- Retention применяется с `group-by: host,tags` — каждая комбинация хост+тег обрабатывается отдельно
- Forget запускается еженедельно, prune — сразу после forget

### Local repo


| Параметр | Значение | Эффект                                                                                |
| ------------------ | ------------------ | --------------------------------------------------------------------------------------------- |
| `keep-within`    | `1d`             | Все снепшоты за последние 24ч (для dev — ~48 снепшотов) |
| `keep-daily`     | `14`             | По одному снепшоту в день за 2 недели                          |
| `keep-weekly`    | `8`              | По одному в неделю за 2 месяца                                       |
| `keep-monthly`   | `6`              | По одному в месяц за полгода                                         |

**Для development:** после 24 часов 30-минутные снепшоты прореживаются до ежедневных. Это даёт мгновенный rollback для свежей работы и разумную историю для старой.

**Для home:** backup ежедневный, поэтому `keep-within: 1d` не влияет. Фактически: 14 ежедневных, 8 еженедельных, 6 ежемесячных.

### B2 repo


| Параметр | Значение | Эффект                                          |
| ------------------ | ------------------ | ------------------------------------------------------- |
| `keep-daily`     | `30`             | Ежедневно за последний месяц |
| `keep-weekly`    | `12`             | Еженедельно за 3 месяца            |
| `keep-monthly`   | `12`             | Ежемесячно за год                      |
| `keep-yearly`    | `3`              | Ежегодно за 3 года                      |

B2 хранит более длинную историю. Даже если локальный repo потерян — в B2 есть год ежемесячных снепшотов.

### Оценка объёма

Для типичного рабочего ноутбука с ~50 GB данных:

- Локальный repo: ~60-80 GB (с дедупликацией и множеством снепшотов)
- B2 repo: ~55-70 GB (меньше снепшотов, но длиннее история)
- Ежемесячная стоимость B2: ~$0.30-0.40

---

## 6. Scheduling (расписание)

### Расписание (MacBook)


| Job                | Профиль | Расписание          | Описание                   |
| -------------------- | ---------------- | ------------------------------- | ------------------------------------ |
| Dev backup         | `development`  | `*:00,30` (каждые 30м) | Каждые 30 мин             |
| Home backup        | `home`         | `2:00`                        | Ежедневно в 02:00        |
| Copy → B2         | `copy-to-b2`   | `0,3,6,9,12,15,18,21:00`      | Каждые 3 часа            |
| Forget+prune local | `maint-local`  | `sun 4:00`                    | Воскресенье 04:00       |
| Forget+prune B2    | `maint-b2`     | `sun 5:00`                    | Воскресенье 05:00       |
| Check local        | `check-local`  | `*-*-01 6:00`                 | 1-е число месяца 06:00 |
| Check B2           | `check-b2`     | `*-*-01 7:00`                 | 1-е число месяца 07:00 |

### Реализация расписания

resticprofile использует встроенный scheduler, который на macOS создаёт launchd-агенты автоматически. Формат расписания — systemd-calendar (`*:00,30` — каждые 30 минут; `2:00` — ежедневно в 02:00).

После любого изменения конфигурации расписаний:

```bash
resticprofile schedule --all
```

Это создаёт/обновляет все plist-файлы в `~/Library/LaunchAgents/`.

### Порядок и зависимости

```
backup (частый)  ──→  copy (каждые 3ч)  ──→  maintenance (еженед.)  ──→  check (ежемес.)
```

- Copy запускается **независимо от backup** по своему расписанию. Он копирует все новые снепшоты, накопившиеся с последнего copy.
- Maintenance (forget+prune) запускается **после copy** по времени — воскресенье в 04:00 (local) и 05:00 (B2). К этому моменту все снепшоты уже скопированы в B2.
- Lock-файлы resticprofile гарантируют, что если backup и copy пересекутся по времени, один подождёт другого.

### Поведение при sleep/lid close

macOS launchd с `StartCalendarInterval` запустит пропущенные задачи после пробуждения (но только один раз, не «догоняет» все пропуски). Это приемлемо:

- Dev backup каждые 30 мин — пропуск во время сна не критичен (файлы не менялись)
- Copy каждые 3 часа — после пробуждения запустится и скопирует накопившееся
- Maintenance и check — запустятся в ближайшее воскресенье/1-е число после пробуждения

---

## 7. Alerting (Apprise)

### Стратегия: два уровня


| Уровень | Механизм         | Что детектирует                                                 | Каналы     |
| ---------------- | -------------------------- | ------------------------------------------------------------------------------- | ------------------ |
| **Active**     | `run-after-fail` хук  | Ошибка операции (backup/copy/forget/prune)                      | Telegram + Email |
| **Passive**    | Healthchecks.io пинг | Операция не запустилась вообще (dead-man's switch) | Telegram + Email |

**Active alerting** — resticprofile вызывает Apprise при ошибке. Немедленная реакция.

**Passive alerting** — после успешной операции Apprise пингует Healthchecks.io. Если пинг не приходит в ожидаемый интервал, Healthchecks.io сам отправляет алерт через свои каналы. Это покрывает сценарии, когда задача вообще не запустилась (launchd сломался, ноутбук не включался и т.д.).

### Apprise — что это

[Apprise](https://github.com/caronc/apprise) — универсальная библиотека и CLI для уведомлений. Поддерживает 100+ сервисов (Telegram, Email, Slack, Discord, PagerDuty, и др.) через единый конфиг и единый вызов.

Вместо отдельных curl-вызовов для Telegram и msmtp для email — один вызов `apprise --tag backup-fail`, и Apprise сам рассылает по всем зарегистрированным каналам с этим тегом.

### Установка

```bash
brew install apprise
```

### Конфиг: `~/.config/resticprofile/apprise.yaml`

> **Важно:** этот файл содержит токены и пароли, **не коммитить в git**. `chmod 600 ~/.config/resticprofile/apprise.yaml`.

Структура конфига — тег-маршрутизация:


| Тег                          | Куда идёт | Когда                                          |
| --------------------------------- | ------------------- | ----------------------------------------------------- |
| `backup-success`                | Telegram          | Успешный backup/copy/forget/check           |
| `backup-fail`                   | Telegram + Email  | Любая ошибка                             |
| `hc-development-backup-success` | HC.io ping        | Успешный backup профиля`development` |
| `hc-development-backup-fail`    | HC.io fail-ping   | Ошибка backup профиля`development`     |
| `hc-home-backup-success`        | HC.io ping        | Успешный backup профиля`home`        |
| `hc-copy-to-b2-success`         | HC.io ping        | Успешный copy в B2                         |
| `hc-maint-local-success`        | HC.io ping        | Успешный forget/prune local                 |
| `hc-maint-b2-success`           | HC.io ping        | Успешный forget/prune B2                    |

Полный файл конфига (`~/.config/resticprofile/apprise.yaml`):

```yaml
version: 1

urls:
  # Telegram: все события (success + failure)
  - tgram://{TELEGRAM_BOT_TOKEN}/{TELEGRAM_CHAT_ID}/:
      tag:
        - backup-success
        - backup-fail
        - backup-info

  # Email: только failure
  - mailtos://{GMAIL_USER}:{GMAIL_APP_PASSWORD}@smtp.gmail.com:
      to: "{ALERT_TO_EMAIL}"
      name: "Restic Backup Alerts"
      tag:
        - backup-fail

  # Healthchecks.io: development-backup (30-min period, 1h grace)
  - hcs://{HC_PROJECT_UUID}/development-backup:
      tag:
        - hc-development-backup-success
  - hcs://{HC_PROJECT_UUID}/development-backup/fail:
      tag:
        - hc-development-backup-fail

  # Healthchecks.io: home-backup (1-day period, 6h grace)
  - hcs://{HC_PROJECT_UUID}/home-backup:
      tag:
        - hc-home-backup-success
  - hcs://{HC_PROJECT_UUID}/home-backup/fail:
      tag:
        - hc-home-backup-fail

  # Healthchecks.io: copy-to-b2 (3h period, 3h grace)
  - hcs://{HC_PROJECT_UUID}/copy-to-b2:
      tag:
        - hc-copy-to-b2-success
  - hcs://{HC_PROJECT_UUID}/copy-to-b2/fail:
      tag:
        - hc-copy-to-b2-fail

  # Healthchecks.io: maint-local (weekly period, 1-day grace)
  - hcs://{HC_PROJECT_UUID}/maint-local:
      tag:
        - hc-maint-local-success
  - hcs://{HC_PROJECT_UUID}/maint-local/fail:
      tag:
        - hc-maint-local-fail

  # Healthchecks.io: maint-b2 (weekly period, 1-day grace)
  - hcs://{HC_PROJECT_UUID}/maint-b2:
      tag:
        - hc-maint-b2-success
  - hcs://{HC_PROJECT_UUID}/maint-b2/fail:
      tag:
        - hc-maint-b2-fail
```

### Интеграция с resticprofile: как работают хуки

В профиле `base` (`profiles.yaml`) каждая операция имеет два хука:

```yaml
base:
  backup:
    run-after:
      # Один вызов — отправляет в Telegram И пингует HC.io для нужного профиля
      - >-
        apprise
        -c "{{ .Env.HOME }}/.config/resticprofile/apprise.yaml"
        --tag backup-success
        --tag "hc-{{ .Profile.Name }}-backup-success"
        -t "Backup Success: {{ .Profile.Name }}"
        -b "Host: $(hostname -s)\nProfile: {{ .Profile.Name }}\nOperation: backup\nTime: $(date '+%Y-%m-%d %H:%M:%S')"
        -vv
    run-after-fail:
      # Один вызов — отправляет Telegram + Email + fail-пинг HC.io
      - >-
        apprise
        -c "{{ .Env.HOME }}/.config/resticprofile/apprise.yaml"
        --tag backup-fail
        --tag "hc-{{ .Profile.Name }}-backup-fail"
        -t "Backup FAILED: {{ .Profile.Name }}"
        -b "Host: $(hostname -s)\nProfile: {{ .Profile.Name }}\nOperation: backup\nTime: $(date '+%Y-%m-%d %H:%M:%S')\nError: {{ .Error }}"
        -vv
```

`{{ .Profile.Name }}` — шаблонная переменная resticprofile, автоматически подставляет имя текущего профиля (`development`, `home`, и т.д.).

`{{ .Error }}` — resticprofile инжектит текст ошибки в `run-after-fail` автоматически.

Аналогичные хуки добавлены в секции `copy`, `forget`, `check` того же `base`-профиля. Все дочерние профили наследуют их через `inherit: base` → `inherit: repo-local`.

### Настройка Telegram

1. Создать бота через `@BotFather` → `/newbot`, получить токен
2. Получить `chat_id`: отправить боту любое сообщение, затем открыть `https://api.telegram.org/bot<TOKEN>/getUpdates`
3. Заменить в `apprise.yaml`:
   - `{TELEGRAM_BOT_TOKEN}` → токен вида `123456789:ABCdefGHI...`
   - `{TELEGRAM_CHAT_ID}` → числовой ID вида `-1001234567890` (группа) или `987654321` (личка)

### Настройка Email (Gmail)

1. Включить 2FA на Google-аккаунте
2. Создать App Password: [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords) → выбрать "Mail" → скопировать 16-значный пароль
3. Заменить в `apprise.yaml`:
   - `{GMAIL_USER}` → `your-email@gmail.com`
   - `{GMAIL_APP_PASSWORD}` → App Password (без пробелов)
   - `{ALERT_TO_EMAIL}` → куда получать письма

### Настройка Healthchecks.io

1. Зарегистрироваться на [healthchecks.io](https://healthchecks.io) (бесплатный план: 20 проверок)
2. Создать **Project** → скопировать **Project UUID** из Settings
3. Создать проверки с нужными slug-именами:


| Slug                 | Period         | Grace        |
| ---------------------- | ---------------- | -------------- |
| `development-backup` | 1 час       | 1 час     |
| `home-backup`        | 1 день     | 6 часов |
| `copy-to-b2`         | 3 часа     | 3 часа   |
| `maint-local`        | 1 неделя | 1 день   |
| `maint-b2`           | 1 неделя | 1 день   |

4. В каждой проверке настроить Integrations: Telegram + Email (через HC.io интеграции)
5. Заменить `{HC_PROJECT_UUID}` в `apprise.yaml` на UUID проекта

### Тестирование уведомлений

```bash
# Проверить success-путь (только Telegram)
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag backup-success \
  -t "Test: Backup Success" \
  -b "Manual test $(date)" -vv

# Проверить failure-путь (Telegram + Email)
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag backup-fail \
  -t "Test: Backup FAILED" \
  -b "Manual failure test" -vv

# Проверить HC.io пинг для development
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag hc-development-backup-success \
  -t "ping" -b "test" -vv

# Проверить HC.io fail-пинг
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag hc-development-backup-fail \
  -t "fail-ping" -b "test" -vv
```

---

## 8. User Guide — как пользоваться

### 8.1 Первый запуск (setup)

**Шаг 1: Установить зависимости**

```bash
brew install restic resticprofile apprise
```

**Шаг 2: Создать директорию конфигурации**

```bash
mkdir -p ~/.config/resticprofile
```

**Шаг 3: Создать файл-пароль репозитория**

```bash
# Придумать надёжный пароль (или сгенерировать)
openssl rand -base64 32 > ~/.config/resticprofile/repo.key
chmod 600 ~/.config/resticprofile/repo.key

# Сохранить этот пароль в password manager — без него данные невосстановимы!
cat ~/.config/resticprofile/repo.key
```

**Шаг 4: Создать файл B2 credentials**

```bash
cat > ~/.config/resticprofile/b2.env << 'EOF'
B2_ACCOUNT_ID="your-account-id"
B2_ACCOUNT_KEY="your-application-key"
EOF
chmod 600 ~/.config/resticprofile/b2.env
```

**Шаг 5: Настроить Apprise**

Создать `~/.config/resticprofile/apprise.yaml` (см. раздел 7), заменить все `{PLACEHOLDER}` реальными значениями:

```bash
chmod 600 ~/.config/resticprofile/apprise.yaml

# Проверить что уведомления работают
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag backup-success -t "Setup test" -b "Apprise configured" -vv
```

**Шаг 6: Инициализировать локальный репозиторий**

```bash
# resticprofile инициализирует автоматически (initialize: true в base),
# но можно сделать явно:
resticprofile -n development backup
# При первом запуске создаст ~/Backups/restic/main
```

**Шаг 7: Включить расписание**

```bash
resticprofile schedule --all
# Создаёт launchd-агенты в ~/Library/LaunchAgents/
```

**Шаг 8: Проверить что всё запущено**

```bash
resticprofile status --all
# Показывает все активные launchd-агенты и их статус
```

---

### 8.2 Ежедневное использование

#### Посмотреть снепшоты

```bash
# Все снепшоты в локальном repo (development + home вместе)
resticprofile -n development snapshots
resticprofile -n home snapshots

# Снепшоты в B2
resticprofile -n maint-b2 snapshots

# С фильтрацией по тегу
resticprofile -n development snapshots --tag development
resticprofile -n home snapshots --tag home
```

#### Принудительный ручной backup

```bash
# Backup только development
resticprofile -n development backup

# Backup только home
resticprofile -n home backup

# Backup обоих сразу (через группу)
resticprofile --group backup backup
```

#### Принудительный ручной copy в B2

```bash
resticprofile -n copy-to-b2 copy
```

#### Полный цикл вручную (backup + copy)

```bash
resticprofile --group full-cycle backup
# Запускает: development backup → home backup → copy-to-b2 copy
```

#### Посмотреть что изменилось в последнем снепшоте

```bash
# Diff между двумя последними снепшотами development
resticprofile -n development diff latest~1 latest

# Diff между конкретными снепшотами
resticprofile -n development diff abc123 def456
```

#### Статистика репозитория

```bash
resticprofile -n development stats
resticprofile -n maint-b2 stats
```

---

### 8.3 Откат файлов (restore)

#### Восстановить один файл или директорию

```bash
# Найти нужный снепшот
resticprofile -n development snapshots

# Восстановить конкретный файл из последнего снепшота
resticprofile -n development restore latest \
  --include "/Users/yoshintame/Development/myproject/src/main.go" \
  --target /tmp/restore

# Файл появится по пути: /tmp/restore/Users/yoshintame/Development/myproject/src/main.go
```

#### Восстановить директорию

```bash
# Восстановить ~/Development/myproject на момент снепшота abc123
resticprofile -n development restore abc123 \
  --include "/Users/yoshintame/Development/myproject" \
  --target /tmp/restore
```

#### Восстановить прямо на место (overwrite)

```bash
# ОСТОРОЖНО: перезапишет текущие файлы
resticprofile -n development restore latest \
  --include "/Users/yoshintame/Development/myproject" \
  --target /
```

#### Восстановить весь home из B2

```bash
resticprofile -n maint-b2 restore latest \
  --tag home \
  --target /tmp/home-restore
```

#### Найти файл по имени в снепшотах

```bash
# Посмотреть содержимое снепшота (ls по пути внутри снепшота)
resticprofile -n development ls latest /Users/yoshintame/Development/myproject

# Найти файл по имени (медленно, но мощно)
resticprofile -n development find "*.go" --tag development
```

---

### 8.4 Обслуживание

#### Ручной forget + prune (вне расписания)

```bash
# Очистить локальный repo по retention-политике
resticprofile -n maint-local forget

# Очистить B2 repo
resticprofile -n maint-b2 forget
```

#### Проверка целостности

```bash
# Проверить структуру локального repo
resticprofile -n check-local check

# Проверить структуру B2 + 5% данных
resticprofile -n check-b2 check

# Полная проверка данных локального repo (медленно, раз в 6 месяцев)
resticprofile -n check-local check --read-data
```

#### Обновить расписание после изменения конфига

```bash
# Удалить старые агенты и создать новые
resticprofile unschedule --all
resticprofile schedule --all

# Проверить статус
resticprofile status
```

#### Посмотреть логи

```bash
# Dev backup лог
tail -f $TMPDIR/resticprofile-development.log

# Home backup лог
tail -f $TMPDIR/resticprofile-home.log

# Copy to B2 лог
tail -f $TMPDIR/resticprofile-copy-to-b2.log

# Maintenance local
tail -f $TMPDIR/resticprofile-maint-local.log

# Maintenance B2
tail -f $TMPDIR/resticprofile-maint-b2.log
```

#### Посмотреть логи launchd

```bash
# Список всех resticprofile агентов
launchctl list | grep resticprofile

# Лог конкретного агента через launchd
log show --predicate 'subsystem == "com.github.creativeprojects.resticprofile"' \
  --last 1h
```

---

### 8.5 Просмотр и управление расписанием

```bash
# Посмотреть все активные расписания
resticprofile status

# Включить расписание для конкретного профиля
resticprofile -n development schedule

# Отключить расписание для конкретного профиля
resticprofile -n development unschedule

# Включить все
resticprofile schedule --all

# Отключить все
resticprofile unschedule --all
```

Launchd-агенты живут в `~/Library/LaunchAgents/` с именами вида `local.resticprofile.development.backup.plist`.

---

### 8.6 Синхронизация с B2 (copy)

Copy выполняется автоматически каждые 3 часа. Чтобы запустить вручную (например, перед выключением ноутбука):

```bash
resticprofile -n copy-to-b2 copy
```

После первого запуска B2-репозиторий инициализируется автоматически с `--copy-chunker-params` из локального repo. Последующие запуски копируют только новые снепшоты.

---

### 8.7 Чистый конфиг (после изменений в dotfiles)

```bash
# Если изменили profiles.yaml — перезапустить расписание
resticprofile unschedule --all
resticprofile schedule --all

# Если изменили apprise.yaml — тест уведомлений
apprise -c ~/.config/resticprofile/apprise.yaml \
  --tag backup-success -t "Config reload test" -b "OK" -vv
```

---

## 9. Disaster Recovery

### Сценарий: MacBook потерян/сломан

Все локальные файлы и локальный restic-репозиторий утрачены. Есть новый MacBook, доступ к B2, пароль.

**Необходимые секреты (хранить отдельно от ноутбука!):**

- Файл-пароль репозитория (`repo.key`) — или passphrase наизусть
- B2 credentials (`B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`)

### Шаг 1: Восстановить рабочие файлы из B2

```bash
# Установить restic
brew install restic

# Посмотреть доступные снепшоты
export B2_ACCOUNT_ID="..."
export B2_ACCOUNT_KEY="..."
restic -r b2:blackgaze:restic/main -p repo.key snapshots

# Восстановить home
restic -r b2:blackgaze:restic/main -p repo.key restore latest --tag home --target ~/

# Восстановить development
restic -r b2:blackgaze:restic/main -p repo.key restore latest --tag development --target ~/
```

### Шаг 2: Воссоздать локальный repo

**Вариант A — свежий старт (быстро, без локальной истории):**

```bash
mkdir -p ~/Backups/restic
restic init --repo ~/Backups/restic/main --password-file ~/.config/resticprofile/repo.key
```

Первый `resticprofile backup` создаст первый снепшот. История в B2 сохранена.

**Вариант B — перенести историю из B2 (долго, сохраняет историю):**

```bash
mkdir -p ~/Backups/restic

# Инициализировать с chunker-params из B2 (для эффективных будущих copy)
restic init \
  --repo ~/Backups/restic/main \
  --password-file ~/.config/resticprofile/repo.key \
  --copy-chunker-params \
  --repo2 b2:blackgaze:restic/main \
  --password-file2 ~/.config/resticprofile/repo.key

# Скопировать все снепшоты из B2 в локальный (обратный copy)
restic copy \
  --repo b2:blackgaze:restic/main \
  --repo2 ~/Backups/restic/main \
  --password-file ~/.config/resticprofile/repo.key \
  --password-file2 ~/.config/resticprofile/repo.key
```

### Шаг 3: Развернуть dotfiles и resticprofile

```bash
# Клонировать dotfiles (уже восстановлен из бэкапа, либо из git)
git clone git@github.com:yoshintame/.dotfiles.git ~/.dotfiles

# Развернуть конфигурацию (nix/dotbot)
# ... стандартная процедура установки ...

# Создать секреты
echo "your-passphrase" > ~/.config/resticprofile/repo.key
chmod 600 ~/.config/resticprofile/repo.key

cat > ~/.config/resticprofile/b2.env << 'EOF'
B2_ACCOUNT_ID="..."
B2_ACCOUNT_KEY="..."
EOF
chmod 600 ~/.config/resticprofile/b2.env

# Создать apprise.yaml (см. раздел 7) и заполнить секреты
chmod 600 ~/.config/resticprofile/apprise.yaml

# Установить расписание
resticprofile schedule --all
```

---

## 10. Фаза 2: Home Lab Server

### Архитектура с сервером

```
MacBook
  [файлы]
      │
      ▼ restic backup
  [Local repo: ~/Backups/restic/main]
      │
      ├──▶ restic copy → [B2: b2:blackgaze:restic/main]
      │
      └──▶ restic copy → [Home Lab: rest:http://server:8000/main]

Home Lab Server
  [server data]
      │
      ▼ restic backup
  [Server local repo: /backups/restic/main]
      │
      └──▶ restic copy → [B2: b2:blackgaze:restic/server]
```

### Что меняется

1. **Новый backend** — на сервере запускается `restic REST server`:

```bash
# На сервере
restic-rest-server --listen :8000 --path /backups/restic
```

2. **Дополнительная секция copy** в profiles.yaml MacBook:

```yaml
copy-to-homelab:
  inherit: repo-local
  copy:
    initialize: true
    initialize-copy-chunker-params: true
    repository: "rest:http://homelab:8000/main"
    password-file: "{{ .Env.HOME }}/.config/resticprofile/repo.key"
    schedule: "0 */3 * * *"
```

3. **Бэкап самого сервера** — отдельная инсталляция resticprofile на сервере, бэкап серверных данных в свой локальный repo + copy в B2 (в отдельный путь `b2:blackgaze:restic/server`).
4. **Retention для Home Lab** — аналогична B2 (длинная история, дешёвое хранение).
5. **Добавить HC.io проверки** для `copy-to-homelab` и добавить соответствующие теги в `apprise.yaml`.

---

## 11. Секреты и безопасность

### Файлы секретов


| Файл                               | Содержимое                | Permissions |
| ---------------------------------------- | ------------------------------------- | ------------- |
| `~/.config/resticprofile/repo.key`     | Пароль репозитория | `600`       |
| `~/.config/resticprofile/b2.env`       | `B2_ACCOUNT_ID`, `B2_ACCOUNT_KEY`   | `600`       |
| `~/.config/resticprofile/apprise.yaml` | Telegram token, SMTP creds, HC UUID | `600`       |

**Ни один из этих файлов не коммитится в git.**

Старый `notify.env` заменён на `apprise.yaml` — все credentials теперь в одном файле.

### Резервное хранение секретов

Пароль от repo и B2 credentials должны быть сохранены **вне** ноутбука:

Password manager (1Password, Bitwarden)

Распечатка в сейфе

Зашифрованная заметка в облаке

Без пароля от repo данные в B2 невосстановимы.

### Исключения из backup

В backup исключаются:

- `/.config/resticprofile/*.key` — файлы с паролями
- `/Backups/restic/**` — сам локальный repo (предотвращает рекурсию)

---

## 12. Структура профилей (profiles.yaml)

### Иерархия наследования

```
base
  ├── repo-local  (+ repository local, lock, mkdir)
  │     ├── default
  │     ├── development  (+ source ~/Development, schedule */30)
  │     ├── home         (+ source home dirs, schedule 02:00)
  │     ├── copy-to-b2   (+ copy section → B2, schedule */3h)
  │     └── maint-local  (+ forget/prune settings, schedule sun 04:00)
  │
  └── repo-b2     (+ repository b2, b2.env, lock)
        ├── maint-b2     (+ forget/prune settings, schedule sun 05:00)
        ├── check-local  (+ check schedule monthly 06:00)  ← наследует repo-local
        └── check-b2     (+ check --read-data-subset=5%, schedule monthly 07:00)
```

### Группы профилей


| Группа  | Профили                | Использование                            |
| --------------- | ------------------------------- | ------------------------------------------------------- |
| `backup`      | development, home             | Запустить все backup-и                   |
| `full-cycle`  | development, home, copy-to-b2 | Backup + copy в одном вызове              |
| `maintenance` | maint-local, maint-b2         | Forget+prune на всех repo                       |
| `check`       | check-local, check-b2         | Проверка целостности всех repo |

### Хуки уведомлений (в base)

Каждая операция (backup, copy, forget, check) имеет:

- `run-after` → Apprise `--tag backup-success --tag hc-<profile>-<op>-success` (TG + HC.io ping)
- `run-after-fail` → Apprise `--tag backup-fail --tag hc-<profile>-<op>-fail` (TG + Email + HC.io fail-ping)

---

## 13. Мониторинг и проверка

### Ручные команды

```bash
# Список снепшотов
resticprofile -n development snapshots
resticprofile -n home snapshots
resticprofile -n maint-b2 snapshots

# Статистика
resticprofile -n development stats
resticprofile -n maint-b2 stats

# Проверка целостности
resticprofile -n check-local check
resticprofile -n check-b2 check

# Ручной backup
resticprofile -n development backup
resticprofile -n home backup

# Ручной copy в B2
resticprofile -n copy-to-b2 copy

# Ручной forget+prune
resticprofile -n maint-local forget
resticprofile -n maint-b2 forget

# Статус расписания
resticprofile status
```

### Логи


| Job               | Лог-файл                         |
| ------------------- | ----------------------------------------- |
| Dev backup        | `$TMPDIR/resticprofile-development.log` |
| Home backup       | `$TMPDIR/resticprofile-home.log`        |
| Copy to B2        | `$TMPDIR/resticprofile-copy-to-b2.log`  |
| Maintenance local | `$TMPDIR/resticprofile-maint-local.log` |
| Maintenance B2    | `$TMPDIR/resticprofile-maint-b2.log`    |
| Check local       | `$TMPDIR/resticprofile-check-local.log` |
| Check B2          | `$TMPDIR/resticprofile-check-b2.log`    |

`$TMPDIR` на macOS — `/var/folders/.../T/` (user temp, не `/tmp`).

### Healthchecks.io dashboard

Открыть [healthchecks.io](https://healthchecks.io) — все проверки должны быть зелёными. Если какая-то серая/красная — значит операция не выполнялась в ожидаемый интервал.

### Регулярная ручная проверка (рекомендуется)

- **Еженедельно:** список снепшотов (`resticprofile snapshots`), убедиться что свежие есть
- **Ежемесячно:** HC.io dashboard, просмотреть логи на предмет warnings
- **Раз в 6 месяцев:** тестовое восстановление файла из B2 во временную директорию

---

## 14. Миграция с предыдущей стратегии

### С notify.env + restic-notify.sh на Apprise

Если ранее использовался скрипт `~/.local/bin/restic-notify.sh` и файл `notify.env`:

1. Установить Apprise: `brew install apprise`
2. Создать `~/.config/resticprofile/apprise.yaml` (см. раздел 7)
3. Обновить `profiles.yaml` — заменить вызовы `restic-notify.sh` на `apprise ...` (уже сделано в текущем конфиге)
4. Удалить старый `notify.env` (секреты теперь в `apprise.yaml`)
5. Протестировать: `apprise -c ~/.config/resticprofile/apprise.yaml --tag backup-fail -t "Test" -b "Migration test" -vv`

### Переинициализировать B2 repo (если нужны chunker-params)

Если текущий B2 repo был инициализирован без `--copy-chunker-params`, restic copy будет работать, но **неэффективно** — каждый блоб будет пересоздан.

**Вариант A — новый B2 repo** (потеря текущей B2-истории, зато эффективные copy):

```bash
# Переименовать путь в B2 или создать новый bucket
# resticprofile инициализирует новый repo автоматически при первом copy
```

**Вариант B — оставить существующий** — первый copy скопирует все данные полностью (нет переиспользования блобов). Последующие copy будут инкрементальными.

**Рекомендация:** вариант A, если текущая B2-история не ценна.

### Обновить расписание

```bash
resticprofile unschedule --all
resticprofile schedule --all
resticprofile status
```

---

## Приложение: Сводная таблица


| Параметр                                 | Значение                                |
| -------------------------------------------------- | ------------------------------------------------- |
| Метод                                       | restic copy (local → B2)                       |
| Хранилища                               | Local + B2 (+ Home Lab в будущем)       |
| Репозиториев на хранилище | 1 (общий для dev+home)                  |
| Dev backup                                       | Каждые 30 мин                          |
| Home backup                                      | Ежедневно 02:00                        |
| Copy → B2                                       | Каждые 3 часа                         |
| Local retention                                  | 1d all + 14d + 8w + 6m                          |
| B2 retention                                     | 30d + 12w + 12m + 3y                            |
| Forget+prune                                     | Еженедельно (вс)                   |
| Check                                            | Ежемесячно (1-е число)          |
| Алерты (active)                            | Apprise → Telegram + Email при ошибке |
| Алерты (passive)                           | Apprise → Healthchecks.io dead-man's switch    |
| Уведомления                           | apprise -c apprise.yaml --tag<tag>              |
| Секреты                                   | repo.key, b2.env, apprise.yaml (вне git)     |

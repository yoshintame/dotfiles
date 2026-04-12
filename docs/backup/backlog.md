# Backup backlog

Идеи и задачи на будущее по системе бэкапа.

---

## APFS snapshot integration (заморожено)

**Статус:** реализация готова и рабочая, лежит в ветке `apfs-snapshot-integration`. В master не мерджится.

**Что это:** consistent backup через APFS local snapshot — перед каждым `restic backup` создаётся snapshot корневого тома, монтируется read-only, restic читает из него, после — cleanup. Это даёт атомарный срез ФС и защищает от «полупрочитанных» файлов при параллельной записи.

**Почему не в master:** restic 0.18.1 не умеет переопределять поле `paths` в snapshot metadata:

- [restic#3200](https://github.com/restic/restic/pull/3200) — PR добавлял `--set-path` для backup, закрыт автором без merge в ноябре 2022. Core-команда отвергла подход «произвольной подмены путей».
- [restic#2092](https://github.com/restic/restic/issues/2092) — issue про `--strip-prefix`, открыт с 2018, без движения.
- `restic rewrite` умеет менять `--new-host` и `--new-time`, но **не пути**.

В результате все backup'ы через mount получаются с путями вида `/tmp/restic-apfs-snap-dev/Users/yoshintame/Development/...` вместо оригинальных. Это ломает:
- `restic snapshots` показывает уродливые пути с префиксом
- `rp restore --include /Users/...` не находит файлы
- `rp diff` путается при сравнении «до» и «после»

**Почему не обойти:** Linux решает это через mount namespaces (`unshare -m` + remount snapshot'а поверх оригинального пути). В macOS **нет поддержки mount namespaces** в ядре Darwin. MacFUSE + bindfs не дают чистых путей и требуют kernel extension.

**Оценка риска без snapshot'ов** (почему это приемлемо для текущего сетапа):
- `dev` (~7 GiB, 255k файлов) — backup идёт ~20 секунд. Код, git, IDE-файлы. Git внутренне atomic. Риск попасть на «половинчатый» файл — низкий
- `home` (~23 GiB, 33k файлов) — backup идёт ~60 секунд. Documents, Pictures — статичны. Shell history — атомарные записи. `.history.db` (atuin) — sqlite с WAL, тоже атомарен
- Нет больших активных БД (Postgres, MySQL, огромных sqlite на запись 24/7) в бэкап-путях
- Если backup схватит битый файл — в следующем инкременте (через 30 мин для dev) он уже будет консистентным

**Когда разморозить ветку и вмерджить:**
1. restic добавит `--set-path` / `--strip-prefix` в `backup` — следить за issue #2092 и changelog
2. Или: `restic rewrite` получит `--new-path` — позволит чинить пути пост-фактум
3. Или: появится production-ready macOS аналог mount namespaces (маловероятно)

**Как разморозить:** `git merge apfs-snapshot-integration`, откатить префиксы в коде, прогнать end-to-end.

---

## Time Machine → homelab (SMB share)

**Цель:** добавить третий слой защиты — **bootable recovery**. restic закрывает данные, но полного образа системы (приложения, настройки, Keychain, Mail, Messages) нет. Time Machine даёт «Mac умер — за час поднял точное состояние» через macOS Recovery → Restore from Time Machine.

**Почему на homelab, а не на внешний SSD:**
- Сервер уже стоит дома, диск подключать/отключать не надо
- Автоматические инкременты без участия пользователя
- Wi-Fi достаточно для инкрементов (первый полный — через Ethernet)

**Что нужно сделать:**

1. На homelab-сервере поднять **Samba share** с правильной конфигурацией для Time Machine:
   ```
   [timemachine]
      path = /srv/timemachine
      valid users = yoshintame
      writable = yes
      vfs objects = catia fruit streams_xattr
      fruit:time machine = yes
      fruit:time machine max size = 1T
   ```
2. Выделить ~2× размера внутреннего SSD Mac
3. На Mac: `System Settings → General → Time Machine → Add Backup Disk → SMB share`
4. Первый бэкап — через Ethernet (быстрее), далее Wi-Fi для инкрементов
5. Опционально: зашифровать TM-бэкап (галочка при добавлении диска)

**Блокер:** homelab ещё не полностью настроен, Samba на нём не поднята.

**Альтернатива на переходный период:** внешний USB-C SSD, подключаемый раз в неделю. Покрывает тот же сценарий, но требует ручного подключения.

**Почему не Arq / облачный аналог TM:** облачных аналогов Time Machine не существует — iCloud не является TM-назначением. Arq даёт полный образ системы в облако, но не даёт bootable recovery через macOS Recovery.

---

## Вторая offsite-точка (3-2-1 → 3-2-2)

**Цель:** текущая схема — `local → B2`. Одна offsite-копия. Если Backblaze аккаунт заблокируют или B2 упадёт как сервис — останется только локальный репо.

**Варианты второго offsite:**

- **rsync.net** — дорого, но надёжно, нативный restic support
- **Hetzner Storage Box** — дёшево (€3/мес за 1 TB), но SFTP-only
- **AWS S3 Glacier Deep Archive** — дёшево для хранения ($1/TB/мес), дорого для извлечения
- **Второй B2 bucket в другой Apple ID / регионе** — защищает от случайного удаления, но не от блокировки аккаунта

**Реализация:** добавить в `profiles.tmpl.yaml` ещё одну `copy`-секцию с новым repo, расписание — раз в сутки (не нужно так часто как B2).

---

## Проверка recovery-процедуры

**Цель:** убедиться, что disaster recovery реально работает, а не только описан в документации.

**Что сделать:**

1. Раз в полгода — тестовый restore home-профиля в `/tmp/recovery-test`
2. Сверить чексуммы ключевых файлов (`.ssh`, `.gnupg`, `.dotfiles`)
3. Эмулировать полное восстановление на тестовой VM (UTM / Parallels) — clean macOS install → `rp restore-from-b2` → проверить, что всё на месте
4. Записать время восстановления — позволит планировать RTO

---

## Photos library (опционально)

**Цель:** фото из системной Photos library сейчас не попадают в `home` backup (они в `~/Pictures/Photos Library.photoslibrary`, а это package со специальными правами).

**Блокер:** нужен Full Disk Access для cron-пользователя + backup через APFS snapshot (чтобы не словить «library is in use»). А APFS snapshot интеграция заморожена — см. выше.

**Альтернатива:** полагаться на iCloud Photos (уже есть) + раз в год — ручной экспорт в `~/Pictures/photo-export-YYYY`, который попадёт в home backup.

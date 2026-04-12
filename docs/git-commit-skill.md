# git-commit skill

Источник: [modules/agents-shared/config/skills/git-commit/](../modules/agents-shared/config/skills/git-commit/)

Кастомный skill для Claude Code, который генерирует Conventional Commits сообщения, безопасно стейджит изменения и защищает от гонок между параллельными Claude-сессиями в одном репозитории.

## Зачем

Базовая проблема: когда в одном git worktree крутится несколько Claude-сессий, они все пишут в `.git/index` (shared staging area). Любая из них может случайно закоммитить чужие staged-файлы или сделать git add поверх чужой в процессе работы. Это приводит к мусорным коммитам и потере контекста.

Skill решает это через **per-session private git index**, плюс делает gather-context первым шагом каждого commit-флоу.

## Архитектура

```
modules/agents-shared/config/skills/git-commit/
├── SKILL.md                            # инструкции для Claude (правила + workflow)
└── scripts/
    └── gather-context.sh               # provisions private index + dumps repo state
```

Симлинки/хардлинки в системе:

- `~/.claude/skills/git-commit/SKILL.md` → симлинк в dotfiles (через dotbot)
- `~/.claude/skills/git-commit/scripts/gather-context.sh` → симлинк в dotfiles
- `~/.agents/skills/git-commit/scripts/gather-context.sh` → хардлинк (общий inode) с dotfiles-копией

То есть редактируется одна точка истины (`modules/agents-shared/...`), но скрипт доступен по обоим путям, потому что разные хосты Claude (CLI vs SDK-агенты) ищут его по разным префиксам.

## Private index mechanism

### Базовая идея

Git позволяет указать альтернативный staging area через переменную окружения `GIT_INDEX_FILE`. Это полностью изолированный bin-файл с теми же тремя slot'ами что и обычный `.git/index`. Все команды (`git add`, `git diff --cached`, `git commit`) работают с ним вместо shared index, если переменная установлена.

```bash
# создать
export GIT_INDEX_FILE=/path/to/private-index
git read-tree HEAD              # инициализировать снимком HEAD

# использовать
git add -- path/to/file         # стейджит в private index
git diff --cached               # показывает staged в private index
git commit -m "..."             # коммитит дерево из private index
```

`gather-context.sh` создаёт такой файл в `.git/claude-sessions/idx-XXXXXXXX` при первом запуске и переиспользует его во всех последующих вызовах через `--index PATH`.

### Что хранится рядом

Каждый private index сопровождается sidecar-файлом `<priv-index>.base`, в котором лежит SHA коммита HEAD на момент инициализации/последнего rebase. Это необходимо для второй защиты — rebase-логики (см. ниже).

### Что НЕ защищено

Private index изолирует **staging area**, но не worktree. Если две сессии редактируют один и тот же файл — победит последняя по времени `Edit/Write`. Это не задача git-commit skill, это уровень файловой системы.

## Rebase-on-HEAD-move (v5.1+)

### Проблема которую решает

Рассмотрим сценарий:

1. **T0** — Claude session A запускает `gather-context.sh`. Создаётся `idx-AAAA`, инициализированный снимком HEAD@T0.
2. **T1** — Claude session B завершает свой commit-флоу. HEAD двигается на новый commit (B-commit).
3. **T2** — session A стейджит свои файлы в `idx-AAAA` и делает `git commit`.

Что произойдёт без rebase-логики: git создаст новый коммит, родителем будет HEAD@T1 (B-commit), но дерево возьмётся из `idx-AAAA` — а оно содержит **снимок HEAD@T0** для всех файлов которые session A не трогал. Включая файлы которые session B изменил в B-commit. Результат: commit от A молча откатывает изменения B для каждого нетронутого файла.

Это **реально произошло** в коммитах `c655954 → ddd74aa → bff7310` 13 апреля 2026: parallel session добавила shebang в vscode-скрипт, моя сессия закоммитила Brewfile-рефакторинг через старый private index, и shebang исчез. Пришлось делать восстанавливающий коммит.

### Как фиксится

При каждом запуске `gather-context.sh --index <existing>`:

1. Читает `<priv-index>.base` — SHA HEAD на момент init/последнего rebase.
2. Сравнивает с `git rev-parse HEAD`.
3. Если HEAD двигался:
   a. Запоминает список путей которые есть в private index но отличаются от base: `git diff --cached --name-only $BASE`.
   b. Делает `git read-tree $NEW_HEAD` в private index — теперь индекс отражает текущий HEAD-tree.
   c. Re-стейджит запомненные пути: для каждого либо `git add -- <path>` (если файл существует в worktree), либо `git rm -- <path>` (если был удалён).
   d. Записывает новый SHA в `<priv-index>.base`.
4. В выводе печатается строка `rebased: <old> -> <new>` — Claude видит её и должен пере-проверить staged diff перед commit.

После rebase private index содержит:
- Снимок текущего HEAD-tree (база с актуальными изменениями всех параллельных сессий)
- Поверх — твои staged-изменения, переcтейдженные из worktree

Так твой commit ляжет child of текущего HEAD и не затронет файлов которые ты не трогал.

### Когда rebase не безопасен

Если параллельная сессия **редактировала тот же файл** что и ты — ваши изменения уже смешаны в worktree (потому что обе сессии пишут в один worktree). Re-stage из worktree подхватит итоговую (смешанную) версию. В нашей схеме это **не конфликт** — итог worktree это и есть суммарный результат всех сессий, и каждая коммитит свою долю по своим путям. Если же одна сессия хочет коммитить только свою часть из спорного файла — это уже задача hunk-staging (`git add -p`), и Claude должен это делать руками.

## Workflow глазами Claude

См. [SKILL.md](../modules/agents-shared/config/skills/git-commit/SKILL.md) — инструкции максимально сжаты, чтобы важные правила (особенно bullet-only body format) не терялись при беглом чтении.

Сжатый flow:

1. Запустить `gather-context.sh` — создаст/переиспользует private index, выведет state репо.
2. Стейджить только нужные пути с префиксом `GIT_INDEX_FILE=<path>` на КАЖДОЙ git-команде. Bash-вызовы Claude не разделяют env между собой, поэтому export не работает.
3. Прямо перед commit — повторно запустить `gather-context.sh --index <path>`. Если HEAD двигался, скрипт сделает rebase и напечатает `rebased: ...`. Тогда Claude должен пере-проверить staged diff.
4. `GIT_INDEX_FILE=<path> git commit-edit "<message>"` — `commit-edit` это пользовательский git alias, открывает редактор для финальной правки сообщения.

## Что выводит gather-context

Секции в порядке появления:

| Секция | Что внутри |
|---|---|
| `PRIVATE INDEX` | Путь к private index, текущий HEAD SHA как `base`, копи-готовая команда `git add`, опционально `rebased: <old> -> <new>` |
| `SHARED INDEX WARNING` | Если в `.git/index` есть staged что-то не от текущей сессии — список файлов с пометкой "off-limits" |
| `BRANCH` | Текущая ветка, Jira-ключ из имени ветки (если есть), base-ветка |
| `WORKING TREE (changed files)` | `git status --short` |
| `STAGED DIFF (private index)` | Diff из private index — full diff если есть, иначе подсказка как стейджить |
| `BRANCH DIVERGENCE` | `git log --oneline base..HEAD` если ветка не base |
| `RECENT COMMITS` | До 25 уникальных `type(scope):` префиксов — для подражания стилю репо |
| `REPO COMMIT CONVENTIONS` | Найденные `.commitlintrc*`, `.gitmessage`, `CONTRIBUTING.md` |

## Self-healing shared index

В `gather-context.sh` есть дополнительная логика: если `.git/index` содержит staged изменения, скрипт пытается понять, не являются ли они тривиальным "staged = HEAD" артефактом. Он сравнивает `git write-tree` (на shared index) с tree последних 30 коммитов через `git rev-parse <c>^{tree}`. Если совпадает с одним из них — выполняет `git read-tree HEAD`, чтобы очистить shared index. Это автоматический cleanup осиротевших артефактов от старых сессий.

Если совпадения не найдено — шлёт WARNING с пометкой "off-limits", и Claude обязан не трогать эти файлы (они принадлежат другой активной сессии).

## История изменений

- **5.0.0** — введение `GIT_INDEX_FILE` per-session, базовая изоляция staging.
- **5.1.0** — добавлен rebase private index на текущий HEAD при каждом повторном запуске gather-context. `<priv-index>.base` хранит SHA. Комментарий: появился из-за реального инцидента с откатом vscode shebang.
- **5.2.0** — SKILL.md сжат, bullet-only body format вынесен в Rules чтобы не теряться при skim-чтении.

## Граничные случаи и известные ограничения

- **Hunk-staging.** Skill ничего не делает с `git add -p`. Если нужно закоммитить часть файла — Claude должен использовать `--patch` руками, через тот же `GIT_INDEX_FILE` префикс.
- **Несколько коммитов в одной сессии.** Между двумя `git commit` Claude ОБЯЗАН повторно вызвать gather-context чтобы освежить `.base`. Иначе следующий rebase отработает от устаревшего значения.
- **Удалённые файлы.** Rebase-логика обрабатывает и удаления — если staged путь больше не существует в worktree, ставит `git rm`.
- **Reset/rebase базовой ветки.** Если HEAD был перемещён через `git reset --hard`/`git update-ref`, rebase-логика всё равно отработает — она просто сравнивает SHA, не различая откуда взялось расхождение. Это безопасно: re-staging из worktree всегда даёт корректное состояние.
- **Параллельные коммиты в один и тот же файл.** Не обнаруживаются. Правильное поведение тут — не молчаливый rebase, а fail-fast с просьбой к человеку. Возможное улучшение: проверять `git diff --name-only $OLD $NEW ∩ $STAGED_PATHS` и абортить если непусто.

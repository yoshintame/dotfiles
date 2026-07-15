---
name: state-reconstruction
description: Незафиксированная работа региона — сессии, правки вне коммитов, git-WIP.
---

# /state-reconstruction

Каждое утверждение о состоянии — из команды этого прогона, не из памяти транскриптов. Вход — регион: репо, vault-папка проекта или их связка. Подбери 1–3 подстроки пути (имя папки репо, имя vault-папки) — они матчат и `file_path` тулов, и текст Bash-команд.

## 1. Обратный индекс сессий

```bash
bun ~/.claude/skills/state-reconstruction/scripts/region-sessions.ts <substr> [substr…] [--limit=N]
```

Скрипт сам склеивает снапшот `~/.claude/cc.duckdb` со свежими JSONL новее его края (живой парсинг батчами ≤128 MB), `--rebuild` не нужен. Секции:

- `Sessions` — кто трогал регион из любого проекта: edits/writes/reads/bash по сессии. Свою текущую сессию игнорируй.
- `Files` — файл → последний редактор-сессия → счётчики. Это ключ к стыку с `git status`.
- `Bash touches` — файлы, созданные `mv`/`cp`/heredoc мимо Write/Edit, видны только здесь; триаж по sample command.

## 2. Git-WIP

По каждому репо, куда попадают файлы из `Files`:

```bash
git-commit-context -C <repo>
git -C <repo> stash list
git -C <repo> log -1 --format='%h %cI %s'
```

`git-commit-context` даёт ветку, working tree, diff `--stat`, дивергенцию, недавние коммиты. stash и дата последнего коммита в нём отсутствуют — потому две добавочные команды.

## 3. Шортлист → session-status

Подозреваемые: сессии с `last` позже последнего коммита региона; последние редакторы файлов, грязных в `git status`; топ по edits. 3–8 сессий, не все — каждый прогон сканирует корпус на staleness:

```bash
bun ~/.claude/skills/session-status/scripts/session-status.ts <uuid> [uuid…]
```

Полные UUID; отчёты разделяются `---`. Дальше — шаги скила `/session-status` (re-read только `re-read needed`).

## 4. Стык — что не легло

- Грязный/untracked файл, чей последний редактор — сессия из `Files` → незакрытый WIP этой сессии.
- Файл из session-status без коммита после окна сессии и не в `git status` → работа перетёрта или уехала — проверь, куда.
- `stash`, ветка ahead → незакрытое вне сессий.
- Спячка = разрыв «последний коммит региона ↔ last свежих сессий»: регион правили, но не фиксировали.

## Вывод

```
## Реконструкция: <регион>
### Git-WIP
- <репо>: ветка, ahead N, M dirty / K untracked, stash: …
### Незакрытое
- <файл> — <сессия, дата>: <что это и почему не легло>
### Спячка
- последний коммит <дата hash> vs последняя активность сессий <дата>
### Факты только в сессиях
- <из «Полезного» session-status: команды, цифры, развилки>
```

Пустую секцию пропусти. Этот вывод — вход шага 1 `/reconcile`.

## Escape hatch — сырой SQL

Никогда не агрегируй живой view `msg` по полному глобу — OOM (ловили 14.3 GiB). Два безопасных пути:

```bash
duckdb ~/.claude/cc.duckdb -readonly -c "SELECT … FROM msg_cache WHERE …"
```

`msg_cache`: `(project, session_id, ts, text, id)`, без `kind`/`tool` — tool-блоки лежат сырым JSON, поля тянутся `json_extract_string(text, '$.file_path')`. Фильтр в `WHERE` до агрегации.

```bash
duckdb -init ~/.claude/skills/find-session/assets/cc.sql -c "
ATTACH '$HOME/.claude/cc.duckdb' AS cc (READ_ONLY);
SELECT … FROM msg_src(['<файл>.jsonl', …]) WHERE kind='tool_use' AND …"
```

`msg_src` по явному списку файлов даёт настоящие `kind`/`tool`; список держи ≤128 MB на запрос.

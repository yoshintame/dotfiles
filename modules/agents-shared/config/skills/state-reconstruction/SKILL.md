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

- `Sessions` — кто трогал регион из любого проекта: edits/writes/reads/bash по сессии. Сессии с файловыми касаниями идут первыми; bash-only хвост — в основном шум (упоминание региона в commit-message, find), триажь по sample. Свою текущую сессию игнорируй.
- `Files` — файл → последний редактор-сессия → счётчики. Это ключ к стыку с `git status`.
- `Handoffs` — handoff-файлы региона отдельно от контента, со статусом из frontmatter (`open` = невзятая работа, `consumed` — кем-то подхвачена, `no-frontmatter` — старый формат, статус смотри руками).
- `Bash touches` — файлы, созданные `mv`/`cp`/heredoc мимо Write/Edit, видны только здесь; триаж по sample command.

## 2. Git-WIP

По каждому репо, куда попадают файлы из `Files`:

```bash
git-commit-context -C <repo>
git -C <repo> stash list
git -C <repo> log -1 --format='%h %cI %s'
```

`git-commit-context` даёт ветку, working tree, diff `--stat`, дивергенцию, недавние коммиты. stash и дата последнего коммита в нём отсутствуют — потому две добавочные команды.

Когда регион — подпапка большого репо (vault-проект), `git-commit-context` выдаст весь чужой dirty tree. Вместо него — region-scoped:

```bash
git -C <repo> status --porcelain -- <paths>
git -C <repo> log -1 --format='%h %cI %s' -- <paths>
git -C <repo> diff HEAD --stat -- <paths>
```

## 3. Шортлист → session-status

Подозреваемые: сессии с `last` позже последнего коммита региона; последние редакторы файлов, грязных в `git status`; топ по edits. 3–8 сессий, не все — каждый прогон сканирует корпус на staleness:

```bash
bun ~/.claude/skills/session-status/scripts/session-status.ts <uuid> [uuid…]
```

Полные UUID; отчёты разделяются `---`. Дальше — шаги скила `/session-status` (re-read только `re-read needed`).

Read-only сессия (reads ≫ 0, edits = 0, `last` позже коммита) для session-status невидима — все секции пустые, а её вывод остался в чате. Не отбрасывай: вытащи финальный ответ ассистента из JSONL — план или развилку, не легшие в артефакты:

```bash
jq -rs 'map(select(.type=="assistant" and (.message.content | type=="array"))) | last.message.content | map(select(.type=="text") | .text) | join("\n")' ~/.claude/projects/<project>/<uuid>.jsonl
```

## 4. Стык — что не легло

- Грязный/untracked файл, чей последний редактор — сессия из `Files` → незакрытый WIP этой сессии.
- Файл из session-status без коммита после окна сессии и не в `git status` → работа перетёрта или уехала — проверь, куда.
- `stash`, ветка ahead → незакрытое вне сессий.
- Спячка = разрыв «последний коммит региона ↔ last свежих сессий»: регион правили, но не фиксировали.

Сессия из первых двух пунктов = **недозакрытая** — её работа не легла в артефакты. Каждую такую доведи до команды резюма: проверь, что JSONL жив (`ls ~/.claude/projects/<project>/<uuid>.jsonl` — ретеншен чистит старые; мёртвую не предлагай, пометь «только снапшот»), и собери `claude --resume <полный-uuid>`. Резюмить нужно из cwd сессии — колонка `project` таблицы `Sessions` кодирует его (`-Users-…` → путь).

## Вывод

```
## Реконструкция: <регион>
### Git-WIP
- <репо>: ветка, ahead N, M dirty / K untracked, stash: …
### Незакрытое
- <файл> — <сессия, дата>: <что это и почему не легло>
### Дозакрыть — сессии для claude --resume
- cd <cwd сессии> && claude --resume <полный-uuid>   # <что именно довести, 1 строка>
- <uuid> — JSONL умер, только снапшот: <что оттуда вытащить руками>
### Спячка
- последний коммит <дата hash> vs последняя активность сессий <дата>
### Факты только в сессиях
- <команды, цифры, развилки — из финальных ответов ассистента (jq-рецепт выше) и session-status>
```

«Дозакрыть» — обязательная секция, ради неё прогон и делается: пользователь заходит по этим командам сам и доводит сессии до конца. Пустую прочую секцию пропусти. Этот вывод — вход шага 1 `/reconcile`.

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

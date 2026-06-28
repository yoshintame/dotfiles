---
name: find-session
description: Поиск по истории сессий Claude Code (мои реплики, ответы, тулзы) через DuckDB.
---

# /find-session

Запрос на естественном языке → поиск по `~/.claude/projects/**/*.jsonl`. Два дефолтных провала агента: (1) грепает сырой JSONL и тонет — схема неоднородная (`message.content` то строка, то массив разнотипных блоков), `kind='user'` забит инъекциями харнесса; (2) делает ILIKE-AND по словам юзера — а юзер путает и конфлейтит слова, обязательность каждого слова выкидывает правильную сессию. Оба чинит BM25 — он и есть дефолтный первый ход.

## Первый ход — BM25 ранжированный шортлист

```bash
bun ~/.claude/skills/find-session/scripts/search.ts --bm25 --sessions "<слова юзера как есть, RU+EN>"
```

Передавай слова юзера дословно плюс очевидные RU/EN-синонимы. BM25 **дизъюнктивен**: отсутствующий терм стоит 0, совпавшие суммируются. Неверное слово юзера сессию не исключает — в отличие от ILIKE-AND, где каждое слово обязательно и один неверный терм выкидывает ответ. И он ранжирует по релевантности, тогда как `--sessions` ILIKE-пути сортирует по дате, где попадание неотличимо от шума.

Колонки: `score` = пиковая релевантность (лучшее сообщение сессии, нейтрально к длине), `total`/`hits` = плотность. Ранжирование по `score`.

BM25 — **шорт-листер, не арбитр**. Гибридный воркфлоу:

1. `--bm25 --sessions "…"` → top 5–10 кандидатов.
2. Внутри добей **дискриминирующим якорём** (ниже) — не доверяй существительным юзера.
3. Кросс-чек кандидата: `git -C <project> status`, mtime файлов, даты сессии.

Флаги BM25:

- `--full` — индекс по `msg` (tool_use/tool_result/thinking), не только мои реплики. Точные формулировки — имена тестов, пути, лог-вывод — живут там. Индекс больше, строится дольше.
- `--rebuild` — пересобрать снапшот+индекс с нуля (full rescan, ~15с). Снимок не авто-обновляется: переиспользуется между вызовами (ради серии тяжёлых запросов). В stderr печатается `newest=<дата>` — край снимка. Ищешь сессию свежее `newest` → добавь `--rebuild`.
- `--limit=N`, `--resume` (готовая колонка `claude --resume`), `--sql` (печать SQL, дебаг).

## Дискриминирующие якоря

Концепт-слова юзера ненадёжны — переякоривайся на конкретный токен:

- **Числовой признак — самый устойчивый к перефразу.** Ищи `число + компаратор + существительное` regex'ом, не полагаясь на существительное юзера: `(<=?|не больше|≤)\s*200`.
- **Числовые ложные друзья** (`tail -200`, порты, лимиты) — склеивай число со смысловым словом, не голое число.
- **Имя теста / путь / лог-строка** — точные; ищи через `--full` (они в tool-блоках, не в `me`).
- **Кросс-чек с рабочим деревом** — git status / свежий mtime подтверждают кандидата дёшево.

Якорь гонишь либо вторым BM25 (`--full "200 client chats"`), либо raw-SQL regex по сессии-кандидату (ниже).

## Доразведка — синоним-скрипт (ILIKE)

Когда нужен точный язык, опечатка или узкий матч мимо стеммера индекса:

```bash
bun ~/.claude/skills/find-session/scripts/search.ts "<синоним>" ["<синоним>" …] [флаги]
```

Агент даёт синонимы, скрипт стеммит их Snowball'ом (`stem()`) и объединяет по OR. RU+EN. Частые опечатки — отдельными синонимами: `stem()` чинит окончания, не корень (`промт`≠`промпт`). **Каждый синоним — упорядоченная склейка `%a%b%` своих слов, и она конъюнктивна** — все слова синонима обязательны (та самая ILIKE-AND-ловушка; держи синонимы короткими).

Флаги: `--kind=user|assistant|tool_use|tool_result|thinking`, `--tool=NAME`, `--sessions`, `--resume`, `--distinct` (схлопнуть дубли sidechain/`<ide_selection>`), `--limit=N` (деф 40), `--no-stem`, `--sql`. `terms:` в stderr показывает, что реально искалось после стемминга.

## Escape hatch — сырой SQL

Пересечения, агрегаты, regex-якоря по шортлисту. OOM-прагмы в `cc.sql` — не вырезай:

```bash
duckdb -init ~/.claude/skills/find-session/assets/cc.sql -c "<SQL>"
```

- `me(project, session_id, ts, text)` — мои реплики (инъекции вычищены).
- `msg(project, session_id, ts, kind, tool, text)` — всё; `kind` ∈ `user|assistant|tool_use|tool_result|thinking|image`.
- `stem(s,'russian'|'english')` доступна после `LOAD fts;`.
- Зарезервированы: `day`, `first`, `last` — не алиасить без кавычек (бери `dt`, `first_seen`, `last_seen`).

```sql
LOAD fts;
-- числовой якорь по сессии-кандидату из BM25-шортлиста
SELECT ts, left(text, 200) FROM msg
WHERE session_id = '…' AND regexp_matches(text, '(не больше|<=?|≤)\s*200');
-- два концепта в одной сессии (пересечение)
SELECT project, session_id FROM me WHERE text ILIKE '%' || stem('postgrest','english') || '%'
INTERSECT SELECT project, session_id FROM me WHERE text ILIKE '%rls%';
-- какая сессия создавала/правила конкретный файл (Write/Edit/MultiEdit).
-- msg.text для tool_use = input тула, file_path извлекается как json-поле.
-- writes>0 → сессия создавала файл (Write); n всего edit'ов по сессии.
WITH e AS (
  SELECT project, session_id, ts, tool,
         json_extract_string(text, '$.file_path') AS fp
  FROM msg WHERE kind='tool_use' AND tool IN ('Write','Edit','MultiEdit')
)
SELECT regexp_replace(fp,'^.*/','') AS file, session_id, project,
       min(ts) AS first_seen, count(*) AS n,
       sum(CASE WHEN tool='Write' THEN 1 ELSE 0 END) AS writes
FROM e WHERE fp ILIKE '%<filename>%'
GROUP BY file, session_id, project ORDER BY first_seen;
```

Если файл создан **не** Write-тулом (например, `mv`/`cp` из `/tmp` через Bash) — `file_path`-фильтр выше не найдёт. Тогда искать по `tool='Bash'` и тексту команды: `SELECT … FROM msg WHERE kind='tool_use' AND tool='Bash' AND text ILIKE '%<filename>%' ORDER BY ts LIMIT 20`. View `msg` парсит JSONL **на лету** (см. cc.sql), `--rebuild` для этих запросов не нужен.

## Под капотом

`--bm25` автоматизирует ручную сборку: материализует снапшот `me`/`msg` в `~/.claude/cc.duckdb` и строит FTS-индекс (id через sequence — `row_number() OVER ()` вешает скан; скан и индекс — раздельными процессами, иначе OOM на парсер-буферах).

**Ограничение — индекс одностеммерный, корпус двуязычный (RU+EN).** Выбран один индекс `stemmer='russian'`: EN-токены проходят Snowball-russian почти нетронутыми, а запрос стеммится тем же стеммером → EN матчится консистентно. Цена: EN-морфология не конфлейтится (`chat`≠`chats`, `deliver`≠`delivered`) — добавляй EN-варианты доп. словами в запрос.

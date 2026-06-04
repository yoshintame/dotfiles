---
name: find-session
description: Поиск по истории сессий Claude Code (мои реплики, ответы, тулзы) через DuckDB.
---

# /find-session

Запрос на естественном языке → поиск по `~/.claude/projects/**/*.jsonl`. Дефолтный агент тут грепает сырой JSONL и тонет: схема неоднородная (`message.content` — то строка, то массив разнотипных блоков), а `kind='user'` забит инъекциями харнесса. Ниже — поправки к этому дефолту.

## Основной путь — скрипт

```bash
bun ~/.claude/skills/find-session/scripts/search.ts "<синоним>" ["<синоним>" …] [флаги]
```

Разделение труда: **агент даёт синонимы**, скрипт детерминированно токенизирует и **стеммит их через DuckDB Snowball** (`stem()`), собирает SQL и бьёт по корпусу. Никаких npm-зависимостей.

Твоя работа как агента — сгенерировать набор синонимов под концепт запроса:

- **RU + EN**, потому что юзер пишет на обоих, иногда в одном сообщении.
- **Включай частые опечатки** отдельными синонимами. `stem()` чинит только окончания (`сессии`→`сесс`), но не корень: `промт` и `промпт` — разные стемы, не матчатся друг с другом.
- Каждый синоним матчится как **упорядоченная склейка** стемов его слов: `инит промт` → `%инит%промт%`. Синонимы объединяются по OR. Хочешь другой порядок слов — дай его отдельным синонимом.

Флаги:

| Флаг | Эффект |
|---|---|
| `--kind=K` | `user`(деф.)`\|assistant\|tool_use\|tool_result\|thinking`. Не-`user` → поиск по полной view `msg`. |
| `--tool=NAME` | фильтр по имени тулзы (ставит `kind=tool_use`). Поиск по действиям агента. |
| `--sessions` | сгруппировать по сессии: число попаданий + окно дат. |
| `--resume` | то же + готовая колонка `claude --resume <id>`. |
| `--distinct` | схлопнуть дубли (одно сообщение часто логируется 2–4× через sidechain'ы/`<ide_selection>`): dedup по нормализованному тексту. |
| `--limit=N` | дефолт 40. |
| `--no-stem` | литеральные подстроки без Snowball (точный язык/опечатка). |
| `--sql` | напечатать сгенерированный SQL и выйти (дебаг). |

Скрипт печатает в stderr строку `terms: …` — что реально искалось после стемминга. Отдавай юзеру сводку + при необходимости `--resume`-команды. Если упёрся в `--limit`, скажи это.

## Escape hatch — сырой SQL

Сложные запросы (пересечения, агрегаты, мысли агента) — напрямую через view. OOM-прагмы уже внутри `cc.sql`, **не вырезай их**:

```bash
duckdb -init ~/.claude/skills/find-session/assets/cc.sql -c "<SQL>"
```

- `me(project, session_id, ts, text)` — только мои реальные реплики (инъекции вычищены).
- `msg(project, session_id, ts, kind, tool, text)` — всё; `kind` ∈ `user|assistant|tool_use|tool_result|thinking|image`.
- `stem(s,'russian'|'english')` доступна после `LOAD fts;` в начале запроса.
- **Зарезервированные слова**: `day`, `first`, `last` — нельзя как алиасы без кавычек (бери `dt`, `first_seen`, `last_seen`).

```sql
LOAD fts;
-- два концепта в одной сессии (пересечение), id готов для resume
SELECT project, session_id FROM me WHERE text ILIKE '%'||stem('postgrest','english')||'%'
INTERSECT
SELECT project, session_id FROM me WHERE text ILIKE '%rls%';

-- разбивка по типам / по тулзам
SELECT kind, count(*) FROM msg GROUP BY 1 ORDER BY 2 DESC;
SELECT tool, count(*) FROM msg WHERE kind='tool_use' GROUP BY 1 ORDER BY 2 DESC;
```

## Опциональный слой — FTS-индекс (BM25)

Живая view всегда свежая, но пересканирует весь корпус (секунды, спилл на диск). Для серии **тяжёлых ранжированных** запросов по неизменному срезу — материализуй снапшот в персистентную БД и построй FTS-индекс (~разово). Минусы: **один стеммер на индекс** (для двуязычного корпуса компромисс), снапшот стареет, ребилд по мере роста сессий.

Сборка — **два отдельных вызова** (скан корпуса и построение индекса в одном процессе упираются в память; разрыв освобождает парсер-буферы между фазами):

```bash
# 1) материализовать снапшот (тяжёлый скан, ~15с)
duckdb -init ~/.claude/skills/find-session/assets/cc.sql ~/.claude/cc.duckdb -c \
  "CREATE OR REPLACE TABLE me_cache AS SELECT project, session_id, ts, text FROM me;"

# 2) id через sequence (НЕ row_number() OVER () — глобальное окно вешает скан) + индекс
duckdb ~/.claude/cc.duckdb -c "
  ALTER TABLE me_cache ADD COLUMN id BIGINT;
  CREATE OR REPLACE SEQUENCE seq_id;
  UPDATE me_cache SET id = nextval('seq_id');
  LOAD fts;
  PRAGMA create_fts_index('me_cache','id','text', stemmer='russian', overwrite=1);"

# BM25-запрос (стеммер индекса жмёт и сам запрос)
duckdb ~/.claude/cc.duckdb -c "
  LOAD fts;
  SELECT project, ts::date AS dt, left(regexp_replace(text,'\s+',' ','g'),120) AS snippet
  FROM (SELECT *, fts_main_me_cache.match_bm25(id, 'инит промт сессия') AS score FROM me_cache) s
  WHERE score IS NOT NULL ORDER BY score DESC LIMIT 20;"
```

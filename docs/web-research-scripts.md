# Web research scripts

Источник: [modules/agents-shared/config/bin/](../modules/agents-shared/config/bin/)

Три CLI-скрипта для поиска и извлечения данных из Reddit, Hacker News и GitHub. Shared между Claude Code и Codex CLI, плюс доступны из терминала.

## Зачем

Агенты (Claude Code, Codex) и сам пользователь регулярно ходят в Reddit/HN/GitHub ради product/tool research и сравнения опций. Без скриптов агенты делают:

- Reddit: 10+ `WebSearch "site:reddit.com ..."` запросов, каскадные fallback-попытки через `curl duckduckgo.com`, парсинг HTML — около **40 мусорных tool-calls** в одной research-сессии (реальный замер через JSONL-логи сессии find-best).
- HN: WebFetch на `hn.algolia.com/?q=...` возвращает HTML страницы поиска, а не API — агент тратит 5+ попыток чтобы нащупать `hn.algolia.com/api/v1/search`.
- GitHub: 10+ раздельных `gh search repos "awesome X"` вместо одного с нормальным фильтром.

Скрипты закрывают все три проблемы: правильные endpoints, структурированный output, нормальные дефолты.

## Архитектура

```
modules/agents-shared/config/bin/
├── search-reddit        # Reddit search + thread fetch (no auth, public JSON)
├── search-hn            # HN search + item fetch via Algolia API
└── search-github        # GitHub discovery via `gh` CLI wrapper
```

Runtime-слои:

- Source: `modules/agents-shared/config/bin/*` — shared между агентами
- Симлинк: `~/.local/bin/*` через nix-dotbot (см. [modules/claude/default.nix](../modules/claude/default.nix))
- PATH: `~/.local/bin` уже на PATH (см. host config `sharedPath`) → скрипты доступны по имени в любом shell, агенте и tool-call'е

Из `~/.local/bin/` scripts видны обоим агентам без агент-специфичной настройки: Codex наследует PATH из fish shell, Claude Code тоже.

## Использование

### search-reddit

```bash
# Поиск в конкретном сабреддите
search-reddit search "biome vs eslint" --sub typescript --sort top --time year --limit 20

# Глобальный поиск
search-reddit search "typescript scaffold tool" --sort top --time year

# Thread + top comments (аналог старого fetch-reddit.py)
search-reddit fetch "https://www.reddit.com/r/typescript/comments/XXX/..."

# JSON output для programmatic использования
search-reddit search "foo" --json
```

Дефолты: `--sort top`, `--time year`, `--limit 20`, User-Agent выставлен (без него Reddit отдаёт 429).

Endpoints: `https://www.reddit.com/search.json` и `https://www.reddit.com/r/<sub>/search.json` с `restrict_sr=on`, `raw_json=1`.

### search-hn

```bash
# Поиск с фильтром по очкам
search-hn search "typescript scaffold" --min-points 30 --limit 20

# Только Show HN
search-hn search "bun" --tags show_hn

# Хронологически
search-hn search "biome" --by-date --limit 50

# Полный story + comment tree
search-hn fetch 47408727
```

Endpoints (Algolia):
- `https://hn.algolia.com/api/v1/search` — relevance
- `https://hn.algolia.com/api/v1/search_by_date` — chronological
- `https://hn.algolia.com/api/v1/items/<id>` — full thread

Output очищен от `_highlightResult` (до 2KB мусора на hit), HTML-entities декодированы через `html.unescape`.

### search-github

Обёртка над `gh` CLI. Требует `gh auth login` (у пользователя уже есть).

```bash
# Найти awesome-lists для топика одним вызовом (не 10)
search-github awesome typescript --limit 10

# Trending по topic, отсортированные по stars/day
search-github trending rust --limit 20

# Health check конкретного репо
search-github health unjs/giget
# → stars, stars/day, last push days ago, license, open issues, archived?

# Свободный поиск с фильтрами
search-github search "awesome scaffolding" --stars ">100" --language go --pushed-after 2025-01-01
```

Key метрика — `stars_per_day` вместо абсолютных звёзд. Для старых репо 10k★ за 10 лет ≠ 10k★ за 1 год: первый — обычный, второй — растущая звезда.

## Использование из агентов

В `AGENTS.md` есть глобальное правило: любые Reddit/HN/GitHub запросы через эти скрипты, `curl`/`WebFetch` только для URL которые не подходят. Скрипт [find-best skill](find-best-skill.md) написан целиком на них.

## Зависимости

- **Python 3** (есть shebang `#!/usr/bin/env python3`, stdlib only — `urllib`, `json`, `argparse`, `html`, `subprocess`)
- **`gh` CLI** для `search-github` (ставится через Homebrew/Nix)

Никаких pip-пакетов, никаких API-ключей.

## Дефолты и почему

| Скрипт | Дефолт | Почему |
|---|---|---|
| `search-reddit search` | `--sort top --time year --limit 20` | Для find-best use case нужен сигнал, а не свежесть; year покрывает зрелые обсуждения |
| `search-reddit fetch` | max 2 уровня вложенности комментов, 10/level | Top-level комментарии = 90% сигнала |
| `search-hn search` | `--tags story` | Фильтрует комментарии и job posts |
| `search-hn search --min-points` | нет default | Пользователь должен указать явно чтобы не захлебнуться |
| `search-github awesome` | `--limit 20 --sort stars` | Awesome-lists обычно крупные — порог 20 достаточен |
| `search-github trending` | fetch `limit * 2`, sort by stars/day | Нужен запас чтобы отранжировать |

## Расширение

Если нужен новый источник (Lobsters, dev.to, Product Hunt) — добавить `search-<source>` файл в `modules/agents-shared/config/bin/`, обновить секцию Web research в [AGENTS.md](../modules/agents-shared/config/AGENTS.md).

Если нужны shared утилиты (dedupe, clustering) — завести `modules/agents-shared/config/lib/` и импортировать через `sys.path.insert`.

## Замеченные ограничения

- `search-reddit` работает без auth, rate limit ~60 req/min per IP — в пределах нормы для research-сессии
- `search-hn` rate limit 10k/hour per IP — практически никогда не упрётесь
- `search-github` зависит от `gh auth` — `gh` токен должен быть валидным
- HN `story_text` в preview-режиме может содержать HTML-теги `<a>` — пока не фильтруем (не критично для 200-символьного сниппета)

## См. также

- [find-best-skill.md](find-best-skill.md) — основной потребитель скриптов
- Библиотека-вдохновитель: [mvanhorn/last30days-skill/scripts/lib/](https://github.com/mvanhorn/last30days-skill/tree/main/scripts/lib) (откуда взяты URL-паттерны и `clean_hit` идея для HN)

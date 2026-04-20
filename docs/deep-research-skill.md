# deep-research skill

Источник: [modules/claude/config/skills/deep-research/](../modules/claude/config/skills/deep-research/)

Claude Code skill общего назначения для research-задач любого типа — не только tool comparison. Ориентирован на гибридный подход: WebSearch как primary источник + [web-research scripts](web-research-scripts.md) как supplementary layers.

## Зачем

Типичные запросы которые попадают под skill:

- "Найди информацию про X" / "исследуй Y"
- "Research best practices for X"
- "Background on <company/person/incident>"
- "Найди лучший vet в Бангкоке" (local/place research)
- "Compile references on <topic>"
- "Deep dive into <technical concept>"

Без skill Claude делает research ad-hoc: обычно работает, но не использует имеющиеся source-specific инструменты (`search-reddit`, `search-hn`, `search-github`) и не применяет cross-check между источниками.

Skill даёт:

- **Source selection rubric** — когда WebSearch достаточно, когда подключать community scripts
- **WebSearch-first policy** — Google ranking + curated content часто сильнее любого community source
- **Supplementary scripts** — когда нужен local/technical/OSS угол
- **Cross-check guidance** — не принимать single-source claim за факт

## Архитектура

```
modules/claude/config/skills/deep-research/
└── SKILL.md                # ~190 строк, workflow + source selection rubric
```

Runtime-слой:
- `~/.claude/skills/deep-research/SKILL.md` → симлинк через nix-dotbot (см. [modules/claude/default.nix](../modules/claude/default.nix))
- Claude-only: использует `Agent` tool для параллельных subagent'ов когда нужно

Skill не имеет собственных scripts — переиспользует [shared scripts](web-research-scripts.md) в `modules/agents-shared/config/bin/`:

- `search-reddit` — Reddit search + fetch
- `search-hn` — HN Algolia API
- `search-github` — `gh` CLI wrapper для awesome/trending/health

## Core principle

**WebSearch is primary**. Причины:

1. Google's BM25 + reputation ranking находит curated expert content (expert blogs, Wikipedia, named-author guides, docs) — signal density выше чем в user-generated community content
2. Reddit's search ранжирует популярные посты с incidental keyword matches выше focused threads (замер: [find-best sessions comparison](#))
3. HN search отличный по качеству, но узкий по охвату (tech-only audience)
4. GitHub покрывает только OSS угол

Scripts supplement WebSearch когда у темы есть:
- **Community dimension** — local knowledge, real user experience → Reddit
- **Technical depth** — expert commentary, early discussions → HN
- **OSS landscape** — libraries, repos, awesome-lists → GitHub

## Source selection rubric (из SKILL.md)

| Question type | Primary | Supplementary |
|---|---|---|
| Local knowledge ("vet в Бангкоке") | WebSearch | `search-reddit --sub <city>` |
| Technical concept | WebSearch | `search-hn` для commentary |
| OSS tool / library | `search-github awesome` + WebSearch | `search-reddit --sub <tech>` |
| Product comparison | — используй **find-best** skill | — |
| News / incident | WebSearch | `search-hn --by-date` если tech |
| Named person / company | WebSearch | community sentiment scripts |
| Migration stories | `search-reddit` | WebSearch для blog write-ups |

Default first action — **WebSearch**. Scripts вызываются только если topic явно выигрывает от community/OSS angle.

## Принципиальные решения (rationale)

### WebSearch first, не Reddit first

Ранее find-best skill эмфазировал Reddit + HN как primary discovery. На реальных запросах выявилось:

- Global Reddit search возвращает мусор (популярные посты с incidental matches)
- Scoped Reddit search (`--sub X`) хорош для local knowledge, но ограничен одним сабом
- WebSearch без site: фильтра → curated comparison articles (expatden, cleverthai, antfu blog) которые уже агрегируют community knowledge + editorial filter

Решено поднять WebSearch на primary, Reddit опустить на supplementary role.

### Phase 3 подключение scripts — opt-in

Не каждая research-задача требует Reddit/HN/GitHub. Простой factual lookup решается 1-2 WebSearch вызовами. Skill явно требует: *"Reach for scripts IF <условие>"* — не по привычке.

### Parallel subagents когда нужно, не всегда

find-best всегда запускает 2-3 parallel subagents в Phase 1. deep-research проще: scale parallelism под task size. Одна WebSearch достаточна? — не спавни subagents. Нужно посмотреть 5 сабов параллельно? — тогда spawn.

### Cross-check как отдельная фаза

Skill требует Phase 4: "Reconcile contradictions explicitly". Это противоядие против синтеза "как будто всё сошлось". Если два источника противоречат — явно отметить, не прятать.

## Ограничения

- **Claude-only** — `Agent` tool subagents специфичны. Codex-вариант пишется отдельно при необходимости
- **Не замена find-best** — для "найди лучший X для Y" конкретно с user profile matching → find-best skill лучше (он тюнен под long list + deep-dive + mandatory red flag)
- **WebSearch US-only** — Anthropic WebSearch ограничен US IP, reddit.com заблокирован для user-agent. Поэтому `site:reddit.com` через WebSearch не работает — только через native `search-reddit`

## Отношение к другим skills

- **`find-best`** — специализация для tool/product comparison с 4-фазным pipeline + long list + red flags. Использовать когда вопрос конкретно про "который лучше"
- **`fetch-reddit`** — deprecated, заменён `search-reddit fetch`. Оба работают, новый предпочтительнее
- **`deep-research`** — general case, триггерится на широкие research-запросы

## См. также

- [web-research-scripts.md](web-research-scripts.md) — инфраструктура скриптов
- [find-best-skill.md](find-best-skill.md) — специализация для product comparison
- [modules/claude/config/skills/deep-research/SKILL.md](../modules/claude/config/skills/deep-research/SKILL.md) — сам skill

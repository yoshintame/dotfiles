# find-best skill

Источник: [modules/claude/config/skills/find-best/](../modules/claude/config/skills/find-best/)

Claude Code skill для "найди лучший X для Y" workflow — discovery + comparison + personalized recommendation под контекст пользователя.

## Зачем

Базовый use case: "найди лучший tool/product/library для моей задачи". Типичные запросы:
- "альтернатива Firecrawl с self-host до $10/мес"
- "лучший hosted Postgres для Next.js"
- "scaffold-утилита для TS templates"

Без skill Claude идёт в single WebSearch "best X 2026", попадает в первую SEO-помойку, находит 4-6 кандидатов, отвечает без red flags. Skill форсит:

- **Широкий discovery** — WebSearch (curated expert content) + awesome-lists в параллель, Reddit/HN как supplementary через [web-research-scripts](web-research-scripts.md)
- **Long list** (обычно 15-35 кандидатов) + top 5-7 deep-dive
- **Counter-review** — обязательный ≥1 red flag на top pick, анти-сикофантия
- **Профиль юзера** из CLAUDE.md/memory применяется в Phase 4, не раньше

Реальный замер на задаче "лучший TS scaffold" показал:
- **Без skill:** 21 кандидат, 0 red flags, пропущен CVE у Nx
- **Со skill:** 35 кандидатов, red flag на каждого finalist, найден CVE-2025-10894 (Nx supply-chain attack)

## Архитектура

```
modules/claude/config/skills/find-best/
└── SKILL.md             # Phase 1-4 workflow + output template + anti-patterns
```

Runtime-слой:
- `~/.claude/skills/find-best/SKILL.md` → симлинк через nix-dotbot (см. [modules/claude/default.nix](../modules/claude/default.nix))
- Claude-only: использует `Agent` tool для parallel subagent dispatch, которого у Codex нет

Skill не имеет `scripts/` — вся инфраструктура поиска вынесена в [shared scripts](web-research-scripts.md) (`search-reddit`, `search-hn`, `search-github`) и доступна на `$PATH`.

## Pipeline

```
Phase 1: Discovery (parallel × source)
├── Subagent A (PRIMARY)       — WebSearch curated guides + awesome-lists + runtime-native
├── Subagent B (SUPPLEMENTARY) — Reddit --sub X + HN (validation, "switched from" stories)
└── Subagent C (CONDITIONAL)   — Commercial/SaaS (alternativeto.net, pricing comparisons)

Phase 2: Consolidate (lead, sequential)
└── Merge → dedupe → rank by mention×source-diversity → long list 10-25

Phase 3: Deep-dive (parallel × candidate, 5-7 agents)
└── Per candidate: github health, pricing, recent changes, ≥1 red flag (mandatory)

Phase 4: Synthesize (lead)
└── Read CLAUDE.md + ~/.claude/projects/.../memory/ → apply hard constraints → output
```

Output: TL;DR → Discovered list → Top 5-7 deep-dive → Recommendation → Sources.

## Использование

### Через Claude Code (explicit)

```
/find-best Найди лучший hosted Postgres до $20/мес для Next.js
```

Skill триггерится на: `найди лучший`, `best X for`, `alternative to`, `X vs Y`, `посоветуй`, `compare options`.

### Промпт best practices

Хороший input включает:
- Use case в одну строку (что, зачем)
- Constraints (бюджет, платформа, OSS/paid, self-host)
- "Не нужно" список (отсекает шум)
- Baseline кандидатов для starting point (опционально)

Плохой input: "посоветуй базу" — слишком generic, skill выдаст широкое но не точное попадание.

## Принципиальные решения (rationale)

### Long list > top 3

Пользователь явно просил "намного больше вариантов чем top-3". Дефолт 10-25 кандидатов в long list, из них 5-7 в deep-dive. Это даёт широкую картину рынка перед рекомендацией.

### WebSearch + awesome-lists как primary discovery

WebSearch (Google ranking) находит curated named-author contenthip — "best X 2026" guides от expat blogs, comparison articles от индустрийных экспертов, alternativeto.net. Signal density выше чем на Reddit потому что авторы уже сделали отбор. Awesome-lists — куратор-driven источник с PR-driven обновлениями, лучший компактный способ узнать OSS-экосистему. Для SaaS/commercial — awesome-lists hit-or-miss, поэтому Subagent C запускается conditionally.

### Reddit как supplementary, не primary

Ранее Reddit/HN были primary discovery. Эмпирически выявилось: Reddit's search ранжирует viral посты с incidental keyword matches выше focused threads. Даже с Lucene `+word` auto-AND (добавлено в search-reddit) 3+ слов global search дают шумные результаты. Scoped `--sub X` работает хорошо для local knowledge, но ограничен одним сабом.

Практика: Reddit для (a) local/community validation конкретного candidate; (b) "switched from X to Y" stories; (c) обнаружения tools которые не попали в awesome-lists. Не для broad discovery.

### Native alternatives check

Одна из главных ошибок в pilot run — пропустили `bun create` для scaffold-темы потому что его нет в awesome-lists. Explicit шаг "check runtime/package-manager native alternatives" в Subagent A закрыл этот gap.

### Mandatory red flag

Без явного "find ≥1 negative signal" Claude накапливает только позитив (маркетинг везде) и финальная рекомендация получается сикофантной. Если subagent не нашёл — это само по себе flag (brand new, polished marketing, плохо искал).

### Profile applies в Phase 4, не раньше

Если фильтровать по бюджету/платформе на Phase 1, отсекаются интересные опции которые могли быть адаптируемы. Discovery должен быть широким, применение ограничений — в самом конце.

### Scripts для Reddit/HN/GitHub, WebSearch для всего остального

См. [web-research-scripts.md](web-research-scripts.md). Важная находка: Anthropic WebSearch **блокирует reddit.com** (на уровне user-agent), поэтому `site:reddit.com` через WebSearch не работает — только native API через `search-reddit`. Reddit/HN/GitHub запросы идут через `search-reddit`/`search-hn`/`search-github` с правильными endpoints и clean output. Для всех остальных типов запросов (comparison guides, expert blogs, curated lists) WebSearch используется напрямую — он у Anthropic хорошо работает везде кроме reddit.com.

## Ограничения

- **Claude-only** — использует `Agent` tool для parallel dispatch. У Codex CLI параллелизма такого нет; если нужна Codex-версия — писать отдельный skill с `codex exec`-оркестрацией
- **Subagent count budget** — Phase 3 жёстко 5-7 параллельных, больше перегружает context lead-агента. Меньше — теряется breadth в comparison
- **Не подходит для methodology-вопросов** типа "как правильно организовать X" — там нет discrete options, awesome-lists методологий не существует (см. обсуждение в [research-и-sub-skills thread](#))

## Будущие улучшения

- **Re-enable PreToolUse hook** — файл `modules/agents-shared/config/hooks/research-steering.sh` уже написан и протестирован, но отключён в settings.json после того как стало ясно: WebSearch часто даёт лучший сигнал чем scripts для product/tool research. Если практика покажет что Claude игнорирует рекомендации из SKILL.md и делает raw curl на reddit/hn — re-enable одной строкой
- **Dedupe utility** — если добавится shared `modules/agents-shared/config/lib/dedupe.py` с hybrid similarity, Phase 2 merge будет точнее схлопывать упоминания одного tool'а с разными именами
- **Codex-версия** — если потребуется, отдельный `modules/codex/config/skills/find-best/SKILL.md` со своей оркестрацией через `codex exec`. Скрипты переиспользуются без изменений

## См. также

- [deep-research-skill.md](deep-research-skill.md) — general research skill (без привязки к tool comparison). Когда запрос не про "который лучше" — используй его
- [web-research-scripts.md](web-research-scripts.md) — инфраструктура поиска (scripts + Lucene AND поведение)
- [modules/claude/config/skills/find-best/SKILL.md](../modules/claude/config/skills/find-best/SKILL.md) — сам skill

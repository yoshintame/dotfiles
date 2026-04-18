---
name: find-best
description: Discover and compare options for "find the best X for Y" requests — tools, libraries, services, products. Use when user asks "найди лучший", "best X for", "alternatives to", "X vs Y", "посоветуй", "compare options", or wants a personalized recommendation under constraints.
---

# Find Best

Workflow for discovery + comparison + personalized recommendation. Optimized to find as many options as possible from real signal sources (Reddit, HN, awesome-lists, GitHub) and avoid SEO listicles.

## Source priority (trust hierarchy)

```
Reddit/HN top comments (peer recs, with discussion)
  > GitHub stars + recent activity trend
    > Awesome-lists (if last commit < 1 year)
      > Indie expert blogs (named author with reputation)
        > alternativeto.net
          > G2/Capterra (often pay-to-rank, sceptical)
            > "Top X Best Y 2026" SEO listicles  ← skip
              > Vendor self-comparisons          ← skip
```

## Workflow

### Phase 1: Discovery (parallel subagents)

Launch 2-3 subagents IN PARALLEL via Agent tool. Do not pass user profile/constraints to subagents — they should find ALL candidates without premature filtering.

**Subagent A — Awesome-lists (PRIMARY, always run)**
1. `search-github awesome <topic> --limit 10` — single call, finds both `awesome-X` and `awesome X` naming
2. For each found list:
   - Output flags `[STALE >1yr]` — still extract but note
   - WebFetch the README, extract ALL listed candidates with their categorization
3. Also check runtime/package-manager native alternatives:
   - `bun create`, `deno init`, `npm create`, `pnpm create`
   - `create-<framework>` pattern (create-vite, create-next-app, etc.)
   - These are often missing from awesome-lists but widely used
4. Return JSON: `{candidates: [{name, github_url|website, category, source_list, brief_description, stars_if_shown}], stale_lists: [...]}`

**Subagent B — Community sentiment (FRESHNESS, always run)**
1. Reddit search (scripts return structured data, no WebSearch dance needed):
   - `search-reddit search "<topic>" --sort top --time year --limit 20` (global)
   - `search-reddit search "<topic>" --sub <relevant-sub> --sort top --time year` for 2-3 likely subreddits (selfhosted, typescript, programming, macapps, LocalLLaMA, etc.)
2. For 3-5 most relevant threads (high score + high comments) → `search-reddit fetch <url>` to read top comments
3. HN: `search-hn search "<topic>" --min-points 50 --limit 20`. For promising stories → `search-hn fetch <id>`.
4. Extract:
   - Tools mentioned in discussions (compare with awesome-lists to find gaps)
   - "switched from X to Y" / "moved to" / "replaced with" stories
   - "don't use X because" warnings
5. BUDGET: max ~12 script calls total. If pattern fails, stop — don't cascade into curl/duckduckgo fallbacks.
6. Return: `{additional_candidates: [...], sentiment: {tool: brief_opinion}, switching_stories: [...], warnings: [...]}`

**Subagent C — Commercial/SaaS (CONDITIONAL)**
Launch only if topic involves SaaS/commercial tools (most awesome-lists are OSS-only).
1. Check alternativeto.net, indie comparison blogs from named experts
2. Return: `{commercial_candidates: [...]}`

### Phase 2: Consolidate (lead, no subagents)

1. Merge candidates from all subagents
2. Deduplicate by canonical name (e.g., "PostgreSQL" / "postgres" / "PG" → one entry)
3. Rank by mention count × source diversity (mentioned in awesome-list AND on Reddit > only one source)
4. Build the LONG LIST (typically 10-25 candidates)
5. Pick top 5-7 for deep-dive based on:
   - Mention frequency
   - Recency of activity
   - Coverage in source diversity

### Phase 3: Deep-dive (parallel subagents per finalist)

For EACH of top 5-7 candidates, launch 1 subagent in parallel.

Task per subagent:
1. **GitHub health** (if OSS): `search-github health <owner/repo>` — one call returns stars/day, last push, open issues, license, archived status
2. **Pricing** (if commercial): WebFetch pricing page TODAY
3. **Recent changes**: changelog, blog, latest release notes
4. **Negative signals**:
   - `search-reddit search "<tool> switched from OR problems" --sort top --time year`
   - `search-hn search "<tool>" --min-points 30` — look for critical threads
   - Check archive.org for pricing/license changes vs 1-2 years ago
5. **MANDATORY**: find ≥1 red flag. If you cannot find ANY negative signal — that's itself a flag (overly polished marketing, brand new project, or you didn't search hard enough).

Common red flags:
- Last commit > 6 months ago
- Open issues piling up, maintainer silent
- Recent license change (MIT → commercial)
- "Switched from X to Y" pattern in community
- Pricing increased 2-3x in last year
- Single-maintainer (bus factor 1)
- VC-funded with unclear revenue model
- Only positive mentions on vendor blog, silence on Reddit/HN

Return per candidate:
```yaml
name: <Tool>
license: <MIT/AGPL/commercial/freemium>
pricing: <free | $X/mo | usage-based>
last_activity: <YYYY-MM>
github_health: <healthy | declining | stale>
pros: [3 bullets, concrete]
cons: [3 bullets, concrete]
red_flags: [≥1 mandatory]
fit_signals: <"best for X use case", "avoid if Y">
```

### Phase 4: Synthesize and recommend (lead)

1. Read user profile from:
   - `~/.claude/CLAUDE.md`
   - `~/.claude/projects/-Users-yoshintame--dotfiles/memory/MEMORY.md` and linked files
   - Conversation context (explicit constraints in the request)
2. Apply hard constraints (budget cap, platform, license requirement) to filter long list
3. Output using the template below

## Output template

```markdown
# Find Best: <topic>

## TL;DR
**<winner>** — <one-line why for THIS user>. → <next action: install / try / read more>.

## Discovered options (<N> total)

Long list of everything found in Phase 1, one line each:
- **<Name>** — <category>, <one-line>
- **<Name>** — <category>, <one-line>
... (10-25 entries)

## Top <5-7> deep-dive

| # | Name | License | Pricing | Activity | Best for |
|---|------|---------|---------|----------|----------|
| 1 | ... | ... | ... | ... | ... |

### 1. <Name> ⭐ Recommended for your profile
- **Pros**: <3 concrete>
- **Cons**: <3 concrete>
- **Red flag**: <at least 1>

### 2. <Name>
... same structure

## Recommendation for your profile

Based on: <list extracted constraints — budget, platform, preferences from CLAUDE.md/memory>

- **Primary pick**: <X> — <why this one specifically for this user>
- **If <constraint loosens>**: <Y>
- **Skip**: <Z> because <reason>

## Sources
- Awesome-lists: <urls with last-commit dates>
- Reddit threads (most informative): <urls>
- HN: <urls>
- Other: <urls>
```

## Search query patterns (cheat sheet for subagents)

Always prefer the structured scripts over raw WebSearch/WebFetch/curl — they return clean data and avoid dead-end query cascades. `--help` on each for full options.

**GitHub awesome-lists + trending:**
```bash
search-github awesome <topic>                    # finds awesome-X lists
search-github trending <topic>                   # ranked by stars/day
search-github search "<query>" --stars ">100"    # free-text search
search-github health <owner/repo>                # stars/day, license, activity
```

**Reddit:**
```bash
search-reddit search "<query>" --sub <subreddit> --sort top --time year --limit 20
search-reddit search "<query>" --sort top --time year                # global
search-reddit fetch <thread-url>                                      # post + top comments
```

**HN:**
```bash
search-hn search "<query>" --min-points 50 --limit 20
search-hn search "<query>" --tags show_hn          # filter Show HN only
search-hn fetch <story-id>                          # story + comment tree
```

**Migration / negative signal patterns** (pass to the relevant script):
- `"<tool> switched from"`, `"<tool> moved to"`, `"<tool> replaced with"`
- `"don't use <tool>"`, `"<tool> alternatives"`

**Pricing-change history:** WebFetch `https://web.archive.org/web/2024*/example.com/pricing`

All scripts support `--json` for structured output.

## Anti-patterns

- ❌ Skipping Phase 1A (awesome-lists) because "I know the candidates"
- ❌ Applying user constraints in Phase 1-3 — filters too early, kills discovery
- ❌ Returning recommendation without ≥1 red flag for top pick
- ❌ Trusting "Top 10 Best X 2026" SEO listicles
- ❌ Trusting vendor self-comparisons ("X vs us" pages)
- ❌ Treating G2/Capterra rankings as authoritative
- ❌ Reading only Reddit POST bodies — top COMMENTS are where real opinion lives
- ❌ Outputting only 3 candidates — show the full long list, deep-dive 5-7
- ❌ Spawning >7 deep-dive subagents — orchestration overhead exceeds value
- ❌ Sequential subagents in Phase 1 / Phase 3 — must be parallel

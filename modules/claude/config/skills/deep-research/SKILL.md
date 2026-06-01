---
name: deep-research
description: Conduct deep research on arbitrary topics (products, places, concepts, people, incidents). Uses WebSearch as primary source for curated expert content and supplements with Reddit, Hacker News, and GitHub scripts for community voice, technical depth, and OSS discovery. Trigger on "research", "investigate", "find info about", "compile references on", "understand X", "background on Y", "deep dive into".
---

# Deep Research

General-purpose research workflow for non-trivial questions. Not a comparison skill (for "find the best X" use `find-best` instead). Focus is on gathering, synthesizing, and citing real information from the best-available sources.

## Core principle

**WebSearch is the primary source.** Google's BM25 + reputation ranking finds curated expert content (blogs, Wikipedia, news, guides, documentation) — the signal density beats Reddit/HN for most research needs.

Supplementary scripts add layers WebSearch can't fully cover:

- **`search-reddit`** — local community knowledge, real user experience, "switched from X" stories
- **`search-hn`** — technical commentary, early discussions, named experts in the comments
- **`search-github`** — OSS code landscape, repo health, awesome-lists

Reach for scripts when the topic has community/technical/OSS dimension beyond what curated web content provides.

## Source selection

| Question type | Primary | Supplementary |
|---|---|---|
| Local knowledge ("vet in Bangkok", "best cafe in Berlin") | WebSearch | `search-reddit --sub <city>` for local sub validation |
| Technical concept ("how does X work") | WebSearch (docs, blog posts) | `search-hn` for expert commentary |
| OSS tool / library | `search-github awesome <topic>` + WebSearch | `search-reddit --sub <tech>` for user voice |
| Product / service comparison | **use `find-best` skill instead** | — |
| News / incident / recent event | WebSearch | `search-hn --by-date` for tech-adjacent |
| Named person / company | WebSearch | `search-reddit`, `search-hn` for community sentiment |
| Real user experience (switched-from, migration) | `search-reddit` | WebSearch for blog write-ups |

Default first action: **WebSearch**. Only call scripts if the topic explicitly benefits from community or OSS angle.

## Available scripts (on $PATH)

All scripts support `--help` and `--json`. Full reference: the **Web Research Scripts** note in the Obsidian vault (`projects/ai-agent-config/web-research-scripts.md`).

`search-reddit` needs no API key, app, or credentials: it impersonates the official Reddit Android client for an anonymous OAuth token (full scores + comment trees), falling back to anonymous `.json` then RSS if Reddit blocks the token path.

### `search-reddit`

```bash
# Primary pattern: scope to relevant subreddit (better quality than global)
search-reddit search "<query>" --sub <subreddit> --limit 20

# Global as fallback (lower quality — Reddit's ranking favours viral posts with incidental matches)
search-reddit search "<query>" --limit 15

# Read a specific thread with top comments
search-reddit fetch <reddit-url>
```

Defaults: `--sort relevance --time all`. Multi-word queries auto-transform into Lucene `+word1 +word2` for strict AND semantics. Power users: pass `title:X author:Y` etc. directly, or `--loose` to disable auto-AND.

**Caveats**: 2-word queries work well. 3+ word queries often return popular posts with incidental matches (Reddit's ranking problem, not fixable via params). Keep queries short.

### `search-hn`

```bash
# Default: story search by relevance
search-hn search "<query>" --min-points 30 --limit 20

# Show HN / Ask HN only
search-hn search "<query>" --tags show_hn

# Chronological
search-hn search "<query>" --by-date

# Read a specific story with comment tree
search-hn fetch <story-id>
```

### `search-github`

```bash
# Awesome-lists for a topic (single call, matches both `awesome-X` and `awesome X`)
search-github awesome <topic>

# Topic repos ranked by stars/day (trend signal, not absolute stars)
search-github trending <topic>

# Free-text repo search with filters
search-github search "<query>" --stars ">100" --language ts

# One-shot repo health check
search-github health <owner/repo>
```

## Workflow

### Phase 1: Scope the question

1. Clarify what the user actually needs: information? comparison? source list? actionable recommendation?
2. Identify topic type (from the table above).
3. Extract constraints from the request and the user's profile (`~/.claude/CLAUDE.md`, memory files) — platform, budget, language, location.

### Phase 2: WebSearch first

Run WebSearch with a focused query. Good queries include:
- Clear noun phrase for the topic
- Year if recency matters (use current year — see `# currentDate` system context)
- Specific qualifier (location, language, audience)

Iterate with 2-4 WebSearch calls if the first didn't surface enough angles. Don't jump to scripts yet.

### Phase 3: Supplementary sources (if needed)

Reach for scripts IF:
- **Local knowledge**: WebSearch gave general/touristy results, but you need resident perspective → `search-reddit --sub <city/locale>`
- **Technical validation**: you found claims in blogs, want to check community consensus → `search-hn` or `search-reddit --sub <tech>`
- **OSS landscape**: question is about libraries/tools → `search-github awesome <topic>` + `search-github trending <topic>`
- **Migration stories**: you want to know why people stopped using X → `search-reddit search "<X> switched from OR moved away"`

If WebSearch already covered the topic fully, skip scripts. Parallelism: when multiple scripts are needed, launch them as parallel subagents via the `Agent` tool to keep lead context clean.

### Phase 4: Cross-check and synthesise

- Reconcile contradictions explicitly — don't hide them
- Note evidence strength per claim (official source > named expert > community thread > anonymous blog)
- If a claim has only one source, flag it
- Apply user profile/constraints (Phase 1 extracted them) only at this final step

## Output

Structure depends on the question. Common patterns:

**For factual/background research:**
```markdown
# <Topic>

## TL;DR
<2-3 sentence synthesis>

## Key findings
- <fact + source>
- <fact + source>

## Nuances / contradictions
- <claim A> vs <claim B> — <which is more credible and why>

## Sources
- <curated blogs>
- <community threads>
- <documentation>
```

**For local/place research:**
```markdown
# <Topic> in <Location>

## Shortlist (<N> options)
| Name | Note | Source |
|---|---|---|
| ... | ... | ... |

## Recommendation for your profile
<constraints → pick>

## Sources
```

**For technical / OSS research:**
```markdown
# <Topic>

## Landscape
<overview of the space, key players>

## Deep-dive on <top N>
<per-item summary with license, maintainer, current state>

## Community signal
<r/X + HN sentiment summary>

## Sources
```

Adapt as needed — the output template isn't sacred.

## Anti-patterns

- ❌ Jumping straight to `search-reddit` without trying WebSearch first
- ❌ Using `search-reddit` for broad tool comparison (Reddit's ranking favours viral posts with incidental keyword matches; use `find-best` skill which is tuned for that)
- ❌ Passing 3+ word queries to `search-reddit` in global scope (low quality due to Reddit's ranking) — keep global queries to 2 words, or use `--sub X` for longer queries
- ❌ Treating a single blog post as authoritative — cross-check with at least one other source before claiming
- ❌ Applying user constraints during Phase 2 discovery — that narrows too early. Save for Phase 4 synthesis.
- ❌ Loading the lead context with raw WebFetch'd pages when a parallel subagent could summarise them — use `Agent` tool for bulk reading
- ❌ Fetching Reddit threads via WebFetch directly — use `search-reddit fetch <url>` for cleaner output

## Relationship to other skills

- **`find-best`** — use it instead of this skill when the question is specifically "which tool/product/service is best for X". `find-best` has its own parallel discovery pipeline tuned for comparison.
- **`fetch-reddit`** — superseded by `search-reddit fetch`. Both work, prefer the new script for consistency.

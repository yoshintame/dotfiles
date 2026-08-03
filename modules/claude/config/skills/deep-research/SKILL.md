---
name: deep-research
description: Conduct deep research on arbitrary topics (products, places, concepts, people, incidents). Uses WebSearch as primary source for curated expert content and supplements with Reddit, Hacker News, and GitHub scripts for community voice, technical depth, and OSS discovery. Always persists the final report as a deep-research note in the Obsidian vault. Trigger on "research", "investigate", "find info about", "compile references on", "understand X", "background on Y", "deep dive into".
---

# Deep Research

General-purpose research workflow for non-trivial questions. Not a comparison skill (for "find the best X" use `find-best` instead). Focus is on gathering, synthesizing, and citing real information from the best-available sources.

## Core principle

**WebSearch is the primary source.** Google's BM25 + reputation ranking finds curated expert content (blogs, Wikipedia, news, guides, documentation) — the signal density beats Reddit/HN for most research needs.

Supplementary scripts add layers WebSearch can't fully cover:

- **`search-reddit`** — local community knowledge, real user experience, "switched from X" stories, **and tool announcements**
- **`search-hn`** — **announcement index**: the only one of the three with search that actually works; `--tags show_hn` isolates launches
- **`search-github`** — repo health, awesome-lists; name-search is weak (see below)

Reach for scripts when the topic has community/technical/OSS dimension beyond what curated web content provides.

**For OSS discovery specifically, the three sources are three different keys over the same set of repos, and two of the three have broken retrieval:**

| Source | Indexed by | Failure mode |
|---|---|---|
| GitHub | the author's own `name`/`description` — vocabulary of someone who already knows the tool | Circular: you must know the author's words to find it. Measured: 0–1 hit out of 3–4 reasonable queries per tool |
| Reddit / HN | the **announcement** — the author explaining the tool to strangers, i.e. the searcher's vocabulary | Reddit ranking anti-correlates (below); HN is fine |

Dropping any of the three leaves a hole. Curated indexes (awesome-lists) beat all three — mine them first.

## Source selection

| Question type | Primary | Supplementary |
|---|---|---|
| Local knowledge ("vet in Bangkok", "best cafe in Berlin") | WebSearch | `search-reddit --sub <city>` for local sub validation |
| Technical concept ("how does X work") | WebSearch (docs, blog posts) | `search-hn` for expert commentary |
| OSS tool / library | **awesome-list mining** (below) + WebSearch | `search-hn` + `search-reddit --sort new` for announcements; `search-github search` last |
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
# Discovering tools/projects: BROWSE, don't search. Broad word + new + time window.
search-reddit search "built" --sub <subreddit> --sort new --time year --limit 25

# Sentiment, consensus, migration stories: score IS the signal, so rank by it
search-reddit search "<query>" --sub <subreddit> --limit 20

# Read a specific thread with top comments (also: how you resolve a tool name → repo URL)
search-reddit fetch <reddit-url>
```

Defaults: `--sort relevance --time all`. Multi-word queries auto-transform into Lucene `+word1 +word2` for strict AND semantics. Power users: pass `title:X author:Y` etc. directly, or `--loose` to disable auto-AND.

**Pick the sort by task — this is the single biggest quality lever:**

- **Discovery → `--sort new`.** Tool announcements on Reddit sit at **0–12 points**, and `relevance`/`top` are score-weighted — they rank *against* exactly the posts you need. Measured on r/ClaudeCode: `--sort top --time year` + "search" → 20 results, **zero** tools (subreddit drama); `--sort new` + "built" → **seven** announcements out of 20. Scan titles, don't filter by score.
- **Sentiment / migration stories → `relevance` or `top`.** Here a high score is the signal.

This is why manually browsing a subscribed subreddit works when searching it doesn't: a feed is **score-blind**, search is score-weighted.

**Caveats**: 2-word queries work well. 3+ word queries often return popular posts with incidental matches (Reddit's ranking problem, not fixable via params). Keep queries short.

### `search-hn`

```bash
# Default: story search by relevance
search-hn search "<query>" --min-points 30 --limit 20

# Show HN / Ask HN only
search-hn search "<query>" --tags show_hn

# Chronological
search-hn search "<query>" --by-date

# Read a specific story with comment tree (also: resolve a tool name → repo URL)
search-hn fetch <story-id>
```

HN's value here is **not** the audience or the expert comments — it is that Algolia is the only working search of the three, over titles and submission text written to explain a tool to strangers. For OSS discovery, run it even when the topic feels non-HN-ish. Outside OSS/technical discovery its payoff is unproven — don't reach for it by default.

### `search-github`

Run every `search-github` call with `dangerouslyDisableSandbox: true` — under the Bash sandbox it dies with `gh error: ... tls: failed to verify certificate: x509: OSStatus -26276` even though `api.github.com` is allowlisted. The failure reads like an ordinary command error and is easy to skim past.

```bash
# 1. Awesome-lists — ALWAYS at least two angles: the capability AND the ecosystem
search-github awesome "<capability>"     # "semantic search"
search-github awesome "<ecosystem>"      # "claude-code", "obsidian"

# 2. MINE the list you found — this is the step that actually pays, not the search result
gh api repos/<owner>/<repo>/contents/README.md --jq .content | base64 -d | rg -i '<keywords>'

# 3. Name-search — supplement only, ≥3 phrasings of the artifact name
search-github search "<query>" --stars ">100" --language ts

# Topic repos ranked by stars/day (trend signal, not absolute stars)
search-github trending <topic>

# One-shot repo health check
search-github health <owner/repo>
```

**`search-github search` is literal over `name`/`description`** — it hits only when your query nearly quotes the author's own wording, so it cannot be the main discovery channel. Use ≥3 distinct phrasings and treat misses as uninformative. Star filters (`--stars ">30"`) silently cut the long tail where new tools live — drop them during discovery.

**Finding an awesome-list is not reading it.** Step 2 is the payoff; a list returned by step 1 and never greped is a step not taken.

## Query hygiene

A null result is a fact about your query, not about the world. Treat it as evidence only after you have ruled out the query.

- **An errored call is not a result.** Non-zero exit, `gh error:`, TLS failure, `IncompleteRead` → re-run, with `dangerouslyDisableSandbox: true` if the sandbox is implicated. Never let a failed call count as coverage.
- **An empty result from a filtered or long query is not evidence of absence.** Re-run shorter and without filters before concluding anything. "The tool returned nothing" ≠ "nothing exists".
- **One negative answer does not close a step.** `awesome "<capability>"` returning nothing means try `awesome "<ecosystem>"` — not that awesome-lists are a dead end.
- **Resolve names from the announcement that gave them.** Got a tool name from a Reddit/HN post? The repo URL is almost always in the post body: `search-reddit fetch <url>` / `search-hn fetch <id>` first, `search-github search` second. An empty GitHub search for a name you read in an announcement proves nothing — the tool exists, you just can't guess its description.

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
- **OSS landscape**: question is about libraries/tools → awesome-list mining (all three steps), then `search-hn`, then `search-reddit --sort new`, then `search-github search`/`trending`
- **Migration stories**: you want to know why people stopped using X → `search-reddit search "<X> switched from OR moved away"`

If WebSearch already covered the topic fully, skip scripts. Parallelism: when multiple scripts are needed, launch them as parallel subagents via the `Agent` tool to keep lead context clean.

### Phase 3.5: Coverage gate (OSS/landscape questions)

Before synthesising, confirm — do not assume:

- [ ] ≥3 distinct query phrasings per candidate class
- [ ] Zero errored or empty calls left un-rerun
- [ ] Awesome-list **mining** done (found *and* greped), ≥2 topic angles
- [ ] Every tool name seen in an announcement resolved to a repo, or explicitly recorded as unresolved
- [ ] Any claim about the *shape of the market* ("nobody has built X", "the space is thin", "it's all one-person projects") rests on ≥2 independent sources — this is the claim most likely to be an artifact of your own thin coverage

### Phase 4: Cross-check and synthesise

- Reconcile contradictions explicitly — don't hide them
- Note evidence strength per claim (official source > named expert > community thread > anonymous blog)
- If a claim has only one source, flag it
- Apply user profile/constraints (Phase 1 extracted them) only at this final step

### Phase 5: Persist to the vault (default, do this automatically)

Every research run ends by saving the report as a `deep-research` note in the Obsidian vault — don't ask first, just write it. Skip only for a throwaway one-line lookup the user clearly won't revisit.

**Use the `obsidian-vault` skill for all vault conventions** — placement, naming, frontmatter schema (read its `_types/deep-research.type`), and the rule that inter-note links live only in frontmatter. Don't restate those rules here. Deep-research specifics on top of that:

- It's a `type: deep-research` note, `status: current`, `date` = today (from the `# currentDate` system context).
- Slug: append `-<year>` when the topic is recency-sensitive (e.g. `vps-asia-thailand-2026`).
- Body = the Phase 4 synthesis; a "## Источники" list of external source URLs is expected.
- Add 1–3 real `linked:` backlinks to existing notes; if an obvious area hub fits, list the note there too.

After writing, **also present the report in chat** with the clickable saved path.

## Output

The report is a single artifact delivered twice: saved to the vault (Phase 5) **and** shown in chat. Structure depends on the question. Common patterns:

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
- ❌ Hunting for tool announcements with the default `--sort relevance` — score-weighted sorts bury them. `--sort new`
- ❌ Skipping a low-score post during discovery — announcements live at 0–12 points; that is the normal range, not a quality signal
- ❌ Reading a `search-github awesome` result list and moving on without grepping the README of the list you found
- ❌ Treating "No results" or a failed call as a finding — see Query hygiene
- ❌ Concluding "the ecosystem is thin / fragmented / all abandoned" from one search pass — that claim needs the Phase 3.5 gate
- ❌ Treating a single blog post as authoritative — cross-check with at least one other source before claiming
- ❌ Applying user constraints during Phase 2 discovery — that narrows too early. Save for Phase 4 synthesis.
- ❌ Loading the lead context with raw WebFetch'd pages when a parallel subagent could summarise them — use `Agent` tool for bulk reading
- ❌ Fetching Reddit threads via WebFetch directly — use `search-reddit fetch <url>` for cleaner output

## Relationship to other skills

- **`find-best`** — use it instead of this skill when the question is specifically "which tool/product/service is best for X". `find-best` has its own parallel discovery pipeline tuned for comparison.
- **`fetch-reddit`** — superseded by `search-reddit fetch`. Both work, prefer the new script for consistency.

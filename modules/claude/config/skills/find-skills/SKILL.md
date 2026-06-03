---
name: find-skills
description: Find and vet good Claude Code / Cursor skills (SKILL.md) from trusted sources, not star-farmed slop. Use when the user asks to find or discover a skill, "найди скилл", "is there a skill for X", or wants reliable sources for skills.
---

# Find Skills

Locate real, high-signal skills (and SKILL.md / rule files), not slop. This ecosystem is full of AI-generated skills and gamed GitHub stars: do not rank by stars, and do not open-web search by default. Start from the source list below.

## Source priority (trust hierarchy)

Pull in this order; stop early once a higher tier answers the query.

**Tier 1 — official + canonical**
- `anthropics/skills` — official Anthropic reference skills + `spec/` + `template/`. Trust anchor.
- `anthropics/claude-plugins-official` — official curated plugin marketplace (skills + agents + hooks + MCP); auto-loaded by Claude Code.
- `cursor/plugins` — official Cursor Open Plugins spec + first-party plugins.
- `hesreallyhim/awesome-claude-code` — canonical hand-curated index; stated bar is quality, security, originality.

**Tier 1 — named authors (credible engineers, dogfooded from their own config)**
- `mattpocock/skills` — Matt Pocock's working `.claude/`; engineering-discipline skills (tdd, grill-me, diagnose, to-prd). TS/JS bias.
- `obra/superpowers` — Jesse Vincent; includes a `writing-skills/` meta-skill.
- `garrytan/gstack` — Garry Tan (YC); 23 opinionated tools modelling a virtual eng team (CEO, designer, eng-manager, QA, security). Take as a whole-config example, not à la carte — his workflow conventions are baked in.

**Tier 2 — supplements (use the source's own grades; ignore raw counts)**
- `travisvn/awesome-claude-skills` — small, clean English list.
- `helloianneo/awesome-claude-code-skills` — Chinese, 4-tier grades, hard inclusion bar.
- `VoltAgent/awesome-agent-skills` — cross-tool; trust only org-attributed entries, not the "1000+" claim.
- `PatrickJS/awesome-cursorrules` — de-facto `.cursorrules`/`.mdc` corpus (rules layer, for CLAUDE.md / AGENTS.md work).

**Never authoritative (slop / SEO / star-farmed)** — skip or flag: `ComposioHQ/awesome-claude-skills`, `karanb192/awesome-claude-skills`, `agentskill.work`, `agent-skills.cc`, `claudeskills.info`.

## Fetch

There is no REST/JSON API anywhere in this ecosystem — everything is GitHub raw + git trees.

Run the enumerator (deterministic; reads SKILL.md frontmatter across repos):

```
bun scripts/list-skills.ts anthropics/skills mattpocock/skills obra/superpowers cursor/plugins
```

It prints `repo | path | name | description` for every `*/SKILL.md`. Manual equivalents:
- enumerate one repo: `https://api.github.com/repos/<owner>/<repo>/git/trees/main?recursive=1` → keep paths ending `/SKILL.md`
- read one skill: `https://raw.githubusercontent.com/<owner>/<repo>/main/<path>`
- plugin marketplaces: `https://raw.githubusercontent.com/<owner>/<repo>/main/.claude-plugin/marketplace.json`
- awesome-lists: fetch `README.md`, extract linked repos, then enumerate those

`raw.githubusercontent.com` fetches are free; only `api.github.com` counts against the 60 req/hr anonymous limit, so the one trees call per repo is the budget. Set `GITHUB_TOKEN` to raise it.

## Rank

Order candidates by, in priority:
1. **provenance** — official org (anthropics, cursor) > named author with a track record > vendor list > anonymous aggregator
2. **maintenance** — recent `pushed_at`, real commit history, live CONTRIBUTING/issues
3. **stated quality bar** — explicit grades or "no padding" beats volume claims ("1000+", "verified" with no process)

Star count is not a ranking signal here — it is gamed across this ecosystem.

## Broaden with deep-research

When the source list does not cover the query (niche domain, a skill type none of the trusted repos carry), invoke `/deep-research` to discover beyond the list, then apply the same Rank heuristics to whatever it surfaces. Treat anything outside the list as unvetted until it passes provenance + maintenance.

## Before recommending install

No registry scans skills for malware — a 2026 supply-chain attack shipped 400+ malicious skills with payloads in plain text. For any skill you recommend installing: read its `SKILL.md` and every file under its `scripts/`, and pin the install to a commit SHA, not `main`.

---
name: actualize-spec
description: Bring a current-state spec up to date from completed work without rotting it.
---

Catch a current-state spec up to what was actually built, then freeze the work. Source of truth is the implementation, not the task's plan — `implemented ≠ done`, the spec is caught up *from* the result.

## Pick the target

- Notes carry `type:` frontmatter → **vault**. Read [references/vault.md](references/vault.md). Invoke the vault's own `obsidian-vault` skill first.
- Docs typed by folder, no `type:` (`business/`, `technical/`, `tasks/`, `analysis/`…) → **dev-repo**. Read [references/dev-repo.md](references/dev-repo.md). If the repo ships its own docs skill (e.g. `.claude/skills/docs-conventions`), read it and defer to its format, routing and link rules — this skill only adds the actualization discipline on top.

## Procedure, per completed unit of work

1. Read the work and its **real result** (diff, what shipped) — not just the task's plan.
2. Rewrite the matching spec section to the new current-state, **in place**, as a clean snapshot. Never "было → стало".
3. Route everything that is *not* current-state by role (table below) — don't let it land in the spec.
4. Record one terse chronicle line linking to the work (vault `log` / dev status-marker).
5. Freeze the work artifact (vault `status: done` / dev `git mv` to `archive/`). Keep it whole as the detailed archive — who/what/when, commits, acceptance — don't delete it and don't flatten it into the chronicle.
6. Run the FM1 linter on the edited files; scrub every hit.

## Guard 1 — no history in the spec

The spec is "what IS", with no timeline. Reversal language is a bug: `раньше`, `прежн…`, `было ошибкой`, `пересмотрено`, `убрано`, reversal-`теперь`, `было X стало Y`. The delta and the reason for it do not go inside the spec — route them (table). After editing:

```
bun <skill-dir>/scripts/history-lint.ts <edited file or dir>
```

It flags reversal markers in current-state docs only (skips `analysis`/`log`/`tasks`/`archive`, skips fenced code). Markers are deterministic — trust it; scrub every hit in a current-state doc.

## Guard 2 — proportion and altitude

The spec describes the **whole system**; this change touched a small part. You systematically overrate whatever fills your chat context. So the edit scale is fixed regardless of how much was discussed: a behavior rule in **1–3 sentences** replacing the stale text, written at the **same altitude** as the surrounding doc. Match its level of detail — no UI labels or step-by-step if the doc is high-level. A new section only when a new *concept* appeared, never for a new implementation. Leave unaffected sections untouched.

## Guard 3 — one artifact, one role

Don't pile mixed content into the spec. Decompose the result by role and route each part:

| Content | Role | Vault | Dev-repo |
|---|---|---|---|
| What IS now (behavior / contract) | spec | rewrite spec in place | update canon, 1–3 sentences |
| Genuine reversal / rejected alt + reason | decision-log | `DECISIONS` | leave in `analysis`, link from the status-marker |
| Origin story (the whole path) | genesis-analysis | `analysis`, genesis + `superseded` | `analysis` |
| Plan / steps | task | `task` | `tasks/` |
| Chronicle (what, when) | log | `LOG` / `log` note | status-marker |
| Solved open-Q / stale snapshot | — | delete (git keeps it) | delete / archive |
| The finished work itself | frozen archive | task → `status: done` | `git mv` → `archive/` + banner |

A decision-log entry earns its place only when it carries context **beyond the final spec** — a real reversal or a rejected alternative with its reason. If it just states the final design, that is spec; put it in the spec.

## Notes

- A standalone always-on FM1 hook is a separate skill-candidate; here the linter runs on demand inside step 6.

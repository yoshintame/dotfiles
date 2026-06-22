# Vault target

Type-driven Obsidian vault: every note's role is its `type:` frontmatter, not its folder. Invoke the `obsidian-vault` skill first and follow it for placement, naming and links.

## Which notes are current-state

- Current-state, rewritten clean: `type: spec`, `type: reference`. The FM1 linter scans these.
- History-allowed, leave the timeline in: `type: analysis`, `type: log`, `type: task`, `type: idea`, and the `DECISIONS` meta-file.

`spec` = the present ("what IS"), rewritten. `log` = the past, a terse chronicle that is appended, not rewritten. These are two artifacts — never merge the chronicle into the spec.

## Merging a completed task

1. Rewrite the affected `spec` section to the new current-state (Guard 1 + Guard 2).
2. Append one terse line to the effort's `LOG` (or its `log` note) pointing at the task. Chronicle, not prose: *what* changed, *when*, link.
3. A genuine reversal or rejected alternative → `DECISIONS`. For a reversible one, reference the commit hash / superseded artifact instead of narrating it.
4. Freeze the task: `status: done`. It stays a full archive — who/what/when, commits, acceptance criteria. Do **not** delete it and do **not** flatten it into `log`; `archive` is a derived view (a status filter), not a place you move things to.

`implemented ≠ done`: the catch-up of the spec from the real result is the step between those two statuses. Only after the spec matches reality does the task move to `done`.

## Meta-file shape

When an effort is a folder, its meta-concerns are fixed ALL-CAPS files: `STATUS`, `LOG`, `DECISIONS`, `OPEN-QUESTIONS`. They collide by basename across efforts, so link them path-form (`[[effort/LOG]]`). Content docs (spec, analysis, the task plan) are kebab-case with a unique basename, linked by basename.

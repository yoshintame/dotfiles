# Dev-repo target

Documentation repo where a doc's type is its folder, with no `type:` frontmatter (e.g. a Fumadocs site: `business/`, `technical/`, `analysis/`, `tasks/`, `archive/`). If the repo ships its own docs skills, **they win** on format, routing, link form and link-checking — read them first. This file only adds the FM1/FM3 actualization discipline on top.

## Which folders are current-state

- Current-state canon, rewritten clean: `business/`, `technical/`, `user/`. The FM1 linter scans these by path.
- History-allowed: `analysis/`, `tasks/`, `process/`, `archive/`.

## Source of truth is the code

Every status claim ("реализовано", "на прод не выкатывалось", "блокируется X") is verified against the actual code, not copied from a neighbor doc. A doc claiming a business rule the code doesn't have is not edited silently — surface "doc-to-code or code-to-doc" to the user; until then record the actual behavior with an open-question note.

## Merging a completed task

1. Update the canon section to the new current-state. The edit scale is fixed (Guard 2): the behavior rule in 1–3 sentences replacing the stale text, with the history and rejected variants left in `analysis` and linked — never dragged into the canon. A new section only for a new business *concept*, not a new implementation.
2. Status-marker as a blockquote right after the frontmatter / `Jira:` line:
   ```md
   > 🟢 **Статус: реализовано** (сверено с кодом, <month year>). <one-line what now holds>. Канон: [link](/content/docs/...).
   ```
   🟢 done · 🟡 partial (list ready/open sections by number) · 🔴 blocked. In backlogs, completed items are struck through (`### ~~title~~`) with `**Готово**` + a one-paragraph answer and a canon link, not deleted.
3. Archive when the task is done **and** the canon is updated: `git mv` into the mirror path under `archive/<type>/<domain>/`, add the banner, drop the name from the source `meta.json` `pages`, rewrite inbound links, and run the repo's link check to zero broken links.
   ```md
   > 🗄 **Архив.** Работа выполнена и поглощена каноном — документ сохранён как история решений.
   ```

Links use the repo's convention (Fumadocs: absolute `/content/docs/…` with extension; the build rewrites them). Don't invent a link form — copy the one the repo's docs skill specifies.

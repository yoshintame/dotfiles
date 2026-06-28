---
name: extract
description: Distill knowledge units from the current session into vault or dev docs by classifying, routing, proposing a plan, applying on confirm, and verifying. Use when the user says "extract", "fixate", "зафиксируй", "сохрани в vault", "запиши в документ", or session is finalizing.
---

# /extract

## Steps

1. **Classify** — выдели из контекста units. Тип каждого: `question` | `decision` | `fact` | `task` | `research-finding`.

2. **Route** — для каждого unit определи целевой документ и секцию. Vault: `$OBSIDIAN_VAULT` (fallback `~/Documents/obsidian/yoshintame`). Поиск через `rg` по frontmatter `type:` и `linked:`.

   Section contracts:
   - `type: project` → `## Context` | `## Decisions` | `## Open questions` | `## Pending`
   - `type: research` → `## Question` | `## Findings` | `## Options analyzed` | `## Sources`
   - `type: reference` → канонический раздел типа | `## Sources`
   - Связи — через frontmatter `linked:` / `context:`. Inline «Связано:» — не пиши.

3. **Propose** — одним сообщением план: `Decision X → [[hub]]/Decisions; Open question Y → [[hub]]/Open questions; Finding Z → [[research-doc]]/Findings; Migration Open question A → Decision (обоснование B)`. Дождись подтверждения.

4. **Apply** — НЕ append. Перечитай документ целиком, переосмысли, переписывай противоречия, реструктурируй секции по necessity, обнови связанные документы. Migration между секциями — explicit шаг.

5. **Verify** — перечитай записанное. Stands-alone читабельно без контекста сессии? Wikilinks резолвятся?

## Principles

- Distillation, не цитирование чата.
- Документ = текущее понимание. История — git.

## Dev-репы (без vault)

`docs/research/<topic>.md` для research, `docs/<project>.md` или `docs/README.md` как hub. Те же типы и контракты, frontmatter упрощён.

## Out of scope (v1)

- `type: session` workspace-файлы (нужны hooks).
- Auto-migration между секциями.
- LLM-verify против оригинала чата.

Reference: `$OBSIDIAN_VAULT/projects/obsidian-vault-ai-access/extraction-framework.md`

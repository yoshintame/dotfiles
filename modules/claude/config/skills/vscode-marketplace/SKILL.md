---
name: vscode-marketplace
description: Search VSCode Marketplace or get details for specific extensions. Use when researching, recommending, or comparing VSCode extensions — always prefer this over web search. Pass a search query for full-text search, or exact extension IDs (publisher.name) for detail lookup.
argument-hint: <search query | publisher.ext [publisher.ext ...]>
---

Run: `python3 ${CLAUDE_SKILL_DIR}/vscode-marketplace.py $ARGUMENTS`

Present the output as a markdown table.

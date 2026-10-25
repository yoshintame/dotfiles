---
paths:
  - "**/package.json"
  - "**/vite.config.*"
  - "**/.config/wt.toml"
---

# Dev-серверы

Dev-серверы (`wt dev`, `wt dev:local`, `bun run dev`, `vite`) всегда запускай с `dangerouslyDisableSandbox: true`. В песочнице внешние хосты не резолвятся (`getaddrinfo ENOTFOUND`), а прокси Vite игнорирует `HTTP(S)_PROXY`, поэтому каждый запрос `/api` к удалённому бэкенду (дев-стенду) падает с 500. На `sandbox.excludedCommands` не полагайся: подходящие под него команды всё равно запускались полностью в песочнице.

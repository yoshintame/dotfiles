---
name: gitlens-compare
description: Open a GitLens "Search & Compare" view comparing two git refs in the editor (VSCode/Cursor) via a deep link. Use to review a batch of commits — e.g. the ones an AI agent just made — by comparing HEAD~N..HEAD or two explicit hashes. Triggers — "open gitlens compare", "compare commits", "review my commits in gitlens", "сравни коммиты", "открой сравнение в gitlens", "/gitlens-compare".
---

# /gitlens-compare

Открывает в редакторе (VSCode/Cursor) GitLens-сравнение двух refs через deep link — лучший интерфейс для ревью пачки коммитов. Команда `gitlens.compareWith` с обоими refs пропускает пикер и сразу строит сравнение; deep link матчит уже открытый репозиторий по SHA, поэтому отдельный аргумент пути не нужен.

## Когда

Юзер хочет глазами отревьюить набор коммитов — чаще всего то, что только что насыпал агент. Дефолт — последние N коммитов: `HEAD~N...HEAD`.

## Как определить refs

1. **Явные хэши/refs в аргументах** — `/gitlens-compare <ref1> <ref2>` → сравнить `ref1...ref2`.
2. **Число N** — `/gitlens-compare <N>` → `HEAD~N...HEAD`.
3. **Без аргументов** — взять число коммитов, которые ты (агент) сделал в этой сессии. Если не уверен — `git rev-list --count @{u}..HEAD` (коммиты впереди upstream); если upstream нет — спроси N у юзера, не угадывай.

Инвариант: `ref1` — более старый коммит (база), `ref2` — более новый (обычно `HEAD`). GitLens покажет изменения от `ref1` к `ref2` (ref1 = original, ref2 = modified).

## Запуск

```bash
bash ~/.claude/skills/gitlens-compare/scripts/open-compare.sh <ref1> <ref2>
```

Скрипт резолвит refs в полные SHA (чтобы в пути deep link не было слешей из имён веток), собирает `<scheme>://eamodio.gitlens/link/r/<repoId>/compare/<sha1>...<sha2>`, печатает ссылку и делает `open`. Схема редактора (`vscode` / `cursor` / `windsurf`) определяется из окружения.

После запуска кратко отчитайся: какие коммиты сравниваются (диапазон + одна строка `git log --oneline`), и что сравнение открыто в редакторе.

## Заметки

- Запускать из каталога внутри нужного git-репо — репозиторий матчится по SHA, значит он должен быть открыт в редакторе.
- Если `open` заблокирован песочницей — перезапустить вне песочницы; это просто открытие URI-схемы редактора, не сеть.
- Ручная альтернатива без агента: which-key `enter g k` (Compare References) — интерактивный пикер двух refs.

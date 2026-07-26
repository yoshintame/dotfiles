---
name: obsidian-vault
description: Конвенции этого Obsidian vault — type-driven модель, размещение и именование файлов, связи только во frontmatter. Используй при любом создании, редактировании или навигации по заметкам в vault ($OBSIDIAN_VAULT, fallback ~/Documents/obsidian/yoshintame).
---

# /obsidian-vault

Персональный Obsidian vault с нестандартной type-driven моделью. Дефолтный агент её ломает: кладёт файлы в папки наугад, дописывает «## Связанные» в тело, именует файлы Title Case. Ниже — только поправки к этому дефолту.

## Тип

Единица классификации — поле `type:` во frontmatter, а не папка (папка производна от типа). Каждый тип описан схемой `_types/<type>.type` (YAML: `description`, `location.folder`, `fields`). `fields` задаёт валидные поля инстанса: shared-ссылки `"[[title]]"` / `"[[linked]]"` / `"[[tags]]"` плюс inline-поля (`name`, `kind: option|url|plain|number`, `values`, `default`, `required`, `from`).

`ls _types/` — это **индекс** всех типов. Не читай `.type` пачкой: это засоряет контекст. Открывай `_types/<type>.type` **только** перед созданием или правкой инстанса этого типа — чтобы frontmatter совпал со схемой (обязательные поля, допустимые `values`).

## Размещение и именование

- Дефолт: инстанс `type: X` лежит в папке из `location.folder` этого типа. Один тип — одна папка — один base.
- **Со-локация effort-артефактов** (перекрывает дефолт): артефакт (`task` / `analysis` / `idea` / `open-question` / `decision` / `business-spec` / `implementation-spec` / …) с **ровно одним** проектом в `parent:` кладётся в папку инстанса этого проекта — `projects/<proj>/{tasks,analysis,ideas,decisions,spec,…}/<slug>.md`. Глобальная типовая папка — только для мульти-parent и без project-родителя. Со-локованный инстанс — полноценный typed-инстанс (несёт `type:`), НЕ sub-файл; `location-mismatch` warning валидатора на нём ожидаем. Решение: `areas/vault-management/decisions/effort-artifacts-colocated-in-project.md`.
- Инстанс — либо файл `<folder>/<slug>.md`, либо папка `<folder>/<slug>/<slug>.md` + sub-файлы. Папка — только когда инстанс разросся.
- Sub-файлы **не имеют `type:`** — они часть main-файла, не самостоятельные сущности. Файл, который осмысленно цитировать отдельно, — не sub, а отдельный инстанс в своей типовой папке.
- На диске всё **kebab-case** (файлы и папки). `title:` во frontmatter — обычный Title Case или нормальная фраза. Имя файла ≠ `title`.

## Assets (картинки, вложения)

Вложение — sub-файл (без `type:`, часть main-файла): живёт в папке своего инстанса, не в общей свалке.

- **Folder-инстанс** → `<инстанс>/assets/<имя>.<ext>` рядом с main.md (как `projects/kitten-care/assets/`).
- **Flat-инстанс** (`<folder>/<slug>.md`) при первом вложении — **промоуть в folder-инстанс**: `<folder>/<slug>/<slug>.md` + `<folder>/<slug>/assets/`. Вложение — это «инстанс разросся». Безопасно: bases фильтруют по `type:`, `[[slug]]` резолвится по shortest-path — ни запросы, ни ссылки не рвутся.
- Глобальный `_assets/` в корне — **не использовать** (рвёт co-location, отрывает asset от дока).
- Имя — семантичное и vault-уникальное; `<slug-дока>-N.png` — безопасный дефолт (гарантирует резолв wikilink), описательное (`ear-lesion-01.png`) — лучше.
- Embed — wikilink: `![[<имя>.png]]` (vault на shortest-path). Markdown-ссылки `![](…)` не использовать.
- Нативная вставка в Obsidian настроена на `./assets` (`attachmentFolderPath`) — кладёт в `assets/` рядом с заметкой.
- **Скрины, вставленные в чат агенту** — не файлы, а base64 в session-транскрипте: достать байты скриптом `extract-images` (механизм — в глобальном `AGENTS.md`), затем разложить по правилам выше.
- Решение и обоснование: `areas/vault-management/decisions/assets-colocated-in-instance-folder.md`.

## Связи — только во frontmatter

Жёсткий запрет: никаких «## Связанные», «## Related», «См. также», «Связано:» в теле заметки. Связи между инстансами — два поля, массивы `"[[slug]]"`:

- `parent:` — доменно-иерархическая принадлежность («частью чего это»): area / software / organization / родительский проект.
- `linked:` — всё прочее смежное; fallback при сомнении.

```yaml
---
title: Change Picker UX
type: project
status: active
parent:
  - "[[git]]"
linked:
  - "[[git-commit-skill]]"
  - "[[vscode]]"
tags: [git, ux]
---
```

## Навигация

Корень — `$OBSIDIAN_VAULT` (fallback `~/Documents/obsidian/yoshintame`). `[[slug]]` резолвится в `<folder>/<slug>.md`, где folder диктуется типом цели.

```sh
ls "$OBSIDIAN_VAULT/_types/"                       # индекс типов
find "$OBSIDIAN_VAULT" -name "*<keyword>*.md"       # по имени файла
rg -l "<keyword>" "$OBSIDIAN_VAULT" -g "*.md"       # по содержимому
rg -l "\[\[<slug>\]\]" "$OBSIDIAN_VAULT" -g "*.md"  # бэклинки на ноту
```

## Прочее

- Содержимое — на русском; английский только в технических идентификаторах и цитатах. Без emoji.
- Полная модель, таксономия и обоснования (читать при необходимости, не по умолчанию): `$OBSIDIAN_VAULT/areas/vault-management/vault-management.md` — хаб области, оттуда роутинг в `spec/storage-model`, `spec/type-groups` и `decisions/`.

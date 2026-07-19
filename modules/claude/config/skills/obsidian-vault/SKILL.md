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
- **Со-локация effort-артефактов** (перекрывает дефолт): артефакт (`task` / `analysis` / `idea` / `open-question` / `decision` / `business-spec` / `implementation-spec` / …) с **ровно одним** проектом в `parent:` кладётся в папку инстанса этого проекта — `projects/<proj>/{tasks,analysis,ideas,decisions,spec,…}/<slug>.md`. Глобальная типовая папка — только для мульти-parent и без project-родителя. Со-локованный инстанс — полноценный typed-инстанс (несёт `type:`), НЕ sub-файл; `location-mismatch` warning валидатора на нём ожидаем. Решение: `projects/obsidian-vault-structure/decisions/effort-artifacts-colocated-in-project.md`.
- Инстанс — либо файл `<folder>/<slug>.md`, либо папка `<folder>/<slug>/<slug>.md` + sub-файлы. Папка — только когда инстанс разросся.
- Sub-файлы **не имеют `type:`** — они часть main-файла, не самостоятельные сущности. Файл, который осмысленно цитировать отдельно, — не sub, а отдельный инстанс в своей типовой папке.
- На диске всё **kebab-case** (файлы и папки). `title:` во frontmatter — обычный Title Case или нормальная фраза. Имя файла ≠ `title`.

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
- Полная модель, таксономия и обоснования (читать при необходимости, не по умолчанию): `$OBSIDIAN_VAULT/projects/obsidian-vault-structure/obsidian-vault-structure.md`.

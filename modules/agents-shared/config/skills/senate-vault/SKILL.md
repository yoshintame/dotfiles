---
name: senate-vault
description: Конвенции senate-vault — рабочего хранилища памяти о продуктах senate (vault/ в репозитории documentation, до выноса в свой репо). Type-driven модель, размещение и именование, связи только во frontmatter, две оси feature × project. Использовать при любом создании, редактировании или навигации по документам senate-vault, и как conventions-скил шага 1 /extract в senate-контексте.
---

# /senate-vault

Рабочее хранилище senate: плоские типизированные markdown-документы, инстанс модели effort-management. Дефолтный агент модель ломает: кладёт файлы в папки наугад, дописывает «## Связанные» в тело, пишет доки-солянки. Ниже — только поправки к этому дефолту.

## Корень

`~/Development/work/senate/senate@docs/vault` — vault живёт как `vault/` в репозитории documentation (in-repo период; после миграции старого корпуса выносится в свой репо). Это **вне `content/docs/`** (fumadocs его не собирает) и **не путать с самим `content/docs/`** (fumadocs-сайт, старый корпус): всё новое пишется в `vault/`; старый корпус правится по его `docs-conventions` до атомарного переноса.

## Тип

Единица классификации — поле `type:` во frontmatter, не папка (папка производна от типа). Каждый тип описан схемой `_types/<type>.type` (YAML: `description`, `location.folder`, `fields`).

`ls _types/` — индекс всех типов. Не читай `.type` пачкой; открывай `_types/<type>.type` **только** перед созданием или правкой инстанса этого типа — чтобы frontmatter совпал со схемой (обязательные поля, допустимые `values`).

Ядро (границы типов и lifecycle — в `description` схем): state — `business-spec` / `implementation-spec`; process — `idea` / `open-question` / `analysis` / `task`; события — `decision` / `incident`; `knowledge`; сущности — `project` (репозиторий) / `host` / `person`.

## Две оси и акторы

- **`feature:`** — бизнес-домен, литерал-тег, multi. Vocabulary — `_fields/feature.field` (единственный источник; новый домен = правка values там).
- **project** — репозиторий: связь на project-ноту в `parent:` (`parent: ["[[crm-backend]]"]`), отдельного поля нет. `business-spec` следует за фичей, `implementation-spec` и `task` — за проектом(ами).
- **Акторные поля** — `assignee:` (кто делает), `by:` (актор шага timeline), `stakeholder:` (чей вход нужен): связи на `person`-ноты, не сваливать в `linked:`.

## Размещение и именование

- Инстанс `type: X` лежит в папке из `location.folder` этого типа. Один тип — одна папка.
- Инстанс — либо файл `<folder>/<slug>.md`, либо папка `<folder>/<slug>/<slug>.md` + sub-файлы, только когда перерос один файл (сабтаски-зоны, target-доки genesis-analysis).
- Sub-файлы **не имеют `type:`** — они часть main-файла. Файл, который осмысленно цитировать отдельно, — не sub, а отдельный инстанс в своей типовой папке.
- На диске всё **kebab-case**; `title:` — человекочитаемый заголовок. Имя файла ≠ `title`.
- «Архив», «задачи проекта X», «спеки фичи Y» — derived-виды по `status:` / `feature:` / бэклинкам, **не папки**: завершённое замораживается статусом (`done` / `concluded` / `resolved`) на месте.

## Связи — только во frontmatter

Жёсткий запрет: никаких «## Связанные», «## Related», «См. также» в теле. Связи — два поля, массивы `"[[slug]]"`:

- `parent:` — «частью чего»: репозиторий(и) для артефактов, главная задача для вынесенных сабтасок, `senate-infra` для host-нот.
- `linked:` — всё прочее смежное; fallback при сомнении. Рёбра DAG репозиториев — `linked:` между project-нотами.

## Ссылки на немигрированный старый корпус

Новый артефакт нередко ссылается на ещё не перенесённый док в `content/docs/`. Wikilink через границу хранилищ не резолвится, поэтому:

- **Несущая зависимость** (артефакт без цели неполон) → триггер **атомарного переноса цели** в vault тем же заходом; порядок миграции диктуется потребностью. После переноса — обычный `[[slug]]`.
- **Слабая ссылка** («просто связано») → **полный путь** от корня documentation: `content/docs/<...>.md`, не wikilink. `rg 'content/docs' vault/` = живой список миграционного долга.

## История — в timeline, не в теле

Process-артефакты (прежде всего `task`) несут `timeline:` — flow-массив `{ at, status, release? }`; `status:` — его head. Каждый переход статуса — новая запись с датой (дату бери из системы, не угадывай). Хроника «что когда сделано» не ведётся ни доком, ни секцией — выводится из timeline. Поле конвенционное (в `.type` не описано, валидатор даст `unknown-field` warning — это ок).

## Навигация

```sh
V=~/Development/work/senate/senate@docs/vault
ls "$V/_types/"                          # индекс типов
find "$V" -name "*<keyword>*.md"          # по имени файла
rg -l "<keyword>" "$V" -g "*.md"          # по содержимому
rg -l '\[\[<slug>\]\]' "$V" -g "*.md"     # бэклинки на ноту
rg -l "feature:.*<domain>" "$V" -g "*.md" # артефакты домена
```

`[[slug]]` резолвится в `<folder>/<slug>.md`, где folder диктуется типом цели.

## Валидатор

`bunx obsidian-types` из корня vault (dep в `package.json`, GitHub Packages — нужен `GITHUB_TOKEN`). Enforcement — warning; при недоступности валидатора сверяй frontmatter со схемой глазами.

## Прочее

- Содержимое — на русском; английский только в технических идентификаторах и цитатах. Без emoji.
- Коммиты: work-контекст senate, conventional commits, `-S`, атомарно и позиционно (`git-commit-atomic -C <repo> --auto -S "<msg>" <файлы>`).
- Канон модели — спеки самого vault: контракт (типы, оси, lifecycle, гигиена) — `business-spec` [[vault-model]], физический surface — `implementation-spec` [[vault-surface]], репозиторий как сущность — [[senate-vault]] в `projects/`. Спайн модели (общий для инстансов) — `$OBSIDIAN_VAULT/projects/effort-management/` в личном vault. Читать при необходимости, не по умолчанию.

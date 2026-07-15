---
name: obsidian-types
description: Работа с типизированным Obsidian vault через библиотеку и CLI obsidian-types.
---

# /obsidian-types

Vault валидируется и мутируется библиотекой `obsidian-types` (в vault установлена как alias `npm:@yoshintame/obsidian-types`). Дефолтный агент ошибается в трёх местах: скриптует библиотеку ради интроспекции схем, глушит типы кастами, гоняет запись голым `bun script.ts` мимо `obsidian-types run`. Ниже — поправки.

## Bootstrap

1. API-документация — published TSDoc: `Read node_modules/obsidian-types/src/public/index.ts` (+ `migrations.ts`, `config.ts`; все три ≈ 8K токенов). Это единственный источник сигнатур — не угадывать по памяти.
2. CLI-справка: `NO_COLOR=1 bunx obsidian-types --help`, у подкоманд свой `--help`.
3. Интроспекция схем — чтение файлов `_types/<type>.type` / `_fields/<field>.field` напрямую. Библиотеку открывать только за resolved/runtime данными (инстансы, граф ссылок, счётчики) — не писать скрипт, чтобы «распечатать схему».

## Каналы: чтение vs запись

- **Чтение**: `openVault()` → синхронные `findFirst` / `findMany` / `count` с mingo-селектором `{ where }`; body заметки — `await note.text()`. Отдельной `eval`-команды нет (target) — одноразовый read-скрипт оформляй тоже как migration и гоняй через `obsidian-types run` без `--apply`: dry-run ничего не пишет.
- **Запись**: только `defineMigration` + `obsidian-types run <script>`. Не запускать мутирующий скрипт голым `bun` — runner делает codegen, typecheck скрипта, git-clean check и держит dry-run по умолчанию.

## Migration-скрипт — текущая форма

```ts
import { openVault } from 'obsidian-types'
import { defineMigration } from 'obsidian-types/migrations'

export default defineMigration({
  name: 'rename status -> state on projects',
  up: async () => {
    const vault = await openVault()
    try {
      const result = vault.update(
        { where: { type: 'project' } },
        { $rename: { 'data.status': 'data.state' } },
      )
      console.log({ matched: result.matched, modified: result.modified })
      await vault.apply({ confirm: true })
    } finally {
      vault.close()
    }
  },
})
```

- `await vault.apply({ confirm: true })` в теле обязателен. Под `run` env-гейт его перекрывает: без `--apply` это dry-run, с `--apply` — запись. Вне `run` `confirm` и есть гейт.
- Порядок всегда: `obsidian-types run migrations/x.ts` → прочитать вывод → тот же вызов с `--apply`.
- Логирование — один `console.log({ matched, modified })` из результата мутации. Не печатать по заметке в цикле. (Target P4: runner будет печатать план/счётчики сам — тогда и этот лог убрать.)
- Target-фичи, которых нет сегодня: `run: (vault) => …` с open/apply/close в runner'е (P2), `match:`-селектор с типизацией драфта (P3), `eval`-команда (P5). Не изобретать их в скриптах.

## Типизация

- Не кастовать возвраты библиотеки: `as Record<string, unknown>` на `FieldDef` / `TypeDef` / результатах глушит уже существующие типы.
- Чистый vault: typed-путь — `openTypedVault()` из `_types/.generated/vault.ts` (codegen), per-type overloads `findMany('project')`.
- Грязный vault (remediation/fix-скрипты): `openTypedVault` непригоден — он открывает со `validate: 'strict'` и бросает на любой ошибке. Канон — `openVault()` и mingo-пути `'data.<field>'` без кастов.

## Автофикс (CLI)

- Цикл: `bunx obsidian-types validate` → `fix --dry-run` → `fix`.
- `fix` без флагов применяет только детерминированные фиксы (порядок полей, однозначная кардинальность). Семантические — `title-format-mismatch`, `field-value-not-in-enum`, `missing-required-field` — только под `--semantic`: они перезаписывают человеческие значения, dry-run обязателен.
- Convergence при `--semantic`: отсутствующее required-поле вставляется пустым стабом → следующий `validate` даёт `required-field-no-default` → заполнить значение (или `default:` в `.type`); повторный прогон сходится. Это ожидаемое поведение, не баг.
- Перемещения файлов — за отдельными флагами `--move-files` / `--rename-files` (или `fixer.renameFiles` в конфиге).
- Тумблеры `fixer.*` и секция `serialization` (минимальные диффы) — в `.obsidian-types.config.ts`; сигнатуры в `node_modules/obsidian-types/src/public/config.ts`.

## Версия

Написано против 0.2.0. Если в `package.json` vault'а закреплена 0.1.1: `--semantic`-гейта нет (там `fix` сразу переписывает семантику — не запускать без `--dry-run` и точечного списка файлов), serialization-fidelity нет (диффы шумные — коммитить vault перед прогоном).

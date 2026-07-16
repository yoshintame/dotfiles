---
name: vault-types
description: Работа с типизированным Obsidian vault через библиотеку и CLI vault-types.
---

# /vault-types

Vault валидируется и мутируется библиотекой `vault-types` (в vault установлена как alias `npm:@yoshintame/vault-types`). Дефолтный агент ошибается в трёх местах: скриптует библиотеку ради интроспекции схем, глушит типы кастами, гоняет запись голым `bun script.ts` мимо `vault-types run`. Ниже — поправки.

## Bootstrap

1. API-документация — published TSDoc: `Read node_modules/vault-types/src/public/index.ts` (+ `migrations.ts`, `config.ts`; все три ≈ 8K токенов). Это единственный источник сигнатур — не угадывать по памяти.
2. CLI-справка: `NO_COLOR=1 bunx vault-types --help`, у подкоманд свой `--help`.
3. Интроспекция схем — чтение файлов `_types/<type>.type` / `_fields/<field>.field` напрямую. Библиотеку открывать только за resolved/runtime данными (инстансы, граф ссылок, счётчики) — не писать скрипт, чтобы «распечатать схему».

## Каналы: чтение vs запись

- **Чтение**: `openVault()` → синхронные `findFirst` / `findMany` / `count` с mingo-селектором `{ where }`; body заметки — `await note.text()`. Отдельной `eval`-команды нет (target) — одноразовый read-скрипт оформляй тоже как migration (`console.log` результата внутри `run`) и гоняй через `vault-types run` без `--apply`: dry-run ничего не пишет.
- **Запись**: только `defineMigration` + `vault-types run <script>`. Не запускать мутирующий скрипт голым `bun` — runner делает codegen, typecheck скрипта, git-clean check и держит dry-run по умолчанию.

## Migration-скрипт

```ts
import { defineMigration } from 'vault-types'

export default defineMigration({
  name: 'rename status -> state on projects',
  run: (vault) => {
    vault.update(
      { where: { type: 'project' } },
      { $rename: { 'data.status': 'data.state' } },
    )
  },
})
```

- Runner сам открывает vault, вызывает `run(vault)`, применяет, печатает план/warnings/счётчики и закрывает в `finally`. В теле `run` НЕ вызывать `openVault()`, `vault.apply()`, `vault.close()` и не печатать план вручную.
- Гейт записи: CLI `--apply` форсит запись, `--dry-run` форсит dry-run, иначе решает поле `apply?: boolean` миграции (default false).
- Порядок всегда: `vault-types run migrations/x.ts` → прочитать план → тот же вызов с `--apply`.
- Target-фичи, которых нет: `match:`-селектор с типизацией драфта (P3), `eval`-команда (P5). Не изобретать их в скриптах.

## Типизация

- Не кастовать возвраты библиотеки: `as Record<string, unknown>` на `FieldDef` / `TypeDef` / результатах глушит уже существующие типы.
- Чистый vault: typed-путь — `openTypedVault()` из `_types/.generated/vault.ts` (codegen), per-type overloads `findMany('project')`.
- Грязный vault (remediation/fix-скрипты): `openTypedVault` непригоден — он открывает со `validate: 'strict'` и бросает на любой ошибке. Канон — `openVault()` и mingo-пути `'data.<field>'` без кастов.

## Автофикс

- CLI-цикл: `bunx vault-types validate` → `fix --dry-run` → `fix`. Из библиотеки то же самое — `vault.fix(selector?, { semantic?, moveFiles?, renameFiles? })` / `note.fix()`: правки буферизуются как обычные мутации до `apply`.
- `fix` без флагов применяет только детерминированные фиксы (порядок полей, однозначная кардинальность). Семантические — `title-format-mismatch`, `field-value-not-in-enum`, `missing-required-field` — только под `--semantic`: они перезаписывают человеческие значения, dry-run обязателен.
- Convergence при `--semantic`: отсутствующее required-поле вставляется пустым стабом → следующий `validate` даёт `required-field-no-default` → заполнить значение (или `default:` в `.type`); повторный прогон сходится. Это ожидаемое поведение, не баг.
- Перемещения файлов — за отдельными флагами `--move-files` / `--rename-files` (или `fixer.renameFiles` в конфиге).
- Тумблеры `fixer.*` и секция `serialization` (минимальные диффы) — в `.vault-types.config.ts`; сигнатуры в `node_modules/vault-types/src/public/config.ts`.

## Версия

Написано против 0.2.0. Если в `package.json` vault'а закреплена 0.1.1: `--semantic`-гейта нет (там `fix` сразу переписывает семантику — не запускать без `--dry-run` и точечного списка файлов), serialization-fidelity нет (диффы шумные — коммитить vault перед прогоном).

# Bun: проблема с глобальными пакетами

## Суть проблемы

Bun использует **плоскую структуру** `node_modules` для глобальных пакетов (`~/.cache/.bun/install/global/node_modules/`). Все зависимости всех глобально установленных CLI-утилит складываются в одну общую папку.

Если два глобальных пакета зависят от разных версий одной библиотеки (например, `commander@2` и `commander@12`), bun установит только одну версию — и один из пакетов сломается.

### Пример

`@dbml/cli` зависит от `commander@2`, а `@modelcontextprotocol/inspector` — от `commander@7+`. Bun ставит `commander@2.20.3`, и `mcp-inspector` падает с ошибкой:

```
program.name(...).allowExcessArguments is not a function
```

## Почему npm/pnpm не страдают

- **npm** — при конфликте создаёт вложенные `node_modules` внутри пакета с правильной версией.
- **pnpm** — использует изолированную структуру с симлинками. Каждый пакет видит только свои объявленные зависимости в правильных версиях. Конфликты невозможны по дизайну.

## Где хранятся глобальные package.json

| Менеджер | Путь |
|----------|------|
| bun | `~/.cache/.bun/install/global/package.json` |
| pnpm | `~/.local/share/pnpm/global/5/package.json` |

## Решение

Использовать **pnpm** для глобальных CLI-утилит вместо bun:

```bash
pnpm add -g <package-name>
```

Либо запускать утилиты через `bunx`/`npx` — они создают изолированное окружение на каждый запуск и не конфликтуют.

### Настройка pnpm

Если `pnpm` не в PATH, выполнить:

```bash
pnpm setup
```

## Ссылки

- [Bun issue: global install также ставит бинарники зависимостей](https://github.com/oven-sh/bun/issues/10985)
- [Bun issue: linker=isolated игнорируется](https://github.com/oven-sh/bun/issues/22148)
- [pnpm: symlinked node_modules structure](https://pnpm.io/symlinked-node-modules-structure)

# `dev` — fish-функция запуска dev/start

Файл: [modules/fish/config/functions/dev.fish](../modules/fish/config/functions/dev.fish)

## Что делает

Запускает `dev` или `start` скрипт из `package.json` в текущей директории, автоматически определяя пакетный менеджер по lock-файлу. Аргументы прокидываются дальше в скрипт.

## Алгоритм

1. Проверяет, что в `$PWD` есть `package.json`. Иначе — ошибка.
2. Проверяет наличие `jq` (нужен для парсинга `package.json`).
3. Определяет пакетный менеджер по lock-файлу:
   - `bun.lock` / `bun.lockb` → `bun`
   - `pnpm-lock.yaml` → `pnpm`
   - `yarn.lock` → `yarn`
   - `package-lock.json` → `npm`
   - ничего нет → `bun` (дефолт)
4. Проверяет, что выбранный pm установлен.
5. Читает `scripts.dev` и `scripts.start` через `jq`.
6. Выбирает что запустить:
   - оба есть → `dev` (с предупреждением в stderr)
   - только один → его
   - ни одного → ошибка
7. Печатает в stderr `→ <pm> run <script> <args>` и выполняет.

## Зачем

В разных репозиториях разные pm и разные имена основного скрипта. `dev` снимает необходимость помнить, что в этом репо `bun run start`, а в соседнем — `pnpm dev`. Запускаешь `dev` — оно само разбирается.

## Примеры

```fish
dev                    # запустит bun/pnpm/yarn/npm run dev (или start)
dev --port 4000        # прокинет --port 4000 в скрипт
```

## Зависимости

- `jq` — установлен через Brewfile
- хотя бы один из `bun` / `pnpm` / `yarn` / `npm` (mise или brew)

# Bun-скрипты в dotfiles

Утилитарные скрипты в репозитории пишутся на TypeScript и запускаются через [Bun](https://bun.sh/) — быстрый рантайм без этапа компиляции.

## Почему Bun, а не bash

- Типизация и автодополнение в IDE
- Нормальная работа с JSON (brew JSON API, plist-парсинг)
- Один язык для скриптов и пакетов в `packages/`
- `Bun.$` — shell-тегированные шаблоны вместо `child_process`

## Структура

Скрипты лежат рядом с тем, что они обслуживают:

```
packages/dump-packages/              # CLI: дамп unmanaged/Setapp приложений
packages/proxy-bindings/src/cli.ts   # кодген proxy-bindings
```

Вызываются из mise tasks в `dot.toml`:

```toml
["dot:dump-packages"]
run = 'bun run "$HOME/.dotfiles/packages/dump-packages/src/cli.ts"'
```

Или напрямую из resticprofile hooks (с полным путём к бинарнику, т.к. cron не наследует PATH):

```yaml
run-before:
  - "/opt/homebrew/bin/bun run {{ .Env.HOME }}/.dotfiles/packages/dump-packages/src/cli.ts"
```

## Типы в VS Code

TypeScript Language Server в VS Code не знает Bun API (`Bun.file()`, `Bun.$`, `import.meta.dir`) без явной установки типов. Глобального решения на уровне OS не существует — это [известная проблема](https://github.com/oven-sh/bun/issues/4586).

### Как работает сейчас

В корне репозитория:

- `tsconfig.json` — fallback-конфиг для всех `.ts` файлов без своего tsconfig
- `package.json` — единственная зависимость `bun-types`
- `node_modules/` — в `.gitignore`, восстанавливается через `bun install`

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "types": ["bun-types"],
    // ...
  }
}
```

Проекты внутри репозитория со своим `tsconfig.json` (например `packages/proxy-bindings/`) используют свой конфиг и не затрагиваются.

### На новой машине

```bash
bun install   # в корне ~/.dotfiles — подтянет bun-types
```

### Почему не ATA

VS Code умеет автоматически скачивать `@types/*` пакеты (Automatic Type Acquisition). Но ATA:
- Не работает надёжно для standalone `.ts` файлов без `package.json` в дереве
- Кэширует типы непрозрачно — сложно отлаживать
- Отключена в конфиге VS Code (`typescript.disableAutomaticTypeAcquisition` было `true`)

Явная зависимость в `package.json` проще и предсказуемее.

## Bun API cheatsheet

```typescript
import { $ } from "bun";

// Shell commands
const output = await $`brew list --cask`.text();
await $`mkdir -p ${dir}`.quiet();

// Files
const file = Bun.file("path/to/file");
if (await file.exists()) {
  const content = await file.text();
}
await Bun.write("path/to/file", content);

// Glob
const glob = new Bun.Glob("*.app");
for await (const path of glob.scan({ cwd: dir, onlyFiles: false })) {
  // ...
}

// Script location (аналог __dirname)
import.meta.dir    // директория текущего файла
import.meta.path   // полный путь к текущему файлу

// CLI args
Bun.argv[2]  // первый аргумент после имени скрипта
```

## Ограничения

- `Bun.file().exists()` возвращает `false` для директорий — использовать `glob.scan()` или `fs/promises`
- В cron/launchd нужен полный путь к `bun` (`/opt/homebrew/bin/bun`)
- VS Code extension (`oven.bun-vscode`) даёт дебаггер, но не инжектит типы

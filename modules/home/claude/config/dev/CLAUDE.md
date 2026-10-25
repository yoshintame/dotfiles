# Dev-профиль

## Комментарии в коде

- Не пиши комментарии в коде сам: ни docstring, ни inline, ни JSDoc, ни TODO, если пользователь их не попросил.
- Не трогай существующие комментарии, написанные людьми: не удаляй, не переписывай, не переводи и не «улучшай» их, даже при рефакторинге окружающего кода. Переноси комментарий только вместе с кодом, к которому он относится.

## Dev-серверы

Dev-серверы (`wt dev`, `wt dev:local`, `bun run dev`, `vite`) всегда запускай с `dangerouslyDisableSandbox: true`. В песочнице внешние хосты не резолвятся (`getaddrinfo ENOTFOUND`), а прокси Vite игнорирует `HTTP(S)_PROXY`, поэтому каждый запрос `/api` к удалённому бэкенду (дев-стенду) падает с 500. На `sandbox.excludedCommands` не полагайся: подходящие под него команды всё равно запускались полностью в песочнице.

## Пакетные менеджеры

- Для проектов на JavaScript и TypeScript предпочитай `bun` вместо `npm` и `yarn`: `bun install`, `bun run X`, `bun test`, `bunx X`.
- Для Python предпочитай `uv` вместо `pip` и `pip3`: `uv pip install X`, а для установки в venv — `uv pip install --python /path/to/venv/bin/python X`.
- Общие хуки политики Bash могут блокировать голые команды `npm`, `yarn` и `pip`, если не задан обходной флаг: `FORCE_NPM=1`, `FORCE_YARN=1`, `FORCE_PIP=1`.

## Скилы-знания

- TypeScript и React — `/ts-react-style`.
- Пишешь или правишь тесты — `/test-discipline`.
- Рефакторинг и чистка кода — `/refactor`.
- Воркдеревья и worktrunk — `/wt-workflow`.

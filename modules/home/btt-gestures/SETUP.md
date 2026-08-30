# btt-gestures — setup

Декларативная конфигурация трекпадных жестов BetterTouchTool через её REST API.
Источник правды — `btt-gestures.yaml`. Идемпотентный sync через `dot btt-gestures sync`.

См. также: `[[keybinds-trackpad]]` в Obsidian-vault (философия, раскладка, backlog).

## Один раз — bootstrap

### 1. BTT Web Server

BTT → Preferences → Advanced Settings → Webserver:

- Enable webserver
- Port: `33344` (или другой — поправь `webserver.url` в `btt-gestures.yaml`)
- Sets a shared secret — скопируй

### 2. Положить secret в SOPS

```fish
echo "BTT_WEBSERVER_SHARED_SECRET: <вставь сюда>" > modules/btt-gestures/secrets.yaml
sops -e -i modules/btt-gestures/secrets.yaml
```

После `dot rebuild` файл материализуется в `~/.config/sops-nix/secrets/BTT_WEBSERVER_SHARED_SECRET`.
CLI читает оттуда автоматически, если `$BTT_WEBSERVER_SHARED_SECRET` не выставлен.

### 3. Macros в системных настройках

Универсальный «первый шаг», без которого 3F-жесты конфликтуют:

- System Settings → Trackpad → More Gestures:
  - **Disable** "Three-finger drag" (или Accessibility → Pointer Control → Trackpad Options)
  - Mission Control swipe direction — выставить чтобы 3F swipe up/down НЕ ловился macOS'ом
- System Settings → Trackpad → Point & Click:
  - **Disable** "Look up & data detectors" (3-finger tap) — нужен под per-app middle-click

### 4. AltTab

Открыть AltTab → Settings → Controls:

- **Shortcut 1** = режим «список приложений»:
  - Hold key: `Cmd+Alt+Ctrl+Shift`
  - Next: `A` (matches `altTabApps` из `proxy-bindings.yaml`)
  - Selection mode: "App switcher (Cmd+Tab equivalent)" — одно окно per app
- **Shortcut 2** = режим «окна активного приложения»:
  - Hold key: `Cmd+Alt+Ctrl+Shift`
  - Next: `W` (matches `altTabWindows`)
  - Selection mode: "Windows of the current app only"

### 5. VoiceInk Power Mode

VoiceInk → Settings → Power Modes → **New**:

- Name: `Chats` (или любое)
- Application scope: Slack, Telegram, iMessage, Discord, WhatsApp, Arc
- **Auto Send: Return**
- Hotkey: `Cmd+Alt+Ctrl+Shift+V` (matches `voiceInkToggle`)
- Type: Push-to-talk

## Каждый раз — sync

После правки `btt-gestures.yaml`:

```fish
dot btt-gestures sync
```

Опциональные команды:

```fish
dot btt-gestures diff    # dry-run: показать что добавится / удалится
dot btt-gestures dump    # вывести trigger JSON без обращения к BTT
```

Удаление жеста — убрать запись из YAML, потом `sync`: orphans удалятся по тегу `[managed:btt-gestures]` в description.

## Verify первого жеста

После первого `sync`'а:

1. Открой BTT → Trackpad → All Apps — должны появиться записи с тегом `[managed:btt-gestures]`.
2. Правый клик по любой → **Copy JSON** → сравни с выводом `dot btt-gestures dump`.
   - Если расхождение по `BTTTriggerType` или `BTTPredefinedActionType` — поправь `src/triggers.ts` или `src/actions.ts`. Конкретные числа BTT version-specific.
3. Сделай жест физически и проверь action.

## Troubleshooting

| Симптом | Причина | Фикс |
|---|---|---|
| `get_triggers failed: 401` | shared_secret неверный | Перепроверь `modules/btt-gestures/secrets.yaml` |
| `ECONNREFUSED 127.0.0.1:<port>` | Web Server выключен или другой порт | BTT Preferences → Advanced → Webserver; обнови `webserver.url` в `btt-gestures.yaml` |
| Жест отображается, но `BTTTriggerTypeDescriptionReadOnly` показывает не тот жест | `BTTTriggerType` число не подходит для этой версии BTT | Запусти `bun -e` пробинг скрипт (см. ниже) для своей версии BTT и обнови `src/triggers.ts` |
| Triggers попадают как "orphans" — есть через `get_trigger/?uuid=` но не в GUI | Использован `update_trigger` для создания нового (он не сохраняет metadata) | Sync использует `delete + add_new_trigger` — должно не происходить |
| Дубли после `sync` | Старая ручная запись с тем же жестом | Удали ручную в BTT GUI, потом sync снова |

## Тонкости физического выполнения жестов

- **3F pinch in/out (cut/paste)** — делать **от центра трекпада в стороны** (или наоборот), используя **максимальную доступную дистанцию**. На полу-высоте трекпада или с маленьким ходом BTT pinch-detection нестабилен — он требует заметного изменения дистанции между thumb и остальными пальцами. Чем больше «ход» — тем надёжнее срабатывание.
- **Thumb + 2 fingers** — большой палец должен быть **физически ниже** двух других на трекпаде; если все три пальца на одной горизонтали, BTT не классифицирует thumb и жест не сработает.
- **3F swipes** — короткий resolute swipe одним движением; «протяжка» с замедлением иногда не распознаётся как swipe.

## API quirks (отлично знать)

- БТТ принимает только **GET** для всех webserver endpoints, несмотря на то что docs утверждают POST для `update_trigger`/`add_new_trigger`.
- `delete_trigger/?uuid=<uuid>` — реальное имя endpoint'а (не `delete_trigger_with_uuid` как пишут некоторые threads).
- `update_trigger` для **существующих** триггеров. Для нового — `add_new_trigger`. Если использовать `update_trigger` на несуществующий UUID, БТТ его создаст, но в orphan-состоянии (нет в GUI list, виден только по UUID).
- `get_triggers/?trigger_type=BTTTriggerTypeTouchpadAll` — фильтр по типу (`trigger_type`, не `trigger_class`).
- `get_trigger/?uuid=<uuid>` возвращает **кеш** — может отдавать stale data после delete. Не использовать для idempotency-check.
- Description должно URL-encode'иться через `%20` для пробелов, не `+`. `URLSearchParams.set()` использует `+` — не подходит, нужно ручное `encodeURIComponent`.

## Пробинг trigger type IDs для своей версии BTT

Числа `BTTTriggerType` отличаются между версиями BTT и недостоверны в docs. Чтобы получить точное соответствие для своей версии:

```fish
set PROBE_UUID A0000000-0000-0000-0000-000000000001
for n in (seq 90 230)
  set JSON '{"BTTTriggerType":'$n',"BTTTriggerClass":"BTTTriggerTypeTouchpadAll","BTTTriggerTypeDescription":"probe","BTTEnabled":1,"BTTOrder":0,"BTTActionsToExecute":[{"BTTPredefinedActionType":24}]}'
  set ENCODED (python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" $JSON)
  curl -sX GET "http://127.0.0.1:57528/update_trigger/?uuid=$PROBE_UUID&json=$ENCODED" -o /dev/null
  set DESC (curl -sX GET "http://127.0.0.1:57528/get_trigger/?uuid=$PROBE_UUID" | grep "DescriptionReadOnly" | sed -E 's/.*: "([^"]+)".*/\1/')
  echo "$n  $DESC"
end
curl -sX GET "http://127.0.0.1:57528/delete_trigger/?uuid=$PROBE_UUID" -o /dev/null
```

Output этого скрипта — авторитативная таблица для конкретной BTT version'и.

---
name: disk-layout
description: Конвенции расположения проектов и клонов на диске.
---

При `git clone`, `git init`, или любой операции выбирающей место для репозитория — определи категорию и клонируй в соответствующую директорию.

| Сценарий | Target |
|----------|--------|
| Изучить чужой код, ответить на вопрос, reference | `~/.cache/repos/<repo-name>` |
| Рабочий проект (senate, vtb, и т.д.) | `~/Development/work/<company>/<repo>` |
| Свой проект (remote yoshintame или новый) | `~/Development/personal/<repo>` |
| Форк чужого репо с планом вносить изменения | `~/Development/forks/<repo>` |
| Spike, playground, одноразовый эксперимент | `~/Development/sandbox/<repo>` |

`~/.cache/repos/` — disposable XDG-кеш: удаляется без потерь, переклонируется по необходимости. Критерий: клон нужен агенту чтобы прочитать код, не пользователю чтобы работать.

Корень `~/Development/` — запрещён как target; всегда подкатегория. Подпапки по технологии (ts/, go/, nix/) — запрещены; внутри каждой категории плоская структура.

Хук `git-clone-layout.sh` deny'ит clone за пределы разрешённых префиксов. Override: `FORCE_CLONE_PATH=1`.

# Markdown Preview & Editing в Cursor/VS Code

## Требования

### Must have

- Красивый рендеринг markdown (preview mode, не split view)
- Поддержка таблиц (GFM)
- Поддержка Mermaid диаграмм
- Sidebar навигация по хедингам (outline/TOC)
- Шорткат для переключения view/edit mode (без split view)
- Возможность выделять текст в view-режиме

### Nice to have

- Поддержка MDX (хотя бы с вырезанием JSX блоков)
- Интеграция с Cursor `Cmd+L` и Claude Code `insertAtMention` — выделенный текст в preview должен работать как reference
- WYSIWYG редактирование

### Критичные проблемы

- **Initial loading time** — даже встроенный preview и Markdown Preview Enhanced рендерят 1-2 секунды. Это большой friction для основного use case (просмотр)
- **Перерендер при переключении табов** — встроенный preview пересоздаёт webview с нуля при уходе с таба и возврате (webview не использует `retainContextWhenHidden`). Это делает workflow с переключением между файлами мучительным

### Контекст

- Большинство текста пишет AI — ручное редактирование редкое
- Основной use case — просмотр, не редактирование
- Split view не нужен и мешает

---

## Исследованные варианты

### 1. Встроенный Preview + bierner.markdown-mermaid

**Подход:** Нативный markdown preview VS Code + расширение для Mermaid.

| Критерий                   | Оценка                                                                                                 |
| ----------------------------| --------------------------------------------------------------------------------------------------------|
| Таблицы                    | GFM из коробки                                                                                         |
| Mermaid                    | Через `bierner.markdown-mermaid` (v11.12.0)                                                            |
| Sidebar/Outline            | Встроенный Outline panel                                                                               |
| View/Edit toggle           | `Cmd+Shift+V` — открывает preview в том же табе                                                        |
| Initial load               | Быстрый                                                                                                |
| MDX                        | Не поддерживается                                                                                      |
| Выделение текста в preview | Работает, но preview — это webview, `Cmd+L` и `insertAtMention` **не работают** с выделением в webview |
| Безопасность               | Высокая (sandboxed)                                                                                    |

**Вердикт:** Быстрый и надёжный, но нет интеграции выделения с AI tools.

### 2. Markdown Preview Enhanced (`shd101wyy.markdown-preview-enhanced`)

**Подход:** Всё-в-одном расширение.

| Критерий         | Оценка                                                                                                                 |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Таблицы          | Полная поддержка                                                                                                       |
| Mermaid          | Встроенная поддержка + PlantUML, KaTeX                                                                                 |
| Sidebar/TOC      | Встроенный TOC в превью (настраивается через front-matter)                                                             |
| View/Edit toggle | `Cmd+Shift+V`                                                                                                          |
| Initial load     | Медленный                                                                                                              |
| MDX              | Не поддерживается                                                                                                      |
| Выделение текста | Webview — те же ограничения                                                                                            |
| Безопасность     | **CVE-2025-65716** (CVSS 8.8) — RCE через crafted .md файл. Уязвимость в v0.8.18, патч выпущен, но серьёзность высокая |

**Вердикт:** Самый функциональный, но медленный loading + проблемы безопасности.

### 3. Mark Sharp (`jonathan-yeung.mark-sharp`)

**Подход:** WYSIWYG markdown editor с переключением режимов.

| Критерий         | Оценка                                                                                                             |
| ---------------- | ------------------------------------------------------------------------------------------------------------------ |
| Таблицы          | Поддержка + визуальное редактирование                                                                              |
| Mermaid          | Поддержка (side-by-side editing диаграмм)                                                                          |
| Sidebar/TOC      | Нет данных                                                                                                         |
| View/Edit toggle | Команда "Mark Sharp: Switch Editor Mode" — переключает между WYSIWYG и source editor с сохранением позиции курсора |
| Initial load     | Нет данных (нужно тестировать)                                                                                     |
| MDX              | Нет                                                                                                                |
| Выделение текста | Custom editor — `Cmd+L` скорее всего **не работает**                                                               |
| Модель           | **Freemium** — Mermaid, slash commands и расширенные фичи требуют платной лицензии                                 |

**Вердикт:** Ближе всего к WYSIWYG идеалу, но платный и неизвестна совместимость с Cursor AI features.

### 4. Markdown Beautiful Editor (`chrp.markdown-beautiful-editor`)

**Подход:** WYSIWYG-style с визуальным оформлением синтаксиса.

| Критерий      | Оценка         |
| ------------- | -------------- |
| Таблицы       | Поддержка      |
| Mermaid       | Нет данных     |
| Sidebar/TOC   | Встроенный TOC |
| GitHub Alerts | Поддержка      |

**Вердикт:** Мало информации, нужно тестировать.

### 5. Markdown Inline Editor (`CodeSmith.markdown-inline-editor-vscode`)

**Подход:** Inline rendering через editor decorations (НЕ webview). Typora-like опыт прямо в редакторе.

| Критерий                          | Оценка                                                                                                 |
| -----------------------------------| --------------------------------------------------------------------------------------------------------|
| Таблицы                           | **Нет** (в roadmap, high priority)                                                                     |
| Mermaid                           | Inline SVG рендеринг с hover preview                                                                   |
| Sidebar/Outline                   | Встроенный VS Code Outline (работает, т.к. это обычный editor)                                         |
| View/Edit toggle                  | 3-state: Rendered → Ghost → Raw. Синтаксис скрывается автоматически, появляется при подведении курсора |
| Initial load                      | **Мгновенный** — editor decorations, без webview                                                       |
| Перерендер при переключении табов | **Нет проблемы** — это обычный text editor, состояние сохраняется                                      |
| MDX                               | Поддерживает `mdx` language ID                                                                         |
| Выделение текста                  | Нативное — `Cmd+L` и `insertAtMention` **должны работать**                                             |
| Модель                            | **Free, MIT License, open source**                                                                     |

**Поддерживаемые элементы:** bold, italic, strikethrough, inline code, headings H1-H6, links, autolinks, images, blockquotes, horizontal rules, unordered lists, task lists (clickable), code blocks, YAML frontmatter, emoji shortcodes, Mermaid.

**Не поддерживается (пока):** таблицы, LaTeX/Math, ordered list auto-numbering, footnotes, HTML tags.

**Ограничения:** H1 может обрезаться на первой строке файла. Файлы >1MB могут парситься медленно.

**Вердикт:** Самый перспективный вариант. Решает ключевые проблемы: мгновенный рендеринг (нет webview), нет перерендера при переключении табов, нативная работа `Cmd+L`/`insertAtMention`. Главный минус — нет таблиц (пока).

### 6. Markdown Toggle Preview (`DarrenJMcLeod.markdown-toggle-preview`)

**Подход:** Утилита для переключения source/preview одной кнопкой.

**Вердикт:** Не самостоятельное решение, а дополнение к встроенному preview. Добавляет кнопку toggle.

---

## Ключевая проблема: webview vs editor decorations

Существуют два принципиально разных подхода к рендерингу markdown:

### Webview-based (варианты 1-4)

Используют VS Code Webview API — изолированный iframe:

- Initial load 1-2 секунды (создание webview + рендеринг)
- Перерендер с нуля при переключении табов (webview уничтожается, если нет `retainContextWhenHidden`)
- Выделенный текст **невидим** для Cursor/Claude Code
- `Cmd+L` и `insertAtMention` не работают

### Editor decorations (вариант 5 — Markdown Inline Editor)

Рендеринг прямо в нативном text editor через decorations API:

- **Мгновенный** — нет создания webview
- Состояние сохраняется при переключении табов
- Нативное выделение текста — `Cmd+L` и `insertAtMention` **работают**
- Все стандартные VS Code фичи доступны (Outline, Go to Symbol, etc.)
- Ограничение: сложные элементы (таблицы) труднее рендерить через decorations

---

## Рекомендованное решение

### Основное: Markdown Inline Editor + дополнения

1. **`CodeSmith.markdown-inline-editor-vscode`** — inline рендеринг без webview, Mermaid, MDX support
2. **`yzhang.markdown-all-in-one`** — шорткаты редактирования, авто-TOC
3. **Встроенный Outline** — навигация по хедингам

**Плюсы:** мгновенный рендеринг, нет перерендера при переключении табов, `Cmd+L`/`insertAtMention` работают нативно.

**Минусы:** нет рендеринга таблиц (пока в roadmap).

### Fallback для таблиц

Для файлов с важными таблицами — `Cmd+Shift+V` для встроенного preview + `bierner.markdown-mermaid`.

---

## TODO

- [ ] Установить и протестировать `CodeSmith.markdown-inline-editor-vscode`
- [ ] Проверить работу `Cmd+L` и `insertAtMention` с выделением в inline editor
- [ ] Оценить качество рендеринга Mermaid диаграмм inline
- [ ] Следить за добавлением таблиц в Markdown Inline Editor (high priority в roadmap)
- [ ] Следить за нативным VS Code WYSIWYG markdown editor (issue #296639)
- [ ] Протестировать Mark Sharp — скорость загрузки и совместимость с Cursor (low priority, freemium)

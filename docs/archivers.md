# Archivers & compression

Единый подход к работе с архивами в дотфайлах: один инструмент в шелле, один
в yazi, минимум системных зависимостей, никаких дублирующих друг друга
утилит.

## TL;DR

| Роль | Инструмент | Где настроен |
|---|---|---|
| Основной CLI (сжатие/распаковка/просмотр) | **ouch** | `brew "ouch"`, fish-алиасы `ma/ad/al` |
| Распаковка и сжатие в yazi | **ouch** через плагин и opener | `modules/yazi/config/yazi.toml`, `keymap.toml` |
| Превью архивов в yazi | **ouch.yazi** plugin | `modules/yazi/config/package.toml` |
| Fallback для экзотики (ISO/dmg/cab/...) | **7zz** (`sevenzip` brew) | Устанавливается, но вручную вызывается только при необходимости |
| Создание rar | **rar** cask (проприетарный) | Опционально, ставится если реально нужно создавать rar |

Всё. Больше ничего не требуется.

## Почему именно так

### Выбор 2026

- **p7zip устарел.** Последний релиз — 16.02 (2016). С версии 21.01 (2021)
  Игорь Павлов поддерживает нативный POSIX-порт 7-Zip сам, бинарь называется
  `7zz`. В Homebrew — формула `sevenzip`, в nixpkgs — атрибут `_7zz`. В
  дотфайлах раньше жил `p7zip`; он выпилен.
- **ouch** — Rust-утилита, покрывающая ~95% повседневных задач с архивами и
  дающая единый UX поверх всех форматов.
- **7zz** остаётся в системе исключительно как ручной fallback для редких
  контейнеров, которые ouch не поддерживает (см. ниже).

### Почему не PeaZip, XCompress, atool, dtrx и т.д.

- **PeaZip** — GUI-first, 200+ форматов, но CLI-режим ограничен и это
  обёртка над теми же бэкендами. Лишний софт.
- **XCompress** — нишевый Rust-инструмент, меньше форматов, меньше
  активность, UX хуже ouch.
- **atool/dtrx** — Perl/Python легаси, полностью покрываются ouch.

## Как работает ouch

**ouch — это не обёртка над внешними бинарниками.** Это самодостаточная
Rust-программа, которая линкует Rust-крейты компрессии напрямую в бинарь.
Отсюда фича "no runtime dependencies": статический бинарь работает на голой
системе без `tar`, `gzip`, `7z` в PATH.

### Архитектура

```
src/
├── commands/       compress / decompress / list — высокоуровневая логика CLI
├── archive/        обёртки над контейнерными форматами (tar, zip, 7z, rar)
└── ...
```

Логика при распаковке/упаковке:

1. **Парсинг расширений справа налево.** `file.tar.gz.zst` → цепочка
   `[zst, gz, tar]`. ouch поддерживает произвольные комбинации, не только
   "известные пары".
2. **Построение pipeline'а из Rust-ридеров/райтеров.** Для декомпресса —
   `File → ZstdDecoder → GzDecoder → TarReader`. Каждый слой это
   `impl Read`/`impl Write` из соответствующего крейта, всё стримится lazy,
   без временных файлов.
3. **Контейнерные форматы** (tar, zip, 7z, rar) — отдельная ветка, потому
   что это не просто поток байт, а файловая структура с метаданными. Под
   каждый свой крейт.
4. **Автодетект формата** — не только по расширению, но и по magic bytes
   когда расширения нет или оно неверное.
5. **Умная распаковка в папку** — если в архиве один top-level каталог,
   извлекает как есть; если файлы россыпью, создаёт папку с именем архива.
   Защита от "архивных бомб" в текущей директории.

### Бэкенды ouch (Rust-крейты)

| Формат | Крейт | Примечание |
|---|---|---|
| gzip / deflate | `flate2` | Можно собрать с zlib-ng backend для скорости |
| gzip (parallel) | `gzp` | Многопоточный gzip/snappy |
| bzip2 | `bzip2` | Биндинги к libbzip2 |
| bzip3 | `bzip3` (bundled) | Встроен целиком, без system libs |
| xz / lzma | `xz2` + `lzma-rust2` | liblzma + pure Rust |
| zstd | `zstd` | Многопоточный, libzstd |
| lz4 | `lz4_flex` | Pure Rust |
| brotli | `brotli` | Pure Rust |
| snappy | `snap` | Pure Rust |
| tar | `tar` | Pure Rust, стриминг |
| zip | `zip` 6.x | Pure Rust, поддержка AES |
| 7z | `sevenz-rust2` | Pure Rust-порт, AES-256 |
| rar | `unrar` (optional) | Биндинги к unrar lib — **только распаковка** |

### Ограничения ouch (важно)

- **Создание rar невозможно.** Алгоритм закрытый, библиотек с компрессией
  rar не существует. Только проприетарный `rar` CLI от RARLAB.
- **Streaming vs non-streaming.** Для `gz/xz/zst/bz2/lz4/br` ouch работает
  честным потоком (файлы больше RAM — не проблема). Для `zip/7z` нужен seek
  по структуре, поэтому требуется реальный файл, не stdin. Это ограничение
  формата, не ouch.
- **xz не параллельный.** Для `xz` используется однопоточный крейт. На очень
  больших архивах `7zz` с `-mmt` может быть заметно быстрее.
- **Контейнерные/дисковые форматы** ouch не тянет: ISO, dmg, cab, wim,
  xar, arj, lzh, chm, pkg, rpm/deb (как контейнеры для распаковки), NSIS
  installers. Для этого есть fallback — `7zz`.

## Flow использования

### Шелл

Алиасы заданы в [modules/fish/aliases.nix](../modules/fish/aliases.nix):

```fish
ad path/to/file.any     # ouch decompress
ma out.tar.zst files/   # ouch compress
al path/to/file.any     # ouch list
```

`ad` детектит формат автоматически. `ma` выбирает формат по расширению
выходного файла. Работает с цепочками: `ma backup.tar.gz.zst src/`.

### Yazi

Три взаимодополняющих механизма:

1. **Превью архивов** (hover) — плагин
   [ndtoan96/ouch.yazi](https://github.com/ndtoan96/ouch.yazi), подключён
   через [modules/yazi/config/package.toml](../modules/yazi/config/package.toml).
   Плагин намеренно не делает распаковку — её делает yazi через opener.

2. **Распаковка** (`Enter`/`o` на архиве) — opener `extract` в
   [modules/yazi/config/yazi.toml](../modules/yazi/config/yazi.toml)
   зовёт обёртку [modules/yazi/scripts/extract.sh](../modules/yazi/scripts/extract.sh):

   ```toml
   extract = [
       { run = '~/.config/yazi/scripts/extract.sh "$@"', desc = "Extract with ouch (unique dir)" },
   ]
   ```

   Прямой `ouch decompress` не используется по двум причинам:

   - **Коллизии top-level каталогов.** Если архив содержит `src/` и в cwd
     уже есть `src/`, голый `ouch d` падает. Обёртка всегда распаковывает в
     каталог, названный по имени архива (`sample.tar.gz` → `sample/`), а
     при конфликте перебирает суффиксы `-1`, `-2`, …
   - **Пустые каталоги на фейле.** Ouch создаёт `--dir` _до_ попытки
     распаковки. Если она падает (например, пароль), остаётся пустая папка.
     Скрипт ловит ненулевой exit, удаляет пустую цель через `rmdir`
     (не тронет непустую) и возвращает код ошибки — yazi покажет fail в
     task manager.

   Регекс на составные расширения корректно режет `.tar.{gz,xz,zst,bz2,lz4,br,lzma,lz,Z}`.

3. **Создание архивов** — через плагин `ouch` с раскладкой `C <format>` в
   [modules/yazi/config/keymap.toml](../modules/yazi/config/keymap.toml):

   ```toml
   { on = [ "C", "z" ], run = "plugin ouch zip",      desc = "Compress → zip" }
   { on = [ "C", "7" ], run = "plugin ouch 7z",       desc = "Compress → 7z" }
   { on = [ "C", "t" ], run = "plugin ouch tar.zst",  desc = "Compress → tar.zst" }
   { on = [ "C", "g" ], run = "plugin ouch tar.gz",   desc = "Compress → tar.gz" }
   { on = [ "C", "x" ], run = "plugin ouch tar.xz",   desc = "Compress → tar.xz" }
   ```

   Формат передаётся как **позиционный аргумент** плагина — это синтаксис
   yazi 25+. Старая форма `--args=X` в yazi 26.x молча игнорируется, и
   плагин падает в дефолтный `zip`. Плагин подставляет формат как суффикс
   в prompt имени архива и вызывает `ouch compress`. Выделенные в yazi
   файлы идут на вход.

### Fallback для экзотики

Если ouch говорит что не знает формат (чаще всего — ISO/dmg/cab/wim), зови
`7zz` руками:

```fish
7zz x file.iso        # распаковать
7zz l file.iso        # посмотреть содержимое
```

Wrapper-функция с автоматическим fallback специально не делалась — это
происходит редко и скрывает, каким инструментом реально работаешь.

## Известные ограничения

Результаты тестов на наборе архивов в `~/Downloads/test-files/` (набор
генерируется вручную через ouch/7zz/rar/hdiutil; он не в репозитории, но
может быть пересобран из истории этой документации).

- **Пароли на распаковке не запрашиваются интерактивно.** Opener в yazi
  запускается без TTY, `ouch` не может прочитать пароль из stdin. Для
  зашифрованных архивов — из шелла: `ouch d -p <password> file.7z`. В
  yazi такие архивы падают с `PasswordRequired`; обёртка подчистит пустую
  папку и покажет ошибку в task manager.
- **Некоторые zip с `--password` ouch читает без пароля.** Связано с тем,
  что классический ZipCrypto (устаревшее шифрование zip) в ряде
  имплементаций не принуждает к паролю на чтение. Реальные защищённые
  архивы из 7-Zip/WinRAR ведут себя корректно — там AES-256, который ouch
  пропустить не может.
- **Multi-volume 7z (`.7z.001/002/...`)** — `sevenz-rust2`, на котором
  стоит ouch, многотомные архивы не поддерживает. Fallback: `7zz x file.7z.001`
  (7zz сам подтянет остальные тома).
- **RAR создавать ouch не умеет никогда** — алгоритм закрытый. Только
  распаковка (через встроенный `unrar` крейт). Создание — только
  проприетарный `rar` CLI из cask.
- **ISO/dmg/cab/wim/pkg/chm** — ouch не поддерживает, хотя *превью* в yazi
  может частично работать через ouch.yazi-плагин (он зовёт `ouch l`, тот
  падает и выводит ошибку, но yazi её показывает как текст превью). Fallback
  на `7zz` тот же.

## Windows

Там живёт отдельный флоу — yazi/ouch на Windows не используется.
Установлен классический **7-Zip** через scoop
([os/windows/packages/scoop.yoshintame-pc.json](../os/windows/packages/scoop.yoshintame-pc.json)).
Это тот же апстрим, что `7zz` на Unix, только исторически с другим именем.
Альтернатива — форк **NanaZip** (тот же движок, современный UI для Win11),
но замены не требуется.

## Установленные пакеты

### Homebrew ([Brewfile](../hosts/lasthaze-mbp/packages/Brewfile))

```
brew "ouch"        # основной инструмент
brew "sevenzip"    # fallback 7zz для экзотических форматов
cask "rar"         # проприетарный RAR для создания rar-архивов (опционально)
```

### Nix (yazi module, [default.nix](../modules/yazi/default.nix))

```nix
home.packages = with pkgs; [
  # ...
  _7zz   # доступен yazi-плагинам и встроенным спотрерам/превьюерам
];
```

`_7zz` в nixpkgs — это канонический атрибут для современного 7-Zip 21.01+.
Используется yazi-ядром для превью и mime-детекта (`file` fallback, архивный
previewer) — даже если сам opener переключён на ouch.

## История решения

- **До:** двойной стек `ouch` + `p7zip`; yazi использовал builtin `ya pub extract`
  (который звал `7zz`); фолбэк через легаси fish-функцию `extract` со
  switch'ом по расширению.
- **Проблемы:** `p7zip` мёртв с 2016, fish-функция дублирует `ouch`, в шелле
  и yazi использовались разные бэкенды без понятной причины.
- **После:** `ouch` везде (шелл + yazi open + yazi compress), `7zz` через
  `sevenzip`/`_7zz` как ручной fallback для редких форматов, легаси
  `extract.fish` удалён, `p7zip` выпилен из Brewfile и yazi module.

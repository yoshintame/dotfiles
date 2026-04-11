# Personal Homebrew Tap

Персональный tap [yoshintame/homebrew-cask](https://github.com/yoshintame/homebrew-cask) для приложений, у которых нет официального Homebrew cask.

## Зачем

Некоторые macOS-приложения устанавливаются только через DMG/прямую загрузку и не попадают в `brew bundle dump`. Создавая cask в персональном tap, мы получаем:

- **Декларативность** — приложение в Brewfile как любое другое
- **Обновления** — `brew upgrade` обновляет через Sparkle/livecheck
- **Автоматизацию** — CI проверяет новые версии и обновляет cask

## Как добавить новый cask

### 1. Найти download URL и update feed

Большинство macOS-приложений используют [Sparkle](https://sparkle-project.org/) для обновлений. URL фида можно найти в Info.plist установленного приложения:

```bash
defaults read /Applications/AppName.app/Contents/Info.plist SUFeedURL
```

Если приложение не использует Sparkle — подойдёт любой стабильный URL, из которого можно извлечь версию (GitHub releases, страница загрузки).

### 2. Скачать DMG и посчитать SHA256

```bash
curl -fsSL -o /tmp/app.dmg "https://example.com/download/App-1.0.dmg"
shasum -a 256 /tmp/app.dmg
```

### 3. Создать cask-файл

```bash
$EDITOR /opt/homebrew/Library/Taps/yoshintame/homebrew-cask/Casks/app-name.rb
```

Шаблон:

```ruby
cask "app-name" do
  version "1.0"
  sha256 "abc123..."

  url "https://example.com/download/App-#{version}.dmg"
  name "App Name"
  desc "Short description"
  homepage "https://example.com/"

  livecheck do
    url "https://example.com/updates/appcast.xml"
    strategy :sparkle, &:short_version
  end

  depends_on macos: ">= :sonoma"  # если есть ограничения

  app "App Name.app"
end
```

#### Стратегии livecheck

| Источник обновлений | Стратегия |
|---|---|
| Sparkle appcast (XML) | `strategy :sparkle, &:short_version` |
| GitHub releases | `url :stable` (автоматически для GitHub URL) |
| Страница загрузки | `strategy :page_match, /App-(\d+\.\d+)\.dmg/` |

### 4. Установить / adopt

```bash
# Новое приложение:
brew install --cask yoshintame/cask/app-name

# Уже установленное (adopt без переустановки):
brew install --cask --adopt yoshintame/cask/app-name
```

### 5. Запушить

```bash
git -C /opt/homebrew/Library/Taps/yoshintame/homebrew-cask add -A
git -C /opt/homebrew/Library/Taps/yoshintame/homebrew-cask commit -m "feat: add app-name cask"
git -C /opt/homebrew/Library/Taps/yoshintame/homebrew-cask push
```

После пуша `brew bundle dump` автоматически включит tap и cask в Brewfile:

```ruby
tap "yoshintame/cask"
cask "yoshintame/cask/app-name"
```

## CI: автоматическое обновление версий

GitHub Actions workflow ([`.github/workflows/livecheck.yml`](https://github.com/yoshintame/homebrew-cask/blob/main/.github/workflows/livecheck.yml)) автоматически обновляет cask-файлы при выходе новых версий.

### Как это работает

```
Разработчик выпускает обновление
  → Sparkle XML / GitHub release обновляется
  → GitHub Actions (каждый понедельник 09:00 UTC) запускает brew livecheck
  → Обнаруживает новую версию → скачивает артефакт → считает sha256
  → Коммитит обновлённый .rb файл в tap
  → brew upgrade --cask подхватывает при следующем запуске
```

### Настройка (одноразовая)

1. Создать [Personal Access Token](https://github.com/settings/tokens) с правами `public_repo` + `workflow`
2. В репозитории `yoshintame/homebrew-cask` → Settings → Secrets and variables → Actions → добавить секрет `HOMEBREW_TAP_TOKEN`

После настройки workflow работает полностью автономно для всех cask-файлов в tap.

### Ручной запуск

Workflow также можно запустить вручную через GitHub Actions UI (кнопка "Run workflow") или CLI:

```bash
gh workflow run livecheck.yml -R yoshintame/homebrew-cask
```

## Текущие cask-и

| Cask | Приложение | Livecheck |
|---|---|---|
| `cotypist` | [Cotypist](https://cotypist.app/) — AI autocomplete | Sparkle appcast |
| `hyperswitch` | [HyperSwitch](https://bahoom.com/hyperswitch) — keyboard window switcher | Sparkle appcast |
| `tana` | [Tana](https://tana.inc/) — notes, tasks, meetings | GitHub releases |

## Приложения-кандидаты

Приложения без официального cask, для которых можно создать cask в этом tap:

| Приложение  | Тип                  | Примечание                  |
| -------------| ----------------------| -----------------------------|
| MetalVoice  | unknown              |                             |
| NuPhyIO     | identified_developer | Нет публичного download URL |
| TranscribeX | identified_developer | Транскрибация               |

## См. также

- [Homebrew + nix-darwin интеграция](homebrew-nix-integration.md)
- [Homebrew Cask Cookbook](https://docs.brew.sh/Cask-Cookbook) — официальная документация по формату cask
- [Brew Livecheck](https://docs.brew.sh/Brew-Livecheck) — документация по стратегиям livecheck

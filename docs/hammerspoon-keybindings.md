# Hammerspoon Keybindings

## App Launcher (Alt-based)

| Shortcut                                       | App              |
| ------------------------------------------------| ------------------|
| `Alt + 1`                                      | 1Password        |
| `Alt + Q`                                      | Telegram         |
| `Alt + W`                                      | Warp             |
| `Alt + Shift + W`                              | Kitty            |
| `Alt + R`                                      | yazi (Warp)      |
| `Alt + B`                                      | btop (Warp)      |
| `Alt + E`                                      | Tana             |
| `Alt + Shift + E`                              | Finder           |
| `Alt + A`                                      | Arc              |
| `Alt + Shift + A`                              | ChatGPT          |
| `Alt + S`                                      | Spotify          |
| `Alt + Shift + S`                              | Spark Mail       |
| `Alt + D`                                      | Cursor           |
| `Alt + Shift + D`                              | Jira             |
| `Alt + Z`                                      | Figma            |
| `Alt + X`                                      | Insomnia         |
| `Alt + C`                                      | Discord          |
| `Alt + V` / `Alt + Esc` / `Ctrl + Shift + Esc` | Activity Monitor |
| `Alt + ,`                                      | System Settings  |

---

## Leader Flow (`F18` -> ...)

Press `F18` to enter leader mode. Then press one of the keys below.
Press `Esc` or `F18` again to cancel.

### `t` Text

| Key | Action | Type |
|---|---|---|
| `t` | Translator (EasyDict) | Raycast |
| `f` | Fix | Shortcut `Cmd+Alt+Ctrl+Shift+1` |

### `c` Case

| Key | Action | Type |
|---|---|---|
| `k` | Kebab Case | Raycast |
| `s` | Snake Case | Raycast |
| `c` | Camel Case | Raycast |
| `u` | Upper Case | Raycast |
| `l` | Lower Case | Raycast |
| `o` | Constant Case | Raycast |

### `p` Passwords

| Key | Action | Type |
|---|---|---|
| `p` | Passwords | Shortcut `Cmd+Shift+Space` |

> Direct action, no submenu.

### `u` Utils

| Key | Action | Type |
|---|---|---|
| `c` | Color Picker | Shortcut `Cmd+Alt+Ctrl+P` |
| `r` | Roulette | Shortcut `Cmd+Alt+Ctrl+O` |
| `e` | Emojis | Raycast |
| `k` | Kill Process | Raycast |

### `l` Links

| Key | Action                | Type |
| -----| -----------------------| ------|
| `g` | github.com/yoshintame | URL  |
| `y` | youtube.com           | URL  |
| `m` | google.com/maps       | URL  |
| `l` | **Localhost** submenu |      |

#### `l` -> `l` Localhost

| Key | Action | URL |
|---|---|---|
| `c` | CRM | `localhost:4003` |
| `t` | TG-Mini | `localhost:8004` |
| `4` | 404 | `localhost:4040` |

### `r` RU Snippets

| Key | Action | Text |
|---|---|---|
| `f` | Full Name | Иванов Михаил Андреевич |
| `n` | First Name | Михаил |
| `l` | Last Name | Иванов |
| `i` | Name with initials | Иванов М.А. |
| `p` | Phone | 79162999311 |

### `e` EN Snippets

| Key | Action             | Text                               |
| -----| --------------------| ------------------------------------|
| `f` | Full Name          | Mikhail Ivanov Andreevich          |
| `n` | First Name         | Mikhail                            |
| `l` | Last Name          | Ivanov                             |
| `i` | Name with initials | Ivanov M.A.                        |
| `u` | Username           | yoshintame                         |
| `p` | Phone              | 0991671150                         |
| `s` | Intr. Passport     | 770867661                          |
| `b` | Birthday           | 24.08.2001                         |
| `a` | Address            | Apt 1115, 1333 The Line Wongsawang |
| `t` | Current Date       | (dynamic)                          |
| `k` | **Keys** submenu   |                                    |
| `m` | **Emails** submenu |                                    |

#### `e` -> `k` Keys (special characters)

| Key | Action | Symbol |
|---|---|---|
| `Shift` | Shift | ⇧ |
| `Ctrl` | Control | ⌃ |
| `Alt` | Option | ⌥ |
| `Cmd` | Command | ⌘ |
| `Fn` | Fn | fn |
| `CapsLock` | CapsLock | ⇪ |
| `Left` | Left | ← |
| `Right` | Right | → |
| `Up` | Up | ↑ |
| `Down` | Down | ↓ |
| `Esc` | Escape | ⎋ |

#### `e` -> `m` Emails

| Key | Action | Email |
|---|---|---|
| `m` | Main | m.ivanov0427@gmail.com |
| `u` | Ursus | ursus.michael@gmail.com |
| `v` | Vbirf | vbirf2001@gmail.com |

### `d` Development

| Key | Action | Type |
|---|---|---|
| `g` | Git Repos | Raycast |
| `o` | **Open Project** submenu | |

#### `d` -> `o` Open Project (in Cursor)

| Key | Project | Path |
|---|---|---|
| `c` | CRM | `~/Development/work/senat-exchange/crm-frontend` |
| `d` | dotfiles | `~/.dotfiles` |
| `k` | karabiner | `~/.dotfiles/modules/karabiner/config` |
| `h` | hammerspoon | `~/.dotfiles/modules/hammerspoon/config` |
| `f` | fish | `~/.dotfiles/modules/fish/config` |
| `v` | vscode | `~/.dotfiles/modules/vscode/config` |

### `s` Screenshots

| Key | Action | Shortcut |
|---|---|---|
| `s` | Area | `Cmd+Shift+2` |
| `w` | Window | `Cmd+Shift+3` |
| `f` | Fullscreen | `Cmd+Shift+1` |
| `r` | Text (OCR) | `Cmd+Shift+4` |
| `v` | Video | `Cmd+Shift+5` |
| `l` | Scroll | `Cmd+Shift+6` |

### `a` AI

| Key | Action | Type |
|---|---|---|
| `a` | Overlay | Shortcut `Alt+Space` |
| `g` | ChatGPT | Launch app |

### `h` Hammerspoon

| Key | Action | Type |
|---|---|---|
| `r` | Reload config | Reload |

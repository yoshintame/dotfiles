# Global CLI wrappers via mise tasks

Pattern for creating global CLI commands backed by mise task runner with fish shell integration.

## Background: justfile -> mise

Initially this pattern used justfiles: each utility was a justfile with recipes, a fish function wrapper (`just -f <path> $argv`), and a separate completions file. This worked but had limitations:

|                      | justfile                             | mise tasks                            |
| -------------------- | ------------------------------------ | ------------------------------------- |
| Flags (`--no-clean`) | not supported                        | native via `usage` field              |
| Choices / validation | manual `case` + error msg            | declarative `choices`                 |
| Autocompletion       | manual fish completions file         | simpler completions via `mise tasks`  |
| Global tasks         | `just -f <path>` hack                | `~/.config/mise/tasks/` native        |
| Files per utility    | 3 (justfile + function + completion) | 3 (toml + function + completion)      |
| Argument parsing     | positional only                      | positional, flags, defaults, env vars |

mise was already installed as a tool version manager, so no extra dependency.

## Structure

Each utility = 3 files:

```text
modules/<module>/config/<name>.toml         # mise tasks (linked to ~/.config/mise/tasks/<name>.toml)
modules/fish/config/functions/<name>.fish   # thin fish wrapper
modules/fish/config/completions/<name>.fish # tab-completion
```

Global mise config includes task files:

```toml
# ~/.config/mise/config.toml
[task_config]
includes = ["tasks/rp.toml", "tasks/other.toml"]
```

Each module's `default.nix` links its own toml:

```nix
nixDotbot.links = {
  "~/.config/mise/tasks/<name>.toml" = "modules/<module>/config/<name>.toml";
};
```

## How to add a new utility

### 1. Create the tasks file

`modules/<module>/config/<name>.toml`:

Note: included task files use `["<name>:command"]` format (without `tasks.` prefix).

```toml
["<name>:command"]
description = "Do something"
usage = '''
arg "<target>" help="Target" default="foo" {
  choices "foo" "bar" "baz"
}
flag "--verbose" help="Enable verbose output"
'''
run = '''
echo "Running on ${usage_target?}"
if [ "${usage_verbose:-false}" = "true" ]; then
    set -x
fi
# ... actual logic
'''
```

### 2. Create the fish function

`modules/fish/config/functions/<name>.fish`:

```fish
function <name> --description "<description>"
    if test (count $argv) -eq 0; or contains -- $argv[1] --help -h
        mise tasks ls 2>/dev/null | grep '^<name>:'
        return
    end
    mise run <name>:$argv[1] -- $argv[2..]
end
```

### 3. Create fish completions

`modules/fish/config/completions/<name>.fish`:

```fish
complete -c <name> -f
complete -c <name> -n "test (count (commandline -opc)) -eq 1" \
    -a "(mise tasks ls 2>/dev/null | grep '^<name>:' | sed 's/^<name>://' | awk '{print \$1\"\t\"\$2\" \"\$3\" \"\$4\" \"\$5}')"
```

### 4. Link in default.nix and include in mise config

`modules/<module>/default.nix` — add link:

```nix
"~/.config/mise/tasks/<name>.toml" = "modules/<module>/config/<name>.toml";
```

`modules/mise/config/config.toml` — add to includes:

```toml
[task_config]
includes = ["tasks/<name>.toml"]
```

### 5. Done

Rebuild dotfiles and reload fish (`exec fish`). `<name> <Tab>` will show available commands.

## Gotchas

- **Included task file format**: use `["name:cmd"]` not `[tasks."name:cmd"]`
- **Include paths**: relative to `config.toml` location (e.g. `tasks/rp.toml` resolves to `~/.config/mise/tasks/rp.toml`)
- **TOML strings with quotes**: use `'''` multi-line literals to avoid escaping issues

## Example: `rp` (resticprofile)

```fish
# functions/rp.fish
function rp --description "resticprofile backup tasks (mise wrapper)"
    if test (count $argv) -eq 0; or contains -- $argv[1] --help -h
        mise tasks ls 2>/dev/null | grep '^rp:'
        return
    end
    mise run rp:$argv[1] -- $argv[2..]
end
```

```fish
# completions/rp.fish
complete -c rp -f
complete -c rp -n "test (count (commandline -opc)) -eq 1" \
    -a "(mise tasks ls 2>/dev/null | grep '^rp:' | sed 's/^rp://' | awk '{print \$1\"\t\"\$2\" \"\$3\" \"\$4\" \"\$5}')"
```

```toml
# rp.toml (excerpt)
["rp:backup"]
description = "Run backup"
usage = '''
arg "<profile>" help="Backup profile" default="all" {
  choices "all" "dev" "home"
}
'''
run = 'resticprofile -n ${usage_profile?} backup'

["rp:save"]
description = "Quick-save current dir (full, no exclusions)"
run = 'RP_SAVE_DIR="$(pwd)" resticprofile -n quicksave backup'

["rp:load"]
description = "Load current dir from latest snapshot"
usage = '''
flag "--no-clean" help="Don't delete existing files before restore"
'''
run = '''
dir="$(pwd)"
if [ "${usage_no_clean:-false}" = "false" ]; then
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi
resticprofile -n quicksave restore "latest:$dir" --target "$dir"
'''
```

Usage:

```fish
rp                    # list available commands
rp backup             # backup all (default)
rp backup dev         # backup dev only
rp save               # full backup of current dir
rp load               # restore current dir from latest snapshot
rp load --no-clean    # restore without deleting new files
rp snapshots local    # list local snapshots
```

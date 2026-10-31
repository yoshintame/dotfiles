# sort-by-added.yazi

A [Yazi](https://github.com/sxyazi/yazi) plugin that reorders the files in the
current directory by their **macOS "Date Added"** timestamp
(`kMDItemDateAdded`), newest first.

This is handy for a `~/Downloads` folder: the most recently downloaded files
float to the top, regardless of how they are named or when they were last
modified.

> **Platform:** macOS only. It relies on Spotlight metadata via the `mdls`
> command, which does not exist on Linux/Windows.

## What it does

The plugin is a one-shot action (not a persistent sort mode). When invoked it:

1. Reads the current working directory from `cx.active.current.cwd`.
2. Asks Spotlight for the file name and "Date Added" of every entry in that
   directory.
3. Sorts those entries by date, newest first.
4. Reorders the file list in the Yazi pane to match, appending any files that
   Spotlight didn't return (e.g. items with no `kMDItemDateAdded`) in their
   original order at the bottom.
5. Redraws the pane.

Because it uses `fs.op("reorder", …)` it only changes the *display order* of the
current view — it never moves, renames, or touches the files on disk.

## How it works internally

The plugin is declared `--- @sync entry`, so the `entry` function runs
synchronously on Yazi's main thread. That is required because it reads `cx`
(the app state) and emits UI mutations (`update_files`, `redraw`).

The core is a small shell pipeline built from the current directory:

```sh
mdls -n kMDItemFSName -n kMDItemDateAdded -raw "<cwd>"/* \
  | xargs -0 -n2 \
  | sort -rk2 \
  | awk '{print $1}'
```

Step by step:

| Stage | Purpose |
| --- | --- |
| `mdls -n kMDItemFSName -n kMDItemDateAdded -raw …/*` | For each file, print its name and its Spotlight "Date Added" as raw, NUL-separated values. |
| `xargs -0 -n2` | Regroup the NUL-separated stream into `name date` pairs, one per line. |
| `sort -rk2` | Sort the pairs by the **2nd** field (the date) in reverse (newest first). |
| `awk '{print $1}'` | Keep only the file name from each pair. |

The resulting newline-separated list of names is then matched back against
`folder.files` (keyed by full URL) to build the new ordering that is handed to
`fs.op("reorder", { files = new_order })`.

## Installation

This plugin lives inside the dotfiles repo and is symlinked into Yazi's config
directory along with the rest of `modules/yazi`. Yazi loads any plugin found in
`~/.config/yazi/plugins/<name>.yazi/`, so no extra registration is needed beyond
having the directory present.

## Usage

It has **no key binding by default** — add one to your `keymap.toml`, for
example:

```toml
[[mgr.prepend_keymap]]
on  = [ "s", "a" ]
run = "plugin sort-by-added"
desc = "Sort by macOS Date Added (newest first)"
```

Then press the bound key while inside the folder you want to reorder.

## Related: the `downloads-sorter` fish function

`modules/fish/config/functions/downloads-sorter.fish` solves the same "newest
download on top" problem from a different angle. Instead of reordering a view,
it rewrites each file's **modification time** (`mtime`) to match its Spotlight
"Date Added":

```fish
mdls -raw -name kMDItemDateAdded $f   # read Date Added
touch -t <that time> $f               # stamp it onto mtime
```

After running it, an ordinary "sort by modified time" (in Yazi, Finder, `ls -t`,
etc.) reflects download order everywhere — a more permanent, tool-agnostic fix,
at the cost of overwriting the real mtime.

## Known issue

The Lua currently spawns the pipeline as:

```lua
Command("mdls"):cwd(cwd):arg({ "-c", shell_cmd }):output()
```

This invokes `mdls -c '<pipeline>'`, but `mdls` has no `-c` (run-shell) option —
that flag belongs to a shell. As written the command fails and the plugin
reports `mdls failed`. To actually execute the pipeline the spawned program
should be a shell, e.g.:

```lua
Command("sh"):cwd(cwd):arg({ "-c", shell_cmd }):output()
```

(or `zsh`). The documented behavior above describes the *intended* design.

# Global Rules

## *Bash*

- *NEVER use `cd` in Bash commands. Always use absolute paths or tool-specific flags such as `git -C /path`.*
- *NEVER chain commands with `cd /path &&` or `cd /path;`.*
- *The Bash tool runs a POSIX shell (zsh), not fish. Use POSIX syntax for every command you execute via the tool, e.g. `export NAME=value`.*
- *The user's own interactive terminal is fish. ONLY when writing a command for the user to copy and run there, use fish syntax, e.g. `set -x NAME value` instead of `export NAME=value`. Default everywhere else is POSIX.*

## Code

- *NEVER add comments to code unless explicitly asked. No docstrings, no inline comments, no JSDoc, no TODO comments unless the user requests them.*
- *NEVER touch existing comments written by others peoples: do not delete, rewrite, translate, or "improve" them, even when refactoring the code around them. Move a comment only when the code it belongs to moves.*

## File references

- *When linking to a file in a response, always use markdown link syntax with the file's **absolute path** as the target, without the `file://` scheme: `[name](/Users/.../file.ts)`. VSCode Claude Code extension renders bare absolute paths as clickable links; `file://` URIs and relative paths to files outside the open workspace do not open.*

## Agent memory

- *NEVER create or write files under `~/.claude/projects/*/memory/` (Claude Code auto-memory storage). Auto-memory is disabled (`autoMemoryEnabled: false`) and the store stays closed until the rules from the vault idea `agent-memory-meta-only-policy` are implemented (what qualifies, source tracing, expiry). When asked to remember something durable, put it in its typed home instead: an agent behavior rule → this file or the relevant skill; knowledge → a typed note in the Obsidian vault.*

## Agent configs & skills

All agent configs (this file, `~/.claude/settings.json`, hooks, skills) are nix-dotbot symlinks from `~/.dotfiles`. Edit the **original in the repo**, never the `~/.claude/` copy. For the full path map and linking mechanics — what is live immediately vs. needs `mise run dot:rebuild` — see `~/.dotfiles/CLAUDE.md`.

## Pasted images

Images pasted into a chat message are never exposed to the agent as files — they persist as base64 image blocks in the session transcript. Recover the bytes (byte-for-byte identical to the original, no re-encoding) with `extract-images` (on `PATH`; run `extract-images --help`): it discovers the current session's transcript and decodes images from the most recent image-bearing user message to files on disk. Reach for it whenever you need a pasted screenshot as a real file — bug-report assets, saving an attachment, diffing an image.

## Package managers

- Prefer `bun` over `npm` and `yarn` for JavaScript and TypeScript projects. Use `bun install`, `bun run X`, `bun test`, `bunx X`.
- Prefer `uv` over `pip` and `pip3` for Python. Use `uv pip install X`, or `uv pip install --python /path/to/venv/bin/python X` for venv installs.
- Shared Bash policy hooks may block raw `npm`, `yarn`, or `pip` commands unless the escape hatch is used: `FORCE_NPM=1`, `FORCE_YARN=1`, `FORCE_PIP=1`.

  .

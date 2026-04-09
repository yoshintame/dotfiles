# Global Rules

## Bash

- NEVER use `cd` in Bash commands. Always use absolute paths or tool-specific flags (e.g. `git -C /path`).
- NEVER chain commands with `cd /path &&` or `cd /path;` — this breaks permission matching and is a security bypass.

## Code

- NEVER add comments to code unless explicitly asked. No docstrings, no inline comments, no JSDoc, no TODO comments — nothing unless the user requests it.

## Package managers

- Prefer `bun` over `npm`/`yarn` for JavaScript/TypeScript projects. Use `bun install`, `bun run X`, `bun test`, `bunx X`.
- Prefer `uv` over `pip`/`pip3` for Python. Use `uv pip install X`, or `uv pip install --python /path/to/venv/bin/python X` for venv installs.
- A PreToolUse hook will block raw `npm`/`yarn`/`pip` commands with this reminder. If the project genuinely requires the original tool (lock files, peer deps, npm-specific scripts), use the env var escape hatch: `FORCE_NPM=1 npm install ...`, `FORCE_YARN=1 yarn add ...`, `FORCE_PIP=1 pip install ...`. The env var is harmless to the underlying tool.
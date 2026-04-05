# Global Rules

## Bash

- NEVER use `cd` in Bash commands. Always use absolute paths or tool-specific flags (e.g. `git -C /path`).
- NEVER chain commands with `cd /path &&` or `cd /path;` — this breaks permission matching and is a security bypass.

## Code

- NEVER add comments to code unless explicitly asked. No docstrings, no inline comments, no JSDoc, no TODO comments — nothing unless the user requests it.
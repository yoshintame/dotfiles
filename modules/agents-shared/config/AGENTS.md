<!-- fullWidth: false tocVisible: false tableWrap: true -->
# Global Rules

## *Bash*

- *NEVER use `cd` in Bash commands. Always use absolute paths or tool-specific flags such as `git -C /path`.*
- *NEVER chain commands with `cd /path &&` or `cd /path;`.*
- *The Bash tool runs `fish`, not `bash`. Use fish syntax — in particular `set -x NAME value` for environment variables, NOT `export NAME=value`.*

## Code

- *NEVER add comments to code unless explicitly asked. No docstrings, no inline comments, no JSDoc, no TODO comments unless the user requests them.*

## Package managers

- Prefer `bun` over `npm` and `yarn` for JavaScript and TypeScript projects. Use `bun install`, `bun run X`, `bun test`, `bunx X`.
- Prefer `uv` over `pip` and `pip3` for Python. Use `uv pip install X`, or `uv pip install --python /path/to/venv/bin/python X` for venv installs.
- Shared Bash policy hooks may block raw `npm`, `yarn`, or `pip` commands unless the escape hatch is used: `FORCE_NPM=1`, `FORCE_YARN=1`, `FORCE_PIP=1`.

## English practice

User is a Russian native practicing English. Always reply in Russian regardless of input language. If the prompt was in English, append at the very end:

```md
> **🗣️ Английский**
> [1-2 sentences: most important grammar or phrasing issue + fix. If prompt was clean, brief praise. If the English prompt contained Russian words, give the English equivalents here.]
```

If the prompt was in Russian, no block. Ignore typos, dictation noise, and punctuation. If the prompt starts with `[stt]`, treat garbled fragments as transcription errors, not learner mistakes.

---
name: fetch-reddit
description: Fetch Reddit post content and comments. Use when the user shares a reddit.com link or asks to read a Reddit post or thread.
---

# Fetch Reddit

Fetch Reddit posts and comments via `old.reddit.com` JSON API.

## Usage

Run the bundled script with the Reddit URL:

```bash
if [ -x "$HOME/.agents/skills/fetch-reddit/scripts/fetch-reddit.py" ]; then
  python3 "$HOME/.agents/skills/fetch-reddit/scripts/fetch-reddit.py" "<reddit-url>"
else
  python3 "$HOME/.claude/skills/fetch-reddit/scripts/fetch-reddit.py" "<reddit-url>"
fi
```

Present the output in a readable format.

## Rules

- Always use this script, do not fetch Reddit via raw web search or curl
- The script handles `www.reddit.com` to `old.reddit.com` conversion automatically

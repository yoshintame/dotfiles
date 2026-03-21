---
name: fetch-reddit
description: Fetch Reddit post content and comments. Use when the user shares a reddit.com link or asks to read a Reddit post/thread.
allowed-tools: Bash(python3:*)
---

# Fetch Reddit

Fetch Reddit posts and comments via `old.reddit.com` JSON API.

## Usage

Run the bundled script with the Reddit URL:

```bash
python3 skills/fetch-reddit/scripts/fetch-reddit.py "<reddit-url>"
```

Present the output to the user in a readable format.

## Rules

- Always use this script — do not fetch Reddit URLs via `WebFetch` or `curl` directly
- The script handles `www.reddit.com` → `old.reddit.com` conversion automatically

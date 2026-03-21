#!/usr/bin/env python3
"""Fetch Reddit post and comments via old.reddit.com JSON API."""

import json
import subprocess
import sys
from urllib.parse import urlparse, urlunparse


def fetch(url: str) -> dict:
    """Fetch JSON from old.reddit.com."""
    parsed = urlparse(url)

    # Convert to old.reddit.com
    host = parsed.hostname or ""
    host = host.replace("www.reddit.com", "old.reddit.com")
    if host == "reddit.com":
        host = "old.reddit.com"

    # Strip query params and fragment, ensure .json suffix on path
    path = parsed.path.rstrip("/")
    if not path.endswith(".json"):
        path += ".json"

    api_url = urlunparse((parsed.scheme or "https", host, path, "", "", ""))

    result = subprocess.run(
        ["curl", "-s", "-L", "-H", "User-Agent: Claude-Code-Reader/1.0", api_url],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"curl failed (exit {result.returncode}): {result.stderr}", file=sys.stderr)
        sys.exit(1)

    if not result.stdout.strip():
        print("Empty response from Reddit API", file=sys.stderr)
        sys.exit(1)

    return json.loads(result.stdout)


def format_comments(children, depth=0):
    """Recursively format comment tree."""
    indent = "  " * depth
    for c in children:
        if c["kind"] != "t1":
            continue
        d = c["data"]
        print(f"{indent}u/{d.get('author', '?')} ({d.get('score', 0)}):")
        for line in d.get("body", "").splitlines():
            print(f"{indent}  {line}")
        print()
        replies = d.get("replies")
        if isinstance(replies, dict):
            format_comments(replies["data"]["children"], depth + 1)


def main():
    if len(sys.argv) < 2:
        print("Usage: fetch-reddit.py <reddit-url>", file=sys.stderr)
        sys.exit(1)

    data = fetch(sys.argv[1])

    post = data[0]["data"]["children"][0]["data"]
    print(f"## {post['title']}")
    print(f"u/{post['author']} | score: {post['score']} | upvote: {post.get('upvote_ratio', 0):.0%}")
    print()
    selftext = post.get("selftext", "")
    if selftext:
        print(selftext)
        print()
    print("---")
    print()

    format_comments(data[1]["data"]["children"])


if __name__ == "__main__":
    main()

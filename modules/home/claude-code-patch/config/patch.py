#!/usr/bin/env python3
"""
Re-applies sidebar-handoff patches to the latest Claude Code VS Code extension
after each update. Idempotent: detects already-patched extensions by content.

Patches enable `vscode://anthropic.claude-code/open-sidebar?session=X` URI which
loads the chosen session into the Claude Code sidebar webview (not editor tab).

Spec for each patch is a (anchor, replacement) pair against the minified
extension.js. If an anchor disappears (Anthropic re-minifies with different
variable names), the script logs an error per extension and exits non-zero.
"""
import os
import shutil
import sys
from pathlib import Path

EXT_GLOB_PARENT = Path.home() / ".vscode" / "extensions"
EXT_PREFIX = "anthropic.claude-code-"

PATCHES = [
    {
        "name": "track-sidebar-view",
        "anchor": "resolveWebviewView(z,K,V){let x={isVisible:()=>z.visible}",
        "replacement": "resolveWebviewView(z,K,V){this.sidebarView=z;let x={isVisible:()=>z.visible}",
    },
    {
        "name": "uri-open-sidebar",
        "anchor": (
            'case"/open":{let v=R.get("session")??void 0,'
            'I=R.get("prompt")??void 0;'
            'R0.commands.executeCommand("claude-vscode.primaryEditor.open",v,I);return}'
        ),
        "replacement": (
            'case"/open":{let v=R.get("session")??void 0,'
            'I=R.get("prompt")??void 0;'
            'R0.commands.executeCommand("claude-vscode.primaryEditor.open",v,I);return}'
            'case"/open-sidebar":{let v=R.get("session")??void 0,'
            'I=R.get("prompt")??void 0;'
            'R0.commands.executeCommand("claude-vscode.sidebar.open");'
            "if(D.sidebarView)"
            "D.sidebarView.webview.html=D.getHtmlForWebview(D.sidebarView.webview,v,I,!0);"
            "return}"
        ),
    },
]


def is_patched(text: str) -> bool:
    return all(p["replacement"][:80] in text for p in PATCHES)


def has_all_anchors(text: str) -> bool:
    return all(p["anchor"] in text for p in PATCHES)


def patch_one(ext_dir: Path) -> str:
    extjs = ext_dir / "extension.js"
    if not extjs.is_file():
        return "no-extension-js"

    text = extjs.read_text()
    if is_patched(text):
        return "already-patched"

    if not has_all_anchors(text):
        missing = [p["name"] for p in PATCHES if p["anchor"] not in text]
        return f"anchor-missing:{','.join(missing)}"

    bak = extjs.with_suffix(".js.bak")
    if not bak.exists():
        shutil.copy2(extjs, bak)

    for p in PATCHES:
        text = text.replace(p["anchor"], p["replacement"], 1)

    extjs.write_text(text)
    return "patched"


def main() -> int:
    if not EXT_GLOB_PARENT.is_dir():
        print(f"no extensions dir at {EXT_GLOB_PARENT}", file=sys.stderr)
        return 1

    ext_dirs = sorted(d for d in EXT_GLOB_PARENT.glob(f"{EXT_PREFIX}*") if d.is_dir())
    if not ext_dirs:
        print(f"no {EXT_PREFIX}* in {EXT_GLOB_PARENT}", file=sys.stderr)
        return 1

    fail = False
    for d in ext_dirs:
        result = patch_one(d)
        print(f"{d.name}: {result}")
        if result.startswith("anchor-missing"):
            fail = True
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())

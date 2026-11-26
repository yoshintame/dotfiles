{
  config,
  myLib,
  ...
}:
let
  harness = path: {
    root = "agent-harness";
    inherit path;
  };
  glob = path: harness path // { glob = true; };
in
myLib.mkModule config "agent-harness" {
  nixLink.links = {
    "~/.codex/AGENTS.md" = harness "codex/instructions/AGENTS.md";
    "~/Development/CLAUDE.md" = harness "claude/instructions/dev-profile.md";
    "~/.local/share/worktrees/CLAUDE.md" = harness "claude/instructions/dev-profile.md";
    "~/.paseo/worktrees/CLAUDE.md" = harness "claude/instructions/dev-profile.md";

    "~/.claude/settings.json" = harness "claude/settings.json";
    "~/.claude/agents" = harness "claude/agents";
    "~/.claude/hooks/" = glob "claude/hooks/**";
    "~/.claude/hooks" = glob "shared/hooks/**";

    "~/.codex/config.toml" = harness "codex/config.toml";
    "~/.codex/rules/chrome-devtools.rules" = harness "codex/rules/chrome-devtools.rules";
    "~/.codex/rules/paseo.rules" = harness "codex/rules/paseo.rules";

    "~/.apm/apm.yml" = harness "shared/apm/apm.yml";
    "~/.apm/apm.lock.yaml" = harness "shared/apm/apm.lock.yaml";

    "~/.local/bin/chrome-cdp" = harness "shared/tools/chrome-cdp/cli.ts";
    "~/.local/bin/chrome-devtools" = harness "shared/tools/chrome-devtools";
    "~/.config/cd4a/config.json" = harness "shared/tools/chrome-cdp/cd4a.json";
    "~/.local/bin/extract-images" = harness "claude/tools/extract-images";
    "~/.local/bin/cc-trace-compact" = harness "claude/tools/cc-trace/cc-trace-compact.ts";
    "~/.local/bin/cc-trace-break" = harness "claude/tools/cc-trace/cc-trace-break.ts";
    "~/.local/bin/claude-code-patch" = harness "claude/tools/claude-code-patch";
    "~/.local/bin/git-commit-atomic" = harness ".apm/skills/git-commit/scripts/git-commit-atomic";
    "~/.local/bin/git-commit-context" = harness ".apm/skills/git-commit/scripts/git-commit-context";
    "~/.local/bin/cc-fork" = harness ".apm/skills/cc-fork/scripts/cc-fork";
    "~/.local/bin/cc-fork-recover" = harness ".apm/skills/cc-fork-recover/scripts/cc-fork-recover";
  };

  home.file.".codex/config.toml".force = true;
}

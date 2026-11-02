{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "codex" {
  nixLink.links = {
    "~/.codex/AGENTS.md" = "modules/home/agents-shared/config/AGENTS.md";
    "~/.codex/config.toml" = "modules/home/codex/config/config.toml";
    "~/.codex/rules/chrome-devtools.rules" = "modules/home/codex/config/rules/chrome-devtools.rules";
  };

  home.file.".codex/config.toml".force = true;

  programs.zsh.envExtra = lib.mkBefore ''
    if [[ -n $AGENT_ZSH_COMPAT ]]; then
      setopt no_nomatch no_equals sh_word_split
    fi
  '';
}

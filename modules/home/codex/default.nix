{
  config,
  lib,
  myLib,
  ...
}:
myLib.mkModule config "codex" {
  programs.zsh.envExtra = lib.mkBefore ''
    if [[ -n $AGENT_ZSH_COMPAT ]]; then
      setopt no_nomatch no_equals sh_word_split
    fi
  '';
}

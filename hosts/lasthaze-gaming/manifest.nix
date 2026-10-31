{ myLib, ... }:
{
  my = myLib.enableList [
    "base"
    "users"
    "wsl"
    "windows-defaults"
    "windows-openssh"
    "windows-power"
    "windows-nilesoft-shell"
    "windows-windhawk"
    "windows-cursor"
  ];

  home-manager.users.yoshintame.my = myLib.enableList [
    "atuin"
    "bat"
    "btop"
    "eza"
    "fish"
    "fzf"
    "git"
    "gitui"
    "gtrash"
    "lazygit"
    "mise"
    "nvim"
    "starship"
    "tmux"
    "uv"
    "yazi"
    "zoxide"
  ];
}

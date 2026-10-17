{ myLib, ... }:
{
  my = myLib.enableList [
    "base"
    "users"
    "wsl"
    "windows-defaults"
    "windows-openssh"
    "windows-power"
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

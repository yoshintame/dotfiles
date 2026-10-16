{ myLib, ... }:
{
  my = myLib.enableList [
    "base"
    "users"
    "wsl"
    "windows-defaults"
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

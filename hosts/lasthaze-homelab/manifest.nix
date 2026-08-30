{ myLib, ... }:
{
  my = myLib.enableList [
    "base"
    "ssh"
    "users"
    "tailscale"
    "sops-age-key"
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
    "yazi"
    "zoxide"
  ];
}

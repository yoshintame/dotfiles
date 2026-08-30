{ myLib, ... }:
{
  my.base = myLib.enabled;
  my.ssh = myLib.enabled;
  my.users = myLib.enabled;
  my.sops-age-key = myLib.enabled;

  home-manager.users.yoshintame = {
    my.git = myLib.enabled;
    my.fish = myLib.enabled;
    my.gitui = myLib.enabled;
    my.lazygit = myLib.enabled;
    my.tmux = myLib.enabled;
    my.yazi = myLib.enabled;
    my.atuin = myLib.enabled;
    my.bat = myLib.enabled;
    my.starship = myLib.enabled;
    my.btop = myLib.enabled;
    my.nvim = myLib.enabled;
    my.mise = myLib.enabled;
    my.fzf = myLib.enabled;
    my.zoxide = myLib.enabled;
  };
}

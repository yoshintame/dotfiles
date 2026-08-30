{ myLib, ... }:
{
  my.macos-defaults = myLib.enabled;
  my.homebrew = myLib.enabled;
  my.linux-builder = myLib.enabled;
  my.session-env = myLib.enabled;

  home-manager.users.yoshintame = {
    my.file-associations = myLib.enabled;
    my.git = myLib.enabled;
    my.fish = myLib.enabled;
    my.gitui = myLib.enabled;
    my.kitty = myLib.enabled;
    my.lazygit = myLib.enabled;
    my.tmux = myLib.enabled;
    my.vscode = myLib.enabled;
    my.wezterm = myLib.enabled;
    my.warp = myLib.enabled;
    my.yazi = myLib.enabled;
    my.hammerspoon = myLib.enabled;
    my.ghostty = myLib.enabled;
    my.karabiner = myLib.enabled;
    my.aerospace = myLib.enabled;
    my.atuin = myLib.enabled;
    my.bat = myLib.enabled;
    my.starship = myLib.enabled;
    my.zoxide = myLib.enabled;
    my.fzf = myLib.enabled;
    my.btop = myLib.enabled;
    my.nvim = myLib.enabled;
    my.mise = myLib.enabled;
    my.op = myLib.enabled;
    my.resticprofile = myLib.enabled;
    my.rclone = myLib.enabled;
    my.btt-gestures = myLib.enabled;
    my.claude = myLib.enabled;
    my.claude-code-patch = myLib.enabled;
    my.codex = myLib.enabled;
    my.serena = myLib.enabled;
    my.iina = myLib.enabled;
    my.worktrunk = myLib.enabled;
  };
}

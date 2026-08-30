let
  username = "yoshintame";
  homeDir = "/Users/${username}";
  sharedEnv = {
    EDITOR = "code --wait";
    VISUAL = "code --wait";
    GOPATH = "${homeDir}/go";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";
    DOTFILES = "${homeDir}/.dotfiles";
    OBSIDIAN_VAULT = "${homeDir}/Documents/obsidian/yoshintame";
    XDG_CONFIG_HOME = "${homeDir}/.config";
    XDG_DATA_HOME = "${homeDir}/.local/share";
    XDG_STATE_HOME = "${homeDir}/.local/state";
    XDG_CACHE_HOME = "${homeDir}/.cache";
    TRASH = "${homeDir}/.Trash";
    PLAY = "iina";
    SSH_AUTH_SOCK = "${homeDir}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  };
  sharedPath = [
    "/run/current-system/sw/bin"
    "/etc/profiles/per-user/${username}/bin"
    "${homeDir}/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "${homeDir}/.local/share/mise/shims"
    "${homeDir}/.local/share/pnpm"
    "${homeDir}/.bun/bin"
    "${homeDir}/go/bin"
    "${homeDir}/.local/bin"
    "${homeDir}/bin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  ];
in
{
  inherit
    username
    homeDir
    sharedEnv
    sharedPath
    ;
  brewfile = ./packages/Brewfile;
}

let
  username = "yoshintame";
  homeDir = "/Users/${username}";
  sharedEnv = {
    EDITOR = "zed --wait";
    VISUAL = "zed --wait";
    GOPATH = "${homeDir}/.local/share/go";
    CARGO_HOME = "${homeDir}/.local/share/cargo";
    RUSTUP_HOME = "${homeDir}/.local/share/rustup";
    NPM_CONFIG_USERCONFIG = "${homeDir}/.config/npm/npmrc";
    NPM_CONFIG_CACHE = "${homeDir}/.cache/npm";
    PKG_CACHE_PATH = "${homeDir}/.cache/pkg-cache";
    BUNDLE_USER_CONFIG = "${homeDir}/.config/bundle";
    BUNDLE_USER_CACHE = "${homeDir}/.cache/bundle";
    BUNDLE_USER_PLUGIN = "${homeDir}/.local/share/bundle";
    ANSIBLE_HOME = "${homeDir}/.local/share/ansible";
    LESSHISTFILE = "${homeDir}/.local/state/less/history";
    WGETRC = "${homeDir}/.config/wgetrc";
    PNPM_HOME = "${homeDir}/.local/share/pnpm";
    BUN_INSTALL = "${homeDir}/.local/share/bun";
    BUN_INSTALL_CACHE_DIR = "${homeDir}/.cache/.bun/install/cache";
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
    "${homeDir}/.local/share/bun/bin"
    "${homeDir}/.local/share/go/bin"
    "${homeDir}/.local/share/cargo/bin"
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
}

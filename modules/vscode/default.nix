{pkgs, ...}: {
  home.packages = [
    pkgs.tmux
  ];

  nixDotbot.links = {
    "~/Library/Application Support/Cursor/User/" = {
      path = "modules/vscode/config/**";
      glob = true;
    };
    "~/Library/Application Support/Code/User/" = {
      path = "modules/vscode/config/**";
      glob = true;
    };

    "~/.cursor/extensions/true-vibrant-vscode-theme" = "modules/vscode/theme/true-vibrant-vscode-theme";
    "~/.vscode/extensions/true-vibrant-vscode-theme" = "modules/vscode/theme/true-vibrant-vscode-theme";
  };
}

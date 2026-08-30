{ config, myLib, ... }:
myLib.mkModule config "vscode" {
  nixDotbot.links = {
    "~/Library/Application Support/Cursor/User/" = {
      path = "modules/home/vscode/config/**";
      glob = true;
    };
    "~/Library/Application Support/Code/User/" = {
      path = "modules/home/vscode/config/**";
      glob = true;
    };

    "~/.cursor/extensions/true-vibrant-vscode-theme" =
      "modules/home/vscode/theme/true-vibrant-vscode-theme";
    "~/.vscode/extensions/true-vibrant-vscode-theme" =
      "modules/home/vscode/theme/true-vibrant-vscode-theme";
  };
}

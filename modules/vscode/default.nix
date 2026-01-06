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

    "~/.cursor/extensions/" = {
      path = "modules/vscode/theme/**";
      glob = true;
    };
    "~/.vscode/extensions/" = {
      path = "modules/vscode/theme/**";
      glob = true;
    };
  };
}

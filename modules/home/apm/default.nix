{
  config,
  pkgs,
  myLib,
  ...
}:
myLib.mkModule config "apm" {
  home.packages = [
    (pkgs.writeShellApplication {
      name = "apm";
      runtimeInputs = [ pkgs.gawk ];
      text = ''
        filtered="$(mktemp)"
        trap 'rm -f "$filtered"' EXIT
        awk '/^[[:space:]]*\[/ { skip = ($0 ~ /^[[:space:]]*\[url "https:\/\/github\.com\/"\]/) } !skip' "$HOME/.config/git/config" > "$filtered"
        GIT_CONFIG_GLOBAL="$filtered" "$HOME/.local/share/mise/shims/apm" "$@"
      '';
    })
  ];

  stencil.files."~/.config/fish/conf.d/mcp-secrets.fish" = {
    template = ./config/mcp-secrets.fish.tmpl;
    sopsFile = ./secrets.yaml;
  };

}

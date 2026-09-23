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
        GIT_CONFIG_GLOBAL="$filtered" "$HOME/.local/bin/apm" "$@"
      '';
    })
  ];

  nixLink.links = {
    "~/.apm/apm.lock.yaml" = "modules/home/apm/config/apm.lock.yaml";
    "~/.apm/apm.yml" = "modules/home/apm/config/apm.yml";
  };

  sopsTemplates.render = {
    "~/.config/fish/conf.d/mcp-secrets.fish" = {
      template = ./config/mcp-secrets.fish.tmpl;
      secretsFile = ./secrets.yaml;
    };
  };

}

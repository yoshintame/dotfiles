{
  pkgs,
  pkgs-unstable ? pkgs,
  ...
}: {
  programs.fish = {
    enable = true;
    interactiveShellInit = "set fish_greeting";
    plugins = [
      { name = "autopair"; src = pkgs.fishPlugins.autopair.src; }
      { name = "sponge"; src = pkgs.fishPlugins.sponge.src; }
      { name = "puffer-fish"; src = pkgs.fishPlugins.puffer.src; }
      { name = "plugin-git"; src = pkgs.fishPlugins.plugin-git.src; }
      { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      {
        name = "plugin-thefuck";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-thefuck";
          rev = "6c9a926d045dc404a11854a645917b368f78fc4d";
          sha256 = "1n6ibqcgsq1p8lblj334ym2qpdxwiyaahyybvpz93c8c9g4f9ipl";
        };
      }
      {
        name = "fish-plugin-sudo";
        src = pkgs.fetchFromGitHub {
          owner = "eth-p";
          repo = "fish-plugin-sudo";
          rev = "e153fdea568cd370312f9c0809fac15fc7582bfd";
          sha256 = "1vlywpfh9k4mg9zczvzfvx47cx9m2xnj0kk8cal07s49dzhbfckd";
        };
      }
      {
        name = "fish-utils-core";
        src = pkgs.fetchFromGitHub {
          owner = "halostatue";
          repo = "fish-utils-core";
          rev = "v3.2.0";
          sha256 = "05c7pjdx3cpv0wcyhcndqkzcw68ip236bd3spw2b8r1g1p3swwsw";
        };
      }
      {
        name = "fish-utils";
        src = pkgs.fetchFromGitHub {
          owner = "halostatue";
          repo = "fish-utils";
          rev = "v4.0.2";
          sha256 = "0qfvqrynzbw0xb02i9ysv8z7yz33sywv6vmfig2fhfbqpvl6d1xz";
        };
      }
      {
        name = "fish-finders";
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-finders";
          rev = "d33e10ff4eb3832d7c449f9374ff131da04ea41c";
          sha256 = "0vvi7m5zrbxywda1d3ipw47qwh8lh51p6bjimwaqm7i18vbf1ala";
        };
      }
      {
        name = "catppuccin";
        src = pkgs.fetchFromGitHub {
          owner = "catppuccin";
          repo = "fish";
          rev = "5fc5ae9c2ec22eb376cb03ce76f0d262a38960f3";
          sha256 = "19qd700wj0h7k68fs27qa1b1qzs8ccd8rw6qpml3ccyffxhmd8yw";
        };
      }
    ];
  };

  home.packages = with pkgs; [
    grc
    thefuck
    eza
    bat
    fd
    ripgrep
    fzf
    gtrash
  ];

  nixDotbot.links = {
    "~/.config/fish/" = {
      path = "modules/fish/config/**";
      glob = true;
    };
  };
}

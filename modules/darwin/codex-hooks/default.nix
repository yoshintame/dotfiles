{
  config,
  pkgs,
  hostFacts,
  myLib,
  ...
}:
let
  hooksDir = "${hostFacts.sharedEnv.DOTFILES}/modules/home/agents-shared/config/hooks";

  command =
    name: extra:
    {
      type = "command";
      command = "${hooksDir}/${name}";
    }
    // extra;

  requirements = {
    hooks = {
      UserPromptSubmit = [
        { hooks = [ (command "session-title.sh" { timeout = 15; }) ]; }
      ];
      PreToolUse = [
        {
          matcher = "^Bash$";
          hooks = map (name: command name { }) [
            "tool-steering.sh"
            "commit-attribution-guard.sh"
            "git-clone-layout.sh"
          ];
        }
        {
          matcher = "^mcp__chrome-devtools__.*";
          hooks = [ (command "chrome-cdp-ensure.sh" { timeout = 30; }) ];
        }
      ];
    };
  };
in
myLib.mkModule config "codex-hooks" {
  environment.etc."codex/requirements.toml".source =
    (pkgs.formats.toml { }).generate "codex-requirements.toml"
      requirements;
}

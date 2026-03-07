{...}: {
  nixDotbot.links = {
    "~/.claude/" = {
      path = "modules/claude/config/**";
      glob = true;
    };
  };
}

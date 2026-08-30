{ lib }:
{
  mkModule = import ./mk-module.nix { inherit lib; };

  enabled = {
    enable = true;
  };
  disabled = {
    enable = false;
  };
}

{ myLib, ... }:
{
  my = myLib.enableList [
    "base"
    "ssh"
    "users"
    "tailscale"
    "sysctl-hardening"
  ];
}

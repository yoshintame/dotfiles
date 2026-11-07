{
  tailnetAddress = "100.123.237.27";
  prometheus = {
    host = "lasthaze-homelab";
    port = 9090;
  };
  resticHub = {
    host = "lasthaze-homelab";
    port = 8000;
    client = "lasthaze-mbp";
  };
}

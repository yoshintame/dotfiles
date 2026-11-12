{
  config,
  myLib,
  ...
}:
myLib.mkModule config "rclone" {
  programs.rclone.enable = true;
}

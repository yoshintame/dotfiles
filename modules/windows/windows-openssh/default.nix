{
  config,
  lib,
  myLib,
  ...
}:
let
  sshDir = ''C:\ProgramData\ssh'';
in
myLib.mkModule config "windows-openssh" {
  windows = {
    capabilities = [ "OpenSSH.Server~~~~0.0.1.0" ];

    firewall.rules.OpenSSH-Server-In-TCP = {
      displayName = "OpenSSH SSH Server (sshd)";
      localPort = 22;
      remoteAddress = [
        "100.64.0.0/10"
        "fd7a:115c:a1e0::/48"
      ];
    };

    services.sshd = {
      startType = "auto";
      state = "running";
    };

    files = {
      "${sshDir}\\sshd_config" = {
        text = ''
          AuthorizedKeysFile .ssh/authorized_keys
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          Subsystem sftp sftp-server.exe

          Match Group administrators
                 AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
        '';
        onChange = "powershell -NoProfile -Command Restart-Service sshd";
      };
      "${sshDir}\\administrators_authorized_keys" = {
        text = lib.concatLines config.users.users.yoshintame.openssh.authorizedKeys.keys;
        grants = [
          "*S-1-5-32-544:F"
          "*S-1-5-18:F"
        ];
      };
    };

    registry.HKLM."SOFTWARE\\OpenSSH".DefaultShell =
      ''C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'';
  };
}

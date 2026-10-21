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
    winget.packages."Tailscale.Tailscale" = { };

    capabilities = [ "OpenSSH.Server~~~~0.0.1.0" ];

    firewall.rules.OpenSSH-Server-In-TCP = {
      displayName = "OpenSSH SSH Server (sshd)";
      localPort = 22;
      interfaceAlias = "Tailscale";
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
          AllowUsers yoshintame
          Subsystem sftp sftp-server.exe

          Match Group administrators
                 AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
        '';
        validate = file: ''"%SystemRoot%\System32\OpenSSH\sshd.exe" -t -f ${file}'';
        onChange = "powershell -NoProfile -Command Restart-Service sshd";
      };
      "${sshDir}\\administrators_authorized_keys" = {
        text = lib.concatLines myLib.authorizedKeys;
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

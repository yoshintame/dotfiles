{
  config,
  pkgs,
  myLib,
  ...
}:
let
  username = "yoshintame";
  keyDir = "/home/${username}/.config/sops/age";
  keyPath = "${keyDir}/keys.txt";
  hostKey = "/etc/ssh/ssh_host_ed25519_key";
in
myLib.mkModule config "sops-age-key" {
  systemd.services.sops-age-key-bootstrap = {
    description = "Derive user-level age key from SSH host key for sops-templates (Variant A)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "sshd.service"
      "local-fs.target"
    ];
    requires = [ "sshd.service" ];

    unitConfig = {
      ConditionPathExists = [
        "!${keyPath}"
        hostKey
      ];
    };

    path = [
      pkgs.ssh-to-age
      pkgs.coreutils
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      install -d -m 0700 -o ${username} -g users ${keyDir}
      ssh-to-age -private-key -i ${hostKey} > ${keyPath}.tmp
      chown ${username}:users ${keyPath}.tmp
      chmod 0600 ${keyPath}.tmp
      mv ${keyPath}.tmp ${keyPath}
    '';
  };
}

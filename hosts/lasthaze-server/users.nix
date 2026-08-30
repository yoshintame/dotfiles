{ pkgs, ... }:
let
  username = "yoshintame";

  authorizedKeys = [
    # TODO: вставить публичный SSH-ключ MBP до реального деплоя.
    # На MBP получить через: cat ~/.ssh/id_ed25519.pub
    # либо через 1Password SSH Agent: op read 'op://Private/<ssh-key>/public key'
  ];
in
{
  users.mutableUsers = false;
  users.allowNoPasswordLogin = true;

  users.users.${username} = {
    isNormalUser = true;
    description = "Mikhail Ivanov";
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = authorizedKeys;

    hashedPassword = "!";
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = authorizedKeys;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}

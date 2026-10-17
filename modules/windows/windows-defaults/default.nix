{
  config,
  lib,
  myLib,
  ...
}:
let
  authorizedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJz1+EB4G3BZUXHDTrLCmRVFUnzEuKbSO5zIwKWGl0ev yoshintame-mbp";
  sshDir = ''C:\ProgramData\ssh'';
  tailnet = [
    "100.64.0.0/10"
    "fd7a:115c:a1e0::/48"
  ];

  openssh = {
    windows.capabilities = [ "OpenSSH.Server~~~~0.0.1.0" ];

    windows.files = {
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
        text = authorizedKey + "\n";
        grants = [
          "*S-1-5-32-544:F"
          "*S-1-5-18:F"
        ];
      };
    };

    windows.services.sshd = {
      startType = "auto";
      state = "running";
    };

    windows.registry.HKLM.SOFTWARE.OpenSSH.DefaultShell =
      ''C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'';

    windows.firewall.rules."OpenSSH SSH Server (sshd)" = {
      localPort = 22;
      remoteAddress = tailnet;
    };
  };

  machine = {
    windows.power = {
      timeouts = {
        standby-timeout-ac = 0;
        hibernate-timeout-ac = 0;
      };
      hibernate = false;
    };

    windows.networkAdapters.powerManagement = {
      WakeOnMagicPacket = "Enabled";
      WakeOnPattern = "Disabled";
    };
  };

  tweaks.windows.defaults = {
    explorer = {
      showFileExtensions = true;
      showHiddenFiles = true;
      launchTo = "thisPC";
      syncProviderNotifications = false;
    };

    start = {
      recommendations = false;
      trackAppLaunches = false;
      suggestions = false;
    };

    search = {
      webResults = false;
      cortana = false;
    };

    suggestions = {
      welcomeExperience = false;
      lockScreenTips = false;
      tips = false;
      settingsSuggestions = false;
      settingsMicrosoft365Ads = false;
      accountNotifications = false;
      finishSetupPrompt = false;
      suggestedNotifications = false;
      backupReminders = false;
      phoneLink = false;
      silentAppInstalls = false;
    };

    privacy = {
      telemetry = "required";
      telemetryService = false;
      telemetryTasks = false;
      advertisingId = false;
      tailoredExperiences = false;
      activityHistory = false;
      onlineSpeechRecognition = false;
      inkingAndTypingImprovement = false;
      inkingAndTypingPersonalization = false;
      feedbackPrompts = false;
    };

    ai = {
      copilot = false;
      recall = false;
      clickToDo = false;
      paint = false;
      notepad = false;
    };

    gaming.gameDvr = false;

    system = {
      sudo = "inline";
      developerMode = true;
      errorReporting = false;
      deviceMetadataDownload = false;
    };
  };
in
myLib.mkModule config "windows-defaults" (
  lib.mkMerge [
    openssh
    machine
    tweaks
  ]
)

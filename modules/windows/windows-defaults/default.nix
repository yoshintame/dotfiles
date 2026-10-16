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

  explorer = {
    windows.registry.HKCU.Software.Microsoft.Windows.CurrentVersion.Explorer.Advanced = {
      HideFileExt = 0;
      Hidden = 1;
      LaunchTo = 1;
    };
  };

  system = {
    windows.registry.HKLM.SOFTWARE.Microsoft.Windows.CurrentVersion = {
      Sudo.Enabled = 3;
      AppModelUnlock.AllowDevelopmentWithoutDevLicense = 1;
    };

    windows.power.timeouts = {
      standby-timeout-ac = 0;
      hibernate-timeout-ac = 0;
    };

    windows.networkAdapters.powerManagement = {
      WakeOnMagicPacket = "Enabled";
      WakeOnPattern = "Disabled";
    };
  };

  debloat = {
    windows.registry.HKLM.SOFTWARE = {
      Policies.Microsoft.Windows = {
        DataCollection.AllowTelemetry = 1;
        System.PublishUserActivities = 0;
        WindowsCopilot.TurnOffWindowsCopilot = 1;
        WindowsAI = {
          DisableAIDataAnalysis = 1;
          AllowRecallEnablement = 0;
          TurnOffSavingSnapshots = 1;
          DisableClickToDo = 1;
        };
        "Windows Search" = {
          AllowCortana = 0;
          CortanaConsent = 0;
        };
        CloudContent.DisableConsumerAccountStateContent = 1;
        GameDVR.AllowGameDVR = 0;
        "Device Metadata".PreventDeviceMetadataFromNetwork = 1;
      };
      Policies.WindowsNotepad.DisableAIFeatures = 1;
      Microsoft.Windows.CurrentVersion.Policies.Paint = {
        DisableCocreator = 1;
        DisableGenerativeFill = 1;
        DisableImageCreator = 1;
        DisableGenerativeErase = 1;
        DisableRemoveBackground = 1;
      };
    };

    windows.registry.HKCU = {
      Software.Policies.Microsoft.Windows = {
        WindowsCopilot.TurnOffWindowsCopilot = 1;
        WindowsAI = {
          DisableAIDataAnalysis = 1;
          DisableClickToDo = 1;
        };
        Explorer.DisableSearchBoxSuggestions = 1;
      };

      Software.Microsoft = {
        Windows.CurrentVersion = {
          AdvertisingInfo.Enabled = 0;
          Privacy.TailoredExperiencesWithDiagnosticDataEnabled = 0;
          Explorer.Advanced = {
            Start_TrackProgs = 0;
            ShowCopilotButton = 0;
            Start_IrisRecommendations = 0;
            ShowSyncProviderNotifications = 0;
            Start_AccountNotifications = 0;
          };
          ContentDeliveryManager = {
            "SubscribedContent-310093Enabled" = 0;
            "SubscribedContent-338387Enabled" = 0;
            "SubscribedContent-338388Enabled" = 0;
            "SubscribedContent-338389Enabled" = 0;
            "SubscribedContent-338393Enabled" = 0;
            "SubscribedContent-353694Enabled" = 0;
            "SubscribedContent-353696Enabled" = 0;
            "SubscribedContent-353698Enabled" = 0;
            SystemPaneSuggestionsEnabled = 0;
            SoftLandingEnabled = 0;
            SilentInstalledAppsEnabled = 0;
            RotatingLockScreenOverlayEnabled = 0;
          };
          SystemSettings.AccountNotifications.EnableAccountNotifications = 0;
          UserProfileEngagement.ScoobeSystemSettingEnabled = 0;
          Notifications.Settings = {
            "Windows.SystemToast.Suggested".Enabled = 0;
            "Windows.SystemToast.BackupReminder".Enabled = 0;
          };
          Mobility.OptedIn = 0;
          GameDVR.AppCaptureEnabled = 0;
        };
        Speech_OneCore.Settings.OnlineSpeechPrivacy.HasAccepted = 0;
        Input.TIPC.Enabled = 0;
        InputPersonalization = {
          RestrictImplicitInkCollection = 1;
          RestrictImplicitTextCollection = 1;
          TrainedDataStore.HarvestContacts = 0;
        };
        Personalization.Settings.AcceptedPrivacyPolicy = 0;
        Siuf.Rules = {
          NumberOfSIUFInPeriod = 0;
          PeriodInNanoSeconds = null;
        };
      };

      System.GameConfigStore.GameDVR_Enabled = 0;
    };

    windows.services = {
      DiagTrack = {
        startType = "disabled";
        state = "stopped";
      };
      WerSvc = {
        startType = "disabled";
        state = "stopped";
      };
    };

    windows.scheduledTasks =
      lib.genAttrs
        [
          ''\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser''
          ''\Microsoft\Windows\Application Experience\ProgramDataUpdater''
          ''\Microsoft\Windows\Autochk\Proxy''
          ''\Microsoft\Windows\Customer Experience Improvement Program\Consolidator''
          ''\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip''
          ''\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector''
          ''\Microsoft\Windows\Feedback\Siuf\DmClient''
          ''\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload''
          ''\Microsoft\Windows\Windows Error Reporting\QueueReporting''
        ]
        (_: {
          enable = false;
        });

    windows.power.hibernate = false;
  };
in
myLib.mkModule config "windows-defaults" (
  lib.mkMerge [
    openssh
    explorer
    system
    debloat
  ]
)

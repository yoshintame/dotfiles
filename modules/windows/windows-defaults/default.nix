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
      LaunchTo = 1; # open Explorer on This PC
    };
  };

  system = {
    windows.registry.HKLM.SOFTWARE.Microsoft.Windows.CurrentVersion = {
      Sudo.Enabled = 3; # sudo.exe inline: output and exit code stay in the calling console
      AppModelUnlock.AllowDevelopmentWithoutDevLicense = 1; # developer mode
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
        DataCollection.AllowTelemetry = 1; # required diagnostic data only; Pro treats 0 as 1
        System.PublishUserActivities = 0; # activity history
        WindowsCopilot.TurnOffWindowsCopilot = 1;
        WindowsAI = {
          DisableAIDataAnalysis = 1; # Recall snapshots analysis
          AllowRecallEnablement = 0; # Recall feature itself
          TurnOffSavingSnapshots = 1;
          DisableClickToDo = 1; # Click to Do screen actions
        };
        "Windows Search" = {
          # Cortana in search
          AllowCortana = 0;
          CortanaConsent = 0;
        };
        CloudContent.DisableConsumerAccountStateContent = 1; # Microsoft 365 ads on the Settings home page
        GameDVR.AllowGameDVR = 0; # Game DVR for all users
        "Device Metadata".PreventDeviceMetadataFromNetwork = 1; # no vendor apps pulled with device drivers
      };
      Policies.WindowsNotepad.DisableAIFeatures = 1; # Copilot in Notepad
      Microsoft.Windows.CurrentVersion.Policies.Paint = {
        # AI features in Paint
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
        Explorer.DisableSearchBoxSuggestions = 1; # Bing results in Start search
      };

      Software.Microsoft = {
        Windows.CurrentVersion = {
          AdvertisingInfo.Enabled = 0; # advertising ID
          Privacy.TailoredExperiencesWithDiagnosticDataEnabled = 0; # tips and ads based on diagnostic data
          Explorer.Advanced = {
            Start_TrackProgs = 0; # Start and search ranking by launched apps
            ShowCopilotButton = 0;
            Start_IrisRecommendations = 0; # tips and app promotions in Start
            ShowSyncProviderNotifications = 0; # OneDrive ads in Explorer
            Start_AccountNotifications = 0; # Microsoft account nags in Start
          };
          ContentDeliveryManager = {
            "SubscribedContent-310093Enabled" = 0; # welcome experience after updates
            "SubscribedContent-338387Enabled" = 0; # lock screen tips
            "SubscribedContent-338388Enabled" = 0; # suggestions in Start
            "SubscribedContent-338389Enabled" = 0; # tips while using Windows
            "SubscribedContent-338393Enabled" = 0; # suggested content in Settings
            "SubscribedContent-353694Enabled" = 0;
            "SubscribedContent-353696Enabled" = 0;
            "SubscribedContent-353698Enabled" = 0;
            SystemPaneSuggestionsEnabled = 0; # app suggestions in Start
            SoftLandingEnabled = 0; # tips about Windows features
            SilentInstalledAppsEnabled = 0; # silent install of promoted apps
            RotatingLockScreenOverlayEnabled = 0; # fun facts overlay on the lock screen
          };
          SystemSettings.AccountNotifications.EnableAccountNotifications = 0; # account notifications in Settings
          UserProfileEngagement.ScoobeSystemSettingEnabled = 0; # "finish setting up your device" prompt
          Notifications.Settings = {
            "Windows.SystemToast.Suggested".Enabled = 0; # suggested-service toasts
            "Windows.SystemToast.BackupReminder".Enabled = 0; # Windows Backup reminders
          };
          Mobility.OptedIn = 0; # Phone Link suggestions
          GameDVR.AppCaptureEnabled = 0; # Game Bar background recording
        };
        Speech_OneCore.Settings.OnlineSpeechPrivacy.HasAccepted = 0; # online speech recognition
        Input.TIPC.Enabled = 0; # send inking and typing data to Microsoft
        InputPersonalization = {
          # learn from handwriting and typing
          RestrictImplicitInkCollection = 1;
          RestrictImplicitTextCollection = 1;
          TrainedDataStore.HarvestContacts = 0;
        };
        Personalization.Settings.AcceptedPrivacyPolicy = 0; # speech and inking personalization consent
        Siuf.Rules = {
          # feedback prompts: never
          NumberOfSIUFInPeriod = 0;
          PeriodInNanoSeconds = null;
        };
      };

      System.GameConfigStore.GameDVR_Enabled = 0; # Game DVR
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

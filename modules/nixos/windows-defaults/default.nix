{ config, myLib, ... }:
myLib.mkModule config "windows-defaults" {
  windows.defaults = {
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
      sudo = "inputDisabled";
      developerMode = true;
      errorReporting = false;
      deviceMetadataDownload = false;
    };
  };

  windows.registry = {
    HKLM."SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System".ConsentPromptBehaviorAdmin =
      0;
    HKCU."Control Panel\\Desktop" = {
      MenuShowDelay = "20";
      JPEGImportQuality = 100;
    };
    HKCU."Software\\Microsoft\\Clipboard".EnableClipboardHistory = 1;
    HKCU."Console\\%%Startup" = {
      DelegationConsole = "{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}";
      DelegationTerminal = "{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}";
    };
    HKCU."Software\\Microsoft\\Windows\\CurrentVersion\\Explorer" = {
      ShowRecent = 0;
      ShowFrequent = 0;
      ShowCloudFilesInQuickAccess = 0;
    };
    HKLM."SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Desktop\\NameSpace\\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" =
      null;
    HKLM."SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Desktop\\NameSpace\\DelegateFolders\\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" =
      null;
    HKLM."SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Desktop\\NameSpace\\DelegateFolders\\{F5FB2C77-0E2F-4A16-A381-3E560C68BC83}" =
      null;
  };
}

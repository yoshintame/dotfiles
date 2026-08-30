_:
let
  homeDir = "/Users/yoshintame";
in
{
  system.primaryUser = "yoshintame";
  system.startup.chime = false;

  system.defaults = {
    LaunchServices.LSQuarantine = false;

    NSGlobalDomain = {
      AppleFontSmoothing = 1;
      AppleInterfaceStyleSwitchesAutomatically = false;
      AppleKeyboardUIMode = 3;
      AppleMeasurementUnits = "Centimeters";
      AppleMetricUnits = 1;
      ApplePressAndHoldEnabled = false;
      AppleShowAllExtensions = true;
      AppleShowScrollBars = "WhenScrolling";
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      NSAutomaticWindowAnimationsEnabled = false;
      NSDisableAutomaticTermination = true;
      NSDocumentSaveNewDocumentsToCloud = false;
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      NSTableViewDefaultSizeMode = 2;
      NSUseAnimatedFocusRing = false;
      NSWindowResizeTime = 0.001;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
      "com.apple.mouse.tapBehavior" = 1;
      "com.apple.sound.beep.feedback" = 0;
      "com.apple.springing.delay" = 0.0;
      "com.apple.springing.enabled" = true;
    };

    dock = {
      autohide = true;
      autohide-delay = 1.0;
      autohide-time-modifier = 0.0;
      dashboard-in-overlay = true;
      enable-spring-load-actions-on-all-items = true;
      expose-animation-duration = 0.1;
      launchanim = false;
      mineffect = "scale";
      minimize-to-application = true;
      mouse-over-hilite-stack = true;
      mru-spaces = false;
      persistent-apps = [ ];
      show-process-indicators = true;
      show-recents = false;
      showhidden = true;
      static-only = true;
      tilesize = 36;
      wvous-bl-corner = 1;
      wvous-br-corner = 1;
      wvous-tl-corner = 1;
      wvous-tr-corner = 1;
    };

    finder = {
      AppleShowAllFiles = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv";
      NewWindowTarget = "Home";
      QuitMenuItem = true;
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowMountedServersOnDesktop = false;
      ShowPathbar = true;
      ShowRemovableMediaOnDesktop = false;
      ShowStatusBar = false;
      _FXShowPosixPathInTitle = true;
      _FXSortFoldersFirst = true;
    };

    screencapture = {
      disable-shadow = true;
      location = "~/Library/Mobile Documents/com~apple~CloudDocs/Screenshots";
      type = "png";
    };

    screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    trackpad = {
      Clicking = true;
    };

    universalaccess = {
      closeViewScrollWheelToggle = true;
      closeViewZoomFollowsFocus = true;
    };

    CustomUserPreferences = {
      "com.apple.AppleMultitouchTrackpad" = {
        Clicking = true;
      };

      "com.apple.CrashReporter" = {
        DialogType = "none";
      };

      "com.apple.HIToolbox" = {
        AppleCurrentKeyboardLayoutInputSourceID = "com.apple.keylayout.ABC";
        AppleInputSourceHistory = [
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout Name" = "ABC";
            "KeyboardLayout ID" = 252;
          }
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout Name" = "RussianWin";
            "KeyboardLayout ID" = 19458;
          }
        ];
        AppleSelectedInputSources = [
          {
            InputSourceKind = "Non Keyboard Input Method";
            "Bundle ID" = "com.apple.PressAndHold";
          }
          {
            InputSourceKind = "Keyboard Layout";
            "KeyboardLayout Name" = "ABC";
            "KeyboardLayout ID" = 252;
          }
        ];
      };

      "com.apple.Mail" = {
        AddressesIncludeNameOnPasteboard = false;
        ConversationViewSortDescending = true;
        DisableReplyAnimations = true;
        DisableSendAnimations = true;
      };

      "com.apple.NetworkBrowser" = {
        BrowseAllInterfaces = true;
      };

      "com.apple.Safari" = {
        AlwaysRestoreSessionAtLaunch = true;
        AutoFillCreditCardData = false;
        AutoFillFromAddressBook = false;
        AutoFillMiscellaneousForms = false;
        AutoFillPasswords = false;
        AutoOpenSafeDownloads = false;
        CanPromptForPushNotifications = false;
        Command1Through9SwitchesTabs = false;
        CommandClickMakesTabs = true;
        DownloadsClearingPolicy = 0;
        ExtensionsEnabled = true;
        FindOnPageMatchesWordStartsOnly = false;
        HomePage = "about:blank";
        IncludeDevelopMenu = true;
        IncludeInternalDebugMenu = true;
        InstallExtensionUpdatesAutomatically = true;
        NewTabBehavior = 0;
        NewWindowBehavior = 0;
        OpenNewTabsInFront = false;
        PreloadTopHit = false;
        ProxiesInBookmarksBar = [ ];
        ReadingListSaveArticlesOfflineAutomatically = false;
        SendDoNotTrackHTTPHeader = true;
        ShowFavoritesBar = false;
        ShowFullURLInSmartSearchField = true;
        ShowIconsInTabs = true;
        ShowSidebarInTopSites = false;
        SuppressSearchSuggestions = true;
        UniversalSearchEnabled = false;
        WarnAboutFraudulentWebsites = false;
        WebAutomaticSpellingCorrectionEnabled = false;
        WebContinuousSpellCheckingEnabled = true;
        WebKitDeveloperExtrasEnabledPreferenceKey = true;
        WebKitInitialTimedLayoutDelay = 0.25;
        WebKitJavaEnabled = false;
        WebKitJavaScriptCanOpenWindowsAutomatically = false;
        WebKitPluginsEnabled = false;
        WebKitStorageBlockingPolicy = 1;
        WebKitTabToLinksPreferenceKey = true;
        "WebKitPreferences.applePayCapabilityDisclosureAllowed" = true;
        WebsiteSpecificSearchEnabled = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" = true;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2HyperlinkAuditingEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaEnabledForLocalFiles" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2JavaScriptCanOpenWindowsAutomatically" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2PluginsEnabled" = false;
        "com.apple.Safari.ContentPageGroupIdentifier.WebKit2TabsToLinks" = true;
      };

      "com.apple.SoftwareUpdate" = {
        AutomaticCheckEnabled = true;
        AutomaticDownload = 1;
        ConfigDataInstall = 0;
        CriticalUpdateInstall = 1;
        ScheduleFrequency = 1;
      };

      "com.apple.Spotlight" = {
        showedFTE = 1;
        showedLearnMore = 1;
      };

      "com.apple.Terminal" = {
        SecureKeyboardEntry = true;
        ShowLineMarks = 0;
        StringEncodings = [ 4 ];
      };

      "com.apple.TimeMachine" = {
        DoNotOfferNewDisksForBackup = true;
      };

      "com.apple.appstore" = {
        ShowDebugMenu = true;
        WebKitDeveloperExtras = true;
      };

      "com.apple.assistant.support" = {
        "Assistant Enabled" = false;
      };

      "com.apple.commerce" = {
        AutoUpdate = true;
        AutoUpdateRestartRequired = false;
      };

      "com.apple.dashboard" = {
        dashboard-enabled-state = 1;
        mcx-disabled = true;
      };

      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
        UseBareEnumeration = true;
      };

      "com.apple.dock" = {
        expose-group-by-app = false;
        workspaces-auto-swoosh = false;
        wvous-bl-modifier = 0;
        wvous-br-modifier = 0;
        wvous-tl-modifier = 0;
        wvous-tr-modifier = 0;
      };

      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        Clicking = true;
      };

      "com.apple.finder" = {
        DisableAllAnimations = true;
        DesktopViewSettings = {
          IconViewSettings = {
            arrangeBy = "name";
            gridSpacing = 1.0;
            iconSize = 64.0;
            showItemInfo = true;
          };
        };
        FK_StandardViewSettings = {
          IconViewSettings = {
            arrangeBy = "name";
            gridSpacing = 1.0;
            iconSize = 64.0;
            showItemInfo = true;
          };
        };
        FXEnableRemoveFromICloudDriveWarning = false;
        FXInfoPanesExpanded = {
          General = true;
          OpenWith = true;
          Privileges = true;
        };
        FinderSpawnTab = true;
        NewWindowTargetIsHome = true;
        ShowRecentTags = false;
        StandardViewSettings = {
          IconViewSettings = {
            arrangeBy = "name";
            gridSpacing = 1.0;
            iconSize = 64.0;
            showItemInfo = true;
          };
        };
        WarnOnEmptyTrash = false;
      };

      "com.apple.frameworks.diskimages" = {
        skip-verify = true;
        skip-verify-locked = true;
        skip-verify-remote = true;
      };

      "com.apple.helpviewer" = {
        DevMode = true;
      };

      "com.apple.messageshelper.MessageController" = {
        SOInputLineSettings = {
          automaticEmojiSubstitutionEnablediMessage = false;
          automaticQuoteSubstitutionEnabled = false;
          continuousSpellCheckingEnabled = false;
        };
      };

      "com.apple.print.PrintingPrefs" = {
        "Quit When Finished" = true;
      };

      "com.apple.symbolichotkeys" = {
        AppleSymbolicHotKeys = {
          "21" = {
            enabled = false;
          };
          "28" = {
            enabled = false;
          };
          "29" = {
            enabled = false;
          };
          "30" = {
            enabled = false;
          };
          "31" = {
            enabled = false;
          };
          "52" = {
            enabled = false;
          };
          "59" = {
            enabled = false;
          };
          "60" = {
            enabled = true;
            value = {
              type = "standard";
              parameters = [
                32
                49
                1048576
              ];
            };
          };
          "61" = {
            enabled = false;
            value = {
              type = "standard";
              parameters = [
                32
                49
                786432
              ];
            };
          };
          "64" = {
            enabled = false;
          };
          "65" = {
            enabled = false;
          };
          "79" = {
            enabled = false;
          };
          "80" = {
            enabled = false;
          };
          "81" = {
            enabled = false;
          };
          "82" = {
            enabled = false;
          };
          "184" = {
            enabled = false;
          };
        };
      };

      "com.apple.systempreferences" = {
        NSQuitAlwaysKeepsWindows = false;
      };

      "com.apple.systemuiserver" = {
        "NSStatusItem Visible com.apple.menuextra.appleuser" = false;
        "NSStatusItem Visible com.apple.menuextra.bluetooth" = true;
        "NSStatusItem Visible com.apple.menuextra.clock" = false;
        "NSStatusItem Visible com.apple.menuextra.volume" = false;
        dontAutoLoad = [
          "/System/Library/CoreServices/Menu Extras/AirPort.menu"
          "/System/Library/CoreServices/Menu Extras/Clock.menu"
          "/System/Library/CoreServices/Menu Extras/Displays.menu"
          "/System/Library/CoreServices/Menu Extras/TimeMachine.menu"
          "/System/Library/CoreServices/Menu Extras/User.menu"
          "/System/Library/CoreServices/Menu Extras/Volume.menu"
          "/System/Library/CoreServices/Menu Extras/WWAN.menu"
        ];
      };

      "com.apple.universalaccess" = {
        HIDScrollZoomModifierMask = 262144;
      };

      NSGlobalDomain = {
        AppleLanguages = [
          "en-RU"
          "ru-RU"
        ];
        AppleLocale = "en_RU";
        QLPanelAnimationDuration = 0;
        TSMLanguageIndicatorEnabled = false;
        WebKitDeveloperExtras = true;
      };
    };
  };

  system.activationScripts.postActivation.text = ''
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode off
    /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on

    systemsetup -setrestartfreeze on 2>/dev/null || true

    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

    chflags nohidden ${homeDir}/Library
    chflags nohidden /Volumes

    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" AutoSubmit -bool false
    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" SeedAutoSubmit -bool false
    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" AutoSubmitVersion -int 4
    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" ThirdPartyDataSubmit -bool false
    defaults write "/Library/Application Support/CrashReporter/DiagnosticMessagesHistory.plist" ThirdPartyDataSubmitVersion -int 4

    defaults write /Library/Preferences/com.apple.TimeMachine AutoBackup -bool false
    defaults write /Library/Preferences/com.apple.TimeMachine MobileBackups -bool false

    defaults write /Library/Preferences/FeatureFlags/Domain/UIKit.plist redesigned_text_cursor -dict-add Enabled -bool false

    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';
}

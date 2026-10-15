#!/usr/bin/env bun
import { join } from "node:path";

const GENERATOR_URL = "https://schneegans.de/windows/unattend-generator/download/";

const accounts = [
  { name: "yoshintame", group: "Administrators" },
  { name: "ksoosha", group: "Administrators" },
];

const removedApps = [
  "3DViewer",
  "BingSearch",
  "Camera",
  "Clipchamp",
  "Copilot",
  "Cortana",
  "DevHome",
  "Family",
  "FeedbackHub",
  "GameAssist",
  "GetHelp",
  "GetStarted",
  "Handwriting",
  "InternetExplorer",
  "MailCalendar",
  "Maps",
  "MathInputPanel",
  "MixedReality",
  "News",
  "Office365",
  "OneDrive",
  "OneNote",
  "OneSync",
  "Outlook",
  "Paint3D",
  "People",
  "PowerAutomate",
  "PowerShell2",
  "PowerShellISE",
  "QuickAssist",
  "RdpClient",
  "Recall",
  "Skype",
  "Solitaire",
  "Speech",
  "StepsRecorder",
  "StickyNotes",
  "Teams",
  "ToDo",
  "VoiceRecorder",
  "Wallet",
  "Weather",
  "WindowsMediaPlayer",
  "WordPad",
  "YourPhone",
  "ZuneMusic",
  "ZuneVideo",
];

const enabledFlags = [
  "UseKeyboard2",
  "BypassNetworkCheck",
  "PauseBeforeFormatting",
  "TargetDiskNoPartitions",
  "TargetDiskInterfaceType",
  "TargetDiskMediaType",
  "TargetDiskSize",
  "ShowFileExtensions",
  "ClassicContextMenu",
  "LaunchToThisPC",
  "ShowEndTask",
  "DisableWidgets",
  "HideTaskViewButton",
  "ShowAllTrayIcons",
  "DisableBingResults",
  "DisableSac",
  "DisableFastStartup",
  "EnableLongPaths",
  "AllowPowerShellScripts",
  "DisableLastAccess",
  "PreventAutomaticReboot",
  "DisableAppSuggestions",
  "PreventDeviceEncryption",
  "HideEdgeFre",
  "DisableEdgeStartupBoost",
  "DisablePointerPrecision",
  "DeleteWindowsOld",
  "DisableWpbt",
  "PreventDeviceApps",
  "DeleteEdgeDesktopIcon",
  "IconRecycleBin",
  "EnableTransparency",
  ...removedApps.map((app) => `Remove${app}`),
];

const options: Record<string, string> = {
  LanguageMode: "Unattended",
  UILanguage: "en-US",
  Locale: "en-US",
  Keyboard: "00000409",
  Locale2: "ru-RU",
  Keyboard2: "00000419",
  GeoLocation: "227",
  WindowsEditionMode: "Generic",
  WindowsEdition: "pro",
  PEMode: "Generated",
  InstallFromMode: "Edition",
  InstallFromEdition: "pro",
  PartitionMode: "Unattended",
  TargetDiskMode: "Generated",
  TargetDiskMinSize: "1800",
  TargetDiskMaxSize: "1900",
  PartitionLayout: "GPT",
  SystemSize: "300",
  RecoveryMode: "Partition",
  RecoverySize: "1000",
  PagingFileMode: "Automatic",
  ProcessorArchitecture: "amd64",
  ComputerNameMode: "Custom",
  ComputerName: "lasthaze-gaming",
  TimeZoneMode: "Explicit",
  TimeZone: "SE Asia Standard Time",
  UserAccountMode: "Unattended",
  AutoLogonMode: "Own",
  PasswordExpirationMode: "Unlimited",
  LockoutMode: "Default",
  HideFiles: "HiddenSystem",
  TaskbarSearch: "Box",
  TaskbarIconsMode: "Empty",
  StartTilesMode: "Default",
  StartPinsMode: "Empty",
  EffectsMode: "Default",
  DesktopIconsMode: "Custom",
  StartFoldersMode: "Default",
  CoreIsolationMode: "Enabled",
  WifiMode: "Skip",
  ExpressSettings: "DisableAll",
  LockKeysMode: "Skip",
  StickyKeysMode: "Disabled",
  ColorMode: "Custom",
  SystemColorTheme: "Dark",
  AppsColorTheme: "Dark",
  AccentColor: "#0078D4",
  WallpaperMode: "Default",
  LockScreenMode: "Default",
  AppLockerMode: "Skip",
};

const params = new URLSearchParams(options);
accounts.forEach((account, index) => {
  params.set(`AccountName${index}`, account.name);
  params.set(`AccountDisplayName${index}`, "");
  params.set(`AccountPassword${index}`, "");
  params.set(`AccountGroup${index}`, account.group);
});
for (const flag of enabledFlags) params.set(flag, "true");

const response = await fetch(`${GENERATOR_URL}?${params}`);
if (!response.ok) throw new Error(`generator responded ${response.status} ${response.statusText}`);

const xml = await response.text();
if (!xml.includes("<unattend")) throw new Error("generator response is not an unattend document");

const output = join(import.meta.dir, "autounattend.xml");
await Bun.write(output, xml);
console.log(`wrote ${output}`);

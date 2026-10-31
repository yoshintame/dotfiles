{
  config,
  lib,
  myLib,
  ...
}:
let
  dir = ''C:\Windows\Cursors\macOS'';
in
myLib.mkModule config "windows-cursor" {
  windows = {
    files."${dir}\\install.ps1" = {
      text = builtins.readFile ./install.ps1;
      onChange = ''%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "${dir}\install.ps1"'';
    };

    registry.HKCU."Control Panel\\Cursors" = lib.mapAttrs (_: file: "${dir}\\${file}") {
      Arrow = "Pointer.cur";
      Help = "Help.cur";
      AppStarting = "Work.ani";
      Wait = "Busy.ani";
      Crosshair = "Cross.cur";
      IBeam = "Text.cur";
      NWPen = "Handwriting.cur";
      No = "Unavailiable.cur";
      SizeNS = "Vert.cur";
      SizeWE = "Horz.cur";
      SizeNWSE = "Dng1.cur";
      SizeNESW = "Dng2.cur";
      SizeAll = "Move.cur";
      UpArrow = "Alternate.cur";
      Hand = "Link.cur";
      Pin = "Pin.cur";
      Person = "Person.cur";
    };
  };
}

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$zip = Join-Path ([IO.Path]::GetTempPath()) 'macOS-Windows.zip'
$unpacked = Join-Path ([IO.Path]::GetTempPath()) 'macOS-cursors'
Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS-Windows.zip' -OutFile $zip
if ((Get-FileHash -Path $zip -Algorithm SHA256).Hash -ne '64A2C74780908954A2EC497F67919709280EBB8EBDF3E3B9336BAC071589C9DE') { throw 'macOS cursor archive hash mismatch' }
Expand-Archive -Path $zip -DestinationPath $unpacked -Force
Copy-Item -Path (Join-Path $unpacked 'macOS-Regular-Windows\*') -Include '*.cur', '*.ani' -Destination $PSScriptRoot -Force
Remove-Item -LiteralPath $zip, $unpacked -Recurse -Force

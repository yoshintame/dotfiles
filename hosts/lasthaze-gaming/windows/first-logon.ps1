$ErrorActionPreference = 'Stop'

$distro = 'lasthaze-gaming'
$wslBin = '/run/current-system/sw/bin'
$log = 'C:\Windows\Setup\Scripts\lasthaze-first-logon.log'
$env:WSL_UTF8 = '1'

function Write-Log([string] $Message) {
    Add-Content -Encoding utf8 -Path $log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Invoke-Native([string] $File, [string[]] $Arguments) {
    $ErrorActionPreference = 'Continue'
    & $File @Arguments 2>&1 | ForEach-Object { Add-Content -Encoding utf8 -Path $log -Value "  $_" }
    if ($LASTEXITCODE -ne 0) { throw "$File $($Arguments -join ' ') exited with $LASTEXITCODE" }
}

function Invoke-Distro([string] $User, [string[]] $Arguments) {
    Invoke-Native 'wsl.exe' (@('-d', $distro, '-u', $User, '-e') + $Arguments)
}

function Invoke-Step([string] $Name, [scriptblock] $Body) {
    Write-Log "start $Name"
    try {
        & $Body
        Write-Log "ok $Name"
    } catch {
        Write-Log "FAILED $Name`: $_"
    }
}

function Get-Media {
    $drive = Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path (Join-Path $_.Root 'lasthaze') } | Select-Object -First 1
    if (-not $drive) { throw 'no drive has a lasthaze directory' }
    Join-Path $drive.Root 'lasthaze'
}

Invoke-Step 'openssh' {
    Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' | Out-Null
    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd
    $sshDir = Join-Path $env:ProgramData 'ssh'
    $config = Join-Path $sshDir 'sshd_config'
    Set-Content -Encoding ascii -Path $config -Value (@('PasswordAuthentication no', 'KbdInteractiveAuthentication no') + (Get-Content $config))
    $keys = Join-Path $sshDir 'administrators_authorized_keys'
    Set-Content -Encoding ascii -Path $keys -Value $authorizedKeys
    Invoke-Native 'icacls.exe' @($keys, '/inheritance:r', '/grant', '*S-1-5-32-544:F', '*S-1-5-18:F')
    Restart-Service -Name sshd
    Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -RemoteAddress LocalSubnet -Action Allow | Out-Null
}

Invoke-Step 'wsl' {
    $msi = Join-Path (Get-Media) 'wsl.msi'
    $process = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$msi`"", '/qn', '/norestart', '/l*v', "`"$log.msi`"") -Wait -PassThru
    if ($process.ExitCode -notin 0, 3010) { throw "msiexec exited with $($process.ExitCode)" }
}

Invoke-Step 'distribution' {
    $installed = & { $ErrorActionPreference = 'Continue'; & wsl.exe --list --quiet 2>$null }
    if ($installed -notcontains $distro) {
        Invoke-Native 'wsl.exe' @('--install', '--from-file', (Join-Path (Get-Media) "$distro.wsl"), '--name', $distro, '--no-launch')
    }
    Invoke-Distro 'root' @("$wslBin/true")
}

Invoke-Step 'dotfiles' {
    Invoke-Distro 'yoshintame' @("$wslBin/sh", '-c', "test -d ~/.dotfiles/.git || $wslBin/git clone https://github.com/yoshintame/dotfiles.git ~/.dotfiles")
    Invoke-Distro 'root' @("$wslBin/systemctl", 'restart', 'home-manager-yoshintame.service')
}

Invoke-Step 'winget' {
    $deadline = (Get-Date).AddMinutes(30)
    while (-not (Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' | Where-Object Status -eq 'Ok')) {
        if ((Get-Date) -gt $deadline) { throw 'App Installer is not registered after 30 minutes' }
        Start-Sleep -Seconds 10
    }
    Invoke-Native "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" @('--version')
    Invoke-Native "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" @('configure', '--enable')
}

Invoke-Step 'windows-rebuild' {
    Invoke-Distro 'yoshintame' @("$wslBin/windows-rebuild", 'switch', '--winget')
}

Invoke-Step 'windows-dotfiles' {
    $repo = Join-Path $env:USERPROFILE '.dotfiles'
    if (-not (Test-Path (Join-Path $repo '.git'))) {
        Invoke-Native "$env:ProgramFiles\Git\cmd\git.exe" @('clone', 'https://github.com/yoshintame/dotfiles.git', $repo)
    }
    Invoke-Native 'icacls.exe' @($repo, '/setowner', $env:USERNAME, '/T', '/C', '/Q')
}

Invoke-Step 'tailscale' {
    $key = Join-Path (Get-Media) 'tailscale.authkey'
    if (Test-Path $key) {
        Invoke-Native "$env:ProgramFiles\Tailscale\tailscale.exe" @('up', '--unattended', "--auth-key=file:$key")
    } else {
        Write-Log '  no auth key on the media, sign in to Tailscale by hand'
    }
}

Invoke-Step 'windows-update' {
    $session = New-Object -ComObject Microsoft.Update.Session
    $found = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0 and BrowseOnly=0 and Type='Software'").Updates
    $updates = New-Object -ComObject Microsoft.Update.UpdateColl
    foreach ($update in $found) {
        if ($update.InstallationBehavior.CanRequestUserInput) {
            Write-Log "  skip, needs user input: $($update.Title)"
            continue
        }
        if (-not $update.EulaAccepted) { $update.AcceptEula() }
        [void]$updates.Add($update)
        Write-Log "  $($update.Title)"
    }
    if ($updates.Count -eq 0) { return }
    $downloader = $session.CreateUpdateDownloader()
    $downloader.Updates = $updates
    $download = $downloader.Download()
    if ($download.ResultCode -notin 2, 3) { throw "Windows Update download finished with result $($download.ResultCode)" }
    $installer = $session.CreateUpdateInstaller()
    $installer.Updates = $updates
    $result = $installer.Install()
    for ($i = 0; $i -lt $updates.Count; $i++) {
        $code = $result.GetUpdateResult($i).ResultCode
        if ($code -ne 2) { Write-Log "  result $code for $($updates.Item($i).Title)" }
    }
    Write-Log "  result $($result.ResultCode), reboot required $($result.RebootRequired)"
    if ($result.ResultCode -notin 2, 3) { throw "Windows Update finished with result $($result.ResultCode)" }
}

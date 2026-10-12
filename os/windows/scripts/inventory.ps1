$ErrorActionPreference = 'Continue'

$OutDir = Join-Path ([Environment]::GetFolderPath('Desktop')) "inventory-$env:COMPUTERNAME-$env:USERNAME"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Invoke-Step([string]$Name, [string]$Tool, [scriptblock]$Action) {
    if ($Tool -and -not (Get-Command $Tool -ErrorAction SilentlyContinue)) {
        Write-Host "[skip] ${Name}: $Tool not installed"
        return
    }
    try {
        & $Action
        Write-Host "[ok]   $Name"
    } catch {
        Write-Host "[fail] ${Name}: $_"
    }
}

function Invoke-Native([string]$Log, [scriptblock]$Command) {
    $global:LASTEXITCODE = 0
    & $Command *> (Join-Path $OutDir $Log)
    if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE, see $Log" }
}

function Export-Table([string]$File) {
    $input | Export-Csv -Path (Join-Path $OutDir $File) -NoTypeInformation -Encoding UTF8
}

Invoke-Step 'winget export' 'winget' {
    Invoke-Native 'winget-export.log' { winget export --output "$OutDir\winget.json" --include-versions --accept-source-agreements }
}

Invoke-Step 'scoop export' 'scoop' {
    Invoke-Native 'scoop.json' { scoop export }
}

Invoke-Step 'choco export' 'choco' {
    Invoke-Native 'choco-export.log' { choco export --output-file-path="$OutDir\choco.config" --include-version-numbers }
}

Invoke-Step 'installed programs (registry)' $null {
    $keys = [ordered]@{
        'machine'     = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'machine-x86' = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        'user'        = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    $keys.GetEnumerator() | ForEach-Object {
        $scope = $_.Key
        Get-ItemProperty -Path $_.Value -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.SystemComponent -ne 1 } |
            Select-Object @{ n = 'Scope'; e = { $scope } }, DisplayName, DisplayVersion, Publisher, InstallDate, InstallLocation
    } | Sort-Object DisplayName | Export-Table 'programs.csv'
}

Invoke-Step 'store apps' $null {
    Get-AppxPackage |
        Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } |
        Select-Object Name, Version, Publisher, SignatureKind |
        Sort-Object Name | Export-Table 'appx.csv'
}

Invoke-Step 'startup commands' $null {
    Get-CimInstance Win32_StartupCommand |
        Select-Object Name, Command, Location, User |
        Sort-Object Name | Export-Table 'startup.csv'
}

Invoke-Step 'local users' $null {
    Get-LocalUser | Select-Object Name, Enabled, LastLogon | Export-Table 'users.csv'
    Get-LocalGroupMember -SID 'S-1-5-32-544' | Select-Object Name, ObjectClass, PrincipalSource | Export-Table 'administrators.csv'
}

Write-Host "Inventory written to $OutDir"

$ErrorActionPreference = 'Continue'

####################################################################################
# Set up paths
####################################################################################
$HostName = [System.Net.Dns]::GetHostName()
$basePath = Join-Path $env:DOTFILES "os\windows\packages"

echo "🛳  Cruising over to $basePath"
cd $basePath

####################################################################################
# Dump from package managers
####################################################################################
echo "💿 Dumping package managers on $HostName to the $basePath directory"

# Export WinGet packages
if (winget export --output "$basePath\winget.$HostName.json" --include-versions) {
    Write-Host "✅ Exported WinGet packages"
} else {
    Write-Host "⛔️Could not export WinGet packages"
}

# Export Scoop packages
if (scoop export) {
    scoop export | Out-File "$basePath\scoop.$HostName.json"
    Write-Host "✅ Exported Scoop packages"
} else {
    Write-Host "⛔️Could not export Scoop packages"
}

# Export Chocolatey packages
if (choco export --output-file-path="$basePath\choco.$HostName.config" --include-version-numbers) {
    Write-Host "✅ Exported Chocolatey packages"
} else {
    Write-Host "⛔️Could not export Chocolatey packages"как узнать где лежит конфиг который использует  ssh
}

# Export Pip packages
if (pip freeze | Out-File "$basePath\pip.$HostName") {
    Write-Host "✅ Exported Pip packages"
} else {
    Write-Host "⛔️Could not export Pip packages"
}

# Export NPM global packages
if (npm list --global --parseable --depth=0) {
    npm list --global --parseable --depth=0 | Select-Object -Skip 1 | ForEach-Object { Split-Path $_ -Leaf } | Out-File "$basePath\npm.$HostName"
    Write-Host "✅ Exported NPM global packages"
} else {
    Write-Host "⛔️ Could not export NPM global packages"
}

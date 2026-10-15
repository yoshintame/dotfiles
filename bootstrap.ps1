param(
    [Parameter(Mandatory)] [string] $HostName,
    [switch] $Machine
)

$ErrorActionPreference = 'Stop'

$repo = Join-Path $env:USERPROFILE '.dotfiles'
$hostDir = Join-Path $repo "hosts\$HostName\windows"

function Invoke-Winget([string[]] $Arguments) {
    & winget @Arguments
    if ($LASTEXITCODE -ne 0) { throw "winget $($Arguments[0]) exited with $LASTEXITCODE" }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Invoke-Winget @('install', '--id', 'Git.Git', '-e', '--source', 'winget', '--scope', 'machine', '--accept-package-agreements', '--accept-source-agreements')
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

if (-not (Test-Path $repo)) {
    git clone https://github.com/yoshintame/dotfiles.git $repo
    if ($LASTEXITCODE -ne 0) { throw "git clone exited with $LASTEXITCODE" }
}

if ($Machine) {
    Invoke-Winget @('configure', '-f', (Join-Path $hostDir 'machine.winget'), '--accept-configuration-agreements', '--disable-interactivity')
}

Invoke-Winget @('configure', '-f', (Join-Path $hostDir "user.$env:USERNAME.winget"), '--accept-configuration-agreements', '--disable-interactivity')

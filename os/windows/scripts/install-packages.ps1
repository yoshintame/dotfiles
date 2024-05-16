Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

$ChocoPackages = @(
    'altserver.install',
    'anydesk.install',
    'autohotkey',
    'autoruns',
    'discord',
    'everything',
    'geforce-experience',
    'git',
    'lockhunter',
    'itunes',
    'msiafterburner',
    'python',
    'python3',
    'qbittorrent',
    'rufus',
    'spotify',
    'teamspeak',
    'vibrancegui',
    'visualstudiocode',
    'vlc-nightly',
    'windirstat',
    'winrar',
    'epicgameslauncher',
    'googlechrome',
    'origin',
    'steam',
    'telegram.install'
)

function InstallChocoApps($packageArray){

    Write-Host "Installing software via chocolatey"

    # Don't try to download and install a package if it shows already installed
    $InstalledChocoPackages = (Get-ChocoPackages).Name
    $packageArray = $packageArray | Where { $InstalledChocoPackages -notcontains $_ }

    if ($packageArray.Count -gt 0) {
        $packageArray | Foreach-Object {
            try {
                choco upgrade -y $_ --cacheLocation "$($env:userprofile)\AppData\Local\Temp\chocolatey" --limitoutput
            }
            catch {
                Write-Warning "Unable to install software package with Chocolatey: $($_)"
            }
        }
    }
    else {
        Write-Host 'There were no packages to install!'
    }
}

function Get-ChocoPackages {
    if (get-command clist -ErrorAction:SilentlyContinue) {
        clist -lo -r -all | Foreach {
            $Name,$Version = $_ -split '\|'
            New-Object -TypeName psobject -Property @{
                'Name' = $Name
                'Version' = $Version
            }
        }
    }
}

function PrintNotInstalledChocoPackages($packageArray){

    $InstalledChocoPackages = (Get-ChocoPackages).Name
    $NotInstalledChocoPackages = $packageArray | Where { $InstalledChocoPackages -notcontains $_ }

    if ($NotInstalledChocoPackages.Count -gt 0) {
        Write-Warning 'Following Chocolatey packages are not installed:'
        foreach ($package in $NotInstalledChocoPackages) {
            Write-Host -ForegroundColor:Red "$($package)"
        }
    }
    else {
        Write-Host -ForegroundColor:Green "All Chocolatey packages installed successfully"
    }
}

function InstallMSStorePackages($packageArray) {
    if ($packageArray.Count -gt 0) {
        $packageArray | Foreach-Object {
            try {
                winget install "$_" --source msstore --accept-source-agreements --accept-package-agreements
                # winget install -e --id StefanSundin.Superf4
            }
            catch {
                Write-Warning "Unable to install software package with Chocolatey: $($_)"
            }
        }
    }
    else {
        Write-Host 'There were no packages to install!'
    }
}

InstallChocoApps $ChocoPackages

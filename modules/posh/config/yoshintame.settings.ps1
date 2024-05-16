# set PowerShell to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# PSReadLine
Import-Module PSReadLine
Set-PSReadLineOption -EditMode Windows
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle ListView

# Fzf
Import-Module PSFzf
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'

# Env
$env:GIT_SSH = "C:\Windows\system32\OpenSSH\ssh.exe"
$env:DOTFILES = "$HOME\.dotfiles\"
$env:STARSHIP_CONFIG = "$HOME\.starship\starship.toml"
$env:STARSHIP_DISTRO = "者 xcad"

# Aliases
# Other utils
Set-Alias cat bat
Set-Alias grep findstr
Set-Alias tig 'C:\Program Files\Git\usr\bin\tig.exe'
Set-Alias less 'C:\Program Files\Git\usr\bin\less.exe'

# Cd - Zoxide
Set-Alias c z
function / { z / }
function ~ { z ~ }
function .. { z .. }
function c.. { z .. }
function ... { z ../.. }
function cd-up-three { z ../../.. }
function cd-up-four { z ../../../.. }
Set-Alias .... cd-up-three
Set-Alias .4 cd-up-three
Set-Alias ..... cd-up-four
Set-Alias .5 cd-up-four

# Ls - Eza
function l  { eza --icons --group --header --group-directories-first -a}
Set-Alias ls list
function ll { eza --icons --group --header --group-directories-first --long -a}
function lg { eza --icons --group --header --group-directories-first --long --git --git-ignore -a}
function le { eza --icons --group --header --group-directories-first --long --extended}
function lt { eza --icons --group --header --group-directories-first --tree }
function lc { eza --icons --group --header --group-directories-first --across}
function lo { eza --icons --group --header --group-directories-first --oneline}

# Git
Set-Alias g git

# Files
function cp { Copy-Item -Recurse }
function ln { New-Item -ItemType SymbolicLink }

# Openers
function edit { & cursor $args }
function ee { cursor . }
Set-Alias e edit

function open { & Invoke-Item $args }
function oo { Invoke-Item . }
Set-Alias o open

# Other
function cpwd { $pwd.Path | Set-Clipboard }

# Dotfiles
function dotapply { ~/.dotfiles/install.ps1}
function dotopen { open ~\.dotfiles\ }
function dotedit { edit $HOME\.dotfiles\ }
function dotdump { sudo $HOME\.dotfiles\os\windows\scripts\backup-packages.ps1 }

# Utilities
function which ($command) {
  Get-Command -Name $command -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Path -ErrorAction SilentlyContinue
}

# Init
Invoke-Expression (&starship init powershell)
Invoke-Expression (& { (zoxide init powershell | Out-String) })

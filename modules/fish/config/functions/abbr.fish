alias cf 'zi'
alias c 'z'
alias f="yy"
alias fc "fzf"
abbr grep="rg"
abbr cat="bat"

alias .. 'z ..'
alias ... 'z ../..'
alias .... 'z ../../..'
alias .4 'z ../../..'
alias ..... 'z ../../../..'
alias .5 'z ../../../..'
abbr / 'z /'
abbr ~ 'z ~'
abbr - 'z -'
alias c.. "z .."
alias cd.. "z .."

abbr mkdir 'mkdir -p'
abbr md 'mkdir -p'

abbr rd 'rmdir'
abbr rm 'rm -r'
abbr rmf 'rm -rf'
abbr rmrf 'rm -rf'

abbr del "trash"
abbr sdel "sudo rm -rf"

abbr cp 'cp -r'
abbr ln 'ln -s'

alias edit "cursor"
alias e "cursor"
alias ee="cursor ."
abbr o "open"
alias oo="open ."

alias cpwd='pwd | tr -d "\n" | pbcopy'

# brew
alias binst "brew install"
alias bi "brew install"

# node
abbr n "npm"
alias ninst "npm install"
alias ni "npm install"
alias nd="npm run dev"
alias ns="npm run start"
abbr nr="npm run"

abbr pn "pnpm"
alias pninst "pnpm install"
alias pni "pnpm install"
alias pnd="pnpm dev"
alias pns="pnpm start"
abbr px "pnpx"

# abbr b "bun"
alias binst "bun install"
alias bi "bun install"
alias bd="bun run dev"
alias bs="bun run start"
# abbr bx="bun exec"
# abbr br="bun run"

# python
abbr py "python"
abbr python "python3"
abbr pip "pip3"
alias pinst "pip3 install"
alias pi "pip3 install"

# network
alias ip "dig +short myip.opendns.com @resolver1.opendns.com"
alias localip "ipconfig getifaddr en0"
alias ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"
alias sniff "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump "sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""
alias lssh "grep -w -i Host ~/.ssh/config | sed s/Host//"
alias -a wget "wget -c"

# fast edit
alias edithostfile "sudo $EDITOR /etc/hosts"
alias editssh "sudo $EDITOR ~/.ssh"

# fast cd
alias dev "cd ~/Development"
alias dotfiles "cd ~/.dotfiles"

# dotfiles
alias dotapply="dotbot -c ~/.dotfiles/os/macos/module.yaml"
alias dotedit="cursor ~/.dotfiles"


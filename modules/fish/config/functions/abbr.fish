alias cf 'zi'
alias c 'z'
alias .. 'z ..'
alias ... 'z ../..'
alias .... 'z ../../..'
alias .4 'z ../../..'
alias ..... 'z ../../../..'
alias .5 'z ../../../..'
alias / 'z /'
alias ~ 'z ~'
alias - 'z -'
alias c.. "z .."
alias cd.. "z .."

abbr md 'mkdir -p'
abbr rd 'rmdir'
abbr mkdir 'mkdir -p'

abbr rm 'rm -r'
abbr rmrf 'rm -rf'

abbr cp 'cp -r'

abbr ln 'ln -s'

alias grep="grep --color"

abbr edit "cursor"
abbr e "cursor"
alias ee="cursor ."
abbr o "open"
alias oo="open ."
abbr del "trash"
abbr sdel "sudo rm -rf"
alias cpwd='pwd | tr -d "\n" | pbcopy'

# lf
abbr ld "lfcd"

# cat (bat)
alias cat="bat"

# brew
abbr binst "brew install"
abbr bi "brew install"

# node
abbr n "npm"
abbr ninst "npm install"
abbr ni "npm install"
alias nd="npm run dev"
alias ns="npm run start"
abbr nr="npm run"

abbr pn "pnpm"
abbr pninst "pnpm install"
abbr pni "pnpm install"
alias pnd="pnpm dev"
alias pns="pnpm start"
alias px "pnpx"

abbr b "bun"
abbr binst "bun install"
abbr bi "bun install"
alias bd="bun run dev"
alias bs="bun run start"
abbr bx="bun exec"
abbr br="bun run"


# python
abbr py "python"
abbr python "python3"
abbr pip "pip3"
abbr pinst "pip3 install"
abbr pi "pip3 install"

# network
abbr ip "dig +short myip.opendns.com @resolver1.opendns.com"
abbr localip "ipconfig getifaddr en0"
abbr ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"
abbr sniff "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
abbr httpdump "sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""
abbr lssh "grep -w -i Host ~/.ssh/config | sed s/Host//"
abbr -a wget "wget -c"

# fast edit
abbr edithostfile "sudo $EDITOR /etc/hosts"
abbr editssh "sudo $EDITOR ~/.ssh"

# fast cd
abbr dev "cd ~/Development"
abbr dotfiles "cd ~/.dotfiles"

# dotfiles
alias dotapply="dotbot -c ~/.dotfiles/install.conf.yaml"
alias dotedit="cursor ~/.dotfiles"

# yazi
alias f="yy"

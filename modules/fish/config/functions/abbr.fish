alias f "yy"
alias fc "fzf"
abbr grep "rg"
abbr cat "bat"

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

alias edit "$EDITOR"
alias e "$EDITOR"
alias ee "$EDITOR ."
abbr o "open"
alias oo "open ."

# brew
abbr br "brew"
alias bri "brew install"
alias brr "brew uninstall"
alias brl "brew list"
alias bru "brew upgrade"
alias brud "brew update"
alias brs "brew search"
alias brd "brew dump"

# node
abbr np "npm"
abbr npi "npm install"
abbr npr "npm uninstall"
abbr npu "npm update"
abbr npd "npm run dev"
abbr nps "npm run start"
abbr npb "npm run build"
abbr npt "npm test"
abbr npr "npm run"

abbr pn "pnpm"
abbr pni "pnpm install"
abbr pnr "pnpm remove"
abbr pnu "pnpm update"
abbr pnl "pnpm list"
abbr pnd "pnpm dev"
abbr pns "pnpm start"
abbr pnb "pnpm build"
abbr pnt "pnpm test"
abbr pnx "pnpx"

abbr bu "bun"
abbr bui "bun install"
abbr bur "bun remove"
abbr buu "bun update"
abbr bud "bun run dev"
abbr bus "bun run start"
abbr bub "bun run build"
abbr but "bun test"

# python
abbr py "python3"
abbr python "python3"
abbr pip "pip3"
alias pyi "pip3 install"

# network
alias ip "dig +short myip.opendns.com @resolver1.opendns.com"
alias localip "ipconfig getifaddr en0"
alias ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"
alias sniff "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump "sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""
alias lssh "grep -w -i Host ~/.ssh/config | sed s/Host//"
alias wget "wget -c"

# fast edit
alias edithostfile "sudo $EDITOR /etc/hosts"
alias editssh "sudo $EDITOR ~/.ssh"

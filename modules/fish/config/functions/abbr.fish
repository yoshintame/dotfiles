# utils
alias fc "fzf"
alias grep "rg"
alias cat "bat"

# file operations
alias md 'mkdir -p'
alias mf 'touch' # auto create dirs (-p)
alias ml 'ln -s'
alias ma 'ouch compress'

alias cp 'cp -Ri'
alias mv 'mv -i'

alias rd 'rmdir'
alias rm 'rm -ri'
alias rmf 'rm -rif'

alias tm 'gtrash put -v'
alias ts 'gtrash summary'
alias tf 'gtrash find'
alias tr 'gtrash restore'
alias trg 'gtrash restore-group'

alias ad 'ouch decompress'
alias al 'ouch list'

# openers
alias edit "$EDITOR"
alias e "$EDITOR"
alias ee "$EDITOR ."
alias o "open"
alias oo "open ."
alias oa 'open -a'

# brew
abbr br "brew"
abbr bri "brew install"
abbr brr "brew uninstall"
abbr brl "brew list"
abbr bru "brew upgrade"
abbr brud "brew update"
abbr brs "brew search"
abbr brd "brew dump"
abbr brup "brew update && brew upgrade && brew cleanup"

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

# docker
abbr dk "docker"
abbr dc "docker compose"

# python
abbr py "python3"
abbr python "python3"
abbr pip "pip3"
abbr pyi "pip3 install"


# network
alias ip "dig +short myip.opendns.com @resolver1.opendns.com"
alias localip "ipconfig getifaddr en0"
alias ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"
alias sniff "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
alias httpdump "sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""
alias whois "grc whois" # colorized whois

# SSH and localhost
alias hostfile 'eval sudo $EDITOR /etc/hosts'
alias editssh 'eval $EDITOR ~/.ssh'
alias lssh 'grep -w -i Host ~/.ssh/config | sed s/Host//'

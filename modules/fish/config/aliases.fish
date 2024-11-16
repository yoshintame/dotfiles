# utils
aliases add fc "fzf"
aliases add grep "rg"
aliases add cat "bat"
aliases add vim "nvim"
aliases add vi "nvim"
aliases add lg "lazygit"
aliases add ld "lazydocker"

aliases add l "eza -a --group --header --group-directories-first --git --icons --hyperlink"
aliases add lo "eza -a --group --header --group-directories-first --git --icons --oneline --hyperlink"
aliases add la "eza -a --group --header --group-directories-first --git --icons --oneline --hyperlink"
aliases add ll "eza -a --group --header --group-directories-first --git --icons --long --hyperlink"

# file operations
aliases add md 'mkdir -p'
aliases add ml 'ln -s'
aliases add ma 'ouch compress'

aliases add cp 'cp -Ri'
aliases add mv 'mv -i'

aliases add rd 'rmdir'
aliases add rm 'rm -ri'
aliases add rmf 'rm -rif'

aliases add tr 'gtrash put -v'
aliases add trs 'gtrash summary'
aliases add trf 'gtrash find'
aliases add trr 'gtrash restore'
aliases add trl 'gtrash find -n 1 --restore -f'
aliases add trg 'gtrash restore-group'

aliases add ad 'ouch decompress'
aliases add al 'ouch list'

# languages
aliases add python "python3"
aliases add pip "pip3"

# openers
aliases add edit "$EDITOR"
aliases add e "$EDITOR"
aliases add ee "$EDITOR ."
aliases add o "open"
aliases add oo "open ."
aliases add oa 'open -a'

# network
aliases add ip "dig +short myip.opendns.com @resolver1.opendns.com"
aliases add localip "ipconfig getifaddr en0"
aliases add ips "ifconfig -a | grep -o 'inet6\? \(\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\)\|[a-fA-F0-9:]\+\)' | sed -e 's/inet6* //'"
aliases add sniff "sudo ngrep -d 'en1' -t '^(GET|POST) ' 'tcp and port 80'"
aliases add httpdump "sudo tcpdump -i en1 -n -s 0 -w - | grep -a -o -E \"Host\: .*|GET \/.*\""
aliases add whois "grc whois" # colorized whois

# SSH and localhost
aliases add hostfile 'eval sudo $EDITOR /etc/hosts'
aliases add editssh 'eval $EDITOR ~/.ssh'
aliases add lssh 'grep -w -i Host ~/.ssh/config | sed s/Host//'


# grep
alias grep="grep --color"

# mkdir
alias mkdir="mkdir -p"
alias mk="mkdir -p"

# cp
alias cp="cp -r"

# cat (bat)
alias cat="bat"

# ls (eza)
alias ls="eza --group-directories-first --icons"                       # ls
alias l='eza -lbF --git --group-directories-first --icons'             # list, size, type, git
alias ll='eza -lbGF --git --group-directories-first --icons'           # long list
alias llm='eza -lbGF --git --icons --sort=modified'                    # long list, modified date sort
alias la='eza -lbhHigUmuSa --time-style=long-iso --git --color-scale --group-directories-first --icons'  # all list
alias lx='eza -lbhHigUmuSa@ --time-style=long-iso --git --color-scale --group-directories-first --icons' # all + extended list

alias lS='eza -1 --icons'			                                   # one column, just names
alias lt='eza --tree --level=2 --icons'                                # tree
alias ltt='eza --tree --level=3 --icons'                                # tree

# tree (fallback to find implementation of tree)
if [ ! -x "$(which tree 2>/dev/null)" ]
then
  alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
fi

# cd
alias ~="cd ~"           # go home directory
alias ..='cd ..'         # go up one directory
alias ...='cd ../..'     # go up two directories
alias ....='cd ../../..' # go up three directories

alias cd..="cd .."

# Open, Remove/Del and Edit shortcuts
alias o="open"
alias oo="open ."
alias oa="open -a /Applications"
alias edit="cursor"
alias e="cursor"
alias ee="cursor ."
alias del="trash"
alias sdel="sudo rm -rf"

# zip/unzip (ouch)
alias zip="ouch compress"
alias unzip="ouch decompress"
alias listzip="ouch list"

#wget
alias wget="wget -c"

# brew
alias binst="brew install"

alias cpwd='pwd | tr -d "\n" | pbcopy' # Copy the current directory to the clipboard

#lf
alias ld="lfcd"
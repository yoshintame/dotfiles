# TODO: fallback to /opt/homebrew/Cellar/fish/3.7.1/share/fish/functions/ls.fish
function ls --wraps='command ls' --wraps=eza --description 'ls as eza or grc with fallback to ls'
    if type -q eza
        eza $argv
    else if type -q grc.wrap
        set -l executable ls
        grc.wrap $executable $argv
    else if type -q grc
        command grc $argv
    else
        command ls --color=auto $argv
    end
end

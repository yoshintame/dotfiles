function brew --wraps='command brew' --description 'Wrapper for the brew command with additional functionality'
    set -l flags
    set -l args

    for arg in $argv
        switch $arg
            case '-*'
                set flags $flags $arg
            case '*'
                set args $args $arg
        end
    end

    if not test -d ~/.config/packages
        mkdir -p ~/.config/packages
    end

    if test (count $args) -gt 0
        switch $args[1]
            case 'install'
                if test (count $args) -eq 1
                    brew bundle install --cleanup --file=~/.config/packages/Brewfile --no-lock $flags
                else
                    command brew install $args[2..-1]
                    brew bundle dump --file=~/.config/packages/Brewfile --force
                end
            case 'remove'
                command brew remove $args[2..-1]
                brew bundle dump --file=~/.config/packages/Brewfile --force
            case 'dump'
                brew bundle dump --file=~/.config/packages/Brewfile --force
            case 'list'
                switch $flags
                    case '-o'
                        __brew_pretty_list
                    case '--descriptions' '-D'
                        __brew_descriptions
                    case '*'
                        command brew list $args[2..-1]
                end
            case '*'
                command brew $argv
        end
    else
        command brew
    end
end

function __brew_pretty_list --description "Show brewed formulae"
    set -l formulae (brew leaves | xargs brew deps --installed --for-each)
    set -l casks (brew list --cask 2>/dev/null)

    echo (set_color blue)"==>"(set_color --bold normal)" Formulae"(set_color normal)
    string replace -r '^(.*):(.*)$' '$1'(set_color blue)'$2'(set_color normal) $formulae
    echo
    echo (set_color blue)"==>"(set_color --bold normal)" Casks"(set_color normal)
    printf '%s\n' $casks
end

function __brew_descriptions -d 'Show descriptions of brew installs'
    brew leaves |
        xargs brew desc --eval-all |
        string replace -r '^(.*:)(\s+[^\[].*)$' '$1'(set_color blue)'$2'(set_color normal)
end

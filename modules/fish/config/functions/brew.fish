function brew
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
            case '*'
                command brew $argv
        end
    else
        command brew
    end
end

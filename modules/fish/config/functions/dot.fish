function dot
    switch $argv[1]
        case 'link'
            dotbot -c $DOTFILES_CONFIG -d $DOTFILES
        case 'go'
            cd $DOTFILES
        case 'edit'
            $EDITOR $DOTFILES
        case '*'
            echo "Usage: dot <apply|go|edit>"
    end
end

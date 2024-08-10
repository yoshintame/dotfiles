function dot --argument-names cmd --description "Dotfiles managment wrapper"
    switch "$cmd"
        case "" -h --help
            echo "Usage: dot <command>"
            echo ""
            echo "Commands:"
            echo "  link   - Run dotbot with the specified configuration"
            echo "  go     - Change directory to the dotfiles directory"
            echo "  edit   - Open the dotfiles directory in the default editor"
            echo "  help   - Display this help message"
            return 0
        case 'link'
            dotbot -c $DOTFILES_CONFIG -d $DOTFILES
        case 'go'
            cd $DOTFILES
        case 'edit'
            $EDITOR $DOTFILES
        case \*
            echo "dot: Unknown command: \"$cmd\"" >&2 && return 1
    end
end

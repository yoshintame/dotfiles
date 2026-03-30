function dot --description "Dotfiles management (mise wrapper)"
    if test (count $argv) -eq 0; or contains -- $argv[1] --help -h
        mise tasks ls 2>/dev/null | grep '^dot:'
        echo ""
        echo "Proxied from doc (nix-dotbot):"
        echo "  link     Link dotfiles via dotbot"
        echo "  config   Print dotbot config"
        return
    end
    switch $argv[1]
        case go
            cd $DOTFILES
        case link config
            doc $argv
        case '*'
            mise run dot:$argv[1] -- $argv[2..]
    end
end

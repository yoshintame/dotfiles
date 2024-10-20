function aliases
    switch $argv[1]
        case 'add'
            alias $argv[2..-1]
            funcsave -d $aliases_path $argv[2]
        case 'update'
            rm -rf $aliases_path
            source $__fish_config_dir/aliases.fish
        case 'remove'
            rm -rf $aliases_path
        case 'source'
            source $__fish_config_dir/aliases.fish
        case \*
            echo "aliases: Unknown command: \"$argv[1]\"" >&2 && return 1
    end
end

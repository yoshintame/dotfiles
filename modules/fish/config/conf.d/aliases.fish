function aliases
    switch $argv[1]
        case 'add'
            alias $argv[2..-1]
            funcsave -d $__fish_config_dir/functions/aliases $argv[2]
        case 'update'
            rm -rf $__fish_config_dir/functions/aliases
            source $__fish_config_dir/functions/aliases.fish
        case 'remove'
            rm -rf $__fish_config_dir/functions/aliases
        case 'source'
            source $__fish_config_dir/functions/aliases.fish
        case \*
            echo "aliases: Unknown command: \"$argv[1]\"" >&2 && return 1
    end
end

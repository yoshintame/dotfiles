function ssh --wraps ssh --description "ssh; offer to save a raw user@host as a manssh alias before connecting"
    # Before connecting: if the target is a bare user@host that isn't saved yet,
    # offer to save it as an alias. Interactive terminals only.
    if status is-interactive; and isatty stdin
        # Find a bare user@host target among the args (skip option flags/values).
        set -l target
        for arg in $argv
            if string match -qr -- '^[^-].*@.+' $arg
                set target $arg
                break
            end
        end

        # Prompt only for a not-yet-saved raw target.
        if test -n "$target"; and not manssh list 2>/dev/null | string match -q -- "*$target*"
            read -l -P "💾 save '$target' as ssh alias? name (empty = skip): " name
            test -n "$name"; and savessh $name $target
        end

        __sshf_log_alias $argv
    end

    command ssh $argv
end

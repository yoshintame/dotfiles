function __sshf_mru --description "Reorder sshf '<alias>\t<user@host>' rows: recently-connected aliases first, the rest in config order"
    set -l state $HOME/.local/state/sshf/last-login
    if not test -s $state
        printf '%s\n' $argv
        return
    end

    set -l order (tail -r $state 2>/dev/null | awk '!seen[$1]++{print $1}')

    for a in $order
        for r in $argv
            if test (string split -f1 \t -- $r) = $a
                printf '%s\n' $r
                break
            end
        end
    end

    for r in $argv
        if not contains -- (string split -f1 \t -- $r) $order
            printf '%s\n' $r
        end
    end
end

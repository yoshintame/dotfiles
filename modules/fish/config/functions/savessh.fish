function savessh --description "Save an ssh connection as a manssh alias (arg order doesn't matter)"
    if test (count $argv) -lt 2
        echo "Usage: savessh <alias> <user@host>   (order-agnostic)" >&2
        return 2
    end

    set -l a $argv[1]
    set -l b $argv[2]
    set -l rest $argv[3..-1]

    # The token that looks like a connection (has a user@ or a dotted host) is
    # the target; the other one is the alias name. This lets savessh accept the
    # args in either order and always call `manssh add <alias> <user@host>`.
    set -l alias
    set -l target
    if string match -qr -- '@|\.' $b
        set alias $a
        set target $b
    else if string match -qr -- '@|\.' $a
        set alias $b
        set target $a
    else
        set alias $a
        set target $b
    end

    manssh add $alias $target $rest
end

function sshf --description "Fuzzy-pick an ssh alias (fzf) and connect"
    type -q fzf; or begin
        echo "sshf: fzf not found" >&2
        return 127
    end
    type -q manssh; or begin
        echo "sshf: manssh not found" >&2
        return 127
    end

    set -l host (__sshf_pick $argv)
    test -n "$host"; or return 0
    command ssh $host
end

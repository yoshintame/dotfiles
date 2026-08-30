function sshf --description "Fuzzy-pick an ssh alias (fzf) and connect, edit, copy or open in tmux"
    type -q fzf; or begin
        echo "sshf: fzf not found" >&2
        return 127
    end
    type -q manssh; or begin
        echo "sshf: manssh not found" >&2
        return 127
    end

    set -l sel (__sshf_pick $argv)
    test -n "$sel"; or return 0

    set -l action (string split -f1 \t -- $sel)
    set -l host (string split -f2 \t -- $sel)

    switch $action
        case connect
            ssh $host
        case '*'
            __sshf_action $action $host
    end
end

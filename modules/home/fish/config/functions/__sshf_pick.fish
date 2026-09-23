function __sshf_pick --description "Fuzzy-pick an ssh alias (fzf); prints '<action>\t<alias>' where action is connect|edit|copy|tmux"
    type -q fzf; or return 1
    type -q manssh; or return 1

    set -l rows
    for alias in (manssh list 2>/dev/null | string replace -rf '^\s+(\S+)\s+->.*' '$1')
        set -l cfg (command ssh -G $alias 2>/dev/null)
        set -l user (string replace -rf '^user (.+)' '$1' -- $cfg)
        set -l host (string replace -rf '^hostname (.+)' '$1' -- $cfg)
        set -l port (string replace -rf '^port (.+)' '$1' -- $cfg)
        set -a rows "$alias"\t"$user@$host:$port"
    end
    test -n "$rows"; or return 0

    set rows (__sshf_mru $rows)

    set -l preview '__sshf_preview {}'

    set -l out (printf '%s\n' $rows \
        | column -t -s \t \
        | fzf --no-multi --height=80% --layout=reverse --info=inline \
            --prompt='ssh ❯ ' --query "$argv" \
            --expect=ctrl-e,ctrl-y,ctrl-t \
            --header 'enter connect · ctrl-e edit · ctrl-y copy · ctrl-t tmux' \
            --preview $preview --preview-window=right:45%:wrap \
        | string collect)
    test -n "$out"; or return 0

    set -l lines (string split \n -- $out)
    set -l alias (string match -r '^\S+' -- "$lines[2]")
    test -n "$alias"; or return 0

    set -l action connect
    switch "$lines[1]"
        case ctrl-e
            set action edit
        case ctrl-y
            set action copy
        case ctrl-t
            set action tmux
    end

    printf '%s\t%s\n' $action $alias
end

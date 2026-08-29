function __sshf_action --description "Perform an sshf non-connect action (edit|copy|tmux) on an alias" --argument-names action host
    switch $action
        case edit
            set -l ed $EDITOR
            test -n "$ed"; or set ed nvim
            eval $ed $HOME/.ssh/config
        case copy
            printf 'ssh %s' $host | pbcopy
        case tmux
            tmux new-window "ssh $host"
    end
end

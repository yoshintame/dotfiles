if not set -q TMUX
    and string match -q "$TERM_PROGRAM" "Apple_Terminal"

    set -g TMUX tmux new-session -d -s base
    eval $TMUX
    tmux attach-session -d -t base
end

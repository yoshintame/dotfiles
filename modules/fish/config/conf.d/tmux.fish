if not set -q TMUX
    and not string match -q "$TERM_PROGRAM" "vscode"
    and not string match -q "$TERM_PROGRAM" "WarpTerminal"

    set -g TMUX tmux new-session -d -s base
    eval $TMUX
    tmux attach-session -d -t base
end

function __sshf_log_alias --description "Record a connect to a known ssh alias (for sshf MRU sorting)"
    set -l first
    for arg in $argv
        string match -qr -- '^-' $arg; and continue
        set first $arg
        break
    end
    test -n "$first"; or return

    contains -- $first (manssh list 2>/dev/null | string replace -rf '^\s+(\S+)\s+->.*' '$1'); or return

    set -l dir $HOME/.local/state/sshf
    test -d $dir; or mkdir -p $dir
    printf '%s %s\n' $first (date +%s) >>$dir/last-login
end

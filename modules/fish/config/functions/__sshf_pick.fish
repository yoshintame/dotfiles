function __sshf_pick --description "Fuzzy-pick an ssh alias from ~/.ssh/config; prints the chosen alias"
    type -q fzf; or return 1
    type -q manssh; or return 1

    manssh list 2>/dev/null \
        | string replace -rf '^\s+(\S+)\s+->\s+(\S+).*' '$1\t$2' \
        | fzf --no-multi --height=40% --layout=reverse --info=inline \
            --delimiter=\t --with-nth=1,2 --nth=1,2 \
            --prompt='ssh ❯ ' --query "$argv" \
        | string split -f1 \t
end

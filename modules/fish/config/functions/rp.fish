function rp --description "resticprofile backup tasks (mise wrapper)"
    if test (count $argv) -eq 0; or contains -- $argv[1] --help -h
        mise tasks ls 2>/dev/null | grep '^rp:'
        return
    end
    mise run rp:$argv[1] -- $argv[2..]
end

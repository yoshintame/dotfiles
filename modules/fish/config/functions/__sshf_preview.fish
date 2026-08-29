function __sshf_preview --description "sshf preview: resolved ssh config + reachability for the highlighted row"
    set -l alias (string match -rg '^\s*(\S+)' -- $argv[1])
    test -n "$alias"; or return 0

    set -l cfg (command ssh -G $alias 2>/dev/null)
    printf '%s\n' $cfg | grep -E '^(hostname|user|port|identityfile) '
    echo

    set -l h (printf '%s\n' $cfg | string match -rg '^hostname (.+)')
    if test -n "$h"; and ping -c1 -t1 $h >/dev/null 2>&1
        echo "✅ reachable"
    else
        echo "❌ no ping"
    end
end

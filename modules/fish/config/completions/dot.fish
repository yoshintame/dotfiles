complete -c dot -f
complete -c dot -n "test (count (commandline -opc)) -eq 1" \
    -a "(mise tasks ls 2>/dev/null | grep '^dot:' | sed 's/^dot://' | awk '{print \$1\"\t\"\$2\" \"\$3\" \"\$4\" \"\$5}')"

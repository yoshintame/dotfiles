complete -c rp -f
complete -c rp -n "test (count (commandline -opc)) -eq 1" \
    -a "(mise tasks ls 2>/dev/null | grep '^rp:' | sed 's/^rp://' | awk '{print \$1\"\t\"\$2\" \"\$3\" \"\$4\" \"\$5}')"

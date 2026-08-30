function killport --description "Kill the process(es) listening on the given TCP port(s)"
    if test (count $argv) -eq 0
        echo "Usage: killport <port> [<port>...]" >&2
        return 1
    end

    set -l exit_code 0

    for port in $argv
        if not string match -qr '^[0-9]+$' -- $port
            echo "killport: '$port' is not a valid port number" >&2
            set exit_code 1
            continue
        end

        set -l pids (lsof -ti tcp:$port -sTCP:LISTEN)

        if test -z "$pids"
            echo "killport: nothing is listening on port $port"
            continue
        end

        for pid in $pids
            echo "killport: killing "(ps -p $pid -o comm= 2>/dev/null)" (PID $pid) on port $port"
        end

        kill $pids 2>/dev/null

        sleep 0.3
        set -l survivors (lsof -ti tcp:$port -sTCP:LISTEN)
        if test -n "$survivors"
            kill -9 $survivors 2>/dev/null
        end
    end

    return $exit_code
end

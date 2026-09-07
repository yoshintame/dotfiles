function sopse --description "Edit a SOPS-encrypted file in Zed (native sops EDITOR workflow)"
    if test (count $argv) -eq 0
        echo "Usage: sopse <file> [<sops-arg>...]" >&2
        return 1
    end

    if not type -q zed
        echo "sopse: zed CLI not found on PATH" >&2
        return 1
    end

    if not type -q sops
        echo "sopse: sops not found on PATH" >&2
        return 1
    end

    set -lx EDITOR 'zed --wait'
    sops $argv
end

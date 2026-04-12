function dev --description "Run dev/start script with auto-detected package manager"
    if not test -f package.json
        echo "dev: no package.json in $PWD" >&2
        return 1
    end

    if not type -q jq
        echo "dev: jq is required" >&2
        return 1
    end

    set -l pm
    if test -f bun.lock -o -f bun.lockb
        set pm bun
    else if test -f pnpm-lock.yaml
        set pm pnpm
    else if test -f yarn.lock
        set pm yarn
    else if test -f package-lock.json
        set pm npm
    else
        set pm bun
    end

    if not type -q $pm
        echo "dev: detected package manager '$pm' but it is not installed" >&2
        return 1
    end

    set -l has_dev 0
    set -l has_start 0
    test (jq -r '.scripts.dev // "null"' package.json) != "null"; and set has_dev 1
    test (jq -r '.scripts.start // "null"' package.json) != "null"; and set has_start 1

    set -l script
    if test $has_dev -eq 1 -a $has_start -eq 1
        echo "dev: both 'dev' and 'start' found, using 'dev'" >&2
        set script dev
    else if test $has_dev -eq 1
        set script dev
    else if test $has_start -eq 1
        set script start
    else
        echo "dev: neither 'dev' nor 'start' script in package.json" >&2
        return 1
    end

    echo "→ $pm run $script $argv" >&2
    $pm run $script $argv
end

# This function provides smart handling of dev/start npm scripts:
# - If neither dev nor start scripts exist - executes the original command
# - If both dev and start scripts exist - shows a warning and executes the original command
# - If only dev or start script exists - runs the existing script regardless of the original command
function run_pnpm_run_dev_or_start
    if not test -f package.json
        command pnpm run start
        return
    end

    set -l has_dev (test (jq -r '.scripts.dev' package.json) != "null")
    set -l has_start (test (jq -r '.scripts.start' package.json) != "null")

    if test $has_dev -a $has_start
        echo "Warning: Both 'dev' and 'start' scripts found in package.json"
        command pnpm $argv
    else if test $has_dev
        command pnpm run dev
    else if test $has_start
        command pnpm run start
    else
        echo "Warning: Neither 'dev' nor 'start' scripts found in package.json"
        command pnpm $argv
    end
end

function pnpm --wraps='command pnpm' --description 'Wrapper for the pnpm command with additional functionality'
    switch (count $argv)
        case 1
            switch $argv[1]
                case 'start' 'dev'
                    run_pnpm_run_dev_or_start $argv
                case '*'
                    command pnpm $argv
            end
        case '*'
            if test $argv[1] = 'run'
                switch $argv[2]
                    case 'start' 'dev'
                        run_pnpm_run_dev_or_start $argv
                    case '*'
                        command pnpm $argv
                end
            else
                command pnpm $argv
            end
    end
end

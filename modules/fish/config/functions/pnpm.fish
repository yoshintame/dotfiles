function run_pnpm_run_dev_or_start
    if not test -f package.json
        command pnpm run start
        return
    end

    if test (jq -r '.scripts.start' package.json) != "null"
        command pnpm run start
    else if test (jq -r '.scripts.dev' package.json) != "null"
        command pnpm run dev
    else
        echo "Neither 'start' nor 'dev' scripts are found in package.json"
        return 1
    end
end

function pnpm --wraps='command pnpm' --description 'Wrapper for the brew command with additional functionality'
    switch (count $argv)
        case 1
            switch $argv[1]
                case 'start' 'dev'
                    run_pnpm_run_dev_or_start
                case '*'
                    command pnpm $argv
            end
        case '*'
            if test $argv[1] = 'run'
                switch $argv[2]
                    case 'start' 'dev'
                        run_pnpm_run_dev_or_start
                    case '*'
                        command pnpm $argv
                end
            else
                command pnpm $argv
            end
    end
end

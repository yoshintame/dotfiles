function brsi
    set query $argv[1]

    if test -z "$query"
        echo "Error: Please provide a search query"
        return 1
    end

    set test (brew search $query | grep -v '^$' | fzf --prompt="Select a package to install: ")

    if test -z "$test"
        echo "No package selected"
        return 1
    end

    brew install $test
end

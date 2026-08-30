function ms --wraps='command touch' --description 'Create file and directories if they do not exist'
    set -l path $argv[1]
    set -l dir (dirname $path)
    if not test -d $dir
        mkdir -p $dir
        if test $status -ne 0
            return 1
        end
    end
    if string match -r '/$' $path
        mkdir -p $path
    else
        touch $path
    end
end

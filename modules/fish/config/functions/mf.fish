function mf --wraps='command touch' --description 'Create file and directories if they do not exist'
    set -l dir (dirname $argv[1])
    if not test -d $dir
        mkdir -p $dir
    end
    touch $argv[1]
end

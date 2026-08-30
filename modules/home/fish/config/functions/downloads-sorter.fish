function downloads-sorter --description 'Sorts downloads by date added'
    set downloads_dir ~/Downloads

    for f in $downloads_dir/*
        set date_added (mdls -raw -name kMDItemDateAdded $f 2>/dev/null)
        if test -z "$date_added"
            continue
        end

        set date_str (date -j -f "%Y-%m-%d %H:%M:%S %z" (string replace -r "T|Z" " " $date_added | string trim) "+%Y%m%d%H%M.%S")

        touch -t $date_str $f
    end
end

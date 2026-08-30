function lg --description "Run lazygit and cd to the directory it returns"
    set LAZYGIT_NEW_DIR_FILE ~/.lazygit/newdir

    lazygit $argv

    if test -f $LAZYGIT_NEW_DIR_FILE
        cd (cat $LAZYGIT_NEW_DIR_FILE)
        rm -f $LAZYGIT_NEW_DIR_FILE > /dev/null
    end
end

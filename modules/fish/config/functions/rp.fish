function rp --description "resticprofile backup tasks (just wrapper)"
    if test "$argv[1]" = save
        just -f ~/.config/resticprofile/justfile save (pwd)
    else if test "$argv[1]" = load
        if contains -- --no-clean $argv
            just -f ~/.config/resticprofile/justfile load (pwd) false
        else
            just -f ~/.config/resticprofile/justfile load (pwd)
        end
    else
        just -f ~/.config/resticprofile/justfile $argv
    end
end

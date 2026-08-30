if test -d "$HOMEBREW_PREFIX/share/fish/completions"
    set --append fish_complete_path "$HOMEBREW_PREFIX/share/fish/completions"
end

set -q MANPATH || set -gx MANPATH ''
set -q HOMEBREW_KEG_ONLY_APPS || set -U HOMEBREW_KEG_ONLY_APPS ruby curl sqlite
for app in $HOMEBREW_KEG_ONLY_APPS
    if test -d "$HOMEBREW_PREFIX/opt/$app/share/man"
        set MANPATH "$HOMEBREW_PREFIX/opt/$app/share/man" $MANPATH
    end
end

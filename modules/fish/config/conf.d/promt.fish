if not status --is-interactive
    exit
end

set fish_greeting

if type -q starship
    starship init fish | source
else
    echo "Warning: starship is not installed"
end

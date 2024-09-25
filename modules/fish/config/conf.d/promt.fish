if not status --is-interactive
    exit
end

# Disable new user greeting.
set fish_greeting

# Check if starship is installed
if type -q starship
    # Initialize starship
    cachecmd starship init fish | source
else
    echo "Warning: starship is not installed"
end

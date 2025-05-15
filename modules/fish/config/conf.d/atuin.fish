if type -q atuin
    atuin init fish --disable-up-arrow | source
else
    echo "Warning: atuin is not installed"
end


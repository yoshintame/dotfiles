if type -q mise
    set -gx MISE_ENV_FILE .env
    set -gx MISE_FISH_AUTO_ACTIVATE 0
    mise activate fish | source
else
    echo "Warning: mise is not installed"
end


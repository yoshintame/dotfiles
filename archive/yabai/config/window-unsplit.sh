#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"
if [ "$(yabai -m query --spaces --space | jq '.index')" -ne 1 ]
then
    if [ "$(yabai -m query --spaces --space | jq '.windows | length')" -le 2 ]
    then
        yabai -m space --destroy
    else
        yabai -m window --space first;
    fi
fi





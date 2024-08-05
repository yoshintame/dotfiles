#!/bin/bash
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"

index=$(yabai -m query --spaces --space | jq '.index')

if [ "$index" -eq 1 ]
then
    yabai -m space --create
    yabai -m window --space last
    yabai -m space --focus last
fi

yabai -m signal --add label=active-split-pending event=window_focused \
    action="/Users/yoshintame/yabai/scripts/window-split-signal.sh"

setKMVar() {
    osascript -l JavaScript -e "function run(argv) \
    {Application('Keyboard Maestro Engine') \
    .setvariable('$1', {to:'$2'})}"
}

setKMVar "yabaiSplit" "true"




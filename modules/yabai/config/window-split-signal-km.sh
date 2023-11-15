#!/bin/bash

# osascript -e "tell application \"Keyboard Maestro Engine\" to do script \"notify\""

yabai -m signal --remove active-split-pending
yabai -m window $YABAI_WINDOW_ID --space "$1"
yabai -m space --focus "$1"

# osascript -e "tell application \"Keyboard Maestro Engine\" to do script \"notif\""

setKMVar() {
    osascript -l JavaScript -e "function run(argv) \
    {Application('Keyboard Maestro Engine') \
    .setvariable('$1', {to:'$2'})}"
}

setKMVar "yabaiSplit" "false"



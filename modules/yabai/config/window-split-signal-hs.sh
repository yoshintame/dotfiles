#!/bin/bash

yabai -m signal --remove active-split-pending
yabai -m window $YABAI_WINDOW_ID --space "$1"
yabai -m space --focus "$1"

hs -c "yabaidirectcall.set_yabai_pending_to_false()"

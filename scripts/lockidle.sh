#!/bin/bash

if pgrep -x "swaylock" > /dev/null; then
    systemctl suspend
else
    swaylock
fi

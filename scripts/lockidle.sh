#!/bin/bash

if pgrep -x "hyprlock" > /dev/null; then
    
    systemctl suspend
else
    hyprlock
fi

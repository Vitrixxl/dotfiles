#!/bin/bash



C=$(echo -e "logout\nsleep\nshutdown"  | rofi -dmenu theme"/home/vitrix/.config/rofi/config.rasi")

case "$C" in 
  "logout")
    exit
    ;;
  "sleep")
     systemctl suspend
    ;;
  "shutdown")
     shutdown now
    ;;
esac



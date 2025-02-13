#!/bin/bash
        C2=$(echo -e "region (copy)\nregion (save)\nwindow (copy)\nwindow (save)" | rofi -dmenu -theme "/home/vitrix/.config/rofi/config.rasi")
        case "$C2" in 
            "region (copy)")
                grim -g "$(slurp)" - | wl-copy
                ;;
            "region (save)")
                grim -g "$(slurp)"
                ;;
            "window (copy)")
              sleep 0.2
                grim - | wl-copy
                ;;
            "window (save)")
              sleep 0.2
                grim  
                ;;
        esac





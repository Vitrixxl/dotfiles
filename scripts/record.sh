#!/bin/bash

# Obtenir la liste des écrans
screens=$(wlr-randr | grep -v "^$" | grep -v "Enabled")
screen_count=$(echo "$screens" | wc -l)
QUALITY_OPTS="-c libx264 -r 60 -p slower -b 15M"

FILEPATH="/home/$USER/Videos/capture/$(date +%s).mp4"
mkdir -p "/home/$USER/Videos/capture"

if [ "$screen_count" -gt 1 ]; then
    # Créer la liste des écrans pour rofi
    screen_list=$(wlr-randr | grep -v "^$" | grep -v "Enabled" | awk '{print $1}')
    
    # Premier menu rofi pour sélectionner l'écran
    selected_screen=$(echo "$screen_list" | rofi -dmenu -theme "/home/vitrix/.config/rofi/config.rasi")
    
    if [ ! -z "$selected_screen" ]; then
        # Deuxième menu rofi pour le type d'enregistrement
        C2=$(echo -e "region\nfull screen" | rofi -dmenu -theme "/home/vitrix/.config/rofi/config.rasi")
        
        case "$C2" in 
            "region")
                notify-send "Recording" "Recording has started"
                wf-recorder -a $QUALITY_OPTS  $FILEPATH -o "$selected_screen" -g "$(slurp)"
                ;;
            "full screen")
                notify-send "Recording" "Recording has started"
                wf-recorder -a $QUALITY_OPTS -f $FILEPATH -o "$selected_screen"
                ;;
        esac
    fi
else
    # S'il n'y a qu'un seul écran, montrer directement le menu des options
    default_screen=$(echo "$screens" | awk '{print $1}')
    C2=$(echo -e "region\nfull screen" | rofi -dmenu -theme "/home/vitrix/.config/rofi/config.rasi")
    
    case "$C2" in 
        "region")
            notify-send "Recording" "Recording has started"
            wf-recorder -a  $QUALITY_OPTS -f $FILEPATH -o "$default_screen" -g "$(slurp)"
            ;;
        "full screen")
            notify-send "Recording" "Recording has started"
            wf-recorder -a $QUALITY_OPTS -f $FILEPATH -o "$default_screen"
            ;;
    esac
fi

echo "file://$FILEPATH" | wl-copy --type text/uri-list
notify-send "Recording" "The recording has been stopped"

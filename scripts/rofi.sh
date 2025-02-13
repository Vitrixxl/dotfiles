#!/bin/bash

# Fonction pour récupérer les fenêtres et les formater pour rofi
get_windows() {
    # Récupère la liste des clients au format JSON
    windows=$(hyprctl clients -j)
    
    # Utilise jq pour parser le JSON et extraire les informations nécessaires
    echo "$windows" | jq -r '.[] | select(.mapped==true) | "\(.initialTitle):\(.address)"'
}

# Récupère la liste des fenêtres
window_list=$(get_windows)

# Prépare la liste pour rofi (uniquement les titres)
rofi_list=$(echo "$window_list" | cut -d':' -f1)

# Affiche rofi avec la liste des fenêtres
selected=$(echo "$rofi_list" | rofi \
    -modi "dmenu" \
    -dmenu \
    -i \
    -p " " \
    -theme /home/vitrix/.config/rofi/config.rasi)

# Si une fenêtre a été sélectionnée
if [ ! -z "$selected" ]; then
    # Récupère l'adresse correspondante au titre sélectionné
    address=$(echo "$window_list" | grep "^$selected:" | cut -d':' -f2)
    
    # Focus sur la fenêtre sélectionnée
    if [ ! -z "$address" ]; then
        hyprctl dispatch focuswindow "address:$address"
    fi
fi

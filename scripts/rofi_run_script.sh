#!/bin/bash

SCRIPT_DIR="$(dirname "$(realpath "$0")")"

# Créer une liste des scripts exécutables dans le répertoire du script
declare -A SCRIPTS_MAP
for script_path in "$SCRIPT_DIR"/*.sh; do
    if [[ -x "$script_path" && -f "$script_path" && "$script_path" != "$0" ]]; then
        script_name=$(basename "${script_path%.sh}")
        SCRIPTS_MAP["$script_name"]="$script_path"
    fi
done

# Vérifier qu'il y a des scripts à afficher
if [[ ${#SCRIPTS_MAP[@]} -eq 0 ]]; then
    echo "Aucun script exécutable trouvé dans $SCRIPT_DIR."
    exit 1
fi

# Afficher les noms des scripts dans rofi
script_choice=$(printf '%s\n' "${!SCRIPTS_MAP[@]}" | rofi -dmenu -p " " -theme "/home/vitrix/.config/rofi/config.rasi")

# Vérifier si une sélection a été faite
if [[ -n "$script_choice" ]]; then
    # Exécuter le script sélectionné
    "${SCRIPTS_MAP[$script_choice]}"
fi

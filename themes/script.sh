#!/bin/bash
theme=$(ls -d $HOME/.dotfiles/themes/*/ | xargs -n 1 basename | rofi -dmenu -no-show-icons -theme $HOME/.config/rofi/config.rasi)

if [[ -z "$theme" ]]; then
  exit 0
fi
cp -f "$HOME/.dotfiles/themes/$theme/hyprpaper/newbg.png" "$HOME/.config/hypr/bg.png"
cp -f "$HOME/.dotfiles/themes/$theme/waybar/style.css" "$HOME/.config/waybar/style.css"
cp -f "$HOME/.dotfiles/themes/$theme/rofi/color.rasi" "$HOME/.config/rofi/color.rasi"
cp -f "$HOME/.dotfiles/themes/$theme/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"


kill -SIGUSR1 $(pgrep kitty)
pkill hyprpaper 
nohup hyprpaper > /dev/null 2>&1 &


  

#!/bin/bash

rm -rf $HOME/.config/hypr
rm -rf $HOME/.config/nvim
rm -rf $HOME/.scripts
rm -rf $HOME/.config/swaylock
rm -rf $HOME/.config/waybar
rm -rf $HOME/.config/rofi

ln -sf $HOME/dotfiles/zshrc $HOME/.zshrc
ln -sf $HOME/dotfiles/tmux.conf $HOME/.tmux.conf

ln -sf  $HOME/dotfiles/config/hypr $HOME/.config/
ln -sf  $HOME/dotfiles/config/rofi $HOME/.config/
ln -sf  $HOME/dotfiles/config/nvim $HOME/.config/
ln -sf  $HOME/dotfiles/config/waybar $HOME/.config/
ln -sf  $HOME/dotfiles/config/swaylock $HOME/.config/
mkdir -p $HOME/.scripts
ln -sf $HOME/dotfiles/scripts/* $HOME/.scripts/


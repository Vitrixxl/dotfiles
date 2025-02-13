#!/bin/bash

rm -rf $HOME/.config/hypr
rm -rf $HOME/.config/nvim

ln -sf $HOME/.dotfiles/zshrc $HOME/.zshrc
ln -sf $HOME/.dotfiles/tmux.conf $HOME/.tmux.conf

ln -sf $HOME/.dotfiles/config/hypr $HOME/.config/
ln -sf $HOME/.dotfiles/config/nvim $HOME/.config/

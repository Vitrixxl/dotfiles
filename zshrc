fortune | cowsay -f small
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi



  # ... (ASCII art and other configurations)

  # Initialize Zinit
  ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
  if [ ! -d "$ZINIT_HOME" ]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
  fi

  source "${ZINIT_HOME}/zinit.zsh"

  # Modify PATH correctly
  export PATH="$HOME/.local/share/pnpm:$PATH"
  export PATH="$HOME/.config/rofi/script:$PATH" 
  export PATH="/var/lib/flatpak/exports/share/applications:$PATH"
  export PATH="$HOME/.script:$PATH"
  export PATH="/usr/local/go/bin:$PATH"  # Append to PATH, don't overwrite
  export PATH="$HOME/.cargo/bin:$PATH"
  export PATH="/home/vitrix/.bun/bin:$PATH"
  export PATH="$HOME/.flutter/flutter/bin:$PATH"
  export PATH="/home/vitrix/.flutter/flutter/bin:$PATH"
  export PATH="/home/vitrix/.postman/Postman/Postman:$PATH"


  export BROWSER="firefox"

  # Zinit plugins
  zinit ice depth=1; zinit light romkatv/powerlevel10k
  zinit light zsh-users/zsh-syntax-highlighting
  zinit light zsh-users/zsh-completions
  zinit light zsh-users/zsh-autosuggestions
  zinit light Aloxaf/fzf-tab

  autoload -U compinit && compinit

  # Powerlevel10k configuration
  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

  # History settings
  HISTSIZE=5001
  HISTFILE=~/.zsh_history
  SAVEHIST=$HISTSIZE
  HISTDUP=erase
  setopt appendhistory
  setopt sharehistory
  setopt hist_ignore_space
  setopt hist_ignore_all_dups
  setopt hist_save_no_dups
  setopt hist_ignore_dups

  # Completion styles
  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
  zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
  zstyle ':completion:*' menu no
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

  # Aliases
  alias ls='ls --color'
  alias nv='nvim'
  alias sm='soundmixer.sh'
  alias setnvim='setnvimup.sh'

  # Homebrew initialization
  # eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

  # Initialize fzf if available
  if command -v fzf &> /dev/null; then
    source <(fzf --zsh)
  else
    echo "fzf not found in \$PATH during initialization."
  fi

  # Node Version Manager (nvm) initialization
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


  # pnpm
  export PNPM_HOME="/home/vitrix/.local/share/pnpm"
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
  # pnpm end

set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
export PATH="$PATH:$(go env GOPATH)/bin"
export PATH="$HOME/.local/bin:$PATH"
if status is-interactive
    fastfetch
end
if status is-interactive; and test -f ~/dev/hour/main.ts
    bun run ~/dev/hour/main.ts
end
if status is-interactive
    # Commands to run in interactive sessions can go here
end

# bun

# NVM: initialize the current directory as well as subsequent directory changes.
set -gx NVM_DIR "$HOME/.nvm"
load_nvm

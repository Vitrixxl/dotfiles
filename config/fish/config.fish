set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
export PATH="$PATH:$(go env GOPATH)/bin"
export PATH="$HOME/.local/bin:$PATH"
fastfetch
bun run ~/dev/hour/main.ts
if status is-interactive
    # Commands to run in interactive sessions can go here
end

# bun

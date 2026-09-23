function nvm --description 'Node Version Manager through Bass'
    set -gx NVM_DIR "$HOME/.nvm"
    set -e __spinal_nvm_request
    bass source "$NVM_DIR/nvm.sh" --no-use ';' nvm $argv
end

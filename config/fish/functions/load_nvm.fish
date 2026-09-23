function load_nvm --description 'Select Node from .nvmrc or the default alias' --on-variable PWD
    set -l dir "$PWD"
    set -l requested default
    while true
        if test -f "$dir/.nvmrc"
            set requested (string trim < "$dir/.nvmrc")
            break
        end
        if test "$dir" = /
            break
        end
        set dir (path dirname "$dir")
    end
    if not set -q __spinal_nvm_request; or test "$__spinal_nvm_request" != "$requested"; or not set -q NVM_BIN
        if nvm use --silent "$requested"
            set -g __spinal_nvm_request "$requested"
        end
    end
end

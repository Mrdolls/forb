#!/bin/bash

# Configuration
RAW_URL="https://raw.githubusercontent.com/Mrdolls/forb/main/forb.sh"
INSTALL_DIR="$HOME/.forb"
BIN_PATH="$INSTALL_DIR/forb.sh"
COMPLETION_FILE="$INSTALL_DIR/forb_completion.sh"

C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_RESET='\033[0m'

main() {
    clear
    echo -e "${C_BLUE}Starting ForbCheck Installation...${C_RESET}"
    mkdir -p "$INSTALL_DIR"
    echo -e "Downloading ForbCheck..."
    curl -sL "$RAW_URL" -o "$BIN_PATH"
    chmod +x "$BIN_PATH"
    cat << 'EOF' > "$COMPLETION_FILE"
_forb_completion() {
    local cur opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    opts="-v -f -p -a -t -up -e -l -mlx -lm --remove --no-auto"

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}
complete -F _forb_completion forb
EOF
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)   SHELL_CONFIG="$HOME/.zshrc" ; IS_ZSH=true ;;
        bash)  SHELL_CONFIG="$HOME/.bashrc" ; IS_ZSH=false ;;
        *)     SHELL_CONFIG="$HOME/.profile" ; IS_ZSH=false ;;
    esac

    if ! grep -q "alias forb=" "$SHELL_CONFIG"; then
        echo -e "\n# ForbCheck\nalias forb='bash $BIN_PATH'" >> "$SHELL_CONFIG"
    fi
    if ! grep -q "forb_completion.sh" "$SHELL_CONFIG"; then
        if [ "$IS_ZSH" = true ]; then
            echo "autoload -U +X compinit && compinit" >> "$SHELL_CONFIG"
            echo "autoload -U +X bashcompinit && bashcompinit" >> "$SHELL_CONFIG"
        fi
        echo "source $COMPLETION_FILE" >> "$SHELL_CONFIG"
    fi

    echo -e "\n${C_GREEN}✔ ForbCheck installed successfully!${C_RESET}"
    echo -e "Please run: ${C_BLUE}source $SHELL_CONFIG${C_RESET} to finish."
}

main

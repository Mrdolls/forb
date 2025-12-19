#!/bin/bash

REPO_URL="https://github.com/Mrdolls/forb.git"
INSTALL_DIR="$HOME/.forb"

C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

main() {
    echo -e "${C_BLUE}Welcome to the ForbCheck installer!${C_RESET}"

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "Updating ForbCheck..."
        cd "$INSTALL_DIR" && git pull > /dev/null 2>&1
    else
        echo -e "Cloning ForbCheck..."
        git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1
    fi

    # Shell config detection
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)   SHELL_CONFIG="$HOME/.zshrc" ;;
        bash)  SHELL_CONFIG="$HOME/.bashrc" ;;
        *)     SHELL_CONFIG="$HOME/.profile" ;;
    esac

    # Alias configuration
    ALIAS_CMD="alias forb='bash $INSTALL_DIR/forb.sh'"
    if ! grep -qF "alias forb=" "$SHELL_CONFIG"; then
        echo -e "\n# Alias for ForbCheck" >> "$SHELL_CONFIG"
        echo "$ALIAS_CMD" >> "$SHELL_CONFIG"
    fi

    echo -e "${C_GREEN}✔ Installation successful!${C_RESET}"
    echo -e "Restart your terminal or run: ${C_BLUE}source $SHELL_CONFIG${C_RESET}"
}

main

#!/bin/bash

# --- CONFIGURATION ---
REPO_URL="https://github.com/Mrdolls/forb.git" # Ton URL Git
INSTALL_DIR="$HOME/.forb"
COMMAND_NAME="forb"

# --- COULEURS ---
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_RESET='\033[0m'

main() {
    echo -e "${C_BLUE}Installing ForbCheck...${C_RESET}"

    # 1. CLONAGE OU UPDATE
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "Updating ForbCheck..."
        cd "$INSTALL_DIR" && git pull > /dev/null 2>&1
    else
        echo -e "Cloning ForbCheck..."
        git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1
    fi

    # 2. CONFIGURATION SHELL
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)   SHELL_CONFIG="$HOME/.zshrc" ;;
        bash)  SHELL_CONFIG="$HOME/.bashrc" ;;
        *)     SHELL_CONFIG="$HOME/.profile" ;;
    esac

    # 3. ALIAS (Pointant vers le fichier dans .forb)
    ALIAS_COMMAND="alias $COMMAND_NAME='bash $INSTALL_DIR/forb.sh'"
    if ! grep -qF "$ALIAS_COMMAND" "$SHELL_CONFIG"; then
        echo -e "\n# Alias for ForbCheck" >> "$SHELL_CONFIG"
        echo "$ALIAS_COMMAND" >> "$SHELL_CONFIG"
    fi

    echo -e "${C_GREEN}✔ Installation successful! Restart your terminal or run 'source $SHELL_CONFIG'${C_RESET}"
}

main

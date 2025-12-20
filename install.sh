#!/bin/bash

REPO_URL="https://github.com/Mrdolls/forb.git"
INSTALL_DIR="$HOME/.forb"

C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'
C_RESET='\033[0m'

main() {
    clear
    echo -e "${C_BLUE}Welcome to the ForbCheck installer!${C_RESET}"

    # 1. CLONAGE OU MISE À JOUR FORCÉE
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${C_YELLOW}Existing directory found. Forcing update to the latest version...${C_RESET}"
        cd "$INSTALL_DIR" || exit 1
        # On récupère les données sans fusionner
        git fetch origin main > /dev/null 2>&1
        # On force l'alignement sur le repo distant (écrase tout le local)
        git reset --hard origin/main > /dev/null 2>&1
        echo -e "${C_GREEN}✔ ForbCheck updated successfully.${C_RESET}"
    else
        echo -e "Cloning the tool..."
        git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1
        echo -e "${C_GREEN}✔ ForbCheck installed in $INSTALL_DIR.${C_RESET}"
    fi

    # 2. CONFIGURATION DU SHELL
    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)   SHELL_CONFIG="$HOME/.zshrc" ;;
        bash)  SHELL_CONFIG="$HOME/.bashrc" ;;
        *)     SHELL_CONFIG="$HOME/.profile" ;;
    esac

    # 3. ALIAS
    # On utilise des doubles quotes pour permettre l'expansion de $INSTALL_DIR
    ALIAS_CMD="alias forb='bash $INSTALL_DIR/forb.sh'"
    
    # Nettoyage et ajout propre de l'alias
    if ! grep -qF "alias forb=" "$SHELL_CONFIG"; then
        echo -e "\n# Alias for ForbCheck" >> "$SHELL_CONFIG"
        echo "$ALIAS_CMD" >> "$SHELL_CONFIG"
        echo -e "${C_GREEN}✔ Alias 'forb' added to $SHELL_CONFIG.${C_RESET}"
    else
        # Si l'alias existe déjà, on s'assure qu'il pointe au bon endroit
        sed -i "/alias forb=/c\\$ALIAS_CMD" "$SHELL_CONFIG"
        echo -e "${C_GREEN}✔ Alias 'forb' verified/updated.${C_RESET}"
    fi

    echo -e "\n${C_GREEN}All done!${C_RESET}"
    echo -e "Please run: ${C_BLUE}source $SHELL_CONFIG${C_RESET} to refresh your terminal."
}

main

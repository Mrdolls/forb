#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/.forb"
echo -e "${BLUE}Installing forb tool to $INSTALL_DIR...${NC}"

mkdir -p "$INSTALL_DIR"
cp forb.sh "$INSTALL_DIR/forb.sh"
cp authorize.txt "$INSTALL_DIR/authorize.txt"
chmod +x "$INSTALL_DIR/forb.sh"
SHELL_CONFIG=""
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

ALIAS_LINE="alias forb='bash $INSTALL_DIR/forb.sh'"

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "$ALIAS_LINE" "$SHELL_CONFIG"; then
        echo "$ALIAS_LINE" >> "$SHELL_CONFIG"
        echo -e "${GREEN}Alias added to $SHELL_CONFIG${NC}"
    else
        echo -e "Alias already exists in $SHELL_CONFIG"
    fi
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "Please restart your terminal or run: ${BLUE}source $SHELL_CONFIG${NC}"

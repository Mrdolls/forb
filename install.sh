#!/bin/bash

# --- COLORS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/.forb"
REPO_URL="https://raw.githubusercontent.com/Mrdolls/forb/main"

echo -e "${BLUE}[ℹ] Installing ForbCheck to $INSTALL_DIR...${NC}"

# 1. Create directory
mkdir -p "$INSTALL_DIR"

# 2. Download files from GitHub
echo -e "${BLUE}[ℹ] Downloading files...${NC}"

curl -fsSL "$REPO_URL/forb.sh" -o "$INSTALL_DIR/forb.sh"
if [ $? -ne 0 ]; then echo -e "${RED}✘ Error downloading forb.sh${NC}"; exit 1; fi

curl -fsSL "$REPO_URL/authorize.txt" -o "$INSTALL_DIR/authorize.txt"
if [ $? -ne 0 ]; then echo -e "${RED}✘ Error downloading authorize.txt${NC}"; exit 1; fi

chmod +x "$INSTALL_DIR/forb.sh"

# 3. Alias setup
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

ALIAS_LINE="alias forb='bash $INSTALL_DIR/forb.sh'"

if [ -n "$SHELL_CONFIG" ]; then
    if ! grep -q "alias forb=" "$SHELL_CONFIG"; then
        echo "$ALIAS_LINE" >> "$SHELL_CONFIG"
        echo -e "${GREEN}[✔] Alias added to $SHELL_CONFIG${NC}"
    else
        # Update alias if it exists but might be wrong
        sed -i "/alias forb=/c\\$ALIAS_LINE" "$SHELL_CONFIG"
        echo -e "${GREEN}[✔] Alias updated in $SHELL_CONFIG${NC}"
    fi
fi

echo -e "${GREEN}Installation complete!${NC}"
echo -e "Please restart your terminal or run: ${BLUE}source $SHELL_CONFIG${NC}"

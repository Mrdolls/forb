#!/bin/bash

# --- COLORS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# --- CONFIGURATION ---
# Remplace bien l'URL si ton dépôt n'est pas sur la branche 'main'
INSTALL_DIR="$HOME/.forb"
REPO_URL="https://raw.githubusercontent.com/Mrdolls/forb/main"

echo -e "${BLUE}[ℹ] Installing ForbCheck to $INSTALL_DIR...${NC}"

# 1. Création du dossier
mkdir -p "$INSTALL_DIR"

# 2. Téléchargement des fichiers depuis GitHub
echo -e "${BLUE}[ℹ] Downloading files from repository...${NC}"

# Téléchargement du script principal
curl -fsSL "$REPO_URL/forb.sh" -o "$INSTALL_DIR/forb.sh"
if [ $? -ne 0 ]; then 
    echo -e "${RED}✘ Error: Could not download forb.sh from $REPO_URL${NC}"
    exit 1
fi

# Téléchargement de la liste de fonctions
curl -fsSL "$REPO_URL/authorize.txt" -o "$INSTALL_DIR/authorize.txt"
if [ $? -ne 0 ]; then 
    echo -e "${RED}✘ Error: Could not download authorize.txt${NC}"
    exit 1
fi

# Droits d'exécution
chmod +x "$INSTALL_DIR/forb.sh"

# 3. Configuration de l'Alias
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
fi

ALIAS_LINE="alias forb='bash $INSTALL_DIR/forb.sh'"

if [ -n "$SHELL_CONFIG" ]; then
    # On nettoie les anciens alias pour éviter les doublons et on ajoute le nouveau
    sed -i '/alias forb=/d' "$SHELL_CONFIG"
    echo "$ALIAS_LINE" >> "$SHELL_CONFIG"
    echo -e "${GREEN}[✔] Alias set in $SHELL_CONFIG${NC}"
fi

echo -e "--------------------------------------------------"
echo -e "${GREEN}Installation complete!${NC}"
echo -e "Please run: ${BLUE}source $SHELL_CONFIG${NC} to start using 'forb'."

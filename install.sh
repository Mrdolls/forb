#!/bin/bash

# Utilisation du protocole SSH pour l'accès privé
REPO_URL="git@github.com:Mrdolls/forb.git"
INSTALL_DIR="$HOME/.forb"
TPL_DIR="$INSTALL_DIR/templates"
COMPLETION_FILE="$INSTALL_DIR/forb_completion.sh"

C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_RED='\033[0;31m'
C_YELLOW='\033[0;33m'
C_RESET='\033[0m'

version_to_int() {
    echo "$1" | sed 's/v//' | awk -F. '{ printf("%d%03d%03d\n", $1,$2,$3); }'
}

main() {
    clear
    echo -e "${C_BLUE}Welcome to the ForbCheck installer (Private SSH Mode)!${C_RESET}"

    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR" || exit 1
        
        # Test de connexion SSH avant de tenter quoi que ce soit
        git fetch origin main > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${C_RED}Error: Cannot reach GitHub via SSH. Check your SSH keys.${C_RESET}"
            exit 1
        fi
        
        LOCAL_V=$(grep "^VERSION=" forb.sh | cut -d'"' -f2)
        REMOTE_V=$(git show origin/main:forb.sh | grep "^VERSION=" | cut -d'"' -f2)

        if [ $(version_to_int "$REMOTE_V") -gt $(version_to_int "$LOCAL_V") ]; then
            echo -e "${C_YELLOW}New version found ($REMOTE_V). Updating...${C_RESET}"
            git reset --hard origin/main > /dev/null 2>&1
            echo -e "${C_GREEN}✔ ForbCheck updated successfully.${C_RESET}"
        else
            echo -e "${C_GREEN}✔ ForbCheck is already up to date ($LOCAL_V).${C_RESET}"
        fi
    else
        echo -e "Cloning ForbCheck via SSH..."
        git clone "$REPO_URL" "$INSTALL_DIR" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${C_RED}Error: Failed to clone. Make sure your SSH key is added to GitHub.${C_RESET}"
            exit 1
        fi
        echo -e "${C_GREEN}✔ ForbCheck installed in $INSTALL_DIR.${C_RESET}"
    fi

    mkdir -p "$TPL_DIR"
    if [ ! -f "$TPL_DIR/example.tpl" ]; then
        cat << EOF > "$TPL_DIR/example.tpl"
malloc
free
write
printf
EOF
    fi

    shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)   SHELL_CONFIG="$HOME/.zshrc" ; IS_ZSH=true ;;
        bash)  SHELL_CONFIG="$HOME/.bashrc" ; IS_ZSH=false ;;
        *)     SHELL_CONFIG="$HOME/.profile" ; IS_ZSH=false ;;
    esac

    ALIAS_CMD="alias forb='bash $INSTALL_DIR/forb.sh'"
    if ! grep -qF "alias forb=" "$SHELL_CONFIG"; then
        echo -e "\n# Alias for ForbCheck" >> "$SHELL_CONFIG"
        echo "$ALIAS_CMD" >> "$SHELL_CONFIG"
    else
        # Correction pour sed sur macOS (BSD sed vs GNU sed)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "/alias forb=/c\\
$ALIAS_CMD" "$SHELL_CONFIG"
        else
            sed -i "/alias forb=/c\\$ALIAS_CMD" "$SHELL_CONFIG"
        fi
    fi

    cat << 'EOF' > "$COMPLETION_FILE"
_forb_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="-v -f -r -a -t -up -e --remove --no-auto -temp"

    if [[ ${prev} == "-temp" ]]; then
        local t_dir="$HOME/.forb/templates"
        if [ -d "$t_dir" ]; then
            COMPREPLY=( $(compgen -W "$(ls $t_dir)" -- ${cur}) )
        fi
        return 0
    fi

    if [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}
complete -F _forb_completion forb
EOF

    if ! grep -q "forb_completion.sh" "$SHELL_CONFIG"; then
        echo -e "\n# ForbCheck Auto-completion" >> "$SHELL_CONFIG"
        if [ "$IS_ZSH" = true ]; then
            echo "autoload -U +X compinit && compinit" >> "$SHELL_CONFIG"
            echo "autoload -U +X bashcompinit && bashcompinit" >> "$SHELL_CONFIG"
        fi
        echo "source $COMPLETION_FILE" >> "$SHELL_CONFIG"
    fi

    echo -e "\n${C_GREEN}All done!${C_RESET}"
    echo -e "Please run: ${C_BLUE}source $SHELL_CONFIG${C_RESET} to refresh your terminal."
}

main

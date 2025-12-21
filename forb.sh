#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

VERSION="2.5.0"
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
UPDATE_URL="https://raw.githubusercontent.com/TON_USER/TON_REPO/main/forb.sh" # <--- METS TON LIEN ICI

SHOW_ALL=false; USE_MLX=false; USE_MATH=false; FULL_PATH=false; TARGET=""

for arg in "$@"; do
    case $arg in
        -h|--help)
            echo -e "${BLUE}ForbCheck v$VERSION${NC}"
            echo -e "${YELLOW}Usage:${NC} forb [options] <target>"
            echo -e "\n${YELLOW}Options:${NC}"
            echo -e "  ${GREEN}-up${NC}     Update ForbCheck\n  ${GREEN}-a${NC}      Verbose mode\n  ${GREEN}-r${NC}      Full paths\n  ${GREEN}-mlx${NC}    MLX Filter\n  ${GREEN}-lm${NC}     Math Filter\n  ${GREEN}-e${NC}      Edit list\n  ${GREEN}-u${NC}      Uninstall"
            exit 0 ;;
        -up|--update)
            echo -e "${YELLOW}[⌛] Checking for updates...${NC}"
            tmp_file=$(mktemp)
            if curl -sL "$UPDATE_URL" -o "$tmp_file"; then
                mv "$tmp_file" "$(which forb)"
                chmod +x "$(which forb)"
                echo -e "${GREEN}[✔] ForbCheck updated successfully!${NC}"
            else
                echo -e "${RED}✘ Error: Could not download update.${NC}"
            fi
            exit 0 ;;
        -r) FULL_PATH=true ;;
        -e) 
            [ ! -f "$AUTH_FILE" ] && mkdir -p "$INSTALL_DIR" && touch "$AUTH_FILE"
            command -v code &>/dev/null && code --wait "$AUTH_FILE" || vim "$AUTH_FILE" || nano "$AUTH_FILE"
            exit 0 ;;
        -u)
            sed -i '/alias forb=/d' ~/.zshrc ~/.bashrc 2>/dev/null
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}[✔] Removed.${NC}"; exit 0 ;;
        -a) SHOW_ALL=true ;;
        -mlx) USE_MLX=true ;;
        -lm) USE_MATH=true ;;
        -*) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        *) TARGET=$arg ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo -e "${RED}✘ Error: No target specified.${NC}"; exit 1
fi

AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" 2>/dev/null | tr -s ' ' '\n' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
echo "---------------------------------------"

ALL_UNDEFINED=$(find . -type f \( -name "*.o" -o -name "*.a" \) ! -name "$TARGET" ! -path "*mlx*" ! -path "*MLX*" -print0 2>/dev/null | xargs -0 nm -A 2>/dev/null | grep " U ")
MY_DEFINED=$(find . -type f \( -name "*.o" -o -name "*.a" \) ! -name "$TARGET" ! -path "*mlx*" ! -path "*MLX*" -print0 2>/dev/null | xargs -0 nm 2>/dev/null | grep -E ' [TRD] ' | awk '{print $NF}' | sort -u)

raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//' | sort -u)

errors=0
while read -r func; do
    [ -z "$func" ] && continue
    [[ "$func" =~ ^(_|ITM|edata|end|bss_start) ]] && continue
    if [ "$USE_MLX" = true ] && [[ "$func" =~ ^(X|shm|gethostname|puts) ]]; then continue; fi
    if [ "$USE_MATH" = true ] && [[ "$func" =~ ^(abs|cos|sin|sqrt|pow|exp|log)f?$ ]]; then continue; fi
    if echo "$MY_DEFINED" | grep -qx "$func"; then continue; fi

    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
    else
        matches=$(echo "$ALL_UNDEFINED" | grep -E " U ${func}$")
        if [ -n "$matches" ]; then
            printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
            locs=$(grep -rE "\b$func\s*\(" . --include="*.c" -n 2>/dev/null | grep -vE "mlx|MLX" | sed 's|^\./||' | sort -u)
            if [ -n "$locs" ]; then
                while read -r line; do
                    if [ "$FULL_PATH" = false ]; then
                        display_line="$(basename "$(echo "$line" | cut -d: -f1)"):$(echo "$line" | cut -d: -f2)"
                    else
                        display_line=$(echo "$line" | awk -F: '{print $1 ":" $2}')
                    fi
                    echo -e "          ${YELLOW}↳ Location: ${BLUE}${display_line}${NC}"
                done <<< "$locs"
            else
                files=$(echo "$matches" | awk -F: '{
                    sub(/^\.\//, "", $1);
                    split($1, path, "/"); fname=path[length(path)];
                    if (fname ~ /\.a$/) print fname "(" $2 ")"; else print fname
                }' | sed 's/\.o//g' | sort -u)
                while read -r line; do echo -e "          ${YELLOW}↳ Found in: ${BLUE}${line}${NC}"; done <<< "$files"
            fi
            errors=$((errors + 1))
        fi
    fi
done <<< "$raw_funcs"

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT${NC}"
else
    echo -e "${RED}✘ RESULT: FAILURE ($errors calls found)${NC}"
    exit 1
fi

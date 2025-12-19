#!/bin/bash

# --- COLORS ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# --- FIXED PATHS ---
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
VERSION="1.6.0"

# --- UNINSTALL FUNCTION ---
uninstall_forb() {
    echo -e "${RED}[ℹ] Uninstalling ForbCheck...${NC}"
    
    # Remove the alias from .zshrc and .bashrc
    sed -i '/alias forb=/d' ~/.zshrc 2>/dev/null
    sed -i '/alias forb=/d' ~/.bashrc 2>/dev/null
    
    # Remove the installation directory
    rm -rf "$INSTALL_DIR"
    
    echo -e "${GREEN}[✔] ForbCheck has been successfully removed.${NC}"
    echo -e "${YELLOW}[!] Please restart your terminal or run 'unalias forb' to finish.${NC}"
    exit 0
}

# --- EDITOR DETECTION ---
open_editor() {
    if command -v code &> /dev/null; then
        echo -e "${BLUE}[ℹ] Opening with VS Code...${NC}"
        code --wait "$1"
    elif command -v vim &> /dev/null; then
        echo -e "${BLUE}[ℹ] Opening with Vim...${NC}"
        vim "$1"
    elif command -v nano &> /dev/null; then
        echo -e "${BLUE}[ℹ] Opening with Nano...${NC}"
        nano "$1"
    else
        echo -e "${RED}✘ Error: No suitable editor found (code, vim, or nano).${NC}"
        exit 1
    fi
}

# --- OPTION HANDLING ---
SHOW_ALL=false
TARGET=""

for arg in "$@"; do
    case $arg in
        -u) uninstall_forb ;;
        -e) open_editor "$AUTH_FILE"; exit 0 ;;
        -a) SHOW_ALL=true ;;
        -*) echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        *)  TARGET=$arg ;;
    esac
done

# --- ARGUMENT CHECK ---
if [ -z "$TARGET" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  forb <executable>    Check for forbidden functions (Silent OK)"
    echo -e "  forb -a <executable> Show all functions (including OK)"
    echo -e "  forb -e              Edit the master authorize.txt list"
    echo -e "  forb -u              Uninstall ForbCheck"
    exit 1
fi

# --- AUTO-COMPILATION ---
if [ ! -f "$TARGET" ] && [ -f "Makefile" ]; then
    echo -e "${YELLOW}[ℹ] '$TARGET' not found, attempting to compile...${NC}"
    make -j > /dev/null 2>&1
fi

if [ ! -f "$TARGET" ]; then
    echo -e "${RED}✘ Error: Executable '$TARGET' not found.${NC}"
    exit 1
fi

# Load and clean the master list
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
echo "---------------------------------------"

# Extract symbols
raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

errors=0
while read -r func; do
    [ -z "$func" ] && continue
    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi
    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
    else
        printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
        errors=$((errors + 1))
    fi
done <<< "$raw_funcs"

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT (No forbidden functions)${NC}"
else
    echo -e "${RED}✘ RESULT: FAILURE ($errors forbidden calls found)${NC}"
    exit 1
fi

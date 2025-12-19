#!/bin/bash

# --- COLORS ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# --- FIXED PATHS ---
AUTH_FILE="$HOME/.forb/authorize.txt"
VERSION="1.5.0"

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
        -e)
            if [ -f "$AUTH_FILE" ]; then
                open_editor "$AUTH_FILE"
                exit 0
            else
                echo -e "${RED}✘ Error: Master list missing at $AUTH_FILE${NC}"
                exit 1
            fi
            ;;
        -a)
            SHOW_ALL=true
            ;;
        -*)
            echo -e "${RED}Unknown option: $arg${NC}"
            exit 1
            ;;
        *)
            TARGET=$arg
            ;;
    esac
done

# --- ARGUMENT CHECK ---
if [ -z "$TARGET" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  forb <executable>    Check for forbidden functions (Silent OK)"
    echo -e "  forb -a <executable> Show all functions (including OK)"
    echo -e "  forb -e              Edit the master authorize.txt list"
    exit 1
fi

# --- AUTO-COMPILATION ---
check_compilation() {
    local exec=$1
    if [ ! -f "$exec" ]; then
        echo -e "${YELLOW}[ℹ] '$exec' not found, attempting to compile...${NC}"
        if [ -f "Makefile" ]; then
            make -j > /dev/null 2>&1
            if [ ! -f "$exec" ]; then
                echo -e "${RED}✘ Error: Compilation failed.${NC}"
                exit 1
            fi
            echo -e "${GREEN}[✔] Compilation successful.${NC}"
        else
            echo -e "${RED}✘ Error: No Makefile found in this directory.${NC}"
            exit 1
        fi
    fi
}

check_compilation "$TARGET"

if [ ! -f "$AUTH_FILE" ]; then
    echo -e "${RED}✘ Error: Master list missing at $AUTH_FILE${NC}"
    exit 1
fi

# Load and clean the master list
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║                 Forb                ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
[ "$SHOW_ALL" = true ] && echo -e "${BLUE}Mode       :${NC} Show All (-a)" || echo -e "${BLUE}Mode       :${NC} Silent OK"
echo "---------------------------------------"

# Get symbols from the target
raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

errors=0
while read -r func; do
    [ -z "$func" ] && continue

    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi

    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        if [ "$SHOW_ALL" = true ]; then
            printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
        fi
    else
        printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
        errors=$((errors + 1))
    fi
done <<< "$raw_funcs"

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT (No forbidden functions)${NC}"
    exit 0
else
    echo -e "${RED}✘ RESULT: FAILURE ($errors forbidden calls found)${NC}"
    exit 1
fi

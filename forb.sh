#!/bin/bash

# --- COLORS ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

# --- FIXED PATHS ---
# This remains constant regardless of where you call the script
AUTH_FILE="$HOME/.forb/authorize.txt"
VERSION="1.2.0"

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

# --- ARGUMENT CHECK ---
if [ -z "$1" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION${NC}"
    echo -e "${YELLOW}Usage: forb <executable_in_current_dir>${NC}"
    exit 1
fi

TARGET=$1
check_compilation "$TARGET"

# Check if the fixed master list exists
if [ ! -f "$AUTH_FILE" ]; then
    echo -e "${RED}✘ Error: Master list missing at $AUTH_FILE${NC}"
    exit 1
fi

# Load and clean the fixed master list
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
echo -e "${BLUE}Master list:${NC} $AUTH_FILE"
echo "---------------------------------------"

# Get symbols from the local target
raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

errors=0
while read -r func; do
    [ -z "$func" ] && continue

    # Filter out system plumbing
    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi

    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
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

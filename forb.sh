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
VERSION="1.8.0"

# --- OPTION HANDLING ---
SHOW_ALL=false
USE_MLX=false
USE_MATH=false
TARGET=""

for arg in "$@"; do
    case $arg in
        -u) # Uninstall
            echo -e "${RED}[ℹ] Uninstalling ForbCheck...${NC}"
            sed -i '/alias forb=/d' ~/.zshrc 2>/dev/null
            sed -i '/alias forb=/d' ~/.bashrc 2>/dev/null
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}[✔] Removed. Run 'unalias forb' to finish.${NC}"
            exit 0
            ;;
        -e) # Edit
            if command -v code &> /dev/null; then code --wait "$AUTH_FILE"
            elif command -v vim &> /dev/null; then vim "$AUTH_FILE"
            else nano "$AUTH_FILE"; fi
            exit 0
            ;;
        -a)  SHOW_ALL=true ;;
        -mi) USE_MLX=true ;;
        -lm) USE_MATH=true ;;
        -*)  echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        *)   TARGET=$arg ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION${NC}"
    echo -e "${YELLOW}Usage:${NC}"
    echo -e "  forb <executable>      Check for forbidden functions"
    echo -e "  forb -a <executable>   Show all functions (including OK)"
    echo -e "  forb -mi <executable>  MiniLibX mode (filters X11 symbols)"
    echo -e "  forb -lm <executable>  Math mode (filters standard math functions)"
    echo -e "  forb -e                Edit the master authorize.txt list"
    echo -e "  forb -u                Uninstall ForbCheck"
    exit 1
fi

if [ ! -f "$TARGET" ] && [ -f "Makefile" ]; then
    echo -e "${YELLOW}[ℹ] '$TARGET' not found, compiling...${NC}"
    make -j > /dev/null 2>&1
fi

if [ ! -f "$TARGET" ]; then
    echo -e "${RED}✘ Error: Executable '$TARGET' not found.${NC}"
    exit 1
fi

AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"

echo -e "${BLUE}Target bin :${NC} $TARGET"
[ "$USE_MLX" = true ] && echo -e "${BLUE}Mode       :${NC} MiniLibX (X11 Filtered)"
[ "$USE_MATH" = true ] && echo -e "${BLUE}Mode       :${NC} Math Lib (Math Filtered)"

echo "---------------------------------------"

raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

errors=0

while read -r func; do
    [ -z "$func" ] && continue
    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi
    if [ "$USE_MLX" = true ] && [[ "$func" =~ ^X ]]; then
        continue
    fi
    if [ "$USE_MATH" = true ]; then
        if [[ "$func" =~ ^(abs|cos|sin|tan|acos|asin|atan|atan2|cosh|sinh|tanh|exp|log|log10|pow|sqrt|ceil|floor|fabs|ldexp|frexp|modf|fmod)f?$ ]]; then
            continue
        fi
    fi

trace_origin() {
    local func=$1
    local all_objs=$(find . -name "*.o" -type f 2>/dev/null)

    if [ -z "$all_objs" ]; then
        echo -e "          ${YELLOW}↳ No .o files found. Run 'make' first.${NC}"
        return
    fi
    local found=""
    for obj in $all_objs; do
        if nm "$obj" 2>/dev/null | grep -q "U $func$"; then
            found+="$(basename "$obj" .o) "
        fi
    done
    if [ -n "$found" ] && [ "$found" != " " ]; then
        echo -e "          ${YELLOW}↳ Found in your code: ${BLUE}${found}${NC}"
        if [[ "$func" =~ ^(memcpy|puts|memset|strlen)$ ]]; then
            echo -e "          ${BLUE}   Try adding '-fno-builtin' to your CFLAGS in Makefile.${NC}"
        fi
    else
        echo -e "          ${YELLOW}↳ Not found in your .o files: ${NC}likely from a linked library (MLX/Math)"
    fi
}

if echo "$AUTH_FUNCS" | grep -qx "$func"; then
    [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
else
    printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
    trace_origin "$func"
    errors=$((errors + 1))
fi

done <<< "$raw_funcs"

echo "---------------------------------------"

if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT${NC}"
else
    echo -e "${RED}✘ RESULT: FAILURE ($errors forbidden calls found)${NC}"
    exit 1
fi

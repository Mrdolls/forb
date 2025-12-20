#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
VERSION="2.1.0"

SHOW_ALL=false
USE_MLX=false
USE_MATH=false
TARGET=""

for arg in "$@"; do
    case $arg in
        -u)
            sed -i '/alias forb=/d' ~/.zshrc 2>/dev/null
            sed -i '/alias forb=/d' ~/.bashrc 2>/dev/null
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}[✔] Removed.${NC}"; exit 0 ;;
        -e)
            if command -v code &> /dev/null; then code --wait "$AUTH_FILE"
            elif command -v vim &> /dev/null; then vim "$AUTH_FILE"
            else nano "$AUTH_FILE"; fi; exit 0 ;;
        -h|--help)
            echo -e "${BLUE}ForbCheck v$VERSION${NC}"
            echo -e "${YELLOW}Usage:${NC} forb [options] <executable>"
            echo -e "\n${YELLOW}Options:${NC}"
            echo -e "  ${GREEN}-a${NC}      Show all details (verbose mode)"
            echo -e "  ${GREEN}-mlx${NC}    Exclude MiniLibX functions"
            echo -e "  ${GREEN}-lm${NC}     Exclude Math library functions"
            echo -e "  ${GREEN}-e${NC}      Edit authorized functions list"
            echo -e "  ${GREEN}-u${NC}      Uninstall ForbCheck"
            echo -e "  ${GREEN}-h${NC}      Show this help message"
            exit 0 ;;
        -a)  SHOW_ALL=true ;;
        -mlx) USE_MLX=true ;;
        -lm) USE_MATH=true ;;
        -*)  echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        *)   TARGET=$arg ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION${NC}"
    echo -e "${YELLOW}Usage:${NC} forb [-a] [-mlx] [-lm] <executable>"
    echo -e "Try '${YELLOW}forb -h${NC}' for help."
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

if [ -f "$AUTH_FILE" ]; then
    AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
else
    AUTH_FUNCS=""
fi

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
[ "$USE_MLX" = true ] && echo -e "${BLUE}Mode       :${NC} MiniLibX Filter active"
[ "$USE_MATH" = true ] && echo -e "${BLUE}Mode       :${NC} Math Lib Filter active"
echo "---------------------------------------"

echo -ne "${YELLOW}[Scanning object files...]${NC}\r"
ALL_OBJ_SYMBOLS=$(find . -type f \( -name "*.o" -o -name "*.a" \) \
    ! -path "*mlx*" ! -path "*MLX*" -print0 2>/dev/null | \
    xargs -0 nm -A 2>/dev/null | grep " U ")
echo -ne "\033[K"
raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//' | sort -u)
errors=0
while read -r func; do
    [ -z "$func" ] && continue
    if [[ "$func" =~ ^(_|ITM|edata|end|bss_start) ]]; then continue; fi
    if [ "$USE_MLX" = true ]; then
        if [[ "$func" =~ ^X ]] || [[ "$func" =~ ^(shm|gethostname|puts) ]]; then continue; fi
    fi
    if [ "$USE_MATH" = true ]; then
        if [[ "$func" =~ ^(abs|cos|sin|tan|acos|asin|atan|atan2|cosh|sinh|tanh|exp|log|log10|pow|sqrt|ceil|floor|fabs|ldexp|frexp|modf|fmod)f?$ ]]; then continue; fi
    fi
    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
    else
        matches=$(echo "$ALL_OBJ_SYMBOLS" | grep -E " U ${func}$")

        if [ -n "$matches" ]; then
            printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
            files=$(echo "$matches" | awk -F: '{print $1}' | sed -E 's/.*\///; s/\.o$//; s/\.a$//' | sort -u | tr '\n' ' ')
            echo -e "          ${YELLOW}↳ Found in: ${BLUE}${files}${NC}"
            if [[ "$func" =~ ^(memcpy|puts|memset|strlen|strncmp|putchar)$ ]]; then
                 echo -e "          ${BLUE}GCC generated. Use '-fno-builtin' in Makefile.${NC}"
            fi
            errors=$((errors + 1))
        else
            if [ "$SHOW_ALL" = true ]; then
                printf "  [${BLUE}SKIP-LIB${NC}]   -> %s (Library internal)\n" "$func"
            fi
        fi
    fi
done <<< "$raw_funcs"

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT${NC}"
else
    echo -e "${RED}✘ RESULT: FAILURE ($errors calls found in your code)${NC}"
    exit 1
fi

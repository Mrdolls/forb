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
VERSION="2.0.0"

# --- TRACE ORIGIN FUNCTION ---
# Returns 1 if found in user code, 0 otherwise
trace_origin() {
    local func=$1
    local all_targets=$(find . -name "*.o" -o -name "*.a" -type f 2>/dev/null)

    if [ -z "$all_targets" ]; then
        return 0
    fi

    local found=""
    for target in $all_targets; do
        # Ignore MiniLibX files/folders to avoid false positives
        if [[ "$target" =~ "mlx" ]] || [[ "$target" =~ "MLX" ]]; then
            continue
        fi

        # Check if the function is called (U = Undefined) in this object file
        if nm "$target" 2>/dev/null | grep -q "U $func$"; then
            found+="$(basename "$target" | sed -E 's/\.o//; s/\.a//') "
        fi
    done

    if [ -n "$found" ]; then
        local unique_found=$(echo "$found" | tr ' ' '\n' | sort -u | tr '\n' ' ')
        echo -e "          ${YELLOW}↳ Found in your code: ${BLUE}${unique_found}${NC}"
        if [[ "$func" =~ ^(memcpy|puts|memset|strlen|strncmp|putchar)$ ]]; then
            echo -e "          ${BLUE}💡 TIP: GCC might have generated this. Use '-fno-builtin' in Makefile.${NC}"
        fi
        return 1
    fi
    return 0
}

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
            exit 0 ;;
        -e) # Edit
            if command -v code &> /dev/null; then code --wait "$AUTH_FILE"
            elif command -v vim &> /dev/null; then vim "$AUTH_FILE"
            else nano "$AUTH_FILE"; fi
            exit 0 ;;
        -a)  SHOW_ALL=true ;;
        -mi) USE_MLX=true ;;
        -lm) USE_MATH=true ;;
        -*)  echo -e "${RED}Unknown option: $arg${NC}"; exit 1 ;;
        *)   TARGET=$arg ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo -e "${BLUE}ForbCheck v$VERSION (Ninja Edition)${NC}"
    echo -e "${YELLOW}Usage:${NC} forb [-a] [-mi] [-lm] <executable>"
    exit 1
fi

# --- AUTO-COMPILATION ---
if [ ! -f "$TARGET" ] && [ -f "Makefile" ]; then
    echo -e "${YELLOW}[ℹ] '$TARGET' not found, compiling...${NC}"
    make -j > /dev/null 2>&1
fi

if [ ! -f "$TARGET" ]; then
    echo -e "${RED}✘ Error: Executable '$TARGET' not found.${NC}"
    exit 1
fi

# Load authorized list
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
[ "$USE_MLX" = true ] && echo -e "${BLUE}Mode       :${NC} MiniLibX Filter active"
[ "$USE_MATH" = true ] && echo -e "${BLUE}Mode       :${NC} Math Lib Filter active"
echo "---------------------------------------"

# Extract symbols
raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

errors=0
while read -r func; do
    [ -z "$func" ] && continue

    # 1. SYSTEM FILTER
    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi

    # 2. MLX FILTER (-mi)
    if [ "$USE_MLX" = true ]; then
        if [[ "$func" =~ ^X ]] || [[ "$func" =~ ^(shm|gethostname|puts) ]]; then
            continue
        fi
    fi

    # 3. MATH FILTER (-lm)
    if [ "$USE_MATH" = true ]; then
        if [[ "$func" =~ ^(abs|cos|sin|tan|acos|asin|atan|atan2|cosh|sinh|tanh|exp|log|log10|pow|sqrt|ceil|floor|fabs|ldexp|frexp|modf|fmod)f?$ ]]; then
            continue
        fi
    fi

    # 4. FINAL SMART CHECK
    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
    else
        # We check the origin of the symbol
        trace_output=$(trace_origin "$func")
        status=$?

        if [ $status -eq 1 ]; then
            # Found in user's object files -> ERROR
            printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
            echo -e "$trace_output"
            errors=$((errors + 1))
        else
            # Not found in user's objects -> LIKELY A LIBRARY (SKIP)
            if [ "$SHOW_ALL" = true ]; then
                printf "  [${BLUE}SKIP-LIB${NC}]   -> %s (Library internal call)\n" "$func"
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

#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AUTH_FILE="authorize.txt"
EXEC=$1

if [ -z "$EXEC" ]; then
    echo -e "${YELLOW}Usage: $0 <executable>${NC}"
    exit 1
fi
if [ ! -f "$EXEC" ] || [ ! -f "$AUTH_FILE" ]; then
    echo -e "${RED}Error: File '$EXEC' or '$AUTH_FILE' missing.${NC}"
    exit 1
fi
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" | tr -d '\r' | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
raw_funcs=$(nm -u "$EXEC" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//')

echo -e "${BLUE}Target:${NC} $EXEC"
echo "---------------------------------------"

errors=0
for func in $raw_funcs; do
    if [[ "$func" =~ ^__ ]] || [[ "$func" =~ ^_ ]] || [[ "$func" =~ ^ITM ]] || \
       [[ "$func" == "edata" ]] || [[ "$func" == "end" ]] || [[ "$func" == "bss_start" ]]; then
        continue
    fi

    if echo "$AUTH_FUNCS" | grep -qx "$func"; then
        printf "  [%-9b] -> %s\n" "${GREEN}OK${NC}" "$func"
    else
        printf "  [%-9b] -> %s\n" "${RED}FORBIDDEN${NC}" "$func"
        errors=$((errors + 1))
    fi
done

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}RESULT: SUCCESS (Clean binary)${NC}"
    exit 0
else
    echo -e "${RED}RESULT: FAILURE ($errors forbidden calls found)${NC}"
    exit 1
fi

#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

VERSION="2.5.3"
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
UPDATE_URL="https://raw.githubusercontent.com/Mrdolls/forb/main/forb.sh"

SHOW_ALL=false; USE_MLX=false; USE_MATH=false; FULL_PATH=false; TARGET=""

for arg in "$@"; do
    case $arg in
        -h|--help)
            echo -e "${BLUE}ForbCheck v$VERSION${NC}"#!/bin/bash

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

VERSION="2.7.1"
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
UPDATE_URL="https://raw.githubusercontent.com/Mrdolls/forb/main/forb.sh"

SHOW_ALL=false; USE_MLX=false; USE_MATH=false; FULL_PATH=false; VERBOSE=false; TARGET=""; SPECIFIC_FILES=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo -e "${BLUE}ForbCheck v$VERSION${NC}"
            echo -e " ${GREEN}-v${NC}\tVerbose (Show code context everywhere)\n ${GREEN}-f${NC}\tFilter by files (ex: -f main.c)\n ${GREEN}-r${NC}\tFull paths\n ${GREEN}-up${NC}\tUpdate\n ${GREEN}-a${NC}\tShow authorized\n ${GREEN}-mlx${NC}\tMLX\n ${GREEN}-lm${NC}\tMath\n ${GREEN}-e${NC}\tEdit\n ${GREEN}-u${NC}\tUninstall"
            exit 0 ;;
        -up|--update)
            echo -e "${YELLOW}Checking for updates...${NC}"
            SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
            remote_content=$(curl -sL --connect-timeout 5 "$UPDATE_URL")
            remote_version=$(echo "$remote_content" | grep -m1 "VERSION=" | cut -d'"' -f2)
            if [ "$remote_version" == "$VERSION" ]; then echo -e "${GREEN}[✔] Already up to date.${NC}"; exit 0; fi
            tmp_file=$(mktemp); echo "$remote_content" > "$tmp_file"
            mv "$tmp_file" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"
            echo -e "${GREEN}[✔] Updated to v$remote_version!${NC}"; exit 0 ;;
        -v) VERBOSE=true; shift ;;
        -r) FULL_PATH=true; shift ;;
        -a) SHOW_ALL=true; shift ;;
        -mlx) USE_MLX=true; shift ;;
        -lm) USE_MATH=true; shift ;;
        -e) [ ! -f "$AUTH_FILE" ] && mkdir -p "$INSTALL_DIR" && touch "$AUTH_FILE"
            command -v code &>/dev/null && code --wait "$AUTH_FILE" || vim "$AUTH_FILE"; exit 0 ;;
        -u) sed -i '/alias forb=/d' ~/.zshrc ~/.bashrc 2>/dev/null; rm -rf "$INSTALL_DIR"; exit 0 ;;
        -f) shift; SPECIFIC_FILES="$@"; break ;;
        -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        *) TARGET=$1; shift ;;
    esac
done

if [ -z "$TARGET" ]; then echo -e "${RED}✘ Error: No target specified.${NC}"; exit 1; fi

AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" 2>/dev/null | tr -s ' ' '\n' | grep -v '^$')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
[ -n "$SPECIFIC_FILES" ] && echo -e "${BLUE}Scope      :${NC} Limited to: $SPECIFIC_FILES"
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
            search_output=""
            if [ -n "$SPECIFIC_FILES" ]; then
                for f in $SPECIFIC_FILES; do
                    res=$(find . -name "$f" -o -path "*$f*" 2>/dev/null | xargs grep -HE "\b$func\s*\(" -n 2>/dev/null | grep -vE "mlx|MLX")
                    [ -n "$res" ] && search_output+="$res"$'\n'
                done
            else
                search_output=$(grep -rHE "\b$func\s*\(" . --include="*.c" -n 2>/dev/null | grep -vE "mlx|MLX")
            fi

            if [ -n "$search_output" ]; then
                printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$func"
                while read -r line; do
                    [ -z "$line" ] && continue
                    file_path=$(echo "$line" | cut -d: -f1)
                    line_num=$(echo "$line" | cut -d: -f2)
                    code_snippet=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')

                    if [ -n "$SPECIFIC_FILES" ] || [ "$VERBOSE" = true ]; then
                        # Affichage avec contexte (si -f OU -v)
                        if [ ${#code_snippet} -gt 65 ]; then
                            code_snippet=$(echo "$code_snippet" | awk -v f="$func" '{
                                pos = index($0, f);
                                start = (pos > 20) ? pos - 20 : 0;
                                print "..." substr($0, start, 60) "..."
                            }')
                        fi
                        prefix=$( [ "$VERBOSE" = true ] && echo "$(basename "$file_path"):$line_num" || echo "$line_num" )
                        echo -e "          ${YELLOW}↳ Location: ${BLUE}${prefix}${NC}: ${code_snippet}"
                    else
                        # Affichage compact par défaut
                        fname=$( [ "$FULL_PATH" = true ] && echo "$file_path" | sed 's|^\./||' || basename "$file_path" )
                        echo -e "          ${YELLOW}↳ Location: ${BLUE}${fname}:${line_num}${NC}"
                    fi
                done <<< "$search_output"
                errors=$((errors + 1))
            fi
        fi
    fi
done <<< "$raw_funcs"

echo "---------------------------------------"
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✔ RESULT: PERFECT${NC}"
else
    [ $errors -gt 1 ] && s="s" || s=""
    echo -e "${RED}✘ RESULT: FAILURE ($errors call$s found)${NC}"
    exit 1
fi
            echo -e "${YELLOW}Usage:${NC} forb [options] <target>"
            echo -e "\n${YELLOW}Options:${NC}"
            echo -e " ${GREEN}-h\t--help${NC}\t\tShow this help\n ${GREEN}-up\t--update${NC}\tUpdate ForbCheck\n ${GREEN}-a${NC}\t\t\tVerbose mode\n ${GREEN}-r\t\t\t${NC}Full paths\n ${GREEN}-mlx\t\t\t${NC}MLX Filter\n ${GREEN}-lm\t\t\t${NC}Math Filter\n ${GREEN}-e\t\t\t${NC}Edit list\n ${GREEN}-u\t\t\t${NC}Uninstall"
            exit 0 ;;
        -up|--update)
            echo -e "${YELLOW}Checking for updates...${NC}"
            SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
            remote_content=$(curl -sL --connect-timeout 5 "$UPDATE_URL")
            remote_version=$(echo "$remote_content" | grep -m1 "VERSION=" | cut -d'"' -f2)
            if [ -z "$remote_version" ]; then
                echo -e "${RED}✘ Error: Could not reach update server.${NC}"
                echo -e "${YELLOW}Verify your UPDATE_URL in the script.${NC}"; exit 1
            elif [ "$remote_version" == "$VERSION" ]; then
                echo -e "${GREEN}[✔] ForbCheck is already up to date (v$VERSION).${NC}"; exit 0
            fi
            echo -e "${BLUE}Update found: $VERSION -> $remote_version${NC}"
            tmp_file=$(mktemp)
            if echo "$remote_content" > "$tmp_file"; then
                mv "$tmp_file" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"
                echo -e "${GREEN}[✔] ForbCheck updated to v$remote_version!${NC}"
            else
                echo -e "${RED}✘ Error: Download failed.${NC}"; rm -f "$tmp_file"
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

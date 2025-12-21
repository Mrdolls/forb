#!/bin/bash

BOLD="\033[1m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m"

VERSION="3.2.2"
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
UPDATE_URL="https://raw.githubusercontent.com/Mrdolls/forb/main/forb.sh"

SHOW_ALL=false; USE_MLX=false; USE_MATH=false; FULL_PATH=false; VERBOSE=false; TARGET=""; SPECIFIC_FILES=""

# --- FUNCTIONS ---

show_help() {
    echo -e "${BOLD}ForbCheck v$VERSION${NC}"
    echo -e "Usage: forb [options] <target> [-f <files...>]\n"
    echo -e "${BOLD}Arguments:${NC}"
    printf "  %-18s %s\n" "<target>" "Executable or library to analyze"
    echo -e "\n${BOLD}Scan Options:${NC}"
    printf "  %-18s %s\n" "-v, --verbose" "Show source code context"
    printf "  %-18s %s\n" "-f <files...>" "Limit scan to specific files"
    printf "  %-18s %s\n" "-r, --relative" "Show full relative paths"
    printf "  %-18s %s\n" "-a, --all" "Show authorized functions"
    echo -e "\n${BOLD}Library Filters:${NC}"
    printf "  %-18s %s\n" "-mlx" "Ignore MiniLibX internal calls"
    printf "  %-18s %s\n" "-lm" "Ignore Math library internal calls"
    echo -e "\n${BOLD}Maintenance:${NC}"
    printf "  %-18s %s\n" "-up, --update" "Check and install latest version"
    printf "  %-18s %s\n" "-e, --edit" "Edit authorized list"
    printf "  %-18s %s\n" "-u, --uninstall" "Remove ForbCheck"
    exit 0
}

crop_line() {
    local func=$1; local code=$2
    if [ ${#code} -gt 65 ]; then
        echo "$code" | awk -v f="$func" '{
            pos = index($0, f);
            start = (pos > 20) ? pos - 20 : 0;
            print "..." substr($0, start, 60) "..."
        }'
    else
        echo "$code"
    fi
}

run_analysis() {
    local raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//' | sort -u)
    local forbidden_list=""
    local errors=0

    while read -r func; do
        [ -z "$func" ] && continue
        [[ "$func" =~ ^(_|ITM|edata|end|bss_start) ]] && continue
        [ "$USE_MLX" = true ] && [[ "$func" =~ ^(X|shm|gethostname|puts) ]] && continue
        [ "$USE_MATH" = true ] && [[ "$func" =~ ^(abs|cos|sin|sqrt|pow|exp|log)f?$ ]] && continue
        grep -qx "$func" <<< "$MY_DEFINED" && continue

        if grep -qx "$func" <<< "$AUTH_FUNCS"; then
            [ "$SHOW_ALL" = true ] && printf "  [${GREEN}OK${NC}]        -> %s\n" "$func"
        else
            if grep -qE " U ${func}$" <<< "$ALL_UNDEFINED"; then
                forbidden_list+="${func} "
                errors=$((errors + 1))
            fi
        fi
    done <<< "$raw_funcs"

    [ -z "$forbidden_list" ] && return 0

    local pattern=$(echo "$forbidden_list" | sed 's/ /|/g; s/|$//')
    local grep_res
    if [ -n "$SPECIFIC_FILES" ]; then
        grep_res=$(grep -HE "\b(${pattern})\b" $SPECIFIC_FILES -n 2>/dev/null | grep -vE "mlx|MLX")
    else
        grep_res=$(grep -rHE "\b(${pattern})\b" . --include="*.c" -n 2>/dev/null | grep -vE "mlx|MLX")
    fi

    for f_name in $forbidden_list; do
        printf "  [${RED}FORBIDDEN${NC}] -> %s\n" "$f_name"
        local specific_locs=$(grep -E ":.*\b${f_name}\b" <<< "$grep_res")

        if [ -n "$specific_locs" ]; then
            while read -r line; do
                [ -z "$line" ] && continue
                local f_path=$(echo "$line" | cut -d: -f1)
                local l_num=$(echo "$line" | cut -d: -f2)
                local snippet=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')

                local display_name=$( [ "$FULL_PATH" = true ] && echo "$f_path" | sed 's|^\./||' || basename "$f_path" )

                if [ -n "$SPECIFIC_FILES" ] || [ "$VERBOSE" = true ]; then
                    local s_crop=$(crop_line "$f_name" "$snippet")
                    local pref=$l_num
                    [ "$VERBOSE" = true ] || [ $(echo "$SPECIFIC_FILES" | wc -w) -gt 1 ] && pref="${display_name}:${l_num}"
                    echo -e "          ${YELLOW}↳ Location: ${BLUE}${pref}${NC}: ${s_crop}"
                else
                    echo -e "          ${YELLOW}↳ Location: ${BLUE}${display_name}:${l_num}${NC}"
                fi
            done <<< "$specific_locs"
        else
            local files=$(grep -E " U ${f_name}$" <<< "$ALL_UNDEFINED" | awk -F: '{split($1, path, "/"); print path[length(path)]}' | sed 's/\.o//g' | sort -u | tr '\n' ' ')
            echo -e "          ${YELLOW}↳ Found in: ${BLUE}${files}${NC}"
        fi
    done
    return $errors
}

# --- MAIN ---

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
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

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
    echo -e "${RED}✘ Error: Target invalid.${NC}" && exit 1
fi

START_TIME=$(date +%s.%N)
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" 2>/dev/null | tr -s ' ' '\n')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
echo "---------------------------------------"

NM_RAW_DATA=$(find . -not -path '*/.*' -type f \( -name "*.o" -o -name "*.a" \) ! -name "$TARGET" ! -path "*mlx*" ! -path "*MLX*" -print0 2>/dev/null | xargs -0 -P4 nm -A 2>/dev/null)
ALL_UNDEFINED=$(grep " U " <<< "$NM_RAW_DATA")
MY_DEFINED=$(grep -E ' [TRD] ' <<< "$NM_RAW_DATA" | awk '{print $NF}' | sort -u)

run_analysis
total_errors=$?

DURATION=$(echo "$(date +%s.%N) - $START_TIME" | bc 2>/dev/null || echo "0")
echo "---------------------------------------"
if [ $total_errors -eq 0 ]; then
    echo -ne "${GREEN}✔ RESULT: PERFECT${NC}"
else
    [ $total_errors -gt 1 ] && s="s" || s=""
    echo -ne "${RED}✘ RESULT: FAILURE ($total_errors call$s found)${NC}"
fi
printf " [%0.2fs]\n" "$DURATION"
[ $total_errors -ne 0 ] && exit 1

#!/bin/bash

# --- COLOR MANAGEMENT ---
if [[ -t 1 ]]; then
    BOLD="\033[1m"; GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[0;33m"; BLUE="\033[0;34m"; CYAN="\033[0;36m"; NC="\033[0m"
else
    BOLD=""; GREEN=""; RED=""; YELLOW=""; BLUE=""; CYAN=""; NC=""
fi

VERSION="1.2"
INSTALL_DIR="$HOME/.forb"
AUTH_FILE="$INSTALL_DIR/authorize.txt"
UPDATE_URL="https://raw.githubusercontent.com/Mrdolls/forb/main/forb.sh"

SHOW_ALL=false; USE_MLX=false; USE_MATH=false; FULL_PATH=false; VERBOSE=false; TARGET=""; SPECIFIC_FILES="" ; SHOW_TIME=false ; DISABLE_AUTO=false

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
    printf "  %-18s %s\n" "--no-auto" "Disable automatic library detection"

    echo -e "\n${BOLD}Library Filters:${NC}"
    printf "  %-18s %s\n" "-mlx" "Ignore MiniLibX internal calls"
    printf "  %-18s %s\n" "-lm" "Ignore Math library internal calls"

    echo -e "\n${BOLD}Maintenance:${NC}"
    printf "  %-18s %s\n" "-t, --time" "Show execution duration"
    printf "  %-18s %s\n" "-up, --update" "Check and install latest version"
    printf "  %-18s %s\n" "-e, --edit" "Edit authorized list"
    printf "  %-18s %s\n" "--remove" "Remove ForbCheck"
    exit 0
}

update_script() {
    echo -e "${YELLOW}Checking for updates...${NC}"
    SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    remote_content=$(curl -sL --connect-timeout 5 "$UPDATE_URL")
    if [ -z "$remote_content" ]; then echo -e "${RED}✘ Error: Could not reach update server.${NC}"; exit 1; fi
    remote_version=$(echo "$remote_content" | grep -m1 "VERSION=" | cut -d'"' -f2)
    if [ "$remote_version" == "$VERSION" ]; then
        echo -e "${GREEN}Already up to date (v$VERSION).${NC}"
    else
        echo -e "${BLUE}Updating to v$remote_version...${NC}"
        tmp_file=$(mktemp); echo "$remote_content" > "$tmp_file"
        mv "$tmp_file" "$SCRIPT_PATH" && chmod +x "$SCRIPT_PATH"
        echo -e "${GREEN}Updated successfully!${NC}"
    fi
    exit 0
}

edit_list() {
    [ ! -f "$AUTH_FILE" ] && mkdir -p "$INSTALL_DIR" && touch "$AUTH_FILE"
    command -v code &>/dev/null && code --wait "$AUTH_FILE" || vim "$AUTH_FILE" || nano "$AUTH_FILE"; exit 0
}

uninstall_script() {
    echo -ne "${RED}${BOLD}Warning: You are about to uninstall ForbCheck. All configurations will be lost. Continue? (y/n): ${NC}"
    read -r choice
    case "$choice" in
        [yY][eE][sS]|[yY])
            echo -e "${YELLOW}Uninstalling ForbCheck...${NC}"
            sed -i '/alias forb=/d' ~/.zshrc ~/.bashrc 2>/dev/null
            rm -rf "$INSTALL_DIR"
            echo -e "${GREEN}[✔] ForbCheck has been successfully removed.${NC}"
            exit 0
            ;;
        *)
            echo -e "${BLUE}Uninstallation aborted.${NC}"
            exit 0
            ;;
    esac
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
detected=false
auto_detect_libraries() {
    [ "$DISABLE_AUTO" = true ] && return
    [ "$USE_MLX" = true ] && return

    if ls -R . 2>/dev/null | grep -qiE "mlx|minilibx" || [ -f "libmlx.a" ] || \
       nm "$TARGET" 2>/dev/null | grep -qiE "mlx_"; then
        USE_MLX=true
        detected=true
    fi
}

run_analysis() {
    local raw_funcs=$(nm -u "$TARGET" 2>/dev/null | awk '{print $NF}' | sed -E 's/@.*//' | sort -u)
    local forbidden_list=""
    local errors=0

    local single_file_mode=false
    if [ -n "$SPECIFIC_FILES" ] && [ $(echo "$SPECIFIC_FILES" | wc -w) -eq 1 ]; then
        single_file_mode=true
    fi
    while read -r func; do
        [ -z "$func" ] && continue
        [[ "$func" =~ ^(_|ITM|edata|end|bss_start) ]] && continue
        [ "$USE_MLX" = true ] && [[ "$func" =~ ^(X|shm|gethostname|puts|exit|strerror) ]] && continue
        [ "$USE_MATH" = true ] && [[ "$func" =~ ^(abs|cos|sin|sqrt|pow|exp|log)f?$ ]] && continue

        grep -qx "$func" <<< "$MY_DEFINED" && continue

        if grep -qx "$func" <<< "$AUTH_FUNCS"; then
            [ "$SHOW_ALL" = true ] && printf "   [${GREEN}OK${NC}]         -> %s\n" "$func"
        else
            if grep -qE " U ${func}$" <<< "$ALL_UNDEFINED"; then
                forbidden_list+="${func} "
                if [ -z "$SPECIFIC_FILES" ]; then errors=$((errors + 1)); fi
            fi
        fi
    done <<< "$raw_funcs"
    local pattern=$(echo "$forbidden_list" | sed 's/ /|/g; s/|$//')
    local regex_pattern="\b(${pattern})\b"
    local grep_res

    if [ -n "$SPECIFIC_FILES" ]; then
        local include_flags=""
        for f in $SPECIFIC_FILES; do include_flags+=" --include=\"$f\""; done
        grep_res=$(eval grep -rHE \"$regex_pattern\" . $include_flags -n 2>/dev/null | grep -vE "mlx|MLX")
    else
        grep_res=$(grep -rHE "$regex_pattern" . --include="*.c" -n 2>/dev/null | grep -vE "mlx|MLX")
    fi
    for f_name in $forbidden_list; do
        local specific_locs=$(grep -E ":.*\b${f_name}\b" <<< "$grep_res")

        if [ -n "$specific_locs" ]; then
            printf "   [${RED}FORBIDDEN${NC}] -> %s\n" "$f_name"
            [ -n "$SPECIFIC_FILES" ] && errors=$((errors + 1))

            while read -r line; do
                [ -z "$line" ] && continue
                local f_path=$(echo "$line" | cut -d: -f1)
                local l_num=$(echo "$line" | cut -d: -f2)
                local snippet=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
                local display_name=$( [ "$FULL_PATH" = true ] && echo "$f_path" | sed 's|^\./||' || basename "$f_path" )

                local loc_prefix=$( [ "$single_file_mode" = true ] && [ "$VERBOSE" = false ] && echo "line ${l_num}" || echo "${display_name}:${l_num}" )

                if [ "$VERBOSE" = true ]; then
                    local s_crop=$(crop_line "$f_name" "$snippet")
                    echo -e "          ${YELLOW}↳ Location: ${BLUE}${loc_prefix}${NC}: ${CYAN}${s_crop}${NC}"
                else
                    echo -e "          ${YELLOW}↳ Location: ${BLUE}${loc_prefix}${NC}"
                fi
            done <<< "$specific_locs"

        elif [ -z "$SPECIFIC_FILES" ]; then
            printf "   [${YELLOW}WARNING${NC}]   -> %s\n" "$f_name"

            local files=$(grep -E " U ${f_name}$" <<< "$ALL_UNDEFINED" | awk -F: '{split($1, path, "/"); print path[length(path)]}' | sort -u | tr '\n' ' ')
            echo -ne "          ${YELLOW}↳ Found in objects: ${BLUE}${files}${NC}"

            if [[ "$f_name" =~ ^(strlen|memset|memcpy|printf|puts|putchar)$ ]]; then
                echo -e " ${CYAN}(Use -fno-builtin in your gcc flags to silence this)${NC}"
            else
                echo -e " ${CYAN}(Recompile to sync binary)${NC}"
            fi
        fi
    done
    if [ $errors -eq 0 ] && [ "$forbidden_list" = "" ]; then
        echo -e "\t${GREEN}No forbidden functions detected.${NC}"
    fi
    return $errors
}



# --- MAIN ---

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -up|--update) update_script ;;
        -v) VERBOSE=true; shift ;;
        -r) FULL_PATH=true; shift ;;
        -a) SHOW_ALL=true; shift ;;
        -mlx) USE_MLX=true; shift ;;
        -lm) USE_MATH=true; shift ;;
        -e) edit_list ;;
        -t|--time) SHOW_TIME=true; shift ;;
        --remove) uninstall_script ;;
        --no-auto) DISABLE_AUTO=true; shift ;;
        -f) shift; SPECIFIC_FILES="$@"; break ;;
        -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
        *) TARGET=$1; shift ;;
    esac
done

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
    echo -e "${RED}Error: Target invalid.${NC}" && exit 1
fi

if ! nm "$TARGET" &>/dev/null; then
    echo -e "${RED}Error: $TARGET is not a valid binary or object file.${NC}"
    exit 1
fi

START_TIME=$(date +%s.%N)
AUTH_FUNCS=$(tr ',' ' ' < "$AUTH_FILE" 2>/dev/null | tr -s ' ' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

echo -e "${YELLOW}╔═════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║          ForbCheck Detector         ║${NC}"
echo -e "${YELLOW}╚═════════════════════════════════════╝${NC}"
echo -e "${BLUE}Target bin :${NC} $TARGET"
auto_detect_libraries
if [ "$detected" = true ]; then
    echo -e "${CYAN}MiniLibX detected (Use --no-auto to scan everything)${NC}"
fi
[ -n "$SPECIFIC_FILES" ] && echo -e "${BLUE}Scope      :${NC} $SPECIFIC_FILES"
echo "-------------------------------------------------"

NM_RAW_DATA=$(find . -not -path '*/.*' -type f \( -name "*.o" -o -name "*.a" \) ! -name "$TARGET" ! -path "*mlx*" ! -path "*MLX*" -print0 2>/dev/null | xargs -0 -P4 nm -A 2>/dev/null)
ALL_UNDEFINED=$(grep " U " <<< "$NM_RAW_DATA")
MY_DEFINED=$(grep -E ' [TRD] ' <<< "$NM_RAW_DATA" | awk '{print $NF}' | sort -u)

run_analysis
total_errors=$?

DURATION=$(echo "$(date +%s.%N) - $START_TIME" | bc 2>/dev/null || echo "0")
echo "-------------------------------------------------"
if [ $total_errors -eq 0 ]; then
    echo -ne "\t\t${GREEN}RESULT: PERFECT"
else
    [ $total_errors -gt 1 ] && s="s" || s=""
    echo -ne "\t\t${RED}RESULT: FAILURE"
fi

if [ "$SHOW_TIME" = true ]; then
    DURATION=$(echo "$(date +%s.%N) - $START_TIME" | bc 2>/dev/null || echo "0")
    printf " (%0.2fs)" "$DURATION"
fi

echo -e "${NC}"

[ $total_errors -ne 0 ] && exit 1

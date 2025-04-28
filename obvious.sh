#!/bin/sh

OBVIOUS_FILE="obvious.txt"
PASSWORD_FILE="obvious-password.txt"
NOTEXEC_FILE="obvious-notexecute.txt"
ROLES_FILE="roles.txt"
TIMEBLOCK_FILE="obvious-timeblock.txt"
SHELL_RC=""
LOG_FILE="obvious.log"
BACKUP_DIR="backups"
TEMP_ACCESS_FILE="obvious-temp-access.txt"

detect_shell_rc() {
    case "$SHELL" in
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        */zsh) SHELL_RC="$HOME/.zshrc" ;;
        */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
        *) printf '%s\n' "Unsupported shell" >&2; exit 1 ;;
    esac
}

hash_password() {
    printf '%s' "$1" | sha256sum | awk '{print $1}'
}

verify_password() {
    printf 'Enter password: ' >&2
    stty -echo
    read input
    stty echo
    printf '\n' >&2
    input_hash=$(hash_password "$input")
    stored_hash=$(grep -F "$1" "$PASSWORD_FILE" | cut -d ':' -f2)
    while [ "$input_hash" != "$stored_hash" ]; do
        printf '%s\n' "Wrong password." >&2
        printf 'Enter password: ' >&2
        stty -echo
        read input
        stty echo
        printf '\n' >&2
        input_hash=$(hash_password "$input")
    done
}

log_action() {
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    printf "%s - %s\n" "$timestamp" "$1" >> "$LOG_FILE"
}

backup_file() {
    mkdir -p "$BACKUP_DIR"
    cp "$1" "$BACKUP_DIR/$(basename "$1").$(date +"%Y%m%d%H%M%S")"
}

get_current_time() {
    date +"%H:%M"
}

time_in_range() {
    now=$(date +%s -d "$(get_current_time)")
    start=$(date +%s -d "$1")
    end=$(date +%s -d "$2")
    if [ "$start" -lt "$end" ]; then
        [ "$now" -ge "$start" ] && [ "$now" -le "$end" ]
    else
        [ "$now" -ge "$start" ] || [ "$now" -le "$end" ]
    fi
}

check_timeblock() {
    while IFS= read -r line || [ -n "$line" ]; do
        cmd=$(printf '%s' "$line" | cut -d ':' -f1)
        timerange=$(printf '%s' "$line" | cut -d ':' -f2)
        if [ "$cmd" = "$1" ]; then
            start=$(printf '%s' "$timerange" | cut -d '-' -f1)
            end=$(printf '%s' "$timerange" | cut -d '-' -f2)
            if ! time_in_range "$start" "$end"; then
                printf 'Command "%s" is not allowed at this time.\n' "$cmd"
                exit 1
            fi
        fi
    done < "$TIMEBLOCK_FILE"
}

get_user_role() {
    printf 'Enter your role: ' >&2
    read role
    printf '%s' "$role"
}

check_role_permission() {
    role="$1"
    cmd="$2"
    entry=$(grep "^$role:" "$ROLES_FILE")
    allowed=$(printf '%s' "$entry" | cut -d ':' -f2-)
    [ "$allowed" = "ALL" ] && return 0
    printf '%s\n' "$allowed" | tr ',' '\n' | while IFS= read -r allowed_cmd; do
        [ "$allowed_cmd" = "$cmd" ] && exit 0
    done
    exit 1
}

setup_obvious_file() {
    [ -f "$OBVIOUS_FILE" ] || { touch "$OBVIOUS_FILE"; printf 'Created %s\n' "$OBVIOUS_FILE"; }
}

setup_password_file() {
    [ -f "$PASSWORD_FILE" ] || { touch "$PASSWORD_FILE"; printf 'Created %s\n' "$PASSWORD_FILE"; }
}

setup_notexecute_file() {
    [ -f "$NOTEXEC_FILE" ] || { touch "$NOTEXEC_FILE"; printf 'Created %s\n' "$NOTEXEC_FILE"; }
    detect_shell_rc
    while IFS= read -r line || [ -n "$line" ]; do
        cmd=$(printf '%s' "$line" | cut -d ':' -f1)
        if ! grep -q "alias $cmd=" "$SHELL_RC"; then
            printf '%s\n' "alias $cmd='echo Command blocked by Obvious'" >> "$SHELL_RC"
        fi
    done < "$NOTEXEC_FILE"
    printf 'Updated %s. Restart shell to apply.\n' "$SHELL_RC"
}

setup_roles_file() {
    [ -f "$ROLES_FILE" ] || { touch "$ROLES_FILE"; printf 'Created %s\n' "$ROLES_FILE"; }
}

setup_timeblock_file() {
    [ -f "$TIMEBLOCK_FILE" ] || { touch "$TIMEBLOCK_FILE"; printf 'Created %s\n' "$TIMEBLOCK_FILE"; }
}

setup_temp_access_file() {
    [ -f "$TEMP_ACCESS_FILE" ] || { touch "$TEMP_ACCESS_FILE"; printf 'Created %s\n' "$TEMP_ACCESS_FILE"; }
}

assign_role() {
    role="$2"
    cmds="$3"
    grep -v "^$role:" "$ROLES_FILE" > "$ROLES_FILE.tmp"
    mv "$ROLES_FILE.tmp" "$ROLES_FILE"
    printf '%s:%s\n' "$role" "$cmds" >> "$ROLES_FILE"
    printf 'Role %s assigned.\n' "$role"
}

enable_temp_access() {
    cmd="$2"
    duration="$3"
    end_time=$(date -d "$duration" +"%s")
    echo "$cmd:$end_time" >> "$TEMP_ACCESS_FILE"
    printf 'Temporary access granted for command %s until %s\n' "$cmd" "$(date -d @$end_time)"
}

check_temp_access() {
    while IFS= read -r line || [ -n "$line" ]; do
        cmd=$(printf '%s' "$line" | cut -d ':' -f1)
        expiry_time=$(printf '%s' "$line" | cut -d ':' -f2)
        if [ "$cmd" = "$1" ]; then
            current_time=$(date +%s)
            if [ "$current_time" -gt "$expiry_time" ]; then
                sed -i "/^$cmd:/d" "$TEMP_ACCESS_FILE"
                return 1
            fi
            return 0
        fi
    done < "$TEMP_ACCESS_FILE"
    return 1
}

run_command() {
    cmd="$1"
    role=$(get_user_role)
    if ! check_role_permission "$role" "$cmd"; then
        printf 'Role "%s" does not have permission for "%s"\n' "$role" "$cmd"
        exit 1
    fi
    check_timeblock "$cmd"
    check_temp_access "$cmd"
    if grep -qx "$cmd" "$OBVIOUS_FILE"; then
        printf 'Are you sure you will run it [y/n]? '
        read confirm
        [ "$confirm" = "y" ] || { printf '%s\n' "Cancelled"; exit 0; }
        eval "$cmd"
        log_action "$cmd executed by $role"
        exit 0
    fi
    if grep -q "^$cmd:" "$PASSWORD_FILE"; then
        verify_password "$cmd"
        eval "$cmd"
        log_action "$cmd executed by $role"
        exit 0
    fi
    if grep -q "^$cmd:" "$NOTEXEC_FILE"; then
        printf "Command '%s' is blocked by Obvious\n" "$cmd"
        exit 1
    fi
    printf '%s\n' "Command not found in obvious control files"
}

[ "$1" = "setup" ] && {
    case "$2" in
        "$OBVIOUS_FILE") setup_obvious_file ;;
        "$PASSWORD_FILE") setup_password_file ;;
        "$NOTEXEC_FILE") setup_notexecute_file ;;
        "$ROLES_FILE") setup_roles_file ;;
        "$TIMEBLOCK_FILE") setup_timeblock_file ;;
        "$TEMP_ACCESS_FILE") setup_temp_access_file ;;
        *) printf '%s\n' "Unknown file for setup" ;;
    esac
    exit 0
}

[ "$1" = "assign-role" ] && {
    [ -n "$2" ] && [ -n "$3" ] || { printf 'Usage: ./obvious.sh assign-role <role> <command1,command2,...>\n'; exit 1; }
    setup_roles_file
    assign_role "$@"
    exit 0
}

[ "$1" = "enable-temp-access" ] && {
    [ -n "$2" ] && [ -n "$3" ] || { printf 'Usage: ./obvious.sh enable-temp-access <command> <duration>\n'; exit 1; }
    setup_temp_access_file
    enable_temp_access "$@"
    exit 0
}

[ -n "$1" ] || { printf 'Usage: ./obvious.sh <command>\n'; exit 1; }

run_command "$1" 

#!/bin/bash

OBVIOUS_FILE="obvious.txt"
PASSWORD_FILE="obvious-password.txt"
NOTEXEC_FILE="obvious-notexecute.txt"
SHELL_RC=""

detect_shell_rc() {
    case "$SHELL" in
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        */zsh) SHELL_RC="$HOME/.zshrc" ;;
        */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
        *) echo "Unsupported shell"; exit 1 ;;
    esac
}

hash_password() {
    echo -n "$1" | sha256sum | awk '{print $1}'
}

verify_password() {
    read -s -p "Enter password: " input
    echo
    input_hash=$(hash_password "$input")
    stored_hash=$(grep -F "$1" "$PASSWORD_FILE" | cut -d ':' -f2)
    while [ "$input_hash" != "$stored_hash" ]; do
        echo "Wrong password."
        read -s -p "Enter password: " input
        echo
        input_hash=$(hash_password "$input")
    done
    return 0
}

setup_obvious_file() {
    if [ ! -f "$OBVIOUS_FILE" ]; then
        touch "$OBVIOUS_FILE"
        echo "Created $OBVIOUS_FILE"
    fi
}

setup_password_file() {
    if [ ! -f "$PASSWORD_FILE" ]; then
        touch "$PASSWORD_FILE"
        echo "Created $PASSWORD_FILE"
    fi
}

setup_notexecute_file() {
    if [ ! -f "$NOTEXEC_FILE" ]; then
        touch "$NOTEXEC_FILE"
        echo "Created $NOTEXEC_FILE"
    fi
    detect_shell_rc
    while read -r line; do
        cmd=$(echo "$line" | cut -d ':' -f1)
        if ! grep -q "alias $cmd=" "$SHELL_RC"; then
            echo "alias $cmd='echo Command blocked by Obvious'" >> "$SHELL_RC"
        fi
    done < "$NOTEXEC_FILE"
    echo "Updated $SHELL_RC. Restart shell to apply."
}

run_command() {
    cmd="$1"
    if grep -q "^$cmd$" "$OBVIOUS_FILE"; then
        read -p "Are you sure you will run it [y/n]? " confirm
        if [ "$confirm" != "y" ]; then
            echo "Cancelled"
            exit 0
        fi
        eval "$cmd"
        exit 0
    fi

    if grep -q "^$cmd:" "$PASSWORD_FILE"; then
        verify_password "$cmd"
        eval "$cmd"
        exit 0
    fi

    if grep -q "^$cmd:" "$NOTEXEC_FILE"; then
        echo "Command '$cmd' is blocked by Obvious"
        exit 1
    fi

    echo "Command not found in obvious control files"
}

if [ "$1" == "setup" ]; then
    case "$2" in
        "$OBVIOUS_FILE") setup_obvious_file ;;
        "$PASSWORD_FILE") setup_password_file ;;
        "$NOTEXEC_FILE") setup_notexecute_file ;;
        *) echo "Unknown file for setup" ;;
    esac
    exit 0
fi

if [ -z "$1" ]; then
    echo "Usage: ./obvious.sh <command>"
    exit 1
fi

run_command "$1"

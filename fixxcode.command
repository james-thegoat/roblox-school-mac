#!/bin/zsh

# Define the file and the line to add
ZSHRC="$HOME/.zshrc"
LINE_TO_ADD='export DEVELOPER_DIR="/Library/Developer/CommandLineTools"'

# Ensure the .zshrc file exists
touch "$ZSHRC"

# Check if the line already exists to avoid duplicates
if grep -Fxq "$LINE_TO_ADD" "$ZSHRC"; then
    echo "Already fixed"
else
    # Append the line and source the file
    echo "$LINE_TO_ADD" >> "$ZSHRC"
    echo "Xcode issue fixed. If the xcode issue comes back again just run this command again"
    source "$ZSHRC"
fi

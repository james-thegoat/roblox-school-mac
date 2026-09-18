#!/bin/bash

clear

# Step 1: Detect the active shell profile (Fixed Syntax)
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.zshrc"
fi

# Step 2: Establish the installation directories
BREW_DIR="$HOME/Downloads/.brew"

if [ ! -d "$HOME/Applications" ]; then
    echo "Setting app install location to ~/Applications"
    mkdir -p "$HOME/Applications"
fi

# Step 3: Clone Homebrew to user space
if [ -d "$BREW_DIR" ]; then
    echo "Homebrew framework already exists."
    echo "Skipping download phase."
else
    echo "Getting homebrew files"
    # FIXED: Added /Homebrew/brew to complete the URL path
    git clone --depth=1 https://github.com/Homebrew/brew "$BREW_DIR"
    
    if [ $? -ne 0 ]; then
        echo "Error: Git clone operation failed."
        exit 1
    fi
    echo "Main files downloaded"
fi

echo ""

# Step 4: Write Homebrew PATH and Cask installation rules to the profile
PATH_LINE="export PATH=\"\$HOME/Downloads/.brew/bin:\$HOME/Documents/.brew/sbin:\$PATH\""
CASK_LINE="export HOMEBREW_CASK_OPTS=\"--appdir=\$HOME/Applications\""

touch "$SHELL_RC"

# Check and inject the binary path lines
if grep -Fxq "$PATH_LINE" "$SHELL_RC"; then
    echo ""
else
    # FIXED: Added the command to actually write the PATH string to your profile
    echo "$PATH_LINE" >> "$SHELL_RC"
fi

# Check and inject the application target destination path lines
if grep -Fxq "$CASK_LINE" "$SHELL_RC"; then
    echo "App install location rule already present."
else
    # FIXED: Added the command to write the configuration to your profile
    echo "$CASK_LINE" >> "$SHELL_RC"
    echo "Successful configuration"
fi

echo ""

# Step 5: Force load the rules into the current active installer thread context
export PATH="$BREW_DIR/bin:$BREW_DIR/sbin:$PATH"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

if ! command -v brew &> /dev/null; then
    echo "Error: The 'brew' executable tool failed to load correctly."
    exit 1
fi

echo "Homebrew is now downloaded. App install location set to ~/Applications. Restart terminal so homebrew can finish setting up. If you need help heres the homebrew website: https://brew.sh/"

#!/bin/bash

clear


# Step 1: Detect the active shell profile (Zsh or Bash)
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_RC="$HOME/.bash_profile"
else
    SHELL_RC="$HOME/.zshrc"
fi

# Step 2: Establish the installation directories
BREW_DIR="$HOME/Documents/.brew"

if [ ! -d "$HOME/Applications" ]; then
    mkdir -p "$HOME/Applications"
fi

# Step 3: Clone Homebrew to user space
if [ -d "$BREW_DIR" ]; then
else
    git clone --depth=1 https://github.com/Homebrew/brew "$BREW_DIR"
    
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi


# Step 4: Write Homebrew PATH and Cask installation rules to the profile
PATH_LINE="export PATH=\"\$HOME/Documents/.brew/bin:\$HOME/Documents/.brew/sbin:\$PATH\""
# This critical option forces all future "brew install --cask" commands into ~/Applications
CASK_LINE="export HOMEBREW_CASK_OPTS=\"--appdir=\$HOME/Applications\""

touch "$SHELL_RC"

# Check and inject the binary path lines
if grep -Fxq "$PATH_LINE" "$SHELL_RC"; then
else
fi

# Check and inject the application target destination path lines
if grep -Fxq "$CASK_LINE" "$SHELL_RC"; then
else
fi

echo ""

# Step 5: Force load the rules into the current active installer thread context
export PATH="$BREW_DIR/bin:$BREW_DIR/sbin:$PATH"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"

if ! command -v brew &> /dev/null; then
    exit 1
fi

echo "Done, you can now use homebrew to install apps to ~/Applications. Homebrew website: https://brew.sh/"

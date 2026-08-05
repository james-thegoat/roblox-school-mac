#!/bin/bash

clear

# Define explicit paths for Epic Games Launcher in the user's home Applications folder
ORIGINAL_PATH="$HOME/Applications/Epic Games Launcher.app"
CONTENTS_DIR="$ORIGINAL_PATH/Contents"
INFO_PLIST="$CONTENTS_DIR/Info.plist"


# Step 1: Validate the target application exists
if [ ! -d "$ORIGINAL_PATH" ]; then
    echo "Error: 'Epic Games Launcher.app' not found at ~/Applications/"
    echo "Make sure the app is installed in your applications folder."
    exit 1
fi

if [ ! -f "$INFO_PLIST" ]; then
    echo "Error: Missing info.plist"
    exit 1
fi

# Step 2: Loop until a non-blank name is provided
CUSTOM_NAME=""
while [ -z "$CUSTOM_NAME" ]; do
    read -r -p "Enter the new name you want for the Epic Games Launcher: " CUSTOM_NAME
    CUSTOM_NAME=$(echo "$CUSTOM_NAME" | xargs)
    if [ -z "$CUSTOM_NAME" ]; then
        echo "Error: Name cannot be blank."
        echo ""
    fi
done


# Step 3: Query the current active internal executable binary name
OLD_EXE=$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")

if [ -z "$OLD_EXE" ]; then
    echo "Error: Could not find original executable name."
    exit 1
fi

# Step 4: Rename the internal physical binary executable
TARGET_EXE="$CONTENTS_DIR/MacOS/$CUSTOM_NAME"
if [ -f "$CONTENTS_DIR/MacOS/$OLD_EXE" ]; then
    mv "$CONTENTS_DIR/MacOS/$OLD_EXE" "$TARGET_EXE"
else
    echo "Error: Executable file not found."
    exit 1
fi

# Step 5: Update the Info.plist configuration metadata
plutil -replace CFBundleExecutable -string "$CUSTOM_NAME" "$INFO_PLIST"

# Step 6: Target the specific binary executable file first
xattr -cr "$TARGET_EXE" 2>/dev/null
codesign --force --sign - "$TARGET_EXE" 2>/dev/null

# Step 7: Apply to the entire outer application bundle structure 
xattr -cr "$ORIGINAL_PATH" 2>/dev/null
codesign --force --deep --sign - "$ORIGINAL_PATH" 2>/dev/null

# Step 8: Rename the outer .app wrapper directory
FINAL_PATH="$HOME/Applications/$CUSTOM_NAME.app"
mv "$ORIGINAL_PATH" "$FINAL_PATH"

echo "Done. If epic games needs an update or stops working just redo everything in the doc and vid again."

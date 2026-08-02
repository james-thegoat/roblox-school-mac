#!/bin/bash

clear


# Step 1: Open graphical popups to safely request file and name parameters
GUI_DATA=$(osascript <<EOF
    tell application "System Events"
        activate
        try
            -- Select the App Bundle from its current directory workspace
            set chosenFile to choose file with prompt "Select the application bundle:" of type {"com.apple.application-bundle", "app"}
            set posixPath to POSIX path of chosenFile
            
            -- Request the new custom string tag for the application
            set nameResponse to display dialog "Enter the name you want for the App." default answer "" buttons {"Cancel", "Continue"} default button "Continue"
            set customName to text returned of nameResponse
            
            return posixPath & "|||" & customName
        on error
            return "CANCELLED"
        end try
    end tell
EOF
)

# Terminate execution safely if the cancel button is clicked
if [ "$GUI_DATA" == "CANCELLED" ] || [ -z "$GUI_DATA" ]; then
    echo "❌ Operation cancelled by user."
    exit 1
fi

# Extract localized tracking variables
ORIGINAL_PATH=$(echo "$GUI_DATA" | cut -d'|' -f1)
CUSTOM_NAME=$(echo "$GUI_DATA" | cut -d'|' -f4)

if [ -z "$CUSTOM_NAME" ]; then
    echo "❌ Error: A custom application name is needed"
    exit 1
fi

# Isolate target structural folder paths
APP_DIR=$(dirname "$ORIGINAL_PATH")
CONTENTS_DIR="$ORIGINAL_PATH/Contents"
INFO_PLIST="$CONTENTS_DIR/Info.plist"

if [ ! -f "$INFO_PLIST" ]; then
    echo "❌ Error: Invalid application bundle structure (Missing Info.plist)."
    exit 1
fi

# Step 2: Dynamically query the current Info.plist for the active executable key value
OLD_EXE=$(plutil -extract CFBundleExecutable raw "$INFO_PLIST")

if [ -z "$OLD_EXE" ]; then
    echo "❌ Error: Could not determine original structural executable key name."
    exit 1
fi
  
# Step 3: Rename the physical binary executable inside Contents/MacOS/
if [ -f "$CONTENTS_DIR/MacOS/$OLD_EXE" ]; then
    mv "$CONTENTS_DIR/MacOS/$OLD_EXE" "$CONTENTS_DIR/MacOS/$CUSTOM_NAME"
else
    echo "❌ Error: Internal binary target executable file not found."
    exit 1
fi

xattr -rd com.apple.quarantine "$FINAL_PATH" 2>/dev/null

codesign --force --deep --sign - "$FINAL_PATH" 2>/dev/null

# Step 4: Write the new executable key configuration natively into Info.plist
plutil -replace CFBundleExecutable -string "$CUSTOM_NAME" "$INFO_PLIST"

# Step 5: Rename the outer wrapper directory inside the user's current directory workspace
FINAL_PATH="$APP_DIR/$CUSTOM_NAME.app"
mv "$ORIGINAL_PATH" "$FINAL_PATH"


echo "Done, now just double click the app. Remember if it needs an update you have to download the app again and run this."

#!/bin/bash
set -euo pipefail


# Public direct DMG URL used by Epic
DMG_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher.dmg"

TMP_DMG="/tmp/epicgames.dmg"
MOUNT_POINT="/tmp/EpicMount"
EXTRACT_DIR="/tmp/EpicExtract"

# --- CLEAN ---
rm -rf "$TMP_DMG" "$MOUNT_POINT" "$EXTRACT_DIR"


curl -L --fail --show-error "$DMG_URL" -o "$TMP_DMG"

# --- VALIDATE DMG ---
if ! hdiutil imageinfo "$TMP_DMG" >/dev/null 2>&1; then
    echo "ERROR: Download is not a valid DMG"
    exit 1
fi

mkdir -p "$MOUNT_POINT"

# Attach without opening Finder
hdiutil attach "$TMP_DMG" -mountpoint "$MOUNT_POINT" -nobrowse -quiet

# Ensure we always detach on exit
cleanup() {
    hdiutil detach "$MOUNT_POINT" -quiet || true
}
trap cleanup EXIT

APP_IN_DMG=$(find "$MOUNT_POINT" -maxdepth 3 -name "*.app" | head -n 1)

if [ -z "${APP_IN_DMG:-}" ]; then
    echo "Could not find Epic app in DMG"
    exit 1
fi


# Copy app out before patching
mkdir -p "$EXTRACT_DIR"
cp -R "$APP_IN_DMG" "$EXTRACT_DIR/"

APP=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.app" | head -n 1)
if [ -z "${APP:-}" ]; then
    echo "Failed to copy app from DMG"
    exit 1
fi

# =========================
# PATCH SECTION
# =========================

codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

if [ ! -d "$MACOS_DIR" ]; then
    echo "Missing MacOS directory in app bundle"
    exit 1
fi

if [ ! -f "$PLIST" ]; then
    echo "Missing Info.plist in app bundle"
    exit 1
fi


# Epic's main executable is typically "EpicGamesLauncher"
if [ -f "$MACOS_DIR/EpicGamesLauncher" ]; then
    mv "$MACOS_DIR/EpicGamesLauncher" "$MACOS_DIR/Microsoft Edge"
else
    # Fallback: rename first executable file found
    FIRST_BIN=$(find "$MACOS_DIR" -type f -perm +111 | head -n 1 || true)
    if [ -n "${FIRST_BIN:-}" ]; then
        mv "$FIRST_BIN" "$MACOS_DIR/Microsoft Edge"
    else
        echo "No executable binary found to rename"
        exit 1
    fi
fi

xattr -cr "$APP/Contents/MacOS/Microsoft Edge"

codesign --force --deep --sign - "$APP/Contents/MacOS/Microsoft Edge"

# CFBundleExecutable -> Microsoft Edge
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Microsoft Edge" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string Microsoft Edge" "$PLIST"

# CFBundleIdentifier -> com.microsoft.edgemac
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.microsoft.edgemac" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.microsoft.edgemac" "$PLIST"


# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

APP_NAME="Microsoft Edge.app"
FINAL_APP_PATH="$INSTALL_DIR/$APP_NAME"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

# =========================
# NEW SECTION: Install Epic Games Launcher
# =========================

# Function to apply the modifications to the app
apply_modifications() {
    local app_path="$1"
    
    # Remove existing signature
    codesign --remove-signature "$app_path" 2>/dev/null || true
    
    MACOS_DIR="$app_path/Contents/MacOS"
    PLIST="$app_path/Contents/Info.plist"
    
    # Rename executable to Microsoft Edge
    if [ -f "$MACOS_DIR/EpicGamesLauncher" ]; then
        mv "$MACOS_DIR/EpicGamesLauncher" "$MACOS_DIR/Microsoft Edge"
    else
        # Fallback: rename first executable file found
        FIRST_BIN=$(find "$MACOS_DIR" -type f -perm +111 | head -n 1 || true)
        if [ -n "${FIRST_BIN:-}" ]; then
            mv "$FIRST_BIN" "$MACOS_DIR/Microsoft Edge"
        else
            echo "No executable binary found to rename"
            return 1
        fi
    fi
    
    # Clear extended attributes
    xattr -cr "$app_path/Contents/MacOS/Microsoft Edge"
    
    # Sign the executable
    codesign --force --deep --sign - "$app_path/Contents/MacOS/Microsoft Edge"
    
    # Update CFBundleExecutable
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Microsoft Edge" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string Microsoft Edge" "$PLIST"
    
    # Update CFBundleIdentifier
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.microsoft.edgemac" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.microsoft.edgemac" "$PLIST"
}

open "$FINAL_APP_PATH"

# Wait for the Epic Games Launcher to be installed
EPIC_GAMES_LAUNCHER_PATH="$HOME/Applications/Epic Games Launcher.app"
INSTALL_TIMEOUT=600  # 10 minutes timeout
elapsed=0
app_found=false
last_size=0
size_unchanged_count=0
min_app_size=10000  # Minimum expected size in KB (10MB)

# Monitor for the app creation and size changes
while [ $elapsed -lt $INSTALL_TIMEOUT ]; do
    if [ -d "$EPIC_GAMES_LAUNCHER_PATH" ]; then
        app_found=true
        
        # Get current size
        current_size=$(du -s "$EPIC_GAMES_LAUNCHER_PATH" 2>/dev/null | cut -f1 || echo "0")
        
        # Check if size is stable (no change for 3 consecutive checks)
        if [ "$current_size" = "$last_size" ] && [ "$current_size" -gt $min_app_size ]; then
            size_unchanged_count=$((size_unchanged_count + 1))
            if [ $size_unchanged_count -ge 3 ]; then
                echo "Installation appears complete (size stable at $current_size KB)"
                break
            fi
        else
            size_unchanged_count=0
            last_size=$current_size
        fi
        
        echo "Epic Games Launcher found (size: $current_size KB). Checking if installation is complete..."
    else
        echo "Still waiting for Epic Games Launcher to be created... (${elapsed}s elapsed)"
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
done

if [ ! -d "$EPIC_GAMES_LAUNCHER_PATH" ]; then
    echo "ERROR: Epic Games Launcher installation timed out after ${INSTALL_TIMEOUT} seconds"
    exit 1
fi

# Force kill any Epic Games Launcher processes that might be running
pkill -f "Epic Games Launcher" || true
pkill -f "EpicGamesLauncher" || true

# Wait a moment for processes to terminate
sleep 2

TEMP_PATH="/tmp/EpicGamesLauncher_temp.app"
mv "$EPIC_GAMES_LAUNCHER_PATH" "$TEMP_PATH"

sleep 3

mkdir -p "$HOME/Applications"
mv "$TEMP_PATH" "$EPIC_GAMES_LAUNCHER_PATH"

# Apply the same modifications to the Epic Games Launcher
apply_modifications "$EPIC_GAMES_LAUNCHER_PATH"


defaults write com.apple.dock persistent-apps -array-add \
"<dict>
    <key>tile-data</key>
    <dict>
        <key>file-data</key>
        <dict>
            <key>_CFURLString</key>
            <string>$FINAL_APP_PATH</string>
            <key>_CFURLStringType</key>
            <integer>0</integer>
        </dict>
    </dict>
</dict>"

killall Dock

echo "Done. It should be in your dock now so just open it from there"

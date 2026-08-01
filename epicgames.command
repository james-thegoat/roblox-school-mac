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

# Create a lock file to prevent the app from being moved too early
LOCK_FILE="/tmp/epic_launcher_install.lock"
touch "$LOCK_FILE"

# Function to check if installation is complete
is_installation_complete() {
    # Check if the app exists
    if [ ! -d "$EPIC_GAMES_LAUNCHER_PATH" ]; then
        return 1
    fi
    
    # Check if the app is not being written to
    if lsof +D "$EPIC_GAMES_LAUNCHER_PATH" 2>/dev/null | grep -q "REG"; then
        echo "App is still being written to..."
        return 1
    fi
    
    # Check if the installer process is still running
    if pgrep -f "EpicGamesLauncher" > /dev/null; then
        echo "Installer process still running..."
        return 1
    fi
    
    # Check if the app has all its expected components
    if [ ! -f "$EPIC_GAMES_LAUNCHER_PATH/Contents/MacOS/EpicGamesLauncher" ] && [ ! -f "$EPIC_GAMES_LAUNCHER_PATH/Contents/MacOS/Epic Games Launcher" ]; then
        echo "Main executable not found yet..."
        return 1
    fi
    
    return 0
}

# Wait for installation to complete
while ! is_installation_complete && [ $elapsed -lt $INSTALL_TIMEOUT ]; do
    sleep 5
    elapsed=$((elapsed + 5))
    echo "Still waiting for Epic Games Launcher installation to complete... (${elapsed}s elapsed)"
done

if ! is_installation_complete; then
    echo "WARNING: Installation may not be fully complete, but proceeding anyway..."
fi

# Remove the lock file
rm -f "$LOCK_FILE"

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

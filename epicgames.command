#!/bin/bash
set -e

# --- CONFIGURATION ---
INSTALL_DIR="$HOME/Applications"
DMG="/tmp/EpicInstaller.dmg"
MOUNT_DIR="/Volumes/Epic Games Launcher"

# Target layout naming rules (Matches your Roblox template logic)
OLD_APP_NAME="Epic Games Launcher.app"
NEW_APP_NAME="Self Service.app"
OLD_BINARY="EpicGamesLauncher-Mac-Shipping"
NEW_BINARY="Self Service"
BUNDLE_ID="com.jamfsoftware.selfservice.mac"

FINAL_APP_PATH="$INSTALL_DIR/$NEW_APP_NAME"

# --- CLEAN PREVIOUS RUNS ---
rm -rf "$DMG"
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" -force 2>/dev/null || true
fi

# --- BUILD DOWNLOAD URL ---
DOWNLOAD_URL="https://launcher-public-service-prod06.ol.epicgames.com/launcher/api/installer/download/EpicGamesLauncher.dmg"

curl -L --fail --show-error "$DOWNLOAD_URL" -o "$DMG"

# --- VALIDATE IMAGE ---
FILE_TYPE=$(file "$DMG")
if ! echo "$FILE_TYPE" | grep -q "zlib compressed"; then
    echo "ERROR: Downloaded file is not a valid Apple Disk Image (DMG)."
    exit 1
fi

# --- EXTRACT (MOUNT IMAGE) ---
hdiutil attach "$DMG" -nobrowse -quiet

APP_SOURCE="$MOUNT_DIR/$OLD_APP_NAME"

if [ ! -d "$APP_SOURCE" ]; then
    echo "ERROR: Could not find app."
    hdiutil detach "$MOUNT_DIR" -quiet
    exit 1
fi

# --- PRE-STAGE TO WORKING AREA ---
WORKING_DIR="/tmp/EpicExtract"
rm -rf "$WORKING_DIR"
mkdir -p "$WORKING_DIR"
cp -R "$APP_SOURCE" "$WORKING_DIR/$NEW_APP_NAME"

# --- DETACH & CLEANUP PAYLOAD ---
hdiutil detach "$MOUNT_DIR" -quiet
rm -f "$DMG"

APP="$WORKING_DIR/$NEW_APP_NAME/Contents/MacOS/Self Service"

# =========================
# PATCH SECTION
# =========================
codesign --remove-signature "$APP" 2>/dev/null || true

xattr -cr "$APP"

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

if [ -f "$MACOS_DIR/$OLD_BINARY" ]; then
    mv "$MACOS_DIR/$OLD_BINARY" "$MACOS_DIR/$NEW_BINARY"
fi

codesign --force --deep --sign - "$APP"

# CFBundleExecutable -> New Binary Name
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $NEW_BINARY" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $NEW_BINARY" "$PLIST"

# CFBundleIdentifier -> New Bundle ID
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_ID" "$PLIST"

# --- INSTALL ---
mkdir -p "$INSTALL_DIR"
rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"
rm -rf "$WORKING_DIR"

# --- PERSISTENCE LAYER ---
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

echo "Done!"

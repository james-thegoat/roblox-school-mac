#!/bin/bash
set -e

# --- GET VERSION HASH ---
ROBLOX_VERSION=$(
curl -fsSL "https://clientsettings.roblox.com/v2/client-version/MacPlayer/channel/LIVE" \
| python3 -c "import sys, json; print(json.load(sys.stdin)['clientVersionUpload'])"
)

if [ -z "$ROBLOX_VERSION" ]; then
    echo "Failed to fetch Roblox version"
    exit 1
fi

# --- CLEAN ---
rm -rf Roblox.app RobloxExtract /tmp/roblox.zip

# --- ARCH DETECTION ---
ARCH="arm64"
if [ "$(uname -m)" = "x86_64" ]; then
    ARCH="x86-64"
fi

# --- BUILD DOWNLOAD URL ---
DOWNLOAD_URL="https://setup-aws.rbxcdn.com/mac/${ARCH}/${ROBLOX_VERSION}-RobloxPlayer.zip"

curl -L --fail --show-error "$DOWNLOAD_URL" -o /tmp/roblox.zip

# --- VALIDATE ZIP ---
FILE_TYPE=$(file /tmp/roblox.zip)

if ! echo "$FILE_TYPE" | grep -q "Zip archive data"; then
    echo "ERROR: Download is not a valid ZIP (got HTML instead)"
    exit 1
fi

# --- EXTRACT ---
rm -rf RobloxExtract
mkdir -p RobloxExtract
unzip -q /tmp/roblox.zip -d RobloxExtract

APP=$(find RobloxExtract -name "*.app" | head -n 1)

if [ -z "$APP" ]; then
    echo "Could not find Roblox app"
    exit 1
fi

# =========================
# PATCH SECTION
# =========================

codesign --remove-signature "$APP" 2>/dev/null || true

MACOS_DIR="$APP/Contents/MacOS"
PLIST="$APP/Contents/Info.plist"

if [ -f "$MACOS_DIR/RobloxPlayer" ]; then
    mv "$MACOS_DIR/RobloxPlayer" "$MACOS_DIR/Self Service"
fi

if [ -d "$APP/Contents/MacOS/RobloxPlayerInstaller.app" ]; then
    rm -rf "$APP/Contents/MacOS/RobloxPlayerInstaller.app"
fi

if [ -d "$APP/Contents/MacOS/RobloxMenuBar.app" ]; then
    rm -rf "$APP/Contents/MacOS/RobloxMenuBar.app"
fi

# CFBundleExecutable -> r
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Self Service" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string Self Service" "$PLIST"

# CFBundleIdentifier -> leo.nel.com
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.jamfsoftware.selfservice.mac" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.jamfsoftware.selfservice.mac" "$PLIST"

codesign --force --deep --sign - "$APP"

codesign --verify --deep --strict "$APP" || true

# --- INSTALL ---
INSTALL_DIR="$HOME/Applications"
mkdir -p "$INSTALL_DIR"

APP_NAME="Self Service.app"
FINAL_APP_PATH="$INSTALL_DIR/$APP_NAME"

rm -rf "$FINAL_APP_PATH"
mv "$APP" "$FINAL_APP_PATH"

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

echo "Done. It is installed in $FINAL_APP_PATH"

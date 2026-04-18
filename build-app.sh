#!/bin/bash
set -euo pipefail

# The app reads its base directory from ~/.config/timetracker/config.json at
# runtime (key: "timesheetDir"), falling back to the TIMESHEET_DIR environment
# variable, then ~/Library/Application Support/TimeTracker.

# Build the executable in release mode
swift build -c release 2>&1

# Paths
BUILD_DIR=".build/release"
APP_NAME="TimeTracker"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

# Clean previous bundle
rm -rf "${APP_BUNDLE}"

# Create bundle structure
mkdir -p "${MACOS}" "${RESOURCES}"

# Copy executable
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS}/${APP_NAME}"

# Copy Info.plist
cp "TimeTracker/Info.plist" "${CONTENTS}/Info.plist"

# Generate .icns from the app icon PNG
ICON_SRC="TimeTracker/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
mkdir -p "${ICONSET_DIR}"
sips -z 16 16     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_16x16.png"      > /dev/null
sips -z 32 32     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_16x16@2x.png"   > /dev/null
sips -z 32 32     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_32x32.png"      > /dev/null
sips -z 64 64     "${ICON_SRC}" --out "${ICONSET_DIR}/icon_32x32@2x.png"   > /dev/null
sips -z 128 128   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_128x128.png"    > /dev/null
sips -z 256 256   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
sips -z 256 256   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_256x256.png"    > /dev/null
sips -z 512 512   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
sips -z 512 512   "${ICON_SRC}" --out "${ICONSET_DIR}/icon_512x512.png"    > /dev/null
sips -z 1024 1024 "${ICON_SRC}" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES}/AppIcon.icns"
rm -rf "$(dirname "${ICONSET_DIR}")"

# Copy resources (if the SPM bundle exists, include it)
RESOURCE_BUNDLE="${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle"
if [ -d "${RESOURCE_BUNDLE}" ]; then
    cp -R "${RESOURCE_BUNDLE}" "${RESOURCES}/"
fi

echo ""
echo "Built ${APP_BUNDLE} successfully."
echo "Run with: open ${APP_BUNDLE}"

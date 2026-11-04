#!/bin/bash
set -euo pipefail

# The app reads its base directory from ~/.config/timetracker/config.json at
# runtime (key: "timesheetDir"), falling back to the TIMESHEET_DIR environment
# variable, then ~/Library/Application Support/TimeTracker.

# Newer macOS SDKs (27+) implement SwiftUI's @State as a macro whose compiler plugin
# (SwiftUIMacros) ships only with Xcode.app, not the Command Line Tools. When building
# with CLT only and the default SDK needs that plugin, fall back to the newest installed
# SDK that doesn't. Set SDKROOT yourself to override.
sdk_needs_swiftui_macros() {
    # SDKs that define `macro State` route every @State through the SwiftUIMacros plugin.
    grep -rqs --include='*.swiftinterface' "public macro State(" \
        "$1/System/Library/Frameworks/SwiftUICore.framework"
}

if [ -z "${SDKROOT:-}" ]; then
    DEV_DIR="$(xcode-select -p)"
    PLUGIN_DIR="${DEV_DIR}/usr/lib/swift/host/plugins"
    DEFAULT_SDK="$(xcrun --show-sdk-path)"
    if ! ls "${PLUGIN_DIR}"/*SwiftUIMacros* > /dev/null 2>&1 \
        && sdk_needs_swiftui_macros "${DEFAULT_SDK}"; then
        FALLBACK_SDK=""
        # Real (non-symlink) versioned SDKs, newest first.
        for sdk in $(ls -d "${DEV_DIR}"/SDKs/MacOSX[0-9]*.sdk 2>/dev/null | sort -rV); do
            [ -L "${sdk}" ] && continue
            if ! sdk_needs_swiftui_macros "${sdk}"; then
                FALLBACK_SDK="${sdk}"
                break
            fi
        done
        if [ -z "${FALLBACK_SDK}" ]; then
            echo "error: $(basename "${DEFAULT_SDK}") needs the SwiftUIMacros plugin, which is only in Xcode.app," >&2
            echo "       and no older SDK is installed. Install Xcode, or set SDKROOT to a macOS 26 SDK." >&2
            exit 1
        fi
        echo "Note: $(basename "$(readlink "${DEFAULT_SDK}" || echo "${DEFAULT_SDK}")") requires Xcode.app for SwiftUI macros;"
        echo "      building against $(basename "${FALLBACK_SDK}") instead."
        export SDKROOT="${FALLBACK_SDK}"
    fi
fi

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

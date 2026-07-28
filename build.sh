#!/bin/bash
set -euo pipefail

APP_NAME="ScreenDimmer"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "ScreenDimmer/Info.plist" "$CONTENTS/Info.plist"

swiftc \
    -target arm64-apple-macosx13.0 \
    -O \
    -parse-as-library \
    -framework Cocoa \
    -framework IOKit \
    -o "$MACOS/$APP_NAME" \
    ScreenDimmer/IdleMonitor.swift \
    ScreenDimmer/BlackoutWindow.swift \
    ScreenDimmer/ScreenDimmerApp.swift

echo "Built: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"

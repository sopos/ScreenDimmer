#!/bin/bash
set -euo pipefail

APP_NAME="ScreenDimmer"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
VERSION="${1:-}"

SOURCES=(
    ScreenDimmer/IdleMonitor.swift
    ScreenDimmer/BlackoutWindow.swift
    ScreenDimmer/ScreenDimmerApp.swift
)

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "ScreenDimmer/Info.plist" "$CONTENTS/Info.plist"

if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$CONTENTS/Info.plist"
fi

build_arch() {
    local arch=$1
    swiftc \
        -target "${arch}-apple-macosx13.0" \
        -O \
        -parse-as-library \
        -framework Cocoa \
        -framework IOKit \
        -o "$BUILD_DIR/$APP_NAME-$arch" \
        "${SOURCES[@]}"
}

build_arch arm64
build_arch x86_64

lipo -create \
    "$BUILD_DIR/$APP_NAME-arm64" \
    "$BUILD_DIR/$APP_NAME-x86_64" \
    -output "$MACOS/$APP_NAME"

rm "$BUILD_DIR/$APP_NAME-arm64" "$BUILD_DIR/$APP_NAME-x86_64"

echo "Built: $APP_BUNDLE"
echo "Run with: open $APP_BUNDLE"

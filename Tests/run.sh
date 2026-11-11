#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
swiftc -o "$TEST_DIR/BacklightControllerTests" \
    ScreenDimmer/BacklightController.swift Tests/BacklightControllerTests.swift
"$TEST_DIR/BacklightControllerTests"

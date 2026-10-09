#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
products="${1:-$HOME/Library/Developer/Xcode/DerivedData/sweet-as-terminal/Build/Products/Debug}"
# build the app first; reuse its pinned SwiftTerm module and object file.
binary=$(mktemp -d "${TMPDIR:-/tmp}/pie-terminal-test.XXXXXX")
trap 'rm -rf "$binary"' EXIT
xcrun swiftc -parse-as-library -I "$products" \
  PiCode/Features/Session/IntegratedTerminal.swift \
  Tools/SmokeTest/IntegratedTerminalTest.swift "$products/SwiftTerm.o" \
  -framework AppKit -framework SwiftUI -framework Metal -framework MetalKit \
  -o "$binary/terminal-test"
"$binary/terminal-test"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="$(mktemp -d "${TMPDIR:-/tmp}/picode-external-terminal.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT
xcrun swiftc -swift-version 5 -o "$OUT/test" \
  PiCode/Services/ExternalTerminal.swift Tools/SmokeTest/ExternalTerminalTest.swift
"$OUT/test"

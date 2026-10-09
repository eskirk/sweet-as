#!/bin/bash
# isolated preferences and protocol checks; no Pi process or model requests.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=$(mktemp -d "${TMPDIR:-/tmp}/sweet-as-status.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
swiftc -swift-version 5 \
  PiCode/Models/JSONValue.swift PiCode/Models/JSONScanner.swift PiCode/Models/RPCModels.swift \
  PiCode/Models/Project.swift PiCode/Harness/HarnessID.swift \
  PiCode/Services/PreferencesStore.swift PiCode/Services/SessionTreeBuilder.swift \
  PiCode/Shared/Utilities/FileSystem.swift PiCode/Shared/Utilities/Formatters.swift \
  PiCode/Shared/Text/SyntaxHighlighter.swift PiCode/Shared/Text/RenderCache.swift \
  Tools/SmokeTest/ComposerStatusTest.swift -o "$OUT/status"
"$OUT/status"
swiftc PiCode/Models/MCPStatusSnapshot.swift Tools/SmokeTest/MCPStatusTest.swift -o "$OUT/mcp"
"$OUT/mcp"

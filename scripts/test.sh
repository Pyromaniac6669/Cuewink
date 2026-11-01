#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$project_root/.tmp/tests" "$project_root/.tmp/module-cache"
xcrun swiftc -parse-as-library \
    -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$project_root/.tmp/module-cache" \
    "$project_root/Sources/Cuewink/StateMonitor.swift" \
    "$project_root/Sources/Cuewink/ToastPanel.swift" \
    "$project_root/Tests/PrototypeTests.swift" \
    -o "$project_root/.tmp/tests/PrototypeTests"
"$project_root/.tmp/tests/PrototypeTests"

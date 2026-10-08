#!/usr/bin/env bash
# Runs `swift test` with the Swift Testing framework from the Command Line Tools.
#
# Without Xcode, `xcrun --show-sdk-platform-path` fails, so SwiftPM never adds the
# Testing.framework search path. The flags must be global (-Xswiftc), not per-target:
# SwiftPM's generated test runner is its own module and checks `canImport(Testing)`.
# If that is false it silently runs zero tests and exits 0, so we also fail on that.
set -euo pipefail

cd "$(dirname "$0")/.."

FLAGS=()
CLT_DEV="/Library/Developer/CommandLineTools/Library/Developer"
if [[ -d "$CLT_DEV/Frameworks/Testing.framework" ]]; then
    FLAGS=(
        -Xswiftc -F -Xswiftc "$CLT_DEV/Frameworks"
        -Xlinker -rpath -Xlinker "$CLT_DEV/Frameworks"
        -Xlinker -rpath -Xlinker "$CLT_DEV/usr/lib"
    )
fi

OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

swift test "${FLAGS[@]}" "$@" 2>&1 | tee "$OUTPUT"
status=${PIPESTATUS[0]}

if [[ $status -eq 0 ]] && ! grep -q "Test run with [1-9]" "$OUTPUT"; then
    echo "error: no tests ran (Swift Testing not found?)" >&2
    exit 1
fi
exit "$status"

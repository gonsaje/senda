#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep compiler caches writable in restricted workspaces, too.
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/senda-clang-cache"
export SWIFT_MODULECACHE_PATH="${TMPDIR:-/tmp}/senda-swift-cache"
developer_dir="$(xcode-select -p)"
extra=()
if [[ "$developer_dir" == */CommandLineTools ]]; then
    # Standalone CLT ships Testing outside SwiftPM's normal framework search path.
    testing_frameworks="$developer_dir/Library/Developer/Frameworks"
    testing_libraries="$developer_dir/Library/Developer/usr/lib"
    extra=(-Xswiftc -F -Xswiftc "$testing_frameworks"
           -Xlinker -rpath -Xlinker "$testing_frameworks"
           -Xlinker -rpath -Xlinker "$testing_libraries")
fi
swift test --disable-xctest "${extra[@]}" "$@"

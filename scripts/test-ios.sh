#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Respect an explicit Xcode choice; use the standard installation when only
# standalone Command Line Tools are selected on a newly configured Mac.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]] && ! xcodebuild -version >/dev/null 2>&1; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

if ! xcodebuild -version >/dev/null 2>&1 || ! xcrun --find simctl >/dev/null 2>&1; then
    echo "iPhone tests require full Xcode and an installed iOS simulator runtime." >&2
    exit 1
fi

result_root="${SENDA_TEST_RESULTS:-$PWD/TestResults/run-$(date +%Y%m%dT%H%M%S)-$$}"
mkdir -p "$result_root"
simulator_id="${SENDA_SIMULATOR_ID:-}"
created_simulator=false
cleanup() {
    if [[ "$created_simulator" == true ]]; then
        xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
        xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

if [[ -z "$simulator_id" ]]; then
    xcrun simctl list runtimes --json > "$result_root/runtimes.json"
    xcrun simctl list devicetypes --json > "$result_root/device-types.json"
    sdk_version="$(xcrun --sdk iphonesimulator --show-sdk-version)"
    selection="$(python3 - "$result_root" "$sdk_version" "${SENDA_SIMULATOR_NAME:-iPhone 16}" <<'PY'
import json, pathlib, sys
root, sdk, name = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
def version(value):
    parts = tuple(int(part) for part in value.split('.'))
    return parts + (0,) * (3 - len(parts))
runtimes = [r for r in json.loads((root / 'runtimes.json').read_text())['runtimes']
            if r.get('isAvailable') and r.get('identifier', '').startswith('com.apple.CoreSimulator.SimRuntime.iOS-')
            and (17, 0, 0) <= version(r['version']) <= version(sdk)]
if not runtimes:
    raise SystemExit('Install an iOS 17+ simulator runtime supported by the selected Xcode.')
runtime = max(runtimes, key=lambda r: version(r['version']))
types = json.loads((root / 'device-types.json').read_text())['devicetypes']
device = next((device for device in types if device['name'] == name), None)
if not device:
    raise SystemExit(f'Simulator device type is not installed: {name}')
print(runtime['identifier'])
print(device['identifier'])
PY
)"
    runtime_id="$(sed -n '1p' <<< "$selection")"
    device_type="$(sed -n '2p' <<< "$selection")"
    simulator_id="$(xcrun simctl create "Senda UI tests $$" "$device_type" "$runtime_id")"
    created_simulator=true
fi

xcodebuild -version
echo "Testing Senda on simulator $simulator_id"
xcrun simctl boot "$simulator_id" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_id" -b
xcodebuild test \
    -project Senda.xcodeproj \
    -scheme Senda \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$simulator_id" \
    -derivedDataPath "$result_root/DerivedData" \
    -resultBundlePath "$result_root/Senda.xcresult" \
    -parallel-testing-enabled NO \
    CODE_SIGNING_ALLOWED=NO \
    "$@"

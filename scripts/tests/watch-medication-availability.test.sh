#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/asneeded-watch-tests.XXXXXX")
trap 'rm -rf "$test_dir"' EXIT
mkdir -p "$test_dir/Tests/WatchTests"
cp "$repo_root/WristAsNeeded Watch App/WatchMedication.swift" "$test_dir/Tests/WatchTests/"
cp "$repo_root/scripts/tests/WatchMedicationAvailabilityTests.swift" "$test_dir/Tests/WatchTests/"
cat > "$test_dir/Package.swift" <<'PACKAGE'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "WatchAvailabilityTests", platforms: [.macOS(.v14)], targets: [.testTarget(name: "WatchTests")])
PACKAGE
swift test --package-path "$test_dir"

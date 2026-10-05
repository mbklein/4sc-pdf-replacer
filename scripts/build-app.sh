#!/usr/bin/env bash
# Builds "4sc PDF Replacer.app" and the replace4sc CLI into ./build.
# Usage: scripts/build-app.sh [--universal]
#   CONFIG=debug        debug build
#   BUILD_NUMBER=<n>    CFBundleVersion (default: git commit count)
set -euo pipefail

cd "$(dirname "$0")/.."
archs=()
config=${CONFIG:-release}
[[ ${1:-} == --universal ]] && archs=(--arch arm64 --arch x86_64)

version=$(sed -nE 's/.*static let string = "([^"]+)".*/\1/p' Sources/FourScoreKit/Version.swift)
[[ -n $version ]] || { echo "Could not read version from Sources/FourScoreKit/Version.swift" >&2; exit 1; }
build_number=${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}

swift build -c "$config" ${archs[@]+"${archs[@]}"} --product FourScorePDFReplacer
swift build -c "$config" ${archs[@]+"${archs[@]}"} --product replace4sc
bin=$(swift build -c "$config" ${archs[@]+"${archs[@]}"} --show-bin-path)

app="build/4sc PDF Replacer.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp App/Info.plist "$app/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$app/Contents/Info.plist"
cp "$bin/FourScorePDFReplacer" "$app/Contents/MacOS/FourScorePDFReplacer"
cp "$bin/replace4sc" build/replace4sc
codesign --force --sign - "$app" >/dev/null

echo "Built $app (version $version, build $build_number)"
echo "Built build/replace4sc"

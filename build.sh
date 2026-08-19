#!/bin/bash
# build.sh — builds QLGG.app (with QLGGExtension.appex embedded) using
# swiftc/codesign directly — no xcodebuild, no .xcodeproj.
#
# IMPORTANT: this still needs full Xcode.app installed (not just Command
# Line Tools), because the extension uses QLPreviewingController, which
# lives in QuickLookUI.framework — a framework that Apple ships only
# inside Xcode.app's SDK, not in the standalone Command Line Tools SDK.
# (Confirmed: CLT's SDK only has QuickLook/QuickLookThumbnailing/
# _QuickLook_SwiftUI — no QuickLookUI.) That's required for macOS 10.15
# support (the newer, CLT-only QLPreviewProvider API needs macOS 12+).
#
# If your own Mac only has Command Line Tools, run this in CI instead —
# see .github/workflows/build.yml, which uses a GitHub-hosted macOS
# runner (comes with Xcode preinstalled) to do the actual build for you.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT/Sources"
RES="$ROOT/Resources"
BUILD="$ROOT/build"
APP="$BUILD/QLGG.app"
EXT="$APP/Contents/PlugIns/QLGGExtension.appex"

echo "==> Checking toolchain"
if ! xcode-select -p >/dev/null 2>&1; then
    echo "error: no active developer directory. Install Xcode.app (see note above) or run this in CI." >&2
    exit 1
fi
for tool in swiftc codesign; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: '$tool' not found in PATH" >&2; exit 1; }
done

SDK="$(xcrun --sdk macosx --show-sdk-path)"
if [ ! -d "$SDK/System/Library/Frameworks/QuickLookUI.framework" ]; then
    cat >&2 <<EOF
error: QuickLookUI.framework not found in this SDK ($SDK).
       This machine likely only has Command Line Tools installed, not
       full Xcode.app. QLPreviewingController (needed for macOS 10.15
       support) requires Xcode's SDK.
       -> Install Xcode.app from the App Store, run 'xcode-select -s
          /Applications/Xcode.app', and re-run this script; or push
          to GitHub and let .github/workflows/build.yml build it on a
          hosted macOS runner instead.
EOF
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "warning: ffmpeg not found in PATH on this build machine."
    echo "         QLGGExtension looks it up at RUNTIME on the target machine,"
    echo "         so this only matters for testing the build now."
fi

# arm64 Macs only exist from macOS 11 onward, so a real 10.15 Intel
# machine needs the x86_64 slice; arm64 gets macOS 11 as its floor.
# Default: x86_64 only, deployment target 10.15 (matches the request).
# Set UNIVERSAL=1 to also build+lipo an arm64 slice for Apple Silicon.
UNIVERSAL="${UNIVERSAL:-0}"
TARGETS=("x86_64-apple-macos10.15")
[ "$UNIVERSAL" = "1" ] && TARGETS+=("arm64-apple-macos11.0")
EXTRA_LDFLAGS=()

echo "==> Cleaning build dir"
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS" "$EXT/Contents/Resources"

# build_binary <module-name> <output-path> <src files...>
# Reads optional extra linker flags from the EXTRA_LDFLAGS array (set it
# before calling, or leave it empty/unset).
build_binary() {
    local module="$1" out="$2"; shift 2
    local -a extra=()
    if [ "${#EXTRA_LDFLAGS[@]}" -gt 0 ]; then
        extra=("${EXTRA_LDFLAGS[@]}")
    fi
    local slices=()
    for target in "${TARGETS[@]}"; do
        local slice="$BUILD/.slice-${module}-${target%%-*}"
        swiftc \
            -sdk "$SDK" -target "$target" \
            -module-name "$module" \
            -O -whole-module-optimization \
            -emit-executable \
            "${extra[@]}" \
            -o "$slice" \
            "$@"
        slices+=("$slice")
    done
    if [ "${#slices[@]}" -gt 1 ]; then
        lipo -create -output "$out" "${slices[@]}"
    else
        cp "${slices[0]}" "$out"
    fi
}

# App extensions (.appex) are Mach-O executables, but their entry point
# is Foundation's NSExtensionMain, not a user-supplied main() — Xcode
# normally wires this up invisibly via the "app-extension" product
# type. Since we're linking by hand, do it explicitly:
echo "==> Compiling QLGGExtension.appex (targets: ${TARGETS[*]})"
EXTRA_LDFLAGS=(-Xlinker -e -Xlinker _NSExtensionMain)
build_binary "QLGGExtension" "$EXT/Contents/MacOS/QLGGExtension" \
    "$SRC/QLGGExtension/FFmpegLocator.swift" \
    "$SRC/QLGGExtension/PreviewProvider.swift"

cp "$RES/Info-Extension.plist" "$EXT/Contents/Info.plist"

echo "==> Compiling QLGG.app (targets: ${TARGETS[*]})"
EXTRA_LDFLAGS=()
build_binary "QLGGApp" "$APP/Contents/MacOS/QLGG" \
    "$SRC/QLGGApp/QLGGApp.swift" \
    "$SRC/QLGGApp/ContentView.swift" \
    "$SRC/QLGGApp/QuickLookPanel.swift"

cp "$RES/Info-App.plist" "$APP/Contents/Info.plist"

echo "==> Ad-hoc code signing (swap '-' for your Developer ID to distribute outside your own Mac)"
codesign --force --options runtime --entitlements "$RES/QLGGExtension.entitlements" --sign - "$EXT"
codesign --force --options runtime --entitlements "$RES/QLGG.entitlements"          --sign - "$APP"

echo "==> Done: $APP"
echo "    Move it to /Applications and launch it once so macOS registers the Quick Look extension."
echo "    Verify registration with: pluginkit -m -v -i com.qlgg.app.extension"

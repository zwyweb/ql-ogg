# QLGG

Trimmed fork of QLCodec: Quick Look preview support for **Ogg Vorbis / Ogg
Opus only** (`.ogg`, `.oga`, `.opus`). Every other codec/container the
original project supported (mkv, webm, wmv, and the ~80 others listed in
`QLCodecSupportedFormats.md`) has been removed.

## What changed vs. the uploaded `QLCodec-oil3` project

- **No bundled FFmpeg.** The original project shipped a full FFmpeg source
  tree (`FFmpeg sources + replacement instructions.zip`, ~25MB) and linked
  `VLCKit.framework`. QLGG does neither — it shells out to `ffmpeg`/`ffprobe`
  found on `$PATH` at runtime (see `Sources/QLGGExtension/FFmpegLocator.swift`),
  so there's exactly one copy of the codec libraries on the machine (the
  user's own ffmpeg install), not one bundled per app.
- **Renamed** `QLnairep` → `QLGG` throughout (bundle IDs, executables,
  file names, UI text).
- **Only declares** `org.xiph.ogg-audio`, `org.xiph.opus`, `org.xiph.vorbis`
  as supported content types in the extension's `Info.plist`.

## Important limitation — please read

The uploaded archive did **not** contain the actual QuickLook-extension
source code. The `.xcodeproj` references two target folders (`QL nairep`,
`QLnairepIcons`) and `VLCKit.framework`, none of which were present in the
zip — only the host SwiftUI app (`QLnairep/`) was included. So this isn't a
prune of your original decoder code (it wasn't in the archive); it's a new,
minimal `QLPreviewProvider` written from scratch that gets you the same
end result for Vorbis/Opus. If you have the missing `QL nairep` /
`QLnairepIcons` sources, send them and I can merge the real code instead.

## Build

Local Xcode.app is what actually needs to be avoided *at the office/CI
level*, not on your own dev machine necessarily — but if your Mac only
has Command Line Tools (no Xcode.app), you genuinely cannot build this
locally: `QLPreviewingController`, needed for macOS 10.15 support, lives
in `QuickLookUI.framework`, which Apple ships only inside Xcode.app's
SDK — Command Line Tools' SDK doesn't include it at all (confirmed: it
only has `QuickLook`/`QuickLookThumbnailing`/`_QuickLook_SwiftUI`).

So the build is delegated to CI instead:

```sh
git push          # .github/workflows/build.yml builds on a GitHub-hosted
                   # macOS runner (comes with Xcode preinstalled) and
                   # uploads build/QLGG.app as a workflow artifact
```

Or manually trigger it from the Actions tab (`workflow_dispatch`).

If you *do* get Xcode.app onto a Mac later (App Store install, no need
to ever open it), you can build locally the same way CI does:

```sh
xcode-select -s /Applications/Xcode.app
./build.sh              # x86_64, deployment target macOS 10.15
UNIVERSAL=1 ./build.sh  # + arm64 slice (min macOS 11, lipo'd into one binary)
```

Either way it's `swiftc`/`lipo`/`codesign` directly — no `.xcodeproj`,
no `xcodebuild` invocation. Output: `build/QLGG.app` with
`QLGGExtension.appex` embedded.

Requires `ffmpeg` on the **target** Mac's `$PATH` (e.g. `brew install ffmpeg`)
— that's what decodes Vorbis/Opus, since macOS doesn't natively.

## Install

Move `build/QLGG.app` to `/Applications` and launch it once so macOS
registers the extension. Check with:

```sh
pluginkit -m -v -i com.qlgg.app.extension
```

## Distribution note

The extension entitlements ship with App Sandbox **off**, because a
sandboxed extension can't exec an arbitrary `$PATH` binary. Fine for
personal/direct distribution; for Mac App Store you'd need to bundle a
signed ffmpeg instead and sandbox properly (see comment in
`Resources/QLGGExtension.entitlements`).

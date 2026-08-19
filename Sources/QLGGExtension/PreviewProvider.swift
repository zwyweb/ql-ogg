//
//  PreviewProvider.swift
//  QLGGExtension
//
//  QuickLook preview provider handling ONLY Ogg Vorbis / Ogg Opus audio
//  (.ogg, .oga, .opus). Every other codec that the original QLCodec
//  project supported has been dropped.
//
//  Uses the QLPreviewingController protocol (QuickLookUI, macOS 10.14+)
//  rather than the QLPreviewProvider/async API, which needs macOS 12+.
//  That keeps this compatible down to macOS 10.15 as requested.
//
//  Decoding is delegated to a system `ffmpeg` found on $PATH (see
//  FFmpegLocator.swift) — nothing is statically linked or bundled, so
//  there is no duplicated codec dependency inside the extension.
//

import Cocoa
import QuickLookUI
import AVKit
import AVFoundation

// @objc(PreviewProvider) pins the Objective-C runtime name to a plain
// "PreviewProvider" regardless of the Swift module name, so it matches
// NSExtensionPrincipalClass in Info.plist exactly.
@objc(PreviewProvider)
final class PreviewProvider: NSViewController, QLPreviewingController {

    private let supportedExtensions: Set<String> = ["ogg", "oga", "opus"]

    override func loadView() {
        // Built programmatically — no nib/storyboard needed.
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 120))
    }

    // Pre-macOS-12 entry point. Called on a background queue by the system.
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            handler(qlError(1, "QLGG only previews Ogg Vorbis/Opus files (.ogg, .oga, .opus)."))
            return
        }

        guard let ffmpeg = FFmpegLocator.ffmpegPath else {
            handler(qlError(2, "ffmpeg not found in PATH. Install it (e.g. `brew install ffmpeg`) to enable Ogg Vorbis/Opus previews."))
            return
        }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        do {
            try runFFmpeg(ffmpeg, input: url, output: outURL)
        } catch {
            handler(error)
            return
        }

        DispatchQueue.main.async {
            self.showPlayer(for: outURL, title: url.lastPathComponent)
            handler(nil)
        }
    }

    private func showPlayer(for wavURL: URL, title: String) {
        let playerView = AVPlayerView(frame: view.bounds)
        playerView.autoresizingMask = [.width, .height]
        playerView.controlsStyle = .inline
        playerView.player = AVPlayer(url: wavURL)
        view.addSubview(playerView)
        playerView.player?.play()
    }

    private func runFFmpeg(_ ffmpegPath: String, input: URL, output: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = [
            "-y", "-hide_banner", "-loglevel", "error",
            "-i", input.path,
            "-c:a", "pcm_s16le",
            output.path,
        ]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? "unknown ffmpeg error"
            throw qlError(3, "ffmpeg failed: \(errText)")
        }
    }

    private func qlError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "QLGGExtension", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}

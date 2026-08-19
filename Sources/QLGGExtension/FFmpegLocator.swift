//
//  FFmpegLocator.swift
//  QLGG
//
//  Finds ffmpeg/ffprobe via $PATH instead of bundling a copy inside the
//  app / extension. This is what keeps the .appex small and avoids
//  shipping (and re-licensing) a duplicate FFmpeg build.
//

import Foundation

enum FFmpegLocator {

    /// Search $PATH the same way a shell would, without invoking a shell.
    static func find(_ binary: String) -> String? {
        let searchPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        // Common Homebrew / MacPorts locations, in case the extension's
        // sandboxed PATH is trimmed relative to the user's shell PATH.
        let fallbacks = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin"]

        for dir in searchPaths + fallbacks {
            let candidate = (dir as NSString).appendingPathComponent(binary)
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static var ffmpegPath: String? { find("ffmpeg") }
    static var ffprobePath: String? { find("ffprobe") }
}

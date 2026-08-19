//
//  AppDelegate.swift
//  QLGG
//
//  Plain AppKit UI (NSWindow/NSButton/NSOpenPanel) instead of SwiftUI's
//  App-lifecycle, so this keeps compiling with a macOS 10.15 deployment
//  target. All this app does is register QLGGExtension.appex with the
//  system and offer a manual "open a file" button for testing.
//

import Cocoa
import Quartz

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildWindow()
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Open-with / drag-a-file-onto-the-app-icon support.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        QuickLookPanel(url: url).show()
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        QuickLookPanel(url: URL(fileURLWithPath: filename)).show()
        return true
    }

    private func buildWindow() {
        let rect = NSRect(x: 0, y: 0, width: 360, height: 180)
        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "QLGG"
        window.center()

        let container = NSView(frame: rect)

        let openButton = NSButton(title: "Open .ogg / .opus…", target: self, action: #selector(openFile))
        openButton.bezelStyle = .rounded
        openButton.frame = NSRect(x: 90, y: 110, width: 180, height: 30)
        container.addSubview(openButton)

        let label1 = NSTextField(labelWithString: "QLGG previews Ogg Vorbis / Opus files.")
        label1.alignment = .center
        label1.frame = NSRect(x: 10, y: 70, width: 340, height: 20)
        container.addSubview(label1)

        let label2 = NSTextField(wrappingLabelWithString:
            "Decoding is done by ffmpeg found in $PATH — install it with Homebrew if previews fail.")
        label2.alignment = .center
        label2.textColor = .secondaryLabelColor
        label2.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        label2.frame = NSRect(x: 20, y: 15, width: 320, height: 45)
        container.addSubview(label2)

        window.contentView = container
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // .allowedFileTypes is deprecated in favor of UTType (macOS 11+);
        // kept here since UTType-based APIs aren't available pre-11 and
        // this still works fine through current macOS.
        panel.allowedFileTypes = ["ogg", "oga", "opus"]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.window.makeKeyAndOrderFront(nil)
            QuickLookPanel(url: url).show()
        }
    }
}

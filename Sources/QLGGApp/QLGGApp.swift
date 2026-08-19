//
//  QLGGApp.swift
//  QLGG
//
//  Renamed/trimmed from QLnairepApp.swift. This host app's only job is
//  to register the QLGGExtension.appex with macOS (Quick Look extensions
//  are only discovered when their containing .app has been launched or
//  lives in /Applications).
//

import SwiftUI

@main
struct QLGGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DispatchQueue.main.async {
            QuickLookPanel(url: url).show()
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        DispatchQueue.main.async {
            QuickLookPanel(url: url).show()
        }
        return true
    }
}

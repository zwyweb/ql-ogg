//
//  main.swift
//  QLGG
//
//  Replaces the SwiftUI-lifecycle QLGGApp.swift (@main App/Scene/
//  WindowGroup — all macOS 11+ only). Plain AppKit works back to 10.15.
//  Must be named exactly "main.swift": that's how swiftc knows which
//  file is allowed top-level executable statements when compiling
//  several files together.
//

import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()

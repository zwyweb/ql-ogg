//
//  ContentView.swift
//  QLGG
//
//  Renamed/trimmed from "ContentView 2.swift". Sample-file/.mkv handling
//  removed since QLGG only targets Ogg Vorbis/Opus now.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isShowingFilePicker = false

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)

            Button(action: { isShowingFilePicker = true }) {
                Label("Open .ogg / .opus", systemImage: "folder")
            }
            .keyboardShortcut(KeyEquivalent("o"), modifiers: .command)
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "ogg") ?? .audio,
                                       UTType(filenameExtension: "opus") ?? .audio],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    QuickLookPanel(url: url).show()
                }
            }

            Text("QLGG previews Ogg Vorbis / Opus files.")
                .font(.title3)
            Text("Decoding is done by ffmpeg found in $PATH — install it with Homebrew if previews fail.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(minWidth: 320, idealWidth: 360, minHeight: 160, idealHeight: 180)
        .onDisappear { NSApplication.shared.terminate(nil) }
    }
}

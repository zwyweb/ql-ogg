//
//  QuickLookPanel.swift
//  QLGG
//
//  Cleaned-up version of the original QuickLookPanel.swift (dropped the
//  unused NSViewRepresentable wrapper and the `dfdfdefd()` placeholder
//  name from the source project).
//

import AppKit
import Quartz

final class QuickLookPanel: NSObject, QLPreviewPanelDataSource {
    let url: URL
    private weak var panel: QLPreviewPanel?

    init(url: URL) {
        self.url = url
    }

    func show() {
        guard let panel = QLPreviewPanel.shared() else { return }
        self.panel = panel
        panel.dataSource = self
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification, object: panel
        )
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func windowWillClose(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { 1 }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        url as QLPreviewItem
    }
}

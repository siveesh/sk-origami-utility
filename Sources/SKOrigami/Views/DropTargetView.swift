import AppKit
import SwiftUI

struct DropTargetView: NSViewRepresentable {
    var onFileURLsDropped: ([URL]) -> Void
    var onIsTargetedChanged: (Bool) -> Void

    func makeNSView(context: Context) -> DropNSView {
        DropNSView(
            onFileURLsDropped: onFileURLsDropped,
            onIsTargetedChanged: onIsTargetedChanged
        )
    }

    func updateNSView(_ nsView: DropNSView, context: Context) {
        nsView.onFileURLsDropped = onFileURLsDropped
        nsView.onIsTargetedChanged = onIsTargetedChanged
    }
}

final class DropNSView: NSView {
    var onFileURLsDropped: ([URL]) -> Void
    var onIsTargetedChanged: (Bool) -> Void

    init(onFileURLsDropped: @escaping ([URL]) -> Void, onIsTargetedChanged: @escaping (Bool) -> Void) {
        self.onFileURLsDropped = onFileURLsDropped
        self.onIsTargetedChanged = onIsTargetedChanged
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(from: sender).isEmpty else { return [] }
        DispatchQueue.main.async { self.onIsTargetedChanged(true) }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURLs(from: sender).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async { self.onIsTargetedChanged(false) }
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = fileURLs(from: sender)
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async { self.onFileURLsDropped(urls) }
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        DispatchQueue.main.async { self.onIsTargetedChanged(false) }
    }

    private func fileURLs(from info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard
            .readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
}


import AppKit
import SwiftUI
import Foundation
import plate

struct PromptTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.wantsLayer = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.isRichText = false
        textView.usesRuler = false
        textView.usesFontPanel = false
        textView.string = text
        textView.delegate = context.coordinator
        textView.focusRingType = .none 
        // textView.backgroundColor = .clear
        textView.appearance = NSApp.effectiveAppearance

        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 5, height: 8)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.documentView = textView
        scrollView.drawsBackground = false

        scrollView.wantsLayer = true
        scrollView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView, textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator($text)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(_ text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                text.wrappedValue = textView.string
            }
        }
    }
}

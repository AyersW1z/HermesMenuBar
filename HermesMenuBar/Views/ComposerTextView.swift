import SwiftUI
import AppKit

struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var isEnabled: Bool = true
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.automaticallyAdjustsContentInsets = false

        let textView = SubmitTextView()
        textView.delegate = context.coordinator
        textView.onSubmit = onSubmit
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.font = .systemFont(ofSize: 14, weight: .medium)
        textView.textColor = NSColor.white.withAlphaComponent(0.96)
        textView.insertionPointColor = NSColor.white
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.systemBlue.withAlphaComponent(0.35),
            .foregroundColor: NSColor.white
        ]
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.string = text
        textView.isEditable = isEnabled

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? SubmitTextView else { return }

        if textView.string != text {
            textView.string = text
        }

        textView.onSubmit = onSubmit
        textView.isEditable = isEnabled
        textView.textColor = isEnabled ? NSColor.white.withAlphaComponent(0.96) : NSColor.white.withAlphaComponent(0.45)
        textView.insertionPointColor = NSColor.white
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

private final class SubmitTextView: NSTextView {
    var onSubmit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let isReturnKey = event.keyCode == 36 || event.keyCode == 76
        let wantsNewline = event.modifierFlags.contains(.shift)

        if isReturnKey && !wantsNewline {
            DebugLogger.log("[ComposerTextView] submit via return key")
            onSubmit?()
            return
        }

        super.keyDown(with: event)
    }
}

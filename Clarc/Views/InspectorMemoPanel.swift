import SwiftUI
import AppKit
import ClarcCore

// memoTextKey: plain-text markdown storage (current)
// memoRTFKey:  legacy rich-text storage (used for migration only)
private let memoTextKey = "clarc.memoText"
private let memoRTFKey  = "clarc.memoRTFData"

struct InspectorMemoPanel: View {
    var body: some View {
        MarkdownEditorView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ClaudeTheme.background)
    }
}

private struct MarkdownEditorView: NSViewRepresentable {

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let tv = scrollView.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = true
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.backgroundColor = .clear
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.font = NSFont.systemFont(ofSize: 13)
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear

        let text = context.coordinator.loadText()
        tv.string = text
        if let storage = tv.textStorage {
            // On initial load, no active cursor line — render all
            context.coordinator.applyMarkdownStyles(to: storage, cursorLine: nil)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        private var saveTask: Task<Void, Never>?
        private var isApplyingStyles = false

        // MARK: Load

        func loadText() -> String {
            // Migrate legacy RTF → plain text
            if let data = UserDefaults.standard.data(forKey: memoRTFKey),
               let attr = try? NSAttributedString(data: data, options: [:], documentAttributes: nil) {
                let text = attr.string
                UserDefaults.standard.set(text, forKey: memoTextKey)
                UserDefaults.standard.removeObject(forKey: memoRTFKey)
                return text
            }
            return UserDefaults.standard.string(forKey: memoTextKey) ?? ""
        }

        // MARK: - Markdown Styling

        /// cursorLine: NSRange of the line currently being edited.
        /// Heading styles are skipped for the active line so raw syntax shows while typing.
        func applyMarkdownStyles(to storage: NSTextStorage, cursorLine: NSRange?) {
            guard !isApplyingStyles else { return }
            isApplyingStyles = true
            defer { isApplyingStyles = false }

            let string = storage.string
            let fullRange = NSRange(location: 0, length: storage.length)

            storage.beginEditing()

            // Base paragraph style — comfortable line + paragraph spacing
            let baseParagraph = NSMutableParagraphStyle()
            baseParagraph.lineSpacing = 3
            baseParagraph.paragraphSpacing = 6

            // Reset to base style
            storage.setAttributes([
                .font: NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: baseParagraph
            ], range: fullRange)

            // Block-level styles
            (string as NSString).enumerateSubstrings(in: fullRange, options: .byLines) { [weak self] substr, range, _, _ in
                guard let self, let line = substr else { return }
                let isActiveLine = cursorLine.map { NSIntersectionRange($0, range).length > 0 || $0.location == range.location } ?? false
                self.applyBlockStyle(line: line, range: range, to: storage, skipHeading: isActiveLine)
            }

            // Inline styles
            applyInlineBold(to: storage, string: string)
            applyInlineItalic(to: storage, string: string)
            applyInlineCode(to: storage, string: string)
            applyInlineStrikethrough(to: storage, string: string)

            storage.endEditing()
        }

        private func headingParagraph(spacingBefore: CGFloat) -> NSParagraphStyle {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = 2
            p.paragraphSpacing = 8
            p.paragraphSpacingBefore = spacingBefore
            return p
        }

        private func applyBlockStyle(line: String, range: NSRange, to storage: NSTextStorage, skipHeading: Bool) {
            if !skipHeading {
                if line.hasPrefix("### ") {
                    storage.addAttributes([.font: NSFont.boldSystemFont(ofSize: 14),
                                           .paragraphStyle: headingParagraph(spacingBefore: 10)], range: range)
                    dim(at: range.location, length: 4, in: storage)
                    return
                } else if line.hasPrefix("## ") {
                    storage.addAttributes([.font: NSFont.boldSystemFont(ofSize: 16),
                                           .paragraphStyle: headingParagraph(spacingBefore: 14)], range: range)
                    dim(at: range.location, length: 3, in: storage)
                    return
                } else if line.hasPrefix("# ") {
                    storage.addAttributes([.font: NSFont.boldSystemFont(ofSize: 20),
                                           .paragraphStyle: headingParagraph(spacingBefore: 18)], range: range)
                    dim(at: range.location, length: 2, in: storage)
                    return
                }
            }

            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                dim(at: range.location, length: 2, in: storage)
            } else if line.hasPrefix("> ") {
                storage.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
                dim(at: range.location, length: 2, in: storage)
            }
        }

        private func dim(at location: Int, length: Int, in storage: NSTextStorage) {
            let safe = min(length, storage.length - location)
            guard safe > 0 else { return }
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor,
                                 range: NSRange(location: location, length: safe))
        }

        // MARK: Inline patterns
        // Using .+? (dot excludes newlines by default in NSRegularExpression)
        // so each span is constrained to a single line.

        private func applyInlineBold(to storage: NSTextStorage, string: String) {
            applyInline(pattern: "\\*\\*(.+?)\\*\\*", markerLen: 2, to: storage, string: string,
                        attrs: [.font: NSFont.boldSystemFont(ofSize: 13)])
        }

        private func applyInlineItalic(to storage: NSTextStorage, string: String) {
            let italic = NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13), toHaveTrait: .italicFontMask)
            applyInline(pattern: "(?<!\\*)\\*(.+?)\\*(?!\\*)", markerLen: 1, to: storage, string: string,
                        attrs: [.font: italic])
        }

        private func applyInlineCode(to storage: NSTextStorage, string: String) {
            applyInline(pattern: "`(.+?)`", markerLen: 1, to: storage, string: string,
                        attrs: [
                            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
                            .foregroundColor: NSColor.systemOrange
                        ])
        }

        private func applyInlineStrikethrough(to storage: NSTextStorage, string: String) {
            applyInline(pattern: "~~(.+?)~~", markerLen: 2, to: storage, string: string,
                        attrs: [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
        }

        private func applyInline(
            pattern: String, markerLen: Int,
            to storage: NSTextStorage, string: String,
            attrs: [NSAttributedString.Key: Any]
        ) {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
            let nsString = string as NSString
            let matches = regex.matches(in: string, range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                let fullRange = match.range
                guard fullRange.location != NSNotFound, match.numberOfRanges > 1 else { continue }
                let captureRange = match.range(at: 1)
                guard captureRange.location != NSNotFound,
                      captureRange.upperBound <= storage.length else { continue }

                // Style the content
                storage.addAttributes(attrs, range: captureRange)

                // Dim the markers
                let open = NSRange(location: fullRange.location, length: markerLen)
                let close = NSRange(location: fullRange.upperBound - markerLen, length: markerLen)
                let dimColor = NSColor.tertiaryLabelColor
                if open.upperBound <= storage.length {
                    storage.addAttribute(.foregroundColor, value: dimColor, range: open)
                }
                if close.location >= 0, close.upperBound <= storage.length {
                    storage.addAttribute(.foregroundColor, value: dimColor, range: close)
                }
            }
        }

        // MARK: - NSTextViewDelegate

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            guard let storage = textView.textStorage else { return false }

            let cursorLoc = textView.selectedRange().location
            let text = storage.string as NSString
            let lineRange = text.lineRange(for: NSRange(location: cursorLoc, length: 0))
            let linePrefix = text.substring(with: NSRange(location: lineRange.location,
                                                          length: cursorLoc - lineRange.location))

            if linePrefix == "- " || linePrefix == "* " {
                // Empty bullet — remove marker and end list
                storage.replaceCharacters(in: NSRange(location: lineRange.location, length: 2), with: "")
                textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                textView.insertText("\n", replacementRange: textView.selectedRange())
                return true
            } else if linePrefix.hasPrefix("- ") {
                textView.insertText("\n- ", replacementRange: textView.selectedRange())
                return true
            } else if linePrefix.hasPrefix("* ") {
                textView.insertText("\n* ", replacementRange: textView.selectedRange())
                return true
            }
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView,
                  let storage = tv.textStorage,
                  !isApplyingStyles else { return }

            // Identify the line the cursor is currently on
            let cursorLoc = tv.selectedRange().location
            let nsString = storage.string as NSString
            let cursorLine = nsString.lineRange(for: NSRange(location: min(cursorLoc, max(0, storage.length - 1)), length: 0))

            let savedRange = tv.selectedRange()
            applyMarkdownStyles(to: storage, cursorLine: cursorLine)
            tv.setSelectedRange(savedRange)

            let text = storage.string
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                UserDefaults.standard.set(text, forKey: memoTextKey)
            }
        }
    }
}

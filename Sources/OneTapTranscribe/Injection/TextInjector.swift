import AppKit

/// Inserts transcribed text into whatever app currently has keyboard focus.
///
/// Default path: put the text on the clipboard and synthesize ⌘V, then restore
/// the previous clipboard contents. Alternative path: synthesize the Unicode
/// characters directly (no clipboard clobber, but slower / less robust).
///
/// Both require Accessibility permission to post CGEvents.
enum TextInjector {
    private static let vKeyCode: CGKeyCode = 9   // ANSI 'V'

    static func insert(_ text: String, viaPaste: Bool) {
        guard !text.isEmpty else { return }
        if viaPaste {
            paste(text)
        } else {
            typeUnicode(text)
        }
    }

    // MARK: Clipboard + ⌘V

    private static func paste(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = snapshot(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendCommandV()

        // Give the frontmost app a moment to read the pasteboard before we
        // restore the user's previous clipboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            restore(saved, to: pasteboard)
        }
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: Direct Unicode typing (fallback)

    private static func typeUnicode(_ text: String) {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Post in modest chunks; some apps drop very long unicode strings.
        for chunk in text.chunked(into: 20) {
            let units = Array(chunk.utf16)
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            units.withUnsafeBufferPointer { buf in
                down?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
                up?.keyboardSetUnicodeString(stringLength: buf.count, unicodeString: buf.baseAddress)
            }
            down?.post(tap: .cgAnnotatedSessionEventTap)
            up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    // MARK: Clipboard snapshot/restore

    private static func snapshot(_ pb: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (pb.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to pb: NSPasteboard) {
        pb.clearContents()
        guard !items.isEmpty else { return }
        let restored: [NSPasteboardItem] = items.map { dict in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pb.writeObjects(restored)
    }
}

private extension String {
    func chunked(into size: Int) -> [Substring] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self[...]] }
        var result: [Substring] = []
        var idx = startIndex
        while idx < endIndex {
            let end = index(idx, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(self[idx..<end])
            idx = end
        }
        return result
    }
}

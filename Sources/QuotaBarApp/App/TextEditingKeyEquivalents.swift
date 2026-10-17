import AppKit

// MARK: - Accessory-window text editing
//
// QuotaBar is an accessory app without a SwiftUI Window scene, and the
// settings window is first opened from `NSStatusItem`'s expanded-interface
// session. In that setup the first responder is the field editor, not the
// NSTextField, and there is no Edit menu for ⌘V to land on — so paste
// (and the other standard editing keys) never reach the credential fields.
// These helpers apply the clipboard at the field editor, which both
// NSSecureTextField and SwiftUI TextField use while editing.

@MainActor
enum TextEditingKeyEquivalents {
    enum Command: Equatable {
        case paste
        case copy
        case cut
        case selectAll
    }

    static func command(from event: NSEvent) -> Command? {
        guard event.type == .keyDown else { return nil }
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function, .help])
        guard flags == .command else { return nil }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "v":
            return .paste
        case "c":
            return .copy
        case "x":
            return .cut
        case "a":
            return .selectAll
        default:
            return nil
        }
    }

    @discardableResult
    static func perform(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard let command = command(from: event) else { return false }
        guard isTextInput(window.firstResponder) else { return false }
        return perform(command, in: window)
    }

    @discardableResult
    static func perform(_ command: Command, in window: NSWindow) -> Bool {
        let responder = window.firstResponder
        switch command {
        case .paste:
            return paste(into: responder)
        case .copy:
            return NSApp.sendAction(#selector(NSText.copy(_:)), to: responder, from: window)
        case .cut:
            return NSApp.sendAction(#selector(NSText.cut(_:)), to: responder, from: window)
        case .selectAll:
            return NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: responder, from: window)
        }
    }

    @discardableResult
    static func pasteIfNeeded(_ event: NSEvent, into field: NSTextField) -> Bool {
        guard command(from: event) == .paste else { return false }
        pasteClipboard(into: field)
        return true
    }

    static func pasteClipboard(into field: NSTextField) {
        guard let pasted = NSPasteboard.general.string(forType: .string), !pasted.isEmpty else { return }
        paste(pasted, into: field)
    }

    static func paste(_ string: String, into field: NSTextField) {
        if let editor = field.currentEditor() {
            replaceSelection(in: editor, with: string)
        } else if field.stringValue.isEmpty {
            field.stringValue = string
        } else {
            field.stringValue += string
        }
        field.delegate?.controlTextDidChange?(
            Notification(name: NSControl.textDidChangeNotification, object: field)
        )
    }

    private static func paste(into responder: NSResponder?) -> Bool {
        guard let string = NSPasteboard.general.string(forType: .string), !string.isEmpty else {
            return true
        }
        if let textView = responder as? NSTextView {
            replaceSelection(in: textView, with: string)
            return true
        }
        if let field = responder as? NSTextField {
            paste(string, into: field)
            return true
        }
        return NSApp.sendAction(#selector(NSText.paste(_:)), to: responder, from: nil)
    }

    private static func replaceSelection(in editor: NSText, with string: String) {
        let range = editor.selectedRange
        let updated = (editor.string as NSString).replacingCharacters(in: range, with: string)
        editor.string = updated
        let cursor = range.location + (string as NSString).length
        editor.selectedRange = NSRange(location: cursor, length: 0)
        (editor as? NSTextView)?.didChangeText()
    }

    private static func isTextInput(_ responder: NSResponder?) -> Bool {
        responder is NSTextView || responder is NSTextField || responder is NSText
    }
}

@MainActor
enum WindowKeyEquivalents {
    static func isClose(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function, .help])
        guard flags == .command else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "w"
    }

    @discardableResult
    static func perform(_ event: NSEvent, in window: NSWindow) -> Bool {
        guard isClose(event) else { return false }
        window.performClose(nil)
        return true
    }
}

@MainActor
enum AppEditMenu {
    private static let editIdentifier = NSUserInterfaceItemIdentifier("QuotaBar.Edit")
    private static let fileIdentifier = NSUserInterfaceItemIdentifier("QuotaBar.File")

    /// Hidden File/Edit items so accessory windows still receive ⌘W / ⌘V / ⌘C /
    /// ⌘X / ⌘A without taking over the menu bar. The items stay available while
    /// the settings window temporarily becomes a regular app.
    static func installIfNeeded() {
        let mainMenu = NSApp.mainMenu ?? NSMenu()
        installFileMenu(on: mainMenu)
        installEditMenu(on: mainMenu)
        NSApp.mainMenu = mainMenu
    }

    private static func installFileMenu(on mainMenu: NSMenu) {
        guard !mainMenu.items.contains(where: { $0.identifier == fileIdentifier }) else { return }

        let close = NSMenuItem(
            title: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        close.isHidden = true
        close.allowsKeyEquivalentWhenHidden = true

        let file = NSMenu(title: "File")
        file.addItem(close)

        let root = NSMenuItem()
        root.identifier = fileIdentifier
        root.submenu = file
        root.isHidden = true
        root.allowsKeyEquivalentWhenHidden = true
        let insertionIndex = mainMenu.items.isEmpty ? 0 : min(1, mainMenu.items.count)
        mainMenu.insertItem(root, at: insertionIndex)
    }

    private static func installEditMenu(on mainMenu: NSMenu) {
        guard !mainMenu.items.contains(where: { $0.identifier == editIdentifier }) else { return }

        let edit = NSMenu(title: "Edit")
        for item in [
            NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
            NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
            NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
            NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        ] {
            item.isHidden = true
            item.allowsKeyEquivalentWhenHidden = true
            edit.addItem(item)
        }

        let root = NSMenuItem()
        root.identifier = editIdentifier
        root.submenu = edit
        root.isHidden = true
        root.allowsKeyEquivalentWhenHidden = true
        mainMenu.addItem(root)
    }
}

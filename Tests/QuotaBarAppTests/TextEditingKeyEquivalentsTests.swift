import AppKit
import Testing
@testable import QuotaBarApp

@Suite("Text editing key equivalents")
struct TextEditingKeyEquivalentsTests {
    @Test("⌘V is recognized even when Caps Lock is on")
    @MainActor
    func pasteIgnoresCapsLock() throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .capsLock],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "v",
                charactersIgnoringModifiers: "v",
                isARepeat: false,
                keyCode: 9
            )
        )
        #expect(TextEditingKeyEquivalents.command(from: event) == .paste)
    }

    @Test("option or shift chords are not treated as paste")
    @MainActor
    func pasteRequiresCommandOnly() throws {
        let optionV = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .option],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "v",
                charactersIgnoringModifiers: "v",
                isARepeat: false,
                keyCode: 9
            )
        )
        #expect(TextEditingKeyEquivalents.command(from: optionV) == nil)
    }

    @Test("paste writes into an empty secure field")
    @MainActor
    func pastesIntoEmptySecureField() {
        let field = NSSecureTextField(string: "")
        TextEditingKeyEquivalents.paste("sk-test-key", into: field)
        #expect(field.stringValue == "sk-test-key")
    }

    @Test("paste inserts at the caret instead of replacing the whole field")
    @MainActor
    func pastesAppendsWhenUnfocused() {
        let field = NSTextField(string: "pre-")
        TextEditingKeyEquivalents.paste("token", into: field)
        #expect(field.stringValue == "pre-token")
    }

    @Test("hidden Edit menu still exposes a paste key equivalent")
    @MainActor
    func editMenuInstallsPasteKeyEquivalent() throws {
        AppEditMenu.installIfNeeded()
        let mainMenu = try #require(NSApp.mainMenu)
        let paste = mainMenu.items
            .flatMap { $0.submenu?.items ?? [] }
            .first { $0.action == #selector(NSText.paste(_:)) }
        #expect(paste != nil)
        #expect(paste?.keyEquivalent == "v")
        #expect(paste?.allowsKeyEquivalentWhenHidden == true)
    }

    @Test("⌘W is recognized as close even when Caps Lock is on")
    @MainActor
    func closeIgnoresCapsLock() throws {
        let event = try #require(
            NSEvent.keyEvent(
                with: .keyDown,
                location: .zero,
                modifierFlags: [.command, .capsLock],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "w",
                charactersIgnoringModifiers: "w",
                isARepeat: false,
                keyCode: 13
            )
        )
        #expect(WindowKeyEquivalents.isClose(event))
    }

    @Test("hidden File menu still exposes a close key equivalent")
    @MainActor
    func fileMenuInstallsCloseKeyEquivalent() throws {
        AppEditMenu.installIfNeeded()
        let mainMenu = try #require(NSApp.mainMenu)
        let close = mainMenu.items
            .flatMap { $0.submenu?.items ?? [] }
            .first { $0.action == #selector(NSWindow.performClose(_:)) }
        #expect(close != nil)
        #expect(close?.keyEquivalent == "w")
        #expect(close?.allowsKeyEquivalentWhenHidden == true)
    }
}

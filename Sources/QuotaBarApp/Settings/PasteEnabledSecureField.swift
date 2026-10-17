import AppKit
import SwiftUI

/// Native line editor that pastes with ⌘V even when SwiftUI's SecureField /
/// TextField is sitting in an accessory settings window. The field editor is
/// the first responder while typing, so paste is applied there rather than on
/// the NSTextField wrapper.
struct PasteEnabledSecureField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> PasteEnabledLineFieldCoordinator {
        PasteEnabledLineFieldCoordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = CommandVPasteSecureTextField()
        configure(field, placeholder: placeholder, coordinator: context.coordinator)
        return field
    }

    func updateNSView(_ view: NSSecureTextField, context: Context) {
        context.coordinator.text = $text
        if view.stringValue != text { view.stringValue = text }
        view.placeholderString = placeholder
    }
}

struct PasteEnabledPlainField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String

    func makeCoordinator() -> PasteEnabledLineFieldCoordinator {
        PasteEnabledLineFieldCoordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = CommandVPasteTextField()
        configure(field, placeholder: placeholder, coordinator: context.coordinator)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        return field
    }

    func updateNSView(_ view: NSTextField, context: Context) {
        context.coordinator.text = $text
        if view.stringValue != text { view.stringValue = text }
        view.placeholderString = placeholder
    }
}

final class PasteEnabledLineFieldCoordinator: NSObject, NSTextFieldDelegate {
    var text: Binding<String>
    init(text: Binding<String>) { self.text = text }
    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        text.wrappedValue = field.stringValue
    }
}

@MainActor
private func configure(_ field: NSTextField, placeholder: String, coordinator: PasteEnabledLineFieldCoordinator) {
    field.placeholderString = placeholder
    field.delegate = coordinator
    field.font = field.font ?? .systemFont(ofSize: 12)
    field.bezelStyle = .roundedBezel
    field.focusRingType = .default
    field.isEditable = true
    field.isSelectable = true
    field.refusesFirstResponder = false
    field.setContentHuggingPriority(.defaultLow, for: .horizontal)
    field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
}

private final class CommandVPasteSecureTextField: NSSecureTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if TextEditingKeyEquivalents.pasteIfNeeded(event, into: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

private final class CommandVPasteTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if TextEditingKeyEquivalents.pasteIfNeeded(event, into: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

import AppKit
import SwiftUI

// MARK: - Liquid Glass chrome
//
// Window and cards use macOS 27 regular glass (frosted, not crystal-clear).
// Interactive glass is required so controls sitting on the material respond
// to pointer and keyboard. Intensity is fixed — there is no user control.
// Reduce Transparency falls back to an opaque fill. Do not set `tintColor`
// on `NSGlassEffectView`: compositing treats a tint as a solid wash and
// kills the glass.

@MainActor
enum FrostedGlassChrome {
    static let settingsWindowStyleMask: NSWindow.StyleMask = [
        .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView
    ]

    static let glassStyle: NSGlassEffectView.Style = .regular
    static let cardGlass: Glass = .regular.interactive()

    static func apply(to window: NSWindow) {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
    }

    static func prepareHostingView(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    /// Window-sized backdrop. Layout is driven by the window, never by SwiftUI's
    /// intrinsic size — the inner hosting view is pinned to this container.
    static func makeBackdrop(
        embedding content: NSView,
        cornerRadius: CGFloat = 0,
        interactive: Bool = true
    ) -> NSView {
        let root = FrostedGlassRootView()
        prepareHostingView(content)

        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            root.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            pin(content, to: root)
            return root
        }

        let glass = NSGlassEffectView()
        glass.style = glassStyle
        glass.cornerRadius = cornerRadius
        glass.effectIsInteractive = interactive
        glass.contentView = content
        pin(glass, to: root)
        return root
    }

    static func pin(_ child: NSView, to parent: NSView) {
        child.translatesAutoresizingMaskIntoConstraints = false
        if child.superview !== parent {
            parent.addSubview(child)
        }
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            child.topAnchor.constraint(equalTo: parent.topAnchor),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
        child.setContentHuggingPriority(.defaultLow, for: .horizontal)
        child.setContentHuggingPriority(.defaultLow, for: .vertical)
        child.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        child.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
}

/// Transparent container so the glass can sample content behind the window.
final class FrostedGlassRootView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isOpaque: Bool { false }
}

@MainActor
final class FrostedGlassHostingController<Content: View>: NSViewController {
    let hostingController: NSHostingController<Content>

    init(rootView: Content, sizingOptions: NSHostingSizingOptions) {
        self.hostingController = NSHostingController(rootView: rootView)
        super.init(nibName: nil, bundle: nil)
        hostingController.sizingOptions = sizingOptions
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        FrostedGlassChrome.prepareHostingView(hostingController.view)
        view = FrostedGlassChrome.makeBackdrop(embedding: hostingController.view)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        FrostedGlassChrome.prepareHostingView(hostingController.view)
    }
}

// MARK: - SwiftUI surfaces

struct FrostedGlassFill: NSViewRepresentable {
    var cornerRadius: CGFloat = 0
    var interactive: Bool = true

    func makeNSView(context: Context) -> NSView {
        FrostedGlassChrome.makeBackdrop(
            embedding: NSView(),
            cornerRadius: cornerRadius,
            interactive: interactive
        )
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct FrostedGlassCardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Branding.radiusMenu, style: .continuous)
            .fill(Branding.controlSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Branding.radiusMenu, style: .continuous)
                    .stroke(Branding.controlStroke, lineWidth: 1)
            )
    }
}

private struct FrostedGlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shaped = content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)

        if reduceTransparency {
            shaped.background { FrostedGlassCardBackground() }
        } else {
            shaped.glassEffect(
                FrostedGlassChrome.cardGlass,
                in: RoundedRectangle(cornerRadius: Branding.radiusMenu, style: .continuous)
            )
        }
    }
}

extension View {
    func frostedGlassCard() -> some View {
        modifier(FrostedGlassCardModifier())
    }

    /// Flatten glyphs so Liquid Glass vibrancy cannot wash calibrated ink
    /// into the wallpaper. Halo polarity follows the current scheme.
    func glassLegibleInk() -> some View {
        modifier(GlassLegibleInkModifier())
    }
}

private struct GlassLegibleInkModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .shadow(
                color: colorScheme == .dark
                    ? Color.black.opacity(0.55)
                    : Color.white.opacity(0.42),
                radius: colorScheme == .dark ? 1.1 : 0.8,
                y: 0.3
            )
    }
}

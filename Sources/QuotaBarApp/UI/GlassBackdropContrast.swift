import AppKit
import SwiftUI

/// Average wallpaper luminance behind a glass window, so ink can flip
/// between dark and light when the desktop is much brighter or darker
/// than the system appearance.
enum GlassBackdropLuminance {
    static let darkInterfaceThreshold: CGFloat = 0.48

    static func luminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    static func prefersDarkInterface(luminance: CGFloat) -> Bool {
        luminance < darkInterfaceThreshold
    }

    @MainActor
    static func sample(behind window: NSWindow) -> CGFloat? {
        guard let screen = window.screen,
              let url = NSWorkspace.shared.desktopImageURL(for: screen) else {
            return nil
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              !isDirectory.boolValue,
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        let source = wallpaperRect(
            windowFrame: window.frame,
            screenFrame: screen.frame,
            imageSize: image.size
        )
        return averageLuminance(of: image, from: source)
    }

    static func wallpaperRect(
        windowFrame: NSRect,
        screenFrame: NSRect,
        imageSize: NSSize
    ) -> NSRect {
        let bounds = NSRect(origin: .zero, size: imageSize)
        guard screenFrame.width > 1, screenFrame.height > 1,
              imageSize.width > 1, imageSize.height > 1 else {
            return bounds
        }
        let mapped = NSRect(
            x: (windowFrame.minX - screenFrame.minX) * (imageSize.width / screenFrame.width),
            y: (windowFrame.minY - screenFrame.minY) * (imageSize.height / screenFrame.height),
            width: windowFrame.width * (imageSize.width / screenFrame.width),
            height: windowFrame.height * (imageSize.height / screenFrame.height)
        )
        let clipped = mapped.intersection(bounds)
        if clipped.width < 8 || clipped.height < 8 {
            return bounds
        }
        return clipped
    }

    static func averageLuminance(of image: NSImage, from sourceRect: NSRect? = nil) -> CGFloat? {
        let width = 16
        let height = 16
        let from: NSRect = {
            if let sourceRect, sourceRect.width > 1, sourceRect.height > 1 {
                return sourceRect
            }
            return NSRect(origin: .zero, size: image.size)
        }()
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .medium
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: from,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        var total: CGFloat = 0
        var count: CGFloat = 0
        for y in 0..<height {
            for x in 0..<width {
                let color = bitmap.colorAt(x: x, y: y) ?? .clear
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                if alpha < 0.05 { continue }
                total += luminance(red: red, green: green, blue: blue)
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return total / count
    }
}

struct GlassBackdropSampler: NSViewRepresentable {
    @Binding var prefersDarkInterface: Bool?

    func makeNSView(context: Context) -> GlassBackdropSamplingView {
        let view = GlassBackdropSamplingView()
        view.onChange = { prefersDarkInterface = $0 }
        return view
    }

    func updateNSView(_ nsView: GlassBackdropSamplingView, context: Context) {
        nsView.onChange = { prefersDarkInterface = $0 }
    }
}

final class GlassBackdropSamplingView: NSView {
    var onChange: ((Bool) -> Void)?
    private var lastValue: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let window {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resample),
                name: NSWindow.didMoveNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resample),
                name: NSWindow.didResizeNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resample),
                name: NSWindow.didBecomeKeyNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resample),
                name: NSWindow.didChangeScreenNotification,
                object: window
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(resample),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(resample),
                name: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil
            )
        }
        resample()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func resample() {
        guard let window, let luminance = GlassBackdropLuminance.sample(behind: window) else {
            return
        }
        let prefersDark = GlassBackdropLuminance.prefersDarkInterface(luminance: luminance)
        let appearance = NSAppearance(named: prefersDark ? .darkAqua : .aqua)
        if window.appearance?.name != appearance?.name {
            window.appearance = appearance
        }
        guard lastValue != prefersDark else { return }
        lastValue = prefersDark
        onChange?(prefersDark)
    }
}

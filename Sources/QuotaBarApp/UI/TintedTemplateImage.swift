import AppKit

// MARK: - Menu bar contrast
//
// The menu bar is translucent: its "dark" vs "light" look comes from the
// wallpaper behind it, not from the app's appearance. `NSStatusBarButton`
// tracks that contrast in `effectiveAppearance`. Custom subviews do not,
// so callers must copy the button appearance onto the content view and
// tint glyphs from that appearance.

enum MenuBarContrast {
    static func isDark(_ appearance: NSAppearance) -> Bool {
        let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
        return match == .darkAqua || match == .vibrantDark
    }

    /// Black on a light menu bar, white on a dark one.
    static func inkColor(in appearance: NSAppearance) -> NSColor {
        let fallback: NSColor = isDark(appearance) ? .white : .black
        var color = fallback
        appearance.performAsCurrentDrawingAppearance {
            color = NSColor.labelColor.usingColorSpace(.deviceRGB) ?? fallback
        }
        return color
    }
}

enum TintedTemplateImage {
    static func resolvedRGBColor(_ color: NSColor, in appearance: NSAppearance? = nil) -> NSColor {
        var resolved = color
        let apply = {
            if let rgb = color.usingColorSpace(.deviceRGB) {
                resolved = rgb
            }
        }
        if let appearance {
            appearance.performAsCurrentDrawingAppearance(apply)
        } else {
            apply()
        }
        return resolved
    }

    /// Recolor an alpha-based (or luminance-based) glyph while keeping its shape.
    static func rasterized(from image: NSImage, size: CGFloat, color: NSColor) -> NSImage {
        guard let source = bitmapRepresentation(of: image) else {
            return templateCopy(image, size: size)
        }

        let resolvedColor = resolvedRGBColor(color)

        if source.hasAlpha, let tinted = compositeTintedIcon(source: source, size: size, color: resolvedColor) {
            return tinted
        }

        return perPixelLuminanceIcon(source: source, size: size, color: resolvedColor)
            ?? templateCopy(image, size: size)
    }

    /// macOS 27 no longer reliably produces TIFF from some NSImage backends.
    /// Prefer existing bitmap reps, then CGImage, then drawing into a bitmap.
    static func bitmapRepresentation(of image: NSImage) -> NSBitmapImageRep? {
        if let existing = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
           existing.pixelsWide > 0, existing.pixelsHigh > 0 {
            return existing
        }

        var proposed = NSRect(origin: .zero, size: image.size)
        if proposed.width < 1 || proposed.height < 1 {
            if let rep = image.representations.first {
                proposed.size = NSSize(
                    width: CGFloat(max(1, rep.pixelsWide)),
                    height: CGFloat(max(1, rep.pixelsHigh))
                )
            } else {
                proposed.size = NSSize(width: 16, height: 16)
            }
        }

        if let cgImage = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil) {
            return NSBitmapImageRep(cgImage: cgImage)
        }

        let width = max(1, Int(round(proposed.width)))
        let height = max(1, Int(round(proposed.height)))
        guard let output = makeOutputRep(width: width, height: height),
              let context = NSGraphicsContext(bitmapImageRep: output) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(x: 0, y: 0, width: width, height: height),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return output
    }

    private static func templateCopy(_ image: NSImage, size: CGFloat) -> NSImage {
        let fallback = image.copy() as? NSImage ?? image
        fallback.size = NSSize(width: size, height: size)
        fallback.isTemplate = true
        return fallback
    }

    private static func compositeTintedIcon(source: NSBitmapImageRep, size: CGFloat, color: NSColor) -> NSImage? {
        guard let output = makeOutputRep(width: source.pixelsWide, height: source.pixelsHigh),
              let context = NSGraphicsContext(bitmapImageRep: output) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let rect = NSRect(x: 0, y: 0, width: source.pixelsWide, height: source.pixelsHigh)
        source.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        let rendered = NSImage(size: NSSize(width: size, height: size))
        rendered.addRepresentation(output)
        rendered.isTemplate = false
        return rendered
    }

    private static func perPixelLuminanceIcon(source: NSBitmapImageRep, size: CGFloat, color: NSColor) -> NSImage? {
        guard let output = makeOutputRep(width: source.pixelsWide, height: source.pixelsHigh) else {
            return nil
        }

        for y in 0 ..< source.pixelsHigh {
            for x in 0 ..< source.pixelsWide {
                guard let pixel = source.colorAt(x: x, y: y),
                      let rgb = pixel.usingColorSpace(.deviceRGB) else {
                    output.setColor(.clear, atX: x, y: y)
                    continue
                }

                let alpha = alphaFromLuminance(red: rgb.redComponent, green: rgb.greenComponent, blue: rgb.blueComponent)
                output.setColor(
                    NSColor(
                        deviceRed: color.redComponent,
                        green: color.greenComponent,
                        blue: color.blueComponent,
                        alpha: alpha * color.alphaComponent
                    ),
                    atX: x,
                    y: y
                )
            }
        }

        let rendered = NSImage(size: NSSize(width: size, height: size))
        rendered.addRepresentation(output)
        rendered.isTemplate = false
        return rendered
    }

    private static func makeOutputRep(width: Int, height: Int) -> NSBitmapImageRep? {
        NSBitmapImageRep(
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
        )
    }

    private static func alphaFromLuminance(red: CGFloat, green: CGFloat, blue: CGFloat) -> CGFloat {
        let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
        if luminance <= 0.08 { return 0 }
        if luminance >= 0.26 { return 1 }
        return (luminance - 0.08) / 0.18
    }
}

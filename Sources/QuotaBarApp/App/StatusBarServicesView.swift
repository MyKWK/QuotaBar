import AppKit

// MARK: - Menu bar capsule rendering
//
// Draw one "Logo 100%" capsule per enabled service into a bitmap assigned to
// `NSStatusBarButton.image`. A live Auto Layout tree inside the status item
// makes AppKit's replicant snapshot (`_updateReplicants`) relayout and redraw
// in a tight loop on macOS 26+, pegging a CPU core.

@MainActor
enum ServiceLogoImage {
    private static var cache: [String: NSImage] = [:]

    static func image(for service: ServiceKind, size: CGFloat, color: NSColor) -> NSImage {
        let resolvedColor = TintedTemplateImage.resolvedRGBColor(color)
        let key = [
            service.rawValue,
            String(format: "%.2f", size),
            String(format: "%.3f", resolvedColor.redComponent),
            String(format: "%.3f", resolvedColor.greenComponent),
            String(format: "%.3f", resolvedColor.blueComponent),
            String(format: "%.3f", resolvedColor.alphaComponent)
        ].joined(separator: "-")

        if let cached = cache[key] {
            return cached
        }

        let source: NSImage
        if let url = AppResourceLocator.url(
            forResource: service.logoResourceName,
            withExtension: "png",
            subdirectory: "Logos"
        ), let loaded = NSImage(contentsOf: url) {
            source = loaded
        } else {
            source = NSImage(size: NSSize(width: size, height: size))
        }

        let image = TintedTemplateImage.rasterized(from: source, size: size, color: resolvedColor)
        cache[key] = image
        return image
    }
}

@MainActor
struct StatusBarServicesDisplay: Equatable {
    let items: [StatusBarServiceEntry]

    var contentWidth: CGFloat {
        StatusBarServicesRenderer.contentWidth(for: items)
    }

    var preferredStatusItemLength: CGFloat {
        StatusBarServicesRenderer.preferredStatusItemLength(for: items)
    }
}

@MainActor
enum StatusBarServicesRenderer {
    static let preferredHeight: CGFloat = 22
    static let contentHorizontalInset: CGFloat = 2
    static let interItemSpacing: CGFloat = 4
    static let logoSize: CGFloat = 13
    static let fallbackIconSize: CGFloat = 17
    static let textFont = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
    static let logoTextSpacing: CGFloat = 3
    static let capsuleHorizontalPadding: CGFloat = 4

    static func contentWidth(for items: [StatusBarServiceEntry]) -> CGFloat {
        let itemWidths = items.map(itemWidth(for:)).reduce(0, +)
        let spacing = CGFloat(max(items.count - 1, 0)) * interItemSpacing
        return ceil(contentHorizontalInset * 2 + itemWidths + spacing)
    }

    static func preferredStatusItemLength(for items: [StatusBarServiceEntry]) -> CGFloat {
        guard !items.isEmpty else { return NSStatusItem.squareLength }
        return max(NSStatusItem.squareLength, contentWidth(for: items) + 4)
    }

    static func itemWidth(for item: StatusBarServiceEntry) -> CGFloat {
        let textWidth = item.text.size(withAttributes: [.font: textFont]).width
        return ceil(
            capsuleHorizontalPadding * 2
                + logoSize
                + logoTextSpacing
                + textWidth
        )
    }

    static func textColor(for item: StatusBarServiceEntry) -> NSColor {
        guard item.hasData else { return .labelColor }
        switch item.level {
        case .exhausted:
            return .systemRed
        case .low:
            return .systemOrange
        case .normal:
            return .labelColor
        }
    }

    /// Rasterize once. Replicants must blit pixels, not invoke a drawing handler.
    static func makeImage(
        display: StatusBarServicesDisplay?,
        fallbackIcon: NSImage,
        appearance: NSAppearance,
        scale: CGFloat
    ) -> NSImage {
        let items = display?.items ?? []
        let width = items.isEmpty
            ? fallbackIconSize + contentHorizontalInset * 2
            : contentWidth(for: items)
        let height = preferredHeight
        let clampedScale = max(scale, 1)
        let pixelsWide = max(1, Int((width * clampedScale).rounded(.up)))
        let pixelsHigh = max(1, Int((height * clampedScale).rounded(.up)))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return fallbackIcon
        }
        rep.size = NSSize(width: width, height: height)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return fallbackIcon
        }
        NSGraphicsContext.current = context
        NSGraphicsContext.current?.imageInterpolation = .high

        appearance.performAsCurrentDrawingAppearance {
            draw(
                items: items,
                fallbackIcon: fallbackIcon,
                appearance: appearance,
                size: NSSize(width: width, height: height),
                scale: clampedScale
            )
        }
        context.flushGraphics()

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        image.isTemplate = false
        image.cacheMode = .never
        return image
    }

    private static func draw(
        items: [StatusBarServiceEntry],
        fallbackIcon: NSImage,
        appearance: NSAppearance,
        size: NSSize,
        scale: CGFloat
    ) {
        let ink = MenuBarContrast.inkColor(in: appearance)
        if items.isEmpty {
            let tinted = TintedTemplateImage.rasterized(from: fallbackIcon, size: fallbackIconSize, color: ink)
            tinted.draw(
                in: NSRect(
                    x: (size.width - fallbackIconSize) / 2,
                    y: (size.height - fallbackIconSize) / 2,
                    width: fallbackIconSize,
                    height: fallbackIconSize
                ),
                from: .zero,
                operation: .sourceOver,
                fraction: 1
            )
            return
        }

        var x = contentHorizontalInset
        for (index, item) in items.enumerated() {
            if index > 0 {
                x += interItemSpacing
            }
            x += drawCapsule(item, originX: x, height: size.height, ink: ink, scale: scale)
        }
    }

    private static func drawCapsule(
        _ item: StatusBarServiceEntry,
        originX: CGFloat,
        height: CGFloat,
        ink: NSColor,
        scale: CGFloat
    ) -> CGFloat {
        let width = itemWidth(for: item)
        var x = originX + capsuleHorizontalPadding
        let logo = ServiceLogoImage.image(for: item.service, size: logoSize * scale, color: ink)
        logo.draw(
            in: NSRect(
                x: x,
                y: (height - logoSize) / 2,
                width: logoSize,
                height: logoSize
            ),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        x += logoSize + logoTextSpacing

        var color = textColor(for: item)
        if !item.hasData {
            color = color.withAlphaComponent(color.alphaComponent * 0.5)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: color
        ]
        let textSize = item.text.size(withAttributes: attributes)
        item.text.draw(
            at: NSPoint(x: x, y: (height - textSize.height) / 2),
            withAttributes: attributes
        )
        return width
    }
}

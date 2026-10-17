import AppKit
import Testing
@testable import QuotaBarApp

@Suite("App resources")
struct AppResourceLocatorTests {
    @Test("tool logos load from packaged resources")
    func toolLogosLoadFromPackagedResources() throws {
        for name in ["codex", "cursor", "claude"] {
            let url = try #require(AppResourceLocator.url(forResource: name, withExtension: "png", subdirectory: "Logos"))
            #expect(NSImage(contentsOf: url) != nil)
        }
    }

    @Test("every service logo loads from packaged resources")
    func serviceLogosLoadFromPackagedResources() throws {
        for service in ServiceKind.allCases {
            let url = try #require(
                AppResourceLocator.url(
                    forResource: service.logoResourceName,
                    withExtension: "png",
                    subdirectory: "Logos"
                )
            )
            #expect(NSImage(contentsOf: url) != nil)
        }
    }

    @Test("DeepSeek logo is the official whale mark, not a letter badge")
    func deepSeekLogoIsOfficialWhale() throws {
        let url = try #require(
            AppResourceLocator.url(forResource: "deepseek", withExtension: "png", subdirectory: "Logos")
        )
        let image = try #require(NSImage(contentsOf: url))
        let representation = try #require(TintedTemplateImage.bitmapRepresentation(of: image))
        #expect(representation.pixelsWide >= 128)
        #expect(representation.pixelsHigh >= 128)
        #expect(representation.hasAlpha)

        let corner = representation.colorAt(x: 0, y: 0)
        #expect((corner?.alphaComponent ?? 1) < 0.05)

        let midX = representation.pixelsWide / 2
        let midY = representation.pixelsHigh / 2
        var opaqueBody = 0
        var transparentHole = 0
        for y in (midY - 8)..<(midY + 8) {
            for x in (midX - 24)..<(midX - 8) {
                let alpha = representation.colorAt(x: x, y: y)?.alphaComponent ?? 0
                if alpha > 0.5 {
                    opaqueBody += 1
                } else if alpha < 0.05 {
                    transparentHole += 1
                }
            }
        }
        #expect(opaqueBody > 20)
        #expect(transparentHole > 20)
    }

    @MainActor
    @Test("status bar tool logos render visible pixels")
    func statusBarToolLogosRenderVisiblePixels() throws {
        for tool in ToolKind.allCases {
            let image = StatusBarToolLogoImageCache.image(for: tool, size: 16, color: .white)
            let representation = try #require(TintedTemplateImage.bitmapRepresentation(of: image))
            var visiblePixels = 0

            for y in 0 ..< representation.pixelsHigh {
                for x in 0 ..< representation.pixelsWide {
                    if (representation.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                        visiblePixels += 1
                    }
                }
            }

            #expect(visiblePixels > 0)
        }
    }
}

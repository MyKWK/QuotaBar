import Foundation

enum AppResourceLocator {
    /// Anchors `Bundle(for:)` to this module's binary so we can locate the
    /// SwiftPM resource bundle in dev/test builds.
    private final class BundleToken {}

    private static let resourceBundleName = "QuotaBar_QuotaBarApp.bundle"

    static func url(
        forResource name: String,
        withExtension resourceExtension: String,
        subdirectory: String? = nil
    ) -> URL? {
        let fileName = "\(name).\(resourceExtension)"
        let fileManager = FileManager.default

        // Deliberately avoid `Bundle.module`: SwiftPM's generated accessor only
        // probes the app-root and the compile-time `.build` path and calls
        // `fatalError` when both miss, which crashes the packaged app (where the
        // resource bundle lives in `Contents/Resources`). These lookups never
        // trap on access.
        return candidateURLs(
            name: name,
            resourceExtension: resourceExtension,
            subdirectory: subdirectory,
            fileName: fileName
        )
        .first { fileManager.fileExists(atPath: $0.path) }
    }

    private static func candidateURLs(
        name: String,
        resourceExtension: String,
        subdirectory: String?,
        fileName: String
    ) -> [URL] {
        var results: [URL] = []
        var seen = Set<String>()
        func append(_ url: URL?) {
            guard let url else { return }
            if seen.insert(url.standardizedFileURL.path).inserted {
                results.append(url)
            }
        }

        let searchBundles = [Bundle.main, Bundle(for: BundleToken.self)] + nestedResourceBundles()
        for bundle in searchBundles {
            append(bundle.url(forResource: name, withExtension: resourceExtension, subdirectory: subdirectory))
            append(bundle.url(forResource: name, withExtension: resourceExtension))
        }

        for root in searchRoots() {
            for url in filesInResourceBundle(root: root, subdirectory: subdirectory, fileName: fileName) {
                append(url)
            }
            for url in filesInResourceBundle(root: root, subdirectory: nil, fileName: fileName) {
                append(url)
            }
        }

        return results
    }

    private static func nestedResourceBundles() -> [Bundle] {
        searchRoots().compactMap { root in
            let url = root.appendingPathComponent(resourceBundleName, isDirectory: true)
            return Bundle(url: url)
        }
    }

    private static func searchRoots() -> [URL] {
        let searchBundles = [Bundle.main, Bundle(for: BundleToken.self)]
        let fromBundles: [URL] = searchBundles.flatMap { bundle -> [URL] in
            [
                bundle.resourceURL,
                bundle.bundleURL,
                // Classic `swift test`: resource bundle sits beside the `.xctest`.
                bundle.bundleURL.deletingLastPathComponent()
            ].compactMap { $0 }
        }
        let packagedAppResources = Bundle.main.executableURL
            .map {
                $0.deletingLastPathComponent() // Contents/MacOS
                    .deletingLastPathComponent() // Contents
                    .appendingPathComponent("Resources", isDirectory: true)
            }

        var results: [URL] = []
        var seen = Set<String>()
        for url in fromBundles + [packagedAppResources].compactMap({ $0 }) {
            if seen.insert(url.standardizedFileURL.path).inserted {
                results.append(url)
            }
        }
        return results
    }

    private static func filesInResourceBundle(
        root: URL,
        subdirectory: String?,
        fileName: String
    ) -> [URL] {
        let bundleRoot = root.appendingPathComponent(resourceBundleName, isDirectory: true)
        // Xcode 27 / native SwiftPM emits a real bundle with Contents/Resources.
        // Older SwiftPM layouts flatten files at the .bundle root.
        let resourceRoots = [
            bundleRoot.appendingPathComponent("Contents/Resources", isDirectory: true),
            bundleRoot
        ]
        var candidates: [URL] = []
        for resourceRoot in resourceRoots {
            if let subdirectory {
                candidates.append(
                    resourceRoot
                        .appendingPathComponent(subdirectory, isDirectory: true)
                        .appendingPathComponent(fileName)
                )
            }
            candidates.append(resourceRoot.appendingPathComponent(fileName))
        }
        return candidates
    }
}

import AppKit

enum BrandAssets {
    static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false  // Icon is already white
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        // Fallback: use system symbol with white configuration
        guard let fallback = NSImage(
            systemSymbolName: "square.grid.3x3.fill",
            accessibilityDescription: "Port Monitor"
        ) else {
            return nil
        }

        let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [.white])
            .applying(.init(pointSize: 18, weight: .medium))

        let configuredImage = fallback.withSymbolConfiguration(whiteConfig)
        configuredImage?.size = NSSize(width: 18, height: 18)
        return configuredImage
    }

    static func glyphImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }

        let fallback = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Port Monitor")
        fallback?.isTemplate = true
        return fallback
    }
}

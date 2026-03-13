import AppKit

enum BrandAssets {
    static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            // Use a template image for menu bar so the system can tint it appropriately.
            image.isTemplate = true
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

        // Return a template symbol sized for the menu bar.
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let configuredImage = fallback.withSymbolConfiguration(config)
        configuredImage?.isTemplate = true
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

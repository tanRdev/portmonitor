import AppKit

enum BrandAssets {
    static func menuBarIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        let fallback = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "Port Monitor")
        fallback?.isTemplate = true
        fallback?.size = NSSize(width: 18, height: 18)
        return fallback
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

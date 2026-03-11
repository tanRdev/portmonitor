#!/usr/bin/env swift

import Cocoa

func generateIcon(size: Int, scale: Int = 1) -> NSImage {
    let pixelSize = size * scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()

    // White background
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

    // Draw network symbol in black
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.5, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "network", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let symbolRect = NSRect(
            x: (CGFloat(pixelSize) - symbolSize.width) / 2,
            y: (CGFloat(pixelSize) - symbolSize.height) / 2,
            width: symbolSize.width,
            height: symbolSize.height
        )

        // Draw in black
        NSColor.black.set()
        symbol.draw(in: symbolRect)
    }

    image.unlockFocus()

    return image
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG data")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate all icon sizes
let sizes = [16, 32, 128, 256, 512]
let outputDir = "PortMonitor/Assets/Assets.xcassets/AppIcon.appiconset"

for size in sizes {
    // 1x
    let icon1x = generateIcon(size: size, scale: 1)
    saveImage(icon1x, to: "\(outputDir)/icon_\(size)x\(size).png")

    // 2x
    let icon2x = generateIcon(size: size, scale: 2)
    saveImage(icon2x, to: "\(outputDir)/icon_\(size)x\(size)@2x.png")
}

print("Icon generation complete!")

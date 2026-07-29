#!/usr/bin/env swift

import Cocoa

let sourcePath = "assets/app-icon-source.png"

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    fputs("Unable to load authoritative icon source at \(sourcePath)\n", stderr)
    exit(1)
}

func generateIcon(size: Int, scale: Int = 1) -> NSImage {
    let pixelSize = size * scale
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
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

import AppKit

final class MenuBarPanel: NSPanel {
    static func make(contentRect: NSRect) -> MenuBarPanel {
        let panel = MenuBarPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

enum MenuBarPanelPositioning {
    static func origin(buttonFrame: NSRect, panelSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        let horizontalPadding: CGFloat = 8
        let verticalOffset: CGFloat = 6
        let centeredX = buttonFrame.midX - (panelSize.width / 2)
        let clampedX = min(
            max(visibleFrame.minX + horizontalPadding, centeredX),
            visibleFrame.maxX - panelSize.width - horizontalPadding
        )

        return NSPoint(
            x: clampedX,
            y: buttonFrame.minY - panelSize.height - verticalOffset
        )
    }
}

@MainActor
enum StatusItemButtonStyle {
    static func apply(to button: NSButton, highlighted: Bool) {
        button.wantsLayer = true
        button.layer?.cornerRadius = 7
        button.layer?.masksToBounds = true
        button.layer?.backgroundColor = highlighted
            ? NSColor.selectedContentBackgroundColor.withAlphaComponent(0.28).cgColor
            : nil
    }
}

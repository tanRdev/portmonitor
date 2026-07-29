import AppKit
import SwiftUI

final class MenuBarPanel: NSPanel {
    static func make(contentRect: NSRect) -> MenuBarPanel {
        let panel = MenuBarPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        return panel
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

enum MenuBarPanelPositioning {
    private static let horizontalPadding: CGFloat = 8

    static func isUsableStatusItemFrame(
        _ buttonFrame: NSRect,
        screenFrame: NSRect,
        visibleFrame: NSRect
    ) -> Bool {
        guard
            buttonFrame.width > 0,
            buttonFrame.height > 0,
            buttonFrame.midX >= screenFrame.minX,
            buttonFrame.midX <= screenFrame.maxX
        else {
            return false
        }

        // AppKit briefly reports the status-item window at the global origin
        // while macOS is still laying out the menu bar. A real status item sits
        // in the strip above the screen's visible work area.
        return buttonFrame.midY >= visibleFrame.maxY
            && buttonFrame.midY <= screenFrame.maxY
    }

    static func origin(
        buttonFrame: NSRect,
        panelSize: NSSize,
        visibleFrame: NSRect
    ) -> NSPoint {
        let desiredX = buttonFrame.midX - (panelSize.width / 2)
        let minimumX = visibleFrame.minX + horizontalPadding
        let maximumX = max(visibleFrame.maxX - panelSize.width - horizontalPadding, minimumX)
        let x = min(max(desiredX, minimumX), maximumX)

        let desiredY = buttonFrame.minY - panelSize.height
        let minimumY = visibleFrame.minY + horizontalPadding
        let maximumY = max(visibleFrame.maxY - panelSize.height, minimumY)
        let y = min(max(desiredY, minimumY), maximumY)

        return NSPoint(x: x, y: y)
    }
}

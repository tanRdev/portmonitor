import AppKit
import Testing
@testable import PortMonitor

struct MenuBarPanelPositioningTests {
    private let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 875)
    private let screenFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let panelSize = NSSize(width: 340, height: 360)

    // MARK: - origin clamping

    @Test
    func originClampsPanelInsideVisibleFrameOnRightEdge() {
        let buttonFrame = NSRect(x: 1408, y: 875, width: 32, height: 25)

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrame,
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x + panelSize.width <= visibleFrame.maxX - 8)
        #expect(origin.x == visibleFrame.maxX - panelSize.width - 8)
    }

    @Test
    func originClampsPanelInsideVisibleFrameOnLeftEdge() {
        let buttonFrame = NSRect(x: 0, y: 875, width: 32, height: 25)

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrame,
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x == visibleFrame.minX + 8)
    }

    @Test
    func originNeverDropsBelowVisibleFrameWhenPanelIsTallerThanWorkArea() {
        let tallPanel = NSSize(width: 340, height: 2000)
        let buttonFrame = NSRect(x: 700, y: 875, width: 32, height: 25)

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrame,
            panelSize: tallPanel,
            visibleFrame: visibleFrame
        )

        #expect(origin.y == visibleFrame.minY + 8)
    }

    @Test
    func originRespectsVisibleFrameOffsetOnSecondaryDisplays() {
        let secondaryVisible = NSRect(x: -1440, y: 0, width: 1440, height: 875)
        let buttonFrame = NSRect(x: -1424, y: 875, width: 32, height: 25)

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrame,
            panelSize: panelSize,
            visibleFrame: secondaryVisible
        )

        #expect(origin.x == secondaryVisible.minX + 8)
        #expect(origin.y + panelSize.height == buttonFrame.minY)
    }

    // MARK: - isUsableStatusItemFrame

    @Test
    func statusItemFrameIsUsableWhenAnchoredInMenuBarStrip() {
        let usable = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1408, y: 876, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(usable)
    }

    @Test
    func statusItemFrameRejectsZeroSizeFrames() {
        let zeroWidth = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1408, y: 876, width: 0, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
        let zeroHeight = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1408, y: 876, width: 24, height: 0),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(zeroWidth == false)
        #expect(zeroHeight == false)
    }

    @Test
    func statusItemFrameRejectsFramesOutsideScreenHorizontally() {
        let offRight = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 2000, y: 876, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
        let offLeft = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: -100, y: 876, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(offRight == false)
        #expect(offLeft == false)
    }

    @Test
    func statusItemFrameRejectsFramesBelowTheMenuBarStrip() {
        // AppKit briefly reports the status-item window at the global origin
        // while the menu bar is still laying out.
        let atGlobalOrigin = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 8, y: 0, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
        let inWorkArea = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1408, y: 400, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(atGlobalOrigin == false)
        #expect(inWorkArea == false)
    }

    @Test
    func statusItemFrameRejectsFramesAboveTheScreen() {
        let aboveScreen = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1408, y: 950, width: 24, height: 24),
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )

        #expect(aboveScreen == false)
    }
}

import AppKit
import SwiftUI
import Testing
@testable import PortMonitor

@MainActor
struct ViewLayoutTests {
    @Test
    func brandGlyphFallbackUsesTemplateImage() {
        let glyph = BrandAssets.glyphImage()

        #expect(glyph != nil)
        #expect(glyph?.isTemplate == true)
    }

    @Test
    func menuBarIconUsesTemplateImageAndExpectedSize() {
        let icon = BrandAssets.menuBarIcon()

        #expect(icon != nil)
        #expect(icon?.isTemplate == true)
        #expect(icon?.size == NSSize(width: 18, height: 18))
    }

    @Test
    func menuBarPanelUsesArrowlessFloatingConfiguration() {
        let panel = MenuBarPanel.make(contentRect: NSRect(x: 0, y: 0, width: 332, height: 360))

        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.backgroundColor == .clear)
        #expect(panel.isOpaque == false)
        #expect(panel.level == .statusBar)
    }

    @Test
    func menuBarPanelOriginCentersUnderStatusItem() {
        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: NSRect(x: 700, y: 900, width: 28, height: 22),
            panelSize: NSSize(width: 340, height: 360),
            visibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 900)
        )

        #expect(origin.x == 544.0)
    }

    @Test
    func statusItemHighlightKeepsMinimalChrome() {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 28, height: 28))

        StatusItemButtonStyle.apply(to: button, highlighted: true)

        #expect(button.wantsLayer)
        #expect(button.layer?.cornerRadius == 8)
        #expect(button.layer?.backgroundColor == nil)
        #expect(button.contentTintColor == .white)

        StatusItemButtonStyle.apply(to: button, highlighted: false)

        #expect(button.layer?.backgroundColor == nil)
    }

    @Test
    func portListUsesGlassEffectContainer() {
        let description = String(reflecting: PortListView().body)

        #expect(description.contains("GlassEffectContainer"))
        #expect(description.contains("GlassEffectModifier"))
    }

    @Test
    func portRowShowsOnlyPortProcessAndKillContent() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        let description = String(reflecting: PortRowView(port: port, isKilling: false, onKill: {}).body)

        #expect(description.contains("3000"))
        #expect(description.contains(":3000") == false)
        #expect(description.contains("node"))
        #expect(description.contains("Kill"))
        #expect(description.contains("PID") == false)
        #expect(description.contains("TCP") == false)
    }

    @Test
    func portRowShowsStoppingStateWhileKilling() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        let description = String(reflecting: PortRowView(port: port, isKilling: true, onKill: {}).body)

        #expect(description.contains("Stopping"))
    }

    @Test
    func portRowUsesCompactMenuBarHeight() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        let height = fittingHeight(
            of: PortRowView(port: port, isKilling: false, onKill: {}),
            width: 320
        )

        #expect(height <= 40)
    }

    @Test
    func portRowDefinesFullWidthHoverHitArea() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        let description = String(reflecting: PortRowView(port: port, isKilling: false, onKill: {}).body)

        #expect(description.contains("ContentShape"))
        #expect(description.contains("maxWidth"))
    }

    @Test
    func headerUsesCompactUtilityHeight() {
        let height = fittingHeight(
            of: HeaderView(portCount: 11, onQuit: {}),
            width: 320
        )

        #expect(height <= 44)
    }

    @Test
    func headerOmitsUpdatedStatusText() {
        let description = String(reflecting: HeaderView(portCount: 11, onQuit: {}).body)

        #expect(description.contains("Updated") == false)
    }

    @Test
    func headerUsesPortMonitorNaming() {
        let description = String(reflecting: HeaderView(portCount: 11, onQuit: {}).body)

        #expect(description.contains("Port Monitor"))
    }

    @Test
    func emptyStateUsesCompactUtilityHeight() {
        let height = fittingHeight(
            of: EmptyStateView(lastUpdatedAt: nil),
            width: 320
        )

        #expect(height <= 140)
    }

    @Test
    func loadingStateUsesCompactUtilityHeight() {
        let height = fittingHeight(
            of: LoadingStateView(),
            width: 320
        )

        #expect(height <= 120)
    }

    @Test
    func portListOmitsPermissionDisclaimer() {
        let description = String(reflecting: PortListView().body)

        #expect(description.contains("permission to terminate") == false)
    }
}

@MainActor
private func fittingHeight<Content: View>(of view: Content, width: CGFloat) -> CGFloat {
    let hostingView = NSHostingView(rootView: view.frame(width: width))
    hostingView.frame = NSRect(x: 0, y: 0, width: width, height: 1)
    hostingView.layoutSubtreeIfNeeded()
    return hostingView.fittingSize.height
}

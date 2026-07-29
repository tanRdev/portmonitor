import AppKit
import SwiftUI
import Testing
@testable import PortMonitor

@MainActor
struct ViewLayoutTests {
    private struct TextCollector: LayoutTestVisitor {
        private(set) var strings: [String] = []

        mutating func visit(type: Any.Type) {}

        mutating func visit(value: Any) {
            let mirror = Mirror(reflecting: value)
            if let storage = mirror.children.first(where: { $0.label == "storage" }) {
                let storageChildren = Mirror(reflecting: storage.value).children
                for child in storageChildren where child.label == "verbatim" || child.label == "anyTextStorage" {
                    collectText(from: child.value)
                }
            }
        }

        private mutating func collectText(from value: Any) {
            if let string = value as? String {
                strings.append(string)
                return
            }

            for child in Mirror(reflecting: value).children {
                collectText(from: child.value)
            }
        }
    }

    @MainActor
    private func makeViewModel() -> PortListViewModel {
        PortListViewModel(scanner: StubScanner(), killer: RecordingKiller(), defaults: .standard)
    }

    @Test
    func headerUsesCompactUtilityHeight() {
        let height = IntrinsicSizeProbe.height(of: HeaderView())
        #expect(height > 0)
        #expect(height <= 52)
    }

    @Test
    func portRowUsesCompactUtilityHeight() {
        let port = PortInfo(port: 3000, processName: "node", pid: 42, protocolType: "TCP")
        let height = IntrinsicSizeProbe.height(of: PortRowView(port: port, isKilling: false))
        #expect(height > 0)
        #expect(height <= 40)
    }

    @Test
    func emptyStateUsesCompactUtilityHeight() {
        let height = IntrinsicSizeProbe.height(of: EmptyStateView())
        #expect(height > 0)
        #expect(height <= 140)
    }

    @Test
    func errorBannerUsesCompactUtilityHeight() {
        let height = IntrinsicSizeProbe.height(of: ErrorBannerView(
            message: "Unable to scan ports",
            canForceKill: false,
            onRetry: {},
            onForceKill: {},
            onDismiss: {}
        ))
        #expect(height > 0)
        #expect(height <= 56)
    }

    @Test
    func menuBarPanelUsesArrowlessFloatingConfiguration() {
        let panel = MenuBarPanel.make(contentRect: NSRect(x: 0, y: 0, width: 340, height: 360))
        #expect(panel.isFloatingPanel)
        #expect(panel.level == .statusBar)
        #expect(panel.styleMask.contains(.titled) == false)
        #expect(panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.isOpaque == false)
        #expect(panel.canBecomeKey)
    }

    @Test
    func menuBarPanelPositioningSitsDirectlyBelowMenuBar() {
        let visibleFrame = NSRect(x: 0, y: 0, width: 1440, height: 875)
        let buttonFrame = NSRect(x: 1310, y: 875, width: 32, height: 25)
        let panelSize = NSSize(width: 340, height: 360)

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrame,
            panelSize: panelSize,
            visibleFrame: visibleFrame
        )

        #expect(origin.x >= visibleFrame.minX)
        #expect(origin.x + panelSize.width <= visibleFrame.maxX)
        #expect(origin.y + panelSize.height == buttonFrame.minY)
    }

    @Test
    func menuBarPanelPositioningRejectsStatusItemFrameBeforeMenuBarLayout() {
        let isUsable = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 8, y: -11, width: 22, height: 22),
            screenFrame: NSRect(x: 0, y: 0, width: 1710, height: 1112),
            visibleFrame: NSRect(x: 0, y: 53, width: 1710, height: 1021)
        )

        #expect(isUsable == false)
    }

    @Test
    func menuBarPanelPositioningAcceptsStatusItemFrameAfterMenuBarLayout() {
        let isUsable = MenuBarPanelPositioning.isUsableStatusItemFrame(
            NSRect(x: 1476, y: 1082, width: 22, height: 22),
            screenFrame: NSRect(x: 0, y: 0, width: 1710, height: 1112),
            visibleFrame: NSRect(x: 0, y: 53, width: 1710, height: 1021)
        )

        #expect(isUsable)
    }

    @MainActor
    @Test
    func portListUsesGlassEffectContainer() {
        let view = PortListView(viewModel: makeViewModel())
        let description = String(reflecting: view.body)
        #expect(description.contains("GlassEffectContainer"))
    }

    @MainActor
    @Test
    func portListOmitsPermissionDisclaimer() {
        let view = PortListView(viewModel: makeViewModel())
        let description = String(reflecting: view)
        #expect(description.contains("Apps may be listed under") == false)
        #expect(description.contains("child process") == false)
    }

    @MainActor
    @Test
    func portListIncludesFilterField() {
        let view = PortListView(viewModel: makeViewModel())
        let description = String(reflecting: view.body)
        #expect(description.contains("TextField"))
        #expect(description.contains("Filter by port or process"))
    }

    @Test
    func portRowShowsPortProcessPidAndKillContent() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        var collector = TextCollector()
        let body = PortRowView(port: port, isKilling: false).body
        collector.walk(body)

        let description = collector.strings.joined(separator: " ")
        #expect(description.contains("3000"))
        #expect(description.contains("node"))
        #expect(description.contains("41446"))
        #expect(String(reflecting: body).contains("KillButton"))
    }

    @MainActor
    @Test
    func portListIncludesFooterWithUpdatedTime() {
        let scanner = StubScanner()
        let viewModel = PortListViewModel(
            scanner: scanner,
            killer: RecordingKiller(),
            defaults: .standard
        )
        scanner.emitPorts([
            PortInfo(port: 3000, processName: "node", pid: 42, protocolType: "TCP")
        ])

        var collector = TextCollector()
        collector.walk(FooterView(viewModel: viewModel).body)
        let description = collector.strings.joined(separator: " ")
        #expect(description.contains("Updated"))
    }

    @MainActor
    @Test
    func portCopyCommandsBuildExpectedStrings() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")
        #expect(PortCopyCommands.lsofCommand(for: port) == "lsof -i :3000")
    }

    @MainActor
    @Test
    func portCopyCommandsWriteToPasteboard() {
        let port = PortInfo(port: 3000, processName: "node", pid: 41446, protocolType: "TCP")

        PortCopyCommands.copyPort(port)
        #expect(NSPasteboard.general.string(forType: .string) == "3000")

        PortCopyCommands.copyPID(port)
        #expect(NSPasteboard.general.string(forType: .string) == "41446")

        PortCopyCommands.copyProcessName(port)
        #expect(NSPasteboard.general.string(forType: .string) == "node")

        PortCopyCommands.copyLsofCommand(port)
        #expect(NSPasteboard.general.string(forType: .string) == "lsof -i :3000")
    }
}

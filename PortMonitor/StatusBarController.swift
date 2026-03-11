import SwiftUI
import AppKit

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var eventMonitor: EventMonitor?

    private let panelSize = NSSize(width: 332, height: 340)

    override init() {
        super.init()
        setupStatusItem()
        setupPanel()
        setupEventMonitor()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = BrandAssets.menuBarIcon()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Port Monitor"
            StatusItemButtonStyle.apply(to: button, highlighted: false)
        }
    }

    private func setupPanel() {
        let panel = MenuBarPanel.make(contentRect: NSRect(origin: .zero, size: panelSize))
        let hostingController = NSHostingController(rootView: PortListView())
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentViewController = hostingController
        panel.setContentSize(panelSize)
        self.panel = panel
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let panel = self.panel else { return }
            if panel.isVisible {
                self.closePopover()
            }
        }
    }

    @objc private func togglePopover() {
        guard let panel = panel, let button = statusItem?.button else { return }

        if panel.isVisible {
            closePopover()
        } else {
            showPopover(from: button)
        }
    }

    private func showPopover(from button: NSStatusBarButton) {
        guard let panel else { return }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let buttonScreenFrame = button.window?.convertToScreen(buttonFrame) ?? .zero
        let visibleFrame = button.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonScreenFrame,
            panelSize: panel.frame.size,
            visibleFrame: visibleFrame
        )

        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        StatusItemButtonStyle.apply(to: button, highlighted: true)
        eventMonitor?.start()
    }

    private func closePopover() {
        panel?.orderOut(nil)
        if let button = statusItem?.button {
            StatusItemButtonStyle.apply(to: button, highlighted: false)
        }
        eventMonitor?.stop()
    }
}

// MARK: - Event Monitor

class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

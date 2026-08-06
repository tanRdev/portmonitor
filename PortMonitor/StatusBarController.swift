import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var panel: MenuBarPanel?
    private var eventMonitor: EventMonitor?
    private var pendingPositioningItem: DispatchWorkItem?
    private let panelSize = NSSize(width: 340, height: 400)
    private let viewModel = PortListViewModel()
    private let maximumPositioningAttempts = 20

    private static let refreshIntervalOptions: [TimeInterval] = [2, 3, 5, 10]

    override init() {
        super.init()

        viewModel.closePanel = { [weak self] in
            self?.closePopover()
        }

        setupStatusItem()
        setupPanel()
        setupEventMonitor()

        if ProcessInfo.processInfo.arguments.contains("--show-panel") {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    let button = self.statusItem?.button
                else { return }
                self.showPopover(relativeTo: button)
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        guard let button = statusItem?.button else { return }

        button.image = BrandAssets.menuBarIcon()
        button.action = #selector(statusItemClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Port Monitor"
    }

    private func setupPanel() {
        let rect = NSRect(origin: .zero, size: panelSize)
        let panel = MenuBarPanel.make(contentRect: rect)
        panel.contentViewController = NSHostingController(rootView: PortListView(viewModel: viewModel))
        panel.setContentSize(panelSize)
        self.panel = panel
    }

    private func setupEventMonitor() {
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let panel, panel.isVisible else { return }
            closePopover()
        }
        eventMonitor?.start()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
            return
        }

        togglePopover()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let panel else { return }

        if panel.isVisible {
            closePopover()
        } else {
            showPopover(relativeTo: button)
        }
    }

    private func showPopover(relativeTo button: NSButton, positioningAttempt: Int = 0) {
        // A fresh show request replaces any pending retry so rapid clicks
        // cannot stack concurrent positioning chains.
        if positioningAttempt == 0 {
            cancelPendingPositioning()
        }

        guard let panel, let buttonWindow = button.window else { return }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        guard let screen = buttonWindow.screen ?? NSScreen.main else { return }

        guard MenuBarPanelPositioning.isUsableStatusItemFrame(
            buttonFrameOnScreen,
            screenFrame: screen.frame,
            visibleFrame: screen.visibleFrame
        ) else {
            guard positioningAttempt < maximumPositioningAttempts else { return }
            let item = DispatchWorkItem { [weak self, weak button] in
                MainActor.assumeIsolated {
                    guard let self, let button else { return }
                    self.pendingPositioningItem = nil
                    self.showPopover(relativeTo: button, positioningAttempt: positioningAttempt + 1)
                }
            }
            pendingPositioningItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
            return
        }

        let origin = MenuBarPanelPositioning.origin(
            buttonFrame: buttonFrameOnScreen,
            panelSize: panel.frame.size,
            visibleFrame: screen.visibleFrame
        )

        panel.setFrameOrigin(origin)
        NotificationCenter.default.post(name: .portMonitorPanelWillShow, object: nil)
        viewModel.startScanning()
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func closePopover() {
        cancelPendingPositioning()
        viewModel.stopScanning()
        panel?.orderOut(nil)
    }

    private func cancelPendingPositioning() {
        pendingPositioningItem?.cancel()
        pendingPositioningItem = nil
    }

    // MARK: - Right-click status menu

    private func showStatusMenu() {
        let menu = NSMenu()

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let intervalMenu = NSMenu()
        for interval in Self.refreshIntervalOptions {
            let item = NSMenuItem(
                title: "Every \(Int(interval)) seconds",
                action: #selector(changeRefreshInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = interval
            item.state = viewModel.refreshInterval == interval ? .on : .off
            intervalMenu.addItem(item)
        }
        let intervalItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        menu.setSubmenu(intervalMenu, for: intervalItem)
        menu.addItem(intervalItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Port Monitor", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Temporarily assign the menu so it opens at the status item, then
        // clear it again so left-click keeps toggling the panel.
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshNow() {
        Task { await viewModel.refreshNow() }
    }

    @objc private func changeRefreshInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? TimeInterval else { return }
        viewModel.setRefreshInterval(interval)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Port Monitor: failed to update launch at login: \(error.localizedDescription)")
        }
    }

    @objc private func quitApp() {
        viewModel.quitApp()
    }
}

final class EventMonitor {
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void
    private var monitor: Any?

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stop()
    }
}

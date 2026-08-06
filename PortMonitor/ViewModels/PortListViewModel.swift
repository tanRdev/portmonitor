import Foundation
import Combine
import AppKit

enum PortSortOrder: String, CaseIterable, Sendable {
    case byPort
    case byProcess

    var label: String {
        switch self {
        case .byPort: "Sort by Port"
        case .byProcess: "Sort by Process"
        }
    }
}

@MainActor
final class PortListViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published var errorMessage: String?
    @Published var killingPortId: String?
    @Published private(set) var failedKillPort: PortInfo?
    @Published private(set) var isStale = false
    @Published private(set) var lastUpdatedAt: Date?
    @Published var filterText = ""
    @Published private(set) var sortOrder: PortSortOrder
    @Published private(set) var refreshInterval: TimeInterval

    /// Set by the status bar controller so the panel can close itself.
    var closePanel: () -> Void = {}

    private let scanner: any PortScanning
    private let killer: any ProcessKilling
    private let terminateApp: () -> Void
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private static let sortOrderDefaultsKey = "portSortOrder"
    private static let refreshIntervalDefaultsKey = "refreshInterval"
    private static let defaultRefreshInterval: TimeInterval = 3.0

    var visiblePorts: [PortInfo] {
        let query = filterText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty
            ? ports
            : ports.filter { port in
                String(port.port).contains(query)
                    || port.processName.localizedCaseInsensitiveContains(query)
            }

        switch sortOrder {
        case .byPort:
            return filtered.sorted { $0.port < $1.port }
        case .byProcess:
            return filtered.sorted {
                let comparison = $0.processName.localizedCaseInsensitiveCompare($1.processName)
                return comparison == .orderedSame ? $0.port < $1.port : comparison == .orderedAscending
            }
        }
    }

    init(
        scanner: any PortScanning = PortScanner(),
        killer: any ProcessKilling = ProcessKiller(),
        terminateApp: @escaping () -> Void = { NSApplication.shared.terminate(nil) },
        defaults: UserDefaults = .standard
    ) {
        self.scanner = scanner
        self.killer = killer
        self.terminateApp = terminateApp
        self.defaults = defaults

        let storedSortOrder = defaults.string(forKey: Self.sortOrderDefaultsKey)
        self.sortOrder = storedSortOrder.flatMap(PortSortOrder.init(rawValue:)) ?? .byPort

        let storedInterval = defaults.double(forKey: Self.refreshIntervalDefaultsKey)
        self.refreshInterval = storedInterval > 0 ? storedInterval : Self.defaultRefreshInterval
        scanner.setUpdateInterval(self.refreshInterval)

        scanner.portsPublisher
            .sink { [weak self] ports in
                guard let self else { return }
                self.ports = ports
                self.isLoading = false
                self.isRefreshing = false
                self.isStale = false
                self.errorMessage = nil
                self.lastUpdatedAt = Date()
            }
            .store(in: &cancellables)

        scanner.errorPublisher
            .sink { [weak self] error in
                guard let self else { return }
                self.isLoading = false
                self.isRefreshing = false
                self.isStale = !self.ports.isEmpty
                self.errorMessage = error.userMessage
            }
            .store(in: &cancellables)
    }

    func startScanning() {
        isLoading = ports.isEmpty
        scanner.startScanning()
    }

    func stopScanning() {
        scanner.stopScanning()
    }

    func refreshNow() async {
        isLoading = ports.isEmpty
        isRefreshing = true

        do {
            try await scanner.refresh()
        } catch let error as PortScannerError {
            isRefreshing = false
            isStale = !ports.isEmpty
            errorMessage = error.userMessage
        } catch {
            isRefreshing = false
            isStale = !ports.isEmpty
            errorMessage = "Unable to scan ports: \(error.localizedDescription)"
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func killPort(_ port: PortInfo) async {
        guard killingPortId == nil else { return }

        killingPortId = port.id
        errorMessage = nil
        failedKillPort = nil

        do {
            try await killer.kill(port: port)
        } catch let error as KillError {
            errorMessage = message(for: error)
            failedKillPort = offersForceKill(for: error) ? port : nil
            killingPortId = nil
            return
        } catch {
            errorMessage = "Failed to kill process: \(error.localizedDescription)"
            failedKillPort = port
            killingPortId = nil
            return
        }

        // The kill succeeded, so a refresh failure here is a scan problem:
        // never report it as a kill failure or offer Force Kill for a
        // process that was already signaled.
        await refreshAfterKill()

        killingPortId = nil
    }

    func forceKillFailedPort() async {
        guard let port = failedKillPort, killingPortId == nil else { return }

        killingPortId = port.id
        errorMessage = nil

        do {
            try await killer.forceKill(port: port)
        } catch let error as KillError {
            errorMessage = message(for: error)
            killingPortId = nil
            return
        } catch {
            errorMessage = "Failed to kill process: \(error.localizedDescription)"
            killingPortId = nil
            return
        }

        failedKillPort = nil
        await refreshAfterKill()

        killingPortId = nil
    }

    /// Post-kill refresh. Errors are reported as scan errors, mirroring
    /// `refreshNow`, and never touch the kill failure state.
    private func refreshAfterKill() async {
        do {
            try await scanner.refresh()
        } catch let error as PortScannerError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Unable to scan ports: \(error.localizedDescription)"
        }
    }

    func setSortOrder(_ order: PortSortOrder) {
        sortOrder = order
        defaults.set(order.rawValue, forKey: Self.sortOrderDefaultsKey)
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        refreshInterval = interval
        defaults.set(interval, forKey: Self.refreshIntervalDefaultsKey)
        scanner.setUpdateInterval(interval)
    }

    func quitApp() {
        terminateApp()
    }

    /// Force Kill is the explicit escalation path: it is only offered after
    /// a plain SIGTERM failed for an unknown reason. Policy refusals and
    /// identity changes are never escalated automatically.
    private func offersForceKill(for error: KillError) -> Bool {
        switch error {
        case .processNotFound, .permissionDenied, .processIdentityChanged, .policyRefused:
            return false
        case .killFailed:
            return true
        }
    }

    private func message(for error: KillError) -> String {
        switch error {
        case .processNotFound:
            return "Process already terminated"
        case .permissionDenied:
            return "Permission denied to terminate this process"
        case let .processIdentityChanged(expected, found):
            return "PID now belongs to \(found), not \(expected). Refresh and try again."
        case let .policyRefused(reason):
            return reason
        case let .killFailed(message):
            return "Failed to kill process: \(message)"
        }
    }
}

import Foundation
import Combine
import AppKit

@MainActor
final class PortListViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var killingPortId: String?
    @Published private(set) var lastUpdatedAt: Date?

    private let scanner: any PortScanning
    private let killer: any ProcessKilling
    private let terminateApp: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        scanner: any PortScanning = PortScanner(),
        killer: any ProcessKilling = ProcessKiller(),
        terminateApp: @escaping () -> Void = { NSApplication.shared.terminate(nil) }
    ) {
        self.scanner = scanner
        self.killer = killer
        self.terminateApp = terminateApp

        scanner.portsPublisher
            .sink { [weak self] ports in
                guard let self else { return }
                self.ports = ports
                self.isLoading = false
                self.errorMessage = nil
                self.lastUpdatedAt = Date()
            }
            .store(in: &cancellables)

        scanner.errorPublisher
            .sink { [weak self] error in
                guard let self else { return }
                self.isLoading = false
                self.errorMessage = error.userMessage
            }
            .store(in: &cancellables)
    }

    func startScanning() {
        isLoading = true
        scanner.startScanning()
    }

    func stopScanning() {
        scanner.stopScanning()
    }

    func killPort(_ port: PortInfo) async {
        guard killingPortId == nil else { return }

        killingPortId = port.id
        errorMessage = nil

        do {
            try await killer.kill(port: port)
            try await scanner.refresh()
        } catch let error as KillError {
            errorMessage = message(for: error)
        } catch let error as PortScannerError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "Failed to kill process: \(error.localizedDescription)"
        }

        killingPortId = nil
    }

    func quitApp() {
        terminateApp()
    }

    private func message(for error: KillError) -> String {
        switch error {
        case .processNotFound:
            return "Process already terminated"
        case .permissionDenied:
            return "Permission denied to terminate this process"
        case let .killFailed(message):
            return "Failed to kill process: \(message)"
        }
    }
}
